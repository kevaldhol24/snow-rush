# CLAUDE.md: start here

Snow Rush is a mobile (Android) endless downhill **free-carve snowboarding** game in **Godot 4.3**, for KDIT Labs (Keval Dhol).

## ⚠️ Work in progress
Phase 1 is done and merged into `main`. **Phase 2 (look-dev)** happens on branch **`phase-2-wip`** (merged only after Keval approves the build). Run `git checkout phase-2-wip` if it exists, then read the top entry of `docs/DEVLOG.md`.

## Read before doing anything
1. `docs/ROADMAP.md`: **Current status** + which phase/tasks are next. Update it as you work.
2. `docs/DECISIONS.md`: what's decided and why. Don't silently reverse decisions; add a new entry instead.
3. `docs/DEVLOG.md`: what was done in past sessions, how and why (newest first).
4. `docs/GDD.md` (game design), `docs/ART_DIRECTION.md` (visual target), `docs/TECH.md` (architecture, **cloud setup commands**, testing), `docs/ASSETS.md` (sources, licences, register).

## How we work with Keval
- Keval playtests on his phone (Oppo Reno 16c) and gives feedback. Claude does design, code, art pipeline and testing.
- He communicates tersely and wants direct, honest answers with no hype. Push back with reasons when needed.
- **Discuss before big changes.** Work in phases. Each phase ends with a debug APK sent to him, plus screenshots.
- Visual quality matters as much as gameplay (D-010).

## Ground rules
- **Log every task/session in `docs/DEVLOG.md`** (newest on top, use the template there): what, why, how, result/feedback, next. Add the entry in the same commit as the work (or right after), and include Keval's feedback when he gives it.
- Keep the game runnable after every commit. Commit in small, descriptive steps. Push to `main` (CI builds the APK).
- Every third-party asset → `docs/ASSETS.md` register (licence!). Raw packs in `assets/third_party/` (not exported).
- Cloud sessions can download from GitHub/npm/PyPI plus the hosts Keval has allowed (kenney.nl, quaternius.com, dl.google.com as of 2026-11-12; see `docs/ASSETS.md`). Test a host before relying on it; ask Keval to allow or upload anything else.
- GitHub is linked (2026-11-12): push work branches; `main` only after Keval approves the build.
- Verify with the headless autotest + xvfb screenshots before handing over (commands in `docs/TECH.md §4`).
- Don't commit secrets. The `ci/debug.keystore` is a public test key only.
