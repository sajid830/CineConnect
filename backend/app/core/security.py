import asyncio
import json
import time
from typing import Any, Dict, Optional
from uuid import UUID

import httpx
import jwt
from jwt import PyJWK, PyJWKSet

from app.core.config import settings
from app.core.logging import logger


class AsyncSupabaseJWKManager:
    """Asynchronous JWKS key manager for Supabase asymmetric JWT verification.

    Maintains an in-memory cache of JWKs with TTL and handles key rotation gracefully
    using an asynchronous lock and httpx.AsyncClient.
    """

    def __init__(
        self,
        jwks_url: Optional[str] = None,
        cache_ttl: int = 300,
        timeout: float = 5.0,
        cooldown_seconds: float = 10.0,
    ) -> None:
        self._custom_jwks_url = jwks_url
        self.cache_ttl = cache_ttl
        self.timeout = timeout
        self.cooldown_seconds = cooldown_seconds
        self._jwk_set: Optional[PyJWKSet] = None
        self._last_fetch_time: float = 0.0
        self._lock = asyncio.Lock()
        self._client: Optional[httpx.AsyncClient] = None

    @property
    def jwks_url(self) -> str:
        return self._custom_jwks_url or settings.SUPABASE_JWKS_URL

    async def get_client(self) -> httpx.AsyncClient:
        """Returns or lazily initializes the reusable httpx.AsyncClient."""
        if self._client is None or self._client.is_closed:
            self._client = httpx.AsyncClient(timeout=httpx.Timeout(self.timeout))
        return self._client

    async def aclose(self) -> None:
        """Closes the underlying HTTP client on application shutdown."""
        if self._client is not None and not self._client.is_closed:
            await self._client.aclose()
            self._client = None

    def _validate_jwk(self, pyjwk: PyJWK, expected_alg: str) -> bool:
        """Validates that the JWK conforms to required cryptography and usage parameters."""
        jwk_data = getattr(pyjwk, "_jwk_data", {}) or {}
        kty = getattr(pyjwk, "key_type", None) or jwk_data.get("kty")
        use = getattr(pyjwk, "public_key_use", None) or jwk_data.get("use")
        alg = getattr(pyjwk, "algorithm_name", None) or jwk_data.get("alg")

        # 1. Key type validation
        if expected_alg.startswith("RS"):
            if kty != "RSA":
                logger.warning(f"JWK kty mismatch: expected 'RSA', got '{kty}'.")
                return False
        elif expected_alg.startswith("ES"):
            crv = jwk_data.get("crv")
            if kty != "EC" or crv != "P-256":
                logger.warning(f"JWK kty/crv mismatch: expected 'EC'/'P-256', got '{kty}'/'{crv}'.")
                return False

        # 2. Key usage validation (RFC 7517 Section 4.2)
        if use and use != "sig":
            logger.warning(f"JWK usage mismatch: expected 'sig', got '{use}'.")
            return False

        # 3. Key operations validation (RFC 7517 Section 4.3)
        key_ops = jwk_data.get("key_ops")
        if key_ops is not None:
            if not isinstance(key_ops, list):
                logger.warning(f"JWK key_ops malformed: expected list, got '{type(key_ops).__name__}'.")
                return False
            if not key_ops or not all(isinstance(op, str) for op in key_ops):
                logger.warning("JWK key_ops malformed: entries must be non-empty valid strings.")
                return False
            if len(key_ops) != len(set(key_ops)):
                logger.warning("JWK key_ops rejected: duplicate operations present.")
                return False
            if "verify" not in key_ops:
                logger.warning(f"JWK key_ops rejected: missing required 'verify' operation. Present: {key_ops}")
                return False

        # 4. Algorithm validation (if explicitly present in JWK)
        if alg and alg != expected_alg:
            logger.warning(f"JWK alg mismatch: expected '{expected_alg}', got '{alg}'.")
            return False

        return True

    def _find_valid_key(self, kid: str, expected_alg: str) -> Optional[PyJWK]:
        """Finds and validates a key with matching kid from cached JWK set."""
        if not self._jwk_set:
            return None
        try:
            pyjwk = self._jwk_set[kid]
            if self._validate_jwk(pyjwk, expected_alg):
                return pyjwk
        except (KeyError, Exception) as exc:
            logger.debug(f"Key ID '{kid}' not found in current cache: {exc}")
        return None

    async def _fetch_jwks(self) -> Optional[PyJWKSet]:
        """Fetches JWKS from endpoint with timeout and exception safety."""
        try:
            client = await self.get_client()
            response = await client.get(self.jwks_url)
            if response.status_code != 200:
                logger.warning(
                    f"Failed to fetch JWKS from {self.jwks_url}: HTTP {response.status_code}"
                )
                return None
            jwks_dict = response.json()
            if not isinstance(jwks_dict, dict) or "keys" not in jwks_dict:
                logger.warning(f"Invalid JWKS payload format from {self.jwks_url}.")
                return None
            return PyJWKSet.from_dict(jwks_dict)
        except Exception as exc:
            logger.warning(f"Exception during JWKS fetch from {self.jwks_url}: {exc}")
            return None

    async def get_signing_key(self, kid: str, expected_alg: str) -> Optional[PyJWK]:
        """Retrieves and validates the PyJWK for the given kid and expected algorithm.

        Uses cached JWKs if fresh; coordinates refreshing with lock and cooldown.
        """
        now = time.time()

        # Check cache if valid
        if self._jwk_set and (now - self._last_fetch_time < self.cache_ttl):
            key = self._find_valid_key(kid, expected_alg)
            if key is not None:
                return key

        # If key missing or cache expired, refresh if cooldown allows
        async with self._lock:
            # Recheck inside lock
            now = time.time()
            if self._jwk_set:
                key = self._find_valid_key(kid, expected_alg)
                if key is not None and (now - self._last_fetch_time < self.cache_ttl):
                    return key

            if now - self._last_fetch_time < self.cooldown_seconds:
                # In cooldown, avoid hammering endpoint
                logger.warning(f"JWKS refresh cooldown active. Rejecting unknown kid '{kid}'.")
                return None

            fetched_set = await self._fetch_jwks()
            if fetched_set:
                self._jwk_set = fetched_set
                self._last_fetch_time = time.time()
                return self._find_valid_key(kid, expected_alg)

        return None


# Global JWK manager instance
jwk_manager = AsyncSupabaseJWKManager()


def create_test_token(
    user_id: Any,
    email: str = "test@cineconnect.com",
    account_type: str = "talent",
    role: Optional[str] = None,
    extra_claims: Optional[Dict[str, Any]] = None,
    expires_in_seconds: int = 86400,
    algorithm: Optional[str] = None,
    signing_key: Optional[str] = None,
    headers: Optional[Dict[str, Any]] = None,
) -> str:
    """Generates a Supabase-compatible JWT token for testing and local development.

    Complies with strict issuer, audience, and algorithm standards.
    """
    now = int(time.time())
    effective_role = role or account_type
    effective_alg = algorithm or settings.effective_jwt_algorithm
    token_headers = {"alg": effective_alg, "typ": "JWT"}
    if headers:
        token_headers.update(headers)

    payload = {
        "sub": str(user_id),
        "email": email,
        "iss": settings.SUPABASE_JWT_ISSUER,
        "aud": settings.SUPABASE_JWT_AUDIENCE,
        "role": "authenticated",
        "iat": now,
        "exp": now + expires_in_seconds,
        "user_metadata": {"account_type": effective_role, "role": effective_role},
    }
    if extra_claims:
        for k, v in extra_claims.items():
            if isinstance(v, dict) and k in payload and isinstance(payload[k], dict):
                payload[k].update(v)
            else:
                payload[k] = v

    key = signing_key or settings.SUPABASE_JWT_SECRET
    return jwt.encode(payload, key, algorithm=effective_alg, headers=token_headers)


async def verify_supabase_jwt(token: str) -> Optional[Dict[str, Any]]:
    """Verifies and decodes a Supabase JWT access token asynchronously.

    Strict security guarantees:
    - Verification algorithm is strictly dictated by server configuration (SUPABASE_JWT_ALGORITHM).
    - Tokens specifying 'none', unconfigured, or mismatched algorithms are rejected.
    - Rejects tokens with 'jku' or 'x5u' header injection.
    - Asymmetric keys (RS256, ES256) are fetched asynchronously via JWKS and validated for
      expected kid, kty, crv, use, and alg.
    - Symmetric keys (HS256) use the configured SUPABASE_JWT_SECRET.
    - Required claims 'exp', 'iss', 'aud', and 'sub' are strictly validated.
    - 'sub' claim is validated as a valid UUID string.
    - Returns decoded payload dict if valid, or None if invalid or expired.
    """
    try:
        token_clean = token.strip()
        if not token_clean:
            return None

        # 1. Inspect unverified header for structural security
        try:
            unverified_header = jwt.get_unverified_header(token_clean)
        except Exception as exc:
            logger.warning(f"Malformed JWT header: {exc}")
            return None

        # 2. Block header injection attacks (jku, x5u)
        if "jku" in unverified_header or "x5u" in unverified_header:
            logger.warning("JWT rejected: untrusted jku or x5u header present.")
            return None

        # 3. Explicit algorithm enforcement: header MUST match configured server algorithm
        configured_alg = settings.effective_jwt_algorithm
        header_alg = unverified_header.get("alg")
        if not header_alg or header_alg.upper() == "NONE":
            logger.warning("JWT rejected: missing or 'none' algorithm.")
            return None

        if header_alg.upper() != configured_alg:
            logger.warning(
                f"JWT rejected: algorithm mismatch. Configured='{configured_alg}', token header='{header_alg}'."
            )
            return None

        # 4. Resolve key material based on configured mode
        if configured_alg in ("RS256", "ES256"):
            kid = unverified_header.get("kid")
            if not kid:
                logger.warning(f"JWT rejected: {configured_alg} requires 'kid' in header.")
                return None

            pyjwk = await jwk_manager.get_signing_key(kid, expected_alg=configured_alg)
            if pyjwk is None:
                logger.warning(f"JWT rejected: unable to resolve valid signing key for kid '{kid}'.")
                return None
            key = pyjwk.key
        elif configured_alg == "HS256":
            key = settings.SUPABASE_JWT_SECRET
        else:
            logger.warning(f"JWT rejected: unsupported server algorithm '{configured_alg}'.")
            return None

        # 5. Decode and strictly validate claims and signature
        payload = jwt.decode(
            token_clean,
            key=key,
            algorithms=[configured_alg],
            audience=settings.SUPABASE_JWT_AUDIENCE,
            issuer=settings.SUPABASE_JWT_ISSUER,
            options={
                "verify_signature": True,
                "verify_exp": True,
                "verify_iss": True,
                "verify_aud": True,
                "require": ["exp", "iss", "aud", "sub"],
            },
            leeway=settings.JWT_CLOCK_SKEW_LEEWAY_SECONDS,
        )

        # 6. Validate subject claim format
        sub = payload.get("sub")
        try:
            UUID(str(sub))
        except (ValueError, TypeError):
            logger.warning("JWT rejected: 'sub' claim is not a valid UUID format.")
            return None

        return payload

    except jwt.ExpiredSignatureError:
        logger.warning("JWT rejected: token signature has expired.")
        return None
    except jwt.InvalidIssuerError:
        logger.warning("JWT rejected: invalid issuer claim.")
        return None
    except jwt.InvalidAudienceError:
        logger.warning("JWT rejected: invalid audience claim.")
        return None
    except jwt.InvalidSignatureError:
        logger.warning("JWT rejected: signature verification failed.")
        return None
    except jwt.PyJWTError as exc:
        logger.warning(f"JWT rejected: PyJWT validation error: {exc}")
        return None
    except Exception as exc:
        logger.error(f"Unexpected error during JWT verification: {exc}")
        return None

