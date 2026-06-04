#!/bin/bash
# Modifies 64gram-desktop's PKGBUILD to apply compile options for build-time tools,
# allowing compilation on different host CPUs.

set -eo pipefail

pkg_dir=$1
if [[ -z "$pkg_dir" || ! -d "$pkg_dir" ]]; then
  echo "Usage: $0 <package_dir>" >&2
  exit 1
fi

pkg_dir=$(realpath "$pkg_dir")
PKGBUILD_PATH="$pkg_dir/PKGBUILD"

if [[ ! -f "$PKGBUILD_PATH" ]]; then
  echo "Error: PKGBUILD not found in $pkg_dir" >&2
  exit 1
fi

patches_dir=$(dirname "$(realpath "$0")")
script='64gram-desktop-inject-host-flags.py'

echo "[64gram-desktop patch] Copying injection script to clone directory..."
cp "$patches_dir/$script" "$pkg_dir/$script"

echo "[64gram-desktop patch] Patching PKGBUILD to inject compile option modifiers..."

# 1. Inject the script into the beginning of the source array
sed -i '/source=(/a \        "'"$script"'"' "$PKGBUILD_PATH"

# 2. Inject 'SKIP' into the beginning of the sha512sums array to match the source order
sed -i "/sha512sums=(/a \            'SKIP'" "$PKGBUILD_PATH"

# 3. Inject the python execution command into the prepare() function
cat << 'EOF' > "$pkg_dir/patch_injection.tmp"

    # Inject compile options dynamically for host tools
    echo "=== [64gram-desktop patch] Injecting host tools compilation option overrides ==="
    python3 "$srcdir/64gram-desktop-inject-host-flags.py" \
        "$srcdir/td/td/generate/CMakeLists.txt" \
        "$srcdir/td/td/generate/tl-parser/CMakeLists.txt" \
        "$srcdir/td/tdtl/CMakeLists.txt" \
        "$srcdir/td/tdutils/generate/CMakeLists.txt" \
        "$srcdir/$_pkgname-$pkgver-full/cmake/external/glib/cppgir/CMakeLists.txt" \
        "$srcdir/$_pkgname-$pkgver-full/Telegram/lib_base/CMakeLists.txt" \
        "$srcdir/$_pkgname-$pkgver-full/Telegram/codegen/codegen/"*/CMakeLists.txt
    sed -i 's/endfunction()/    message(STATUS "--- [DEBUG PATCH] Injecting options for target ${target_name}_${namespace}_dbus ---")\n    target_compile_options(${target_name}_${namespace}_dbus PRIVATE "-march=x86-64" "-O2")\nendfunction()/' cmake/external/glib/generate_dbus.cmake
EOF

sed -i '/patch -Np1 -d Telegram\/lib_base/r '"$pkg_dir/patch_injection.tmp" "$PKGBUILD_PATH"
rm -f "$pkg_dir/patch_injection.tmp"

# 4. Make dos2unix quiet
sed -i 's/exec dos2unix/exec dos2unix -q/' "$PKGBUILD_PATH"

echo "[64gram-desktop patch] PKGBUILD patched successfully."
