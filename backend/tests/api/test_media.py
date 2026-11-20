"""Media Domain Integration Tests.

Validates S3/MinIO presigned upload URL generation, MIME-type enforcement,
file-size boundaries, filename sanitization, signature parameters, and
authentication requirements.
"""
from uuid import UUID
import pytest
import httpx
from httpx import AsyncClient
from botocore.exceptions import ClientError

from app.main import app
from app.core.config import settings
from app.services.storage import (
    init_storage_buckets,
    get_internal_s3_client,
    generate_presigned_download_url,
    parse_storage_url,
    extract_file_key,
    is_minio_public_url,
)


# ==============================================================================
# Route Registration & Smoke
# ==============================================================================

def test_media_routes_registered():
    """Verifies media endpoints are mounted on the FastAPI application."""
    routes = [getattr(r, "path", "") for r in app.routes]
    assert any("/api/v1/media/upload-url" in r for r in routes)


# ==============================================================================
# Presigned URL Generation for Permitted Types
# ==============================================================================

@pytest.mark.parametrize(
    "file_name,content_type",
    [
        ("headshot.jpg", "image/jpeg"),
        ("portrait.png", "image/png"),
        ("backdrop.webp", "image/webp"),
        ("audition_tape.mp4", "video/mp4"),
        ("scene_clip.webm", "video/webm"),
        ("voice_over.mp3", "audio/mpeg"),
        ("soundtrack.wav", "audio/wav"),
        ("actor_resume.pdf", "application/pdf"),
    ],
)
@pytest.mark.asyncio
async def test_media_upload_url_permitted_types(
    async_client: AsyncClient,
    talent_headers: dict,
    talent_user_id: UUID,
    file_name: str,
    content_type: str,
):
    """Verifies presigned upload URL generation for images, videos, audio, and PDFs."""
    payload = {
        "file_name": file_name,
        "content_type": content_type,
        "file_size_bytes": 1024 * 500,  # 500 KB
    }
    response = await async_client.post(
        "/api/v1/media/upload-url",
        headers=talent_headers,
        json=payload,
    )
    assert response.status_code == 200
    data = response.json()

    assert "upload_url" in data
    assert "public_url" in data
    assert "file_key" in data
    assert data["expires_in_seconds"] == 3600

    # Verify key structure: media/{user_id}/{uuid}/{clean_name}
    key_parts = data["file_key"].split("/")
    assert key_parts[0] == "media"
    assert key_parts[1] == str(talent_user_id)
    assert key_parts[3] == file_name

    # Verify AWS SigV4 presigned URL components
    upload_url = data["upload_url"]
    assert "X-Amz-Algorithm=AWS4-HMAC-SHA256" in upload_url
    assert "X-Amz-Credential=" in upload_url
    assert "X-Amz-Signature=" in upload_url
    assert "X-Amz-Expires=3600" in upload_url
    assert "X-Amz-SignedHeaders=" in upload_url


@pytest.mark.asyncio
async def test_media_upload_url_filename_sanitization(
    async_client: AsyncClient,
    talent_headers: dict,
):
    """Verifies spaces in filenames are sanitized to underscores."""
    payload = {
        "file_name": "my audition reel final cut 2026.mp4",
        "content_type": "video/mp4",
        "file_size_bytes": 1024 * 1024 * 10,
    }
    response = await async_client.post(
        "/api/v1/media/upload-url",
        headers=talent_headers,
        json=payload,
    )
    assert response.status_code == 200
    file_key = response.json()["file_key"]
    assert " " not in file_key
    assert "my_audition_reel_final_cut_2026.mp4" in file_key


# ==============================================================================
# Validation & Error Handling
# ==============================================================================

@pytest.mark.parametrize(
    "forbidden_mime",
    [
        "application/x-msdownload",
        "text/plain",
        "text/html",
        "application/zip",
        "application/javascript",
        "application/octet-stream",
    ],
)
@pytest.mark.asyncio
async def test_media_upload_url_disallowed_mime_rejected(
    async_client: AsyncClient,
    talent_headers: dict,
    forbidden_mime: str,
):
    """Verifies that non-whitelisted MIME types are rejected with 400 Bad Request."""
    payload = {
        "file_name": "payload.bin",
        "content_type": forbidden_mime,
        "file_size_bytes": 1024,
    }
    response = await async_client.post(
        "/api/v1/media/upload-url",
        headers=talent_headers,
        json=payload,
    )
    assert response.status_code == 400
    detail = response.json().get("detail", "")
    assert "not permitted" in detail


@pytest.mark.asyncio
async def test_media_upload_url_max_file_size_exceeded(
    async_client: AsyncClient,
    talent_headers: dict,
):
    """Verifies that files exceeding 100 MB (104,857,600 bytes) are rejected with 400."""
    oversized_bytes = 101 * 1024 * 1024  # 101 MB
    payload = {
        "file_name": "huge_film.mov",
        "content_type": "video/mp4",
        "file_size_bytes": oversized_bytes,
    }
    response = await async_client.post(
        "/api/v1/media/upload-url",
        headers=talent_headers,
        json=payload,
    )
    assert response.status_code == 400
    assert "exceeds maximum allowed limit" in response.json().get("detail", "")


@pytest.mark.asyncio
async def test_media_upload_url_max_file_size_boundary_accepted(
    async_client: AsyncClient,
    talent_headers: dict,
):
    """Verifies that a file exactly at the 100 MB limit is accepted."""
    exact_limit_bytes = 100 * 1024 * 1024  # exactly 100 MB
    payload = {
        "file_name": "boundary_reel.mp4",
        "content_type": "video/mp4",
        "file_size_bytes": exact_limit_bytes,
    }
    response = await async_client.post(
        "/api/v1/media/upload-url",
        headers=talent_headers,
        json=payload,
    )
    assert response.status_code == 200


@pytest.mark.asyncio
async def test_media_upload_url_missing_required_fields(
    async_client: AsyncClient,
    talent_headers: dict,
):
    """Verifies 422 validation error when required fields are missing."""
    # Missing content_type
    res1 = await async_client.post(
        "/api/v1/media/upload-url",
        headers=talent_headers,
        json={"file_name": "test.jpg"},
    )
    assert res1.status_code == 422

    # Missing file_name
    res2 = await async_client.post(
        "/api/v1/media/upload-url",
        headers=talent_headers,
        json={"content_type": "image/jpeg"},
    )
    assert res2.status_code == 422


# ==============================================================================
# Authentication & Role Matrix
# ==============================================================================

@pytest.mark.asyncio
async def test_media_upload_url_unauthenticated_rejected(async_client: AsyncClient):
    """Verifies that unauthenticated upload URL requests are rejected (401 or 403)."""
    payload = {
        "file_name": "unauthorized.jpg",
        "content_type": "image/jpeg",
    }
    response = await async_client.post("/api/v1/media/upload-url", json=payload)
    assert response.status_code in (401, 403)


@pytest.mark.asyncio
async def test_media_upload_url_expired_token_rejected(
    async_client: AsyncClient,
    expired_headers: dict,
):
    """Verifies that expired tokens are rejected with 401 Unauthorized."""
    payload = {
        "file_name": "expired.jpg",
        "content_type": "image/jpeg",
    }
    response = await async_client.post(
        "/api/v1/media/upload-url",
        headers=expired_headers,
        json=payload,
    )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_media_upload_url_invalid_token_rejected(
    async_client: AsyncClient,
    invalid_headers: dict,
):
    """Verifies that malformed tokens are rejected with 401 Unauthorized."""
    payload = {
        "file_name": "invalid.jpg",
        "content_type": "image/jpeg",
    }
    response = await async_client.post(
        "/api/v1/media/upload-url",
        headers=invalid_headers,
        json=payload,
    )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_media_upload_url_production_house_allowed(
    async_client: AsyncClient,
    ph_headers: dict,
    ph_user_id: UUID,
):
    """Verifies that Production House accounts can also request presigned upload URLs."""
    payload = {
        "file_name": "studio_banner.png",
        "content_type": "image/png",
    }
    response = await async_client.post(
        "/api/v1/media/upload-url",
        headers=ph_headers,
        json=payload,
    )
    assert response.status_code == 200
    assert str(ph_user_id) in response.json()["file_key"]


# ==============================================================================
# Group 2: AWS SigV4, Bucket Segregation & Live MinIO Upload Verification
# ==============================================================================

@pytest.mark.asyncio
async def test_media_upload_url_sigv4_structure(
    async_client: AsyncClient,
    talent_headers: dict,
):
    """Verifies that the generated presigned upload URL contains complete AWS SigV4 query parameters."""
    payload = {
        "file_name": "cinematography_reel.mp4",
        "content_type": "video/mp4",
        "file_size_bytes": 1024 * 1024 * 5,
    }
    response = await async_client.post(
        "/api/v1/media/upload-url",
        headers=talent_headers,
        json=payload,
    )
    assert response.status_code == 200
    data = response.json()
    upload_url = data["upload_url"]

    # SigV4 mandatory components
    assert "X-Amz-Algorithm=AWS4-HMAC-SHA256" in upload_url
    assert "X-Amz-Credential=" in upload_url
    assert "X-Amz-Date=" in upload_url
    assert "X-Amz-Expires=3600" in upload_url
    assert "X-Amz-SignedHeaders=" in upload_url
    assert "X-Amz-Signature=" in upload_url

    # Signed headers must include content-type and host
    assert "content-type" in upload_url
    assert "host" in upload_url

    # Key and bucket validation
    assert settings.MINIO_PUBLIC_BUCKET in upload_url
    assert "cinematography_reel.mp4" in data["file_key"]


@pytest.mark.asyncio
async def test_media_endpoint_separation_and_config():
    """Verifies internal and public storage endpoint configuration properties."""
    assert settings.internal_storage_endpoint.startswith(("http://", "https://"))
    assert settings.public_storage_endpoint.startswith(("http://", "https://"))
    assert settings.MINIO_PUBLIC_BUCKET == "cineconnect-public"
    assert settings.MINIO_PRIVATE_BUCKET == "cineconnect-private"
    assert settings.MINIO_BUCKET in ("cineconnect-public", "cineconnect-media")


@pytest.mark.asyncio
async def test_media_android_emulator_endpoint_configuration_and_presigned_url(
    async_client: AsyncClient,
    talent_headers: dict,
):
    """Verifies that when MINIO_PUBLIC_ENDPOINT is configured for the Android emulator
    (http://10.0.2.2:9000), presigned upload and download URLs are generated using that
    reachable address with authentic AWS SigV4 signatures matching that host.
    """
    from unittest.mock import patch
    from app.services.storage import generate_presigned_upload_url, generate_presigned_download_url

    with patch.object(settings, "MINIO_PUBLIC_ENDPOINT", "http://10.0.2.2:9000"):
        assert settings.public_storage_endpoint == "http://10.0.2.2:9000"

        # 1. Generate presigned upload URL
        res = generate_presigned_upload_url(
            file_name="emulator_test.jpg",
            content_type="image/jpeg",
            user_id="00000000-0000-0000-0000-000000000001",
            purpose="public",
        )
        upload_url = res["upload_url"]
        assert "http://10.0.2.2:9000/" in upload_url
        assert res["public_url"].startswith("http://10.0.2.2:9000/")
        assert "X-Amz-Signature=" in upload_url

        # 2. Generate presigned download URL
        dl_url = generate_presigned_download_url(
            bucket_name=settings.MINIO_PUBLIC_BUCKET,
            file_key=res["file_key"],
        )
        assert "http://10.0.2.2:9000/" in dl_url
        assert "X-Amz-Signature=" in dl_url


@pytest.mark.asyncio
async def test_storage_bucket_initialization_idempotent():
    """Verifies that bucket initialization creates buckets and is fully idempotent."""
    status1 = init_storage_buckets()
    assert status1.get(settings.MINIO_PUBLIC_BUCKET) is True
    assert status1.get(settings.MINIO_PRIVATE_BUCKET) is True

    # Repeated initialization must not fail
    status2 = init_storage_buckets()
    assert status2.get(settings.MINIO_PUBLIC_BUCKET) is True
    assert status2.get(settings.MINIO_PRIVATE_BUCKET) is True


@pytest.mark.asyncio
async def test_storage_private_bucket_remains_private():
    """Verifies that the private bucket does not have a public-read policy attached."""
    init_storage_buckets()
    s3 = get_internal_s3_client()

    # Public bucket should have a policy
    try:
        pub_pol = s3.get_bucket_policy(Bucket=settings.MINIO_PUBLIC_BUCKET)
        assert "PublicReadOnly" in pub_pol["Policy"]
    except ClientError as e:
        pytest.fail(f"Public bucket should have public policy: {e}")

    # Private bucket should NOT have a policy
    try:
        s3.get_bucket_policy(Bucket=settings.MINIO_PRIVATE_BUCKET)
        pytest.fail("Private bucket must NOT have a bucket policy attached")
    except ClientError as e:
        assert e.response.get("Error", {}).get("Code") in ("NoSuchBucketPolicy", "404")


@pytest.mark.asyncio
async def test_media_real_minio_upload_and_retrieval(
    async_client: AsyncClient,
    talent_headers: dict,
):
    """End-to-end integration test: Generates SigV4 URL, performs real HTTP PUT to MinIO, and retrieves object."""
    # 1. Request presigned upload URL from backend
    payload = {
        "file_name": "real_integration_test_headshot.png",
        "content_type": "image/png",
        "file_size_bytes": 1024 * 10,
    }
    response = await async_client.post(
        "/api/v1/media/upload-url",
        headers=talent_headers,
        json=payload,
    )
    assert response.status_code == 200
    data = response.json()
    upload_url = data["upload_url"]
    file_key = data["file_key"]

    # 2. Perform real HTTP PUT upload to MinIO using the presigned URL
    test_content = b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00CineConnectTestImageData"
    async with httpx.AsyncClient() as http_client:
        put_resp = await http_client.put(
            upload_url,
            content=test_content,
            headers={"Content-Type": "image/png"},
        )
        assert put_resp.status_code == 200, f"MinIO PUT failed: {put_resp.status_code} {put_resp.text}"

    # 3. Verify object exists and content matches via internal S3 client
    s3 = get_internal_s3_client()
    obj = s3.get_object(Bucket=settings.MINIO_PUBLIC_BUCKET, Key=file_key)
    retrieved_data = obj["Body"].read()
    assert retrieved_data == test_content, "Retrieved content from MinIO does not match uploaded payload"

    # 4. Clean up test object
    s3.delete_object(Bucket=settings.MINIO_PUBLIC_BUCKET, Key=file_key)


# ==============================================================================
# Group 3A: Dual-Bucket Upload Routing & Presigned Download URL Tests
# ==============================================================================

@pytest.mark.asyncio
async def test_media_upload_url_default_purpose_is_public(
    async_client: AsyncClient,
    talent_headers: dict,
):
    """Verifies that omitting 'purpose' defaults to 'public' and targets cineconnect-public."""
    payload = {
        "file_name": "default_purpose_banner.jpg",
        "content_type": "image/jpeg",
        "file_size_bytes": 1024 * 100,
    }
    response = await async_client.post(
        "/api/v1/media/upload-url",
        headers=talent_headers,
        json=payload,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["purpose"] == "public"
    assert data["bucket"] == settings.MINIO_PUBLIC_BUCKET
    assert settings.MINIO_PUBLIC_BUCKET in data["upload_url"]
    assert settings.MINIO_PRIVATE_BUCKET not in data["upload_url"]


@pytest.mark.asyncio
async def test_media_upload_url_explicit_public_purpose(
    async_client: AsyncClient,
    talent_headers: dict,
):
    """Verifies that purpose='public' explicitly targets cineconnect-public."""
    payload = {
        "file_name": "public_headshot.png",
        "content_type": "image/png",
        "purpose": "public",
        "file_size_bytes": 1024 * 50,
    }
    response = await async_client.post(
        "/api/v1/media/upload-url",
        headers=talent_headers,
        json=payload,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["purpose"] == "public"
    assert data["bucket"] == settings.MINIO_PUBLIC_BUCKET
    assert settings.MINIO_PUBLIC_BUCKET in data["upload_url"]


@pytest.mark.asyncio
async def test_media_upload_url_explicit_private_purpose(
    async_client: AsyncClient,
    talent_headers: dict,
):
    """Verifies that purpose='private' explicitly targets cineconnect-private."""
    payload = {
        "file_name": "confidential_actor_contract.pdf",
        "content_type": "application/pdf",
        "purpose": "private",
        "file_size_bytes": 1024 * 200,
    }
    response = await async_client.post(
        "/api/v1/media/upload-url",
        headers=talent_headers,
        json=payload,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["purpose"] == "private"
    assert data["bucket"] == settings.MINIO_PRIVATE_BUCKET
    assert settings.MINIO_PRIVATE_BUCKET in data["upload_url"]
    assert settings.MINIO_PUBLIC_BUCKET not in data["upload_url"]
    # Verify client-reachable endpoint is used
    assert data["upload_url"].startswith(settings.public_storage_endpoint)


@pytest.mark.asyncio
async def test_media_upload_url_unsupported_purpose_rejected(
    async_client: AsyncClient,
    talent_headers: dict,
):
    """Verifies that invalid/unsupported purpose values are rejected with 422 Unprocessable Entity."""
    payload = {
        "file_name": "resume.pdf",
        "content_type": "application/pdf",
        "purpose": "classified_internal",
    }
    response = await async_client.post(
        "/api/v1/media/upload-url",
        headers=talent_headers,
        json=payload,
    )
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_media_upload_url_arbitrary_bucket_injection_rejected(
    async_client: AsyncClient,
    talent_headers: dict,
):
    """Verifies that clients cannot supply arbitrary bucket names (forbidden extra field -> 422)."""
    payload = {
        "file_name": "malicious.jpg",
        "content_type": "image/jpeg",
        "bucket": "attacker-controlled-bucket",
    }
    response = await async_client.post(
        "/api/v1/media/upload-url",
        headers=talent_headers,
        json=payload,
    )
    assert response.status_code == 422


def test_presigned_download_url_generation():
    """Verifies presigned download URL generation for both public and private buckets."""
    file_key = "media/test-user/sample.pdf"

    # 1. Download URL for public bucket
    pub_url = generate_presigned_download_url(
        bucket_name=settings.MINIO_PUBLIC_BUCKET,
        file_key=file_key,
        expires_in=1800,
    )
    assert pub_url.startswith(settings.public_storage_endpoint)
    assert settings.MINIO_PUBLIC_BUCKET in pub_url
    assert file_key in pub_url
    assert "X-Amz-Algorithm=AWS4-HMAC-SHA256" in pub_url
    assert "X-Amz-Signature=" in pub_url
    assert "X-Amz-Expires=1800" in pub_url

    # 2. Download URL for private bucket
    priv_url = generate_presigned_download_url(
        bucket_name=settings.MINIO_PRIVATE_BUCKET,
        file_key=file_key,
        expires_in=3600,
    )
    assert priv_url.startswith(settings.public_storage_endpoint)
    assert settings.MINIO_PRIVATE_BUCKET in priv_url
    assert file_key in priv_url
    assert "X-Amz-Algorithm=AWS4-HMAC-SHA256" in priv_url
    assert "X-Amz-Signature=" in priv_url
    assert "X-Amz-Expires=3600" in priv_url


def test_presigned_download_url_validation_rejections():
    """Verifies input validation boundaries for generate_presigned_download_url."""
    # Invalid bucket
    with pytest.raises(ValueError, match="not an authorized CineConnect bucket"):
        generate_presigned_download_url(bucket_name="nonexistent-bucket", file_key="file.jpg")

    # Empty file key
    with pytest.raises(ValueError, match="File key cannot be empty"):
        generate_presigned_download_url(bucket_name=settings.MINIO_PUBLIC_BUCKET, file_key="")

    with pytest.raises(ValueError, match="File key cannot be empty"):
        generate_presigned_download_url(bucket_name=settings.MINIO_PUBLIC_BUCKET, file_key="   ")

    # Invalid expiration
    with pytest.raises(ValueError, match="expires_in must be a positive integer"):
        generate_presigned_download_url(
            bucket_name=settings.MINIO_PRIVATE_BUCKET,
            file_key="file.jpg",
            expires_in=0,
        )

    with pytest.raises(ValueError, match="expires_in must be a positive integer"):
        generate_presigned_download_url(
            bucket_name=settings.MINIO_PRIVATE_BUCKET,
            file_key="file.jpg",
            expires_in=-50,
        )

    with pytest.raises(ValueError, match="expires_in must be a positive integer"):
        generate_presigned_download_url(
            bucket_name=settings.MINIO_PRIVATE_BUCKET,
            file_key="file.jpg",
            expires_in=700000,  # exceeds 7 days (604800)
        )


@pytest.mark.asyncio
async def test_live_minio_private_bucket_upload_and_presigned_download(
    async_client: AsyncClient,
    talent_headers: dict,
):
    """Live MinIO integration test for private bucket upload and presigned GET download."""
    init_storage_buckets()

    # 1. Generate private upload URL
    payload = {
        "file_name": "private_audition_reel.mp4",
        "content_type": "video/mp4",
        "purpose": "private",
        "file_size_bytes": 1024 * 8,
    }
    response = await async_client.post(
        "/api/v1/media/upload-url",
        headers=talent_headers,
        json=payload,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["bucket"] == settings.MINIO_PRIVATE_BUCKET
    assert data["purpose"] == "private"
    upload_url = data["upload_url"]
    file_key = data["file_key"]
    public_url = data["public_url"]

    # 2. Upload binary payload to private bucket via presigned PUT URL
    video_payload = b"\x00\x00\x00 ftypmp42\x00\x00\x00\x00CineConnectPrivateReelBytes"
    async with httpx.AsyncClient() as http_client:
        put_resp = await http_client.put(
            upload_url,
            content=video_payload,
            headers={"Content-Type": "video/mp4"},
        )
        assert put_resp.status_code == 200, f"Private PUT upload failed: {put_resp.status_code} {put_resp.text}"

    # 3. Verify that direct anonymous GET to the object fails with 403 Forbidden
    async with httpx.AsyncClient() as http_client:
        anon_resp = await http_client.get(public_url)
        assert anon_resp.status_code in (403, 404), (
            f"Private object was accessible anonymously! Expected 403/404, got {anon_resp.status_code}"
        )

    # 4. Generate presigned GET download URL
    download_url = generate_presigned_download_url(
        bucket_name=settings.MINIO_PRIVATE_BUCKET,
        file_key=file_key,
        expires_in=600,
    )

    # 5. Download using presigned URL (without credentials) -> should succeed with 200 OK
    async with httpx.AsyncClient() as http_client:
        get_resp = await http_client.get(download_url)
        assert get_resp.status_code == 200, f"Presigned download failed: {get_resp.status_code} {get_resp.text}"
        assert get_resp.content == video_payload, "Downloaded content does not match uploaded payload"

    # 6. Clean up object from private bucket
    s3 = get_internal_s3_client()
    s3.delete_object(Bucket=settings.MINIO_PRIVATE_BUCKET, Key=file_key)


# ==============================================================================
# Group 3B Final Hardening: Safe MinIO URL Detection & Verification (MED-01)
# ==============================================================================

def test_safe_minio_url_detection_cases():
    """Validates URL parsing and MinIO detection across all 8 security criteria:
    1. Valid public MinIO URL.
    2. Valid private MinIO URL.
    3. Valid relative object key.
    4. External URL containing /media/.
    5. External URL containing the configured MinIO hostname only in its path.
    6. External URL containing the configured hostname in its query string.
    7. Malformed URL.
    8. Public bucket detection.
    """
    uid = "00000000-0000-0000-0000-000000000001"
    key = f"media/{uid}/11111111-1111-1111-1111-111111111111/cv.pdf"
    pub_endpoint = settings.public_storage_endpoint.rstrip("/")

    # 1. Valid public MinIO URL
    valid_pub_url = f"{pub_endpoint}/{settings.MINIO_PUBLIC_BUCKET}/{key}"
    f_key, bucket, is_int = parse_storage_url(valid_pub_url)
    assert is_int is True
    assert f_key == key
    assert bucket == settings.MINIO_PUBLIC_BUCKET
    assert extract_file_key(valid_pub_url) == key
    assert is_minio_public_url(valid_pub_url) is True

    # 2. Valid private MinIO URL
    valid_priv_url = f"{pub_endpoint}/{settings.MINIO_PRIVATE_BUCKET}/{key}"
    f_key, bucket, is_int = parse_storage_url(valid_priv_url)
    assert is_int is True
    assert f_key == key
    assert bucket == settings.MINIO_PRIVATE_BUCKET
    assert extract_file_key(valid_priv_url) == key
    assert is_minio_public_url(valid_priv_url) is False

    # 3. Valid relative object key
    f_key, bucket, is_int = parse_storage_url(key)
    assert is_int is True
    assert f_key == key
    assert bucket is None
    assert extract_file_key(key) == key
    assert is_minio_public_url(key) is False

    # 4. External URL containing /media/
    ext_media_url = "https://vimeo.com/media/user123/audition_reel.mp4"
    f_key, bucket, is_int = parse_storage_url(ext_media_url)
    assert is_int is False
    assert f_key is None
    assert extract_file_key(ext_media_url) is None
    assert is_minio_public_url(ext_media_url) is False

    # 5. External URL containing the configured MinIO hostname only in its path
    ext_host_in_path = f"https://example-portfolio.com/{settings.MINIO_ENDPOINT}/media/test.pdf"
    f_key, bucket, is_int = parse_storage_url(ext_host_in_path)
    assert is_int is False
    assert f_key is None
    assert extract_file_key(ext_host_in_path) is None

    # 6. External URL containing the configured hostname in its query string
    ext_host_in_query = f"https://vimeo.com/12345?origin=http://{settings.MINIO_ENDPOINT}/media/cv.pdf"
    f_key, bucket, is_int = parse_storage_url(ext_host_in_query)
    assert is_int is False
    assert f_key is None
    assert extract_file_key(ext_host_in_query) is None

    # 7. Malformed URLs
    assert extract_file_key("http:///") is None
    assert extract_file_key("not a url at all :::") is None
    assert extract_file_key("") is None
    assert extract_file_key(None) is None

    # 8. Public bucket detection
    # External URL with cineconnect-public in path is NOT internal public bucket
    ext_with_bucket_name = f"https://external-cdn.com/{settings.MINIO_PUBLIC_BUCKET}/media/video.mp4"
    assert is_minio_public_url(ext_with_bucket_name) is False
    assert extract_file_key(ext_with_bucket_name) is None



