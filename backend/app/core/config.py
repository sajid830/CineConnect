import os
from typing import List, Union, Optional
from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables and .env file."""

    model_config = SettingsConfigDict(
        env_file=(".env", "../.env"),
        env_file_encoding="utf-8",
        extra="ignore",
        case_sensitive=True,
    )

    # Application
    APP_ENV: str = "local"
    APP_NAME: str = "CineConnect"
    API_V1_PREFIX: str = "/api/v1"
    BACKEND_HOST: str = "0.0.0.0"
    BACKEND_PORT: int = 8000
    LOG_LEVEL: str = "INFO"

    # CORS
    CORS_ORIGINS: Union[List[str], str] = [
        "http://localhost:3000",
        "http://localhost:8000",
        "http://127.0.0.1:3000",
        "http://127.0.0.1:8000",
        "http://10.0.2.2:8000",
    ]

    @field_validator("CORS_ORIGINS", mode="before")
    @classmethod
    def assemble_cors_origins(cls, v: Union[str, List[str]]) -> List[str]:
        if isinstance(v, str):
            return [origin.strip() for origin in v.split(",") if origin.strip()]
        return v

    # Database
    POSTGRES_USER: str = "cineconnect"
    POSTGRES_PASSWORD: str = "connectcine321"
    POSTGRES_DB: str = "cineconnect_db"
    POSTGRES_TEST_DB: str = "cineconnect_test_db"
    POSTGRES_HOST: str = "postgres"
    POSTGRES_PORT: int = 5432
    DATABASE_URL: Union[str, None] = None
    TEST_DATABASE_URL: Union[str, None] = None

    # Connection Pool Settings
    DB_POOL_SIZE: int = 10
    DB_MAX_OVERFLOW: int = 20
    DB_POOL_TIMEOUT: int = 30
    DB_POOL_RECYCLE: int = 1800

    # Supabase Authentication & JWT
    SUPABASE_URL: str = "https://your-project.supabase.co"
    SUPABASE_KEY: str = "your_supabase_anon_key_here"
    SUPABASE_JWT_SECRET: str = "cineconnect_supabase_jwt_secret_change_me"
    SUPABASE_JWT_ALGORITHM: Optional[str] = None
    JWT_ALGORITHM: Optional[str] = None  # backward compatibility alias
    SUPABASE_JWT_AUDIENCE: str = "authenticated"
    JWT_CLOCK_SKEW_LEEWAY_SECONDS: int = 60

    @property
    def effective_jwt_algorithm(self) -> str:
        """Resolves the normalized, trusted JWT signing algorithm.

        In production: strictly requires an explicitly configured, supported algorithm (RS256, ES256, HS256).
        In local/test environments: falls back to HS256 when unconfigured.
        Rejects unsupported algorithms in every environment.
        """
        supported_algs = ("RS256", "ES256", "HS256")
        raw_alg = self.SUPABASE_JWT_ALGORITHM or self.JWT_ALGORITHM
        if raw_alg is not None and isinstance(raw_alg, str) and raw_alg.strip():
            normalized = raw_alg.strip().upper()
            if normalized not in supported_algs:
                raise ValueError(
                    f"Unsupported JWT algorithm '{raw_alg}'. Must be one of {supported_algs}."
                )
            return normalized

        if self.is_production:
            raise ValueError(
                f"Production requires SUPABASE_JWT_ALGORITHM to be explicitly configured as one of {supported_algs}."
            )

        return "HS256"

    @property
    def effective_supabase_jwt_algorithm(self) -> str:
        """Alias for effective_jwt_algorithm."""
        return self.effective_jwt_algorithm

    @property
    def SUPABASE_JWT_ISSUER(self) -> str:
        """Expected JWT issuer based on Supabase URL."""
        return f"{self.SUPABASE_URL.rstrip('/')}/auth/v1"

    @property
    def SUPABASE_JWKS_URL(self) -> str:
        """Supabase public JWKS endpoint."""
        return f"{self.SUPABASE_URL.rstrip('/')}/auth/v1/.well-known/jwks.json"

    def validate_production_jwt_config(self) -> None:
        """Validates JWT configuration against production security requirements."""
        if not self.is_production:
            return

        supported_algs = ("RS256", "ES256", "HS256")
        raw_alg = self.SUPABASE_JWT_ALGORITHM or self.JWT_ALGORITHM
        if not raw_alg or not isinstance(raw_alg, str) or not raw_alg.strip():
            raise ValueError(
                f"Production requires SUPABASE_JWT_ALGORITHM to be explicitly configured as one of {supported_algs}."
            )

        alg = raw_alg.strip().upper()
        if alg not in supported_algs:
            raise ValueError(
                f"Production requires SUPABASE_JWT_ALGORITHM to be explicitly set to one of {supported_algs}. "
                f"Received: '{raw_alg}'"
            )

        if not self.SUPABASE_URL or not self.SUPABASE_URL.startswith("https://") or "your-project" in self.SUPABASE_URL:
            raise ValueError(
                "Production requires a valid HTTPS SUPABASE_URL configured."
            )

        if alg == "HS256":
            if (
                not self.SUPABASE_JWT_SECRET
                or self.SUPABASE_JWT_SECRET == "cineconnect_supabase_jwt_secret_change_me"
                or len(self.SUPABASE_JWT_SECRET.strip()) < 32
            ):
                raise ValueError(
                    "Production with HS256 requires a secure SUPABASE_JWT_SECRET (minimum 32 characters)."
                )

    # Media Storage (MinIO / S3)
    MINIO_ENDPOINT: str = "localhost:9000"
    MINIO_INTERNAL_ENDPOINT: Optional[str] = None
    MINIO_PUBLIC_ENDPOINT: Optional[str] = None
    MINIO_ACCESS_KEY: str = "minioadmin"
    MINIO_SECRET_KEY: str = "minioadmin"
    MINIO_REGION: str = "us-east-1"
    MINIO_BUCKET_NAME: str = "cineconnect-public"
    MINIO_PUBLIC_BUCKET: str = "cineconnect-public"
    MINIO_PRIVATE_BUCKET: str = "cineconnect-private"
    MINIO_USE_SSL: bool = False

    @property
    def internal_storage_endpoint(self) -> str:
        """Internal endpoint used for backend server-to-MinIO communication."""
        endpoint = (self.MINIO_INTERNAL_ENDPOINT or "").strip() or self.MINIO_ENDPOINT
        if not endpoint.startswith("http://") and not endpoint.startswith("https://"):
            protocol = "https" if self.MINIO_USE_SSL else "http"
            return f"{protocol}://{endpoint}"
        return endpoint

    @property
    def public_storage_endpoint(self) -> str:
        """Client-reachable public endpoint for mobile/browser uploads and media URLs."""
        endpoint = (self.MINIO_PUBLIC_ENDPOINT or "").strip() or self.MINIO_ENDPOINT
        if not endpoint.startswith("http://") and not endpoint.startswith("https://"):
            protocol = "https" if self.MINIO_USE_SSL else "http"
            return f"{protocol}://{endpoint}"
        return endpoint

    @property
    def MINIO_BUCKET(self) -> str:
        return self.MINIO_PUBLIC_BUCKET or self.MINIO_BUCKET_NAME

    @property
    def MINIO_SECURE(self) -> bool:
        return self.MINIO_USE_SSL

    # Cache & Real-Time Messaging (Redis)
    REDIS_URL: str = "redis://localhost:6379/0"

    @property
    def async_database_url(self) -> str:
        """Returns explicitly set DATABASE_URL or constructs asyncpg PostgreSQL connection URL."""
        if self.DATABASE_URL:
            if self.DATABASE_URL.startswith("postgresql://"):
                return self.DATABASE_URL.replace("postgresql://", "postgresql+asyncpg://", 1)
            return self.DATABASE_URL

        return (
            f"postgresql+asyncpg://{self.POSTGRES_USER}:{self.POSTGRES_PASSWORD}"
            f"@{self.POSTGRES_HOST}:{self.POSTGRES_PORT}/{self.POSTGRES_DB}"
        )

    @property
    def async_test_database_url(self) -> str:
        """Returns explicitly set TEST_DATABASE_URL or constructs asyncpg connection URL for test DB."""
        if self.TEST_DATABASE_URL:
            if self.TEST_DATABASE_URL.startswith("postgresql://"):
                return self.TEST_DATABASE_URL.replace("postgresql://", "postgresql+asyncpg://", 1)
            return self.TEST_DATABASE_URL

        host = "localhost" if self.POSTGRES_HOST == "postgres" else self.POSTGRES_HOST
        port = 5433 if host == "localhost" else self.POSTGRES_PORT
        return (
            f"postgresql+asyncpg://{self.POSTGRES_USER}:{self.POSTGRES_PASSWORD}"
            f"@{host}:{port}/{self.POSTGRES_TEST_DB}"
        )

    @property
    def is_production(self) -> bool:
        return self.APP_ENV.lower() in ("production", "prod")


settings = Settings()
