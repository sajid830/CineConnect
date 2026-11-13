# CineConnect – System Architecture

## 1. Overview
CineConnect is a cross-platform mobile platform designed to connect talent, crews, production houses, and vendors across the cinema and creative media industry. 

This document outlines the foundation architecture spanning the Flutter mobile client, the asynchronous FastAPI backend, the PostgreSQL relational persistence layer, local Docker containerization, and future AWS cloud infrastructure.

```
┌─────────────────────────────────────────────────────────────┐
│                    Mobile Client (Flutter)                  │
│   (Dart, Android / iOS, Material 3, Clean Architecture)     │
└──────────────────────────────┬──────────────────────────────┘
                               │ HTTP / JSON (Port 8000)
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                 Backend API Gateway (FastAPI)               │
│  - Async ASGI Runtime (Uvicorn)                             │
│  - Pydantic Settings & Request Validation                   │
│  - API Versioning (/api/v1)                                 │
│  - CORS & Structured Error Handling                         │
└──────────────────────────────┬──────────────────────────────┘
                               │ Asyncpg Connection Pool
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                  Relational Database (PostgreSQL)           │
│  - SQLAlchemy 2.0 Async ORM                                 │
│  - Alembic Versioned Migrations                             │
│  - Named Persistent Volumes (postgres_data)                 │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Mobile Frontend Architecture (Flutter)

### Architectural Paradigm
The Flutter mobile application (`mobile/`) follows a scalable, feature-first clean architecture:

```
mobile/lib/
├── app/          # App initialization, routing, and Material 3 theme definitions
├── core/         # Cross-cutting infrastructural concerns
│   ├── config/   # Environment-specific configuration (local, dev, prod)
│   ├── constants/# Application-wide constants and timeouts
│   ├── errors/   # Typed exceptions and UI failures
│   ├── network/  # HTTP client wrapper, interceptors, and logging
│   ├── utils/    # Logging and formatters
│   └── widgets/  # Reusable primitives (loading indicator, error view)
├── features/     # Encapsulated vertical feature modules
│   └── <feature>/
│       ├── data/           # Remote data sources, repositories, DTO models
│       ├── domain/         # Entities and business use cases
│       └── presentation/   # State, UI widgets, screens
└── shared/       # Cross-feature models, services, and reusable design components
```

### Key Principles
1. **Separation of Concerns**: UI widgets never execute raw HTTP requests directly; calls pass through typed service/repository contracts.
2. **Environment Agnostic**: Runtime configuration is resolved through `--dart-define` (`APP_ENV`, `API_BASE_URL`), allowing seamless transitions between Android emulator (`10.0.2.2`), physical devices (LAN IP), and production domains.
3. **Design System**: Strict adherence to Material 3 with a dedicated Cinema Dark aesthetic (Slate, Amber/Gold accents) and accessible typography.

---

## 3. Backend Architecture (FastAPI)

### Layered Async Architecture
The backend (`backend/`) employs an asynchronous, dependency-injected design:

```
backend/app/
├── api/
│   └── v1/
│       ├── api.py           # Primary v1 router aggregator
│       └── endpoints/       # Route controllers (health, future features)
├── core/
│   ├── config.py            # Pydantic Settings reading .env / OS environment
│   └── logging.py           # Structured formatting with level filtering
├── db/
│   ├── base.py              # DeclarativeBase model registry
│   ├── session.py           # AsyncEngine & async_sessionmaker
│   └── init_db.py           # Startup verification & schema creation
├── models/                  # SQLAlchemy 2.x ORM database models
├── schemas/                 # Pydantic request/response validation schemas
├── repositories/            # Data access layer (async queries, filters)
├── services/                # Business logic orchestrators
└── utils/                   # Shared helpers and datetime utilities
```

### Key Capabilities
- **High Concurrency**: Built entirely on Python's `asyncio` event loop and `asyncpg` async PostgreSQL driver.
- **Dependency Injection**: Database sessions (`get_db`) are injected per-request and automatically cleaned up with rollback on unhandled errors.
- **Security by Default**:
  - CORS strictly configured via environment variables.
  - Exception handlers prevent leaking internal database schemas, credentials, or stack traces to clients.
  - Docker container operates as non-root `appuser`.

---

## 4. Database Architecture (PostgreSQL)

- **Engine**: PostgreSQL 16 (official Docker image).
- **Driver**: `asyncpg` accessed via `SQLAlchemy 2.0` asynchronous engine.
- **Connection Pool**:
  - `pool_size`: 10 connections.
  - `max_overflow`: 20 connections.
  - `pool_timeout`: 30 seconds.
  - `pool_recycle`: 1800 seconds (30 minutes) to eliminate stale connections.
  - `pool_pre_ping`: Active keepalive health ping before query execution.
- **Migrations**: Alembic with asynchronous `env.py` runner for automated schema generation and zero-downtime migrations.

---

## 5. Local Docker Infrastructure

The `infrastructure/docker-compose.yml` provides a reliable local reproduction of the production environment:
- **`postgres` container**: Runs PostgreSQL 16 with custom health checks (`pg_isready`). Stores data on a named volume (`postgres_data`) across container restarts.
- **`backend` container**: Builds the FastAPI application using `backend/Dockerfile`, waits for PostgreSQL to become healthy before launching, and maps port `8000`.
- **`cineconnect_network`**: An isolated bridge network enabling inter-container communication using DNS service names (`postgres:5432`).
- **Host Separation**: Flutter runs on the host machine / emulator to maintain full access to native graphics, hot reload, and emulator bridges.

---

## 6. Future AWS Cloud Migration Approach

When migrating from local Docker to AWS, the architecture maps directly to managed cloud services without requiring rewrites:

| Local Component | Target AWS Service | Migration Strategy |
|---|---|---|
| FastAPI Backend | AWS ECS (Fargate) or App Runner | Dockerfile deploys directly to ECR and runs serverless on Fargate behind an Application Load Balancer (ALB). |
| PostgreSQL | Amazon RDS for PostgreSQL | Replace `DATABASE_URL` with RDS endpoint; multi-AZ failover and automated automated snapshots. |
| Configuration | AWS Secrets Manager / SSM Parameter Store | Inject credentials at container startup via ECS task definitions. |
| Object Storage (Phase 3) | Amazon S3 + CloudFront CDN | Profile media, portfolio assets, and media streaming. |
| Caching (Phase 3) | Amazon ElastiCache (Redis) | Session tokens and job listing caching. |
| Search (Phase 6) | Amazon OpenSearch Service | Talent search, production job filters, and full-text matching. |
| CI/CD | GitHub Actions | Automated lint, test, Docker image build, and ECS rolling deployments. |

