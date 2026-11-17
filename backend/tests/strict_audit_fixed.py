import sys
import uuid
import json
import httpx
import websockets
import asyncio
from app.core.security import create_test_token

BASE_URL = "http://localhost:8000"

def run_strict_audit():
    client = httpx.Client(base_url=BASE_URL, timeout=10.0, follow_redirects=False)

    # 1. Setup personas
    run_uuid = uuid.uuid4().hex[:6]
    talent_id = str(uuid.uuid4())
    ph_user_id = str(uuid.uuid4())
    other_user_id = str(uuid.uuid4())

    talent_token = create_test_token(
        user_id=talent_id,
        email=f"talent_{run_uuid}@audit.cineconnect.test",
        role="talent",
        extra_claims={"user_metadata": {"full_name": "Audit Talent", "role": "talent"}},
    )
    ph_token = create_test_token(
        user_id=ph_user_id,
        email=f"ph_{run_uuid}@audit.cineconnect.test",
        role="production_house",
        extra_claims={"user_metadata": {"full_name": "Audit Producer", "role": "production_house"}},
    )
    other_token = create_test_token(
        user_id=other_user_id,
        email=f"other_{run_uuid}@audit.cineconnect.test",
        role="talent",
        extra_claims={"user_metadata": {"full_name": "Other Talent", "role": "talent"}},
    )

    t_headers = {"Authorization": f"Bearer {talent_token}"}
    p_headers = {"Authorization": f"Bearer {ph_token}"}
    o_headers = {"Authorization": f"Bearer {other_token}"}

    # Fetch OpenAPI spec to inspect registered paths
    r_spec = client.get("/openapi.json")
    spec = r_spec.json()
    api_paths = spec.get("paths", {})

    results = []

    def check_and_test(module, method, expected_route_template, request_builder):
        """
        module: string name
        method: GET, POST, etc.
        expected_route_template: string e.g. '/api/v1/posts/{post_id}'
        request_builder: function taking the resolved path and calling client
        """
        # 1. Find matching path in OpenAPI
        # Match directly or with trailing slash
        candidates = [
            expected_route_template,
            expected_route_template + "/",
            expected_route_template.rstrip("/")
        ]
        matched_openapi_path = None
        for c in candidates:
            if c in api_paths and method.lower() in api_paths[c]:
                matched_openapi_path = c
                break

        actual_route = matched_openapi_path
        status_category = None
        http_code = None

        if matched_openapi_path is not None:
            # Endpoint is implemented. Now execute test.
            try:
                resp = request_builder(matched_openapi_path)
                http_code = resp.status_code
                if resp.status_code in (200, 201, 204):
                    status_category = "PASS"
                else:
                    status_category = f"FAIL"
            except Exception as e:
                status_category = "FAIL"
                http_code = str(e)
        else:
            # Check if there is an alternate path implemented under another prefix (ROUTE MISMATCH)
            alt_candidates = [p for p in api_paths if method.lower() in api_paths[p] and ("interactions" in p and "posts" in p)]
            if "interactions" in expected_route_template and alt_candidates:
                actual_route = alt_candidates[0]
                status_category = "ROUTE MISMATCH"
                # Test whether the expected route works or 404s
                try:
                    resp = request_builder(expected_route_template)
                    http_code = resp.status_code
                except Exception:
                    http_code = 404
            else:
                actual_route = "NOT FOUND"
                status_category = "MISSING"
                http_code = 404

        results.append({
            "module": module,
            "method": method.upper(),
            "expected_route": expected_route_template,
            "actual_route": actual_route if actual_route else "NOT FOUND",
            "http_status": http_code,
            "test_result": status_category
        })
        return status_category, http_code

    # =========================================================================
    # Module 16: Health Checks
    # =========================================================================
    check_and_test("Infrastructure / Health", "GET", "/health", lambda p: client.get(p))
    check_and_test("Infrastructure / Health", "GET", "/api/v1/health", lambda p: client.get(p))
    check_and_test("Infrastructure / Health", "GET", "/api/v1/health/db", lambda p: client.get(p))

    # =========================================================================
    # Module 1: User / Talent Profiles
    # =========================================================================
    # 1. GET /api/v1/users/me
    check_and_test("User / Talent Profiles", "GET", "/api/v1/users/me", lambda p: client.get(p, headers=t_headers))

    # 2. PUT /api/v1/users/me
    check_and_test("User / Talent Profiles", "PUT", "/api/v1/users/me", lambda p: client.put(p, headers=t_headers, json={
        "full_name": "Audit Talent Verified",
        "role": "Lead Actor",
        "location": "Mumbai",
        "bio": "Method actor with theatre credentials.",
        "phone": "+919988776655",
        "experience_years": 5,
    }))

    # 3. PATCH /api/v1/users/me
    check_and_test("User / Talent Profiles", "PATCH", "/api/v1/users/me", lambda p: client.patch(p, headers=t_headers, json={
        "bio": "Method actor updated bio.",
    }))

    # Sync other personas into DB
    client.get("/api/v1/users/me", headers=p_headers)
    client.get("/api/v1/users/me", headers=o_headers)

    # 4. GET /api/v1/users/{user_id}
    check_and_test("User / Talent Profiles", "GET", "/api/v1/users/{user_id}", lambda p: client.get(f"/api/v1/users/{talent_id}", headers=t_headers))

    # 5. GET /api/v1/users
    check_and_test("User / Talent Profiles", "GET", "/api/v1/users", lambda p: client.get(p, headers=t_headers))

    # 6. GET /api/v1/users/search
    check_and_test("User / Talent Profiles", "GET", "/api/v1/users/search", lambda p: client.get(f"{p}?q=Audit", headers=t_headers))

    # 7. GET /api/v1/users/{user_id}/portfolio
    check_and_test("User / Talent Profiles", "GET", "/api/v1/users/{user_id}/portfolio", lambda p: client.get(f"/api/v1/users/{talent_id}/portfolio", headers=t_headers))

    # 8. GET /api/v1/users/{user_id}/posts
    check_and_test("User / Talent Profiles", "GET", "/api/v1/users/{user_id}/posts", lambda p: client.get(f"/api/v1/users/{talent_id}/posts", headers=t_headers))

    # 9. GET /api/v1/users/{user_id}/connections
    check_and_test("User / Talent Profiles", "GET", "/api/v1/users/{user_id}/connections", lambda p: client.get(f"/api/v1/users/{talent_id}/connections", headers=t_headers))

    # 10. GET /api/v1/users/{user_id}/followers
    check_and_test("User / Talent Profiles", "GET", "/api/v1/users/{user_id}/followers", lambda p: client.get(f"/api/v1/users/{talent_id}/followers", headers=t_headers))

    # 11. GET /api/v1/users/{user_id}/following
    check_and_test("User / Talent Profiles", "GET", "/api/v1/users/{user_id}/following", lambda p: client.get(f"/api/v1/users/{talent_id}/following", headers=t_headers))

    # =========================================================================
    # Module 2: Production Houses
    # =========================================================================
    ph_obj = {}
    def create_ph(p):
        r = client.post(p, headers=p_headers, json={
            "company_name": "Strict Audit Studios",
            "description": "Studio created for strict audit.",
            "location": "Mumbai, India",
            "website": "https://audit.cineconnect.test",
            "specialization": "Feature Films",
        })
        if r.status_code == 201:
            ph_obj.update(r.json())
        return r
    # 12. POST /api/v1/production-houses
    check_and_test("Production Houses", "POST", "/api/v1/production-houses", create_ph)
    ph_id = ph_obj.get("id", str(uuid.uuid4()))

    # 13. GET /api/v1/production-houses/me
    check_and_test("Production Houses", "GET", "/api/v1/production-houses/me", lambda p: client.get(p, headers=p_headers))

    # 14. PUT /api/v1/production-houses/me
    check_and_test("Production Houses", "PUT", "/api/v1/production-houses/me", lambda p: client.put(p, headers=p_headers, json={
        "company_name": "Strict Audit Studios Updated",
        "description": "Updated studio description.",
        "location": "Mumbai, India",
        "website": "https://audit.cineconnect.test",
        "specialization": "Features & Web Series",
    }))

    # 15. GET /api/v1/production-houses
    check_and_test("Production Houses", "GET", "/api/v1/production-houses", lambda p: client.get(p))

    # 16. GET /api/v1/production-houses/{house_id}
    check_and_test("Production Houses", "GET", "/api/v1/production-houses/{house_id}", lambda p: client.get(f"/api/v1/production-houses/{ph_id}"))

    # 17. GET /api/v1/production-houses/search
    check_and_test("Production Houses", "GET", "/api/v1/production-houses/search", lambda p: client.get(f"{p}?q=Strict"))

    # 18. GET /api/v1/production-houses/{house_id}/projects
    check_and_test("Production Houses", "GET", "/api/v1/production-houses/{house_id}/projects", lambda p: client.get(f"/api/v1/production-houses/{ph_id}/projects"))

    # 19. GET /api/v1/production-houses/{house_id}/opportunities
    check_and_test("Production Houses", "GET", "/api/v1/production-houses/{house_id}/opportunities", lambda p: client.get(f"/api/v1/production-houses/{ph_id}/opportunities"))

    # =========================================================================
    # Module 3: Projects
    # =========================================================================
    proj_obj = {}
    def create_proj(p):
        r = client.post(p, headers=p_headers, json={
            "title": "Strict Audit Feature Film",
            "synopsis": "A movie created during strict audit testing.",
            "genre": "Suspense",
            "status": "development",
            "budget": "$2,000,000",
        })
        if r.status_code == 201:
            proj_obj.update(r.json())
        return r
    # 20. POST /api/v1/projects
    check_and_test("Project Management", "POST", "/api/v1/projects", create_proj)
    project_id = proj_obj.get("id", str(uuid.uuid4()))

    # 21. GET /api/v1/projects
    check_and_test("Project Management", "GET", "/api/v1/projects", lambda p: client.get(p))

    # 22. GET /api/v1/projects/{project_id}
    check_and_test("Project Management", "GET", "/api/v1/projects/{project_id}", lambda p: client.get(f"/api/v1/projects/{project_id}"))

    # 23. PUT /api/v1/projects/{project_id}
    check_and_test("Project Management", "PUT", "/api/v1/projects/{project_id}", lambda p: client.put(f"/api/v1/projects/{project_id}", headers=p_headers, json={
        "title": "Strict Audit Feature Film Updated",
        "synopsis": "Updated project synopsis.",
        "genre": "Thriller",
        "status": "pre-production",
        "budget": "$2,200,000",
    }))

    # 24. PATCH /api/v1/projects/{project_id}
    check_and_test("Project Management", "PATCH", "/api/v1/projects/{project_id}", lambda p: client.patch(f"/api/v1/projects/{project_id}", headers=p_headers, json={
        "status": "filming",
    }))

    # 25. GET /api/v1/projects/my
    check_and_test("Project Management", "GET", "/api/v1/projects/my", lambda p: client.get(p, headers=p_headers))

    # 26. GET /api/v1/projects/search
    check_and_test("Project Management", "GET", "/api/v1/projects/search", lambda p: client.get(f"{p}?q=Strict"))

    # 27. GET /api/v1/projects/{project_id}/opportunities
    check_and_test("Project Management", "GET", "/api/v1/projects/{project_id}/opportunities", lambda p: client.get(f"/api/v1/projects/{project_id}/opportunities"))

    # 28. GET /api/v1/projects/{project_id}/collaborations
    check_and_test("Project Management", "GET", "/api/v1/projects/{project_id}/collaborations", lambda p: client.get(f"/api/v1/projects/{project_id}/collaborations", headers=p_headers))

    # 29. DELETE /api/v1/projects/{project_id} (performed on a disposable project)
    disposable_proj = client.post("/api/v1/projects", headers=p_headers, json={"title": "To Delete", "genre": "Short"}).json()
    disp_proj_id = disposable_proj.get("id", str(uuid.uuid4()))
    check_and_test("Project Management", "DELETE", "/api/v1/projects/{project_id}", lambda p: client.delete(f"/api/v1/projects/{disp_proj_id}", headers=p_headers))

    # =========================================================================
    # Module 4: Opportunity / Job APIs
    # =========================================================================
    opp_obj = {}
    def create_opp(p):
        r = client.post(p, headers=p_headers, json={
            "project_id": project_id,
            "title": "Lead Detective Role",
            "role_type": "Lead",
            "requirements": "Age 28-40, sharp intensity",
            "location": "Mumbai",
            "compensation": "$3,000/day",
            "status": "open",
        })
        if r.status_code == 201:
            opp_obj.update(r.json())
        return r
    # 30. POST /api/v1/opportunities
    check_and_test("Opportunity / Job", "POST", "/api/v1/opportunities", create_opp)
    opp_id = opp_obj.get("id", str(uuid.uuid4()))

    # 31. GET /api/v1/opportunities
    check_and_test("Opportunity / Job", "GET", "/api/v1/opportunities", lambda p: client.get(p))

    # 32. GET /api/v1/opportunities/{opportunity_id}
    check_and_test("Opportunity / Job", "GET", "/api/v1/opportunities/{opportunity_id}", lambda p: client.get(f"/api/v1/opportunities/{opp_id}"))

    # 33. PUT /api/v1/opportunities/{opportunity_id}
    check_and_test("Opportunity / Job", "PUT", "/api/v1/opportunities/{opportunity_id}", lambda p: client.put(f"/api/v1/opportunities/{opp_id}", headers=p_headers, json={
        "project_id": project_id,
        "title": "Lead Detective Role Updated",
        "role_type": "Lead",
        "requirements": "Age 25-42",
        "location": "Mumbai",
        "compensation": "$3,500/day",
        "status": "open",
    }))

    # 34. PATCH /api/v1/opportunities/{opportunity_id}
    check_and_test("Opportunity / Job", "PATCH", "/api/v1/opportunities/{opportunity_id}", lambda p: client.patch(f"/api/v1/opportunities/{opp_id}", headers=p_headers, json={
        "compensation": "$4,000/day",
    }))

    # 35. GET /api/v1/opportunities/my
    check_and_test("Opportunity / Job", "GET", "/api/v1/opportunities/my", lambda p: client.get(p, headers=p_headers))

    # 36. GET /api/v1/opportunities/search
    check_and_test("Opportunity / Job", "GET", "/api/v1/opportunities/search", lambda p: client.get(f"{p}?q=Detective"))

    # 37. GET /api/v1/opportunities/{opportunity_id}/applications
    check_and_test("Opportunity / Job", "GET", "/api/v1/opportunities/{opportunity_id}/applications", lambda p: client.get(f"/api/v1/opportunities/{opp_id}/applications", headers=p_headers))

    # 38. PATCH /api/v1/opportunities/{opportunity_id}/status
    check_and_test("Opportunity / Job", "PATCH", "/api/v1/opportunities/{opportunity_id}/status", lambda p: client.patch(f"/api/v1/opportunities/{opp_id}/status", headers=p_headers, json={
        "status": "open"
    }))

    # 39. DELETE /api/v1/opportunities/{opportunity_id}
    disp_opp = client.post("/api/v1/opportunities/", headers=p_headers, json={
        "project_id": project_id,
        "title": "Disposable Opp",
        "status": "open"
    }).json()
    disp_opp_id = disp_opp.get("id", str(uuid.uuid4()))
    check_and_test("Opportunity / Job", "DELETE", "/api/v1/opportunities/{opportunity_id}", lambda p: client.delete(f"/api/v1/opportunities/{disp_opp_id}", headers=p_headers))

    # =========================================================================
    # Module 5: Application APIs
    # =========================================================================
    app_obj = {}
    def create_app(p):
        r = client.post(p, headers=t_headers, json={
            "opportunity_id": opp_id,
            "cover_letter": "I am thrilled to audition for the lead detective role.",
            "resume_url": "https://storage.cineconnect.test/resumes/talent.pdf",
            "reel_url": "https://vimeo.com/99887766",
        })
        if r.status_code == 201:
            app_obj.update(r.json())
        return r
    # 40. POST /api/v1/applications
    check_and_test("Application", "POST", "/api/v1/applications", create_app)
    application_id = app_obj.get("id", str(uuid.uuid4()))

    # 41. GET /api/v1/applications/my
    check_and_test("Application", "GET", "/api/v1/applications/my", lambda p: client.get(p, headers=t_headers))

    # 42. GET /api/v1/applications
    check_and_test("Application", "GET", "/api/v1/applications", lambda p: client.get(p, headers=p_headers))

    # 43. GET /api/v1/applications/{application_id}
    check_and_test("Application", "GET", "/api/v1/applications/{application_id}", lambda p: client.get(f"/api/v1/applications/{application_id}", headers=t_headers))

    # 44. PATCH /api/v1/applications/{application_id}
    check_and_test("Application", "PATCH", "/api/v1/applications/{application_id}", lambda p: client.patch(f"/api/v1/applications/{application_id}", headers=t_headers, json={
        "cover_letter": "Updated audition statement.",
    }))

    # 45. PATCH /api/v1/applications/{application_id}/status
    check_and_test("Application", "PATCH", "/api/v1/applications/{application_id}/status", lambda p: client.patch(f"/api/v1/applications/{application_id}/status", headers=p_headers, json={
        "status": "shortlisted",
    }))

    # 46. DELETE /api/v1/applications/{application_id}
    disp_app = client.post("/api/v1/applications/", headers=o_headers, json={
        "opportunity_id": opp_id,
        "cover_letter": "Disposable app",
    }).json()
    disp_app_id = disp_app.get("id", str(uuid.uuid4()))
    check_and_test("Application", "DELETE", "/api/v1/applications/{application_id}", lambda p: client.delete(f"/api/v1/applications/{disp_app_id}", headers=o_headers))

    # =========================================================================
    # Module 6: Portfolio Media APIs
    # =========================================================================
    port_obj = {}
    def create_port(p):
        r = client.post(p, headers=t_headers, json={
            "title": "Strict Audit Showreel",
            "description": "Dramatic audition scenes.",
            "media_type": "video",
            "media_url": "https://storage.cineconnect.test/portfolio/showreel.mp4",
        })
        if r.status_code == 201:
            port_obj.update(r.json())
        return r
    # 47. POST /api/v1/portfolio
    check_and_test("Portfolio Media", "POST", "/api/v1/portfolio", create_port)
    media_id = port_obj.get("id", str(uuid.uuid4()))

    # 48. GET /api/v1/portfolio/my
    check_and_test("Portfolio Media", "GET", "/api/v1/portfolio/my", lambda p: client.get(p, headers=t_headers))

    # 49. GET /api/v1/portfolio/{media_id}
    check_and_test("Portfolio Media", "GET", "/api/v1/portfolio/{media_id}", lambda p: client.get(f"/api/v1/portfolio/{media_id}"))

    # 50. PUT /api/v1/portfolio/{media_id}
    check_and_test("Portfolio Media", "PUT", "/api/v1/portfolio/{media_id}", lambda p: client.put(f"/api/v1/portfolio/{media_id}", headers=t_headers, json={
        "title": "Strict Audit Showreel Remastered",
        "description": "4K remaster of dramatic scenes.",
        "media_type": "video",
        "media_url": "https://storage.cineconnect.test/portfolio/showreel_4k.mp4",
    }))

    # 51. DELETE /api/v1/portfolio/{media_id}
    disp_port = client.post("/api/v1/portfolio/", headers=t_headers, json={
        "title": "Disposable Reel",
        "media_type": "image",
        "media_url": "https://storage.cineconnect.test/portfolio/temp.jpg",
    }).json()
    disp_media_id = disp_port.get("id", str(uuid.uuid4()))
    check_and_test("Portfolio Media", "DELETE", "/api/v1/portfolio/{media_id}", lambda p: client.delete(f"/api/v1/portfolio/{disp_media_id}", headers=t_headers))

    # =========================================================================
    # Module 7: Social Posts APIs
    # =========================================================================
    post_obj = {}
    def create_post(p):
        r = client.post(p, headers=t_headers, json={
            "caption": "Audit Day 1: BTS photography on film location! #cineconnect",
            "media_url": "https://storage.cineconnect.test/posts/bts_audit.jpg",
        })
        if r.status_code == 201:
            post_obj.update(r.json())
        return r
    # 52. POST /api/v1/posts
    check_and_test("Social Posts", "POST", "/api/v1/posts", create_post)
    post_id = post_obj.get("id", str(uuid.uuid4()))

    # 53. GET /api/v1/posts
    check_and_test("Social Posts", "GET", "/api/v1/posts", lambda p: client.get(p))

    # 54. GET /api/v1/posts/my
    check_and_test("Social Posts", "GET", "/api/v1/posts/my", lambda p: client.get(p, headers=t_headers))

    # 55. GET /api/v1/posts/{post_id}
    check_and_test("Social Posts", "GET", "/api/v1/posts/{post_id}", lambda p: client.get(f"/api/v1/posts/{post_id}"))

    # 56. PUT /api/v1/posts/{post_id}
    check_and_test("Social Posts", "PUT", "/api/v1/posts/{post_id}", lambda p: client.put(f"/api/v1/posts/{post_id}", headers=t_headers, json={
        "caption": "Audit Day 1: BTS photography edited caption.",
        "media_url": "https://storage.cineconnect.test/posts/bts_audit_v2.jpg",
    }))

    # 57. DELETE /api/v1/posts/{post_id}
    disp_post = client.post("/api/v1/posts/", headers=t_headers, json={"caption": "Post to delete"}).json()
    disp_post_id = disp_post.get("id", str(uuid.uuid4()))
    check_and_test("Social Posts", "DELETE", "/api/v1/posts/{post_id}", lambda p: client.delete(f"/api/v1/posts/{disp_post_id}", headers=t_headers))

    # =========================================================================
    # Module 8: Interactions APIs
    # =========================================================================
    inter_obj = {}
    def create_inter(p):
        r = client.post(p, headers=p_headers, json={
            "post_id": post_id,
            "type": "comment",
            "comment": "Brilliant composition!",
        })
        if r.status_code == 201:
            inter_obj.update(r.json())
        return r
    # 58. POST /api/v1/interactions
    check_and_test("Interactions", "POST", "/api/v1/interactions", create_inter)
    interaction_id = inter_obj.get("id", str(uuid.uuid4()))

    # 59. GET /api/v1/interactions/my
    check_and_test("Interactions", "GET", "/api/v1/interactions/my", lambda p: client.get(p, headers=p_headers))

    # 60. GET /api/v1/interactions/{interaction_id}
    check_and_test("Interactions", "GET", "/api/v1/interactions/{interaction_id}", lambda p: client.get(f"/api/v1/interactions/{interaction_id}"))

    # 61. PATCH /api/v1/interactions/{interaction_id}
    check_and_test("Interactions", "PATCH", "/api/v1/interactions/{interaction_id}", lambda p: client.patch(f"/api/v1/interactions/{interaction_id}", headers=p_headers, json={
        "comment": "Brilliant composition! (Verified)",
    }))

    # 62. GET /api/v1/posts/{post_id}/interactions (Inventory route)
    check_and_test("Interactions", "GET", "/api/v1/posts/{post_id}/interactions", lambda p: client.get(f"/api/v1/posts/{post_id}/interactions"))

    # 63. POST /api/v1/posts/{post_id}/interactions (Inventory route)
    check_and_test("Interactions", "POST", "/api/v1/posts/{post_id}/interactions", lambda p: client.post(f"/api/v1/posts/{post_id}/interactions", headers=t_headers, json={
        "comment": "Thank you!"
    }))

    # 64. DELETE /api/v1/interactions/{interaction_id}
    disp_inter = client.post("/api/v1/interactions/", headers=t_headers, json={"post_id": post_id, "type": "like"}).json()
    disp_inter_id = disp_inter.get("id", str(uuid.uuid4()))
    check_and_test("Interactions", "DELETE", "/api/v1/interactions/{interaction_id}", lambda p: client.delete(f"/api/v1/interactions/{disp_inter_id}", headers=t_headers))

    # =========================================================================
    # Module 9: Connections / Follow APIs
    # =========================================================================
    conn_obj = {}
    def create_conn(p):
        r = client.post(p, headers=t_headers, json={
            "receiver_id": other_user_id,
        })
        if r.status_code == 201:
            conn_obj.update(r.json())
        return r
    # 65. POST /api/v1/connections
    check_and_test("Connections", "POST", "/api/v1/connections", create_conn)
    connection_id = conn_obj.get("id", str(uuid.uuid4()))

    # 66. GET /api/v1/connections/requests
    check_and_test("Connections", "GET", "/api/v1/connections/requests", lambda p: client.get(p, headers=o_headers))

    # 67. GET /api/v1/connections/{connection_id}
    check_and_test("Connections", "GET", "/api/v1/connections/{connection_id}", lambda p: client.get(f"/api/v1/connections/{connection_id}", headers=t_headers))

    # 68. PATCH /api/v1/connections/{connection_id}/accept
    check_and_test("Connections", "PATCH", "/api/v1/connections/{connection_id}/accept", lambda p: client.patch(f"/api/v1/connections/{connection_id}/accept", headers=o_headers))

    # 69. GET /api/v1/connections/my
    check_and_test("Connections", "GET", "/api/v1/connections/my", lambda p: client.get(p, headers=t_headers))

    # 70. PATCH /api/v1/connections/{connection_id}/reject
    disp_conn = client.post("/api/v1/connections/", headers=p_headers, json={"receiver_id": other_user_id}).json()
    disp_conn_id = disp_conn.get("id", str(uuid.uuid4()))
    check_and_test("Connections", "PATCH", "/api/v1/connections/{connection_id}/reject", lambda p: client.patch(f"/api/v1/connections/{disp_conn_id}/reject", headers=o_headers))

    # 71. DELETE /api/v1/connections/{connection_id}
    check_and_test("Connections", "DELETE", "/api/v1/connections/{connection_id}", lambda p: client.delete(f"/api/v1/connections/{disp_conn_id}", headers=o_headers))

    # =========================================================================
    # Module 10: Collaboration APIs
    # =========================================================================
    collab_obj = {}
    def create_collab(p):
        r = client.post(p, headers=p_headers, json={
            "project_id": project_id,
            "talent_id": talent_id,
            "role": "Lead Detective",
        })
        if r.status_code == 201:
            collab_obj.update(r.json())
        return r
    # 72. POST /api/v1/collaborations
    check_and_test("Collaborations", "POST", "/api/v1/collaborations", create_collab)
    collab_id = collab_obj.get("id", str(uuid.uuid4()))

    # 73. GET /api/v1/collaborations/my
    check_and_test("Collaborations", "GET", "/api/v1/collaborations/my", lambda p: client.get(p, headers=t_headers))

    # 74. GET /api/v1/collaborations/{collaboration_id}
    check_and_test("Collaborations", "GET", "/api/v1/collaborations/{collaboration_id}", lambda p: client.get(f"/api/v1/collaborations/{collab_id}", headers=t_headers))

    # 75. PATCH /api/v1/collaborations/{collaboration_id}/accept
    check_and_test("Collaborations", "PATCH", "/api/v1/collaborations/{collaboration_id}/accept", lambda p: client.patch(f"/api/v1/collaborations/{collab_id}/accept", headers=t_headers))

    # 76. PATCH /api/v1/collaborations/{collaboration_id}/status
    check_and_test("Collaborations", "PATCH", "/api/v1/collaborations/{collaboration_id}/status", lambda p: client.patch(f"/api/v1/collaborations/{collab_id}/status", headers=p_headers, json={
        "status": "completed",
    }))

    # 77. PATCH /api/v1/collaborations/{collaboration_id}/reject
    disp_collab = client.post("/api/v1/collaborations/", headers=p_headers, json={
        "project_id": project_id,
        "talent_id": other_user_id,
        "role": "Sound Engineer",
    }).json()
    disp_collab_id = disp_collab.get("id", str(uuid.uuid4()))
    check_and_test("Collaborations", "PATCH", "/api/v1/collaborations/{collaboration_id}/reject", lambda p: client.patch(f"/api/v1/collaborations/{disp_collab_id}/reject", headers=o_headers))

    # 78. DELETE /api/v1/collaborations/{collaboration_id}
    check_and_test("Collaborations", "DELETE", "/api/v1/collaborations/{collaboration_id}", lambda p: client.delete(f"/api/v1/collaborations/{disp_collab_id}", headers=o_headers))

    # =========================================================================
    # Module 11: Messaging / Chat APIs
    # =========================================================================
    msg_obj = {}
    def create_msg(p):
        r = client.post(p, headers=p_headers, json={
            "recipient_id": talent_id,
            "body": "Strict audit messaging test.",
        })
        if r.status_code == 201:
            msg_obj.update(r.json())
        return r
    # 79. POST /api/v1/messages
    check_and_test("Messaging", "POST", "/api/v1/messages", create_msg)
    message_id = msg_obj.get("id", str(uuid.uuid4()))

    # 80. GET /api/v1/messages/unread-count
    check_and_test("Messaging", "GET", "/api/v1/messages/unread-count", lambda p: client.get(p, headers=t_headers))

    # 81. GET /api/v1/messages/conversations
    check_and_test("Messaging", "GET", "/api/v1/messages/conversations", lambda p: client.get(p, headers=t_headers))

    # 82. GET /api/v1/messages/conversations/{user_id}
    check_and_test("Messaging", "GET", "/api/v1/messages/conversations/{user_id}", lambda p: client.get(f"/api/v1/messages/conversations/{ph_user_id}", headers=t_headers))

    # 83. GET /api/v1/messages/{message_id}
    check_and_test("Messaging", "GET", "/api/v1/messages/{message_id}", lambda p: client.get(f"/api/v1/messages/{message_id}", headers=t_headers))

    # 84. DELETE /api/v1/messages/{message_id}
    disp_msg = client.post("/api/v1/messages/", headers=t_headers, json={"recipient_id": ph_user_id, "body": "Temp msg"}).json()
    disp_msg_id = disp_msg.get("id", str(uuid.uuid4()))
    check_and_test("Messaging", "DELETE", "/api/v1/messages/{message_id}", lambda p: client.delete(f"/api/v1/messages/{disp_msg_id}", headers=t_headers))

    # =========================================================================
    # Module 12: Additional Application APIs
    # =========================================================================
    # 85. GET /api/v1/search
    check_and_test("Search", "GET", "/api/v1/search", lambda p: client.get(f"{p}?q=Audit"))

    # 86. GET /api/v1/notifications
    check_and_test("Notifications", "GET", "/api/v1/notifications", lambda p: client.get(p, headers=t_headers))

    # 87. GET /api/v1/notifications/unread-count
    check_and_test("Notifications", "GET", "/api/v1/notifications/unread-count", lambda p: client.get(p, headers=t_headers))

    # 88. PATCH /api/v1/notifications/read-all
    check_and_test("Notifications", "PATCH", "/api/v1/notifications/read-all", lambda p: client.patch(p, headers=t_headers))

    # Insert test notification for single read test
    from app.db.session import AsyncSessionLocal
    from app.models.notification import Notification
    async def insert_notif():
        async with AsyncSessionLocal() as session:
            notif = Notification(
                user_id=uuid.UUID(talent_id),
                title="Audit Notice",
                message="Strict audit message.",
                type="system",
            )
            session.add(notif)
            await session.commit()
            await session.refresh(notif)
            return str(notif.id)
    notif_id = asyncio.run(insert_notif())
    # 89. PATCH /api/v1/notifications/{notification_id}/read
    check_and_test("Notifications", "PATCH", "/api/v1/notifications/{notification_id}/read", lambda p: client.patch(f"/api/v1/notifications/{notif_id}/read", headers=t_headers))

    # 90. POST /api/v1/media/upload-url
    check_and_test("Media Storage", "POST", "/api/v1/media/upload-url", lambda p: client.post(p, headers=t_headers, json={
        "file_name": "strict_headshot.jpg",
        "content_type": "image/jpeg",
        "file_size_bytes": 2048576,
    }))

    # 91. GET /api/v1/dashboard/talent
    check_and_test("Dashboards", "GET", "/api/v1/dashboard/talent", lambda p: client.get(p, headers=t_headers))

    # 92. GET /api/v1/dashboard/production-house
    check_and_test("Dashboards", "GET", "/api/v1/dashboard/production-house", lambda p: client.get(p, headers=p_headers))

    # Output formatted results
    print("\n" + "=" * 90)
    print("FINAL STRICT AUDIT RESULTS")
    print("=" * 90)
    for r in results:
        print(json.dumps(r))

    total = len(results)
    passed = sum(1 for r in results if r["test_result"] == "PASS")
    failed = sum(1 for r in results if r["test_result"] == "FAIL")
    blocked = sum(1 for r in results if r["test_result"] == "BLOCKED")
    not_tested = sum(1 for r in results if r["test_result"] == "NOT TESTED")
    missing = sum(1 for r in results if r["test_result"] == "MISSING")
    mismatches = sum(1 for r in results if r["test_result"] == "ROUTE MISMATCH")
    matched = total - mismatches - missing

    print("\n" + "=" * 50)
    print("STRICT AUDIT SUMMARY COUNTS")
    print("=" * 50)
    print(f"Total expected HTTP endpoints: {total}")
    print(f"Total matched HTTP endpoints: {matched}")
    print(f"Total successfully tested HTTP endpoints: {passed}")
    print(f"Total failed endpoints: {failed}")
    print(f"Total blocked endpoints: {blocked}")
    print(f"Total missing endpoints: {missing}")
    print(f"Total route mismatches: {mismatches}")

if __name__ == "__main__":
    run_strict_audit()
