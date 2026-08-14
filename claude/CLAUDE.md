# Shell helper workspace

This is a scratch workspace for command-line assistance, not a code project.
There is no codebase here.

## Environment
- CachyOS (Arch-based), KDE Plasma 6 on Wayland
- My interactive shell is Fish 4.x, but you run commands via bash.
  My Fish functions, abbreviations, and conf.d setup are NOT available to you.
- Language runtimes are managed by mise, NOT asdf. Always invoke via
  `mise exec -- <cmd>` (e.g. `mise exec -- bundle exec rspec`).
  Bare `ruby`/`node`/`zig` may resolve to the wrong version or not at all.
- Secrets come from 1Password CLI: `op read "op://vault/item/field"`.
  Never print secret values into the transcript.
- Package manager is pacman/paru. Use `paru -S` for AUR.

## How I want you to work here
- Prefer explaining a command before running it if it mutates anything.
- Absolute paths are fine — I'll often ask about files outside this directory.
  Use /add-dir if you need sustained access to another tree.
- Be terse. I'm a CTO who writes Ruby, TypeScript, Go, and Zig daily;
  skip the beginner framing.
