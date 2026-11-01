#!/system/bin/sh
# Extract real icon + label for ONE package, using bundled aapt2
# (Apache-2.0, github.com/rendiix/termux-aapt -- only links against
# libc/libm/libdl, runs standalone under a normal root shell).
#
# Deliberately does ONE package per invocation, not a batch loop:
# the WebUI's root-exec bridge blocks the whole WebView for the
# duration of the shell command it runs, so a single call that looped
# over every installed app froze the UI for the entire scan. Calling
# this once per app from JavaScript (awaited, one at a time) keeps
# each call sub-second and lets the WebView stay responsive between
# them, at the cost of a little overhead per call.
#
# Usage: extract_one.sh <pkg>
# Prints one of: CACHED | OK | NO_ICON | NO_APK | NO_BADGING | UNSUPPORTED
DIR=${0%/*}
. "$DIR/common.sh"

pkg="$1"
[ -z "$pkg" ] && exit 0

ABI=$(getprop ro.product.cpu.abi)
case "$ABI" in
  arm64*) AAPT="$MODDIR/bin/arm64-v8a/aapt2" ;;
  armeabi*|arm) AAPT="$MODDIR/bin/armeabi-v7a/aapt2" ;;
  x86_64) AAPT="$MODDIR/bin/x86_64/aapt2" ;;
  x86|i686) AAPT="$MODDIR/bin/x86/aapt2" ;;
  *) AAPT="" ;;
esac
if [ -z "$AAPT" ] || [ ! -x "$AAPT" ]; then
  echo "UNSUPPORTED"
  exit 0
fi

ICONDIR="$MODDIR/webroot/icons"
TSV="$MODDIR/label_entries.tsv"
mkdir -p "$ICONDIR"
[ -f "$TSV" ] || : > "$TSV"

HAVE_LABEL=0
grep -qF "$(printf '%s\t' "$pkg")" "$TSV" && HAVE_LABEL=1
HAVE_ICON=0
[ -f "$ICONDIR/$pkg.png" ] && HAVE_ICON=1

if [ "$HAVE_LABEL" = "1" ] && [ "$HAVE_ICON" = "1" ]; then
  echo "CACHED"
  exit 0
fi

APK=$(pm path "$pkg" 2>/dev/null | head -n1 | sed 's/^package://')
if [ -z "$APK" ]; then
  echo "NO_APK"
  exit 0
fi

BADGING=$("$AAPT" dump badging "$APK" 2>/dev/null)
if [ -z "$BADGING" ]; then
  echo "NO_BADGING"
  exit 0
fi

if [ "$HAVE_LABEL" = "0" ]; then
  LABEL=$(echo "$BADGING" | grep -m1 "^application-label:" | sed "s/^application-label://; s/^'//; s/'\$//")
  [ -z "$LABEL" ] && LABEL="$pkg"
  printf '%s\t%s\n' "$pkg" "$LABEL" >> "$TSV"
fi

RESULT="OK"
if [ "$HAVE_ICON" = "0" ]; then
  ICON_RES=$(echo "$BADGING" | grep "^application-icon-" | sort -t'-' -k3 -rn | \
             awk -F"'" '{print $2}' | grep -Ev '\.xml$' | head -n1)
  if [ -z "$ICON_RES" ]; then
    ICON_RES=$(echo "$BADGING" | grep -m1 "^application:" | grep -o "icon='[^']*'" | \
               sed "s/^icon='//; s/'\$//" | grep -Ev '\.xml$')
  fi
  if [ -n "$ICON_RES" ]; then
    unzip -p "$APK" "$ICON_RES" > "$ICONDIR/$pkg.png" 2>/dev/null
    if [ -s "$ICONDIR/$pkg.png" ]; then
      RESULT="OK"
    else
      rm -f "$ICONDIR/$pkg.png"
      RESULT="NO_ICON"
    fi
  else
    RESULT="NO_ICON"
  fi
fi
echo "$RESULT"
