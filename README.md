# Spanning Wallpaper

A [Noctalia](https://github.com/quickshell-mirror/quickshell) plugin that spans a single image seamlessly across all connected monitors as one unified canvas. No gaps, no seams — just one continuous picture across your entire desktop.

---

## Features

- **Seamless multi-monitor spanning** — automatically computes the bounding geometry of all screens and crops the correct slice for each monitor
- **AI upscaling** — optional [Real-ESRGAN](https://github.com/xinntao/Real-ESRGAN-ncnn-vulkan) upscaling before resize for sharper results on low-resolution source images
- **Per-image upscale overrides** — toggle AI upscaling on or off for individual images, independent of the global setting
- **Auto-switching** — rotate through your wallpapers folder on a configurable interval (1 min – 1 hour)
- **Thumbnail cache** — SHA-256-keyed 384×384 thumbnail cache for fast panel browsing without re-reading full images
- **Browse & search panel** — 1000×700 image browser with live search, selection state, processing indicator, and folder picker
- **IPC support** — control the plugin externally from scripts or other plugins via `plugin:spanningwallpaper`
- **Bar widget** — system bar pill with right-click context menu for quick access to Panel, Random, Clear, and Settings

---

## Requirements

- [Noctalia](https://github.com/quickshell-mirror/quickshell) >= 4.1.2
- [ImageMagick](https://imagemagick.org/) (`magick` available in PATH)
- **Optional:** `realesrgan-ncnn-vulkan` binary and models at `~/.local/bin/` for AI upscaling

---

## Installation

Install via the Noctalia plugin registry by adding this repository URL, or clone manually:

```bash
git clone https://github.com/willcoded0/spanning-wallpaper
```

Then point Noctalia at the cloned directory or copy the `spanning-wallpaper/` folder into your Noctalia plugins directory.

---

## Usage

### Selecting a wallpaper

Click the wallpaper icon in your system bar to open the panel. Browse or search your wallpapers folder, then click any image to apply it. The plugin will resize the image to fill the combined bounding box of all your monitors and crop a perfectly aligned slice for each screen.

### Random wallpaper

Click **Random** in the panel header or right-click the bar widget and select **Random**. A random image from your wallpapers folder will be applied.

### Clearing

Select **Clear** from the bar widget context menu or panel header to reset all monitors to the system default wallpaper.

### AI Upscaling

Enable **AI Upscaling** in Settings to run `realesrgan-ncnn-vulkan` on the source image before resizing. This produces noticeably sharper results when the source image is smaller than your combined desktop resolution. Requires `realesrgan-ncnn-vulkan` installed at `~/.local/bin/`.

You can also toggle upscaling per-image using the sparkle badge on each thumbnail in the panel — useful for overriding the global setting on specific images.

> Note: AI upscaling adds roughly 15–30 seconds of processing time depending on hardware.

### Auto-switching

Enable **Auto Wallpaper Switching** in Settings and choose an interval. The plugin will automatically cycle through your wallpapers folder at the selected interval.

---

## Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `wallpapersFolder` | `~/Pictures/Wallpapers/Spanning` | Folder scanned for wallpaper images |
| `upscaleEnabled` | `false` | Enable Real-ESRGAN AI upscaling globally |
| `upscaleMethod` | `lanczos` | Fallback resize filter when AI upscaling is off |
| `upscaleMultiplier` | `2` | AI upscale factor (2× or 4×) |
| `autoEnabled` | `false` | Enable automatic wallpaper rotation |
| `autoIntervalSec` | `300` | Rotation interval in seconds (60/300/600/1800/3600) |

---

## IPC

The plugin exposes an IPC target at `plugin:spanningwallpaper` for external control:

| Method | Arguments | Description |
|--------|-----------|-------------|
| `setWallpaper` | `path: string` | Apply a specific image by path |
| `getWallpaper` | — | Returns the current wallpaper path |
| `random` | — | Apply a random image from the wallpapers folder |
| `clear` | — | Reset all monitors to the default wallpaper |
| `openPanel` | — | Open the image browser panel |

---

## How It Works

When a wallpaper is applied, the plugin queries `Quickshell.screens` to read each monitor's position and dimensions. It computes the total bounding rectangle, then dynamically generates a shell script that:

1. Optionally runs `realesrgan-ncnn-vulkan` to upscale the source image
2. Uses ImageMagick to resize the image to exactly fill the bounding box
3. Crops a per-monitor slice in parallel using `magick -crop` with each screen's geometry
4. Calls `WallpaperService.changeWallpaper(slicePath, screenName)` for each monitor simultaneously

Thumbnail previews in the panel are cached to disk using a SHA-256 hash of the image path as the filename key, keeping the browser fast even with large wallpaper collections.

---

## License

MIT — see [LICENSE](LICENSE)

**Author:** Will Hall · [GitHub](https://github.com/willcoded0) · [Portfolio](https://willcoded0.github.io/portfolio/)
