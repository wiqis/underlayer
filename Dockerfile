# ================================================================
# Dockerfile — Build Underlayer using the Chemical toolchain
#
# Context: underlayer repo root (chemical.cloud.mod, app/, core/, ..., courses/)
# Dependencies: cloned from GitHub by the modules' imports. The brand layer is
# private: the two .cloud.mod manifests import github.com/wiqis/brandlib instead
# of the local ../../WebLibs/brandlib path, and are copied over their local
# twins below (same pattern as Web/timeline and Web/123mind). A GitHub token
# with read access to the wiqis org is needed for that clone — see the H8
# build-token note below. database/chemical.mod also pulls
# chemicallang/sqlite3, compiled from C source — no shared libraries to ship.
# ================================================================

FROM chemicallang/chemical:v0.6.2-tcc-ubuntu AS builder

RUN apt-get update && apt-get install -y git ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# Build inputs: the root module file plus every source tree it compiles.
# content/ is compiled in (lesson HTML is generated code, not read at runtime).
# Cloud manifests replace the local ones: brandlib comes from GitHub here.
COPY chemical.cloud.mod ./chemical.mod
COPY app/ ./app/
COPY core/ ./core/
COPY database/ ./database/
COPY learning/ ./learning/
COPY models/ ./models/
COPY repository/ ./repository/
COPY web/ ./web/
# web/ has its own brandlib import — overwrite it with the GitHub-URL manifest.
COPY web/chemical.cloud.mod ./web/chemical.mod
COPY content/ ./content/

# Surfaces the compiler version in the build log — this project is sensitive to it.
RUN chemical --version

# H8 — build token handling, LEGACY-BUILDER COMPATIBLE.
#
# Google Cloud Build's default Docker builder does not enable BuildKit, so
# `RUN --mount=type=secret` fails there with "--mount requires BuildKit". This
# file deliberately uses no BuildKit-only syntax: `docker build` and
# `gcloud builds submit` both work with the same Dockerfile.
#
# The token arrives as a build ARG on this BUILDER stage only. This is safe for
# the pushed image because the runtime stage below is a fresh `FROM ubuntu:24.04`
# that copies only the compiled binary and courses: builder-stage ARGs and RUN
# commands are NOT part of the final image's `docker history`. The git config
# that carries the token is written to a temp file, exported via
# GIT_CONFIG_GLOBAL for THIS shell only, and deleted in the same RUN, so it does
# not even survive in the builder layer. No ENV records the token.
#
# Usage: docker build --build-arg GITHUB_TOKEN="$GITHUB_TOKEN" -t underlayer .
# In Cloud Build, pass it as a masked substitution and never print it.
# Builds that need only public modules work with no token supplied at all.
ARG GITHUB_TOKEN=
RUN mkdir -p /workspace/build && set -eu; \
    cfg=/tmp/underlayer-gitconfig; \
    rm -f "$cfg"; \
    if [ -n "${GITHUB_TOKEN:-}" ]; then \
        printf '[url "https://x-access-token:%s@github.com/"]\n\tinsteadOf = https://github.com/\n' "$GITHUB_TOKEN" > "$cfg"; \
        export GIT_CONFIG_GLOBAL="$cfg"; \
    fi; \
    export GIT_TERMINAL_PROMPT=0; \
    chemical chemical.mod -o /workspace/build/underlayer.exe --mode release --no-cache; \
    rm -f "$cfg"

# ── Runtime ─────────────────────────────────────────────────
FROM ubuntu:24.04

RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /workspace/build/underlayer.exe ./

# Courses are discovered at startup by scanning COURSES_DIR for
# <course>/manifest.json, so the manifests have to be on disk.
COPY courses/ ./courses/

# Learner state is SQLite. The container filesystem is ephemeral: mount a
# DURABLE volume at /data (a Cloud Run volume mount, not an in-container mkdir).
# Remote libsql/Turso URLs are FATAL-refused at startup by this build; do not
# point DATABASE_URL at one.
RUN mkdir -p /data

# H5 build provenance (no secrets). Supply these at build time:
#   docker build --build-arg UL_BUILD_COMMIT=<sha> \
#     --build-arg UL_BUILD_COMPILER_VERSION="$(chemical --version)" \
#     --build-arg UL_BUILD_AT=<ISO-8601-UTC> \
#     --build-arg UL_BUILD_MODE=release ...
# A release-mode image with any identifying value missing exits FATAL before
# serving (core/src/build_info.ch). debug is the local-build default.
ARG UL_BUILD_COMMIT=unknown
ARG UL_BUILD_COMPILER_VERSION=unknown
ARG UL_BUILD_AT=unknown
ARG UL_BUILD_MODE=debug
ENV PORT=8080 \
    COURSES_DIR=./courses \
    DATABASE_URL=/data/underlayer.db \
    UL_BUILD_COMMIT=${UL_BUILD_COMMIT} \
    UL_BUILD_COMPILER_VERSION=${UL_BUILD_COMPILER_VERSION} \
    UL_BUILD_AT=${UL_BUILD_AT} \
    UL_BUILD_MODE=${UL_BUILD_MODE}

EXPOSE 8080
CMD ["./underlayer.exe"]
