# Contributing to CineConnect

Thank you for contributing to CineConnect! To maintain high code quality, system stability, and smooth multi-developer collaboration, all team members are required to follow these guidelines.

---

## 1. Branching Strategy

The repository follows a clean Git feature-branching workflow:

- **`main`**: The primary stable shared branch. Production and staging releases branch from `main`. Direct commits to `main` are strictly protected and prohibited.
- **Feature Branches**: Dedicated branches for independent unit work, branched off `main`.

### Branch Naming Conventions
Use standardized prefixes:

| Branch Pattern | Purpose | Example |
|---|---|---|
| `feature/frontend-*` | Mobile client UI and client state features | `feature/frontend-login-ui` |
| `feature/backend-*` | FastAPI endpoints, services, or business logic | `feature/backend-auth-service` |
| `feature/database-*` | Database models, schemas, and Alembic migrations | `feature/database-users-table` |
| `feature/integration-*` | Cross-stack or third-party service integrations | `feature/integration-s3-upload` |
| `bugfix/*` | Non-critical bug repairs on existing features | `bugfix/fix-null-pointer-profile` |
| `hotfix/*` | Urgent patches directly applied to production | `hotfix/cors-origin-fix` |

---

## 2. Standard Development Workflow

1. **Pull Latest Main**:
   ```bash
   git checkout main
   git pull origin main
   ```

2. **Create a Feature Branch**:
   ```bash
   git checkout -b feature/backend-user-registration
   ```

3. **Develop & Test Locally**:
   - Write clean, documented code adhering to `.editorconfig`.
   - Ensure all automated tests pass before committing.

4. **Run Quality Verification**:
   - For Mobile:
     ```bash
     cd mobile
     flutter analyze
     flutter test
     ```
   - For Backend:
     ```bash
     cd backend
     pytest -v
     ```

5. **Commit Changes**:
   Follow conventional commits format:
   ```bash
   git commit -m "feat(auth): add password hashing and user model"
   ```

6. **Push Branch & Open a Pull Request (PR)**:
   ```bash
   git push -u origin feature/backend-user-registration
   ```
   - Navigate to GitHub and open a Pull Request targeting `main`.
   - Complete the PR template describing the feature, testing steps, and relevant issue numbers.

---

## 3. Commit Message Conventions

We use standard Conventional Commits (`type(scope): description`):

- `feat`: A new user-facing or backend feature.
- `fix`: A bug fix.
- `docs`: Documentation updates only.
- `style`: Changes that do not affect the meaning of the code (whitespace, formatting).
- `refactor`: A code change that neither fixes a bug nor adds a feature.
- `test`: Adding missing tests or correcting existing tests.
- `chore`: Build process, dependency updates, or auxiliary tool configuration.

### Examples
- `feat(api): implement /api/v1/auth/register endpoint`
- `fix(mobile): resolve android emulator connection timeout`
- `docs(setup): clarify windows python virtual environment activation`

---

## 4. Code Review Requirements

All pull requests require:
1. **At least 1 approving review** from a fellow team developer.
2. **All automated CI checks passing** (Flutter analyze/test, Pytest, Docker build).
3. **No merge conflicts** with `main`.
4. **No committed secrets**: Any PR containing `.env`, tokens, credentials, or private keys will be immediately closed.

---

## 5. Definition of Done (DoD)

A feature is considered done when:
- Code compiles without warnings (`flutter analyze` has 0 issues).
- Unit and integration tests cover new logic.
- Documentation in `docs/` is updated if APIs or architecture changed.
- Migrations are committed if database schemas were modified.

