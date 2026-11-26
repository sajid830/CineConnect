"""CineConnect Object Storage Service.

Provides S3/MinIO compatible object storage integration using boto3:
- AWS Signature Version 4 (SigV4) presigned upload and download URLs.
- Dual-bucket segregation:
    * 'cineconnect-public' for public media (logos, feed posts, portfolio).
    * 'cineconnect-private' for confidential files (resumes, audition reels).
- Idempotent bucket initialization with public-read policy on public assets.
- Endpoint separation: internal container network vs. client-reachable mobile/web endpoints.
"""
import hashlib
import json
import logging
import re
import struct
import uuid
from contextlib import asynccontextmanager
from typing import Any, Dict, Optional, Set, Tuple, Iterable, List
from urllib.parse import urlparse
from fastapi import HTTPException, status
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
import boto3
from botocore.client import Config
from botocore.exceptions import (
    ClientError,
    BotoCoreError,
    EndpointConnectionError,
    ConnectTimeoutError,
)

from app.core.config import settings

logger = logging.getLogger("cineconnect.storage")


# ==============================================================================
# Storage Exceptions
# ==============================================================================

class StorageError(Exception):
    """Base exception for CineConnect object storage operations."""
    pass


class StorageValidationError(StorageError, ValueError):
    """Raised when storage input parameters (bucket, key, URL) are invalid."""
    pass


class StorageConnectionError(StorageError, HTTPException):
    """Raised when connecting to MinIO/S3 fails."""

    def __init__(self, detail: str = "Media storage service connection failed. Please try again later."):
        super().__init__(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=detail)


class StorageAccessDeniedError(StorageError, HTTPException):
    """Raised when MinIO denies access (403 / AccessDenied)."""

    def __init__(self, detail: str = "Storage access denied: insufficient permissions to perform operation."):
        super().__init__(status_code=status.HTTP_403_FORBIDDEN, detail=detail)


class StorageDeletionError(StorageError, HTTPException):
    """Raised when MinIO fails to delete an object."""

    def __init__(self, detail: str = "Failed to delete storage object."):
        super().__init__(status_code=status.HTTP_502_BAD_GATEWAY, detail=detail)


ALLOWED_MIME_PREFIXES = ("image/", "video/", "audio/", "application/pdf")
MAX_FILE_SIZE = 100 * 1024 * 1024  # 100 MB
MAX_PRESIGNED_EXPIRATION = 604800  # 7 days in seconds


def get_internal_s3_client():
    """Returns a boto3 S3 client configured for internal backend-to-MinIO operations."""
    return boto3.client(
        "s3",
        endpoint_url=settings.internal_storage_endpoint,
        aws_access_key_id=settings.MINIO_ACCESS_KEY,
        aws_secret_access_key=settings.MINIO_SECRET_KEY,
        region_name=settings.MINIO_REGION,
        config=Config(signature_version="s3v4", s3={"addressing_style": "path"}),
    )


# Backward compatibility alias
get_s3_client = get_internal_s3_client


def get_public_s3_client(custom_endpoint: Optional[str] = None):
    """Returns a boto3 S3 client configured with client-reachable endpoint for SigV4 presigned URLs.

    Generating presigned URLs signs the 'Host' header matching this endpoint_url,
    ensuring mobile/browser clients can upload/download directly without signature mismatch.
    """
    return boto3.client(
        "s3",
        endpoint_url=custom_endpoint or settings.public_storage_endpoint,
        aws_access_key_id=settings.MINIO_ACCESS_KEY,
        aws_secret_access_key=settings.MINIO_SECRET_KEY,
        region_name=settings.MINIO_REGION,
        config=Config(signature_version="s3v4", s3={"addressing_style": "path"}),
    )


def init_storage_buckets() -> Dict[str, bool]:
    """Safe, idempotent initialization for CineConnect storage buckets.

    Ensures:
    - 'cineconnect-public' exists and has read-only policy for public media (logos, feed, portfolio).
    - 'cineconnect-private' exists and remains private (no public policy attached).

    Returns a dict with bucket names and their initialization status.
    """
    s3 = get_internal_s3_client()
    status: Dict[str, bool] = {}

    buckets = [
        {"name": settings.MINIO_PUBLIC_BUCKET, "is_public": True},
        {"name": settings.MINIO_PRIVATE_BUCKET, "is_public": False},
    ]

    for b in buckets:
        bucket_name = b["name"]
        try:
            # Check if bucket already exists
            s3.head_bucket(Bucket=bucket_name)
            logger.info("Bucket '%s' already exists.", bucket_name)
            status[bucket_name] = True
        except ClientError as e:
            error_code = str(e.response.get("Error", {}).get("Code", ""))
            if error_code in ("404", "NoSuchBucket", "NotFound"):
                logger.info("Bucket '%s' not found. Creating...", bucket_name)
                try:
                    s3.create_bucket(Bucket=bucket_name)
                    logger.info("Bucket '%s' created successfully.", bucket_name)
                    status[bucket_name] = True
                except ClientError as ce:
                    logger.error("Failed to create bucket '%s': %s", bucket_name, ce)
                    status[bucket_name] = False
                    continue
            else:
                logger.warning("Bucket check for '%s' returned: %s", bucket_name, e)
                status[bucket_name] = True

        # Apply access policy: public-read only for public bucket
        if b["is_public"] and status.get(bucket_name):
            policy = {
                "Version": "2012-10-17",
                "Statement": [
                    {
                        "Sid": "PublicReadOnly",
                        "Effect": "Allow",
                        "Principal": "*",
                        "Action": ["s3:GetObject"],
                        "Resource": [f"arn:aws:s3:::{bucket_name}/*"],
                    }
                ],
            }
            try:
                s3.put_bucket_policy(Bucket=bucket_name, Policy=json.dumps(policy))
                logger.info("Public read policy applied to '%s'.", bucket_name)
            except ClientError as pe:
                logger.warning("Could not set public policy on '%s': %s", bucket_name, pe)

    return status


def generate_presigned_upload_url(
    file_name: str,
    content_type: str,
    user_id: uuid.UUID,
    file_size_bytes: Optional[int] = None,
    purpose: str = "public",
    bucket_name: Optional[str] = None,
    expires_in: int = 3600,
    client_host: Optional[str] = None,
) -> Dict[str, Any]:
    """Generates an AWS SigV4 presigned upload URL for direct client-to-storage PUT uploads.

    Security & integrity guarantees:
    - user_id is taken from the authenticated session (never trusted from client input).
    - MIME prefix whitelist is enforced.
    - Declared file size limit is verified.
    - Path isolation: media/{user_id}/{uuid4}/{clean_name}.
    - Host header matches client-accessible endpoint.
    - AWS Signature Version 4 (SigV4) generated via boto3.
    - Purpose routing: 'public' -> cineconnect-public; 'private' -> cineconnect-private.
    - Client cannot inject arbitrary external buckets; bucket names resolve from configuration.
    """
    # 1. Resolve and validate target bucket
    authorized_buckets = (settings.MINIO_PUBLIC_BUCKET, settings.MINIO_PRIVATE_BUCKET)
    if bucket_name:
        if bucket_name not in authorized_buckets:
            raise ValueError(
                f"Bucket '{bucket_name}' is not an authorized CineConnect bucket. "
                f"Allowed: {', '.join(authorized_buckets)}."
            )
        target_bucket = bucket_name
    elif purpose == "public":
        target_bucket = settings.MINIO_PUBLIC_BUCKET
    elif purpose == "private":
        target_bucket = settings.MINIO_PRIVATE_BUCKET
    else:
        raise ValueError(
            f"Invalid upload purpose '{purpose}'. Allowed values: 'public', 'private'."
        )

    # 2. Validate filename
    if not file_name or not file_name.strip():
        raise ValueError("Filename cannot be empty.")

    # 3. Validate MIME prefix
    if not content_type or not any(content_type.startswith(prefix) for prefix in ALLOWED_MIME_PREFIXES):
        raise ValueError(
            f"Content type '{content_type}' is not permitted. Allowed: images, videos, audio, and PDF documents."
        )

    # 4. Validate declared file size
    if file_size_bytes is not None:
        if file_size_bytes <= 0:
            raise ValueError("File size must be greater than zero bytes.")
        if file_size_bytes > MAX_FILE_SIZE:
            raise ValueError(
                f"File size exceeds maximum allowed limit of {MAX_FILE_SIZE // (1024 * 1024)} MB."
            )

    # 5. Validate expires_in
    if not isinstance(expires_in, int) or expires_in <= 0 or expires_in > MAX_PRESIGNED_EXPIRATION:
        raise ValueError(
            f"expires_in must be a positive integer between 1 and {MAX_PRESIGNED_EXPIRATION} seconds."
        )

    # 6. Clean filename and generate unique file key
    clean_name = re.sub(r"[^\w\-.]", "_", file_name.strip().replace(" ", "_"))
    file_uuid = uuid.uuid4()
    file_key = f"media/{user_id}/{file_uuid}/{clean_name}"

    # 7. Generate upload URL
    if client_host and ("ngrok" in client_host or "trycloudflare" in client_host):
        scheme = "https"
        base_api = f"{scheme}://{client_host}"
        upload_url = f"{base_api}/api/v1/media/upload/{target_bucket}/{file_key}"
        public_url = f"{base_api}/api/v1/media/file/{target_bucket}/{file_key}"
    else:
        effective_endpoint = settings.public_storage_endpoint
        if client_host and client_host not in ("localhost", "127.0.0.1", "testserver") and not getattr(settings, "MINIO_PUBLIC_ENDPOINT", None):
            parsed_pub = urlparse(settings.public_storage_endpoint)
            port_part = f":{parsed_pub.port}" if parsed_pub.port else ":9000"
            scheme = parsed_pub.scheme or ("https" if settings.MINIO_USE_SSL else "http")
            effective_endpoint = f"{scheme}://{client_host}{port_part}"

        s3_public = get_public_s3_client(custom_endpoint=effective_endpoint)
        upload_url = s3_public.generate_presigned_url(
            ClientMethod="put_object",
            Params={
                "Bucket": target_bucket,
                "Key": file_key,
                "ContentType": content_type,
            },
            ExpiresIn=expires_in,
        )
        public_url = f"{effective_endpoint}/{target_bucket}/{file_key}"

    return {
        "upload_url": upload_url,
        "file_key": file_key,
        "public_url": public_url,
        "bucket": target_bucket,
        "purpose": purpose,
        "expires_in_seconds": expires_in,
    }


def generate_presigned_download_url(
    bucket_name: str,
    file_key: str,
    expires_in: int = 3600,
) -> str:
    """Generates an AWS SigV4 presigned GET URL for temporary read access to an object.

    Security & validation requirements:
    - Validates bucket against authorized CineConnect buckets (cineconnect-public, cineconnect-private).
    - Validates that file_key is non-empty.
    - Validates expires_in boundary (1s to 7 days / 604800s).
    - Uses client-reachable storage endpoint so the URL functions from client/mobile environment.
    - Employs boto3 AWS SigV4 temporary credentials.
    """
    # 1. Bucket validation
    authorized_buckets = (settings.MINIO_PUBLIC_BUCKET, settings.MINIO_PRIVATE_BUCKET)
    if not bucket_name or bucket_name not in authorized_buckets:
        raise ValueError(
            f"Bucket '{bucket_name}' is not an authorized CineConnect bucket. "
            f"Allowed: {', '.join(authorized_buckets)}."
        )

    # 2. File key validation
    if not file_key or not file_key.strip():
        raise ValueError("File key cannot be empty.")

    # 3. Expiration validation
    if not isinstance(expires_in, int) or expires_in <= 0 or expires_in > MAX_PRESIGNED_EXPIRATION:
        raise ValueError(
            f"expires_in must be a positive integer between 1 and {MAX_PRESIGNED_EXPIRATION} seconds (7 days)."
        )

    # 4. Generate presigned GET URL using client-reachable S3 client
    s3_public = get_public_s3_client()
    download_url = s3_public.generate_presigned_url(
        ClientMethod="get_object",
        Params={
            "Bucket": bucket_name,
            "Key": file_key.strip(),
        },
        ExpiresIn=expires_in,
    )

    return download_url


def get_trusted_storage_netlocs() -> Set[str]:
    """Returns a set of normalized netloc (host:port or host) strings corresponding to
    the configured CineConnect MinIO storage endpoints.
    """
    trusted: Set[str] = set()
    endpoints = [
        settings.public_storage_endpoint,
        settings.internal_storage_endpoint,
        getattr(settings, "MINIO_ENDPOINT", None),
        getattr(settings, "MINIO_PUBLIC_ENDPOINT", None),
        getattr(settings, "MINIO_INTERNAL_ENDPOINT", None),
    ]
    for ep in endpoints:
        if not ep or not isinstance(ep, str):
            continue
        ep_str = ep.strip()
        if not ep_str.startswith(("http://", "https://")):
            ep_str = f"http://{ep_str}"
        try:
            p = urlparse(ep_str)
            if p.netloc:
                trusted.add(p.netloc.lower())
                # If port is omitted or default HTTP/HTTPS, also allow bare hostname
                if p.hostname and not p.port:
                    trusted.add(p.hostname.lower())
        except Exception:
            continue
    return trusted


def parse_storage_url(url_or_key: Optional[str]) -> Tuple[Optional[str], Optional[str], bool]:
    """Safely parses a storage URL or relative key using Python's urllib.parse.

    Distinguishes CineConnect MinIO URLs from arbitrary external URLs by validating
    the parsed hostname and port against configured trusted MinIO endpoints.
    Does NOT use unrestricted substring matching.

    Returns:
        (file_key, bucket_name, is_internal)
        - file_key: Normalized relative object key (e.g. 'media/{user_id}/...'), or None.
        - bucket_name: Extracted bucket name if in path, or None.
        - is_internal: True if the URL/key targets CineConnect MinIO storage, False otherwise.
    """
    if not url_or_key or not isinstance(url_or_key, str):
        return None, None, False

    cleaned = url_or_key.strip()
    if not cleaned:
        return None, None, False

    # 1. Check if it's already a relative key starting with 'media/'
    if cleaned.startswith("media/"):
        file_key = cleaned.split("?")[0].strip()
        return file_key, None, True

    # 2. Check if it looks like a full URL with scheme
    if cleaned.startswith(("http://", "https://")):
        try:
            parsed = urlparse(cleaned)
        except Exception:
            return None, None, False

        # Validate that the parsed hostname & port match trusted CineConnect MinIO endpoints
        if not parsed.netloc:
            return None, None, False

        trusted_netlocs = get_trusted_storage_netlocs()
        netloc_lower = parsed.netloc.lower()
        is_trusted = netloc_lower in trusted_netlocs
        if not is_trusted:
            # Also allow if port matches configured MinIO storage port (e.g. 9000)
            storage_port = urlparse(settings.public_storage_endpoint).port or 9000
            if parsed.port == storage_port:
                is_trusted = True
        if not is_trusted:
            # Arbitrary external URL (Vimeo, YouTube, foreign CDN, or fake host in path/query)
            return None, None, False

        # Parse path-style bucket and key: /{bucket}/media/{user_id}/{uuid}/{filename}
        path_segments = [s for s in parsed.path.strip("/").split("/") if s]
        if not path_segments:
            return None, None, True

        # Check if proxy path style: /api/v1/media/(file|upload)/{bucket}/{file_key:path}
        if len(path_segments) >= 5 and path_segments[0] == "api" and path_segments[1] == "v1" and path_segments[2] == "media" and path_segments[3] in ("file", "upload"):
            bucket = path_segments[4]
            file_key = "/".join(path_segments[5:])
            return file_key, bucket, True

        # Find the last occurrence of "media" that represents the storage key root
        media_indices = [i for i, seg in enumerate(path_segments) if seg == "media"]
        if media_indices:
            media_idx = media_indices[-1]
            file_key = "/".join(path_segments[media_idx:])
            bucket = path_segments[media_idx - 1] if media_idx > 0 else None
            return file_key, bucket, True
        else:
            # Trusted host but doesn't have "media" in path
            bucket = path_segments[0] if path_segments else None
            key = "/".join(path_segments[1:]) if len(path_segments) > 1 else None
            return key, bucket, True

    # Neither starts with media/ nor has http(s):// scheme
    return None, None, False


def extract_file_key(url_or_key: Optional[str]) -> Optional[str]:
    """Extracts relative storage file key (media/{user_id}/{uuid}/{clean_name})
    from a full MinIO/S3 URL or raw key string.
    Returns None if url_or_key does not represent a trusted CineConnect storage object.
    """
    file_key, _, is_internal = parse_storage_url(url_or_key)
    if is_internal and file_key and file_key.startswith("media/"):
        return file_key
    return None


def is_minio_public_url(url_or_key: Optional[str]) -> bool:
    """Returns True if the URL or key explicitly targets the public MinIO bucket."""
    _, bucket, is_internal = parse_storage_url(url_or_key)
    if is_internal and bucket == settings.MINIO_PUBLIC_BUCKET:
        return True
    return False


def check_storage_object_exists(
    bucket_name: str,
    file_key: str,
) -> bool:
    """Verifies that an object actually exists in MinIO storage using head_object.
    Returns True if the object exists.
    Returns False if the object does not exist (404/NoSuchKey).
    Raises HTTPException(503) if MinIO service is unreachable or encounters a system error.
    """
    s3_internal = get_internal_s3_client()
    try:
        s3_internal.head_object(Bucket=bucket_name, Key=file_key)
        return True
    except ClientError as e:
        error_code = str(e.response.get("Error", {}).get("Code", ""))
        # S3 head_object returns '404' or 'NoSuchKey' when an object does not exist
        if error_code in ("404", "NoSuchKey", "NotFound"):
            return False
        logger.error(
            "MinIO ClientError during head_object for key '%s' in bucket '%s': %s",
            file_key, bucket_name, e
        )
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Media storage service is temporarily unavailable. Please try again later.",
        )
    except (BotoCoreError, Exception) as e:
        logger.error(
            "Storage connection error during head_object for key '%s' in bucket '%s': %s",
            file_key, bucket_name, e
        )
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Media storage service is temporarily unavailable. Please try again later.",
        )


def validate_talent_media_ownership(
    url_or_key: Optional[str],
    talent_id: uuid.UUID,
    field_name: str = "media",
    verify_exists: bool = True,
    checked_keys: Optional[Set[Tuple[str, str]]] = None,
) -> Optional[str]:
    """Validates that a private media attachment belongs to the authenticated Talent
    and exists in the private MinIO bucket.

    Security rules:
    - If the URL targets the public CineConnect bucket, reject with 400 Bad Request.
    - If the URL/key represents an internal CineConnect media object:
        * Verify that the key path matches media/{talent_id}/... (403 Forbidden if not).
        * If verify_exists is True, verify with MinIO head_object that the object exists (400 Bad Request if not).
    - If it is an external URL (e.g. Vimeo, YouTube), bypass MinIO checks and allow.
    - Avoids duplicate MinIO head_object requests when checked_keys set is provided.

    Returns:
        The extracted file_key if it is an internal object, or None if external.
    """
    if not url_or_key or not isinstance(url_or_key, str):
        return None

    cleaned = url_or_key.strip()
    if not cleaned:
        return None

    file_key, bucket, is_internal = parse_storage_url(cleaned)

    # 1. External URLs bypass MinIO ownership and existence checks
    if not is_internal:
        return None

    # 2. Reject if explicitly targeting the public bucket
    if bucket == settings.MINIO_PUBLIC_BUCKET:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"{field_name.capitalize()} in CineConnect storage must be uploaded with purpose='private'.",
        )

    # 3. Validate user ownership in key path: media/{user_id}/{uuid}/{clean_name}
    if not file_key:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid storage key format for {field_name}.",
        )

    parts = file_key.split("/")
    if len(parts) >= 2:
        key_user_id = parts[1]
        if key_user_id != str(talent_id):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"You do not have permission to attach {field_name} belonging to another user.",
            )
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid storage key format for {field_name}.",
        )

    # 4. Verify object existence in private bucket using head_object
    if verify_exists:
        cache_key = (settings.MINIO_PRIVATE_BUCKET, file_key)
        if checked_keys is not None and cache_key in checked_keys:
            return file_key

        exists = check_storage_object_exists(
            bucket_name=settings.MINIO_PRIVATE_BUCKET,
            file_key=file_key,
        )
        if not exists:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"The specified {field_name} file does not exist in storage or has not finished uploading.",
            )

        if checked_keys is not None:
            checked_keys.add(cache_key)

    return file_key


def validate_public_media_ownership(
    url_or_key: Optional[str],
    user_id: uuid.UUID,
    field_name: str = "media",
    verify_exists: bool = True,
    checked_keys: Optional[Set[Tuple[str, str]]] = None,
) -> Optional[str]:
    """Validates that a public media attachment belongs to the authenticated user
    and exists in the public MinIO bucket (cineconnect-public).

    Security rules:
    - If url_or_key is None or empty, returns None.
    - If external URL (e.g. Vimeo, YouTube, third-party CDN), bypasses MinIO checks and returns None.
    - If the URL explicitly targets the private CineConnect bucket (cineconnect-private), reject with 400 Bad Request.
    - If internal CineConnect media:
        * Verify that the key path matches media/{user_id}/... (403 Forbidden if belonging to another user).
        * If verify_exists is True, verify with MinIO head_object that the object exists in settings.MINIO_PUBLIC_BUCKET (400 Bad Request if not).
    - Avoids duplicate MinIO head_object requests when checked_keys set is provided.

    Returns:
        The extracted file_key if it is an internal object, or None if external.
    """
    if not url_or_key or not isinstance(url_or_key, str):
        return None

    cleaned = url_or_key.strip()
    if not cleaned:
        return None

    file_key, bucket, is_internal = parse_storage_url(cleaned)

    # 1. External URLs bypass MinIO ownership and existence checks
    if not is_internal:
        return None

    # 2. Reject if explicitly targeting the private bucket
    if bucket == settings.MINIO_PRIVATE_BUCKET:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"{field_name.capitalize()} in CineConnect storage must be uploaded with purpose='public'.",
        )

    # 3. Validate user ownership in key path: media/{user_id}/{uuid}/{clean_name}
    if not file_key:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid storage key format for {field_name}.",
        )

    parts = file_key.split("/")
    if len(parts) >= 2:
        key_user_id = parts[1]
        if key_user_id != str(user_id):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"You do not have permission to attach {field_name} belonging to another user.",
            )
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid storage key format for {field_name}.",
        )

    # 4. Verify object existence in public bucket using head_object
    if verify_exists:
        cache_key = (settings.MINIO_PUBLIC_BUCKET, file_key)
        if checked_keys is not None and cache_key in checked_keys:
            return file_key

        exists = check_storage_object_exists(
            bucket_name=settings.MINIO_PUBLIC_BUCKET,
            file_key=file_key,
        )
        if not exists:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"The specified {field_name} file does not exist in storage or has not finished uploading.",
            )

        if checked_keys is not None:
            checked_keys.add(cache_key)

    return file_key


def get_application_file_download_url(
    url_or_key: Optional[str],
    expires_in: int = 3600,
) -> Optional[str]:
    """Resolves an application's stored resume_url or reel_url into an authorized
    temporary presigned GET download URL if it references a MinIO object.
    External/legacy URLs (e.g. Vimeo, YouTube, legacy CDNs) are returned unchanged.
    """
    if not url_or_key or not isinstance(url_or_key, str):
        return None

    cleaned = url_or_key.strip()
    file_key, bucket, is_internal = parse_storage_url(cleaned)
    if not is_internal or not file_key:
        # External URL (Vimeo, YouTube, etc.) or legacy link
        return cleaned

    # Determine target bucket: defaults to private bucket for application files
    target_bucket = bucket if bucket == settings.MINIO_PUBLIC_BUCKET else settings.MINIO_PRIVATE_BUCKET

    try:
        return generate_presigned_download_url(
            bucket_name=target_bucket,
            file_key=file_key,
            expires_in=expires_in,
        )
    except Exception as e:
        logger.error("Failed to generate presigned download URL for key '%s': %s", file_key, e)
        return cleaned


def delete_storage_object(
    bucket_name: str,
    file_key: str,
    s3_client: Optional[Any] = None,
) -> bool:
    """Securely deletes an object from the specified CineConnect storage bucket.

    Security & validation requirements:
    1. Validates that bucket_name is in authorized CineConnect buckets (cineconnect-public, cineconnect-private).
    2. Validates that file_key is non-empty, contains no path traversal (..), null bytes, or control characters.
    3. Rejects external URLs (e.g. Vimeo, YouTube, third-party CDNs).
    4. If an internal CineConnect URL is provided, validates that its embedded bucket matches bucket_name and extracts key.
    5. Enforces that target key starts with 'media/' prefix and is not a directory prefix.
    6. Uses MinIO/S3 delete_object via the internal boto3 S3 client.
    7. Verifies response status code (200/204) and handles ClientError, Connection errors, and permission failures.
    8. Provides structured logging without exposing credentials or sensitive information.

    Returns:
        bool: True if the object was successfully deleted.

    Raises:
        StorageValidationError (subclass of ValueError): For invalid input parameters, malformed keys, or external URLs.
        StorageAccessDeniedError (subclass of HTTPException 403): If access to the object/bucket is denied.
        StorageConnectionError (subclass of HTTPException 503): If the MinIO service cannot be reached.
        StorageDeletionError (subclass of HTTPException 502): If MinIO returns an error or failure status.
    """
    # 1. Bucket validation
    authorized_buckets = (settings.MINIO_PUBLIC_BUCKET, settings.MINIO_PRIVATE_BUCKET)
    if not bucket_name or not isinstance(bucket_name, str) or bucket_name not in authorized_buckets:
        raise StorageValidationError(
            f"Bucket '{bucket_name}' is not an authorized CineConnect bucket. "
            f"Allowed: {', '.join(authorized_buckets)}."
        )

    # 2. Key / URL validation
    if not file_key or not isinstance(file_key, str) or not file_key.strip():
        raise StorageValidationError("Object key cannot be empty.")

    cleaned_key = file_key.strip()

    # Reject null bytes and control characters
    if any(ord(c) < 32 or ord(c) == 127 for c in cleaned_key):
        raise StorageValidationError("Object key contains invalid control characters.")

    # Check for path traversal patterns (raw, backslash-separated, or URL-encoded)
    if (
        ".." in cleaned_key
        or "\\.." in cleaned_key
        or "..\\" in cleaned_key
        or "%2e" in cleaned_key.lower()
        or "%2f" in cleaned_key.lower()
        or "%5c" in cleaned_key.lower()
    ):
        raise StorageValidationError("Object key cannot contain path traversal patterns.")

    normalized_for_traversal = cleaned_key.replace("\\", "/").split("?")[0]
    segments = normalized_for_traversal.split("/")
    if "." in segments:
        raise StorageValidationError("Object key cannot contain path traversal patterns.")

    # Check if input is a full URL
    if cleaned_key.startswith(("http://", "https://")):
        parsed_key, parsed_bucket, is_internal = parse_storage_url(cleaned_key)
        if not is_internal:
            raise StorageValidationError(
                "Cannot delete external media URL: object does not belong to CineConnect storage."
            )
        if parsed_bucket and parsed_bucket != bucket_name:
            raise StorageValidationError(
                f"Bucket mismatch: URL specifies bucket '{parsed_bucket}', "
                f"but target bucket is '{bucket_name}'."
            )
        if not parsed_key:
            raise StorageValidationError("Malformed object key: could not extract key from storage URL.")
        target_key = parsed_key
    else:
        target_key = cleaned_key.split("?")[0].strip()

    # Reject leading/trailing slashes or empty directory paths
    if target_key.startswith("/") or target_key.startswith("\\"):
        raise StorageValidationError("Malformed object key: key cannot start with a slash or backslash.")
    if target_key.endswith("/") or target_key.endswith("\\"):
        raise StorageValidationError("Malformed object key: key cannot be a directory prefix.")

    if "//" in target_key or "\\\\" in target_key:
        raise StorageValidationError("Malformed object key: consecutive slashes are not allowed.")

    # Must start with 'media/' prefix and have valid key structure
    if not target_key.startswith("media/"):
        raise StorageValidationError(
            f"Malformed object key: '{target_key}' is not a valid CineConnect storage key. Keys must start with 'media/'."
        )

    parts = [p for p in target_key.split("/") if p]
    if len(parts) < 2:
        raise StorageValidationError(
            f"Malformed object key: '{target_key}' does not contain an object filename."
        )

    # 3. MinIO delete_object execution
    client = s3_client if s3_client is not None else get_internal_s3_client()

    try:
        response = client.delete_object(
            Bucket=bucket_name,
            Key=target_key,
        )
        status_code = response.get("ResponseMetadata", {}).get("HTTPStatusCode")
        if status_code is not None and status_code not in (200, 204):
            logger.error(
                "MinIO returned unexpected status code %s when deleting key '%s' from bucket '%s'",
                status_code, target_key, bucket_name
            )
            raise StorageDeletionError(
                f"Failed to delete object from storage: MinIO returned HTTP {status_code}."
            )

        logger.info(
            "Successfully deleted storage object '%s' from bucket '%s'",
            target_key, bucket_name
        )
        return True

    except ClientError as e:
        error_code = str(e.response.get("Error", {}).get("Code", ""))
        error_msg = str(e.response.get("Error", {}).get("Message", str(e)))
        logger.error(
            "MinIO ClientError during delete_object for key '%s' in bucket '%s' (Code: %s): %s",
            target_key, bucket_name, error_code, error_msg
        )
        if error_code in ("AccessDenied", "403"):
            raise StorageAccessDeniedError(
                "Access denied: insufficient permissions to delete storage object."
            )
        raise StorageDeletionError(
            f"MinIO client error during object deletion: {error_code or 'Unknown error'}."
        )
    except (EndpointConnectionError, ConnectTimeoutError) as e:
        logger.error(
            "MinIO connection failure during delete_object for key '%s' in bucket '%s': %s",
            target_key, bucket_name, e
        )
        raise StorageConnectionError(
            "Storage service connection failed. Please try again later."
        )
    except BotoCoreError as e:
        err_str = str(e).lower()
        logger.error(
            "BotoCoreError during delete_object for key '%s' in bucket '%s': %s",
            target_key, bucket_name, e
        )
        if any(term in err_str for term in ("connect", "endpoint", "timeout", "network", "unreachable")):
            raise StorageConnectionError(
                "Storage service connection failed. Please try again later."
            )
        raise StorageDeletionError(
            "Low-level storage client error during object deletion."
        )
    except (StorageError, HTTPException):
        raise
    except Exception as e:
        logger.error(
            "Unexpected error during delete_object for key '%s' in bucket '%s': %s",
            target_key, bucket_name, e
        )
        raise StorageDeletionError("Unexpected failure during storage object deletion.")


# ==============================================================================
# Advisory Lock Helpers for Concurrency Control
# ==============================================================================

def get_media_advisory_lock_id(canonical_key: str) -> int:
    """Derives a deterministic 64-bit signed integer for PostgreSQL transaction advisory locks.

    Uses a consistent namespace 'cineconnect:application-media:' and SHA-256 hash.
    The resulting signed 64-bit integer (-2^63 to 2^63 - 1) is passed to pg_advisory_xact_lock.
    Identical canonical keys always produce identical lock IDs across all workers and processes.
    """
    clean = canonical_key.strip()
    namespaced = f"cineconnect:application-media:{clean}"
    digest = hashlib.sha256(namespaced.encode("utf-8")).digest()
    return struct.unpack(">q", digest[:8])[0]


async def acquire_media_advisory_lock(db: AsyncSession, canonical_key: str) -> Optional[int]:
    """Acquires a PostgreSQL transaction-scoped advisory lock (pg_advisory_xact_lock)
    for the specified canonical media key.

    Guarantees cross-worker mutual exclusion on media attachment, reference-counting,
    and deletion operations. The lock is held until the current transaction commits or rolls back.
    """
    if not canonical_key or not isinstance(canonical_key, str):
        return None
    clean_key = extract_file_key(canonical_key) or canonical_key.strip()
    if not clean_key or not clean_key.startswith("media/"):
        return None

    lock_id = get_media_advisory_lock_id(clean_key)
    try:
        await db.execute(
            text("SELECT pg_advisory_xact_lock(:lock_id)"),
            {"lock_id": lock_id},
        )
        logger.debug("Acquired advisory xact lock %d for key '%s'", lock_id, clean_key)
        return lock_id
    except Exception as e:
        # Non-PostgreSQL dialect fallback (e.g. SQLite in unit tests)
        err_msg = str(e).lower()
        if "pg_advisory_xact_lock" in err_msg and ("syntax error" in err_msg or "no such function" in err_msg):
            return None
        raise


async def acquire_media_advisory_locks(
    db: AsyncSession,
    file_keys_or_urls: Iterable[Optional[str]],
) -> List[int]:
    """Extracts canonical private keys and acquires advisory locks in deterministic sorted order
    to prevent deadlocks when an operation involves multiple media files (e.g. resume and reel).
    """
    canonical_keys: Set[str] = set()
    for raw in file_keys_or_urls:
        if not raw or not isinstance(raw, str):
            continue
        k = extract_file_key(raw)
        if k and k.startswith("media/"):
            # Only lock private bucket media
            _, bucket, is_internal = parse_storage_url(raw)
            if is_internal and bucket != settings.MINIO_PUBLIC_BUCKET:
                canonical_keys.add(k)

    if not canonical_keys:
        return []

    acquired_locks: List[int] = []
    # Sort keys deterministically to avoid deadlocks across multiple workers
    for key in sorted(canonical_keys):
        lock_id = await acquire_media_advisory_lock(db, key)
        if lock_id is not None:
            acquired_locks.append(lock_id)

    return acquired_locks


def get_public_media_advisory_lock_id(canonical_key: str) -> int:
    """Derives a deterministic 64-bit signed integer for PostgreSQL transaction advisory locks
    on public MinIO media objects (cineconnect-public).

    Uses a dedicated namespace 'cineconnect:public-media:' and SHA-256 hash.
    The resulting signed 64-bit integer (-2^63 to 2^63 - 1) is passed to pg_advisory_xact_lock.
    Identical canonical keys always produce identical lock IDs across all workers and processes.
    """
    clean = canonical_key.strip()
    namespaced = f"cineconnect:public-media:{clean}"
    digest = hashlib.sha256(namespaced.encode("utf-8")).digest()
    return struct.unpack(">q", digest[:8])[0]


async def acquire_public_media_advisory_lock(db: AsyncSession, canonical_key: str) -> Optional[int]:
    """Acquires a PostgreSQL transaction-scoped advisory lock (pg_advisory_xact_lock)
    for the specified canonical public media key.

    Guarantees cross-worker mutual exclusion on public media attachment, reference-counting,
    and deletion operations. The lock is held until the current transaction commits or rolls back.
    """
    if not canonical_key or not isinstance(canonical_key, str):
        return None
    clean_key = extract_file_key(canonical_key) or canonical_key.strip()
    if not clean_key or not clean_key.startswith("media/"):
        return None

    lock_id = get_public_media_advisory_lock_id(clean_key)
    try:
        await db.execute(
            text("SELECT pg_advisory_xact_lock(:lock_id)"),
            {"lock_id": lock_id},
        )
        logger.debug("Acquired public media advisory xact lock %d for key '%s'", lock_id, clean_key)
        return lock_id
    except Exception as e:
        err_msg = str(e).lower()
        if "pg_advisory_xact_lock" in err_msg and ("syntax error" in err_msg or "no such function" in err_msg):
            return None
        raise


async def acquire_public_media_advisory_locks(
    db: AsyncSession,
    file_keys_or_urls: Iterable[Optional[str]],
) -> List[int]:
    """Extracts canonical public keys and acquires public advisory locks in deterministic sorted order
    to prevent deadlocks when an operation involves multiple media files (e.g. media_url and thumbnail_url).
    """
    canonical_keys: Set[str] = set()
    for raw in file_keys_or_urls:
        if not raw or not isinstance(raw, str):
            continue
        k = extract_file_key(raw)
        if k and k.startswith("media/"):
            # Only lock public bucket media (not private)
            _, bucket, is_internal = parse_storage_url(raw)
            if is_internal and bucket != settings.MINIO_PRIVATE_BUCKET:
                canonical_keys.add(k)

    if not canonical_keys:
        return []

    acquired_locks: List[int] = []
    # Sort keys deterministically to avoid deadlocks across multiple workers
    for key in sorted(canonical_keys):
        lock_id = await acquire_public_media_advisory_lock(db, key)
        if lock_id is not None:
            acquired_locks.append(lock_id)

    return acquired_locks


@asynccontextmanager
async def media_transaction_scope(db: AsyncSession):
    """Ensures an active transaction scope for advisory lock operations.
    If the session is not currently in a transaction, opens one with db.begin()
    and commits on exit, releasing all acquired transaction-scoped advisory locks.
    """
    if not db.in_transaction():
        async with db.begin():
            yield
    else:
        yield


# ==============================================================================
# Application Media Reference Checking & Cleanup Services
# ==============================================================================

async def count_application_media_references(
    db: AsyncSession,
    file_key_or_url: str,
    exclude_application_id: Optional[uuid.UUID] = None,
) -> int:
    r"""Counts how many active applications reference the specified private MinIO file key.

    Security & validation rules:
    1. Extracts canonical key (media/{talent_id}/{uuid}/{clean_name}) via extract_file_key().
    2. If the input is an external URL (Vimeo, YouTube, etc.) or targets the public bucket,
       returns 0 (not a private application storage reference).
    3. Queries PostgreSQL for applications where resume_url or reel_url contains or equals the key.
    4. Handles SQL LIKE wildcards safely (escaping %, _, and \).
    5. Performs Python-level canonical key verification (extract_file_key) on every candidate row,
       guaranteeing exact canonical key equality regardless of whether the DB stored a relative key
       or a full MinIO endpoint URL.
    6. Excludes exclude_application_id if provided.
    7. Includes applications regardless of status ('submitted', 'under_review', 'shortlisted', etc.).
    8. Any database execution error propagates (never interpreted as 0 references).

    Returns:
        int: Number of other applications referencing this exact MinIO object.
    """
    if not file_key_or_url or not isinstance(file_key_or_url, str):
        return 0

    cleaned = file_key_or_url.strip()
    if not cleaned:
        return 0

    # 1. Parse URL/key and ensure it is an internal private CineConnect storage object
    parsed_key, parsed_bucket, is_internal = parse_storage_url(cleaned)
    if not is_internal or not parsed_key:
        # External URL (e.g. Vimeo, YouTube) or non-storage key
        return 0

    # Reject public bucket objects (not private application media)
    if parsed_bucket == settings.MINIO_PUBLIC_BUCKET:
        return 0

    canonical_key = extract_file_key(cleaned)
    if not canonical_key or not canonical_key.startswith("media/"):
        return 0

    # 2. Escape SQL LIKE wildcards: %, _, \
    escaped_key = (
        canonical_key.replace("\\", "\\\\")
        .replace("%", "\\%")
        .replace("_", "\\_")
    )

    from sqlalchemy import or_, select
    from app.models.opportunity import Application

    stmt = select(Application.id, Application.resume_url, Application.reel_url).where(
        or_(
            Application.resume_url == canonical_key,
            Application.resume_url.like(f"%{escaped_key}%", escape="\\"),
            Application.reel_url == canonical_key,
            Application.reel_url.like(f"%{escaped_key}%", escape="\\"),
        )
    )
    if exclude_application_id is not None:
        stmt = stmt.where(Application.id != exclude_application_id)

    # Execute query: DB exceptions propagate so failures never produce a false 0
    result = await db.execute(stmt)
    rows = result.all()

    # 3. Canonical key verification in Python for exact equality
    count = 0
    for row_id, r_url, reel_u in rows:
        if exclude_application_id is not None and row_id == exclude_application_id:
            continue

        ref_keys = set()
        if r_url:
            k = extract_file_key(r_url)
            if k:
                ref_keys.add(k)
        if reel_u:
            k = extract_file_key(reel_u)
            if k:
                ref_keys.add(k)

        if canonical_key in ref_keys:
            count += 1

    return count


async def cleanup_unreferenced_application_media(
    db: AsyncSession,
    urls_to_check: Iterable[Optional[str]],
    exclude_application_id: Optional[uuid.UUID] = None,
    s3_client: Optional[Any] = None,
) -> List[str]:
    """Safely cleans up private MinIO application objects that are no longer referenced by any application.

    Security & reference-safety requirements:
    1. Deduplicates candidate keys so the same object is never processed twice.
    2. Filters out external URLs (Vimeo, YouTube) and public-bucket objects.
    3. Only deletes from settings.MINIO_PRIVATE_BUCKET ('cineconnect-private').
    4. Calls count_application_media_references() for each candidate key.
    5. If ref_count >= 1: retains the object.
    6. If ref_count == 0: calls delete_storage_object().
    7. If reference check or deletion encounters an error, logs cleanly without exposing credentials.
    8. Never deletes an object if reference checking fails or is uncertain.

    Returns:
        List[str]: List of canonical file keys that were deleted from MinIO storage.
    """
    if not urls_to_check:
        return []

    # 1. Deduplicate candidate canonical keys
    candidate_keys: Set[str] = set()
    for raw_url in urls_to_check:
        if not raw_url or not isinstance(raw_url, str):
            continue
        cleaned = raw_url.strip()
        if not cleaned:
            continue

        parsed_key, parsed_bucket, is_internal = parse_storage_url(cleaned)
        # Skip external URLs or public bucket assets
        if not is_internal or parsed_bucket == settings.MINIO_PUBLIC_BUCKET:
            continue
        # If a specific bucket was embedded and it's not private, skip
        if parsed_bucket and parsed_bucket != settings.MINIO_PRIVATE_BUCKET:
            continue

        canonical_key = extract_file_key(cleaned)
        if canonical_key and canonical_key.startswith("media/"):
            candidate_keys.add(canonical_key)

    if not candidate_keys:
        return []

    deleted_keys: List[str] = []

    # 2. Reference check and conditional deletion for each candidate key
    for c_key in sorted(candidate_keys):
        # Open transaction scope and acquire advisory lock on c_key before checking or deleting.
        # Lock is held continuously across both the reference check and MinIO deletion,
        # completely closing the TOCTOU window.
        async with media_transaction_scope(db):
            await acquire_media_advisory_lock(db, c_key)

            # Database query failures propagate out, halting deletion loop
            ref_count = await count_application_media_references(
                db=db,
                file_key_or_url=c_key,
                exclude_application_id=exclude_application_id,
            )

            if ref_count > 0:
                logger.info(
                    "Retaining storage object '%s' in bucket '%s': still referenced by %d application(s)",
                    c_key,
                    settings.MINIO_PRIVATE_BUCKET,
                    ref_count,
                )
                continue

            # ref_count == 0: Safe to delete while still holding the advisory lock
            logger.info(
                "Storage object '%s' has 0 remaining application references; deleting from bucket '%s'",
                c_key,
                settings.MINIO_PRIVATE_BUCKET,
            )
            try:
                delete_storage_object(
                    bucket_name=settings.MINIO_PRIVATE_BUCKET,
                    file_key=c_key,
                    s3_client=s3_client,
                )
                deleted_keys.append(c_key)
            except StorageError as se:
                logger.warning(
                    "Storage error deleting unreferenced object '%s' from bucket '%s': %s",
                    c_key,
                    settings.MINIO_PRIVATE_BUCKET,
                    se,
                )
            except Exception as e:
                logger.warning(
                    "Unexpected error deleting unreferenced object '%s' from bucket '%s': %s",
                    c_key,
                    settings.MINIO_PRIVATE_BUCKET,
                    e,
                )

    return deleted_keys


# ==============================================================================
# Public Media Reference Checking & Cleanup Services (Group 3C.3)
# ==============================================================================

async def count_public_media_references(
    db: AsyncSession,
    file_key_or_url: str,
    exclude_portfolio_id: Optional[uuid.UUID] = None,
    exclude_post_id: Optional[uuid.UUID] = None,
    exclude_ph_id: Optional[uuid.UUID] = None,
) -> int:
    r"""Counts how many public records reference the specified MinIO public file key.

    Inspects all four public media fields across three tables:
    1. PortfolioMedia.media_url
    2. PortfolioMedia.thumbnail_url
    3. Post.media_url
    4. ProductionHouse.logo_url

    Security & validation rules:
    - Normalizes relative keys and full MinIO URLs into canonical key (media/{user_id}/{uuid}/{clean_name}).
    - External URLs (Vimeo, YouTube, etc.) or private-bucket keys return 0 (not a public storage reference).
    - Escapes SQL LIKE wildcards (\, %, _) to avoid false matches.
    - Performs exact Python-level canonical key verification (extract_file_key) on candidate rows.
    - Supports multiple field references on the same record (e.g. media_url == thumbnail_url).
    - Supports cross-model sharing (e.g. same key used as logo and post media).
    - Excludes specified IDs if provided.
    - Database exceptions propagate (never interpreted as 0 references).

    Returns:
        int: Total number of remaining field references to this exact public MinIO object.
    """
    if not file_key_or_url or not isinstance(file_key_or_url, str):
        return 0

    cleaned = file_key_or_url.strip()
    if not cleaned:
        return 0

    parsed_key, parsed_bucket, is_internal = parse_storage_url(cleaned)
    if not is_internal or not parsed_key:
        return 0

    # Ignore private-bucket references
    if parsed_bucket == settings.MINIO_PRIVATE_BUCKET:
        return 0

    canonical_key = extract_file_key(cleaned)
    if not canonical_key or not canonical_key.startswith("media/"):
        return 0

    escaped_key = (
        canonical_key.replace("\\", "\\\\")
        .replace("%", "\\%")
        .replace("_", "\\_")
    )

    from sqlalchemy import or_, select
    from app.models.portfolio import PortfolioMedia
    from app.models.social import Post, Story, Reel
    from app.models.production_house import ProductionHouse

    total_refs = 0

    # 1. Query PortfolioMedia (both media_url and thumbnail_url)
    stmt_pm = select(PortfolioMedia.id, PortfolioMedia.media_url, PortfolioMedia.thumbnail_url).where(
        or_(
            PortfolioMedia.media_url == canonical_key,
            PortfolioMedia.media_url.like(f"%{escaped_key}%", escape="\\"),
            PortfolioMedia.thumbnail_url == canonical_key,
            PortfolioMedia.thumbnail_url.like(f"%{escaped_key}%", escape="\\"),
        )
    )
    if exclude_portfolio_id is not None:
        stmt_pm = stmt_pm.where(PortfolioMedia.id != exclude_portfolio_id)

    res_pm = await db.execute(stmt_pm)
    for row_id, m_url, t_url in res_pm.all():
        if exclude_portfolio_id is not None and row_id == exclude_portfolio_id:
            continue
        if m_url and extract_file_key(m_url) == canonical_key:
            total_refs += 1
        if t_url and extract_file_key(t_url) == canonical_key:
            total_refs += 1

    # 2. Query Post (media_url)
    stmt_post = select(Post.id, Post.media_url).where(
        or_(
            Post.media_url == canonical_key,
            Post.media_url.like(f"%{escaped_key}%", escape="\\"),
        )
    )
    if exclude_post_id is not None:
        stmt_post = stmt_post.where(Post.id != exclude_post_id)

    res_post = await db.execute(stmt_post)
    for row_id, p_url in res_post.all():
        if exclude_post_id is not None and row_id == exclude_post_id:
            continue
        if p_url and extract_file_key(p_url) == canonical_key:
            total_refs += 1

    # 3. Query ProductionHouse (logo_url)
    stmt_ph = select(ProductionHouse.id, ProductionHouse.logo_url).where(
        or_(
            ProductionHouse.logo_url == canonical_key,
            ProductionHouse.logo_url.like(f"%{escaped_key}%", escape="\\"),
        )
    )
    if exclude_ph_id is not None:
        stmt_ph = stmt_ph.where(ProductionHouse.id != exclude_ph_id)

    res_ph = await db.execute(stmt_ph)
    for row_id, l_url in res_ph.all():
        if exclude_ph_id is not None and row_id == exclude_ph_id:
            continue
        if l_url and extract_file_key(l_url) == canonical_key:
            total_refs += 1

    # 4. Query Story (media_url)
    stmt_story = select(Story.id, Story.media_url).where(
        or_(
            Story.media_url == canonical_key,
            Story.media_url.like(f"%{escaped_key}%", escape="\\"),
        )
    )
    res_story = await db.execute(stmt_story)
    for row_id, s_url in res_story.all():
        if s_url and extract_file_key(s_url) == canonical_key:
            total_refs += 1

    # 5. Query Reel (media_url, thumbnail_url)
    stmt_reel = select(Reel.id, Reel.media_url, Reel.thumbnail_url).where(
        or_(
            Reel.media_url == canonical_key,
            Reel.media_url.like(f"%{escaped_key}%", escape="\\"),
            Reel.thumbnail_url == canonical_key,
            Reel.thumbnail_url.like(f"%{escaped_key}%", escape="\\"),
        )
    )
    res_reel = await db.execute(stmt_reel)
    for row_id, r_m_url, r_t_url in res_reel.all():
        if r_m_url and extract_file_key(r_m_url) == canonical_key:
            total_refs += 1
        if r_t_url and extract_file_key(r_t_url) == canonical_key:
            total_refs += 1

    return total_refs


async def cleanup_unreferenced_public_media(
    db: AsyncSession,
    urls_to_check: Iterable[Optional[str]],
    exclude_portfolio_id: Optional[uuid.UUID] = None,
    exclude_post_id: Optional[uuid.UUID] = None,
    exclude_ph_id: Optional[uuid.UUID] = None,
    s3_client: Optional[Any] = None,
) -> List[str]:
    """Safely cleans up public MinIO objects (cineconnect-public) that are no longer referenced
    by any PortfolioMedia, Post, or ProductionHouse record.

    Security & reference-safety requirements:
    1. Deduplicates candidate keys.
    2. Filters out external URLs and private-bucket objects.
    3. Only deletes from settings.MINIO_PUBLIC_BUCKET ('cineconnect-public').
    4. For each candidate key, enters media_transaction_scope(db) and acquires
       acquire_public_media_advisory_lock(db, c_key).
    5. Calls count_public_media_references(db, c_key, ...).
    6. If ref_count > 0: retains the object.
    7. If ref_count == 0: calls delete_storage_object(settings.MINIO_PUBLIC_BUCKET, c_key).
    8. Holds advisory lock continuously between reference check and MinIO deletion.
    9. Sanitizes and logs errors without exposing credentials; DB failure aborts cleanup.
    10. MinIO deletion failure after DB commit does not revert database changes.

    Returns:
        List[str]: Canonical file keys deleted from MinIO public storage.
    """
    if not urls_to_check:
        return []

    # 1. Deduplicate candidate canonical keys
    candidate_keys: Set[str] = set()
    for raw_url in urls_to_check:
        if not raw_url or not isinstance(raw_url, str):
            continue
        cleaned = raw_url.strip()
        if not cleaned:
            continue

        parsed_key, parsed_bucket, is_internal = parse_storage_url(cleaned)
        # Skip external URLs or private bucket assets
        if not is_internal or parsed_bucket == settings.MINIO_PRIVATE_BUCKET:
            continue
        if parsed_bucket and parsed_bucket != settings.MINIO_PUBLIC_BUCKET:
            continue

        canonical_key = extract_file_key(cleaned)
        if canonical_key and canonical_key.startswith("media/"):
            candidate_keys.add(canonical_key)

    if not candidate_keys:
        return []

    deleted_keys: List[str] = []

    # 2. Reference check and conditional deletion for each candidate key
    for c_key in sorted(candidate_keys):
        async with media_transaction_scope(db):
            await acquire_public_media_advisory_lock(db, c_key)

            # Database query failures propagate out, halting deletion loop
            ref_count = await count_public_media_references(
                db=db,
                file_key_or_url=c_key,
                exclude_portfolio_id=exclude_portfolio_id,
                exclude_post_id=exclude_post_id,
                exclude_ph_id=exclude_ph_id,
            )

            if ref_count > 0:
                logger.info(
                    "Retaining public storage object '%s' in bucket '%s': still referenced by %d record(s)/field(s)",
                    c_key,
                    settings.MINIO_PUBLIC_BUCKET,
                    ref_count,
                )
                continue

            # ref_count == 0: Safe to delete while holding advisory lock
            logger.info(
                "Public storage object '%s' has 0 remaining references; deleting from bucket '%s'",
                c_key,
                settings.MINIO_PUBLIC_BUCKET,
            )
            try:
                delete_storage_object(
                    bucket_name=settings.MINIO_PUBLIC_BUCKET,
                    file_key=c_key,
                    s3_client=s3_client,
                )
                deleted_keys.append(c_key)
            except StorageError as se:
                logger.warning(
                    "Storage error deleting unreferenced public object '%s' from bucket '%s': %s",
                    c_key,
                    settings.MINIO_PUBLIC_BUCKET,
                    se,
                )
            except Exception as e:
                logger.warning(
                    "Unexpected error deleting unreferenced public object '%s' from bucket '%s': %s",
                    c_key,
                    settings.MINIO_PUBLIC_BUCKET,
                    e,
                )

    return deleted_keys



