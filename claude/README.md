# Claude Code terminal helpers

Fish functions wrapping Claude Code as a command-line assistant on CachyOS.

`ai` and friends run in print mode (`claude -p`), which is stateless, has no
repo context, and skips the workspace trust prompt entirely. `cs` is the
opposite: a real interactive session in the one directory that is trusted.

## Layout

| Path | Purpose |
| --- | --- |
| `~/.claude/CLAUDE.md` | Environment context; applies to every session regardless of cwd |
| `~/.claude/settings.json` | Permission allow/deny lists, update channel |
| `~/shell/` | The only trusted directory; workspace for `cs` |
| `~/.config/fish/functions/ai.fish` | One-shot, plain-text output |
| `~/.config/fish/functions/aim.fish` | One-shot, markdown-rendered via `glow` |
| `~/.config/fish/functions/explain.fish` | Explain a command before running it |
| `~/.config/fish/functions/cs.fish` | Interactive session in `~/shell` |
| `~/.config/fish/functions/_ai_clean.fish` | Strips markdown fences from output |

Fish autoloads from `functions/`, so no `source` and no shell restart.

---

## `ai` — paste-ready answers

Plain text, no fences, command on its own lines. Use when the answer is
something you are about to run.

### Direct queries

```fish
ai "fish syntax to loop over files matching a glob"
ai "systemd unit to run a script every 30 minutes"
ai "pacman command to list orphaned packages"
ai "git command to move the last 3 commits to a new branch"
ai "zig build flags for a release-safe static binary"
ai "psql to show the 10 largest tables with index sizes"
ai "wg command to show handshake times for all peers"
ai "find files over 100MB modified in the last week"
```

### Piped input

Anything on stdin gets appended under an `--- input ---` header, so the
question and the data both arrive in one turn.

```fish
# code review
git diff --cached | ai "review this, flag bugs only"
git log --oneline -20 | ai "draft a release note from these"

# log triage
journalctl -u sidekiq -n 200 --no-pager | ai "what is failing"
kamal app logs --lines 200 | ai "summarise the errors by frequency"
tail -100 log/production.log | ai "any N+1 queries here"

# config and output inspection
ai "which of these rules is too permissive" < firewall.json
doctl compute droplet list | ai "which of these are undersized"
bundle exec rspec 2>&1 | ai "why did this fail"
cat Gemfile.lock | ai "any gems with known CVEs"

# structured data
psql -c "\d+ devices" | ai "suggest missing indexes for tenant-scoped queries"
kubectl get events --sort-by=.lastTimestamp | ai "what changed"
```

### Verifying output shape

When output looks wrong, check the terminal directly rather than a copy —
clipboards mangle whitespace and capitalization.

```fish
ai "some query" | cat -n        # confirm line breaks survived
ai "some query" | head -1 | cat -A   # confirm exact first-line bytes
```

---

## `aim` — explanations, rendered

Same query path as `ai`, piped through `glow`. Use when you intend to read
the answer rather than run it. Requires `paru -S glow`.

```fish
aim "how does Rails cache_key_with_version interact with ActsAsTenant"
aim "difference between Zig's ArenaAllocator and FixedBufferAllocator"
aim "explain WPA3 SAE handshake failure modes"
aim "tradeoffs of Kamal vs App Platform for a Rails deploy"

# with input
cat lib/vpn/metrics/collector.rb | aim "review the error handling design"
git diff main...HEAD | aim "write a PR description"
```

---

## `explain` — before you run it

Wraps the command in a request for what it does and what is risky about it.
For anything copied off the internet.

```fish
explain "git filter-repo --invert-paths --path config/secrets.yml"
explain "pacman -Rns (pacman -Qtdq)"
explain "dd if=/dev/zero of=/dev/sdb bs=4M status=progress"
explain "find . -name '*.log' -mtime +30 -delete"
explain "sysctl -w net.ipv4.tcp_tw_reuse=1"
explain "kamal app exec --reuse 'bin/rails db:migrate'"
```

---

## `cs` — interactive session

Drops into `~/shell` and starts a full Claude Code session, then returns you
to where you were. Multi-turn, keeps context, can iterate on a command until
it works.

```fish
cs                                  # new session
cs --continue                       # resume the most recent one
cs --resume                         # pick from a list
```

Useful in-session commands:

```
/add-dir ~/code/rzilient-backend    # give it access to a real repo
/help                               # available slash commands
/config                             # settings, including update channel
```

Reach for `cs` over `ai` when the task spans several commands, needs to react
to output, or involves editing files.

---

## Notes

**`~/.claude/CLAUDE.md` must be at user level, not in `~/shell`.** Project
memory is read from the current working directory. Since `ai` runs from
wherever you happen to be standing, anything in `~/shell/CLAUDE.md` is
invisible to it.

**Claude Code shells out to bash, not fish.** Your functions, abbreviations,
and `conf.d` setup do not exist as far as the agent is concerned. This is why
`CLAUDE.md` spells out `mise exec --` explicitly — bare `ruby` or `zig` may
resolve to the wrong version or nothing at all.

**Format guarantees belong in the pipeline, not the prompt.** Four rounds of
telling the model not to emit markdown fences did not stop it. One `sed` line
in `_ai_clean` did. Style strings shape tendencies; filters enforce invariants.

**Trust is per-directory and one-time.** It gates project-scoped config
(`.claude/settings.json`, `.mcp.json`, hooks), not command execution — those
are approved separately. `~/shell` is trusted precisely because it contains
nothing. Note that `--dangerously-skip-permissions` does *not* bypass the
trust prompt.

**Verify anything load-bearing.** Shell trivia is exactly the category where a
plausible-sounding flag or variable turns out not to exist. `man` and `--help`
are cheaper than a wrong command.
