# CineConnect – Core Architecture & Foundation

> **Cross-Platform Mobile Platform for the Cinema & Creative Media Industry**

CineConnect connects actors, directors, technicians, crew members, production companies, and vendors into a single unified collaborative ecosystem.

This repository represents the **core architectural foundation** of the application, structured for multi-developer collaboration, automated testing, and scalable cloud migration.

---

## 1. Technology Stack

### Mobile Frontend
- **Framework**: [Flutter](https://flutter.dev) (Dart SDK 3.13+)
- **Platforms**: Android (API 21+) and iOS (iOS 12+)
- **Architecture**: Scalable Clean Architecture (App, Core, Features, Shared)
- **UI System**: Material 3 (Cinema Dark Theme with Cinematic Amber Accents)

### Backend Services
- **Framework**: [FastAPI](https://fastapi.tiangolo.com) (Python 3.12+)
- **Runtime**: High-concurrency ASGI server ([Uvicorn](https://www.uvicorn.org))
- **Validation**: [Pydantic v2](https://docs.pydantic.dev) & Pydantic Settings
- **ORM**: [SQLAlchemy 2.0](https://www.sqlalchemy.org) with asynchronous engine
- **Driver**: [asyncpg](https://github.com/MagicStack/asyncpg) for asynchronous PostgreSQL connectivity
- **Migrations**: [Alembic](https://alembic.sqlalchemy.org) with async execution runner

### Infrastructure & Persistence
- **Database**: PostgreSQL 16
- **Containerization**: Docker & Docker Compose
- **Storage**: Persistent named Docker volumes (`cineconnect_postgres_data`)
- **Networking**: Isolated bridge network (`cineconnect_network`)

---

## 2. Project Directory Structure

```
CineConnect/
│
├── mobile/                      # Flutter Cross-Platform Client
│   ├── lib/
│   │   ├── main.dart            # Flutter application entrypoint
│   │   ├── app/                 # App widget, routing, Material 3 theme
│   │   ├── core/                # Config (EnvConfig), constants, network client, logger
│   │   ├── features/            # Vertical domain feature modules (home, future features)
│   │   └── shared/              # Reusable models (HealthStatus), services, UI buttons
│   ├── assets/                  # Images, icons, fonts, animations
│   ├── test/                    # Widget and unit tests (widget_test.dart)
│   ├── android/                 # Android native runner configuration
│   ├── ios/                     # iOS native runner configuration
│   ├── pubspec.yaml             # Dart dependencies & assets manifest
│   └── analysis_options.yaml    # Flutter static analysis rules
│
├── backend/                     # FastAPI Asynchronous Service
│   ├── app/
│   │   ├── main.py              # Application lifecycle, CORS, exception handlers
│   │   ├── api/v1/              # Versioned API routes & health endpoints
│   │   ├── core/                # Config (Pydantic Settings), structured logging
│   │   ├── db/                  # Async session pool, base model, DB initialization
│   │   ├── models/              # SQLAlchemy 2.x ORM models
│   │   ├── schemas/             # Pydantic request/response schemas
│   │   ├── repositories/        # Database query abstractions
│   │   ├── services/            # Business logic handlers
│   │   └── utils/               # Shared utilities
│   ├── alembic/                 # Database migration scripts & async env.py
│   ├── tests/                   # Pytest automated test suite (test_health.py)
│   ├── alembic.ini              # Alembic migration configuration
│   ├── requirements.txt         # Pinned backend dependencies
│   ├── Dockerfile               # Production non-root multi-stage image
│   └── .dockerignore            # Build context exclusions
│
├── infrastructure/              # Docker & Deployment Configuration
│   ├── docker-compose.yml       # PostgreSQL 16 & FastAPI services definition
│   └── docker/
│       └── postgres/            # Database initialization scripts
│
├── docs/                        # Architectural & Team Documentation
│   ├── architecture.md          # Full system architecture & AWS cloud roadmap
│   ├── development-setup.md     # Local setup guide for Windows
│   ├── api-guidelines.md        # REST API conventions & error contracts
│   └── database-design.md       # Database naming standards & migration guides
│
├── .gitignore                   # Git exclusion rules (Python, Flutter, Docker, OS)
├── .editorconfig                # Multi-editor indentation and format standards
├── .env.example                 # Documented template for environment variables
├── CONTRIBUTING.md              # Git branching workflow and PR requirements
└── README.md                    # Primary repository overview
```

---

## 3. Quick Start Guide

### Step 1: Clone & Configure Environment
```bash
git clone <repository-url>
cd CineConnect

# Create your local environment configuration file
cp .env.example .env
```

### Step 2: Start Infrastructure with Docker
Ensure Docker Desktop is running:
```bash
cd infrastructure
docker compose up --build -d
```
Verify container health:
```bash
docker compose ps
```
The services will be reachable at:
- Backend Health: http://localhost:8000/health
- API v1 Health: http://localhost:8000/api/v1/health
- Database Health Check: http://localhost:8000/api/v1/health/db
- Interactive Swagger UI: http://localhost:8000/docs
- Interactive ReDoc: http://localhost:8000/redoc

### Step 3: Run the Flutter Mobile App
In a separate terminal:
```bash
cd mobile
flutter pub get
```

#### On Android Emulator:
The Android emulator reaches the host backend via `10.0.2.2:8000` (built into `EnvConfig`):
```bash
flutter run
```

#### On Physical Android Device:
Pass your computer's local Wi-Fi IP address:
```bash
flutter run --dart-define=API_BASE_URL=http://<YOUR-LAN-IP>:8000
```

---

## 4. Running Tests

### Mobile Automated Tests (Flutter)
```bash
cd mobile
flutter analyze      # Verify zero lint/analysis issues
flutter test         # Execute widget and unit test suites
```

### Backend Automated Tests (FastAPI / Pytest)
```bash
cd backend
# With virtual environment activated:
pytest -v
```

---

## 5. Alembic Database Migrations

To create and apply schema migrations:
```bash
cd backend

# Create autogenerated migration from ORM models:
alembic revision --autogenerate -m "describe changes"

# Apply all migrations to the database:
alembic upgrade head

# Rollback one migration step:
alembic downgrade -1
```

---

## 6. Development Rules & Contributing
- Direct commits to `main` are prohibited.
- Create feature branches adhering to `feature/frontend-*`, `feature/backend-*`, or `feature/database-*`.
- Review the complete guidelines in [CONTRIBUTING.md](CONTRIBUTING.md).
- Follow the detailed guides in the `docs/` folder:
  - [Architecture Overview](docs/architecture.md)
  - [Local Setup Guide](docs/development-setup.md)
  - [API Guidelines](docs/api-guidelines.md)
  - [Database Design & Migrations](docs/database-design.md)

