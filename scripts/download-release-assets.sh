#!/bin/bash
set -eo pipefail

PROFILE=$1
if [[ -z "$PROFILE" ]]; then
  echo "Usage: $0 <profile>" >&2
  exit 1
fi

REPO_DIR="repos/$PROFILE"
REPO_NAME="aur-$PROFILE"
mkdir -p "$REPO_DIR"

echo "=== [1/2] Downloading Pacman database for profile '$PROFILE' ==="
gh release download "$PROFILE" \
  --dir "$REPO_DIR" \
  --pattern "$REPO_NAME.db*" \
  --pattern "$REPO_NAME.files*" \
  --repo "$GITHUB_REPOSITORY" || true

if [[ -f "$REPO_DIR/$REPO_NAME.db.tar.zst" ]]; then
  echo "=== [2/2] Extracting and downloading active packages only ==="
  ACTIVE_PKGS=$(tar --wildcards -xOf "$REPO_DIR/$REPO_NAME.db.tar.zst" '*/desc' | grep -A 1 '%FILENAME%' | grep -v '%FILENAME%' | grep -v '^--$' || true)
  
  echo "$ACTIVE_PKGS" | while read -r filename; do
    [[ -n "$filename" ]] || continue
    echo "Downloading active package: $filename"
    gh release download "$PROFILE" \
      --dir "$REPO_DIR" \
      --pattern "$filename" \
      --repo "$GITHUB_REPOSITORY" || true
  done
else
  echo "=== [2/2] No existing database found. Skipping package pre-download. ==="
fi
