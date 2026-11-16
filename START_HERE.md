# START HERE — the first 60 minutes

## 0. What you received
A Godot project with source code; structured game-design and technical documents; original concept illustrations; blank original-asset folders; Claude project instructions and a master prompt. It is **not a finished multiplayer game**.

## 1. Windows installation checklist
- [ ] Unzip this package into a normal folder (short path without `OneDrive` sync is recommended for initial testing).
- [ ] Download **Godot 4.7.2 Standard** from <https://godotengine.org/download/windows/>. The `.NET` version is unnecessary for this GDScript starter.
- [ ] Install Blender and VS Code, if wanted.
- [ ] Open `project.godot` in Godot Project Manager; do NOT create a separate empty project and paste random folders into it.
- [ ] Run **F5** to test the starter.
- [ ] Check Godot **Debugger → Errors**, and fix parse errors before doing any feature work.
- [ ] Install Claude Code, authenticate, and open the **same root folder** in VS Code.
- [ ] Read the integration setup; optionally install the external Godot MCP bridge after backing up/committing this project.

## 2. Exactly how to "plug the files" into Godot
Godot reads everything under the directory containing `project.godot`. The `scenes/`, `scripts/`, `assets/`, and `references/` folders are already **inside** the project. You do **not** upload Markdown to a dashboard or manually import `.gd` files.

- **`.tscn` scene files** → appear in Godot **FileSystem** dock and can be opened or instanced.
- **`.gd` scripts** → auto-indexed; linked to scenes through their `script` resources.
- **`.glb` models** → copy/export into `assets/models/...`; Godot imports them. Drag imported scenes into the appropriate character/court scene.
- **`.png` concept art** → under `references/` for consultation, **not** installed as gameplay material.
- **`.md` design docs** → Godot may list them, but read/edit them in VS Code; they are the context Claude consumes.
- **`CLAUDE.md` and `AGENTS.md`** → instructions for supported AI coding workflows, not Godot executable scripts.

## 3. First Claude prompt
Open a Claude Code session with working directory set to this project root. Copy [prompts/MASTER_STARTING_PROMPT.md](prompts/MASTER_STARTING_PROMPT.md). Ask Claude to **inspect and validate before implementing**. Do not request "finish the entire game" in a single turn.

## 4. First Git commit
```powershell
cd "C:\Dev\RallyPop_Pickleball_Godot_Starter"
git init
git add .
git commit -m "chore: add Godot pickleball vertical-slice starter"
```
Create an empty GitHub repository if you want cloud backup. Verify that no keys, auth tokens, or `.godot/` cache were committed.

## 5. First playable acceptance
Press F5, start the practice court, move the capsule, aim the target on the far court, hit the staged ball, and observe a bounce or net fault. This proves only the **vertical-slice scaffold**, not full match logic.

## 6. Next actions
Ask Claude to repair any runtime issues, write a reproducible test report, then implement the next backlog task: **accurate paddle-contact timing and fixed-step ballistic trajectory solver**.
