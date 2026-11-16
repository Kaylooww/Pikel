# 07 — Original visual identity and aesthetic guidelines

## Direction
**Sunny court / toy-like athletes / competitive clarity.** Original chibi characters, exaggerated facial expressions, high-contrast outlines, a polished readable court, small but satisfying impact FX. Inspired by the accessible feel of contemporary arcade sports games, not a duplication of any reference game's proprietary art.

## Original generated images
| File | Purpose |
|---|---|
| `references/concept_art/01_court_environment.png` | Exterior court palette, atmosphere, set dressing |
| `references/concept_art/02_character_direction.png` | Original chibi character proportions and uniform shapes |
| `references/concept_art/03_gameplay_hud_direction.png` | 3D camera, cursor/trajectory readability, match HUD direction |
| `references/concept_art/04_paddles_equipment_palette.png` | Paddle concepts, ball, shoes, net and textures |
| `references/concept_art/00_full_style_board.png` | Combined art board |

**These are original AI-generated visual concepts**, NOT production-ready source meshes, rigging references with exact orthographic proportions, or copyrighted gameplay captures. Reinterpret through your own 3D model designs.

## Palette
| Usage | HEX | Note |
|---|---|---|
| Deep navy | `#17324D` | UI typography and dark equipment |
| Court blue | `#285C8D` | Main play surface |
| Court teal | `#32B6AD` | Kitchen/inset surface |
| Aqua accent | `#55D5CB` | Target indicator / positive motion |
| Coral | `#FF816C` | Home player accent |
| Sun yellow | `#FFE06B` | Ball and shot feedback |
| Soft sky | `#BDE8F1` | Background |
| Off-white | `#F7F7F2` | Lines and UI |

## Character proportions
- Head 1.4–1.8× natural relative size, relatively short body, readable expression even at gameplay camera distance.
- Preserve distinct silhouettes and cloth color contrast.
- One reusable skeleton where possible. Allow hair/clothes/shoes as interchangeable meshes attached to rig slots.
- Avoid expensive per-frame deformation and heavy transparent effects on performance targets.

## UI style
Small consistent scoreboard at screen top, highlighted serving team, center-court targeting ring/reticle with a clearly visible predicted bounce point, transparent hints without obstructing the ball, large readable fault labels and clean menu transitions.

## Effects
Impact spark at paddle, limited trail during drives, cyan ring for cursor target, tiny puff on ground bounce, no overbearing screen shakes in competitive mode. Keep accessible color and motion alternatives.

## Reference handling and originality
Do not add screenshots or ripped models from *just volleyball* into this repository. Avoid copying its characters, UI assets, texture atlases, code or brand. The generated image sheets here are original reference direction, and you must redraw final in-game assets and confirm commercial-rights requirements for external fonts, SFX, textures, and plugins.
