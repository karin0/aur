#!/bin/bash
set -eo pipefail

PROFILE=$1
if [[ -z "$PROFILE" ]]; then
  echo "Usage: $0 <profile>" >&2
  exit 1
fi

REPO_DIR="repos/$PROFILE"
REPO_NAME="aur-$PROFILE"

# A. Clean up obsolete local package files (.pkg.tar.zst) not registered in the database
if [[ -f "$REPO_DIR/$REPO_NAME.db.tar.zst" ]]; then
  echo "=== [1/3] Extracting active packages from database ==="
  ACTIVE_PKGS=$(tar --wildcards -xOf "$REPO_DIR/$REPO_NAME.db.tar.zst" '*/desc' | grep -A 1 '%FILENAME%' | grep -v '%FILENAME%' | grep -v '^--$' || true)
  
  echo "=== [2/3] Cleaning up obsolete local package files ==="
  for pkg_file in "$REPO_DIR"/*.pkg.tar.zst; do
    [[ -f "$pkg_file" ]] || continue
    filename=$(basename "$pkg_file")
    if ! echo "$ACTIVE_PKGS" | grep -Fqx "$filename"; then
      echo "Deleting obsolete local package: $filename"
      rm "$pkg_file"
    fi
  done
else
  echo "=== [1/3] No database found in $REPO_DIR. Skipping local package cleanup. ==="
fi

# B. Resolve symlinks: Replace database and files symlinks with actual file copies
echo "=== [2/3] Resolving pacman database symlinks ==="
for ext in db files; do
  if [[ -L "$REPO_DIR/$REPO_NAME.$ext" ]]; then
    echo "Converting symlink $REPO_NAME.$ext to actual file..."
    TARGET=$(readlink "$REPO_DIR/$REPO_NAME.$ext")
    rm "$REPO_DIR/$REPO_NAME.$ext"
    cp "$REPO_DIR/$TARGET" "$REPO_DIR/$REPO_NAME.$ext"
  fi
done

# C. Clean up obsolete release assets on GitHub that are no longer in repos/
echo "=== [3/3] Syncing GitHub Release assets with local repository ==="
if ASSETS=$(gh release view "$PROFILE" --json assets --jq '.assets[].name' --repo "$GITHUB_REPOSITORY" 2>/dev/null); then
  echo "$ASSETS" | while read -r asset; do
    [[ -n "$asset" ]] || continue
    if [[ ! -f "$REPO_DIR/$asset" ]]; then
      echo "Deleting obsolete Release asset: $asset"
      gh release delete-asset "$PROFILE" "$asset" -y --repo "$GITHUB_REPOSITORY" || true
    fi
  done
else
  echo "Release '$PROFILE' does not exist yet. Skipping asset sync."
fi
