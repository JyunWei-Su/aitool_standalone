#!/bin/bash
set -euo pipefail

NODEJS_VERSION="${NODEJS_VERSION:-$(curl -sL https://nodejs.org/dist/index.json | jq -r '[.[] | select(.lts != false)] | first | .version' | tr -d 'v')}"
QMD_VERSION="${QMD_VERSION:-latest}"

echo "========================================"
echo " qmd Standalone Builder"
echo " Node.js: ${NODEJS_VERSION}"
echo " qmd:     ${QMD_VERSION}"
echo "========================================"

export PATH="$PWD/build/.node/bin:/usr/bin"
mkdir -p tmp

NODEJS_URL="https://nodejs.org/dist/v${NODEJS_VERSION}/node-v${NODEJS_VERSION}-linux-x64.tar.xz"
NODEJS_ARCHIVE="tmp/node-v${NODEJS_VERSION}-linux-x64.tar.xz"
if [ ! -f "$NODEJS_ARCHIVE" ]; then
  echo "Downloading Node.js from ${NODEJS_URL}..."
  wget -qO "$NODEJS_ARCHIVE" "$NODEJS_URL"
fi

echo "Extracting Node.js..."
rm -rf build
mkdir -p build/.node
tar xf "$NODEJS_ARCHIVE" -C build/.node --strip-components 1

pushd build

PKG_SPEC="@tobilu/qmd"
if [ "$QMD_VERSION" != "latest" ] && [ -n "$QMD_VERSION" ]; then
  PKG_SPEC="@tobilu/qmd@${QMD_VERSION}"
fi
echo "Installing ${PKG_SPEC}..."
# Force native modules (better-sqlite3) to compile from source against the
# local glibc 2.28, instead of fetching a prebuilt binary that needs 2.29.
export npm_config_build_from_source=true
export PYTHON=/usr/bin/python3
./.node/bin/npm install "$PKG_SPEC"

cat > qmd << 'WRAPPER'
#!/bin/bash
set -eu
SCRIPT_PATH="$(cd -- "$(dirname "$0")" >/dev/null 2>&1; pwd -P)"
export PATH="$SCRIPT_PATH/.node/bin:$PATH"
exec "$SCRIPT_PATH/node_modules/.bin/qmd" "$@"
WRAPPER
chmod +x qmd

popd

VERSION_TAG=$( build/.node/bin/node \
  -e "console.log(require('./build/node_modules/@tobilu/qmd/package.json').version)" )

echo "Bundling qmd-standalone-${VERSION_TAG}..."
rm -rf dist && mkdir dist
pushd build
tar czf "../dist/qmd-standalone-${VERSION_TAG}-x86_64-linux.tar.gz" .
popd
sha256sum dist/*.tar.gz > dist/SHA256SUMS
printf 'name=qmd\nversion=%s\n' "${VERSION_TAG}" > dist/BUILD_INFO.txt

echo "=== Done ==="
ls -lh dist/
cat dist/SHA256SUMS
