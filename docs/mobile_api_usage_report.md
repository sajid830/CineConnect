# CineConnect Mobile API Usage Report

**Prepared for:** CineConnect Backend Team  
**Date:** 20 November 2026  
**Scope:** Full repository inspection (`mobile/`, `backend/`, `docs/`)  
**Purpose:** Document which APIs the Flutter client uses, where they are called, and where the mobile and backend contracts do not match.

---

## 1. Executive Summary

| Metric | Count |
|---|---:|
| REST APIs actively called by the mobile app | **3** |
| User-triggered APIs | **2** |
| Startup/background API | **1** |
| WebSocket APIs actively used | **0** |
| Endpoint paths defined in mobile `ApiEndpoints` | **55** |
| Service methods implemented in `TalentApiService` | **33** |
| Unique endpoint paths with a service method | **31** |
| Endpoint definitions with no service method | **24** |
| Backend operations available | **96** |
| Backend REST operations under `/api/v1` | **94** |
| Backend root HTTP operations | **1** (`GET /health`) |
| Backend WebSocket operations | **1** (`/ws/chat`) |
| Third-party APIs integrated | **0** |

**Bottom line:** The mobile app has a large API catalog and service layer, but only three backend operations are actually invoked. Of those, one is a startup health check and two are user actions. Both user actions currently fail against the backend because the app sends non-UUID mock IDs, and one also sends the wrong field name. Authentication is also not wired, so protected endpoints return `401` before validation.

---

## 2. Runtime API Configuration

### 2.1 Base URL

Defined in `mobile/lib/core/network/api_endpoints.dart`:

| Environment | Base URL |
|---|---|
| Override | `--dart-define=API_BASE_URL=<url>` |
| Flutter Web | `http://localhost:8000` |
| Android emulator | `http://10.0.2.2:8000` |
| iOS simulator / macOS | `http://127.0.0.1:8000` |
| Fallback | `http://localhost:8000` |

API prefix: `/api/v1`

### 2.2 Request defaults

Implemented in `mobile/lib/core/network/api_client.dart`:

- HTTP client: `package:http`
- `Content-Type: application/json`
- `Accept: application/json`
- Auth header when a token exists: `Authorization: Bearer <token>`
- Request timeout: **10 seconds**
- Error handling:
  - `401` → authentication required / token expired
  - `403` → forbidden
  - `404` → not found
  - `422` → validation error
  - Other non-2xx → `HTTP Error <code>`
  - Network failure → `ApiException(statusCode: 0, ...)`

### 2.3 Authentication state

`TalentApiService.authenticateWithSupabaseToken(String token)` exists, but **it is never called anywhere in the mobile app**.

Consequences:

- `ApiClient._authToken` remains `null`.
- All protected backend endpoints return `401 Unauthorized`.
- The app hides this because API exceptions are swallowed in `CineAppState`.
- No Supabase SDK or token storage is present in `pubspec.yaml`; only `http` is used.

### 2.4 Response handling

- The app does not parse any API response into Dart models.
- `GET /api/v1/health` is reduced to a boolean.
- The other two active API responses are discarded.
- All screens render hardcoded mock data from `CineAppState`.
- There is no WebSocket client, even though the backend exposes `/ws/chat`.

---

## 3. API Counts

### 3.1 Mobile endpoint catalog by module

`mobile/lib/core/network/api_endpoints.dart` contains 55 endpoint definitions:

| Module | Endpoint definitions | Active |
|---|---:|---:|
| Health | 3 | 1 |
| Users / Talent Profiles | 9 | 0 |
| Projects | 4 | 0 |
| Opportunities | 3 | 0 |
| Applications | 3 | 1 |
| Portfolio | 3 | 0 |
| Posts | 3 | 0 |
| Interactions | 4 | 0 |
| Connections | 6 | 1 |
| Collaborations | 4 | 0 |
| Messages | 6 | 0 |
| Search & Notifications | 5 | 0 |
| Media | 1 | 0 |
| Dashboard | 1 | 0 |
| **Total** | **55** | **3** |

### 3.2 Mobile service layer

`mobile/lib/core/services/talent_api_service.dart` implements 33 methods covering 34 HTTP operations:

- `updateProfile()` can issue either `PUT /users/me` or `PATCH /users/me`.
- `getFeedPosts()` and `createFeedPost()` share `/posts/`.
- `getMyProfile()` and `updateProfile()` share `/users/me`.
- `getMyApplications()` and `withdrawApplication()` use different paths.

### 3.3 Backend coverage

| Backend module | Backend operations | Referenced by mobile | Actively called |
|---|---:|---:|---:|
| Health | 2 | 2 | 1 |
| Root health | 1 | 1 | 0 |
| Users | 11 | 11 | 0 |
| Production Houses | 8 | 0 | 0 |
| Projects | 10 | 4 | 0 |
| Opportunities | 10 | 3 | 0 |
| Applications | 7 | 3 | 1 |
| Portfolio | 5 | 3 | 0 |
| Posts | 8 | 4 | 0 |
| Interactions | 5 | 3 | 0 |
| Connections | 7 | 6 | 1 |
| Collaborations | 7 | 4 | 0 |
| Messages | 6 | 5 | 0 |
| Search | 1 | 1 | 0 |
| Notifications | 4 | 4 | 0 |
| Media | 1 | 1 | 0 |
| Dashboard | 2 | 1 | 0 |
| WebSocket | 1 | 1 | 0 |
| **Total** | **96** | **57** | **3** |

Note: “Referenced” is counted by HTTP method + path. The mobile catalog contains 55 paths, but some paths cover multiple verbs.

---

## 4. Active APIs in Detail

## 4.1 `GET /api/v1/health`

**Status:** Active, startup/background  
**Purpose:** Backend connectivity check.

**Call chain:**

1. `CineAppState()` constructor
2. `_initConnectivityCheck()`
3. `TalentApiService.checkBackendHealth()`
4. `ApiClient.get('/api/v1/health')`

**Trigger:** App launch, before login.

**Authentication:** None.

**Request:**

```http
GET /api/v1/health
```

**Backend response (`200`):**

```json
{
  "status": "healthy",
  "service": "cineconnect-backend",
  "environment": "local",
  "version": "1.0.0",
  "timestamp": "2026-11-20T10:00:00+00:00"
}
```

**Client behavior:**

- Any non-null response is treated as connected.
- Exceptions are caught and converted to `false`.
- `isBackendConnected` is stored but never displayed in the UI.

**File references:**

- Mobile: `mobile/lib/core/state/app_state.dart:33-40`
- Mobile: `mobile/lib/core/services/talent_api_service.dart:18-25`
- Mobile: `mobile/lib/core/network/api_endpoints.dart:27`
- Backend: `backend/app/api/v1/endpoints/health.py:20-33`

---

## 4.2 `POST /api/v1/applications/`

**Status:** Active, user-triggered  
**Purpose:** Submit a one-tap application to a casting opportunity.

**Call chain:**

1. Opportunities tab
2. Job card → “Apply with Self-Tape”
3. Self-tape dialog → “Submit 1-Tap Application”
4. `CineAppState.applyToJob(job.id)`
5. `TalentApiService.applyForOpportunity(opportunityId: jobId)`
6. `ApiClient.post('/api/v1/applications/')`

**Authentication:** Required, Talent role only (`require_talent`).

**Current mobile request body:**

```json
{
  "opportunity_id": "job-101"
}
```

Optional fields supported by the mobile method but not currently passed:

```json
{
  "self_tape_url": "...",
  "notes": "..."
}
```

**Backend contract (`ApplicationCreate`):**

```json
{
  "opportunity_id": "123e4567-e89b-12d3-a456-426614174000",
  "cover_letter": "Optional text",
  "resume_url": "Optional URL",
  "reel_url": "Optional URL"
}
```

**Backend response (`201 Created`):**

```json
{
  "id": "uuid",
  "opportunity_id": "uuid",
  "talent_id": "uuid",
  "status": "submitted",
  "cover_letter": "text or null",
  "resume_url": "url or null",
  "reel_url": "url or null",
  "created_at": "datetime",
  "updated_at": "datetime"
}
```

**Current result against backend:**

| Condition | Result |
|---|---|
| No auth token | `401 Unauthorized` |
| Mock ID `job-101` | `422 Unprocessable Entity` (`opportunity_id` must be UUID) |
| Valid token + real UUID | `201 Created` |
| Duplicate application | `409 Conflict` |
| Opportunity not open | `400 Bad Request` |
| Opportunity not found | `404 Not Found` |

**Important contract issue:** `self_tape_url` and `notes` are not fields in the backend schema. Pydantic ignores them, so the self-tape and notes are silently lost even when the request succeeds.

**Client behavior:** Errors are swallowed. The local mock job is always marked as applied, the applicant count is incremented, and a success snackbar is shown regardless of the actual HTTP result.

**File references:**

- Mobile UI: `mobile/lib/features/jobs/naukri_casting_board.dart:89-110`
- Mobile state: `mobile/lib/core/state/app_state.dart:620-637`
- Mobile service: `mobile/lib/core/services/talent_api_service.dart:77-88`
- Backend route: `backend/app/api/v1/endpoints/applications.py:23-65`
- Backend schema: `backend/app/schemas/application.py:7-37`

---

## 4.3 `POST /api/v1/connections/`

**Status:** Active, user-triggered  
**Purpose:** Send a peer connection / collaboration request.

**Call chain:**

1. Search / Network tab
2. Open a peer slate
3. “Send collaboration request”
4. `CineAppState.togglePeerConnection(peer.id)`
5. `TalentApiService.sendConnectionRequest(talentId)`
6. `ApiClient.post('/api/v1/connections/')`

**Authentication:** Required, any authenticated user (`get_current_user`).

**Current mobile request body:**

```json
{
  "target_user_id": "talent-1"
}
```

**Backend contract (`ConnectionCreate`):**

```json
{
  "receiver_id": "123e4567-e89b-12d3-a456-426614174000"
}
```

**Backend response (`201 Created`):**

```json
{
  "id": "uuid",
  "sender_id": "uuid",
  "receiver_id": "uuid",
  "status": "pending",
  "created_at": "datetime",
  "updated_at": "datetime"
}
```

**Current result against backend:**

| Condition | Result |
|---|---|
| No auth token | `401 Unauthorized` |
| Wrong field `target_user_id` | `422 Unprocessable Entity` (`receiver_id` required) |
| Mock ID `talent-1` | `422 Unprocessable Entity` (`receiver_id` must be UUID) |
| Valid token + real UUID + `receiver_id` | `201 Created` |
| Existing connection | `409 Conflict` |
| Target user not found | `404 Not Found` |

**Client behavior:** Errors are swallowed. The UI always flips the peer to connected and increments the connection count regardless of the actual HTTP result.

**File references:**

- Mobile UI: `mobile/lib/features/radar/talent_network_radar.dart:244-256`
- Mobile state: `mobile/lib/core/state/app_state.dart:639-656`
- Mobile service: `mobile/lib/core/services/talent_api_service.dart:172-174`
- Backend route: `backend/app/api/v1/endpoints/connections.py:16-58`
- Backend schema: `backend/app/schemas/connection.py:6-18`

---

## 5. Full Mobile Endpoint Catalog

Legend:

- **ACTIVE** — called from the app.
- **SERVICE_ONLY** — service method exists, but no UI/state caller invokes it.
- **CATALOG_ONLY** — endpoint constant exists, but no service method uses it.
- **INVALID** — path does not exist on the backend.

| # | Module | Method | Path | Service method | Status |
|---:|---|---|---|---|---|
| 1 | Health | GET | `/health` | — | CATALOG_ONLY |
| 2 | Health | GET | `/api/v1/health` | `checkBackendHealth` | **ACTIVE** |
| 3 | Health | GET | `/api/v1/health/db` | — | CATALOG_ONLY |
| 4 | Users | GET / PUT / PATCH | `/api/v1/users/me` | `getMyProfile`, `updateProfile` | SERVICE_ONLY |
| 5 | Users | GET | `/api/v1/users/{userId}` | `getPeerProfile` | SERVICE_ONLY |
| 6 | Users | GET | `/api/v1/users` | `listPeers` | SERVICE_ONLY |
| 7 | Users | GET | `/api/v1/users/search` | `searchPeers` | SERVICE_ONLY |
| 8 | Users | GET | `/api/v1/users/{userId}/portfolio` | — | CATALOG_ONLY |
| 9 | Users | GET | `/api/v1/users/{userId}/posts` | — | CATALOG_ONLY |
| 10 | Users | GET | `/api/v1/users/{userId}/connections` | — | CATALOG_ONLY |
| 11 | Users | GET | `/api/v1/users/{userId}/followers` | — | CATALOG_ONLY |
| 12 | Users | GET | `/api/v1/users/{userId}/following` | — | CATALOG_ONLY |
| 13 | Projects | GET | `/api/v1/projects` | — | CATALOG_ONLY |
| 14 | Projects | GET | `/api/v1/projects/{projectId}` | — | CATALOG_ONLY |
| 15 | Projects | GET | `/api/v1/projects/search` | — | CATALOG_ONLY |
| 16 | Projects | GET | `/api/v1/projects/{projectId}/opportunities` | — | CATALOG_ONLY |
| 17 | Opportunities | GET | `/api/v1/opportunities/` | `getOpportunities` | SERVICE_ONLY |
| 18 | Opportunities | GET | `/api/v1/opportunities/{oppId}` | `getOpportunityDetails` | SERVICE_ONLY |
| 19 | Opportunities | GET | `/api/v1/opportunities/search` | `searchOpportunities` | SERVICE_ONLY |
| 20 | Applications | POST | `/api/v1/applications/` | `applyForOpportunity` | **ACTIVE** |
| 21 | Applications | GET | `/api/v1/applications/my` | `getMyApplications` | SERVICE_ONLY |
| 22 | Applications | DELETE | `/api/v1/applications/{appId}` | `withdrawApplication` | SERVICE_ONLY |
| 23 | Portfolio | POST | `/api/v1/portfolio/` | `addPortfolioMedia` | SERVICE_ONLY |
| 24 | Portfolio | GET | `/api/v1/portfolio/my` | `getMyPortfolio` | SERVICE_ONLY |
| 25 | Portfolio | DELETE | `/api/v1/portfolio/{mediaId}` | `deletePortfolioMedia` | SERVICE_ONLY |
| 26 | Posts | GET / POST | `/api/v1/posts/` | `getFeedPosts`, `createFeedPost` | SERVICE_ONLY |
| 27 | Posts | GET | `/api/v1/posts/{postId}` | — | CATALOG_ONLY |
| 28 | Posts | GET | `/api/v1/posts/my` | — | CATALOG_ONLY |
| 29 | Interactions | POST | `/api/v1/interactions/` | `interactWithPost` | SERVICE_ONLY |
| 30 | Interactions | GET | `/api/v1/interactions/my` | — | CATALOG_ONLY |
| 31 | Interactions | GET | `/api/v1/interactions/{interactionId}` | — | CATALOG_ONLY |
| 32 | Interactions | GET | `/api/v1/interactions/posts/{postId}/interactions` | — | **INVALID** |
| 33 | Connections | POST | `/api/v1/connections/` | `sendConnectionRequest` | **ACTIVE** |
| 34 | Connections | GET | `/api/v1/connections/my` | `getMyConnections` | SERVICE_ONLY |
| 35 | Connections | GET | `/api/v1/connections/requests` | `getConnectionRequests` | SERVICE_ONLY |
| 36 | Connections | PATCH | `/api/v1/connections/{connId}/accept` | `acceptConnectionRequest` | SERVICE_ONLY |
| 37 | Connections | PATCH | `/api/v1/connections/{connId}/reject` | `rejectConnectionRequest` | SERVICE_ONLY |
| 38 | Connections | DELETE | `/api/v1/connections/{connId}` | — | CATALOG_ONLY |
| 39 | Collaborations | GET | `/api/v1/collaborations/my` | `getMyCollaborations` | SERVICE_ONLY |
| 40 | Collaborations | GET | `/api/v1/collaborations/{collabId}` | — | CATALOG_ONLY |
| 41 | Collaborations | PATCH | `/api/v1/collaborations/{collabId}/accept` | `acceptCollaboration` | SERVICE_ONLY |
| 42 | Collaborations | PATCH | `/api/v1/collaborations/{collabId}/reject` | `rejectCollaboration` | SERVICE_ONLY |
| 43 | Messages | POST | `/api/v1/messages/` | `sendDirectMessage` | SERVICE_ONLY |
| 44 | Messages | GET | `/api/v1/messages/conversations` | `listConversations` | SERVICE_ONLY |
| 45 | Messages | GET | `/api/v1/messages/conversations/{userId}` | `getConversationMessages` | SERVICE_ONLY |
| 46 | Messages | GET | `/api/v1/messages/{msgId}` | — | CATALOG_ONLY |
| 47 | Messages | GET | `/api/v1/messages/unread-count` | — | CATALOG_ONLY |
| 48 | Messages | WS | `/ws/chat?token=` | — | CATALOG_ONLY |
| 49 | Search | GET | `/api/v1/search/` | — | CATALOG_ONLY |
| 50 | Notifications | GET | `/api/v1/notifications/` | `getNotifications` | SERVICE_ONLY |
| 51 | Notifications | GET | `/api/v1/notifications/unread-count` | — | CATALOG_ONLY |
| 52 | Notifications | PATCH | `/api/v1/notifications/{notifId}/read` | — | CATALOG_ONLY |
| 53 | Notifications | PATCH | `/api/v1/notifications/read-all` | `markAllNotificationsRead` | SERVICE_ONLY |
| 54 | Media | POST | `/api/v1/media/upload-url` | `requestPresignedUploadUrl` | SERVICE_ONLY |
| 55 | Dashboard | GET | `/api/v1/dashboard/talent` | `getTalentDashboard` | SERVICE_ONLY |

---

## 6. Backend Route Inventory

Total: **96 operations** = 94 REST operations under `/api/v1` + 1 root HTTP health check + 1 WebSocket.

### Health — 2 operations

- `GET /api/v1/health`
- `GET /api/v1/health/db`

### Root — 1 operation

- `GET /health`

### WebSocket — 1 operation

- `WS /ws/chat?token=<jwt>`

### Users — 11 operations

- `GET /api/v1/users/me`
- `PUT /api/v1/users/me`
- `PATCH /api/v1/users/me`
- `GET /api/v1/users/search`
- `GET /api/v1/users/{user_id}`
- `GET /api/v1/users`
- `GET /api/v1/users/{user_id}/portfolio`
- `GET /api/v1/users/{user_id}/posts`
- `GET /api/v1/users/{user_id}/connections`
- `GET /api/v1/users/{user_id}/followers`
- `GET /api/v1/users/{user_id}/following`

### Production Houses — 8 operations

- `POST /api/v1/production-houses`
- `GET /api/v1/production-houses/me`
- `PUT /api/v1/production-houses/me`
- `GET /api/v1/production-houses/search`
- `GET /api/v1/production-houses/{house_id}`
- `GET /api/v1/production-houses`
- `GET /api/v1/production-houses/{house_id}/projects`
- `GET /api/v1/production-houses/{house_id}/opportunities`

### Projects — 10 operations

- `POST /api/v1/projects`
- `GET /api/v1/projects/my`
- `GET /api/v1/projects/search`
- `GET /api/v1/projects/{project_id}`
- `PUT /api/v1/projects/{project_id}`
- `PATCH /api/v1/projects/{project_id}`
- `DELETE /api/v1/projects/{project_id}`
- `GET /api/v1/projects`
- `GET /api/v1/projects/{project_id}/opportunities`
- `GET /api/v1/projects/{project_id}/collaborations`

### Opportunities — 10 operations

- `POST /api/v1/opportunities/`
- `GET /api/v1/opportunities/my`
- `GET /api/v1/opportunities/search`
- `GET /api/v1/opportunities/`
- `GET /api/v1/opportunities/{opportunity_id}`
- `PUT /api/v1/opportunities/{opportunity_id}`
- `PATCH /api/v1/opportunities/{opportunity_id}`
- `DELETE /api/v1/opportunities/{opportunity_id}`
- `GET /api/v1/opportunities/{opportunity_id}/applications`
- `PATCH /api/v1/opportunities/{opportunity_id}/status`

### Applications — 7 operations

- `POST /api/v1/applications/`
- `GET /api/v1/applications/my`
- `GET /api/v1/applications/`
- `GET /api/v1/applications/{application_id}`
- `PATCH /api/v1/applications/{application_id}`
- `DELETE /api/v1/applications/{application_id}`
- `PATCH /api/v1/applications/{application_id}/status`

### Portfolio — 5 operations

- `POST /api/v1/portfolio/`
- `GET /api/v1/portfolio/my`
- `GET /api/v1/portfolio/{media_id}`
- `PUT /api/v1/portfolio/{media_id}`
- `DELETE /api/v1/portfolio/{media_id}`

### Posts — 8 operations

- `POST /api/v1/posts/`
- `GET /api/v1/posts/my`
- `GET /api/v1/posts/`
- `GET /api/v1/posts/{post_id}`
- `PUT /api/v1/posts/{post_id}`
- `DELETE /api/v1/posts/{post_id}`
- `GET /api/v1/posts/{post_id}/interactions`
- `POST /api/v1/posts/{post_id}/interactions`

### Interactions — 5 operations

- `POST /api/v1/interactions/`
- `GET /api/v1/interactions/my`
- `GET /api/v1/interactions/{interaction_id}`
- `PATCH /api/v1/interactions/{interaction_id}`
- `DELETE /api/v1/interactions/{interaction_id}`

### Connections — 7 operations

- `POST /api/v1/connections/`
- `GET /api/v1/connections/my`
- `GET /api/v1/connections/requests`
- `GET /api/v1/connections/{connection_id}`
- `PATCH /api/v1/connections/{connection_id}/accept`
- `PATCH /api/v1/connections/{connection_id}/reject`
- `DELETE /api/v1/connections/{connection_id}`

### Collaborations — 7 operations

- `POST /api/v1/collaborations/`
- `GET /api/v1/collaborations/my`
- `GET /api/v1/collaborations/{collaboration_id}`
- `PATCH /api/v1/collaborations/{collaboration_id}/accept`
- `PATCH /api/v1/collaborations/{collaboration_id}/reject`
- `PATCH /api/v1/collaborations/{collaboration_id}/status`
- `DELETE /api/v1/collaborations/{collaboration_id}`

### Messages — 6 operations

- `POST /api/v1/messages/`
- `GET /api/v1/messages/conversations`
- `GET /api/v1/messages/conversations/{user_id}`
- `GET /api/v1/messages/unread-count`
- `GET /api/v1/messages/{message_id}`
- `DELETE /api/v1/messages/{message_id}`

### Search — 1 operation

- `GET /api/v1/search/`

### Notifications — 4 operations

- `GET /api/v1/notifications/`
- `GET /api/v1/notifications/unread-count`
- `PATCH /api/v1/notifications/read-all`
- `PATCH /api/v1/notifications/{notification_id}/read`

### Media — 1 operation

- `POST /api/v1/media/upload-url`

### Dashboard — 2 operations

- `GET /api/v1/dashboard/talent`
- `GET /api/v1/dashboard/production-house`

---

## 7. Contract Mismatches and Blockers

### Critical

| # | Issue | Mobile | Backend | Effect |
|---:|---|---|---|---|
| 1 | Auth token never set | `authenticateWithSupabaseToken()` is never called | Protected routes require Bearer JWT | All protected calls return `401` |
| 2 | Mock IDs are not UUIDs | Sends `job-101`, `talent-1` | `opportunity_id` and `receiver_id` are `UUID` | `422` validation failure |
| 3 | Connection field name mismatch | `target_user_id` | `receiver_id` | `422` validation failure |
| 4 | No response parsing | Responses discarded | Returns typed JSON | Backend changes cannot be verified through the app |

### High

| # | Issue | Mobile | Backend | Effect |
|---:|---|---|---|---|
| 5 | Application field names | `self_tape_url`, `notes` | `reel_url`, `cover_letter` | Self-tape and notes silently dropped |
| 6 | Message body field | `content` | `body` | `422` missing `body` |
| 7 | Post create fields | `content`, `video_slate_title`, `smpte_timecode`, `tags` | `caption`, `media_url` | `422` missing `caption` |
| 8 | Media upload field | `filename` | `file_name` | `422` missing `file_name` |
| 9 | Invalid interactions path | `/api/v1/interactions/posts/{postId}/interactions` | `/api/v1/posts/{post_id}/interactions` | `404` |

### Medium

| # | Issue | Mobile | Backend | Effect |
|---:|---|---|---|---|
| 10 | Interaction fields | `timecode`, `note` | `comment` | Critique text dropped |
| 11 | Portfolio fields | `craft`, `smpte_timecode` | `media_type`, `description`, `thumbnail_url` | Extra fields dropped |
| 12 | Opportunity filters | `page`, `craft`, `hub` | `skip`, `role_type`, `location`, `status`, `limit` | Filters and pagination ignored |
| 13 | User list filters | `page`, `craft` | `skip`, `account_type`, `limit` | Filters and pagination ignored |
| 14 | Post pagination | `page` | `skip` | Page parameter ignored |
| 15 | User search response | Expects a list | Returns `{items, total}` | Not consumed today; would break future wiring |
| 16 | Application detail | Mobile uses DELETE only | Backend also supports GET/PATCH | Unused backend capability |
| 17 | Portfolio detail | Mobile uses DELETE only | Backend also supports GET/PUT | Unused backend capability |

---

## 8. Backend Team Action Checklist

1. Decide the final authentication handoff. The mobile app needs a Supabase JWT injected into `TalentApiService.authenticateWithSupabaseToken()` after login.
2. Confirm whether mock IDs will be replaced with backend UUIDs before API integration.
3. Change mobile `sendConnectionRequest` payload from `target_user_id` to `receiver_id`.
4. Map mobile application fields:
   - `self_tape_url` → `reel_url`
   - `notes` → `cover_letter`
5. Align message payload: `content` → `body`.
6. Align post payload: `content` → `caption`; decide where `video_slate_title`, `smpte_timecode`, and `tags` belong.
7. Align media upload payload: `filename` → `file_name`; optionally add `file_size_bytes`.
8. Fix interaction payload: `note` → `comment`; decide whether `timecode` is supported.
9. Fix or remove `/api/v1/interactions/posts/{postId}/interactions`; use `/api/v1/posts/{post_id}/interactions`.
10. Standardize pagination: mobile uses `page`; backend uses `skip`.
11. Standardize opportunity filters: mobile uses `craft` and `hub`; backend uses `role_type` and `location`.
12. Add response DTO mapping in mobile before enabling the unused service methods.
13. Confirm production `API_BASE_URL` and HTTPS; current defaults are local HTTP.
14. Confirm whether WebSocket chat is in scope; the mobile client currently has no WebSocket implementation.

---

## 9. API-Related File Reference Map

### Mobile

| File | Role |
|---|---|
| `mobile/lib/core/network/api_endpoints.dart` | 55 endpoint definitions, base URL, WebSocket URL |
| `mobile/lib/core/network/api_client.dart` | HTTP wrapper, headers, auth token, timeout, errors |
| `mobile/lib/core/services/talent_api_service.dart` | 33 API service methods |
| `mobile/lib/core/state/app_state.dart` | Health call, apply call, connection call, mock data |
| `mobile/lib/features/jobs/naukri_casting_board.dart` | Application UI trigger at line 96 |
| `mobile/lib/features/radar/talent_network_radar.dart` | Connection UI trigger at line 248 |
| `mobile/lib/app/app.dart` | App shell and state ownership |
| `mobile/lib/main.dart` | App entrypoint |
| `mobile/pubspec.yaml` | `http: ^1.6.0`; no Supabase/Firebase SDK |
| `mobile/test/widget_test.dart` | UI tests; no HTTP mocking |

### Backend

| File | Role |
|---|---|
| `backend/app/main.py` | App setup, root health, WebSocket route, CORS, exception handlers |
| `backend/app/api/v1/api.py` | v1 router aggregation |
| `backend/app/api/dependencies.py` | JWT auth and role guards |
| `backend/app/api/websocket.py` | Chat WebSocket protocol |
| `backend/app/api/v1/endpoints/*.py` | 94 REST route handlers across 16 modules |
| `backend/app/schemas/*.py` | Request/response contracts |
| `backend/app/core/config.py` | API prefix, CORS, JWT, MinIO, DB settings |
| `backend/tests/verify_all_apis.py` | End-to-end API verification suite |

### Documentation

| File | Role |
|---|---|
| `docs/api-guidelines.md` | REST conventions and error envelope |
| `docs/architecture.md` | System architecture |
| `docs/database-design.md` | Database conventions |
| `docs/talent_api_integration_report.md` | Empty file |

---

## 10. Verification Notes

- All Dart files under `mobile/lib` and `mobile/test` were searched for network usage. Only `api_client.dart`, `api_endpoints.dart`, `talent_api_service.dart`, and `app_state.dart` perform or define HTTP work.
- No direct `http` calls exist in feature widgets.
- No Supabase, Firebase, Dio, GraphQL, gRPC, or third-party API client is present.
- Backend route counts were derived from every `@router.<method>` decorator plus the root `/health` and `/ws/chat` routes.
- The mobile test suite does not exercise real HTTP; it runs against mock state.
