# 19 — GitHub rules and commit/push instructions

Remote: `origin` → <https://github.com/Kaylooww/Pikel.git>. Default branch: `main`.

## Commit message format

```text
<commit type>: <short description>
```

- Type is lowercase, followed by a colon and one space.
- Description is short (aim for 60 characters or fewer), imperative mood ("add", not "added"), no trailing period.
- One logical change per commit. If you need "and" in the description, split the commit.
- Optional: a blank line, then a body explaining *why*. Reference the backlog ID there (for example `RP-010`).

| Type | Use for |
|---|---|
| `feat` | New gameplay, system or user-visible behaviour |
| `fix` | Bug fix |
| `test` | Adding or changing tests only |
| `docs` | Markdown, specs, comments only |
| `refactor` | Code restructuring with no behaviour change |
| `perf` | Performance improvement |
| `asset` | Models, textures, audio, animations, scenes that are art-only |
| `chore` | Tooling, config, `.gitignore`, project settings, housekeeping |
| `revert` | Reverting an earlier commit |

Examples:

```text
feat: add swept net collision for the ball
fix: stop ball spawning on the opponent half
test: add net collision unit scenarios
docs: record headless validation results
asset: add placeholder paddle glb
chore: add net collision test to validate scripts
```

## Repository rules

1. **Never commit directly to `main`.** One issue → one branch → one pull request (see `AGENTS.md`).
2. **Branch names:** `<commit type>/<short-kebab-description>`, for example `feat/swept-net-collision` or `fix/ball-spawn-side`.
3. **Run the checks before every commit.** Both must exit 0:
   ```powershell
   ./tools/validate_project.ps1
   ```
   A commit that touches physics, rules, match state, networking or serialization must include or update a test.
4. **No secrets or PII:** no API keys, tokens, `.env` files or player data in code, scenes, Markdown or history.
5. **No third-party copyrighted assets**, screenshots or code from reference games.
6. **Do not commit generated or local files:** `.godot/`, `builds/`, `logs/`, `.claude/settings.local.json`. These are already in `.gitignore`; do not force-add them.
7. **Do commit Godot `.uid` and `.import` sidecar files** alongside the file they belong to. Missing sidecars break references on other machines.
8. **Keep commits small.** Do not mix unrelated modules, and do not mix a refactor with a behaviour change.
9. **Never force-push `main`** and never rewrite history that is already pushed to a shared branch.
10. **Large binaries** (`.blend`, `.glb`, audio) need team agreement first; Git LFS is not configured yet.
11. **Pull requests** need: what changed, commands run with their real output, known limitations, and at least one reviewer approval before merge. Do not say "tested" without saying whether it was code inspection, headless import, unit test or live gameplay.

## Commit and push, step by step

```powershell
# 1. Start from an up-to-date main
git checkout main
git pull origin main

# 2. Create your branch
git checkout -b feat/swept-net-collision

# 3. Do the work, then run the checks
./tools/validate_project.ps1

# 4. Review what changed, then stage specific files (avoid `git add .`)
git status
git diff
git add scripts/physics/net_collision.gd scripts/physics/net_collision.gd.uid tests/unit/test_net_collision.gd

# 5. Commit using the required format
git commit -m "feat: add swept net collision for the ball"

# 6. Push the branch (first push sets the upstream)
git push -u origin feat/swept-net-collision

# 7. Open a pull request into main on GitHub (or with the CLI)
gh pr create --base main --title "feat: add swept net collision for the ball"
```

After the pull request is merged:

```powershell
git checkout main
git pull origin main
git branch -d feat/swept-net-collision
```

## Fixing common mistakes

| Situation | Command |
|---|---|
| Wrong message on the last commit, **not pushed yet** | `git commit --amend -m "fix: correct message"` |
| Staged a file by mistake | `git restore --staged <file>` |
| Branch is behind `main` | `git fetch origin` then `git merge origin/main` |
| Already pushed a bad commit | `git revert <sha>` and push; do not rewrite history |
| Committed a secret | Tell the team immediately and rotate the secret; deleting the commit is not enough |
