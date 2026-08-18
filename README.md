# claude-shell

Fish shell functions that turn [Claude Code](https://code.claude.com/docs/en/setup)
into a terminal assistant: describe what you want, get the command, install
whatever it needs, run it.

Built for CachyOS. The pacman/paru paths are Arch-specific; everything else is
portable fish.

```fish
$ aix "check available formats for https://www.youtube.com/watch?v=DMGLAV8Q0mM"

yt-dlp -F https://www.youtube.com/watch?v=DMGLAV8Q0mM
Missing command: yt-dlp
Multiple repos provide yt-dlp:
  1) extra/yt-dlp
  2) chaotic-aur/yt-dlp-git
Which? [1] 1
Install extra/yt-dlp ? [y/N] y
...
[r]un  [e]dit  [s]ave as script  [N]o?
```

## Design

Two modes, deliberately separate:

**Print mode** (`ai`, `aim`, `aix`, `explain`) — stateless one-shot calls with
tools disabled and a single turn. No repo context, no session state, no
workspace trust prompt. The model writes text; nothing else happens without
your say-so.

**Interactive** (`cs`) — a real Claude Code session in one trusted scratch
directory, for work that spans several commands or needs Claude to inspect
things itself.

The design principle that emerged from building this: **format and safety
guarantees belong in the pipeline, not the prompt.** Asking the model four
separate times to stop emitting markdown fences did not work; one `sed` line
did. The system prompts here still matter — they shape what the model reaches
for — but every invariant is enforced by a check that does not depend on the
model cooperating.

## Requirements

- Fish 3.7+ (4.x recommended)
- Claude Code, plus a Pro, Max, Team, Enterprise, or Console account
- `glow` for `aim` only — `paru -S glow`
- Arch-family distro for the auto-install path

## Install

```fish
git clone https://github.com/eddygarcas/claude-shell ~/code/claude-shell
cd ~/code/claude-shell
./install.fish
```

`install.fish` symlinks into `~/.claude/` and `~/.config/fish/functions/`,
creates `~/shell/`, then runs 60+ verification checks. Symlinks rather than
copies, so repo edits take effect immediately and `git status` stays honest.
Re-running is safe.

```fish
./install.fish            # link, then verify
./install.fish --check    # verify only, changes nothing
./install.fish --link     # link only, skip verification
./install.fish --help
```

Exit codes: `0` clean, `1` any failure, `2` bad flag. Warnings don't fail.

Then, once:

```fish
paru -S glow              # if you want aim
sudo pacman -Fy           # files database, needed for auto-install
cd ~/shell && claude      # accept the trust prompt
```

Fish autoloads from `functions/`, so no `source` and no shell restart.

## What's in here

```
claude-shell/
├── install.fish            # symlink + verify
├── bench.fish              # latency comparison across configs
├── TESTING.md              # manual/interactive test plan
├── claude/
│   ├── CLAUDE.md           → ~/.claude/CLAUDE.md
│   └── settings.json       → ~/.claude/settings.json
└── fish/functions/         → ~/.config/fish/functions/
    ├── ai.fish             # one-shot, plain text
    ├── aim.fish            # one-shot, markdown-rendered
    ├── aix.fish            # generate → install → confirm → run
    ├── explain.fish        # describe a command before running it
    ├── cs.fish             # interactive session in ~/shell
    ├── _ai_opts.fish       # shared claude flags (model, bare, no tools)
    ├── _ai_clean.fish      # strips markdown fences
    ├── _ai_validate.fish   # is this actually a runnable command?
    ├── _ai_binaries.fish   # extract command names from a snippet
    ├── _ai_shadowed.fish   # detect alias/function shadowing
    ├── _ai_install.fish    # resolve binary → package, install
    └── _ai_save.fish       # save a snippet to ~/.local/bin
```

`claude/CLAUDE.md` lives at **user level**, not in `~/shell`, because project
memory is read from the current working directory and `ai` runs from wherever
you happen to be standing.

`claude/settings.json` holds a permission allow list for read-only commands and
a deny list covering `~/.ssh`, `~/.aws`, `.env` files, and `op read`.

## Usage

### `aix` — generate, install, run

The main event. Generates a command, resolves and installs any missing binary,
then asks what to do with it.

```fish
aix "show the 10 largest directories under /var, human-readable"
aix "list the 5 most recently modified files here with timestamps"
aix "convert all pngs in this folder to webp at 80% quality"
aix "show which process is listening on port 3000"
aix "strip GPS data from every jpg in this directory"
```

Flow: generate → validate → show → install missing deps → prompt.

```
[r]un  [e]dit  [s]ave as script  [N]o?
```

`e` opens `$EDITOR`, then re-validates before running — use it when the command
is 90% right, which is often.

When a value must vary between runs, the model emits a parameterised script
instead, and `aix` saves it to `~/.local/bin`:

```fish
aix "tail the last N lines of a systemd unit's log, unit and N as arguments"
# → Script name: unitlog
# → unitlog sshd 50
```

A value given *in* the request (a URL, a path) gets embedded directly rather
than turned into a parameter.

### `ai` — paste-ready answers

Plain text, no fences, command on its own lines. For when you want to read or
copy rather than run.

```fish
ai "fish syntax to loop over files matching a glob"
ai "git command to move the last 3 commits to a new branch"
ai "zig build flags for a release-safe static binary"
```

Anything on stdin is appended under an `--- input ---` header:

```fish
git diff --cached | ai "review this, flag bugs only"
journalctl -u sidekiq -n 200 --no-pager | ai "what is failing"
kamal app logs --lines 200 | ai "summarise the errors by frequency"
bundle exec rspec 2>&1 | ai "why did this fail"
```

### `aim` — explanations, rendered

Same path as `ai`, through `glow`. For answers you intend to read.

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

In-session: `/add-dir ~/code/some-repo` for access to a real project, `/config`,
`/help`.

Reach for `cs` over `aix` when the task spans several commands, needs to react
to output, or needs Claude to actually look at things.

## Tuning

Set env vars; no file editing:

```fish
set -Ux AIX_MODEL haiku    # smaller model — command generation is short output
set -Ux AIX_BARE 1         # skip startup discovery of hooks/skills/MCP/memory
set -e AIX_MODEL           # revert
```

`_ai_opts` builds the flag list that all four print-mode functions share, so a
change applies everywhere.

To find out whether either helps:

```fish
./bench.fish -n 5 --verify
```

Compares sonnet, sonnet+bare, haiku, haiku+bare with median/min/max, and runs
each result through `_ai_validate`. Exits non-zero if any config produces
something that isn't a valid command. Costs roughly 20 short API calls.

Reading it: `--bare` much faster means startup discovery dominates (MCP servers
are the usual cause). `haiku` much faster means generation dominates. Neither
helping means you're network-bound.

The `--verify` column is the point. A config that is three times faster and
emits prose a fifth of the time is worse than what you had.

## The guards, and why each exists

Every one of these was added after a real failure, and every one replaced a
failed attempt to fix the same thing by rewording a prompt.

| Guard | Failure it prevents |
| --- | --- |
| `_ai_clean` | ` ```fish ` fences arriving as terminal output, language tag on its own line |
| `_ai_validate` — question check | `What's the URL?` reaching `eval` and crashing on the unbalanced quote |
| `_ai_validate` — first-token check | `Please go ahead and share the URL` → tried to install a package called `Please` |
| `_ai_validate` — path/extension check | `db/schema.rb` → tried to install `schema.rb` |
| `_ai_validate` — `fish --no-execute` | any unbalanced-quote output crashing `eval` |
| `_ai_shadowed` | generated `ls -t` hitting an eza wrapper whose `-t` means `--time FIELD` |
| `command` prefixes throughout | our own `_ai_clean` breaking because `cat` was wrapped by bat |
| `#!SCRIPT` requires `$argv` | script mode firing for `list files here`, which has no parameters |
| `_ai_save` name rules | saving a script called `r`, shadowing R, three characters from disaster |
| `--tools ""` | the model attempting WebFetch instead of writing a command |
| `--system-prompt` (not append) | "I don't have tools to access YouTube" instead of `yt-dlp -F` |
| doubled-`command` lint | `command sudo command pacman` → `sudo: command: command not found` |

## Notes

**Claude Code shells out to bash, not fish.** Your functions, abbreviations and
`conf.d` setup don't exist as far as the agent is concerned. `CLAUDE.md` spells
out `mise exec --` explicitly for this reason — bare `ruby` or `zig` may resolve
to the wrong version, or nothing.

**`aix` runs with your full permissions, in your current directory, unsandboxed.**
There is a confirmation prompt, and the command behind it came from a model that
invented a fish variable called `fish_globopt` during development. Read the
yellow text. `e` exists for a reason.

**`aix` replaces the system prompt**, which per the CLI docs also drops Claude
Code's default safety guidance. `_ai_validate`, the `CANNOT` rule and the run
confirmation are what stand in for it. `ai`/`aim`/`explain` still append, since
the coding-assistant framing helps there.

**Install failures are usually a stale package database.** `pacman -Fy` syncs
only the *files* databases; the package databases can be weeks behind, and then
every mirror 404s on a version that no longer exists. `_ai_install` detects this
and offers `pacman -Syu`. It will not do a partial upgrade, because Arch doesn't
support them.

**Verify in the terminal, not in a paste.** Several rounds of development here
were spent debugging collapsed newlines and a capitalised keyword that turned
out to be clipboard artifacts. `ai "..." | cat -n` settles it.

## Known limitations

- `_ai_binaries` only inspects the leading word of each pipeline segment. In
  `xargs -I{} stat -c ...` it sees `xargs`, not `stat`. Same for `sh -c`,
  `find -exec`, and anything past the first `sudo` hop. Those aren't
  dependency-checked or shadow-checked.
- `[c]lean run` uses a child fish, so `cd` does not persist. Use `r` for
  directory changes.
- With tools disabled, `aix` can only write commands from knowledge. It can't
  inspect your filesystem — asking where a file is produces a `find` command,
  which is the point. Use `cs` when you want Claude to actually look.
- The model can only suggest tools it knows. A plausible-but-nonexistent tool
  name will reach `paru` and fail there.
- `_ai_validate` catches structural failures, not semantic ones. A syntactically
  perfect command with the wrong flag passes every check.

## Testing

`TESTING.md` has the full plan — offline unit tests, then API-calling tests,
then safety checks — with expected output for each. `install.fish --check`
automates everything that can be automated.

## License

MIT
