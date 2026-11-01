# Legacy source preservation inventory

The original ZIP archives are preserved byte-for-byte in `legacy-modules/source-archives/`.
Extracted copies are provided beside them for review and porting. Their presence does not mean their scripts have been integrated into the Android application.

| Source archive | Extracted review folder | Role |
|---|---|---|
| `MkVenomPro_android_optimizer_v1.1.zip` | `android-optimizer-v1.1/` | App/performance profiles, package management and restore scripts, WebUI assets |
| `HyperCool_v1.6.zip` | `hypercool-v1.6/` | Performance/battery profile scripts, guards, configuration, restore and WebUI assets |
| `Ultimate_Tools_Spinel.zip` | `ultimate-tools-spinel/` | Device/ROM inspection, governors, sensors, USB/OTG, package tools and other control scripts |

## Porting rule

Do not delete or rewrite a legacy feature merely because it is not yet represented in Compose. First map it to a feature entry, document its permission and device requirements, then implement and test the Android-side equivalent. Features previously explicitly excluded by the project owner must remain excluded from the app UI.
