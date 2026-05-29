#!/bin/bash
set -euo pipefail

NAME="$1"
REPO="$2"
TYPE="$3"
VERSION="${4:-latest}"

if [ "$VERSION" = "latest" ]; then
  VERSION=$(curl -sL "https://api.github.com/repos/${REPO}/releases/latest" | jq -r .tag_name)
  if [ "$VERSION" = "null" ] || [ -z "$VERSION" ]; then
    echo "ERROR: Could not resolve latest version for ${REPO}"
    exit 1
  fi
fi

echo "========================================"
echo " Building: ${NAME} ${VERSION}"
echo "========================================"

if [ "$TYPE" = "binary" ]; then
  ASSET_PATTERN="${ASSET_PATTERN:-}"
  if [ -z "$ASSET_PATTERN" ]; then
    echo "ERROR: ASSET_PATTERN is required for binary type"
    exit 1
  fi
  ASSET_PATTERN="${ASSET_PATTERN//\{VERSION\}/${VERSION}}"
  wget -q "https://github.com/${REPO}/releases/download/${VERSION}/${ASSET_PATTERN}" \
       -O "${NAME}-${VERSION}-x86_64-linux.tar.gz"
  printf 'name=%s\nversion=%s\n' "${NAME}" "${VERSION}" > BUILD_INFO.txt
  echo "=== Done: ${NAME}-${VERSION}-x86_64-linux.tar.gz ==="
  exit 0
fi

ARCHIVE_URL="https://github.com/${REPO}/archive/refs/tags/${VERSION}.tar.gz"
wget -qO source.tar.gz "$ARCHIVE_URL"
tar xzf source.tar.gz
REPO_NAME=$(basename "$REPO")
SRC_DIR=$(find . -maxdepth 1 -type d -name "${REPO_NAME}*" | head -1)
if [ -z "$SRC_DIR" ] || [ "$SRC_DIR" = "." ]; then
  SRC_DIR=$(find . -maxdepth 1 -type d ! -name "." | head -1)
fi
mv "$SRC_DIR" "$NAME" 2>/dev/null || true
cd "$NAME"

case "$TYPE" in
  node)
    npm install --production 2>/dev/null || npm install
    npm run build 2>/dev/null || echo "No build script, skipping."
    ;;
  python)
    pip install . --target=./dist 2>/dev/null || \
    pip install -r requirements.txt --target=./dist 2>/dev/null || \
    echo "WARNING: pip install had issues."
    ;;
  go)
    BUILD_CMD="${BUILD_CMD:-go build -o ${NAME} .}"
    eval "$BUILD_CMD"
    ;;
  rust)
    BUILD_CMD="${BUILD_CMD:-cargo build --release}"
    eval "$BUILD_CMD"
    ;;
  *)
    echo "ERROR: Unknown type '${TYPE}'"
    exit 1
    ;;
esac

cd ..
OUTPUT="${NAME}-${VERSION}-x86_64-linux.tar.gz"
tar czf "$OUTPUT" "$NAME"/
printf 'name=%s\nversion=%s\n' "${NAME}" "${VERSION}" > BUILD_INFO.txt
echo "=== Done: ${OUTPUT} ==="
