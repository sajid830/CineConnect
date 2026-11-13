# CineConnect – REST API Design Guidelines

This document outlines the conventions, standards, and patterns for developing APIs across CineConnect.

---

## 1. API Versioning
All business and domain endpoints must reside under a versioned URL prefix:

`/api/v1/<resource>`

Only root health checks (`/health`) and OpenAPI metadata (`/docs`, `/redoc`, `/openapi.json`) are excluded from prefixing.

---

## 2. Resource Naming Conventions
- **Plural nouns** for collections (`/api/v1/users`, `/api/v1/productions`, `/api/v1/jobs`).
- **Kebab-case** for compound URL segments (`/api/v1/job-listings`, `/api/v1/crew-members`).
- **Standard HTTP verbs**:
  - `GET`: Retrieve a resource or collection (idempotent, safe).
  - `POST`: Create a new resource.
  - `PUT`: Full update of an existing resource (replaces entire resource).
  - `PATCH`: Partial update of an existing resource.
  - `DELETE`: Remove a resource.

---

## 3. Standard HTTP Status Codes

| Status Code | Meaning | When to Use |
|---|---|---|
| `200 OK` | Request succeeded | Standard successful `GET`, `PUT`, `PATCH` operations. |
| `201 Created` | Resource created | Successful `POST` resulting in new entity creation. |
| `204 No Content` | Action succeeded with no body | Successful `DELETE` or empty response actions. |
| `400 Bad Request` | Client semantic error | Malformed data not caught by type validation. |
| `401 Unauthorized` | Missing / invalid credentials | Missing or expired auth token. |
| `403 Forbidden` | Authenticated but unauthorized | User lacks permission to access the resource. |
| `404 Not Found` | Resource not found | Target ID does not exist in the database. |
| `409 Conflict` | State conflict | Duplicate email, username, or unique constraint violation. |
| `422 Unprocessable Entity` | Schema validation error | Pydantic validation failure on request payload. |
| `500 Internal Server Error` | Unexpected backend crash | Unhandled exception (caught by global handler). |
| `503 Service Unavailable` | Downstream failure | Database down, third-party service unreachable. |

---

## 4. Uniform Response Structures

### Success Envelope
Collection endpoints should support standard pagination:
```json
{
  "items": [
    {
      "id": "123e4567-e89b-12d3-a456-426614174000",
      "title": "Director of Photography",
      "created_at": "2026-11-13T12:00:00Z"
    }
  ],
  "total": 1,
  "page": 1,
  "page_size": 20
}
```

### Structured Error Responses
All error responses from CineConnect follow a predictable schema:
```json
{
  "status": "error",
  "code": 404,
  "detail": "Requested job listing was not found",
  "errors": []
}
```
Validation failures (`422`) include specific field details:
```json
{
  "status": "error",
  "code": 422,
  "detail": "Request validation failed",
  "errors": [
    {
      "loc": ["body", "email"],
      "msg": "value is not a valid email address",
      "type": "value_error"
    }
  ]
}
```

---

## 5. Security & Sensitive Information
- **Never expose credentials**: Database passwords, connection strings, private keys, or system credentials must never appear in error payloads.
- **CORS**: Cross-Origin Resource Sharing is controlled strictly by the `CORS_ORIGINS` environment variable. Wildcard `*` is prohibited in staging and production.
- **Authentication**: Phase 2 will implement JWT bearer token authentication via the `Authorization: Bearer <token>` header.

