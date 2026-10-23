#!/bin/bash
# An unversioned provides satisfies no versioned dependency, such as qt6-base>=6.6.0.
set -e
# shellcheck disable=SC2016 # $pkgver is PKGBUILD text that makepkg expands
sed -i 's/^provides=(qt6-base)$/provides=("qt6-base=$pkgver")/' "$1/PKGBUILD"
# shellcheck disable=SC2016 # the same PKGBUILD text
grep -qx 'provides=("qt6-base=$pkgver")' "$1/PKGBUILD"
