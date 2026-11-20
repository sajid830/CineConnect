# CineConnect — Group 3C.3: Public Media Cleanup Implementation Report
**Reference-Aware Public Media Cleanup & Advisory Locking**

## 1. Executive Summary

In MinIO Group 3C.3, we implemented reference-aware, race-safe cleanup of public media objects stored in `cineconnect-public`.

Prior to this task, deleting or updating records in `portfolio_media`, `posts`, or `production_houses` removed the database record or updated the column, but left the corresponding media objects permanently orphaned in MinIO.

We implemented:
1. A multi-table, four-field public media reference counter: `count_public_media_references`.
2. Dedicated public media transactional advisory locking under namespace `"cineconnect:public-media:"`.
3. An unreferenced public media cleanup service: `cleanup_unreferenced_public_media`.
4. Public media ownership and existence validation: `validate_public_media_ownership`.
5. Full concurrency and lifecycle protection across all portfolio, post, and production house creation, replacement, and deletion endpoints.
6. A 21-scenario test suite in `backend/tests/api/test_public_media_cleanup.py` proving mutual exclusion and reference safety.
7. 100% test pass rate across the entire CineConnect test suite (281 passed, 1 skipped).

Zero database migrations, zero schema changes, and zero external infrastructure dependencies (such as Redis or Celery) were introduced.

---

## 2. Public Media Reference Counter (`count_public_media_references`)

Located in `backend/app/services/storage.py`:

```python
async def count_public_media_references(
    db: AsyncSession,
    file_key_or_url: str,
    exclude_portfolio_id: Optional[uuid.UUID] = None,
    exclude_post_id: Optional[uuid.UUID] = None,
    exclude_ph_id: Optional[uuid.UUID] = None,
) -> int
```

### Verification Logic
1. **Canonical Normalization**: Uses `parse_storage_url()` and `extract_file_key()` to convert full URLs (`http://localhost:9000/cineconnect-public/media/...`) and relative keys (`media/...`) into exact canonical keys.
2. **Bucket Isolation**: Rejects external URLs (YouTube, Vimeo) and private bucket media (`cineconnect-private`), immediately returning 0.
3. **Escaped SQL LIKE Queries**: Escapes wildcards (`\`, `%`, `_`) to safely query candidate rows.
4. **All Four Fields Inspected**:
   - `PortfolioMedia.media_url`
   - `PortfolioMedia.thumbnail_url`
   - `Post.media_url`
   - `ProductionHouse.logo_url`
5. **Exact Python Verification**: Every candidate row undergoes Python-level `extract_file_key()` verification for exact key equality, eliminating false positive substring matches.
6. **Dual-Field Record Safety**: An item having identical `media_url` and `thumbnail_url` counts as two references. If only one field is cleared on update, the other retains the object.
7. **Cross-Model Reference Counting**: If an object is referenced as a post image and as a portfolio media asset, both tables contribute to `total_refs`.
8. **Fail-Closed Guarantee**: Database exceptions propagate and are never interpreted as 0 references.

---

## 3. Public Media Advisory Locking

Located in `backend/app/services/storage.py`:

- `get_public_media_advisory_lock_id(canonical_key: str) -> int`:
  Derives a signed 64-bit integer from `hashlib.sha256("cineconnect:public-media:" + clean_key)`.
  This guarantees complete separation from the private application media lock namespace (`"cineconnect:application-media:"`).
- `acquire_public_media_advisory_lock(db: AsyncSession, canonical_key: str) -> Optional[int]`:
  Executes `SELECT pg_advisory_xact_lock(:lock_id)` bound to the current database transaction.
- `acquire_public_media_advisory_locks(db: AsyncSession, file_keys_or_urls: Iterable[Optional[str]]) -> List[int]`:
  Filters for internal public bucket keys, deduplicates identical keys, and acquires locks in deterministic alphabetical order (`sorted(canonical_keys)`), eliminating cyclic wait conditions and deadlocks.

---

## 4. Protected Endpoints Across Lifecycle

### 4.1 Portfolio Workflows (`backend/app/api/v1/endpoints/portfolio.py`)
- **Creation (`POST /`)**: Locks candidate keys, validates ownership & existence in `cineconnect-public` via `validate_public_media_ownership()`, inserts and commits.
- **Update (`PUT /{media_id}`)**: Captures old `media_url` and `thumbnail_url`, locks new keys, validates, updates and commits, then calls `cleanup_unreferenced_public_media()` on replaced or cleared old URLs.
- **Deletion (`DELETE /{media_id}`)**: Captures old `media_url` and `thumbnail_url`, deletes database row and commits, then calls `cleanup_unreferenced_public_media([old_media_url, old_thumb_url])`.

### 4.2 Post Workflows (`backend/app/api/v1/endpoints/posts.py`)
- **Creation (`POST /`)**: Locks `post_in.media_url`, validates public ownership & existence, inserts and commits.
- **Update (`PUT /{post_id}`)**: Captures old `media_url`, locks new `media_url`, validates, updates and commits, then cleans up old URL if replaced or cleared.
- **Deletion (`DELETE /{post_id}`)**: Captures old `media_url`, deletes row and commits, then cleans up old URL.

### 4.3 Production House Workflows (`backend/app/api/v1/endpoints/production_houses.py`)
- **Creation (`POST /`)**: If `logo_url` provided, locks, validates public ownership & existence, inserts and commits.
- **Update (`PUT /me`)**: Captures old `logo_url`, locks new `logo_url`, validates, updates and commits, then cleans up old logo if replaced or cleared.

---

## 5. Transaction Boundaries & Lock Scope

1. **Attachment Transactions**: Advisory locks are acquired at the start of endpoint execution before validation. Locks are held continuously through PostgreSQL `commit()`. Any concurrent cleanup waiting for the lock is serialized and will observe the newly committed reference upon waking.
2. **Deletion & Replacement Transactions**:
   - The database record modification is committed **first**.
   - `cleanup_unreferenced_public_media()` runs inside `media_transaction_scope(db)`.
   - The advisory lock is acquired on the candidate key before reference counting and held through MinIO deletion.
   - The transaction commits, releasing the lock.
3. **Storage Outage Resilience**: If MinIO is unreachable during cleanup, a warning is logged. The user's already-committed database operation (row deletion or update) is never rolled back or broken.

---

## 6. Concurrency Test Results

Located in `backend/tests/api/test_public_media_cleanup.py`:

| # | Test Case | Description | Result |
| :- | :--- | :--- | :-: |
| 1 | `test_delete_unshared_portfolio_item_cleans_up_storage` | Deleting unshared portfolio item deletes file from MinIO. | **PASSED** |
| 2 | `test_delete_shared_portfolio_item_retains_media` | Deleting shared portfolio item retains file in MinIO. | **PASSED** |
| 3 | `test_identical_media_and_thumbnail_deduplicated_and_deleted_once` | Identical media and thumbnail deleted exactly once. | **PASSED** |
| 4 | `test_replace_unshared_portfolio_media_cleans_up_old_object` | Replacing unshared portfolio media deletes old file. | **PASSED** |
| 5 | `test_replace_shared_portfolio_media_retains_old_object` | Replacing shared portfolio media retains old file. | **PASSED** |
| 6 | `test_clearing_unshared_thumbnail_cleans_up_storage` | Setting thumbnail to None deletes unreferenced thumbnail. | **PASSED** |
| 7 | `test_delete_unshared_post_cleans_up_storage` | Deleting unshared post deletes media from MinIO. | **PASSED** |
| 8 | `test_delete_post_with_shared_media_retains_storage` | Deleting shared post retains media in MinIO. | **PASSED** |
| 9 | `test_replace_post_media_cleans_up_old_object` | Replacing post media deletes old file from MinIO. | **PASSED** |
| 10 | `test_replace_production_house_logo_cleans_up_old_object` | Replacing PH logo deletes old logo from MinIO. | **PASSED** |
| 11 | `test_clear_production_house_logo_cleans_up_storage` | Clearing PH logo deletes old logo from MinIO. | **PASSED** |
| 12 | `test_cross_model_shared_media_retained` | Media shared between portfolio and post is retained. | **PASSED** |
| 13 | `test_external_urls_never_trigger_minio_deletion` | YouTube/Vimeo URLs bypass MinIO deletion cleanly. | **PASSED** |
| 14 | `test_unauthorized_deletion_never_triggers_minio_deletion` | Unauthorized delete returns 404 and does not delete file. | **PASSED** |
| 15 | `test_db_commit_failure_never_triggers_minio_deletion` | DB commit failure aborts without MinIO delete. | **PASSED** |
| 16 | `test_minio_deletion_failure_preserves_database_deletion` | MinIO timeout logs warning and preserves DB deletion. | **PASSED** |
| 17 | `test_failed_reference_query_never_triggers_deletion` | DB error during reference query aborts without MinIO delete. | **PASSED** |
| 18 | `test_concurrency_post_creation_and_portfolio_deletion_serialized` | 2 PostgreSQL sessions: post creation waits for portfolio cleanup lock. | **PASSED** |
| 19 | `test_concurrency_portfolio_creation_first_retains_object` | 2 PostgreSQL sessions: cleanup waits for portfolio creation lock. | **PASSED** |
| 20 | `test_concurrency_ph_logo_attachment_and_cleanup_serialized` | 2 PostgreSQL sessions: logo worker waits for cleanup lock. | **PASSED** |
| 21 | `test_multiple_public_media_keys_deterministic_sorted_lock_order` | Locks acquired in sorted alphabetical order. | **PASSED** |

---

## 7. Full Regression Results

- `test_public_media_cleanup.py`: 21 passed
- Combined media regression suites (162 tests): 162 passed in 29.83s
- Full CineConnect backend suite: **281 passed, 1 skipped in 42.27s** (100% pass rate)
