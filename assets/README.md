# Production asset drop zones

- `models/characters/`: humanoid GLB + rig, named `chr_<name>_vNN.glb`.
- `models/paddles/`: `paddle_<name>_vNN.glb`.
- `models/courts/`: `court_<setting>_vNN.glb`.
- `animations/`: reusable animations, separated where possible.
- `materials/`, `textures/`: production materials, albedo, normals, masks.
- `audio/sfx/`, `audio/music/`: properly licensed sound.
- `effects/`: custom particles and lightweight materials.
- `ui/`: icons/fonts/style resources with usage rights recorded.

These folders are intentionally mostly empty. The visible court and character in the starter are procedural Godot placeholder shapes. Read `docs/08_3D_ASSET_PIPELINE.md` before exporting.
