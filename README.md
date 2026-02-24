# Spanning Wallpaper

A [Noctalia](https://github.com/quickshell-mirror/quickshell) plugin that takes one image and spans it across all your monitors as a single continuous picture.

## What it does

Most wallpaper tools set the same image on each monitor independently. This plugin instead treats all monitors as one canvas — it figures out the combined bounding box of your display layout, resizes the image to fill it, then crops the right slice for each screen and applies them simultaneously.

## Features

- Spans any image across any number of monitors, accounting for different sizes and positions
- Optional [Real-ESRGAN](https://github.com/xinntao/Real-ESRGAN-ncnn-vulkan) AI upscaling before resize (falls back to Lanczos if not installed)
- Per-image upscale overrides independent of the global setting
- Auto-switching on a configurable interval
- Image browser panel with search and thumbnail previews (thumbnails are cached by SHA-256 hash)
- Bar widget with right-click context menu
- IPC target at `plugin:spanningwallpaper` for scripting

## Requirements

- Noctalia >= 4.1.2
- ImageMagick (`magick` in PATH)
- Optional: `realesrgan-ncnn-vulkan` at `~/.local/bin/` for AI upscaling

## Installation

```bash
git clone https://github.com/willcoded0/spanning-wallpaper
```

Copy the `spanning-wallpaper/` folder into your Noctalia plugins directory.

## Settings

| Setting | Default | Description |
|---|---|---|
| `wallpapersFolder` | `~/Pictures/Wallpapers/Spanning` | Folder to scan for images |
| `upscaleEnabled` | `false` | Run Real-ESRGAN before resize |
| `upscaleMultiplier` | `2` | Upscale factor (2 or 4) |
| `autoEnabled` | `false` | Auto-rotate wallpapers |
| `autoIntervalSec` | `300` | Rotation interval in seconds |

## IPC

```
plugin:spanningwallpaper
  setWallpaper(path)
  getWallpaper()
  random()
  clear()
  openPanel()
```

## How it works

`applySpanning()` reads screen geometry from `Quickshell.screens`, builds a shell script on the fly, and runs it via Quickshell's `Process` API. The script resizes the source image with ImageMagick (optionally after an AI upscale pass), crops per-screen slices in parallel, then calls `WallpaperService.changeWallpaper()` for each monitor.

## License

MIT
