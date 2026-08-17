# Testing claude-shell

Run these in order after `./install.fish`. Sections 1–3 cost nothing and make
no API calls. Section 4 onward calls the API.

Each test states what a pass looks like. If a test fails, stop there — later
tests build on earlier ones.

---

## 1. Prerequisites

```fish
fish --version                    # expect 4.x (3.7+ works)
type -q claude; and echo "claude: OK"; or echo "claude: MISSING"
type -q glow; and echo "glow: OK"; or echo "glow: MISSING (aim only)"
claude doctor
```

**Pass:** fish 3.7 or later, `claude` present, `claude doctor` reports no errors.
`glow` missing is fine unless you want `aim`.

```fish
for f in ai aim aix explain cs _ai_clean _ai_binaries _ai_install _ai_save _ai_shadowed
    functions -q $f; and echo "OK   $f"; or echo "MISSING $f"
end
```

**Pass:** all ten present. Anything missing means `install.fish` did not
symlink it — check `ls -la ~/.config/fish/functions/`.

```fish
readlink -f ~/.claude/CLAUDE.md
```

**Pass:** resolves into your clone, and the filename is lowercase `.md`. An
uppercase `CLAUDE.MD` is silently ignored by Claude Code.

---

## 2. Syntax and config

```fish
for f in ~/code/claude-shell/fish/functions/*.fish ~/code/claude-shell/install.fish
    fish --no-execute $f >/dev/null 2>&1; and echo "OK   "(basename $f); or echo "FAIL "(basename $f)
end

python3 -c "import json; json.load(open('$HOME/code/claude-shell/claude/settings.json')); print('OK   settings.json')"
```

**Pass:** every file OK, JSON valid.

---

## 3. Offline unit tests

### Binary extraction

```fish
_ai_binaries 'sudo -E env FOO=1 kubectl get pods | jq .items[0]'
```
**Pass:** exactly `kubectl` and `jq`. This is the hard case — sudo, a flag,
`env`, and a `VAR=value` pair all skipped.

```fish
_ai_binaries 'for f in *.txt
    echo $f
end'
```
**Pass:** no output at all. A false positive here makes `aix` try to install
`for` or `echo`.

```fish
_ai_binaries '/usr/local/bin/mytool --flag'
```
**Pass:** `mytool` — leading path stripped.

### Output cleaning

```fish
printf '```fish\nfor f in *.txt\n    echo $f\nend\n```\n\nUse `ls` to check.\n' | _ai_clean
```
**Pass:** five lines — the three-line loop, one blank, then `Use ls to check.`
No fence lines, no `fish` language tag on its own line, no backticks. Pipe
through `cat -n` if you want to count them.

### Alias shadow detection

```fish
function __test_ls; end
_ai_shadowed ls find sort head
functions --erase __test_ls
```
**Pass:** prints `ls` only if you actually wrap `ls` (eza users will; others
will get nothing). To force a positive:

```fish
function ls; end
_ai_shadowed ls find sort
functions --erase ls
```
**Pass:** prints `ls`.

### Pacman files database

```fish
sudo pacman -Fy
pacman -Fq usr/bin/rg
```
**Pass:** one or more `repo/package` lines, e.g. `extra/ripgrep`. On CachyOS
expect two hits including a znver4 variant. If you get "database file does not
exist" warnings, the `-Fy` did not complete.

---

## 4. `ai` — composing

```fish
ai "command to show total disk usage of the current directory"
```
**Pass:** a plain command, no markdown fences, no backticks, at most one
sentence of explanation.

```fish
ai "command to show total disk usage" | cat -n
```
**Pass:** line 1 is the command itself, not a language tag like `fish`.

```fish
git log --oneline -5 | ai "summarise these commits in one line"
```
**Pass:** a summary reflecting your actual commits. Confirms stdin is reaching
the model.

---

## 5. `explain` and `aim`

```fish
explain "find . -name '*.log' -mtime +30 -delete"
```
**Pass:** describes what it does and flags that it deletes files.

```fish
aim "difference between hard and soft links"
```
**Pass:** rendered markdown via glow. Skip if glow is not installed.

---

## 6. `aix` — the run path

### 6a. Decline

```fish
aix "show the 10 largest directories under /var with human-readable sizes"
```
Answer **N**.

**Pass:** command shown in bold yellow; a `du`-based pipeline (not prose); no
install prompt; `Not run.` on declining.

**Fail modes to watch for:**
- English sentences instead of a command → the prose guard should have caught
  it and printed `model returned prose`. If prose got through, report it.
- An install prompt for a word that isn't a real command (`pkg`, `the`) → prose
  leaked past the guard into `_ai_binaries`.

### 6b. Run something read-only

```fish
cd /tmp
aix "list the 5 most recently modified files in this directory with timestamps"
```
Answer **r**.

**Pass:** a `find -printf` or `stat` based command (it should NOT parse `ls`
output), and correct results.

### 6c. Directory change persists

```fish
aix "change to the /tmp directory"
```
Answer **r**, then `pwd`.

**Pass:** you are in `/tmp`. This proves `eval` runs in your shell rather than
a subprocess. If nothing happens, execution context is wrong.

### 6d. Alias shadowing

Force the case even if you don't wrap `ls`:

```fish
function ls; command eza $argv; end   # or any wrapper
aix "list files sorted by modification time, newest first"
```

**Pass:** a warning listing `ls` under "Shadowed by your fish functions", and a
menu that now includes `[c]lean run`. Press **c**.

**Pass:** the command runs against the real binary and succeeds. Then:

```fish
functions --erase ls
```

### 6e. Script mode

```fish
aix "tail the last N lines of a systemd unit's log, unit and N as arguments"
```

**Pass:** skips the run menu, prints `Parameterised — saving as a script`, asks
for a name. Enter `unitlog`. Then:

```fish
cat ~/.local/bin/unitlog          # shebang, date, original prompt, then command
fish --no-execute ~/.local/bin/unitlog; and echo "valid fish"
unitlog sshd 20
```

**Pass:** valid fish, and running it works.

### 6f. Script mode is NOT over-triggered

```fish
aix "show the current kernel version"
```

**Pass:** offers the normal run menu. It must NOT go to script mode — nothing
here varies between runs. If you see `ignoring #!SCRIPT (no $argv)`, the gate
caught an over-eager model; that is a pass, not a failure.

---

## 7. Safety checks

### Short and colliding script names

```fish
aix "print the current date in ISO format"
```
Answer **s**, then try each name:

| Name | Expected |
| --- | --- |
| `r` | rejected, too short |
| `ab` | rejected, too short |
| `ls` | rejected, too short |
| `find` | "already resolves to /usr/bin/find" + shadow confirm |
| `isodate` | accepted |

**Pass:** short names refused outright; existing commands trigger the shadow
warning before overwriting.

### Deny list

Start a session and confirm the permission denies hold:

```fish
cs
```

Then in the session ask it to read `~/.ssh/config` or run `op read`.

**Pass:** refused by policy, not attempted.

### Prose guard directly

```fish
functions aix | grep -c 'returned prose'
```
**Pass:** returns `1` — the guard is present in the installed copy, not just in
the repo. `0` means the symlink points at an older version.

---

## 8. Cleanup

```fish
rm -f ~/.local/bin/unitlog ~/.local/bin/isodate
functions --erase ls 2>/dev/null
```

---

## Troubleshooting

| Symptom | Cause |
| --- | --- |
| `ai` output has a bare `fish` line | `_ai_clean` not in the pipeline; check the symlink |
| `aix` tries to install `pkg`, `the`, `worth` | prose leaked past the guard; report the raw output |
| `aix` command fails on flags | alias shadowing; use `[c]lean run` |
| `cd` via `aix` does nothing | `eval` replaced with a subshell somewhere |
| install prompt says "files database not synced" every time | `pacman -Fy` failing, or `/var/lib/pacman/sync` not writable |
| `pacman -Fq` finds nothing for a real command | binary lives outside `usr/bin` and `usr/sbin` |
| Claude Code ignores `CLAUDE.md` | filename case wrong, or it is in `~/shell` instead of `~/.claude/` |
| Trust prompt reappears every session | `~/.claude.json` not writable |

## Known limitations

- `_ai_binaries` only inspects the leading word of each pipeline segment. In
  `xargs -I{} stat -c ...` it sees `xargs`, not `stat`. Same for `sh -c`,
  `find -exec`, and anything past the first `sudo` hop. Those commands are not
  dependency-checked or shadow-checked.
- `[c]lean run` uses a child fish, so `cd` does not persist. Use `r` when you
  need a directory change.
- `aix` runs with your full user permissions in your current directory. There
  is no sandbox. Check `pwd` before pressing `r` on anything that writes.
