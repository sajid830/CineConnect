import sys
import uuid
import json
import httpx
import websockets
import asyncio
from app.core.security import create_test_token

BASE_URL = "http://localhost:8000"

def run_comprehensive_audit():
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

    # Helper function to check spec and test endpoint
    def audit_endpoint(module, method, expected_route, test_callable):
        # Check if route exists exactly or with trailing slash
        actual_route = None
        status_category = None
        http_code = None

        norm_expected = expected_route.rstrip("/")
        # Check exact matches in OpenAPI
        candidates = [expected_route, expected_route + "/", norm_expected]
        found_path = None
        for c in candidates:
            if c in api_paths and method.lower() in api_paths[c]:
                found_path = c
                break

        if found_path is not None:
            actual_route = found_path
            # Execute actual HTTP test
            try:
                resp = test_callable(found_path)
                http_code = resp.status_code
                if resp.status_code in (200, 201, 204):
                    status_category = "PASS"
                else:
                    status_category = "FAIL"
            except Exception as e:
                status_category = "FAIL"
                http_code = str(e)
        else:
            # Check if implemented under a different prefix/route
            # e.g., interactions route
            alt_candidates = [p for p in api_paths if method.lower() in api_paths[p] and ("interactions" in p and "posts" in p)]
            if "interactions" in expected_route and alt_candidates:
                actual_route = alt_candidates[0]
                status_category = "ROUTE MISMATCH"
                try:
                    resp = client.request(method, expected_route)
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
            "expected_route": expected_route,
            "actual_route": actual_route,
            "http_status": http_code,
            "test_result": status_category
        })
        return status_category, http_code

    # =========================================================================
    # Module 16: Health Check Endpoints (Foundation prerequisites)
    # =========================================================================
    audit_endpoint("Health", "GET", "/health", lambda p: client.get(p))
    audit_endpoint("Health", "GET", "/api/v1/health", lambda p: client.get(p))
    audit_endpoint("Health", "GET", "/api/v1/health/db", lambda p: client.get(p))

    # =========================================================================
    # Module 1: User / Talent Profile APIs
    # =========================================================================
    # 1. GET /api/v1/users/me
    audit_endpoint("User / Talent Profiles", "GET", "/api/v1/users/me", lambda p: client.get(p, headers=t_headers))

    # 2. PUT /api/v1/users/me
    audit_endpoint("User / Talent Profiles", "PUT", "/api/v1/users/me", lambda p: client.put(p, headers=t_headers, json={
        "full_name": "Audit Talent Verified",
        "role": "Lead Actor",
        "location": "Mumbai",
        "bio": "Method actor with theatre credentials.",
        "phone": "+919988776655",
        "experience_years": 5,
    }))

    # 3. PATCH /api/v1/users/me
    audit_endpoint("User / Talent Profiles", "PATCH", "/api/v1/users/me", lambda p: client.patch(p, headers=t_headers, json={
        "bio": "Method actor updated bio.",
    }))

    # Initialize Other user and PH user in DB
    client.get("/api/v1/users/me", headers=o_headers)
    client.get("/api/v1/users/me", headers=p_headers)

    # 4. GET /api/v1/users/{user_id}
    audit_endpoint("User / Talent Profiles", "GET", f"/api/v1/users/{talent_id}", lambda p: client.get(f"/api/v1/users/{talent_id}", headers=t_headers))

    # 5. GET /api/v1/users
    audit_endpoint("User / Talent Profiles", "GET", "/api/v1/users", lambda p: client.get(p, headers=t_headers))

    # 6. GET /api/v1/users/search
    audit_endpoint("User / Talent Profiles", "GET", "/api/v1/users/search", lambda p: client.get(f"{p}?q=Audit", headers=t_headers))

    # 7. GET /api/v1/users/{user_id}/portfolio
    audit_endpoint("User / Talent Profiles", "GET", f"/api/v1/users/{talent_id}/portfolio", lambda p: client.get(f"/api/v1/users/{talent_id}/portfolio", headers=t_headers))

    # 8. GET /api/v1/users/{user_id}/posts
    audit_endpoint("User / Talent Profiles", "GET", f"/api/v1/users/{talent_id}/posts", lambda p: client.get(f"/api/v1/users/{talent_id}/posts", headers=t_headers))

    # 9. GET /api/v1/users/{user_id}/connections
    audit_endpoint("User / Talent Profiles", "GET", f"/api/v1/users/{talent_id}/connections", lambda p: client.get(f"/api/v1/users/{talent_id}/connections", headers=t_headers))

    # 10. GET /api/v1/users/{user_id}/followers
    audit_endpoint("User / Talent Profiles", "GET", f"/api/v1/users/{talent_id}/followers", lambda p: client.get(f"/api/v1/users/{talent_id}/followers", headers=t_headers))

    # 11. GET /api/v1/users/{user_id}/following
    audit_endpoint("User / Talent Profiles", "GET", f"/api/v1/users/{talent_id}/following", lambda p: client.get(f"/api/v1/users/{talent_id}/following", headers=t_headers))

    # =========================================================================
    # Module 2: Production House APIs
    # =========================================================================
    # 12. POST /api/v1/production-houses
    ph_obj = {}
    def create_ph(p):
        r = client.post(p, headers=p_headers, json={
            "company_name": "Audit Cine Productions",
            "description": "Production house for audit testing.",
            "location": "Mumbai, India",
            "website": "https://auditproductions.cineconnect.test",
            "specialization": "Feature Films",
        })
        if r.status_code == 201:
            ph_obj.update(r.json())
        return r
    audit_endpoint("Production Houses", "POST", "/api/v1/production-houses", create_ph)
    ph_id = ph_obj.get("id", str(uuid.uuid4()))

    # 13. GET /api/v1/production-houses/me
    audit_endpoint("Production Houses", "GET", "/api/v1/production-houses/me", lambda p: client.get(p, headers=p_headers))

    # 14. PUT /api/v1/production-houses/me
    audit_endpoint("Production Houses", "PUT", "/api/v1/production-houses/me", lambda p: client.put(p, headers=p_headers, json={
        "company_name": "Audit Cine Productions Updated",
        "description": "Updated production house description.",
        "location": "Mumbai, India",
        "website": "https://auditproductions.cineconnect.test",
        "specialization": "Feature Films & Series",
    }))

    # 15. GET /api/v1/production-houses
    audit_endpoint("Production Houses", "GET", "/api/v1/production-houses", lambda p: client.get(p))

    # 16. GET /api/v1/production-houses/{house_id}
    audit_endpoint("Production Houses", "GET", f"/api/v1/production-houses/{ph_id}", lambda p: client.get(f"/api/v1/production-houses/{ph_id}"))

    # 17. GET /api/v1/production-houses/search
    audit_endpoint("Production Houses", "GET", "/api/v1/production-houses/search", lambda p: client.get(f"{p}?q=Audit"))

    # 18. GET /api/v1/production-houses/{house_id}/projects
    audit_endpoint("Production Houses", "GET", f"/api/v1/production-houses/{ph_id}/projects", lambda p: client.get(f"/api/v1/production-houses/{ph_id}/projects"))

    # 19. GET /api/v1/production-houses/{house_id}/opportunities
    audit_endpoint("Production Houses", "GET", f"/api/v1/production-houses/{ph_id}/opportunities", lambda p: client.get(f"/api/v1/production-houses/{ph_id}/opportunities"))

    # =========================================================================
    # Module 3: Project Management APIs
    # =========================================================================
    proj_obj = {}
    def create_project(p):
        r = client.post(p, headers=p_headers, json={
            "title": "Audit Chronicle",
            "synopsis": "A production project created during audit verification.",
            "genre": "Drama",
            "status": "development",
            "budget": "$1,000,000",
        })
        if r.status_code == 201:
            proj_obj.update(r.json())
        return r
    # 20. POST /api/v1/projects
    audit_endpoint("Project Management", "POST", "/api/v1/projects", create_project)
    project_id = proj_obj.get("id", str(uuid.uuid4()))

    # 21. GET /api/v1/projects
    audit_endpoint("Project Management", "GET", "/api/v1/projects", lambda p: client.get(p))

    # 22. GET /api/v1/projects/{project_id}
    audit_endpoint("Project Management", "GET", f"/api/v1/projects/{project_id}", lambda p: client.get(f"/api/v1/projects/{project_id}"))

    # 23. PUT /api/v1/projects/{project_id}
    audit_endpoint("Project Management", "PUT", f"/api/v1/projects/{project_id}", lambda p: client.put(f"/api/v1/projects/{project_id}", headers=p_headers, json={
        "title": "Audit Chronicle Updated",
        "synopsis": "Updated project synopsis.",
        "genre": "Thriller",
        "status": "pre-production",
        "budget": "$1,200,000",
    }))

    # 24. PATCH /api/v1/projects/{project_id}
    audit_endpoint("Project Management", "PATCH", f"/api/v1/projects/{project_id}", lambda p: client.patch(f"/api/v1/projects/{project_id}", headers=p_headers, json={
        "status": "filming",
    }))

    # 25. GET /api/v1/projects/my
    audit_endpoint("Project Management", "GET", "/api/v1/projects/my", lambda p: client.get(p, headers=p_headers))

    # 26. GET /api/v1/projects/search
    audit_endpoint("Project Management", "GET", "/api/v1/projects/search", lambda p: client.get(f"{p}?q=Audit"))

    # 27. GET /api/v1/projects/{project_id}/opportunities
    audit_endpoint("Project Management", "GET", f"/api/v1/projects/{project_id}/opportunities", lambda p: client.get(f"/api/v1/projects/{project_id}/opportunities"))

    # 28. GET /api/v1/projects/{project_id}/collaborations
    audit_endpoint("Project Management", "GET", f"/api/v1/projects/{project_id}/collaborations", lambda p: client.get(f"/api/v1/projects/{project_id}/collaborations", headers=p_headers))

    # Note: We test DELETE /api/v1/projects/{project_id} at the end of the project cycle on a separate dummy project
    dummy_proj_r = client.post("/api/v1/projects", headers=p_headers, json={
        "title": "Project To Delete",
        "synopsis": "Temporary project to test DELETE endpoint.",
        "genre": "Short",
    })
    dummy_proj_id = dummy_proj_r.json().get("id", str(uuid.uuid4())) if dummy_proj_r.status_code == 201 else str(uuid.uuid4())
    # 29. DELETE /api/v1/projects/{project_id}
    audit_endpoint("Project Management", "DELETE", f"/api/v1/projects/{dummy_proj_id}", lambda p: client.delete(f"/api/v1/projects/{dummy_proj_id}", headers=p_headers))

    # =========================================================================
    # Module 4: Opportunity / Job APIs
    # =========================================================================
    opp_obj = {}
    def create_opp(p):
        r = client.post(p, headers=p_headers, json={
            "project_id": project_id,
            "title": "Supporting Detective Inspector",
            "role_type": "Supporting Role",
            "requirements": "Sharp eye, intense dialogue delivery, Age 30-45",
            "location": "Mumbai",
            "compensation": "$2,500/day",
            "status": "open",
        })
        if r.status_code == 201:
            opp_obj.update(r.json())
        return r
    # 30. POST /api/v1/opportunities
    audit_endpoint("Opportunity / Job", "POST", "/api/v1/opportunities", create_opp)
    opp_id = opp_obj.get("id", str(uuid.uuid4()))

    # 31. GET /api/v1/opportunities
    audit_endpoint("Opportunity / Job", "GET", "/api/v1/opportunities", lambda p: client.get(p))

    # 32. GET /api/v1/opportunities/{opportunity_id}
    audit_endpoint("Opportunity / Job", "GET", f"/api/v1/opportunities/{opp_id}", lambda p: client.get(f"/api/v1/opportunities/{opp_id}"))

    # 33. PUT /api/v1/opportunities/{opportunity_id}
    audit_endpoint("Opportunity / Job", "PUT", f"/api/v1/opportunities/{opp_id}", lambda p: client.put(f"/api/v1/opportunities/{opp_id}", headers=p_headers, json={
        "project_id": project_id,
        "title": "Supporting Detective Inspector Updated",
        "role_type": "Supporting Role",
        "requirements": "Age 28-45",
        "location": "Mumbai / Goa",
        "compensation": "$3,000/day",
        "status": "open",
    }))

    # 34. PATCH /api/v1/opportunities/{opportunity_id}
    audit_endpoint("Opportunity / Job", "PATCH", f"/api/v1/opportunities/{opp_id}", lambda p: client.patch(f"/api/v1/opportunities/{opp_id}", headers=p_headers, json={
        "compensation": "$3,500/day",
    }))

    # 35. GET /api/v1/opportunities/my
    audit_endpoint("Opportunity / Job", "GET", "/api/v1/opportunities/my", lambda p: client.get(p, headers=p_headers))

    # 36. GET /api/v1/opportunities/search
    audit_endpoint("Opportunity / Job", "GET", "/api/v1/opportunities/search", lambda p: client.get(f"{p}?q=Detective"))

    # 37. GET /api/v1/opportunities/{opportunity_id}/applications
    audit_endpoint("Opportunity / Job", "GET", f"/api/v1/opportunities/{opp_id}/applications", lambda p: client.get(f"/api/v1/opportunities/{opp_id}/applications", headers=p_headers))

    # 38. PATCH /api/v1/opportunities/{opportunity_id}/status
    audit_endpoint("Opportunity / Job", "PATCH", f"/api/v1/opportunities/{opp_id}/status", lambda p: client.patch(f"/api/v1/opportunities/{opp_id}/status", headers=p_headers, json={
        "status": "open"
    }))

    # DELETE /api/v1/opportunities/{opportunity_id} on dummy opp
    dummy_opp_r = client.post("/api/v1/opportunities/", headers=p_headers, json={
        "project_id": project_id,
        "title": "Extra Background Role to Delete",
        "role_type": "Extra",
        "status": "open",
    })
    dummy_opp_id = dummy_opp_r.json().get("id", str(uuid.uuid4())) if dummy_opp_r.status_code == 201 else str(uuid.uuid4())
    # 39. DELETE /api/v1/opportunities/{opportunity_id}
    audit_endpoint("Opportunity / Job", "DELETE", f"/api/v1/opportunities/{dummy_opp_id}", lambda p: client.delete(f"/api/v1/opportunities/{dummy_opp_id}", headers=p_headers))

    # =========================================================================
    # Module 5: Application APIs
    # =========================================================================
    app_obj = {}
    def create_application(p):
        r = client.post(p, headers=t_headers, json={
            "opportunity_id": opp_id,
            "cover_letter": "Audit cover letter expressing interest.",
            "resume_url": "https://storage.cineconnect.test/resumes/audit.pdf",
            "reel_url": "https://vimeo.com/11223344",
        })
        if r.status_code == 201:
            app_obj.update(r.json())
        return r
    # 40. POST /api/v1/applications
    audit_endpoint("Application", "POST", "/api/v1/applications", create_application)
    application_id = app_obj.get("id", str(uuid.uuid4()))

    # 41. GET /api/v1/applications/my
    audit_endpoint("Application", "GET", "/api/v1/applications/my", lambda p: client.get(p, headers=t_headers))

    # 42. GET /api/v1/applications
    audit_endpoint("Application", "GET", "/api/v1/applications", lambda p: client.get(p, headers=p_headers))

    # 43. GET /api/v1/applications/{application_id}
    audit_endpoint("Application", "GET", f"/api/v1/applications/{application_id}", lambda p: client.get(f"/api/v1/applications/{application_id}", headers=t_headers))

    # 44. PATCH /api/v1/applications/{application_id}
    audit_endpoint("Application", "PATCH", f"/api/v1/applications/{application_id}", lambda p: client.patch(f"/api/v1/applications/{application_id}", headers=t_headers, json={
        "cover_letter": "Updated audition cover letter.",
    }))

    # 45. PATCH /api/v1/applications/{application_id}/status
    audit_endpoint("Application", "PATCH", f"/api/v1/applications/{application_id}/status", lambda p: client.patch(f"/api/v1/applications/{application_id}/status", headers=p_headers, json={
        "status": "shortlisted",
    }))

    # DELETE /api/v1/applications/{application_id} on dummy application
    dummy_app_r = client.post("/api/v1/applications/", headers=o_headers, json={
        "opportunity_id": opp_id,
        "cover_letter": "Application to withdraw",
    })
    dummy_app_id = dummy_app_r.json().get("id", str(uuid.uuid4())) if dummy_app_r.status_code == 201 else str(uuid.uuid4())
    # 46. DELETE /api/v1/applications/{application_id}
    audit_endpoint("Application", "DELETE", f"/api/v1/applications/{dummy_app_id}", lambda p: client.delete(f"/api/v1/applications/{dummy_app_id}", headers=o_headers))

    # =========================================================================
    # Module 6: Portfolio Media APIs
    # =========================================================================
    port_obj = {}
    def create_port(p):
        r = client.post(p, headers=t_headers, json={
            "title": "Acting Monologue 2026",
            "description": "Dramatic audition scene.",
            "media_type": "video",
            "media_url": "https://storage.cineconnect.test/portfolio/reel.mp4",
        })
        if r.status_code == 201:
            port_obj.update(r.json())
        return r
    # 47. POST /api/v1/portfolio
    audit_endpoint("Portfolio Media", "POST", "/api/v1/portfolio", create_port)
    media_id = port_obj.get("id", str(uuid.uuid4()))

    # 48. GET /api/v1/portfolio/my
    audit_endpoint("Portfolio Media", "GET", "/api/v1/portfolio/my", lambda p: client.get(p, headers=t_headers))

    # 49. GET /api/v1/portfolio/{media_id}
    audit_endpoint("Portfolio Media", "GET", f"/api/v1/portfolio/{media_id}", lambda p: client.get(f"/api/v1/portfolio/{media_id}"))

    # 50. PUT /api/v1/portfolio/{media_id}
    audit_endpoint("Portfolio Media", "PUT", f"/api/v1/portfolio/{media_id}", lambda p: client.put(f"/api/v1/portfolio/{media_id}", headers=t_headers, json={
        "title": "Acting Monologue 2026 Remastered",
        "description": "Remastered dramatic audition scene.",
        "media_type": "video",
        "media_url": "https://storage.cineconnect.test/portfolio/reel_v2.mp4",
    }))

    # DELETE /api/v1/portfolio/{media_id}
    dummy_port_r = client.post("/api/v1/portfolio/", headers=t_headers, json={
        "title": "Media To Delete",
        "media_type": "image",
        "media_url": "https://storage.cineconnect.test/portfolio/thumb_temp.jpg",
    })
    dummy_media_id = dummy_port_r.json().get("id", str(uuid.uuid4())) if dummy_port_r.status_code == 201 else str(uuid.uuid4())
    # 51. DELETE /api/v1/portfolio/{media_id}
    audit_endpoint("Portfolio Media", "DELETE", f"/api/v1/portfolio/{dummy_media_id}", lambda p: client.delete(f"/api/v1/portfolio/{dummy_media_id}", headers=t_headers))

    # =========================================================================
    # Module 7: Social Posts APIs
    # =========================================================================
    post_obj = {}
    def create_post(p):
        r = client.post(p, headers=t_headers, json={
            "caption": "Audit feed update: Just wrapped shooting scenes! #film #cineconnect",
            "media_url": "https://storage.cineconnect.test/posts/bts.jpg",
        })
        if r.status_code == 201:
            post_obj.update(r.json())
        return r
    # 52. POST /api/v1/posts
    audit_endpoint("Social Posts", "POST", "/api/v1/posts", create_post)
    post_id = post_obj.get("id", str(uuid.uuid4()))

    # 53. GET /api/v1/posts
    audit_endpoint("Social Posts", "GET", "/api/v1/posts", lambda p: client.get(p))

    # 54. GET /api/v1/posts/my
    audit_endpoint("Social Posts", "GET", "/api/v1/posts/my", lambda p: client.get(p, headers=t_headers))

    # 55. GET /api/v1/posts/{post_id}
    audit_endpoint("Social Posts", "GET", f"/api/v1/posts/{post_id}", lambda p: client.get(f"/api/v1/posts/{post_id}"))

    # 56. PUT /api/v1/posts/{post_id}
    audit_endpoint("Social Posts", "PUT", f"/api/v1/posts/{post_id}", lambda p: client.put(f"/api/v1/posts/{post_id}", headers=t_headers, json={
        "caption": "Audit feed update edited caption.",
        "media_url": "https://storage.cineconnect.test/posts/bts_v2.jpg",
    }))

    # DELETE /api/v1/posts/{post_id}
    dummy_post_r = client.post("/api/v1/posts/", headers=t_headers, json={
        "caption": "Temporary post to delete",
    })
    dummy_post_id = dummy_post_r.json().get("id", str(uuid.uuid4())) if dummy_post_r.status_code == 201 else str(uuid.uuid4())
    # 57. DELETE /api/v1/posts/{post_id}
    audit_endpoint("Social Posts", "DELETE", f"/api/v1/posts/{dummy_post_id}", lambda p: client.delete(f"/api/v1/posts/{dummy_post_id}", headers=t_headers))

    # =========================================================================
    # Module 8: Interactions APIs
    # =========================================================================
    # 58. POST /api/v1/interactions
    inter_obj = {}
    def create_inter(p):
        r = client.post(p, headers=p_headers, json={
            "post_id": post_id,
            "type": "comment",
            "comment": "Incredible performance!",
        })
        if r.status_code == 201:
            inter_obj.update(r.json())
        return r
    audit_endpoint("Interactions", "POST", "/api/v1/interactions", create_inter)
    interaction_id = inter_obj.get("id", str(uuid.uuid4()))

    # 59. GET /api/v1/interactions/my
    audit_endpoint("Interactions", "GET", "/api/v1/interactions/my", lambda p: client.get(p, headers=p_headers))

    # 60. GET /api/v1/interactions/{interaction_id}
    audit_endpoint("Interactions", "GET", f"/api/v1/interactions/{interaction_id}", lambda p: client.get(f"/api/v1/interactions/{interaction_id}"))

    # 61. PATCH /api/v1/interactions/{interaction_id}
    audit_endpoint("Interactions", "PATCH", f"/api/v1/interactions/{interaction_id}", lambda p: client.patch(f"/api/v1/interactions/{interaction_id}", headers=p_headers, json={
        "comment": "Incredible performance! (Edited)",
    }))

    # 62. GET /api/v1/posts/{post_id}/interactions (Expected Route in Section 7 & 8)
    audit_endpoint("Interactions", "GET", f"/api/v1/posts/{post_id}/interactions", lambda p: client.get(f"/api/v1/interactions/posts/{post_id}/interactions"))

    # 63. POST /api/v1/posts/{post_id}/interactions (Expected Route in Section 8)
    audit_endpoint("Interactions", "POST", f"/api/v1/posts/{post_id}/interactions", lambda p: client.post(f"/api/v1/interactions/posts/{post_id}/interactions", headers=t_headers, json={
        "comment": "Thank you so much!"
    }))

    # DELETE /api/v1/interactions/{interaction_id}
    dummy_inter_r = client.post("/api/v1/interactions/", headers=t_headers, json={
        "post_id": post_id,
        "type": "like",
    })
    dummy_inter_id = dummy_inter_r.json().get("id", str(uuid.uuid4())) if dummy_inter_r.status_code == 201 else str(uuid.uuid4())
    # 64. DELETE /api/v1/interactions/{interaction_id}
    audit_endpoint("Interactions", "DELETE", f"/api/v1/interactions/{dummy_inter_id}", lambda p: client.delete(f"/api/v1/interactions/{dummy_inter_id}", headers=t_headers))

    # =========================================================================
    # Module 9: Connections / Follow APIs
    # =========================================================================
    # 65. POST /api/v1/connections
    conn_obj = {}
    def create_conn(p):
        r = client.post(p, headers=t_headers, json={
            "receiver_id": other_user_id,
        })
        if r.status_code == 201:
            conn_obj.update(r.json())
        return r
    audit_endpoint("Connections", "POST", "/api/v1/connections", create_conn)
    connection_id = conn_obj.get("id", str(uuid.uuid4()))

    # 66. GET /api/v1/connections/requests
    audit_endpoint("Connections", "GET", "/api/v1/connections/requests", lambda p: client.get(p, headers=o_headers))

    # 67. GET /api/v1/connections/{connection_id}
    audit_endpoint("Connections", "GET", f"/api/v1/connections/{connection_id}", lambda p: client.get(f"/api/v1/connections/{connection_id}", headers=t_headers))

    # 68. PATCH /api/v1/connections/{connection_id}/accept
    audit_endpoint("Connections", "PATCH", f"/api/v1/connections/{connection_id}/accept", lambda p: client.patch(f"/api/v1/connections/{connection_id}/accept", headers=o_headers))

    # 69. GET /api/v1/connections/my
    audit_endpoint("Connections", "GET", "/api/v1/connections/my", lambda p: client.get(p, headers=t_headers))

    # PATCH /api/v1/connections/{connection_id}/reject
    dummy_conn_r = client.post("/api/v1/connections/", headers=p_headers, json={
        "receiver_id": other_user_id,
    })
    dummy_conn_id = dummy_conn_r.json().get("id", str(uuid.uuid4())) if dummy_conn_r.status_code == 201 else str(uuid.uuid4())
    # 70. PATCH /api/v1/connections/{connection_id}/reject
    audit_endpoint("Connections", "PATCH", f"/api/v1/connections/{dummy_conn_id}/reject", lambda p: client.patch(f"/api/v1/connections/{dummy_conn_id}/reject", headers=o_headers))

    # 71. DELETE /api/v1/connections/{connection_id}
    audit_endpoint("Connections", "DELETE", f"/api/v1/connections/{dummy_conn_id}", lambda p: client.delete(f"/api/v1/connections/{dummy_conn_id}", headers=o_headers))

    # =========================================================================
    # Module 10: Collaboration APIs
    # =========================================================================
    # 72. POST /api/v1/collaborations
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
    audit_endpoint("Collaborations", "POST", "/api/v1/collaborations", create_collab)
    collab_id = collab_obj.get("id", str(uuid.uuid4()))

    # 73. GET /api/v1/collaborations/my
    audit_endpoint("Collaborations", "GET", "/api/v1/collaborations/my", lambda p: client.get(p, headers=t_headers))

    # 74. GET /api/v1/collaborations/{collaboration_id}
    audit_endpoint("Collaborations", "GET", f"/api/v1/collaborations/{collab_id}", lambda p: client.get(f"/api/v1/collaborations/{collab_id}", headers=t_headers))

    # 75. PATCH /api/v1/collaborations/{collaboration_id}/accept
    audit_endpoint("Collaborations", "PATCH", f"/api/v1/collaborations/{collab_id}/accept", lambda p: client.patch(f"/api/v1/collaborations/{collab_id}/accept", headers=t_headers))

    # 76. PATCH /api/v1/collaborations/{collaboration_id}/status
    audit_endpoint("Collaborations", "PATCH", f"/api/v1/collaborations/{collab_id}/status", lambda p: client.patch(f"/api/v1/collaborations/{collab_id}/status", headers=p_headers, json={
        "status": "completed",
    }))

    # PATCH /api/v1/collaborations/{collaboration_id}/reject on dummy
    dummy_collab_r = client.post("/api/v1/collaborations/", headers=p_headers, json={
        "project_id": project_id,
        "talent_id": other_user_id,
        "role": "Sound Recordist",
    })
    dummy_collab_id = dummy_collab_r.json().get("id", str(uuid.uuid4())) if dummy_collab_r.status_code == 201 else str(uuid.uuid4())
    # 77. PATCH /api/v1/collaborations/{collaboration_id}/reject
    audit_endpoint("Collaborations", "PATCH", f"/api/v1/collaborations/{dummy_collab_id}/reject", lambda p: client.patch(f"/api/v1/collaborations/{dummy_collab_id}/reject", headers=o_headers))

    # 78. DELETE /api/v1/collaborations/{collaboration_id}
    audit_endpoint("Collaborations", "DELETE", f"/api/v1/collaborations/{dummy_collab_id}", lambda p: client.delete(f"/api/v1/collaborations/{dummy_collab_id}", headers=o_headers))

    # =========================================================================
    # Module 11: Messaging / Chat APIs
    # =========================================================================
    # 79. POST /api/v1/messages
    msg_obj = {}
    def create_msg(p):
        r = client.post(p, headers=p_headers, json={
            "recipient_id": talent_id,
            "body": "Hello Alice! Calling about the casting call.",
        })
        if r.status_code == 201:
            msg_obj.update(r.json())
        return r
    audit_endpoint("Messaging", "POST", "/api/v1/messages", create_msg)
    message_id = msg_obj.get("id", str(uuid.uuid4()))

    # 80. GET /api/v1/messages/unread-count
    audit_endpoint("Messaging", "GET", "/api/v1/messages/unread-count", lambda p: client.get(p, headers=t_headers))

    # 81. GET /api/v1/messages/conversations
    audit_endpoint("Messaging", "GET", "/api/v1/messages/conversations", lambda p: client.get(p, headers=t_headers))

    # 82. GET /api/v1/messages/conversations/{user_id}
    audit_endpoint("Messaging", "GET", f"/api/v1/messages/conversations/{ph_user_id}", lambda p: client.get(f"/api/v1/messages/conversations/{ph_user_id}", headers=t_headers))

    # 83. GET /api/v1/messages/{message_id}
    audit_endpoint("Messaging", "GET", f"/api/v1/messages/{message_id}", lambda p: client.get(f"/api/v1/messages/{message_id}", headers=t_headers))

    # DELETE /api/v1/messages/{message_id}
    dummy_msg_r = client.post("/api/v1/messages/", headers=t_headers, json={
        "recipient_id": ph_user_id,
        "body": "Temporary message to delete",
    })
    dummy_msg_id = dummy_msg_r.json().get("id", str(uuid.uuid4())) if dummy_msg_r.status_code == 201 else str(uuid.uuid4())
    # 84. DELETE /api/v1/messages/{message_id}
    audit_endpoint("Messaging", "DELETE", f"/api/v1/messages/{dummy_msg_id}", lambda p: client.delete(f"/api/v1/messages/{dummy_msg_id}", headers=t_headers))

    # =========================================================================
    # Module 12: Additional Application APIs
    # =========================================================================
    # 85. GET /api/v1/search
    audit_endpoint("Search", "GET", "/api/v1/search", lambda p: client.get(f"{p}?q=Audit"))

    # 86. GET /api/v1/notifications
    audit_endpoint("Notifications", "GET", "/api/v1/notifications", lambda p: client.get(p, headers=t_headers))

    # 87. GET /api/v1/notifications/unread-count
    audit_endpoint("Notifications", "GET", "/api/v1/notifications/unread-count", lambda p: client.get(p, headers=t_headers))

    # 88. PATCH /api/v1/notifications/read-all
    audit_endpoint("Notifications", "PATCH", "/api/v1/notifications/read-all", lambda p: client.patch(p, headers=t_headers))

    # Note: PATCH /api/v1/notifications/{notification_id}/read
    # Insert a dummy notification for this user to test single read
    from app.db.session import AsyncSessionLocal
    from app.models.notification import Notification
    async def insert_test_notif():
        async with AsyncSessionLocal() as session:
            notif = Notification(
                user_id=uuid.UUID(talent_id),
                title="Audit Notification",
                message="Your audition was reviewed.",
                type="application",
            )
            session.add(notif)
            await session.commit()
            await session.refresh(notif)
            return str(notif.id)
    notif_id = asyncio.run(insert_test_notif())
    # 89. PATCH /api/v1/notifications/{notification_id}/read
    audit_endpoint("Notifications", "PATCH", f"/api/v1/notifications/{notif_id}/read", lambda p: client.patch(f"/api/v1/notifications/{notif_id}/read", headers=t_headers))

    # 90. POST /api/v1/media/upload-url
    audit_endpoint("Media Storage", "POST", "/api/v1/media/upload-url", lambda p: client.post(p, headers=t_headers, json={
        "file_name": "headshot_audit.jpg",
        "content_type": "image/jpeg",
        "file_size_bytes": 2048576,
    }))

    # 91. GET /api/v1/dashboard/talent
    audit_endpoint("Dashboards", "GET", "/api/v1/dashboard/talent", lambda p: client.get(p, headers=t_headers))

    # 92. GET /api/v1/dashboard/production-house
    audit_endpoint("Dashboards", "GET", "/api/v1/dashboard/production-house", lambda p: client.get(p, headers=p_headers))

    # Print Full Markdown Report Table
    print("\n" + "=" * 90)
    print("AUDIT RESULTS TABLE")
    print("=" * 90)
    print("| Module | HTTP Method | Expected Route | Actual Route | HTTP Status | Test Result |")
    print("|---|---|---|---|---|---|")
    for r in results:
        print(f"| {r['module']} | {r['method']} | `{r['expected_route']}` | `{r['actual_route']}` | {r['http_status']} | **{r['test_result']}** |")

    # Counts
    total_expected = len(results)
    passed = sum(1 for r in results if r["test_result"] == "PASS")
    failed = sum(1 for r in results if r["test_result"] == "FAIL")
    blocked = sum(1 for r in results if r["test_result"] == "BLOCKED")
    not_tested = sum(1 for r in results if r["test_result"] == "NOT TESTED")
    missing = sum(1 for r in results if r["test_result"] == "MISSING")
    mismatches = sum(1 for r in results if r["test_result"] == "ROUTE MISMATCH")
    matched = total_expected - mismatches - missing

    print("\n" + "=" * 50)
    print("CALCULATED METRICS")
    print("=" * 50)
    print(f"Total expected HTTP endpoints: {total_expected}")
    print(f"Total matched HTTP endpoints: {matched}")
    print(f"Total successfully tested HTTP endpoints: {passed}")
    print(f"Total failed endpoints: {failed}")
    print(f"Total blocked endpoints: {blocked}")
    print(f"Total missing endpoints: {missing}")
    print(f"Total route mismatches: {mismatches}")

if __name__ == "__main__":
    run_comprehensive_audit()
