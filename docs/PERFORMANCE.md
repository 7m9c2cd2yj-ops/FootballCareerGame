# Performance budget

Target: **stable 60 FPS** on a mid-range phone from the last four years
(reference devices: Samsung Galaxy A52/A53 class, Snapdragon 720G–778G or
equivalent, 4–6 GB RAM, and iPhone 11 / A13 or newer).
These are targets. They must be measured on a real device in M8.

## Frame budget (16.6 ms)

| Area | Budget |
|------|--------|
| CPU game logic + scripts | ≤ 4 ms |
| Physics (3D moments only) | ≤ 2 ms |
| Rendering (CPU submit + GPU) | ≤ 9 ms |
| Headroom | ≥ 1.6 ms |

## Rendering (3D moments)

- Renderer: Mobile (Vulkan / Metal). Compatibility (OpenGL) is the fallback only.
- Draw calls: ≤ 150 per frame. Visible triangles: ≤ 150k.
- Low-poly stylized models: player ≤ 4k tris, ball ≤ 500, stadium ≤ 40k.
  Crowd uses a few billboard or MultiMesh instances, not individual meshes.
- Lighting: one directional light. Shadows on the players and ball only, at
  low resolution, or blob shadows. No real-time GI, SSAO, SSR, glow or volumetrics.
- Materials: vertex colors or one small atlas per object. Unshaded or simple
  lit shaders. No custom screen-space effects.
- Optional 3D resolution scale of 0.8 or higher on weaker devices (setting in M8).

## Textures and memory

| Asset | Max size | Format |
|-------|----------|--------|
| Character atlas | 512×512 | ASTC/ETC2 (VRAM compressed) |
| Stadium / pitch atlas | 1024×1024 | ASTC/ETC2 |
| UI icons and crests | Vector (SVG) or 256×256 | Lossless |
| Total texture memory | ≤ 128 MB | |
| Total app RAM | ≤ 600 MB | |
| Install size (AAB download) | ≤ 150 MB | |

Club crests and kits are simple vector shapes generated from data, so they
cost almost nothing.

## Menus (portrait 2D)

- No continuous redraw when idle. Animations are short tweens only.
- Lists of clubs, players and feed posts are built lazily, not all at once.

## How to measure (M8)

Use the Godot remote debugger's Monitors tab (FPS, draw calls, video memory)
on a device with a debug build. Record the results in the table below.

| Device | Scene | Avg FPS | 1% low | Draw calls | VRAM |
|--------|-------|---------|--------|------------|------|
| _not measured yet_ | | | | | |
