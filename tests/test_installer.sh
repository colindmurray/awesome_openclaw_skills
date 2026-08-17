#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TARGET_DIR"
}
trap cleanup EXIT HUP INT TERM

list_output="$("$REPO_DIR/install.sh" --list)"
grep -q 'tweetclaw' <<< "$list_output"

if PATH="/usr/bin:/bin" "$REPO_DIR/install.sh" --all --dry-run "$TARGET_DIR" >"$TARGET_DIR/output.log" 2>&1; then
  echo "Expected missing dependencies to return a failure status"
  exit 1
fi

grep -q 'Installation finished with missing dependencies.' "$TARGET_DIR/output.log"
test ! -d "$TARGET_DIR/skills"

echo "Installer tests passed"
