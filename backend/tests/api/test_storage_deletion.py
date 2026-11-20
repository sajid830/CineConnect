"""Tests for CineConnect MinIO Group 3C.1: Safe Object Deletion Service.

Verifies:
1. Successful deletion from configured public bucket.
2. Successful deletion from configured private bucket.
3. Invalid bucket rejection.
4. Empty object key rejection.
5. Malformed object key rejection.
6. Path traversal rejection.
7. External URL rejection.
8. MinIO connection failure handling.
9. Access-denied response handling.
10. MinIO deletion failure handling.
11. Internal URL with matching bucket deletion.
12. Internal URL with bucket mismatch rejection.
13. Live MinIO integration test with ephemeral temporary test objects.
"""
import uuid
from unittest.mock import MagicMock
import pytest
from botocore.exceptions import ClientError, EndpointConnectionError, BotoCoreError

from app.core.config import settings
from app.services.storage import (
    delete_storage_object,
    check_storage_object_exists,
    get_internal_s3_client,
    StorageValidationError,
    StorageConnectionError,
    StorageAccessDeniedError,
    StorageDeletionError,
)


# ==============================================================================
# Unit Tests with Mocked Boto3 S3 Client
# ==============================================================================

def test_delete_storage_object_public_bucket_success():
    """1. Successful deletion from configured public bucket."""
    mock_s3 = MagicMock()
    mock_s3.delete_object.return_value = {
        "ResponseMetadata": {"HTTPStatusCode": 204}
    }

    test_key = f"media/{uuid.uuid4()}/{uuid.uuid4()}/profile_photo.jpg"
    result = delete_storage_object(
        bucket_name=settings.MINIO_PUBLIC_BUCKET,
        file_key=test_key,
        s3_client=mock_s3,
    )

    assert result is True
    mock_s3.delete_object.assert_called_once_with(
        Bucket=settings.MINIO_PUBLIC_BUCKET,
        Key=test_key,
    )


def test_delete_storage_object_private_bucket_success():
    """2. Successful deletion from configured private bucket."""
    mock_s3 = MagicMock()
    mock_s3.delete_object.return_value = {
        "ResponseMetadata": {"HTTPStatusCode": 200}
    }

    test_key = f"media/{uuid.uuid4()}/{uuid.uuid4()}/confidential_resume.pdf"
    result = delete_storage_object(
        bucket_name=settings.MINIO_PRIVATE_BUCKET,
        file_key=test_key,
        s3_client=mock_s3,
    )

    assert result is True
    mock_s3.delete_object.assert_called_once_with(
        Bucket=settings.MINIO_PRIVATE_BUCKET,
        Key=test_key,
    )


def test_delete_storage_object_invalid_bucket_rejection():
    """3. Invalid bucket rejection."""
    mock_s3 = MagicMock()
    test_key = f"media/{uuid.uuid4()}/{uuid.uuid4()}/doc.pdf"

    for invalid_bucket in ["unauthorized-bucket", "aws-prod-bucket", "", None, "cineconnect-media-legacy"]:
        with pytest.raises(ValueError, match="not an authorized CineConnect bucket"):
            delete_storage_object(
                bucket_name=invalid_bucket,  # type: ignore
                file_key=test_key,
                s3_client=mock_s3,
            )

    assert mock_s3.delete_object.call_count == 0


def test_delete_storage_object_empty_key_rejection():
    """4. Empty object key rejection."""
    mock_s3 = MagicMock()

    for empty_key in ["", "   ", None, "\t\n"]:
        with pytest.raises(ValueError, match="Object key cannot be empty"):
            delete_storage_object(
                bucket_name=settings.MINIO_PUBLIC_BUCKET,
                file_key=empty_key,  # type: ignore
                s3_client=mock_s3,
            )

    assert mock_s3.delete_object.call_count == 0


def test_delete_storage_object_malformed_key_rejection():
    """5. Malformed object key rejection."""
    mock_s3 = MagicMock()

    malformed_keys = [
        "not_media/user/file.jpg",
        "media/",
        "media///file.jpg",
        "/media/user/uuid/file.jpg",
        "media/user/uuid/file.jpg/",
        "just_a_filename.mp4",
        "media",
        "media/user\x00file.jpg",  # Null byte
        "media/user\nfile.jpg",    # Control character
    ]

    for bad_key in malformed_keys:
        with pytest.raises(ValueError):
            delete_storage_object(
                bucket_name=settings.MINIO_PUBLIC_BUCKET,
                file_key=bad_key,
                s3_client=mock_s3,
            )

    assert mock_s3.delete_object.call_count == 0


def test_delete_storage_object_path_traversal_rejection():
    """6. Path traversal rejection."""
    mock_s3 = MagicMock()

    traversal_keys = [
        "../media/user/file.jpg",
        "media/../../etc/passwd",
        "media/user/../other_user/file.jpg",
        "media/user/./file.jpg",
        "media/..",
        "media/user/..\\file.jpg",
        "media/user/file.jpg?foo=../bar",
        "media%2e%2e/file.jpg",
        "media/%2e%2e/user/file.jpg",
        "media/%2f/file.jpg",
    ]

    for bad_key in traversal_keys:
        with pytest.raises(ValueError, match="path traversal"):
            delete_storage_object(
                bucket_name=settings.MINIO_PRIVATE_BUCKET,
                file_key=bad_key,
                s3_client=mock_s3,
            )

    assert mock_s3.delete_object.call_count == 0


def test_delete_storage_object_external_url_rejection():
    """7. External URL rejection."""
    mock_s3 = MagicMock()

    external_urls = [
        "https://vimeo.com/123456789",
        "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
        "https://example.com/media/user/file.mp4",
        "http://evil-attacker.com/cineconnect-public/media/u/f.jpg",
        # Spoofed host in path or query
        f"https://attacker.com/{settings.MINIO_ENDPOINT}/media/test.jpg",
        f"https://external-cdn.com/file.mp4?origin={settings.MINIO_PUBLIC_ENDPOINT}",
    ]

    for ext_url in external_urls:
        with pytest.raises(ValueError, match="Cannot delete external media URL"):
            delete_storage_object(
                bucket_name=settings.MINIO_PUBLIC_BUCKET,
                file_key=ext_url,
                s3_client=mock_s3,
            )

    assert mock_s3.delete_object.call_count == 0


def test_delete_storage_object_connection_failure():
    """8. MinIO connection failure handling."""
    mock_s3 = MagicMock()
    mock_s3.delete_object.side_effect = EndpointConnectionError(
        endpoint_url="http://minio:9000"
    )

    test_key = f"media/{uuid.uuid4()}/{uuid.uuid4()}/headshot.png"

    with pytest.raises(StorageConnectionError) as exc_info:
        delete_storage_object(
            bucket_name=settings.MINIO_PUBLIC_BUCKET,
            file_key=test_key,
            s3_client=mock_s3,
        )

    assert exc_info.value.status_code == 503
    assert "connection failed" in exc_info.value.detail.lower()


def test_delete_storage_object_access_denied():
    """9. Access-denied response handling."""
    mock_s3 = MagicMock()
    mock_s3.delete_object.side_effect = ClientError(
        {
            "Error": {
                "Code": "AccessDenied",
                "Message": "Access Denied by policy",
            }
        },
        "DeleteObject",
    )

    test_key = f"media/{uuid.uuid4()}/{uuid.uuid4()}/reel.mp4"

    with pytest.raises(StorageAccessDeniedError) as exc_info:
        delete_storage_object(
            bucket_name=settings.MINIO_PRIVATE_BUCKET,
            file_key=test_key,
            s3_client=mock_s3,
        )

    assert exc_info.value.status_code == 403
    assert "access denied" in exc_info.value.detail.lower()


def test_delete_storage_object_deletion_failure_status():
    """10. MinIO deletion failure handling (HTTP error status / client error)."""
    mock_s3 = MagicMock()
    # Scenario A: Unexpected HTTP status returned by storage
    mock_s3.delete_object.return_value = {
        "ResponseMetadata": {"HTTPStatusCode": 500}
    }

    test_key = f"media/{uuid.uuid4()}/{uuid.uuid4()}/photo.jpg"

    with pytest.raises(StorageDeletionError) as exc_info:
        delete_storage_object(
            bucket_name=settings.MINIO_PUBLIC_BUCKET,
            file_key=test_key,
            s3_client=mock_s3,
        )

    assert exc_info.value.status_code == 502
    assert "failed to delete" in exc_info.value.detail.lower()

    # Scenario B: MinIO internal client error
    mock_s3.delete_object.side_effect = ClientError(
        {
            "Error": {
                "Code": "InternalError",
                "Message": "We encountered an internal error. Please try again.",
            }
        },
        "DeleteObject",
    )

    with pytest.raises(StorageDeletionError) as exc_info2:
        delete_storage_object(
            bucket_name=settings.MINIO_PUBLIC_BUCKET,
            file_key=test_key,
            s3_client=mock_s3,
        )

    assert exc_info2.value.status_code == 502


def test_delete_storage_object_internal_url_parsing():
    """11. Internal URL handling: extracts key and deletes from matching bucket."""
    mock_s3 = MagicMock()
    mock_s3.delete_object.return_value = {
        "ResponseMetadata": {"HTTPStatusCode": 204}
    }

    raw_key = f"media/{uuid.uuid4()}/{uuid.uuid4()}/headshot.png"
    full_url = f"{settings.public_storage_endpoint}/{settings.MINIO_PUBLIC_BUCKET}/{raw_key}"

    result = delete_storage_object(
        bucket_name=settings.MINIO_PUBLIC_BUCKET,
        file_key=full_url,
        s3_client=mock_s3,
    )

    assert result is True
    mock_s3.delete_object.assert_called_once_with(
        Bucket=settings.MINIO_PUBLIC_BUCKET,
        Key=raw_key,
    )


def test_delete_storage_object_internal_url_bucket_mismatch():
    """12. Bucket mismatch between target bucket and bucket in URL is rejected."""
    mock_s3 = MagicMock()
    raw_key = f"media/{uuid.uuid4()}/{uuid.uuid4()}/resume.pdf"
    private_url = f"{settings.public_storage_endpoint}/{settings.MINIO_PRIVATE_BUCKET}/{raw_key}"

    with pytest.raises(ValueError, match="Bucket mismatch"):
        delete_storage_object(
            bucket_name=settings.MINIO_PUBLIC_BUCKET,  # Calling with public bucket
            file_key=private_url,                      # But URL targets private bucket
            s3_client=mock_s3,
        )

    assert mock_s3.delete_object.call_count == 0


# ==============================================================================
# Live MinIO Integration Test
# ==============================================================================

def test_live_minio_temporary_object_lifecycle():
    """13. Live MinIO Integration Test:
    - Creates a uniquely named temporary test object.
    - Confirms existence in MinIO.
    - Deletes only that exact object using delete_storage_object.
    - Confirms absence in MinIO.
    - Tests both public and private buckets.
    - Guarantees cleanup via try/finally (never touches user or application media).
    """
    s3 = get_internal_s3_client()

    for bucket in [settings.MINIO_PUBLIC_BUCKET, settings.MINIO_PRIVATE_BUCKET]:
        unique_id = uuid.uuid4()
        test_key = f"media/test-runner/{unique_id}/group3c1_temp_lifecycle_test.txt"
        test_body = b"Temporary object for Group 3C.1 deletion service verification."

        try:
            # 1. Put temporary test object
            s3.put_object(
                Bucket=bucket,
                Key=test_key,
                Body=test_body,
                ContentType="text/plain",
            )

            # 2. Verify it exists
            assert check_storage_object_exists(bucket_name=bucket, file_key=test_key) is True

            # 3. Delete using delete_storage_object
            delete_res = delete_storage_object(
                bucket_name=bucket,
                file_key=test_key,
            )
            assert delete_res is True

            # 4. Verify absence
            assert check_storage_object_exists(bucket_name=bucket, file_key=test_key) is False

        finally:
            # Safety cleanup in case of any assertion failure
            try:
                s3.delete_object(Bucket=bucket, Key=test_key)
            except Exception:
                pass
