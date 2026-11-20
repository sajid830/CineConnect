# CineConnect — MinIO Group 3C.4: Account Deletion and Media Cleanup Read-Only Audit Report

**Date**: 2026-11-19  
**Audit Status**: Complete (Strictly Read-Only — Zero Code Changes, Zero Database Changes, Zero MinIO Object Changes)  
**System**: CineConnect FastAPI Backend, PostgreSQL Async SQLAlchemy, MinIO Object Storage (`cineconnect-public`, `cineconnect-private`)

---

## Executive Summary

This read-only audit investigates the lifecycle of MinIO media objects when a user account is deleted in CineConnect. It analyzes database foreign-key cascade behaviors, media reference tracking, multi-tenant ownership boundaries, transactional advisory locking, and failure modes across both `cineconnect-public` and `cineconnect-private` buckets.

### Key Audit Finding
**There is currently NO account deletion endpoint (`DELETE /api/v1/users/me` or similar) implemented in the CineConnect backend.**  
All current deletion endpoints are strictly entity-scoped (`/applications/{id}`, `/portfolio/{id}`, `/posts/{id}`, `/opportunities/{id}`, `/projects/{id}`, etc.). If an account were deleted directly in the database (or if an account deletion endpoint is introduced), PostgreSQL `ON DELETE CASCADE` rules would immediately purge related database rows. Unless candidate MinIO media keys are **pre-captured before the database delete statement is executed**, the URLs pointing to MinIO objects are completely lost, permanently orphaning the underlying storage objects in MinIO. Furthermore, when a Production House account is deleted, cascading deletion of its opportunities and applications must **never** delete Talent-owned resumes or reels that are still owned by the applicant.

---

## 1. Exact Files Inspected

The following files were inspected to establish actual code behavior and database relationships:

1. **Endpoint Modules**:
   - `backend/app/api/v1/endpoints/users.py`: Audited all user endpoints; confirmed absence of user account deletion endpoints (`DELETE /me` or `DELETE /{user_id}`).
   - `backend/app/api/v1/endpoints/applications.py`: Inspected private application media handling (`resume_url`, `reel_url`), reference counting, and lock patterns.
   - `backend/app/api/v1/endpoints/portfolio.py`: Inspected public media handling (`media_url`, `thumbnail_url`) and cleanup integration.
   - `backend/app/api/v1/endpoints/posts.py`: Inspected post media handling (`media_url`) and cleanup integration.
   - `backend/app/api/v1/endpoints/production_house.py`: Inspected company logo handling (`logo_url`) and cleanup integration.
   - `backend/app/api/v1/endpoints/media.py`: Inspected upload presigning, key prefixes, and metadata validation.
2. **Database Models & ORM Definitions**:
   - `backend/app/models/user.py`: Audited `User` model, relationships, and SQLAlchemy `cascade="all, delete-orphan"` definitions.
   - `backend/app/models/portfolio.py`: Audited `PortfolioMedia` table, foreign keys (`user_id` with `ondelete="CASCADE"`).
   - `backend/app/models/social.py`: Audited `Post` table, foreign keys (`user_id` with `ondelete="CASCADE"`), `Connection`, `Interaction`.
   - `backend/app/models/production_house.py`: Audited `ProductionHouse` table, `Project` table, `user_id` foreign keys with `ondelete="CASCADE"`.
   - `backend/app/models/opportunity.py`: Audited `Opportunity` and `Application` tables, foreign keys (`talent_id`, `opportunity_id` with `ondelete="CASCADE"`).
   - `backend/app/models/message.py`: Audited `Message` table and foreign keys.
   - `backend/app/models/notification.py`: Audited `Notification` table and foreign keys.
3. **Storage & Advisory Lock Services**:
   - `backend/app/services/storage.py`: Audited `extract_storage_key_from_url`, `delete_storage_object`, `count_application_media_references`, `acquire_media_advisory_locks`, `count_public_media_references`, `acquire_public_media_advisory_locks`.
   - `backend/app/services/__init__.py`: Verified public export interfaces for media cleanup.
4. **Test Suites**:
   - `backend/tests/api/test_users.py`: Verified existing user test coverage (profile, update, search).
   - `backend/tests/api/test_application_media_cleanup.py`: Audited private cleanup unit and integration tests.
   - `backend/tests/api/test_public_media_cleanup.py`: Audited public cleanup unit and integration tests.

---

## 2. Account Deletion Endpoint and Transaction Flow

### Current Reality
- In `backend/app/api/v1/endpoints/users.py`, the available routes are:
  - `GET /me`, `PUT /me`, `PATCH /me`
  - `GET /search`, `GET /{user_id}`, `GET /`
  - `GET /{user_id}/portfolio`, `GET /{user_id}/posts`, `GET /{user_id}/connections`, `GET /{user_id}/followers`, `GET /{user_id}/following`
- There is **no `DELETE /me` or administrative `DELETE /users/{id}` endpoint**.
- If a user row is deleted via direct SQL execution (`DELETE FROM users WHERE id = :user_id`), PostgreSQL executes foreign-key cascades automatically.

### Recommended Transaction Flow for Future Implementation
To prevent orphaning objects or prematurely deleting shared objects, the deletion lifecycle must strictly follow this phased sequence:

```
[Incoming DELETE /api/v1/users/me]
                │
                ▼
1. Authenticate user & start DB Transaction (session)
                │
                ▼
2. PRE-CAPTURE CANDIDATE MEDIA KEYS (Read Phase)
   - Query all User's PortfolioMedia (media_url, thumbnail_url)
   - Query all User's Posts (media_url)
   - Query User's ProductionHouse (logo_url)
   - IF User is Talent: Query all User's Applications (resume_url, reel_url)
   - Extract canonical keys and segregate into:
       * candidate_public_keys
       * candidate_private_keys
                │
                ▼
3. ACQUIRE ADVISORY LOCKS
   - acquire_public_media_advisory_locks(candidate_public_keys)
   - acquire_media_advisory_locks(candidate_private_keys)
   (Locks held within PostgreSQL transaction; sorted to prevent deadlocks)
                │
                ▼
4. DELETE USER RECORD IN DATABASE
   - db.delete(user)
   - SQLAlchemy & PostgreSQL ON DELETE CASCADE purges:
     portfolio_media, posts, applications, production_house, etc.
                │
                ▼
5. VERIFY REMAINING REFERENCES (Post-Delete Reference Check)
   - For each candidate_public_key:
       count_public_media_references(session, key)
       If count == 0 -> mark for MinIO deletion
   - For each candidate_private_key:
       count_application_media_references(session, key)
       If count == 0 -> mark for MinIO deletion
                │
                ▼
6. COMMIT DATABASE TRANSACTION
   - await db.commit()
   - DB state is finalized; locks automatically release upon commit.
                │
                ▼
7. EXECUTE MINIO OBJECT DELETION (Post-Commit)
   - For each verified unreferenced public key:
       delete_storage_object(settings.MINIO_PUBLIC_BUCKET, key)
   - For each verified unreferenced private key:
       delete_storage_object(settings.MINIO_PRIVATE_BUCKET, key)
   - Tolerate MinIO errors (log warnings; do not abort user deletion)
                │
                ▼
8. Return 204 No Content / Success Response
```

---

## 3. Complete List of Media-Reference Fields Affected by Account Deletion

| Model / Table | Attribute Name | Column Name | Target MinIO Bucket | Description |
| :--- | :--- | :--- | :--- | :--- |
| `Application` (`applications`) | `resume_url` | `resume_url` | `cineconnect-private` | Talent's uploaded resume (PDF/DOCX) |
| `Application` (`applications`) | `reel_url` | `reel_url` | `cineconnect-private` | Talent's uploaded audition reel (video) |
| `PortfolioMedia` (`portfolio_media`) | `media_url` | `media_url` | `cineconnect-public` | Public portfolio file (photo, video reel, audio) |
| `PortfolioMedia` (`portfolio_media`) | `thumbnail_url` | `thumbnail_url` | `cineconnect-public` | Generated or uploaded thumbnail for portfolio file |
| `Post` (`posts`) | `media_url` | `media_url` | `cineconnect-public` | Public feed attachment (photo/video) |
| `ProductionHouse` (`production_houses`) | `logo_url` | `logo_url` | `cineconnect-public` | Official production house logo image |

*Note on Profile Pictures*: `User.profile_image_url` is currently defined in schemas (`backend/app/schemas/user.py`), but the database model `User` (`backend/app/models/user.py`) does not contain a `profile_image_url` column. If a avatar/profile picture column is added to `User` in the future, it must be included in the public media pre-capture set.

---

## 4. Cascade Relationship Analysis

### A. Direct User Children Cascades (`User` in `backend/app/models/user.py`)
- `User.production_house`: `relationship("ProductionHouse", back_populates="user", uselist=False, cascade="all, delete-orphan")`
  - DDL: `ForeignKey("users.id", ondelete="CASCADE")`
- `User.portfolio_items`: `relationship("PortfolioMedia", back_populates="user", cascade="all, delete-orphan")`
  - DDL: `ForeignKey("users.id", ondelete="CASCADE")`
- `User.posts`: `relationship("Post", back_populates="user", cascade="all, delete-orphan")`
  - DDL: `ForeignKey("users.id", ondelete="CASCADE")`
- `User.applications`: `relationship("Application", back_populates="talent", cascade="all, delete-orphan")`
  - DDL: `ForeignKey("users.id", ondelete="CASCADE")` (on `talent_id`)
- `User.following_connections` / `follower_connections`: `cascade="all, delete-orphan"`
  - DDL: `ForeignKey("users.id", ondelete="CASCADE")`
- `User.sent_messages` / `received_messages`: `cascade="all, delete-orphan"`
  - DDL: `ForeignKey("users.id", ondelete="CASCADE")`
- `User.notifications`: `cascade="all, delete-orphan"`
  - DDL: `ForeignKey("users.id", ondelete="CASCADE")`
- `User.collaborations`: `cascade="all, delete-orphan"`
  - DDL: `ForeignKey("users.id", ondelete="CASCADE")`

### B. Grandchild Cascades (Through `ProductionHouse`)
- `ProductionHouse.projects`: `cascade="all, delete-orphan"`
  - DDL: `ForeignKey("production_houses.id", ondelete="CASCADE")`
- `Project.opportunities`: `cascade="all, delete-orphan"`
  - DDL: `ForeignKey("projects.id", ondelete="CASCADE")`
- `Opportunity.applications`: `cascade="all, delete-orphan"`
  - DDL: `ForeignKey("opportunities.id", ondelete="CASCADE")`

### Critical Consequence of Cascade Chain
If a Production House deletes its user account:
`User` -> deletes `ProductionHouse` -> deletes `Project` -> deletes `Opportunity` -> deletes all `Application` records submitted by various Talents!
If the system blindly collected all media keys from cascading application deletions and deleted them from MinIO, **it would delete Talent-owned resumes and audition reels from the private bucket**, corrupting active files belonging to innocent Talents.

---

## 5. Shared-Media and Ownership Risks

1. **Talent Resume & Reel Ownership vs Opportunity/Production House Deletion**:
   - `Application.resume_url` and `Application.reel_url` belong to the **Talent** who uploaded them (stored under prefix `resumes/{talent_id}/...` or `auditions/{talent_id}/...`).
   - If a Production House deletes their account, the associated `Application` rows are deleted via cascade. **The underlying MinIO files must NOT be deleted.** The talent may still use that resume/reel for other applications or future submissions.
   - Deletion of private application media must **only** be triggered if the **Talent** account is being deleted, and **only** if no other application records in the database reference that file.
2. **Identical Public Media Reuse Across Posts/Portfolios**:
   - A user could paste the same public media URL into multiple posts, or use the same URL for both a portfolio media entry and a post.
   - Another user could conceivably share or re-post a public URL (or an admin could reference a corporate asset).
   - Because `count_public_media_references()` aggregates across `PortfolioMedia.media_url`, `PortfolioMedia.thumbnail_url`, `Post.media_url`, and `ProductionHouse.logo_url`, public objects are only deleted if the count drops to exactly 0 across the entire database.
3. **Cross-Tenant Malicious Linking**:
   - An attacker could observe a public media URL from user A and attach it to user B's post. If user B deletes their account, user A's media could be deleted if reference counting was not database-wide.
   - Because `count_public_media_references` performs a full union count across all users and models, user A's post/portfolio keeps the reference count > 0, preventing deletion.

---

## 6. Public and Private Cleanup Requirements

1. **Bucket Separation**:
   - Resumes and reels belong strictly to `settings.MINIO_PRIVATE_BUCKET` (`cineconnect-private`).
   - Portfolio items, thumbnails, posts, and logos belong strictly to `settings.MINIO_PUBLIC_BUCKET` (`cineconnect-public`).
   - Keys must never be evaluated against or deleted from the wrong bucket.
2. **Canonical Key Extraction**:
   - All URLs must pass through `extract_storage_key_from_url(url, expected_bucket)`.
   - External URLs (e.g. YouTube links, AWS S3 URLs, Vimeo links) must return `None` and be skipped with zero errors.
   - Malformed URLs (traversal paths, empty keys, invalid bucket names) must return `None` and be ignored safely.
3. **Reference Counting Segregation**:
   - Private media keys must be verified using `count_application_media_references(session, key)`.
   - Public media keys must be verified using `count_public_media_references(session, key)`.

---

## 7. Advisory-Lock and Concurrency Requirements

To avoid Time-Of-Check to Time-Of-Use (TOCTOU) race conditions during account deletion:

1. **Namespace Preservation**:
   - Private application media locks must strictly use namespace:
     `"cineconnect:application-media:"` (managed by `acquire_media_advisory_locks`).
   - Public media locks must strictly use namespace:
     `"cineconnect:public-media:"` (managed by `acquire_public_media_advisory_locks`).
2. **Deadlock Avoidance**:
   - Both lock helpers sort keys lexicographically before taking locks via `pg_advisory_xact_lock(hashtext(:lock_str))`.
   - During account deletion, public locks must be acquired in sorted order, followed by private locks in sorted order.
3. **Lock Scope & Lifetime**:
   - Locks are transaction-scoped (`pg_advisory_xact_lock`).
   - They must be acquired **before** `db.delete(user)` and held until `await db.commit()`.
   - While held, concurrent workers attempting to attach the same media key to a new application, post, portfolio, or logo will serialize and wait, ensuring they cannot attach to an object being verified for deletion.

---

## 8. Failure Handling and Transaction Boundaries

1. **Database Deletion Failure**:
   - If an exception occurs during `db.delete(user)` or `await db.commit()` (e.g. database disconnect, integrity violation), the transaction is rolled back via `await db.rollback()`.
   - The advisory locks are instantly released by PostgreSQL.
   - No post-commit cleanup is invoked; **zero MinIO objects are deleted**.
2. **MinIO Service Unavailable Post-Commit**:
   - If MinIO is down or unreachable (e.g. HTTP 503, connection timeout) when `delete_storage_object` is called post-commit:
     - The database transaction has already committed; the user account remains deleted.
     - The deletion service catches the MinIO client exception, logs a high-severity warning with the bucket and object key, and continues.
     - The API endpoint returns a successful deletion response to the client (204 No Content).
     - The un-deleted MinIO object is recorded in logs for background reconciliation/tombstone cleanup.
3. **Reference Counting Query Failure**:
   - If a reference counting query throws an error or fails, the candidate key must default to **still referenced** (or abort the transaction), ensuring that an object is never deleted on error.

---

## 9. Missing Tests

The audit identified the following missing tests that should be implemented when the account deletion feature is built:

1. **Account Deletion Endpoint Tests**:
   - No tests exist because `DELETE /api/v1/users/me` does not exist.
2. **Pre-Capture Verification**:
   - Test verifying that candidate public and private keys are extracted prior to database cascade.
3. **Talent Deletion Cleanup Test**:
   - Test verifying that deleting a Talent account deletes their portfolio files and thumbnails from `cineconnect-public` and their sole-referenced resumes from `cineconnect-private`.
4. **Talent Resume Multi-Application Reference Test**:
   - Test where Talent applies to Opportunity A and Opportunity B with the same resume key. Opportunity A was deleted, but Talent account deletion occurs with no other applications remaining -> verifies private file is cleaned up.
5. **Production House Cascade Protection Test**:
   - Test verifying that when a Production House account is deleted:
     - The Production House logo is deleted from `cineconnect-public`.
     - The cascading deletion of projects, opportunities, and applications does **NOT** delete the Talent's resume or audition reel from `cineconnect-private`.
6. **Concurrent Attachment vs Account Deletion Test**:
   - Concurrency test verifying that advisory locking prevents another worker from attaching to a candidate key while an account deletion is in flight.
7. **MinIO Outage Resilience Test**:
   - Test simulating MinIO failure during post-commit cleanup; verifying that DB account deletion commits successfully without crashing or returning a 500 error.

---

## 10. Phased Implementation Recommendation

### Phase 1: Account Deletion Endpoint Design & Candidate Pre-Capture
- Implement `DELETE /api/v1/users/me` in `backend/app/api/v1/endpoints/users.py`.
- Query and extract candidate keys for the user:
  - Public keys: `PortfolioMedia.media_url`, `PortfolioMedia.thumbnail_url`, `Post.media_url`, `ProductionHouse.logo_url`.
  - Private keys: Only if user is Talent (`Application.resume_url`, `Application.reel_url` joined on `Application.talent_id == user.id`).
  - Do NOT query applications if the deleted user is a Production House.

### Phase 2: Dual Advisory Locking & Cascade Commit
- Call `acquire_public_media_advisory_locks(db, candidate_public_keys)`.
- Call `acquire_media_advisory_locks(db, candidate_private_keys)`.
- Execute `await db.delete(user)`.
- Perform post-cascade reference counting in the same transaction:
  - `count_public_media_references(db, key)`
  - `count_application_media_references(db, key)`
- Execute `await db.commit()`.

### Phase 3: Post-Commit MinIO Cleanup & Telemetry
- Iterate through confirmed unreferenced public keys -> `delete_storage_object(settings.MINIO_PUBLIC_BUCKET, key)`.
- Iterate through confirmed unreferenced private keys -> `delete_storage_object(settings.MINIO_PRIVATE_BUCKET, key)`.
- Log all cleanup actions and catch MinIO errors with warning logs.

### Phase 4: Comprehensive Test Suite
- Add unit and integration tests in `backend/tests/api/test_account_deletion_media_cleanup.py`.
- Test role-specific behaviors (Talent vs Production House vs Admin).
- Verify mock MinIO deletion calls and assert that zero Talent files are touched on Production House deletion.

---

## Answers to User Questions

1. **Which database rows are deleted directly or through cascading when a user account is deleted?**  
   Directly: `users`.  
   Cascading via SQLAlchemy/PostgreSQL `ON DELETE CASCADE`: `portfolio_media`, `posts`, `interactions`, `connections`, `messages`, `notifications`, `collaborations`, `applications` (where user is talent), and `production_houses`. If a `production_houses` row is deleted, it cascades to `projects`, which cascades to `opportunities`, which cascades to all `applications` submitted for those opportunities.

2. **Which MinIO objects could become unreferenced?**  
   - Files in `cineconnect-public`: `PortfolioMedia.media_url`, `PortfolioMedia.thumbnail_url`, `Post.media_url`, and `ProductionHouse.logo_url`.  
   - Files in `cineconnect-private`: `Application.resume_url` and `Application.reel_url` belonging to the deleted Talent, provided no other applications reference those identical files.

3. **Can an object be shared across multiple database rows or models?**  
   Yes. A public media file or thumbnail can be reused across multiple portfolio entries or posts. A private resume or reel can be attached to multiple applications submitted by the talent to different opportunities.

4. **Can Talent-owned resumes or reels be referenced by applications belonging to multiple Production Houses?**  
   Yes. When a Talent submits the same resume or reel to multiple casting calls hosted by different Production Houses, each application record stores the same MinIO URL.

5. **Can public media be referenced by another user's portfolio, post, or Production House?**  
   Yes. The schema does not enforce single-user uniqueness on URLs; a URL could be duplicated or cross-referenced across different users or models.

6. **Does the current account-deletion workflow capture media keys before database cascades remove the references?**  
   No, because **no account-deletion workflow currently exists**. If a user row were deleted directly in the database today, cascading foreign keys would immediately delete all child records, permanently erasing the URLs before any keys could be captured.

7. **Can a cleanup operation safely run after the account deletion commits?**  
   Yes, provided candidate keys are **pre-captured** and reference counts are verified **within the transaction before commit**. The actual `delete_storage_object` calls against MinIO should run strictly post-commit.

8. **How should public and private advisory locks be acquired without changing the existing lock namespaces?**  
   Candidate keys must be partitioned into public and private sets. The public keys are passed to `acquire_public_media_advisory_locks` (using namespace `"cineconnect:public-media:"`), and the private keys are passed to `acquire_media_advisory_locks` (using namespace `"cineconnect:application-media:"`). Both helpers sort keys lexicographically and take transaction-level advisory locks.

9. **What happens if MinIO is unavailable after the account deletion commits?**  
   The database transaction has already succeeded, so the account deletion remains permanent. The post-commit MinIO deletion call catches the client exception, logs a warning with the key and bucket details, and returns 204 to the user without failing the request.

10. **What happens if the database deletion fails?**  
    The database session rolls back automatically. All database records remain intact, advisory locks are immediately released by PostgreSQL, and **no MinIO objects are deleted**.

11. **Are external URLs, malformed keys, and private/public bucket boundaries handled safely?**  
    Yes. `extract_storage_key_from_url` validates bucket names, strips queries/fragments, checks for path traversal, and returns `None` for external domains (e.g. YouTube, Vimeo) or mismatched buckets, preventing erroneous deletion.

12. **Are there objects that cannot be reliably attributed to the deleted account?**  
    Yes. Resumes and audition reels attached to applications under a deleted Production House belong to Talents, not the Production House. They cannot be attributed to the Production House and must not be cleaned up when a Production House account is deleted. Additionally, if orphan objects exist in MinIO without any database record pointing to them, they cannot be attributed to an account deletion event and must be handled via scheduled storage reconciliation.

---

## Confirmation of Audit Guardrails

This audit was conducted strictly in read-only mode:
- **Zero code changes** were made.
- **Zero database changes or migrations** were made.
- **Zero MinIO objects or buckets** were created, modified, or deleted.
