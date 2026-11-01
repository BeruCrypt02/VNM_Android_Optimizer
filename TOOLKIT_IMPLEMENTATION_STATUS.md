# Implementation status

| Area | Status |
|---|---|
| Compose dashboard and navigation | Implemented |
| Device and kernel inspection | Implemented (read-only, availability varies by OEM) |
| Battery information | Implemented |
| Installed application inventory | Implemented |
| ADB/Fastboot reference catalog | Implemented (display only) |
| Local custom partition notes | Implemented |
| USB host capability detection | Implemented |
| Root detection | Implemented (detection only) |
| USB ADB/Fastboot protocol transport | Not implemented |
| Shizuku integration | Not implemented |
| Arbitrary command execution | Intentionally not implemented |
| Partition flashing / kernel flashing | Intentionally not implemented |
| Thermal-limit modification | Intentionally not implemented |

Device interfaces may be hidden by Android permissions, SELinux, or vendor kernels. Missing information is reported as unavailable rather than guessed.
