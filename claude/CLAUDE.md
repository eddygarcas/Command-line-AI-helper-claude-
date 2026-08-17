# Environment

- CachyOS (Arch-based), KDE Plasma 6 on Wayland, Ghostty terminal.
- My interactive shell is Fish 4.x, but you run commands via bash. My Fish
  functions, abbreviations, and conf.d setup are NOT available to you.
- Language runtimes are managed by mise, NOT asdf. Always invoke via
  `mise exec -- <cmd>` (e.g. `mise exec -- bundle exec rspec`). Bare
  `ruby`/`node`/`zig` may resolve to the wrong version or not at all.
- Secrets come from 1Password CLI: `op read "op://vault/item/field"`.
  Never print secret values into the transcript.
- Package manager is pacman; AUR helper is paru. Repos include znver4
  variants (cachyos-znver4, cachyos-core-znver4, cachyos-extra-znver4)
  ahead of core/extra/multilib.

# How I want you to work

- Explain a command before running it if it mutates anything.
- Absolute paths are fine; I often ask about files outside the cwd. Use
  /add-dir if you need sustained access to another tree.
- Be terse. I write Ruby, TypeScript, Go, and Zig daily. Skip beginner framing.
- When writing fish, use fish syntax: `(cmd)` not `$(cmd)`, `set -x` not
  `export`, `test` not `[[ ]]`, and no heredocs.
