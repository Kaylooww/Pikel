# 08 — Blender → Godot asset pipeline (team-owned models)

## Global contract
- **Units:** meters (Blender scene units at 1.0), +Y up in Godot after glTF export/import; verify orientation.
- **Forward:** agree on forward facing -Z at rest for the local home player and document each model's actual forward before applying animations.
- **Locations:** all production originals under `assets/models/...` and animation clips under `assets/animations/` (or imported with the GLB).
- **Format:** Blender `.blend` source (store separately or in LFS), exported `.glb` for Godot. Avoid FBX unless justified.
- **Naming:** `chr_base_a.glb`, `paddle_core_a.glb`, `court_park_a.glb`, `anim_character_core.glb` (example convention).

## Character asset specification
| Feature | Contract |
|---|---|
| Character scale | Choose a consistent target reference (e.g. ~1.4–1.7m stylized) |
| Rig | Shared humanoid skeleton + stable bone names |
| Root | Single origin / root transform; no hidden 100× scale offset |
| Rest pose | Consistent A-pose or T-pose for all cosmetics |
| Swing clips | Forehand, backhand, dink, overhead, lunge, serve |
| Movement clips | Idle, 8-direction locomotion, acceleration, pivot, recovery |
| Animations | Prefer in-place first; networked movement controlled by gameplay |
| Paddle socket | Bone marker or child node for paddle handle grip |
| Modular slots | Hair, upper body, lower body, shoes, accessories |
| Materials | Reuse small material palette; avoid excessive draw calls |

## Court specification
- 6.096×13.4112m playable court plus run-off area; kitchen from z=-2.1336 to 2.1336.
- Net spans the width at z=0, height around 0.8636m center and 0.9144m edges.
- Mesh lines follow regulatory geometry, but **physics boundaries** use numeric/authoritative geometry independent of the art.
- Crowd, plants, buildings, benches and shadows are low-priority and separate from collision meshes.

## Paddle and ball
- Paddle collision representation is simple and gameplay-controlled; visual paddle can be stylized with thick bevels.
- The initial prototype uses a larger ball for readability; competitive physical collision scale should be reviewed separately.
- Ball material should stay visible on dark and light courts; optional trajectory shadow/reticle helps tracking.

## Export and import — detailed steps
1. Save original `.blend` file and apply object rotation/scale as appropriate (`Ctrl+A` in Blender) without destroying skinning.
2. Inspect mesh normals, modifiers, armature weights and animation actions.
3. Use **File → Export → glTF 2.0** (`.glb`), export selected objects when appropriate, include animations/materials only when needed.
4. Copy GLB to `assets/models/characters/` or the matching category.
5. Return to Godot and let it import. Click imported GLB in FileSystem → **Import** to adjust animation/material import rules as needed; reimport.
6. Instantiate imported GLB as a **visual child** under `CharacterBody3D`, not in place of the gameplay/collision controller.
7. Align mesh feet to y=0 and paddle grip to the paddle socket. Validate forward orientation, scale, skeleton, animation blending and collider.
8. Save a dedicated wrapper/variant scene so replacing the original GLB doesn't erase controller behavior.
9. Test running, hitting, and side switching from both halves; verify camera silhouette and performance.

## Don't do this
- Don't ship huge uncompressed Blender sources as game runtime resources.
- Don't animate world position via both root motion and network transform without a plan.
- Don't let visual model collisions decide scoring.
- Don't edit imported GLB internal nodes destructively without inherited/wrapper scenes.
- Don't put separate AI-generated images into the game as textures unless you have chosen to adapt them and verified readability/licensing.

## Team handoff package
Every model handoff includes: file, preview image, Blender version, scale/axis, rig reference, animation list, material slots, mesh counts, texture sizes, gameplay-facing attachment locations, license/ownership, and revision notes.
