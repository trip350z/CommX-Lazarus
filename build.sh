#!/bin/sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
case "$(uname -s)" in
  Linux) widgetset=${1:-gtk2}; project=demo/CommXDemo.lpi ;;
  Darwin) widgetset=${1:-cocoa}; project=demo/CommXDemoMac.lpi ;;
  *) echo "Use Lazarus on Windows, or this script on Linux/macOS." >&2; exit 2 ;;
esac
case "$widgetset" in
  gtk2|qt5|qt6|cocoa) ;;
  *) echo "Usage: sh build.sh [gtk2|qt5|qt6|cocoa]" >&2; exit 2 ;;
esac
lazbuild --build-all --widgetset="$widgetset" commxlcl.lpk
lazbuild --build-all --widgetset="$widgetset" "$project"
lazbuild --build-all --widgetset="$widgetset" tests/CommXSmoke.lpi
