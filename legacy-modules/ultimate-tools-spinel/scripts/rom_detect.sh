#!/system/bin/sh
# Reads a `getprop` dump ("[key]: [value]") on stdin and prints ROM=<name> / ANDROID=.. / BASE=..
P=$(cat)
g() { echo "$P" | sed -n "s/^\[$1\]: \[\(.*\)\]$/\1/p" | head -n 1; }
ROM=""; VER=""
set_rom() { [ -z "$ROM" ] && [ -n "$2" ] && { ROM="$1"; VER="$2"; }; }
v=$(g ro.mi.os.version.name);        [ -n "$v" ] && set_rom "Xiaomi HyperOS" "$(g ro.mi.os.version.incremental)"
v=$(g ro.miui.ui.version.name);      [ -n "$v" ] && { [ "$(g ro.miui.ui.version.code)" -ge 816 ] 2>/dev/null && :; set_rom "Xiaomi MIUI" "$v $(g ro.build.version.incremental)"; }
set_rom "LineageOS"        "$(g ro.lineage.version)"
set_rom "crDroid"          "$(g ro.crdroid.version)"
set_rom "PixelExperience"  "$(g ro.pixelexperience.version)"
set_rom "Evolution X"      "$(g ro.evolution.version)"
set_rom "Paranoid Android" "$(g ro.pa.version)"
set_rom "ArrowOS"          "$(g ro.arrow.version)"
set_rom "Havoc-OS"         "$(g ro.havoc.version)"
set_rom "DerpFest"         "$(g ro.derp.version)"
set_rom "AOSPA"            "$(g ro.aospa.version)"
set_rom "Project Elixir"   "$(g ro.elixir.version)"
set_rom "RisingOS"         "$(g ro.rising.version)"
set_rom "iodéOS"           "$(g ro.iode.version)"
set_rom "GrapheneOS"       "$(g ro.grapheneos.version)"
set_rom "CalyxOS"          "$(g ro.calyxos.version)"
set_rom "/e/OS"            "$(g ro.build.version.eelo)"
set_rom "Samsung One UI"   "$(g ro.build.version.oneui)"
[ -z "$ROM" ] && [ -n "$(g ro.build.version.sem)" ] && set_rom "Samsung One UI" "$(g ro.build.version.sem)"
set_rom "OxygenOS / ColorOS" "$(g ro.build.version.oplusrom)"
set_rom "ColorOS"          "$(g ro.build.version.opporom)"
set_rom "realme UI"        "$(g ro.build.version.realmeui)"
set_rom "Funtouch/OriginOS" "$(g ro.vivo.os.version)"
set_rom "MagicOS/EMUI"     "$(g ro.build.version.emui)"
set_rom "MagicOS"          "$(g ro.build.version.magic)"
if [ -z "$ROM" ]; then
  CUSTOM=$(g ro.build.flavor); DISP=$(g ro.build.display.id)
  case "$(g ro.product.system.name) $CUSTOM $DISP" in
    *treble*|*gsi*|*aosp*|*phh*) ROM="AOSP / GSI (Treble)"; VER="$DISP" ;;
    *) ROM="Stock / AOSP-based"; VER="$DISP" ;;
  esac
fi
echo "ROM=$ROM"
echo "ROMVER=$VER"
echo "ANDROID=$(g ro.build.version.release)"
echo "SDK=$(g ro.build.version.sdk)"
echo "PATCH=$(g ro.build.version.security_patch)"
echo "BUILD=$(g ro.build.display.id)"
echo "FP=$(g ro.build.fingerprint)"
echo "GSI=$( [ "$(g ro.product.system.name)" != "$(g ro.product.vendor.name)" ] && [ -n "$(g ro.product.vendor.name)" ] && echo yes || echo no)"
