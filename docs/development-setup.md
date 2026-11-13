# CineConnect – Local Development Setup Guide (Windows)

This document provides a complete step-by-step walkthrough for configuring your local development environment on Windows.

---

## 1. Prerequisites

Ensure the following tools are installed on your Windows machine:

1. **Git for Windows**:
   - Download: https://git-scm.com/download/win
   - Ensure Git is available in PowerShell (`git --version`).

2. **Flutter SDK (3.24+ / stable channel)**:
   - Download: https://docs.flutter.dev/get-started/install/windows
   - Add Flutter's `bin/` directory to your System `PATH`.
   - Run `flutter doctor` to verify Android toolchain status.

3. **Android Studio & Android SDK**:
   - Install Android Studio, Android SDK Build-Tools, and configure an Android Virtual Device (AVD).
   - Verify emulator launch from Android Studio Device Manager.

4. **Python (3.12 recommended)**:
   - Download: https://www.python.org/downloads/
   - During setup, check **"Add python.exe to PATH"**.
   - Verify in PowerShell:
     ```powershell
     py -3.12 --version
     ```

5. **Docker Desktop for Windows**:
   - Download: https://www.docker.com/products/docker-desktop/
   - Enable WSL 2 backend integration.

---

## 2. Repository Configuration

1. Clone or open the CineConnect repository:
   ```powershell
   cd d:\CineConnect
   ```

2. Create your local `.env` file from `.env.example`:
   ```powershell
   Copy-Item .env.example .env
   ```

3. Review `.env` and customize database credentials or ports if necessary.

---

## 3. Backend Setup & Local Verification

### Option A: Run Backend via Docker Compose (Recommended)
From the project root:
```powershell
cd infrastructure
docker compose up --build -d
```
Check container status:
```powershell
docker compose ps
docker compose logs -f backend
```
Verify the health endpoint in your browser or PowerShell:
```powershell
Invoke-RestMethod http://localhost:8000/health
Invoke-RestMethod http://localhost:8000/api/v1/health/db
```

### Option B: Run Backend Directly on Host (Python 3.12)
1. Navigate to `backend/`:
   ```powershell
   cd backend
   ```
2. Create and activate a Python virtual environment:
   ```powershell
   py -3.12 -m venv .venv
   .\.venv\Scripts\Activate.ps1
   ```
   *(If script execution is disabled, run `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`)*

3. Install required packages:
   ```powershell
   pip install -r requirements.txt
   ```

4. Run the automated test suite:
   ```powershell
   pytest -v
   ```

5. Start the FastAPI development server:
   ```powershell
   uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
   ```

6. Open interactive API docs:
   - Swagger UI: http://localhost:8000/docs
   - ReDoc: http://localhost:8000/redoc

---

## 4. Mobile Frontend Setup (Flutter)

1. Open a new terminal and navigate to `mobile/`:
   ```powershell
   cd mobile
   ```

2. Fetch Flutter packages:
   ```powershell
   flutter pub get
   ```

3. Verify code quality and static analysis:
   ```powershell
   flutter analyze
   ```

4. Run Flutter widget tests:
   ```powershell
   flutter test
   ```

---

## 5. Running on Android Emulator & Devices

### Android Emulator
The Android emulator uses `10.0.2.2` to loop back to services running on your Windows host. CineConnect includes built-in detection for this.

1. Launch your Android Virtual Device (AVD) from Android Studio.
2. Run CineConnect:
   ```powershell
   flutter run
   ```
   Or explicitly pass the base URL:
   ```powershell
   flutter run --dart-define=APP_ENV=local --dart-define=API_BASE_URL=http://10.0.2.2:8000
   ```

### Physical Android Device
When debugging on a physical phone connected over Wi-Fi:
1. Find your Windows computer's local IP address:
   ```powershell
   ipconfig
   # Look for IPv4 Address (e.g., 192.168.1.50)
   ```
2. Ensure Windows Defender firewall allows inbound connections on port `8000`.
3. Launch the app with your LAN IP:
   ```powershell
   flutter run --dart-define=API_BASE_URL=http://192.168.1.50:8000
   ```

---

## 6. Troubleshooting Common Issues

| Issue | Cause | Solution |
|---|---|---|
| `docker is not recognized` | Docker Desktop not running or not in PATH | Launch Docker Desktop from the Start menu and ensure WSL 2 integration is enabled. |
| Backend DB health returns 503 | PostgreSQL container not started or credentials mismatch | Verify container is healthy via `docker compose ps` and check `.env` credentials. |
| Android emulator cannot reach API | Using `localhost` instead of `10.0.2.2` | Pass `--dart-define=API_BASE_URL=http://10.0.2.2:8000`. |
| PowerShell script execution error | ExecutionPolicy restricted | Run `Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned`. |

