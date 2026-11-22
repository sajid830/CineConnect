import asyncio
import time
import uuid
from typing import Any, Dict
from unittest.mock import AsyncMock, patch

import httpx
import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import ec, rsa

from app.core.config import settings
from app.core.security import AsyncSupabaseJWKManager, create_test_token, verify_supabase_jwt
from tests.conftest import TEST_HS256_SECRET, TEST_EC_KEY, TEST_EC_KID, create_test_jwt


def _rsa_to_jwk(private_key: rsa.RSAPrivateKey, kid: str = "test-rsa-kid") -> Dict[str, Any]:
    public_numbers = private_key.public_key().public_numbers()
    e_bytes = public_numbers.e.to_bytes((public_numbers.e.bit_length() + 7) // 8, "big")
    n_bytes = public_numbers.n.to_bytes(256, "big")
    return {
        "kty": "RSA",
        "kid": kid,
        "use": "sig",
        "alg": "RS256",
        "n": jwt.utils.base64url_encode(n_bytes).decode("utf-8"),
        "e": jwt.utils.base64url_encode(e_bytes).decode("utf-8"),
    }


def _ec_to_jwk(private_key: ec.EllipticCurvePrivateKey, kid: str = "test-ec-kid") -> Dict[str, Any]:
    public_numbers = private_key.public_key().public_numbers()
    x_bytes = public_numbers.x.to_bytes(32, "big")
    y_bytes = public_numbers.y.to_bytes(32, "big")
    return {
        "kty": "EC",
        "crv": "P-256",
        "kid": kid,
        "use": "sig",
        "alg": "ES256",
        "x": jwt.utils.base64url_encode(x_bytes).decode("utf-8"),
        "y": jwt.utils.base64url_encode(y_bytes).decode("utf-8"),
    }


@pytest.mark.asyncio
async def test_verify_hs256_success():
    """Valid HS256 token verification succeeds with payload."""
    user_id = uuid.uuid4()
    with patch.object(settings, "SUPABASE_JWT_ALGORITHM", "HS256"), \
         patch.object(settings, "SUPABASE_JWT_SECRET", TEST_HS256_SECRET):
        token = create_test_token(
            user_id=user_id,
            email="talent@cineconnect.com",
            algorithm="HS256",
            signing_key=TEST_HS256_SECRET,
        )
        payload = await verify_supabase_jwt(token)

        assert payload is not None
        assert payload["sub"] == str(user_id)
        assert payload["email"] == "talent@cineconnect.com"
        assert payload["iss"] == settings.SUPABASE_JWT_ISSUER
        assert payload["aud"] == settings.SUPABASE_JWT_AUDIENCE


@pytest.mark.asyncio
async def test_verify_hs256_invalid_secret():
    """HS256 token signed with wrong secret is rejected."""
    user_id = uuid.uuid4()
    with patch.object(settings, "SUPABASE_JWT_ALGORITHM", "HS256"), \
         patch.object(settings, "SUPABASE_JWT_SECRET", TEST_HS256_SECRET):
        token = create_test_token(
            user_id=user_id,
            algorithm="HS256",
            signing_key="wrong_secret_key_12345678901234567890",
        )
        payload = await verify_supabase_jwt(token)
        assert payload is None


@pytest.mark.asyncio
async def test_verify_es256_success():
    """Valid ES256 token verification succeeds with payload using isolated test JWKS."""
    user_id = uuid.uuid4()
    with patch.object(settings, "SUPABASE_JWT_ALGORITHM", "ES256"):
        token = create_test_jwt(
            user_id=user_id,
            email="talent_es256@cineconnect.com",
            algorithm="ES256",
        )
        payload = await verify_supabase_jwt(token)

        assert payload is not None
        assert payload["sub"] == str(user_id)
        assert payload["email"] == "talent_es256@cineconnect.com"
        assert payload["iss"] == settings.SUPABASE_JWT_ISSUER
        assert payload["aud"] == settings.SUPABASE_JWT_AUDIENCE


@pytest.mark.asyncio
async def test_verify_es256_invalid_signature():
    """ES256 token signed with an untrusted EC key is rejected."""
    user_id = uuid.uuid4()
    untrusted_ec_key = ec.generate_private_key(ec.SECP256R1())
    with patch.object(settings, "SUPABASE_JWT_ALGORITHM", "ES256"):
        token = create_test_jwt(
            user_id=user_id,
            email="untrusted@cineconnect.com",
            algorithm="ES256",
            signing_key=untrusted_ec_key,
            kid=TEST_EC_KID,
        )
        payload = await verify_supabase_jwt(token)
        assert payload is None


@pytest.mark.asyncio
async def test_verify_es256_expired_token():
    """ES256 token expired past clock skew leeway is rejected."""
    user_id = uuid.uuid4()
    with patch.object(settings, "SUPABASE_JWT_ALGORITHM", "ES256"):
        token = create_test_jwt(
            user_id=user_id,
            email="expired_es256@cineconnect.com",
            algorithm="ES256",
            expires_in_seconds=-120,
        )
        payload = await verify_supabase_jwt(token)
        assert payload is None


@pytest.mark.asyncio
async def test_reject_algorithm_none():
    """Reject unsigned tokens specifying alg='none'."""
    now = int(time.time())
    payload = {
        "sub": str(uuid.uuid4()),
        "iss": settings.SUPABASE_JWT_ISSUER,
        "aud": settings.SUPABASE_JWT_AUDIENCE,
        "exp": now + 3600,
    }
    # Create token with alg: none
    token = jwt.encode(payload, key="", algorithm="none")
    verified = await verify_supabase_jwt(token)
    assert verified is None


@pytest.mark.asyncio
async def test_reject_algorithm_mismatch():
    """Reject token when header alg does not match configured SUPABASE_JWT_ALGORITHM."""
    user_id = uuid.uuid4()
    # Token signed with HS512 while config expects HS256
    with patch.object(settings, "SUPABASE_JWT_ALGORITHM", "HS256"), \
         patch.object(settings, "SUPABASE_JWT_SECRET", TEST_HS256_SECRET):
        token = create_test_token(
            user_id=user_id,
            algorithm="HS512",
            signing_key="test_secret_for_hs512_verification_test_at_least_64_characters_long_1234",
        )
        verified = await verify_supabase_jwt(token)
        assert verified is None


@pytest.mark.asyncio
async def test_reject_jku_and_x5u_headers():
    """Reject tokens that include jku or x5u headers to prevent header injection."""
    user_id = uuid.uuid4()
    with patch.object(settings, "SUPABASE_JWT_ALGORITHM", "HS256"), \
         patch.object(settings, "SUPABASE_JWT_SECRET", TEST_HS256_SECRET):
        token_jku = create_test_token(
            user_id=user_id,
            algorithm="HS256",
            signing_key=TEST_HS256_SECRET,
            headers={"jku": "https://attacker.com/jwks.json"},
        )
        assert await verify_supabase_jwt(token_jku) is None

        token_x5u = create_test_token(
            user_id=user_id,
            algorithm="HS256",
            signing_key=TEST_HS256_SECRET,
            headers={"x5u": "https://attacker.com/cert.pem"},
        )
        assert await verify_supabase_jwt(token_x5u) is None


@pytest.mark.asyncio
async def test_reject_expired_token():
    """Reject token expired past clock skew leeway."""
    user_id = uuid.uuid4()
    # Expired 120 seconds ago (> 60s leeway)
    with patch.object(settings, "SUPABASE_JWT_ALGORITHM", "HS256"), \
         patch.object(settings, "SUPABASE_JWT_SECRET", TEST_HS256_SECRET):
        token = create_test_token(
            user_id=user_id,
            algorithm="HS256",
            signing_key=TEST_HS256_SECRET,
            expires_in_seconds=-120,
        )
        assert await verify_supabase_jwt(token) is None


@pytest.mark.asyncio
async def test_accept_token_within_clock_skew_leeway():
    """Accept token expired 30 seconds ago within 60s clock skew leeway."""
    user_id = uuid.uuid4()
    with patch.object(settings, "SUPABASE_JWT_ALGORITHM", "HS256"), \
         patch.object(settings, "SUPABASE_JWT_SECRET", TEST_HS256_SECRET):
        token = create_test_token(
            user_id=user_id,
            algorithm="HS256",
            signing_key=TEST_HS256_SECRET,
            expires_in_seconds=-30,
        )
        payload = await verify_supabase_jwt(token)
        assert payload is not None
        assert payload["sub"] == str(user_id)


@pytest.mark.asyncio
async def test_reject_missing_required_claims():
    """Reject tokens missing exp, iss, aud, or sub."""
    now = int(time.time())
    base_claims = {
        "sub": str(uuid.uuid4()),
        "iss": settings.SUPABASE_JWT_ISSUER,
        "aud": settings.SUPABASE_JWT_AUDIENCE,
        "exp": now + 3600,
    }

    with patch.object(settings, "SUPABASE_JWT_ALGORITHM", "HS256"), \
         patch.object(settings, "SUPABASE_JWT_SECRET", TEST_HS256_SECRET):
        # Missing exp
        claims_no_exp = {k: v for k, v in base_claims.items() if k != "exp"}
        token = jwt.encode(claims_no_exp, TEST_HS256_SECRET, algorithm="HS256")
        assert await verify_supabase_jwt(token) is None

        # Missing iss
        claims_no_iss = {k: v for k, v in base_claims.items() if k != "iss"}
        token = jwt.encode(claims_no_iss, TEST_HS256_SECRET, algorithm="HS256")
        assert await verify_supabase_jwt(token) is None

        # Missing aud
        claims_no_aud = {k: v for k, v in base_claims.items() if k != "aud"}
        token = jwt.encode(claims_no_aud, TEST_HS256_SECRET, algorithm="HS256")
        assert await verify_supabase_jwt(token) is None

        # Missing sub
        claims_no_sub = {k: v for k, v in base_claims.items() if k != "sub"}
        token = jwt.encode(claims_no_sub, TEST_HS256_SECRET, algorithm="HS256")
        assert await verify_supabase_jwt(token) is None


@pytest.mark.asyncio
async def test_reject_mismatched_iss_and_aud():
    """Reject tokens where issuer or audience does not match server configuration."""
    user_id = uuid.uuid4()

    with patch.object(settings, "SUPABASE_JWT_ALGORITHM", "HS256"), \
         patch.object(settings, "SUPABASE_JWT_SECRET", TEST_HS256_SECRET):
        token_wrong_iss = create_test_token(
            user_id=user_id,
            algorithm="HS256",
            signing_key=TEST_HS256_SECRET,
            extra_claims={"iss": "https://malicious-issuer.supabase.co/auth/v1"},
        )
        assert await verify_supabase_jwt(token_wrong_iss) is None

        token_wrong_aud = create_test_token(
            user_id=user_id,
            algorithm="HS256",
            signing_key=TEST_HS256_SECRET,
            extra_claims={"aud": "other-audience"},
        )
        assert await verify_supabase_jwt(token_wrong_aud) is None


@pytest.mark.asyncio
async def test_reject_invalid_uuid_sub():
    """Reject tokens where sub claim is not a valid UUID string."""
    with patch.object(settings, "SUPABASE_JWT_ALGORITHM", "HS256"), \
         patch.object(settings, "SUPABASE_JWT_SECRET", TEST_HS256_SECRET):
        token = create_test_token(
            user_id="not-a-valid-uuid",
            algorithm="HS256",
            signing_key=TEST_HS256_SECRET,
        )
        assert await verify_supabase_jwt(token) is None


@pytest.mark.asyncio
async def test_asymmetric_rs256_verification_and_caching():
    """Test RS256 token verification with mocked JWKS, including caching behavior."""
    rsa_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    kid = "rsa-test-kid-1"
    jwk_dict = _rsa_to_jwk(rsa_key, kid=kid)
    jwks_response = {"keys": [jwk_dict]}

    user_id = uuid.uuid4()
    now = int(time.time())
    payload = {
        "sub": str(user_id),
        "iss": settings.SUPABASE_JWT_ISSUER,
        "aud": settings.SUPABASE_JWT_AUDIENCE,
        "exp": now + 3600,
    }
    token = jwt.encode(
        payload,
        key=rsa_key,
        algorithm="RS256",
        headers={"kid": kid, "alg": "RS256", "typ": "JWT"},
    )

    manager = AsyncSupabaseJWKManager(cache_ttl=300, cooldown_seconds=0)

    # Mock HTTP response
    mock_response = httpx.Response(200, json=jwks_response, request=httpx.Request("GET", "https://mock"))
    mock_client = AsyncMock()
    mock_client.get = AsyncMock(return_value=mock_response)
    mock_client.is_closed = False

    with patch.object(manager, "get_client", AsyncMock(return_value=mock_client)), \
         patch("app.core.security.jwk_manager", manager), \
         patch.object(settings, "SUPABASE_JWT_ALGORITHM", "RS256"):

        # First verification - should fetch from mock endpoint
        verified = await verify_supabase_jwt(token)
        assert verified is not None
        assert verified["sub"] == str(user_id)
        assert mock_client.get.call_count == 1

        # Second verification with same kid - should hit cache without calling get()
        verified_cached = await verify_supabase_jwt(token)
        assert verified_cached is not None
        assert verified_cached["sub"] == str(user_id)
        assert mock_client.get.call_count == 1


@pytest.mark.asyncio
async def test_asymmetric_es256_verification():
    """Test ES256 token verification with EC P-256 key and mocked JWKS."""
    ec_key = ec.generate_private_key(ec.SECP256R1())
    kid = "ec-test-kid-1"
    jwk_dict = _ec_to_jwk(ec_key, kid=kid)
    jwks_response = {"keys": [jwk_dict]}

    user_id = uuid.uuid4()
    now = int(time.time())
    payload = {
        "sub": str(user_id),
        "iss": settings.SUPABASE_JWT_ISSUER,
        "aud": settings.SUPABASE_JWT_AUDIENCE,
        "exp": now + 3600,
    }
    token = jwt.encode(
        payload,
        key=ec_key,
        algorithm="ES256",
        headers={"kid": kid, "alg": "ES256", "typ": "JWT"},
    )

    manager = AsyncSupabaseJWKManager(cache_ttl=300, cooldown_seconds=0)
    mock_response = httpx.Response(200, json=jwks_response, request=httpx.Request("GET", "https://mock"))
    mock_client = AsyncMock()
    mock_client.get = AsyncMock(return_value=mock_response)
    mock_client.is_closed = False

    with patch.object(manager, "get_client", AsyncMock(return_value=mock_client)), \
         patch("app.core.security.jwk_manager", manager), \
         patch.object(settings, "SUPABASE_JWT_ALGORITHM", "ES256"):

        verified = await verify_supabase_jwt(token)
        assert verified is not None
        assert verified["sub"] == str(user_id)


@pytest.mark.asyncio
async def test_asymmetric_key_rotation():
    """Test that an unknown kid triggers a refresh and succeeds when new key is published."""
    rsa_key1 = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    rsa_key2 = rsa.generate_private_key(public_exponent=65537, key_size=2048)

    kid1 = "rsa-kid-1"
    kid2 = "rsa-kid-2"

    jwk1 = _rsa_to_jwk(rsa_key1, kid=kid1)
    jwk2 = _rsa_to_jwk(rsa_key2, kid=kid2)

    manager = AsyncSupabaseJWKManager(cache_ttl=300, cooldown_seconds=0)

    # Initial response only has kid1
    resp1 = httpx.Response(200, json={"keys": [jwk1]}, request=httpx.Request("GET", "https://mock"))
    # Rotated response has both kid1 and kid2
    resp2 = httpx.Response(200, json={"keys": [jwk1, jwk2]}, request=httpx.Request("GET", "https://mock"))

    mock_client = AsyncMock()
    mock_client.get = AsyncMock(side_effect=[resp1, resp2])
    mock_client.is_closed = False

    user_id = uuid.uuid4()
    now = int(time.time())
    token_kid1 = jwt.encode(
        {"sub": str(user_id), "iss": settings.SUPABASE_JWT_ISSUER, "aud": settings.SUPABASE_JWT_AUDIENCE, "exp": now + 3600},
        key=rsa_key1,
        algorithm="RS256",
        headers={"kid": kid1, "alg": "RS256", "typ": "JWT"},
    )
    token_kid2 = jwt.encode(
        {"sub": str(user_id), "iss": settings.SUPABASE_JWT_ISSUER, "aud": settings.SUPABASE_JWT_AUDIENCE, "exp": now + 3600},
        key=rsa_key2,
        algorithm="RS256",
        headers={"kid": kid2, "alg": "RS256", "typ": "JWT"},
    )

    with patch.object(manager, "get_client", AsyncMock(return_value=mock_client)), \
         patch("app.core.security.jwk_manager", manager), \
         patch.object(settings, "SUPABASE_JWT_ALGORITHM", "RS256"):

        # 1. First verification with kid1 populates cache from resp1
        verified_1 = await verify_supabase_jwt(token_kid1)
        assert verified_1 is not None
        assert mock_client.get.call_count == 1

        # 2. Verification with new kid2 detects missing key in cache, refreshes from resp2, and succeeds
        verified_2 = await verify_supabase_jwt(token_kid2)
        assert verified_2 is not None
        assert verified_2["sub"] == str(user_id)
        assert mock_client.get.call_count == 2


@pytest.mark.asyncio
async def test_reject_incompatible_jwk_parameters():
    """Reject JWKs with wrong kty, wrong crv, or non-signature use."""
    manager = AsyncSupabaseJWKManager()

    # 1. EC key rejected when RS256 is expected
    ec_key = ec.generate_private_key(ec.SECP256R1())
    ec_jwk = jwt.PyJWK(_ec_to_jwk(ec_key, kid="ec-kid"))
    assert not manager._validate_jwk(ec_jwk, expected_alg="RS256")

    # 2. RSA key rejected when ES256 is expected
    rsa_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    rsa_jwk = jwt.PyJWK(_rsa_to_jwk(rsa_key, kid="rsa-kid"))
    assert not manager._validate_jwk(rsa_jwk, expected_alg="ES256")

    # 3. Non-signature use (use="enc") rejected
    enc_jwk_dict = _rsa_to_jwk(rsa_key, kid="enc-kid")
    enc_jwk_dict["use"] = "enc"
    bad_use_jwk = jwt.PyJWK(enc_jwk_dict)
    assert not manager._validate_jwk(bad_use_jwk, expected_alg="RS256")

    # 4. Explicit algorithm mismatch rejected
    bad_alg_dict = _rsa_to_jwk(rsa_key, kid="alg-kid")
    bad_alg_dict["alg"] = "RS512"
    bad_alg_jwk = jwt.PyJWK(bad_alg_dict, algorithm="RS512")
    assert not manager._validate_jwk(bad_alg_jwk, expected_alg="RS256")


@pytest.mark.asyncio
async def test_jwks_network_outage_fails_safely():
    """Network failure or timeout during JWKS fetch fails safely and returns None."""
    rsa_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    manager = AsyncSupabaseJWKManager(cooldown_seconds=0)
    mock_client = AsyncMock()
    mock_client.get = AsyncMock(side_effect=httpx.ConnectTimeout("Connection timed out"))
    mock_client.is_closed = False

    with patch.object(manager, "get_client", AsyncMock(return_value=mock_client)), \
         patch("app.core.security.jwk_manager", manager), \
         patch.object(settings, "SUPABASE_JWT_ALGORITHM", "RS256"):

        token = jwt.encode(
            {"sub": str(uuid.uuid4()), "iss": settings.SUPABASE_JWT_ISSUER, "aud": settings.SUPABASE_JWT_AUDIENCE, "exp": int(time.time()) + 3600},
            key=rsa_key,
            algorithm="RS256",
            headers={"kid": "some-kid", "alg": "RS256"},
        )
        verified = await verify_supabase_jwt(token)
        assert verified is None


def test_production_jwt_configuration_validation():
    """Verify production startup validation checks."""
    from app.core.config import Settings

    # Production with valid HTTPS and RS256
    prod_valid_rs = Settings(
        APP_ENV="production",
        SUPABASE_URL="https://prod-project.supabase.co",
        SUPABASE_JWT_ALGORITHM="RS256",
    )
    prod_valid_rs.validate_production_jwt_config()  # Should not raise

    # Production with valid HTTPS and strong HS256 secret
    prod_valid_hs = Settings(
        APP_ENV="production",
        SUPABASE_URL="https://prod-project.supabase.co",
        SUPABASE_JWT_ALGORITHM="HS256",
        SUPABASE_JWT_SECRET="a" * 32,
    )
    prod_valid_hs.validate_production_jwt_config()  # Should not raise

    # Production with placeholder URL
    prod_placeholder_url = Settings(
        APP_ENV="production",
        SUPABASE_URL="https://your-project.supabase.co",
        SUPABASE_JWT_ALGORITHM="RS256",
    )
    with pytest.raises(ValueError, match="valid HTTPS SUPABASE_URL"):
        prod_placeholder_url.validate_production_jwt_config()

    # Production with unconfigured / invalid algorithm
    prod_invalid_alg = Settings(
        APP_ENV="production",
        SUPABASE_URL="https://prod-project.supabase.co",
        SUPABASE_JWT_ALGORITHM="NONE",
    )
    with pytest.raises(ValueError, match="Production requires SUPABASE_JWT_ALGORITHM to be explicitly set"):
        prod_invalid_alg.validate_production_jwt_config()

    # Production with missing algorithm fails startup
    prod_missing_alg = Settings(
        APP_ENV="production",
        SUPABASE_URL="https://prod-project.supabase.co",
        SUPABASE_JWT_ALGORITHM=None,
    )
    with pytest.raises(ValueError, match="Production requires SUPABASE_JWT_ALGORITHM to be explicitly configured"):
        prod_missing_alg.validate_production_jwt_config()

    # Production with blank algorithm fails startup
    prod_blank_alg = Settings(
        APP_ENV="production",
        SUPABASE_URL="https://prod-project.supabase.co",
        SUPABASE_JWT_ALGORITHM="   ",
    )
    with pytest.raises(ValueError, match="Production requires SUPABASE_JWT_ALGORITHM to be explicitly configured"):
        prod_blank_alg.validate_production_jwt_config()

    # Production with explicitly configured ES256 succeeds and normalizes
    prod_valid_es = Settings(
        APP_ENV="production",
        SUPABASE_URL="https://prod-project.supabase.co",
        SUPABASE_JWT_ALGORITHM="es256",
    )
    prod_valid_es.validate_production_jwt_config()
    assert prod_valid_es.effective_jwt_algorithm == "ES256"

    # Local environment falls back to HS256 when unconfigured
    local_default = Settings(
        APP_ENV="local",
        SUPABASE_JWT_ALGORITHM=None,
    )
    assert local_default.effective_jwt_algorithm == "HS256"

    # Unsupported algorithm fails in local environment
    local_unsupported = Settings(
        APP_ENV="local",
        SUPABASE_JWT_ALGORITHM="NONE",
    )
    with pytest.raises(ValueError, match="Unsupported JWT algorithm 'NONE'"):
        _ = local_unsupported.effective_jwt_algorithm

    # Production with default weak HS256 secret
    prod_weak_hs = Settings(
        APP_ENV="production",
        SUPABASE_URL="https://prod-project.supabase.co",
        SUPABASE_JWT_ALGORITHM="HS256",
        SUPABASE_JWT_SECRET="cineconnect_supabase_jwt_secret_change_me",
    )
    with pytest.raises(ValueError, match="secure SUPABASE_JWT_SECRET"):
        prod_weak_hs.validate_production_jwt_config()


@pytest.mark.asyncio
async def test_jwk_key_ops_validation():
    """Verify JWK key_ops parameter compliance with RFC 7517 Section 4.3."""
    manager = AsyncSupabaseJWKManager()
    rsa_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)

    # 1. Missing key_ops is accepted
    jwk_missing_ops = _rsa_to_jwk(rsa_key, kid="ops-missing")
    assert "key_ops" not in jwk_missing_ops
    pyjwk_missing = jwt.PyJWK(jwk_missing_ops)
    assert manager._validate_jwk(pyjwk_missing, expected_alg="RS256")

    # 2. ["verify"] is accepted
    jwk_verify = _rsa_to_jwk(rsa_key, kid="ops-verify")
    jwk_verify["key_ops"] = ["verify"]
    pyjwk_verify = jwt.PyJWK(jwk_verify)
    assert manager._validate_jwk(pyjwk_verify, expected_alg="RS256")

    # 3. ["verify", "wrapKey"] is accepted
    jwk_multi_valid = _rsa_to_jwk(rsa_key, kid="ops-multi")
    jwk_multi_valid["key_ops"] = ["verify", "wrapKey"]
    pyjwk_multi = jwt.PyJWK(jwk_multi_valid)
    assert manager._validate_jwk(pyjwk_multi, expected_alg="RS256")

    # 4. ["encrypt"] without "verify" is rejected
    jwk_encrypt = _rsa_to_jwk(rsa_key, kid="ops-encrypt")
    jwk_encrypt["key_ops"] = ["encrypt"]
    pyjwk_encrypt = jwt.PyJWK(jwk_encrypt)
    assert not manager._validate_jwk(pyjwk_encrypt, expected_alg="RS256")

    # 5. ["sign"] without "verify" is rejected
    jwk_sign = _rsa_to_jwk(rsa_key, kid="ops-sign")
    jwk_sign["key_ops"] = ["sign"]
    pyjwk_sign = jwt.PyJWK(jwk_sign)
    assert not manager._validate_jwk(pyjwk_sign, expected_alg="RS256")

    # 6. Empty list [] is rejected
    jwk_empty = _rsa_to_jwk(rsa_key, kid="ops-empty")
    jwk_empty["key_ops"] = []
    pyjwk_empty = jwt.PyJWK(jwk_empty)
    assert not manager._validate_jwk(pyjwk_empty, expected_alg="RS256")

    # 7. Non-list key_ops (string) is rejected
    jwk_non_list = _rsa_to_jwk(rsa_key, kid="ops-non-list")
    jwk_non_list["key_ops"] = "verify"
    pyjwk_non_list = jwt.PyJWK(jwk_non_list)
    assert not manager._validate_jwk(pyjwk_non_list, expected_alg="RS256")

    # 8. List with non-string elements is rejected
    jwk_non_string = _rsa_to_jwk(rsa_key, kid="ops-non-string")
    jwk_non_string["key_ops"] = [123]
    pyjwk_non_string = jwt.PyJWK(jwk_non_string)
    assert not manager._validate_jwk(pyjwk_non_string, expected_alg="RS256")

    # 9. Duplicate operations are rejected
    jwk_duplicate = _rsa_to_jwk(rsa_key, kid="ops-duplicate")
    jwk_duplicate["key_ops"] = ["verify", "verify"]
    pyjwk_duplicate = jwt.PyJWK(jwk_duplicate)
    assert not manager._validate_jwk(pyjwk_duplicate, expected_alg="RS256")
