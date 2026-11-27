# ================================================================
# Dockerfile — Build Underlayer using the Chemical toolchain
#
# Context: underlayer repo root (chemical.cloud.mod, app/, core/, ..., courses/)
# Dependencies: cloned from GitHub by the modules' imports. The brand layer is
# private: the two .cloud.mod manifests import github.com/wiqis/brandlib instead
# of the local ../../WebLibs/brandlib path, and are copied over their local
# twins below (same pattern as Web/timeline and Web/123mind). GITHUB_TOKEN must
# have read access to the wiqis org. database/chemical.mod also pulls
# chemicallang/sqlite3, compiled from C source — no shared libraries to ship.
# ================================================================

FROM chemicallang/chemical:v0.6.2-tcc-ubuntu AS builder

RUN apt-get update && apt-get install -y git ca-certificates && rm -rf /var/lib/apt/lists/*

ARG GITHUB_TOKEN=
RUN set -eux; \
    if [ -n "${GITHUB_TOKEN:-}" ]; then \
        git config --global url."https://x-access-token:${GITHUB_TOKEN:-}@github.com/".insteadOf "https://github.com/"; \
    fi

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

RUN mkdir -p /workspace/build && \
    chemical chemical.mod -o /workspace/build/underlayer.exe --mode release --no-cache

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
