#!/usr/bin/env bash
set -euo pipefail

REPO="wprhvso/unsafie-cloud"
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$ARCH" in
    x86_64) ARCH="x86_64" ;;
    aarch64|arm64) ARCH="aarch64" ;;
    *) echo "Unsupported architecture: $ARCH" && exit 1 ;;
esac

LATEST_RELEASE=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null || true)
if [ -n "$LATEST_RELEASE" ]; then
    LATEST_URL=$(echo "$LATEST_RELEASE" | grep -o "https://[^\"]*unsafie-${OS}-${ARCH}[^\"]*" | head -n 1)
else
    LATEST_URL="https://github.com/${REPO}/releases/latest/download/unsafie-${OS}-${ARCH}.tar.gz"
fi

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Downloading Unsafie Cloud from ${LATEST_URL}..."
if curl -fsSL "$LATEST_URL" -o "${TMP_DIR}/unsafie.tar.gz" 2>/dev/null; then
    tar -xzf "${TMP_DIR}/unsafie.tar.gz" -C "$TMP_DIR"
    BIN_PATH="${TMP_DIR}/unsafie-cloud"
else
    FALLBACK_URL="https://github.com/${REPO}/releases/latest/download/unsafie-${OS}-${ARCH}"
    curl -fsSL "$FALLBACK_URL" -o "${TMP_DIR}/unsafie"
    BIN_PATH="${TMP_DIR}/unsafie-cloud"
fi

chmod +x "$BIN_PATH"
if [ -w "/usr/local/bin" ]; then
    mv "$BIN_PATH" /usr/local/bin/unsafie-cloud
else
    sudo mv "$BIN_PATH" /usr/local/bin/unsafie-cloud
fi

echo "Unsafie Cloud successfully installed to /usr/local/bin/unsafie-cloud"
