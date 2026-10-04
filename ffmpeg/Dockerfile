# Cross-compiles a minimal LGPL FFmpeg for Windows x64.
FROM ubuntu:24.04@sha256:a853f94d226358a79c740cfc7bce0c289748f3fe3488d921d038ccd752c61b60
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl xz-utils bzip2 zip make cmake ninja-build meson nasm pkg-config \
        autoconf automake libtool \
        gcc-mingw-w64-x86-64-posix g++-mingw-w64-x86-64-posix binutils-mingw-w64-x86-64 mingw-w64-tools \
    && rm -rf /var/lib/apt/lists/*
COPY Dockerfile build.sh sources.lock /recipe/
ENTRYPOINT ["bash", "/recipe/build.sh"]
