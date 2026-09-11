# Deployment Skill

Load this skill when working on auto-deployment, Android app, or CI/CD pipeline.

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
CD: Deploy web to hosting
  ↓
(if app changes)
CI: Build Android APK
  ↓
CD: Upload APK to distribution
  ↓
(if courses change)
CD: Update course CDN
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

- **Server:** Chemical `http::server::Server` (single binary)
- **Database:** SQLite via Turso HTTP v2
- **Hosting:** Fly.io (or similar — single binary deployment)

### Deploy Steps

1. Build the Chemical binary:
```bash
cmake-build-debug/TCCCompiler lang/compiled/underlayer/chemical.mod \
    -o build/underlayer.exe --mode debug_quick --no-cache -bm-modules
```

2. Package for deployment:
```bash
tar -czf underlayer.tar.gz build/underlayer.exe courses/
```

3. Deploy to Fly.io:
```bash
fly deploy
```

### Environment Variables

| Variable | Purpose |
|---|---|
| `UNDERLAYER_PORT` | Server port (default: 9000) |
| `DATABASE_URL` | Turso HTTP URL |
| `DATABASE_TOKEN` | Turso auth token |
| `STORAGE_BUCKET` | Tigris S3 bucket |
| `STORAGE_ENDPOINT` | Tigris S3 endpoint |
| `STORAGE_KEY` | Tigris access key |
| `STORAGE_SECRET` | Tigris secret key |
| `COURSE_CDN_URL` | CDN URL for course downloads |

## Android App

### Architecture

```
Android UI (Kotlin)
  ↓ JNI
Chemical Runtime (libunderlayer.so)
  ↓
Course Player
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
    -o build/libunderlayer.so --target android -bm-modules
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
3. App downloads course zip from CDN
4. Zip extracted to `courses/<id>/`
5. Manifest loaded
6. Review items generated (if first download)
7. Learner state initialized
8. Course available offline

### Offline-First Design

The app works entirely offline after course download:
- All content is local
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
      - name: Build
        run: |
          cmake-build-debug/TCCCompiler lang/compiled/underlayer/chemical.mod \
              -o build/underlayer.exe --mode debug_quick --no-cache -bm-modules
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

Course zips are hosted on Tigris S3 (or any S3-compatible CDN).

### Upload

```bash
# Upload course zip
aws s3 cp courses/elf-v1.zip s3://underlayer-courses/elf-v1.zip \
    --endpoint-url https://fly.storage.tigris.dev
```

### Update Flow

1. Course version bumps (e.g., 1.0 → 1.1)
2. New zip uploaded to CDN
3. Old zip remains (for version pinning)
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
2. Course CDN: re-upload previous zip version
3. Android: previous APK remains downloadable

## Chemical Gaps for Android

| Gap | Description | Workaround |
|---|---|---|
| JNI bridge | Chemical → Android Java interop | Write Android UI in Kotlin, bridge to Chemical via JNI |
| Android UI toolkit | No Chemical Android UI library | Use Kotlin for UI, Chemical for logic |
| APK signing | Chemical doesn't handle APK signing | Use standard Android toolchain for signing |
| Delta updates | Download only changed content | Full re-download for now |

Document these gaps as we encounter them.
