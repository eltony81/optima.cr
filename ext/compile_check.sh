#!/bin/sh

# ext/compile_check.sh
# Diagnostic script run post-install to check if highs solver libraries are available

echo "Optima.cr: Running post-install FFI linker diagnostics..."

if pkg-config --exists highs 2>/dev/null || [ -f "/usr/lib/libhighs.so" ] || [ -f "/usr/local/lib/libhighs.so" ] || [ -f "/usr/lib/libhighs.dylib" ] || [ -f "/usr/local/lib/libhighs.dylib" ]; then
  echo "Optima.cr: HiGHS development library detected. Build linking will succeed."
else
  echo ""
  echo "========================================================================="
  echo "WARNING: Optima.cr could not detect a system-installed 'highs' C library."
  echo "To resolve this dependency, please run:"
  echo ""
  echo "  On Arch Linux/Manjaro:  sudo pacman -S highs"
  echo "  On macOS (Homebrew):    brew install highs"
  echo "  On Ubuntu/Debian:       sudo apt-get install libhighs-dev (or compile from source)"
  echo "========================================================================="
  echo ""
fi
exit 0
