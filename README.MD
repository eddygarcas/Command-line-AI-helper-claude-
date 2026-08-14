# claude-shell

Fish shell wrappers that turn [Claude Code](https://code.claude.com/docs/en/setup)
into a command-line assistant. Built for CachyOS, but nothing here is
Arch-specific beyond the `paru` calls.

Two modes, deliberately separated:

- **Print mode** (`ai`, `aim`, `explain`) — stateless one-shots via `claude -p`.
  No repo context, no session state, and no workspace trust prompt. Output is
  post-processed into plain text so it pastes straight into a prompt.
- **Interactive** (`cs`) — a full Claude Code session in a single trusted
  scratch directory, for anything that spans multiple commands or needs to
  react to output.

## Requirements

- Fish 4.x
- Claude Code, plus a Pro, Max, Team, Enterprise, or Console account
- `glow` (only for `aim`) — `paru -S glow`

## Install

```fish
git clone https://github.com/eddygarcas/claude-shell ~/code/claude-shell
~/code/claude-shell/install.fish
```

`install.fish` symlinks into `~/.claude/` and `~/.config/fish/functions/`,
creates `~/shell/`, and prints the two manual steps left:

```fish
paru -S glow          # required by aim
cd ~/shell && claude  # accept the trust prompt once
```

Symlinks rather than copies, so edits in the repo take effect immediately and
`git status` stays honest about drift. Re-running `install.fish` is safe.

Fish autoloads from `functions/`, so no `source` and no shell restart.

## What's in here

```
claude-shell/
├── install.fish
├── claude/
│   ├── CLAUDE.md          → ~/.claude/CLAUDE.md
│   └── settings.json      → ~/.claude/settings.json
└── fish/functions/        → ~/.config/fish/functions/
    ├── ai.fish
    ├── aim.fish
    ├── explain.fish
    ├── cs.fish
    └── _ai_clean.fish
```

`claude/CLAUDE.md` carries environment context — mise not asdf, bash not fish,
1Password for secrets, pacman for packages. It lives at **user level**, not in
`~/shell`, because project memory is read from the current working directory and
`ai` runs from wherever you happen to be standing.

`claude/settings.json` holds a permission allow list for read-only commands and
a deny list covering `~/.ssh`, `~/.aws`, `.env` files, and `op read`.

## Usage

### `ai` — paste-ready answers

```fish
ai "fish syntax to loop over files matching a glob"
ai "systemd unit to run a script every 30 minutes"
ai "git command to move the last 3 commits to a new branch"
ai "zig build flags for a release-safe static binary"
ai "psql to show the 10 largest tables with index sizes"
```

Anything on stdin is appended under an `--- input ---` header, so the question
and the data arrive in one turn:

```fish
git diff --cached | ai "review this, flag bugs only"
journalctl -u sidekiq -n 200 --no-pager | ai "what is failing"
kamal app logs --lines 200 | ai "summarise the errors by frequency"
bundle exec rspec 2>&1 | ai "why did this fail"
doctl compute droplet list | ai "which of these are undersized"
```

### `aim` — explanations, rendered

Same path as `ai`, piped through `glow`. For answers you intend to read rather
than run.

```fish
aim "how does Rails cache_key_with_version interact with ActsAsTenant"
aim "difference between Zig's ArenaAllocator and FixedBufferAllocator"
git diff main...HEAD | aim "write a PR description"
```

### `explain` — before you run it

```fish
explain "git filter-repo --invert-paths --path config/secrets.yml"
explain "pacman -Rns (pacman -Qtdq)"
explain "find . -name '*.log' -mtime +30 -delete"
```

### `cs` — interactive session

```fish
cs                    # new session in ~/shell
cs --continue         # resume the most recent
cs --resume           # pick from a list
```

In-session: `/add-dir ~/code/some-repo` to grant access to a real project,
`/config` for settings, `/help` for the rest.

## Verifying output

Check the terminal directly rather than a copy — clipboards mangle whitespace
and capitalization, which is worth several rounds of phantom debugging.

```fish
ai "some query" | cat -n              # confirm line breaks survived
ai "some query" | head -1 | cat -A    # confirm exact first-line bytes
```

## Notes

**Format guarantees belong in the pipeline, not the prompt.** Repeatedly asking
the model not to emit markdown fences did not stop it. One `sed` line in
`_ai_clean` did. Style strings shape tendencies; filters enforce invariants.

**Claude Code shells out to bash, not fish.** Your functions, abbreviations, and
`conf.d` setup do not exist as far as the agent is concerned. This is why
`CLAUDE.md` spells out `mise exec --` explicitly — bare `ruby` or `zig` may
resolve to the wrong version, or to nothing.

**Trust is per-directory and one-time.** It gates project-scoped configuration
(`.claude/settings.json`, `.mcp.json`, hooks), not command execution — those are
approved separately. `~/shell` is trusted precisely because it contains nothing.
`--dangerously-skip-permissions` does *not* bypass the trust prompt.

**Verify anything load-bearing.** Shell trivia is the category where a
plausible-sounding flag or variable turns out not to exist. `man` and `--help`
are cheaper than a wrong command.

## Customising

The style string at the top of `ai.fish` controls output shape. The clauses
doing the real work are the ones forbidding self-revision and forbidding mention
of flags the model isn't certain exist — terseness pressure otherwise tends to
produce a confident-sounding detail just to fill the line.

For bare commands with no explanation at all, replace *"Then either stop, or add
exactly one declarative sentence"* with *"Output nothing else."*

## License

MIT
