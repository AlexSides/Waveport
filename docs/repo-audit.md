# Public Release Audit

This note captures the cleanup pass for turning Waveport into a public portfolio repository.

## Public-Safe Source Folders

- `assets/`
- `cards/`
- `data/`
- `enemies/`
- `globals/`
- `modules/`
- `scenes/`
- `ship/`
- `ui/`

## Keep Private Or Generated

- `.godot/`
- `export_credentials.cfg`
- `.mono/` and `mono_crash.*.json`
- local runtime save data written to `user://save_slot_1.json` outside the repo
- future personal notes, raw captures, or export/signing material that is not meant for the portfolio

## Findings From This Pass

- Fixed a case-sensitive path issue in `data/CardList.gd`: `Crate.png` now matches the on-disk file `assets/cards/crate.png`.
- Verified that `project.godot` resolves to `scenes/MainMenu.tscn` as the main scene.
- Ran a static `res://` reference scan across `.gd`, `.tscn`, and `project.godot`; no missing resource paths were found.
- Noted an odd filename in `modules/BasicCannon.tscn.tscn`. It was left unchanged because it is not part of the live resource-reference set inspected in this release pass.

## Recommended Before Publishing

- Add 2-4 screenshots or a short GIF to `media/screenshots/`.
- Decide whether to add a `LICENSE` file for the public GitHub release.
- If export presets or signing files are added later, review them before committing so machine-specific credentials do not leak.
