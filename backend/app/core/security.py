import base64
import hashlib
import hmac
import json
import time
from typing import Any, Dict, Optional
from uuid import UUID

from app.core.config import settings
from app.core.logging import logger


def _base64url_decode(input_str: str) -> bytes:
    """Decode base64url-encoded string with padding correction."""
    rem = len(input_str) % 4
    if rem > 0:
        input_str += "=" * (4 - rem)
    return base64.urlsafe_b64decode(input_str)


def _base64url_encode(input_bytes: bytes) -> str:
    """Encode bytes to base64url string without trailing padding."""
    return base64.urlsafe_b64encode(input_bytes).decode("utf-8").rstrip("=")


def create_test_token(
    user_id: Any,
    email: str = "test@cineconnect.com",
    account_type: str = "talent",
    role: Optional[str] = None,
    extra_claims: Optional[Dict[str, Any]] = None,
    expires_in_seconds: int = 86400,
) -> str:
    """Generates a test Supabase-compatible JWT token signed with SUPABASE_JWT_SECRET.
    Useful for local development and automated API tests.
    """
    now = int(time.time())
    effective_role = role or account_type
    header = {"alg": "HS256", "typ": "JWT"}
    payload = {
        "sub": str(user_id),
        "email": email,
        "role": "authenticated",
        "aud": "authenticated",
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

    header_b64 = _base64url_encode(json.dumps(header, separators=(",", ":")).encode("utf-8"))
    payload_b64 = _base64url_encode(json.dumps(payload, separators=(",", ":")).encode("utf-8"))
    signing_input = f"{header_b64}.{payload_b64}".encode("utf-8")

    signature = hmac.new(
        settings.SUPABASE_JWT_SECRET.encode("utf-8"),
        signing_input,
        hashlib.sha256,
    ).digest()
    sig_b64 = _base64url_encode(signature)

    return f"{header_b64}.{payload_b64}.{sig_b64}"


def verify_supabase_jwt(token: str) -> Optional[Dict[str, Any]]:
    """Verifies and decodes a Supabase JWT token.
    Validates HS256 HMAC signature against SUPABASE_JWT_SECRET and verifies expiration.
    Returns decoded payload dict if valid, or None if invalid or expired.
    """
    try:
        parts = token.strip().split(".")
        if len(parts) != 3:
            logger.warning("Malformed JWT format (does not contain 3 segments).")
            return None

        header_b64, payload_b64, signature_b64 = parts

        # Verify signature
        signing_input = f"{header_b64}.{payload_b64}".encode("utf-8")
        expected_sig = hmac.new(
            settings.SUPABASE_JWT_SECRET.encode("utf-8"),
            signing_input,
            hashlib.sha256,
        ).digest()
        actual_sig = _base64url_decode(signature_b64)

        if not hmac.compare_digest(expected_sig, actual_sig):
            logger.warning("JWT signature verification failed.")
            return None

        # Decode payload
        payload_bytes = _base64url_decode(payload_b64)
        payload = json.loads(payload_bytes.decode("utf-8"))

        # Verify expiration
        exp = payload.get("exp")
        if exp and int(exp) < int(time.time()):
            logger.warning("JWT token has expired.")
            return None

        # Verify subject (user UUID)
        sub = payload.get("sub")
        if not sub:
            logger.warning("JWT token missing 'sub' claim.")
            return None

        return payload
    except Exception as exc:
        logger.error(f"Error during JWT verification: {exc}")
        return None
