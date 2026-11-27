# syntax=docker/dockerfile:1
# ================================================================
# Dockerfile — Build Underlayer using the Chemical toolchain
#
# Context: underlayer repo root (chemical.cloud.mod, app/, core/, ..., courses/)
# Dependencies: cloned from GitHub by the modules' imports. The brand layer is
# private: the two .cloud.mod manifests import github.com/wiqis/brandlib instead
# of the local ../../WebLibs/brandlib path, and are copied over their local
# twins below (same pattern as Web/timeline and Web/123mind). A GitHub token
# with read access to the wiqis org is needed for that clone — see the H8
# BuildKit secret-mount note below. database/chemical.mod also pulls
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

# H8 — the build token is a BuildKit SECRET, not a build ARG.
# Build args are recorded in image metadata and `docker history`, so a token
# passed with --build-arg would be recoverable from a pushed image. A secret
# mount exists only for the duration of this RUN and is never committed. It has
# to be on the COMPILE step: the compiler is what clones the private module.
#
# The token is also never allowed to reach the layer filesystem: git's config is
# written to a temp file, exported via GIT_CONFIG_GLOBAL for THIS shell only, and
# removed in the same RUN before it exits. No ENV records it. Builds of the
# public dependency set work with no secret supplied at all.
#
# Usage:
#   docker build --secret id=github_token,env=GITHUB_TOKEN -t underlayer .
# (or ,src=/path/to/token-file; never --build-arg GITHUB_TOKEN).
RUN --mount=type=secret,id=github_token,target=/run/secrets/github_token \
    mkdir -p /workspace/build && set -eu; \
    cfg=/tmp/underlayer-gitconfig; \
    rm -f "$cfg"; \
    if [ -s /run/secrets/github_token ]; then \
        token="$(cat /run/secrets/github_token)"; \
        printf '[url "https://x-access-token:%s@github.com/"]\n\tinsteadOf = https://github.com/\n' "$token" > "$cfg"; \
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
