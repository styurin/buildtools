#!/usr/bin/env bash

set -e

if [ -z "$GITHUB_ACCESS_TOKEN" ]
then
    echo "Create a Github auth token at https://github.com/settings/tokens and set it as \$GITHUB_ACCESS_TOKEN"
    exit 1
fi

TAG="$(git describe --abbrev=0 --tags | sed 's/* //')"  # v1.2.3
VERSION=$(echo $TAG | sed 's/v//')  # 1.2.3
DATE="$(date +"%Y-%m-%d")"
NAME="Release $VERSION ($DATE)"

GH_REPO="repos/bazelbuild/buildtools"
GH_AUTH_HEADER="Authorization: token $GITHUB_ACCESS_TOKEN"

BIN_DIR=`mktemp -d -p "$DIR"`

bazel clean
bazel build --config=release //buildifier:all //buildozer:all //unused_deps:all

for tool in "buildifier" "buildozer" "unused_deps"; do
  cp bazel-bin/"$tool/$tool-linux_amd64" $BIN_DIR
  cp bazel-bin/"$tool/$tool-linux_arm64" $BIN_DIR
  cp bazel-bin/"$tool/$tool-linux_riscv64" $BIN_DIR
  cp bazel-bin/"$tool/$tool-linux_s390x" $BIN_DIR
  cp bazel-bin/"$tool/$tool-darwin_amd64" $BIN_DIR
  cp bazel-bin/"$tool/$tool-darwin_arm64" $BIN_DIR
  cp bazel-bin/"$tool/$tool-windows_amd64.exe" $BIN_DIR
  cp bazel-bin/"$tool/$tool-windows_arm64.exe" $BIN_DIR
done;

echo "Creating a draft release"
API_JSON="{\"tag_name\": \"$TAG\", \"target_commitish\": \"main\", \"name\": \"$NAME\", \"draft\": true}"
RESPONSE=$(curl -s --show-error -H "$GH_AUTH_HEADER" --data "$API_JSON" "https://api.github.com/$GH_REPO/releases")
RELEASE_ID=$(echo $RESPONSE | jq -r '.id')
RELEASE_URL=$(echo $RESPONSE | jq -r '.html_url')

upload_file() {
    echo "Uploading $2"
    ASSET="https://uploads.github.com/$GH_REPO/releases/$RELEASE_ID/assets?name=$2"
    curl --data-binary @"$1" -s --show-error -o /dev/null -H "$GH_AUTH_HEADER" -H "Content-Type: application/octet-stream" $ASSET
}

for tool in "buildifier" "buildozer" "unused_deps"; do
  upload_file "$BIN_DIR/$tool-linux_amd64" "$tool-linux-amd64"
  upload_file "$BIN_DIR/$tool-linux_arm64" "$tool-linux-arm64"
  upload_file "$BIN_DIR/$tool-linux_riscv64" "$tool-linux-riscv64"
  upload_file "$BIN_DIR/$tool-linux_s390x" "$tool-linux-s390x"
  upload_file "$BIN_DIR/$tool-darwin_amd64" "$tool-darwin-amd64"
  upload_file "$BIN_DIR/$tool-darwin_arm64" "$tool-darwin-arm64"
  upload_file "$BIN_DIR/$tool-windows_amd64.exe" "$tool-windows-amd64.exe"
  upload_file "$BIN_DIR/$tool-windows_arm64.exe" "$tool-windows-arm64.exe"
done

rm -rf $BIN_DIR

echo "The draft release is available at $RELEASE_URL"
