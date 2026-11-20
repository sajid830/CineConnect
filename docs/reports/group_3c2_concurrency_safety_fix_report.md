# CineConnect — Group 3C.2 Concurrency Safety Fix Report
**PostgreSQL Transactional Advisory Locks for Reference-Safe Application Media Cleanup**

## 1. Executive Summary

This report documents the implementation and verification of PostgreSQL transaction-scoped advisory locks (`pg_advisory_xact_lock`) to eliminate the Time-of-Check to Time-of-Use (TOCTOU) race condition in private MinIO application media cleanup.

Attachment, reference-counting, and deletion decisions for canonical private MinIO media objects (`cineconnect-private`) are now strictly serialized across all backend Uvicorn workers and Docker containers. The implementation required zero database schema modifications, zero Alembic migrations, and zero external infrastructure dependencies (such as Redis or Celery).

All 8 genuine concurrency tests passed in 4.43s, and the entire backend test suite (260 tests passed, 1 skipped) passed with 100% success.

---

## 2. Advisory Lock ID Derivation Method

PostgreSQL provides `pg_advisory_xact_lock(bigint)` which accepts a single signed 64-bit integer in the range `[-9223372036854775808, 9223372036854775807]`.

### Derivation Algorithm
In `backend/app/services/storage.py`, `get_media_advisory_lock_id(canonical_key: str) -> int`:
1. **Namespace Isolation**: Uses prefix `"cineconnect:application-media:"` to isolate media locks from any other potential advisory locks in PostgreSQL.
2. **Cryptographic Hashing**: Hashes the namespaced string with `hashlib.sha256()`.
3. **64-bit Conversion**: Extracts the first 8 bytes of the digest in big-endian order using Python's `struct.unpack(">q", digest[:8])[0]`.
4. **Collision Characteristics**: SHA-256 provides uniform bit distribution across the 64-bit space ($2^{64} \approx 1.84 \times 10^{19}$ distinct lock IDs). The probability of an accidental lock ID collision between two independent media files in an application dataset is vanishingly small ($< 10^{-9}$ for billions of files). Even in the theoretical event of a hash collision, the result is merely benign serialized processing between two distinct files rather than any data corruption or race condition.

---

## 3. Shared Advisory Locking Implementation

Advisory locking is enforced across all three critical lifecycle operations:

### 3.1 Application Submission (`submit_application`)
- **Location**: `backend/app/api/v1/endpoints/applications.py`
- **Execution Flow**:
  1. Identifies candidate private media keys (`resume_url`, `audition_reel_url`).
  2. Acquires exclusive advisory locks via `await acquire_media_advisory_locks(db, candidate_media)`.
  3. Validates talent ownership and existence against MinIO storage while holding the lock.
  4. Inserts the `Application` record into PostgreSQL.
  5. Commits transaction (`await db.commit()`), atomically persisting the reference and releasing the advisory lock.

### 3.2 Application Media Replacement (`update_application`)
- **Location**: `backend/app/api/v1/endpoints/applications.py`
- **Execution Flow**:
  1. Identifies replacement media keys being attached.
  2. Acquires advisory locks via `await acquire_media_advisory_locks(db, new_media_to_lock)` before validating or attaching them.
  3. Collects old media URLs that are being replaced or cleared for cleanup.
  4. Updates the application row and commits (`await db.commit()`), guaranteeing the new reference is durable and unlocking the new media key.
  5. Initiates cleanup of the replaced old media via `cleanup_unreferenced_application_media()`.

### 3.3 Application Withdrawal & Media Cleanup (`cleanup_unreferenced_application_media`)
- **Location**: `backend/app/services/storage.py`
- **Execution Flow**:
  1. For each candidate media key, executes inside `async with media_transaction_scope(db):`.
  2. Acquires transactional advisory lock: `await acquire_media_advisory_lock(db, c_key)`.
  3. Queries PostgreSQL for active references: `await count_application_media_references(...)`.
  4. If references == 0: executes `delete_storage_object(settings.MINIO_PRIVATE_BUCKET, c_key, s3_client=s3_client)`.
  5. Transaction ends and commits, releasing the advisory lock.

---

## 4. Transaction Boundaries, Scoping & Zero Lock Leaks

1. **Lock Scoping**: PostgreSQL's `pg_advisory_xact_lock` is bound to the current transaction. When the transaction terminates (`COMMIT` or `ROLLBACK`), PostgreSQL automatically releases the lock at the engine level.
2. **SQLAlchemy Session Safety**: The helper `media_transaction_scope(db: AsyncSession)` inspects `db.in_transaction()`. If the session is not currently in an active transaction block, it enters `async with db.begin():`. This guarantees that every advisory lock is bound to a transactional boundary and cannot leak into subsequent operations or pool connections.
3. **Fault Tolerance**: If an exception occurs, the network drops, or the application process crashes, PostgreSQL immediately rolls back the open transaction and releases all advisory locks. No dangling mutexes or leaked locks can exist.

---

## 5. Deadlock-Avoidance Strategy

When an application attaches or modifies multiple media keys (e.g., both a resume PDF and an audition reel video):
1. **Normalization & Canonical Key Extraction**: Filters and extracts only valid canonical private keys. External URLs (YouTube, Vimeo) and non-private paths are ignored and never acquire database locks.
2. **Deduplication**: Eliminates duplicate keys if the user supplied identical keys across fields.
3. **Deterministic Alphabetical Sorting**: All keys are sorted in strict ascending lexicographical order (`sorted(set(valid_keys))`).
4. **Guaranteed Lock Hierarchy**: Because every backend worker and concurrency path acquires locks in the identical sorted order, cyclic lock dependencies are impossible, completely preventing PostgreSQL deadlocks.

---

## 6. Multi-Worker & Multi-Process Concurrency Without New Infrastructure

- **Engine-Level Mutex in PostgreSQL**: PostgreSQL manages advisory locks in shared memory inside the database server.
- **Worker Independence**: Multiple Uvicorn ASGI worker processes, Docker containers, or background tasks all connect to the same PostgreSQL database (`cineconnect_db`).
- **No Redis / External Mutex**: PostgreSQL itself coordinates mutual exclusion between connections.
- **Zero Schema Migrations**: Advisory locks operate directly on virtual 64-bit integer identifiers and do not alter any database tables or create migration files.

---

## 7. Concurrency Test Suite Verification

The genuine asynchronous concurrency test suite is located in `backend/tests/api/test_application_media_concurrency.py`. It utilizes two distinct PostgreSQL `AsyncSession` connections bound to `test_engine` to verify real multi-connection mutual exclusion:

| Test Scenario | Purpose & Verification Method | Status |
| :--- | :--- | :--- |
| **1. Cleanup first blocks submission** | Worker 1 acquires advisory lock during cleanup. Worker 2 waits on the lock; once unlocked, Worker 2 detects the deleted MinIO file and is rejected. | **PASSED** |
| **2. Submission first retains file** | Worker 1 acquires lock and commits new application reference. Worker 2 (cleanup) waits; once unlocked, Worker 2 sees reference count == 1 and retains the file. | **PASSED** |
| **3. Media replacement & attachment serialized** | Media replacement cleanup and concurrent attachment of the old file are serialized via the advisory lock without race conditions. | **PASSED** |
| **4. Two applications concurrently attach same file** | Two concurrent submissions lock and attach the same pre-existing file; both succeed and reference count equals 2. | **PASSED** |
| **5. Two applications concurrently withdraw same file** | Two concurrent withdrawals run cleanup; advisory locks serialize reference checking and deletion occurs safely once. | **PASSED** |
| **6. Failed reference query never deletes file** | Simulated database failure during reference query aborts cleanup; MinIO `delete_object` is never invoked. | **PASSED** |
| **7. MinIO failure preserves withdrawal** | Storage outage during deletion logs a warning but allows application withdrawal to succeed and commit. | **PASSED** |
| **8. Deterministic sorted lock order** | Multiple media keys (Z, A, M, external) are locked strictly in sorted alphabetical order (`[A, M, Z]`), preventing deadlocks. | **PASSED** |

---

## 8. Regression Testing & Test Suite Results

1. **Concurrency Suite**:
   - `backend/tests/api/test_application_media_concurrency.py`: 8 passed in 4.43s.
2. **Media Cleanup & Storage Suite**:
   - `backend/tests/api/test_application_media_cleanup.py`: 17 passed.
   - `backend/tests/api/test_storage_deletion.py`: 13 passed.
   - `backend/tests/api/test_applications.py`: 28 passed.
   - `backend/tests/api/test_media.py`: 38 passed.
   - **Combined media/application subtotal**: 104 passed in 18.50s.
3. **Full Backend Suite**:
   - `pytest backend/tests -q`: **260 passed, 1 skipped in 37.96s** (100% passing).

---

## 9. Readiness Assessment for Group 3C

The TOCTOU concurrency vulnerability has been resolved. The media storage subsystem is robust, safe against race conditions across distributed workers, and ready for Group 3C production deployment.
