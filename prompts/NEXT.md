# NEXT — what to do when the user says "continue" or "next"

When the user's whole message is "continue" or "next" (any capitalisation or punctuation), they are asking you to build the next piece of RallyPop Pickleball on your own: pick the next backlog task, branch out, implement it, prove it works, commit it, push the branch, and ask them to merge it. They do not want to be asked what to work on. This file is the full brief for that one word.

The user is building this game one small verified step at a time. Each "continue" should leave the repository in a state where the game still imports and every test passes, with exactly one backlog task further along. A small finished task is worth more than a large half-finished one, because the user reviews each step and a later "continue" builds on it.

## 1. Find out where things stand

Run `git status -sb`, `git branch -a` and `git log --oneline -5`.

- If the working tree has uncommitted changes you did not make in this session, stop and ask the user what they are. Do not commit, stash or discard someone else's work.
- Run `git fetch origin` so you know what has been merged.
- If a branch from an earlier task is not merged into `origin/main` yet, do not start new work and do not stack a new branch on it. Ask the user to merge it (or to tell you to merge it), and stop. One branch is open at a time.
- If an earlier branch has been merged but still exists, delete it locally and on GitHub before starting.

## 2. Pick the task

`docs/11_ROADMAP_AND_BACKLOG.md` is the single source of truth for progress. Tasks are checkboxes: `[x]` is done, `[ ]` is open.

Take the first open task in the lowest-numbered sprint, P0 tasks before P1 tasks, in ID order. Do exactly one task per "continue".

Skip a task, and say that you skipped it and why, when:

- **It needs a human.** RP-003 (manual F5 playtest) and anything that needs someone to look at the screen, judge game feel, or supply Blender models. You cannot do these, and pretending to would break the project's honesty rule. Leave the box unticked.
- **It needs approval first.** `AGENTS.md` and `prompts/MASTER_STARTING_PROMPT.md` require a human decision before external SDKs or services, paid infrastructure, an engine change, a large architecture migration, or a public release. For these, write the proposal in your reply and stop instead of building.
- **Its dependency is still open.** Do the dependency instead.

If a task is too large to finish and verify in one session (most of Sprint 3 and 4 are), do its first testable slice. Add the remaining slices as indented open checkboxes under the task in the roadmap so the next "continue" picks up from there, and leave the parent unticked until all slices are done.

If no open task is left that you can do, say so, list what is waiting on a human, and stop.

## 3. Read before writing

Read `AGENTS.md`, the spec in `docs/` that covers the task (physics → 04, rules → 05, networking → 06, controls → 03, UI → 09, assets → 08), and the scripts and tests you will touch. The specs describe intent; the code is what actually exists, and they sometimes disagree. When they do, trust the code and fix the doc as part of the task.

## 4. Create the branch

Branch names and commit messages follow `docs/19_GITHUB_RULES.md`: branch `<commit type>/<short-kebab-description>`, commit `<commit type>: <short description>`. Never commit on `main`.

Always branch from an up-to-date `main` (`git checkout main`, `git pull origin main`, `git checkout -b <branch>`). Section 1 already guaranteed that nothing unmerged is outstanding.

## 5. Implement

Make the smallest change that fully completes the task's acceptance line in the roadmap. Follow the module boundaries in `docs/02_TECHNICAL_ARCHITECTURE.md`: gameplay logic never depends on UI nodes, `scripts/core/court_dimensions.gd` owns all dimensions, and pure logic lives in classes that can be tested without a scene. Do not touch unrelated modules and do not add dependencies.

Any change to physics, rules, match state, networking or serialization needs a test in `tests/unit/` in the same style as the existing ones (a `SceneTree` script that prints `PASS: N ...` and exits 0, or prints failures and exits 1). Add each new test to both `tools/validate_project.ps1` and `tools/validate_project.sh`.

## 6. Verify

Godot 4.7.2 is on PATH as `godot`. Run all of these and read the output; every one must exit 0 with no script errors:

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/unit/<each test file>.gd
godot --headless --path . --quit-after 120 res://scenes/game/training.tscn
```

The first command also generates the `.uid` file for any new script; those get committed. If something fails, fix the root cause and rerun. Do not weaken a test to make it pass. If you cannot get to green, do not commit: report the failure with its output and stop.

Headless runs prove the code parses, the tests pass and the scene loads. They do not prove the game feels right. Keep that distinction in your report.

## 7. Update the records

- Tick the task `[x]` in `docs/11_ROADMAP_AND_BACKLOG.md`.
- Update the truth table in `README.md` if a feature's status changed.
- Add the real command results to `docs/18_VALIDATION_STATUS.md`.
- Fix any other doc your change made untrue.

## 8. Commit and push to the branch

The user has asked that every finished task ends committed and pushed to its branch, so do this without asking.

- Stage files by name, not `git add .`, and check `git status` first so nothing unexpected goes in. Include `.uid` and `.import` sidecars. Never stage `.godot/`, `builds/`, `logs/`, `.env` files or anything containing a secret.
- One logical change per commit. Tests and docs for a feature go in the feature's commit.
- The user is the sole author. Use the configured git identity and do not add a `Co-Authored-By` trailer.
- `git push -u origin <branch>`.

## 9. Ask for the merge, then clean up

Merging into `main` is the user's decision, so ask and wait. End your report with a direct request: they can merge the branch on GitHub (give the link the push printed), or reply "merge" and you will do it.

- If they tell you to merge: `git checkout main`, `git pull origin main`, `git merge --no-ff <branch> -m "chore: merge <branch> into main"`, `git push origin main`. Rerun the checks on `main` after merging and report the result.
- If they say they merged on GitHub: `git checkout main`, `git pull origin main`, and confirm the branch is in `origin/main` before going further.
- Once the merge is confirmed, delete the branch in both places: `git branch -d <branch>` and `git push origin --delete <branch>`. Use `-d`, not `-D`, so git refuses if something is unmerged.
- Then stop. Tell the user the branch is merged and deleted and that you are waiting for "continue". Do not start the next task on your own.

## 10. Report

Reply briefly, leading with what now works. Include:

- the task ID and one sentence on what it does for the game,
- the branch, commit hashes and the GitHub link for merging,
- the commands you ran and their real results,
- what is still approximate or unverified, including that no human has played it,
- anything you skipped and why,
- which task the next "continue" will pick up,
- the merge request from section 9, as the last thing in the reply.

Never say something was tested, played or seen unless you actually ran it in this session.
