# Godot Android export toolchain
# All versions parameterized — update ARGs to upgrade.

ARG GODOT_VERSION=4.6.1-stable
ARG ANDROID_BUILD_TOOLS=35.0.1
ARG ANDROID_PLATFORM=android-35
ARG ANDROID_NDK=25.2.9519653
ARG ANDROID_CMAKE=3.22.1

FROM ubuntu:24.04

# Re-declare ARGs after FROM so they're available in the build stage
ARG GODOT_VERSION
ARG ANDROID_BUILD_TOOLS
ARG ANDROID_PLATFORM
ARG ANDROID_NDK
ARG ANDROID_CMAKE

ENV DEBIAN_FRONTEND=noninteractive \
    ANDROID_HOME=/opt/android-sdk \
    JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

# System packages: JDK, build tools for C helper, utilities
RUN apt-get update && apt-get install -y --no-install-recommends \
        openjdk-17-jdk-headless \
        gcc make libc6-dev sudo fontconfig \
        wget unzip ca-certificates git \
    && rm -rf /var/lib/apt/lists/*

# ── Android SDK ──────────────────────────────────────────────────────
RUN mkdir -p "${ANDROID_HOME}/cmdline-tools" \
    && wget -q "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip" \
       -O /tmp/cmdline-tools.zip \
    && unzip -q /tmp/cmdline-tools.zip -d "${ANDROID_HOME}/cmdline-tools" \
    && mv "${ANDROID_HOME}/cmdline-tools/cmdline-tools" "${ANDROID_HOME}/cmdline-tools/latest" \
    && rm /tmp/cmdline-tools.zip

ENV PATH="${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${PATH}"

RUN yes | sdkmanager --licenses > /dev/null 2>&1 \
    && sdkmanager \
        "platform-tools" \
        "build-tools;${ANDROID_BUILD_TOOLS}" \
        "platforms;${ANDROID_PLATFORM}" \
        "ndk;${ANDROID_NDK}" \
        "cmake;${ANDROID_CMAKE}"

ENV ANDROID_NDK_ROOT="${ANDROID_HOME}/ndk/${ANDROID_NDK}"

# ── Debug keystore ───────────────────────────────────────────────────
RUN keytool -genkeypair \
        -alias androiddebugkey \
        -keypass android \
        -keystore /opt/debug.keystore \
        -storepass android \
        -dname "CN=Android Debug,O=Android,C=US" \
        -keyalg RSA -keysize 2048 -validity 10000

# ── Godot editor (headless-capable) ─────────────────────────────────
# Strip the "-stable" suffix for the download URL
RUN GODOT_VER_NUM="${GODOT_VERSION%-stable}" \
    && wget -q "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip" \
       -O /tmp/godot.zip \
    && unzip -q /tmp/godot.zip -d /tmp/godot \
    && mv /tmp/godot/Godot_v${GODOT_VERSION}_linux.x86_64 /usr/local/bin/godot \
    && chmod +x /usr/local/bin/godot \
    && rm -rf /tmp/godot.zip /tmp/godot

# ── Non-root user ───────────────────────────────────────────────────
# Ubuntu 24.04 ships a default "ubuntu" user at UID/GID 1000.
# Rename it if it exists; otherwise create from scratch.
RUN if getent group 1000 > /dev/null; then \
        groupmod -n vscode "$(getent group 1000 | cut -d: -f1)"; \
    else \
        groupadd -g 1000 vscode; \
    fi \
    && if id -u 1000 > /dev/null 2>&1; then \
        usermod -l vscode -d /home/vscode -m -s /bin/bash "$(id -nu 1000)"; \
    else \
        useradd -m -u 1000 -g 1000 -s /bin/bash vscode; \
    fi \
    && echo "vscode ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/vscode

# Pre-create Godot directory tree so Docker volume mounts don't leave
# root-owned parents that block sibling creation (e.g. app_userdata).
RUN mkdir -p /home/vscode/.local/share/godot/export_templates \
             /home/vscode/.local/share/godot/app_userdata \
             /home/vscode/.cache/godot \
             /home/vscode/.config/godot \
             /home/vscode/.gradle \
    && chown -R vscode:vscode /home/vscode/.local /home/vscode/.cache /home/vscode/.config /home/vscode/.gradle

USER vscode
WORKDIR /workspace
