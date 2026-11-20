# CineConnect — Talent User Portal Production UI/UX Architecture & API Guide

## 1. Executive Summary: 100% Talent-Centric Cinema Super-App

CineConnect is engineered exclusively for **Individual 24-Crafts Cinema Talent** (Actors, Directors, Cinematographers, Sound Designers, Stunt Coordinators, Editors, Colorists, Gaffers, and Crew). It consolidates three industry paradigms into one unified, production-grade Flutter application:

1. **LinkedIn for Cinema**: Professional networking across 24 film crafts, cryptographically verified guild IDs (SICA, ISC, CINTAA, SWA), verified crew credits ledgers, daily call-sheet availability calendars, and frame-accurate SMPTE 24fps master showreel critiques.
2. **Naukri for Cinema**: Open Pan-India and global casting/crew calls, real-time **Skill Match % Engine** (e.g. 96% Match with green matched tags vs missing tags), 12pt Courier screenplay sides preview, 1-tap self-tape application submissions, and an **Auditions Status Progression Tracker** (`Submitted` → `Under Director Review` → `Shortlisted` → `Call-Sheet Hold` → `Booked`).
3. **Instagram Reels for Cinema (CineReels)**: Full 9:16 vertical showreels, double-tap radiant gold heart bursts, audio track info with sync FX, frame-accurate timecode critique notes, bookmarking to digital slate, and direct peer collaboration inquiries.
4. **24-Crafts Talent Radar & Peer Network**: Discover and connect with fellow technicians and artists filtered by craft, hub location, verified equipment owned (ARRI Alexa 35, Steadicam M-2, DaVinci Resolve, Schoeps), and immediate shoot availability.
5. **Digital Slate Profile**: Interactive clapperboard with snap animation ("CLAP! Scene 84A, Take 03"), shoot availability calendar, live skills matrix customizer, and cryptographically verified filmography ledger.

---

## 2. Design System Tokens (Palette Specified)

```dart
// Exact tokens in lib/core/theme/app_theme.dart
class CineColors {
  // User Exact Primary Palette:
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFF1D675);
  static const Color surface = Color(0xFF161616);
  static const Color border = Color(0xFF2A2A2A);
  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textMuted = Color(0xFF9A9A9A);
  static const Color error = Color(0xFFE5484D);

  // OLED Cinema & Anamorphic Extension
  static const Color background = Color(0xFF0B0C10); // 0.005 nit OLED true black
  static const Color surfaceElevated = Color(0xFF1C1C22);
  static const Color surfaceCard = Color(0xFF141419);
  static const Color success = Color(0xFF10B981);    // 96% Match & Guild Badges
  static const Color warning = Color(0xFFF59E0B);    // 35mm Amber Warning
}
```

---

## 3. Talent API Integration Matrix

All routes are implemented in [`lib/core/network/api_endpoints.dart`](file:///c:/Users/DELL/cine_connect_app1/CineConnect/mobile/lib/core/network/api_endpoints.dart) and [`lib/core/services/talent_api_service.dart`](file:///c:/Users/DELL/cine_connect_app1/CineConnect/mobile/lib/core/services/talent_api_service.dart).

### 3.1 Talent-Specific Endpoints Utilized

| Module | Method | Endpoint | Purpose for Talent User Portal |
| :--- | :--- | :--- | :--- |
| **Health** | `GET` | `/health` & `/api/v1/health` | Backend status check |
| **Talent Profile** | `GET` | `/api/v1/users/me` | Fetch authenticated talent profile |
| | `PUT` | `/api/v1/users/me` | Complete profile replacement |
| | `PATCH` | `/api/v1/users/me` | Update skills, day rate, shoot availability |
| | `GET` | `/api/v1/users/{user_id}` | View peer public slate profile |
| | `GET` | `/api/v1/users` | List 24-Crafts talent radar peers |
| | `GET` | `/api/v1/users/search` | Search fellow technicians and actors |
| | `GET` | `/api/v1/users/{user_id}/portfolio` | Inspect peer showreels |
| **Casting Calls** | `GET` | `/api/v1/opportunities/` | Browse casting & crew calls (trailing slash preserved) |
| | `GET` | `/api/v1/opportunities/{id}` | Read 12pt Courier screenplay audition sides |
| | `GET` | `/api/v1/opportunities/search` | Search calls by craft and skill tags |
| **Audition Apps** | `POST` | `/api/v1/applications/` | 1-Tap apply with self-tape video URL |
| | `GET` | `/api/v1/applications/my` | My Auditions Status Tracker |
| | `DELETE` | `/api/v1/applications/{id}` | Withdraw application |
| **Portfolio Media** | `GET` | `/api/v1/portfolio/my` | List showreels on digital slate |
| | `POST` | `/api/v1/portfolio/` | Add SMPTE showreel / video slate |
| | `DELETE` | `/api/v1/portfolio/{id}` | Delete portfolio item |
| | `POST` | `/api/v1/media/upload-url` | Request presigned S3 upload URL for reels |
| **Social Feed** | `GET` | `/api/v1/posts/` | Fetch cinema industry feed |
| | `POST` | `/api/v1/posts/` | Publish wrap post / reel slate |
| | `POST` | `/api/v1/interactions/` | Clapper clap / SMPTE timecode critique note |
| **Connections** | `POST` | `/api/v1/connections/` | Send peer connection request |
| | `GET` | `/api/v1/connections/my` | List connected 24-crafts crew |
| | `GET` | `/api/v1/connections/requests`| Received peer connection requests |
| | `PATCH` | `/api/v1/connections/{id}/accept`| Accept peer connection |
| | `PATCH` | `/api/v1/connections/{id}/reject`| Decline peer connection |
| **Collaborations** | `GET` | `/api/v1/collaborations/my` | Inbound film project invitations |
| | `PATCH` | `/api/v1/collaborations/{id}/accept` | Accept project collaboration |
| | `PATCH` | `/api/v1/collaborations/{id}/reject` | Reject project collaboration |
| **Chat & DMs** | `POST` | `/api/v1/messages/` | Send direct message to peer |
| | `GET` | `/api/v1/messages/conversations` | List conversation threads |
| | `GET` | `/api/v1/messages/unread-count` | Unread badge indicator |
| | `WS` | `/ws/chat?token=<JWT>` | Real-time WebSocket chat connection |
| **Notifications** | `GET` | `/api/v1/notifications/` | Audition review updates & connection alerts |
| | `PATCH` | `/api/v1/notifications/read-all`| Mark all notifications read |
| **Dashboard** | `GET` | `/api/v1/dashboard/talent` | Talent Overview Analytics |

---

### 3.2 Strictly Excluded Routes (Production House Portal — NOT Merged)

The following backend endpoints belong solely to production houses and have been deliberately excluded from the Talent User Portal:
- `POST/GET/PUT /api/v1/production-houses/*`
- `POST /api/v1/projects`, `PUT/PATCH/DELETE /api/v1/projects/*`
- `POST/PUT/PATCH/DELETE /api/v1/opportunities/*`, `GET /api/v1/opportunities/my`
- `GET /api/v1/opportunities/{id}/applications`, `PATCH /api/v1/opportunities/{id}/status`
- `GET /api/v1/applications/` (recruiter review), `PATCH /api/v1/applications/{id}/status`
- `POST /api/v1/collaborations/` (producer dispatching invites)
- `GET /api/v1/dashboard/production-house`

---

## 4. Mobile Architecture (mobile/lib/)

```
CineConnect/mobile/lib/
├── app/
│   └── app.dart                        # Pure Talent Portal root shell
├── core/
│   ├── models/craft_models.dart        # 24 Crafts, Profiles, Jobs, Reels, Stories
│   ├── network/
│   │   ├── api_endpoints.dart          # Talent-only API route constants
│   │   └── api_client.dart             # HTTP client with Supabase Bearer Auth
│   ├── services/
│   │   └── talent_api_service.dart     # Service layer for all talent endpoints
│   ├── state/app_state.dart            # Reactive ChangeNotifier state & match engine
│   └── theme/app_theme.dart            # Cinema OLED Material 3 theme & color tokens
├── features/
│   ├── auth/talent_auth_modal.dart     # 3-step talent guild onboarding & sign-in
│   ├── feed/linkedin_cinema_feed.dart  # LinkedIn for Cinema, SMPTE player & LogC4 wipe
│   ├── header/app_header.dart          # Golden aperture, talent badge, hub filter, story rings
│   ├── jobs/naukri_casting_board.dart  # Naukri Casting board & auditions tracker
│   ├── navigation/cine_bottom_nav_bar.dart # Home, Opportunities, Create(+), Search, Profile
│   ├── profile/digital_slate_profile.dart # Clapperboard slate, calendar & filmography
│   ├── radar/talent_network_radar.dart # 24-Crafts peer networking & slate inspection
│   ├── reels/cinereels_view.dart       # 9:16 Instagram Reels, gold hearts & connect
│   ├── specs/architecture_inspector_dialog.dart # In-app Dart code & specs inspector
│   └── stories/story_viewer_dialog.dart # Full-screen on-set soundstage story viewer
└── main.dart                           # Entrypoint with OLED system overlay config
```
