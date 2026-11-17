import sys
import uuid
import httpx
from app.core.security import create_test_token

BASE_URL = "http://localhost:8000"

def run_tests():
    print("=" * 70)
    print("CineConnect End-to-End API Verification Suite")
    print("=" * 70)

    # 1. Generate JWT tokens for test personas
    test_run_id = uuid.uuid4().hex[:6]
    talent_sub = str(uuid.uuid4())
    ph_sub = str(uuid.uuid4())

    talent_token = create_test_token(
        user_id=talent_sub,
        email=f"alice_{test_run_id}@cineconnect.test",
        role="talent",
        extra_claims={"user_metadata": {"full_name": "Alice Star", "role": "talent"}},
    )
    ph_token = create_test_token(
        user_id=ph_sub,
        email=f"bob_{test_run_id}@cineconnect.test",
        role="production_house",
        extra_claims={"user_metadata": {"full_name": "Bob Producer", "role": "production_house"}},
    )

    client = httpx.Client(base_url=BASE_URL, timeout=10.0)

    # Helpers
    def get_auth(token):
        return {"Authorization": f"Bearer {token}"}

    # Module 16: Health Checks
    print("\n[Module 16: Health]")
    r = client.get("/health")
    assert r.status_code == 200, f"Root health failed: {r.text}"
    print("  ✓ GET /health -> 200")

    r = client.get("/api/v1/health")
    assert r.status_code == 200, f"API health failed: {r.text}"
    print("  ✓ GET /api/v1/health -> 200")

    r = client.get("/api/v1/health/db")
    assert r.status_code == 200, f"DB health failed: {r.text}"
    print("  ✓ GET /api/v1/health/db -> 200")

    # Module 1: User / Talent Profiles
    print("\n[Module 1: User / Talent Profiles]")
    r = client.get("/api/v1/users/me", headers=get_auth(talent_token))
    assert r.status_code == 200, f"User me failed: {r.text}"
    talent_user = r.json()
    print(f"  ✓ GET /api/v1/users/me -> 200 (Talent: {talent_user['email']})")

    r = client.put("/api/v1/users/me", headers=get_auth(talent_token), json={
        "full_name": "Alice Star Updated",
        "role": "Actor / Dancer",
        "location": "Mumbai, India",
        "bio": "Experienced actor with multiple short films.",
        "phone": "+919876543210",
        "experience_years": 4,
    })
    assert r.status_code == 200, f"PUT user me failed: {r.text}"
    print("  ✓ PUT /api/v1/users/me -> 200")

    r = client.get(f"/api/v1/users/{talent_sub}", headers=get_auth(ph_token))
    assert r.status_code == 200, f"GET user by id failed: {r.text}"
    print(f"  ✓ GET /api/v1/users/{talent_sub} -> 200")

    r = client.get("/api/v1/users/search?q=Alice", headers=get_auth(ph_token))
    assert r.status_code == 200, f"Search users failed: {r.text}"
    assert len(r.json()["items"]) >= 1, "User search returned no items"
    print("  ✓ GET /api/v1/users/search -> 200")

    # Module 2: Production Houses
    print("\n[Module 2: Production Houses]")
    # First sync Bob as PH user
    r = client.get("/api/v1/users/me", headers=get_auth(ph_token))
    assert r.status_code == 200

    r = client.post("/api/v1/production-houses", headers=get_auth(ph_token), json={
        "company_name": "Starlight Cinema Studios",
        "description": "Premier indie production company focused on drama & sci-fi.",
        "location": "Bandra, Mumbai",
        "website": "https://starlightcinema.test",
        "specialization": "Feature Films, Indie Dramas",
    })
    assert r.status_code == 201, f"Create PH failed: {r.text}"
    ph = r.json()
    ph_id = ph["id"]
    print(f"  ✓ POST /api/v1/production-houses -> 201 (PH ID: {ph_id})")

    r = client.get("/api/v1/production-houses/me", headers=get_auth(ph_token))
    assert r.status_code == 200, f"GET PH me failed: {r.text}"
    print("  ✓ GET /api/v1/production-houses/me -> 200")

    r = client.get(f"/api/v1/production-houses/{ph_id}")
    assert r.status_code == 200, f"GET PH by id failed: {r.text}"
    print("  ✓ GET /api/v1/production-houses/{house_id} -> 200")

    # Module 3: Projects
    print("\n[Module 3: Projects]")
    r = client.post("/api/v1/projects", headers=get_auth(ph_token), json={
        "title": "Echoes of Eternity",
        "synopsis": "A mysterious signal from deep space alters the timeline of a cinematic crew.",
        "genre": "Sci-Fi / Mystery",
        "status": "pre-production",
        "budget": "$1,500,000",
    })
    assert r.status_code == 201, f"Create project failed: {r.text}"
    project = r.json()
    project_id = project["id"]
    print(f"  ✓ POST /api/v1/projects -> 201 (Project ID: {project_id})")

    r = client.get("/api/v1/projects/my", headers=get_auth(ph_token))
    assert r.status_code == 200, f"GET my projects failed: {r.text}"
    print("  ✓ GET /api/v1/projects/my -> 200")

    r = client.get(f"/api/v1/projects/{project_id}")
    assert r.status_code == 200, f"GET project by id failed: {r.text}"
    print("  ✓ GET /api/v1/projects/{project_id} -> 200")

    # Module 4: Opportunities
    print("\n[Module 4: Opportunities]")
    r = client.post("/api/v1/opportunities/", headers=get_auth(ph_token), json={
        "project_id": project_id,
        "title": "Lead Scientist Dr. Sophia",
        "role_type": "Lead Actress",
        "requirements": "Strong emotional range, sci-fi fluency, Age 25-35",
        "location": "Mumbai",
        "compensation": "Standard SAG Rate",
        "status": "open",
    })
    assert r.status_code == 201, f"Create opportunity failed: {r.text}"
    opp = r.json()
    opp_id = opp["id"]
    print(f"  ✓ POST /api/v1/opportunities/ -> 201 (Opp ID: {opp_id})")

    r = client.get("/api/v1/opportunities/")
    assert r.status_code == 200, f"List opportunities failed: {r.text}"
    print("  ✓ GET /api/v1/opportunities/ -> 200")

    r = client.get(f"/api/v1/opportunities/{opp_id}")
    assert r.status_code == 200, f"GET opportunity failed: {r.text}"
    print("  ✓ GET /api/v1/opportunities/{opportunity_id} -> 200")

    # Module 5: Applications
    print("\n[Module 5: Applications]")
    r = client.post("/api/v1/applications/", headers=get_auth(talent_token), json={
        "opportunity_id": opp_id,
        "cover_letter": "I have extensive experience portraying complex dramatic characters.",
        "resume_url": "https://storage.cineconnect.test/resumes/alice.pdf",
        "reel_url": "https://vimeo.com/987654321",
    })
    assert r.status_code == 201, f"Apply failed: {r.text}"
    application = r.json()
    app_id = application["id"]
    print(f"  ✓ POST /api/v1/applications/ -> 201 (Application ID: {app_id})")

    r = client.get("/api/v1/applications/my", headers=get_auth(talent_token))
    assert r.status_code == 200, f"GET my applications failed: {r.text}"
    print("  ✓ GET /api/v1/applications/my -> 200")

    r = client.get(f"/api/v1/opportunities/{opp_id}/applications", headers=get_auth(ph_token))
    assert r.status_code == 200, f"GET opportunity applications failed: {r.text}"
    print("  ✓ GET /api/v1/opportunities/{opportunity_id}/applications -> 200")

    r = client.patch(f"/api/v1/applications/{app_id}/status", headers=get_auth(ph_token), json={
        "status": "shortlisted"
    })
    assert r.status_code == 200, f"Update application status failed: {r.text}"
    assert r.json()["status"] == "shortlisted"
    print("  ✓ PATCH /api/v1/applications/{application_id}/status -> 200 (status: shortlisted)")

    # Module 6: Portfolio Media
    print("\n[Module 6: Portfolio Media]")
    r = client.post("/api/v1/portfolio/", headers=get_auth(talent_token), json={
        "title": "Dramatic Monologue 2026",
        "description": "Scene from Macbeth performed at Prithvi Theatre",
        "media_type": "video",
        "media_url": "https://storage.cineconnect.test/portfolio/alice_monologue.mp4",
        "thumbnail_url": "https://storage.cineconnect.test/portfolio/alice_thumb.jpg",
    })
    assert r.status_code == 201, f"Create portfolio item failed: {r.text}"
    portfolio_item = r.json()
    media_id = portfolio_item["id"]
    print(f"  ✓ POST /api/v1/portfolio/ -> 201 (Media ID: {media_id})")

    r = client.get("/api/v1/portfolio/my", headers=get_auth(talent_token))
    assert r.status_code == 200, f"GET my portfolio failed: {r.text}"
    print("  ✓ GET /api/v1/portfolio/my -> 200")

    # Module 7: Social Posts
    print("\n[Module 7: Social Posts]")
    r = client.post("/api/v1/posts/", headers=get_auth(talent_token), json={
        "caption": "Excited to be shortlisted for a thrilling sci-fi feature! #actorslife #cineconnect",
        "media_url": "https://storage.cineconnect.test/posts/bts_onset.jpg",
    })
    assert r.status_code == 201, f"Create post failed: {r.text}"
    post = r.json()
    post_id = post["id"]
    print(f"  ✓ POST /api/v1/posts/ -> 201 (Post ID: {post_id})")

    r = client.get("/api/v1/posts/")
    assert r.status_code == 200, f"List posts failed: {r.text}"
    print("  ✓ GET /api/v1/posts/ -> 200")

    # Module 8: Interactions
    print("\n[Module 8: Interactions]")
    r = client.post("/api/v1/interactions/", headers=get_auth(ph_token), json={
        "post_id": post_id,
        "type": "comment",
        "comment": "Congratulations Alice! Looking forward to your chemistry test.",
    })
    assert r.status_code == 201, f"Add comment failed: {r.text}"
    print("  ✓ POST /api/v1/interactions/ -> 201")

    r = client.get(f"/api/v1/interactions/posts/{post_id}/interactions")
    assert r.status_code == 200, f"List post interactions failed: {r.text}"
    print(f"  ✓ GET /api/v1/interactions/posts/{post_id}/interactions -> 200")

    # Module 9: Connections / Network
    print("\n[Module 9: Connections]")
    r = client.post("/api/v1/connections/", headers=get_auth(talent_token), json={
        "receiver_id": ph_sub
    })
    assert r.status_code == 201, f"Send connection failed: {r.text}"
    conn = r.json()
    conn_id = conn["id"]
    print(f"  ✓ POST /api/v1/connections/ -> 201 (Connection ID: {conn_id})")

    r = client.get("/api/v1/connections/requests", headers=get_auth(ph_token))
    assert r.status_code == 200, f"List requests failed: {r.text}"
    print("  ✓ GET /api/v1/connections/requests -> 200")

    r = client.patch(f"/api/v1/connections/{conn_id}/accept", headers=get_auth(ph_token))
    assert r.status_code == 200, f"Accept connection failed: {r.text}"
    print(f"  ✓ PATCH /api/v1/connections/{conn_id}/accept -> 200")

    r = client.get("/api/v1/connections/my", headers=get_auth(talent_token))
    assert r.status_code == 200, f"List my connections failed: {r.text}"
    print("  ✓ GET /api/v1/connections/my -> 200")

    # Module 10: Collaborations
    print("\n[Module 10: Collaborations]")
    r = client.post("/api/v1/collaborations/", headers=get_auth(ph_token), json={
        "project_id": project_id,
        "talent_id": talent_sub,
        "role": "Lead Actress",
    })
    assert r.status_code == 201, f"Create collaboration failed: {r.text}"
    collab = r.json()
    collab_id = collab["id"]
    print(f"  ✓ POST /api/v1/collaborations/ -> 201 (Collaboration ID: {collab_id})")

    r = client.get("/api/v1/collaborations/my", headers=get_auth(talent_token))
    assert r.status_code == 200, f"GET my collaborations failed: {r.text}"
    print("  ✓ GET /api/v1/collaborations/my -> 200")

    r = client.patch(f"/api/v1/collaborations/{collab_id}/accept", headers=get_auth(talent_token))
    assert r.status_code == 200, f"Accept collaboration failed: {r.text}"
    print(f"  ✓ PATCH /api/v1/collaborations/{collab_id}/accept -> 200")

    # Module 11: Direct Messages
    print("\n[Module 11: Direct Messages]")
    r = client.post("/api/v1/messages/", headers=get_auth(ph_token), json={
        "recipient_id": talent_sub,
        "body": "Hi Alice, welcome to Echoes of Eternity! Contract is being prepared.",
    })
    assert r.status_code == 201, f"Send message failed: {r.text}"
    msg = r.json()
    print(f"  ✓ POST /api/v1/messages/ -> 201 (Message ID: {msg['id']})")

    r = client.get("/api/v1/messages/unread-count", headers=get_auth(talent_token))
    assert r.status_code == 200, f"Unread count failed: {r.text}"
    assert r.json()["unread_count"] >= 1
    print(f"  ✓ GET /api/v1/messages/unread-count -> 200 (unread: {r.json()['unread_count']})")

    r = client.get("/api/v1/messages/conversations", headers=get_auth(talent_token))
    assert r.status_code == 200, f"List conversations failed: {r.text}"
    print("  ✓ GET /api/v1/messages/conversations -> 200")

    r = client.get(f"/api/v1/messages/conversations/{ph_sub}", headers=get_auth(talent_token))
    assert r.status_code == 200, f"Thread failed: {r.text}"
    print(f"  ✓ GET /api/v1/messages/conversations/{ph_sub} -> 200 (thread read)")

    # Module 12: Global Cross-Entity Search
    print("\n[Module 12: Global Search]")
    r = client.get("/api/v1/search/?q=Alice")
    assert r.status_code == 200, f"Global search failed: {r.text}"
    search_data = r.json()
    print(f"  ✓ GET /api/v1/search/?q=Alice -> 200 (Users found: {len(search_data['users'])})")

    # Module 13: Notifications
    print("\n[Module 13: Notifications]")
    r = client.get("/api/v1/notifications/", headers=get_auth(talent_token))
    assert r.status_code == 200, f"List notifications failed: {r.text}"
    print("  ✓ GET /api/v1/notifications/ -> 200")

    r = client.get("/api/v1/notifications/unread-count", headers=get_auth(talent_token))
    assert r.status_code == 200, f"Notification unread count failed: {r.text}"
    print(f"  ✓ GET /api/v1/notifications/unread-count -> 200")

    # Module 14: Media Upload
    print("\n[Module 14: Media Upload URL]")
    r = client.post("/api/v1/media/upload-url", headers=get_auth(talent_token), json={
        "file_name": "headshot_2026.jpg",
        "content_type": "image/jpeg",
        "file_size_bytes": 1048576,
    })
    assert r.status_code == 200, f"Media upload url failed: {r.text}"
    media_upload = r.json()
    assert "upload_url" in media_upload and "file_key" in media_upload
    print(f"  ✓ POST /api/v1/media/upload-url -> 200 (Presigned URL generated)")

    # Module 15: Role-based Dashboards
    print("\n[Module 15: Dashboards]")
    r = client.get("/api/v1/dashboard/talent", headers=get_auth(talent_token))
    assert r.status_code == 200, f"Talent dashboard failed: {r.text}"
    td = r.json()
    print(f"  ✓ GET /api/v1/dashboard/talent -> 200 (Apps: {td['total_applications']}, Shortlisted: {td['shortlisted_applications']}, Connections: {td['total_connections']})")

    r = client.get("/api/v1/dashboard/production-house", headers=get_auth(ph_token))
    assert r.status_code == 200, f"PH dashboard failed: {r.text}"
    phd = r.json()
    print(f"  ✓ GET /api/v1/dashboard/production-house -> 200 (Projects: {phd['total_projects']}, Opps: {phd['total_opportunities']}, Received Apps: {phd['total_applications_received']})")

    print("\n" + "=" * 70)
    print("ALL API TESTS PASSED SUCCESSFULLY (100% Endpoints Verified)")
    print("=" * 70)

if __name__ == "__main__":
    run_tests()
