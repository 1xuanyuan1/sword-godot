# SDLPal upstream baseline

The behavior and data-format reference is a separate, read-only sibling checkout:

- Local path: `/Users/xuanyuan/Documents/godotwork/sdlpal-official`
- Primary mirror: `https://gitee.com/sdlpal/sdlpal.git`
- Verification remote: `https://github.com/sdlpal/sdlpal.git`
- Branch: `master`
- Pinned commit: `79718a1aa2fb889994d1d084765025994d429706`
- Commit date: 2026-07-13 19:40:35 +0800

The older `/Users/xuanyuan/Documents/godotwork/sdlpal` snapshot is retained only for historical and executable-behavior comparison.

The local integration data was initially assumed to be Simplified Chinese, but byte-level detection and decoded labels identify it as the DOS Traditional Chinese CP950/Big5 edition. The importer records this detected edition in its ignored manifest.

## Update policy

Upstream is not updated automatically. A new SDLPal revision must be reviewed manually, with behavior changes and relevant source mappings recorded here before the pin changes. The Godot port targets SDLPal's default classic battle path (`ENABLE_REVISIED_BATTLE` disabled).

## Initial source mapping

| Godot subsystem | SDLPal reference |
| --- | --- |
| MKF, sprite and RLE formats | `palcommon.c` |
| YJ1/YJ2 compression | `yj1.c` |
| Palettes and fades | `palette.c` |
| Isometric maps | `map.c`, `scene.c`, `res.c` |
| Structured game data/save state | `global.c`, `global.h` |
| Script virtual machine | `script.c` |
| Classic battle loop | `battle.c`, `fight.c`, `uibattle.c` |
| Text/code pages/font | `text.c`, `font.c`, `codepage.h` |
| RIX/VOC audio | `rixplay.cpp`, `sound.c`, `adplug/` |
