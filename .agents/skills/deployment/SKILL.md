# Deployment Skill

Load this skill when working on auto-deployment, Android app, or CI/CD pipeline.

> **Also load `engineering_patterns`** for graceful shutdown, monitoring, health checks, and performance budgets. This skill covers *how to deploy*; `engineering_patterns` covers *how to run reliably*.

## Auto-Deployment Pipeline

```
git push main
  ↓
CI: Build Chemical project
  ↓
CI: Run integration tests
  ↓
CI: Build web platform
  ↓
CI: Build course pages (compile .ch → HTML/CSS/JS)
  ↓
CD: Deploy web to hosting
  ↓
CD: Upload course output to CDN
  ↓
(if app changes)
CI: Build Android APK
  ↓
CD: Upload APK to distribution
```

### Design Principle

**Code must be correct before merge.** There is no "fix it later." The auto-deploy pipeline means every commit goes live.

### Rollback

If any step fails:
1. Previous version stays live
2. Failure is reported (GitHub notification)
3. Fix is committed, pipeline re-runs

## Web Platform Deployment

### Stack

- **Server:** Chemical `server::Server` (single binary, thread pool) — entrypoint `app/main.ch`
- **Database (local):** SQLite3 (imported by `database/chemical.mod` as `"../../sqlite3"`)
- **Database (remote):** Turso HTTP v2 (selected automatically by `underlayer_db::make_client` when `DATABASE_URL` is http(s))
- **Hosting:** Fly.io (or similar — single binary deployment)

### Build & Run Commands (real paths — verified 2026-09-14)

```bash
# Build the platform binary (from project root)
cmake-build-debug/TCCCompiler lang/compiled/underlayer/chemical.mod \
    -o lang/compiled/underlayer/build/underlayer.exe --mode debug_quick --no-cache -bm-modules

# NOTE: when building inside this repo (where the module tree is at the root),
# the equivalent command is just:
cmake-build-debug/TCCCompiler chemical.mod --mode debug_quick --no-cache -bm-modules
# TCCCompiler may emit a.exe into the CWD — check both locations.

# Convenience scripts (scripts/):
./scripts/serve.sh                       # build + run server on :9000 (--no-build, --port N supported)
./scripts/test.sh                        # build tests.exe + run all @test functions
./scripts/underlayer-build-test.sh       # build + start + curl every endpoint + stop (always exits)

# Smoke test after start
curl localhost:9000/api/health           # → {"status": "ok", "version": "0.1.0"}
curl localhost:9000/courses/elf/lessons/bytes
```

### Environment Variables (read by core/src/main.ch::load_config)

| Variable | Purpose | Default |
|----------|---------|---------|
| `PORT` | Server port | `9000` |
| `DATABASE_URL` | SQLite file path or Turso HTTP URL | `./underlayer.db` |
| `DATABASE_TOKEN` | Turso auth token (empty for local) | (empty) |
| `COURSES_DIR` | Course content directory | `./courses` |

Remote (Turso) URLs skip `init_schema()` — schema is provisioned externally.

## Course Page Deployment

Course pages are pre-rendered static files. They can be deployed independently:

### Option 1: Served by Platform Binary

The platform binary serves `courses/*/output/` directories as static files.

### Option 2: CDN

Upload `courses/*/output/` to Tigris S3 or any CDN:

```bash
# Upload course output to CDN
aws s3 sync courses/elf/output/ s3://underlayer-courses/elf/ \
    --endpoint-url https://fly.storage.tigris.dev
```

### Option 3: Standalone

Course output is just HTML/CSS/JS files. They can be:
- Opened directly in a browser (file://)
- Served by any web server
- Hosted on GitHub Pages
- Distributed as a zip file

### Dual-Mode Deployment

**Static Mode (GitHub Pages):**
- Compile courses to HTML/CSS/JS files
- Commit output/ directory to repo
- GitHub Pages serves automatically
- No backend required
- Progress stored in localStorage

**Backend Mode (Full Server — this is what actually runs today):**
- Concept pages are compiled INTO the server binary (`content/src/*.ch` render functions, dispatched by `web/src/helpers.ch::render_concept()`)
- Static assets served from disk via `static.ch` under `/courses/*`
- API endpoints for review, progress, exercises, weaknesses, FSRS
- `courses/elf/src/` mirrors 3 concepts for optional static output; the pre-render step is not wired into CI

**Static output build (when wired):**
```bash
cmake-build-debug/TCCCompiler courses/elf/chemical.mod \
    -o courses/elf/build/elf-pages.exe --mode debug_quick
./courses/elf/build/elf-pages.exe
# → writes courses/elf/output/*.html + *.css + *.js

git add courses/elf/output/
git commit -m "Update ELF course pages"
git push   # GitHub Pages serves automatically
```

## Android App

### Architecture

```
Android UI (Kotlin)
  ↓ JNI
Chemical Runtime (libunderlayer.so)
  ↓
Course Player (reads pre-rendered HTML/CSS/JS in WebView)
  ↓
FSRS Engine
  ↓
Local SQLite
  ↓
File System (downloaded courses)
```

### Build Steps

1. Cross-compile Chemical to Android:
```bash
cmake-build-debug/TCCCompiler lang/compiled/underlayer/chemical.mod \
    -o lang/compiled/underlayer/build/libunderlayer.so --target android -bm-modules
```

2. Build Android APK:
```bash
cd android/
./gradlew assembleRelease
```

3. Sign APK:
```bash
jarsigner -verbose -sigalg SHA256withRSA -digestalg SHA-256 \
    -keystore release-key.jks \
    app/build/outputs/apk/release/app-release-unsigned.apk \
    alias_name
```

### Distribution

- **Primary:** Direct APK download from Underlayer website
- **Secondary:** F-Droid (open source)
- **Not initially:** Google Play Store (requires Play Console account)

### Course Download Flow

1. App requests course list from server
2. User taps "Download" on a course
3. App downloads course zip from CDN (output/ + assets/ + manifest.json)
4. Zip extracted to `courses/<id>/`
5. Manifest loaded
6. Review items generated (if first download)
7. Learner state initialized
8. Course available offline

### Offline-First Design

The app works entirely offline after course download:
- All content is local (pre-rendered HTML/CSS/JS)
- FSRS runs locally
- Learner state stored in local SQLite
- Sync when online (optional)

## CI/CD Configuration

### GitHub Actions

```yaml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  build-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup Chemical
        run: # install Chemical toolchain
      - name: Build Platform
        run: |
          cmake-build-debug/TCCCompiler lang/compiled/underlayer/chemical.mod \
              -o build/underlayer.exe --mode debug_quick --no-cache -bm-modules
      - name: Build Course Pages
        run: |
          cmake-build-debug/TCCCompiler lang/compiled/underlayer/courses/elf/chemical.mod \
              -o courses/elf/build/elf-pages.exe --mode debug_quick --no-cache -bm-modules
          ./courses/elf/build/elf-pages.exe
      - name: Test
        run: |
          ./build/underlayer.exe &
          sleep 2
          curl -f http://localhost:9000/api/health
          kill %1

  deploy-web:
    needs: build-and-test
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to Fly.io
        run: fly deploy

  build-android:
    needs: build-and-test
    runs-on: ubuntu-latest
    if: contains(github.event.head_commit.message, '[app]')
    steps:
      - name: Cross-compile for Android
        run: |
          cmake-build-debug/TCCCompiler lang/compiled/underlayer/chemical.mod \
              -o build/libunderlayer.so --target android -bm-modules
      - name: Build APK
        run: |
          cd android/
          ./gradlew assembleRelease
      - name: Upload APK
        run: |
          # Upload to Tigris S3 for download
```

## Course CDN

### Setup

Course output (HTML/CSS/JS) is hosted on Tigris S3 (or any S3-compatible CDN).

### Upload

```bash
# Upload course output
aws s3 sync courses/elf/output/ s3://underlayer-courses/elf/ \
    --endpoint-url https://fly.storage.tigris.dev
```

### Update Flow

1. Course version bumps (e.g., 1.0 → 1.1)
2. New output uploaded to CDN
3. Old output remains (for version pinning)
4. App detects update on sync
5. Downloads changed content (delta update)
6. Merges with existing local copy

## Monitoring

### Health Check

```bash
curl http://localhost:9000/api/health
# Should return: {"status": "ok"}
```

### Deployment Status

- GitHub Actions: pipeline status in PRs
- Fly.io: deployment logs
- Course CDN: download counts in S3 access logs

### Rollback

If deployment fails:
1. Fly.io: `fly deploy --image <previous-image>`
2. Course CDN: re-upload previous output version
3. Android: previous APK remains downloadable

## Chemical Gaps for Android

| Gap | Description | Workaround |
|---|---|---|
| JNI bridge | Chemical → Android Java interop | Write Android UI in Kotlin, bridge to Chemical via JNI |
| Android UI toolkit | No Chemical Android UI library | Use Kotlin for UI, Chemical for logic; course content is pre-rendered HTML in WebView |
| APK signing | Chemical doesn't handle APK signing | Use standard Android toolchain for signing |
| Delta updates | Download only changed content | Full re-download for now |

Document these gaps as we encounter them.
