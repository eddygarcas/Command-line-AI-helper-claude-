#!/usr/bin/env fish
#
# claude-shell installer.
#
#   ./install.fish            symlink everything, then verify
#   ./install.fish --check    verify only, change nothing
#   ./install.fish --link     symlink only, skip verification
#   ./install.fish --help
#
# Exits non-zero if any check fails, so it is safe to use in CI.

set -g REPO (realpath (dirname (status --current-filename)))
set -g PASS 0
set -g WARN 0
set -g FAIL 0

set -g FUNCS ai aim aix explain cs _ai_clean _ai_binaries _ai_install _ai_save _ai_shadowed

# ---------------------------------------------------------------- helpers

function _ok
    set_color green; printf '  ok   '; set_color normal; echo $argv
    set -g PASS (math $PASS + 1)
end

function _warn
    set_color yellow; printf '  warn '; set_color normal; echo $argv
    set -g WARN (math $WARN + 1)
end

function _fail
    set_color red; printf '  FAIL '; set_color normal; echo $argv
    set -g FAIL (math $FAIL + 1)
end

function _section
    echo
    set_color --bold cyan; echo $argv; set_color normal
end

function _usage
    echo "usage: ./install.fish [--check|--link|--help]"
    echo
    echo "  (no flags)   symlink files into place, then verify"
    echo "  --check      verify only, make no changes"
    echo "  --link       symlink only, skip verification"
end

# ---------------------------------------------------------------- linking

function _do_link
    _section "Linking"

    mkdir -p ~/.claude ~/.config/fish/functions ~/shell

    for f in CLAUDE.md settings.json
        if test -f $REPO/claude/$f
            ln -sf $REPO/claude/$f ~/.claude/$f
            _ok "~/.claude/$f"
        else
            _fail "missing in repo: claude/$f"
        end
    end

    for f in $REPO/fish/functions/*.fish
        ln -sf $f ~/.config/fish/functions/(basename $f)
        _ok "~/.config/fish/functions/"(basename $f)
    end
end

# ---------------------------------------------------------------- checks

function _check_prereqs
    _section "Prerequisites"

    set -l v (string split '.' -- (string match -r '[0-9.]+' -- (fish --version)))
    if test $v[1] -gt 3
        _ok "fish "(string join '.' $v)
    else if test $v[1] -eq 3; and test $v[2] -ge 7
        _ok "fish "(string join '.' $v)" (4.x recommended)"
    else
        _fail "fish "(string join '.' $v)" is too old; need 3.7+"
    end

    if type -q claude
        _ok "claude on PATH: "(type -p claude)
    else
        _fail "claude not on PATH -- see https://code.claude.com/docs/en/setup"
    end

    if type -q glow
        _ok "glow present"
    else
        _warn "glow missing; 'aim' will not work (paru -S glow)"
    end

    if type -q pacman
        _ok "pacman present"
    else
        _warn "pacman missing; aix cannot auto-install dependencies"
    end

    if contains -- (realpath ~/.local/bin 2>/dev/null; or echo ~/.local/bin) $PATH
        _ok "~/.local/bin on PATH"
    else
        _warn "~/.local/bin not on PATH; saved scripts will not be callable"
        echo "         fix: fish_add_path ~/.local/bin"
    end
end

function _check_links
    _section "Symlinks"

    for f in CLAUDE.md settings.json
        set -l target ~/.claude/$f
        if not test -e $target
            _fail "~/.claude/$f missing"
            continue
        end
        set -l resolved (realpath $target)
        if string match -q "$REPO/*" -- $resolved
            _ok "~/.claude/$f -> "(string replace $REPO '<repo>' $resolved)
        else
            _warn "~/.claude/$f is not linked to this repo ($resolved)"
        end
    end

    # Case matters: Claude Code looks for CLAUDE.md exactly.
    if test -e ~/.claude/CLAUDE.md
        _ok "CLAUDE.md filename case correct"
    else if test -e ~/.claude/CLAUDE.MD -o -e ~/.claude/claude.md
        _fail "CLAUDE.md has wrong case; Claude Code will ignore it"
    end

    for f in $FUNCS
        if test -e ~/.config/fish/functions/$f.fish
            _ok "$f.fish linked"
        else
            _fail "$f.fish not installed"
        end
    end
end

function _check_syntax
    _section "Syntax"

    for f in $REPO/fish/functions/*.fish $REPO/install.fish
        if fish --no-execute $f >/dev/null 2>&1
            _ok (basename $f)
        else
            _fail (basename $f)" -- run: fish --no-execute $f"
        end
    end

    if type -q python3
        if python3 -c "import json,sys; json.load(open('$REPO/claude/settings.json'))" 2>/dev/null
            _ok "settings.json is valid JSON"
        else
            _fail "settings.json is not valid JSON"
        end
    else
        _warn "python3 missing; skipped JSON validation"
    end
end

function _check_units
    _section "Unit tests"

    # Source from the repo so we test what is committed, not a stale link.
    for f in _ai_binaries _ai_clean _ai_shadowed
        source $REPO/fish/functions/$f.fish 2>/dev/null
    end

    # Binary extraction: sudo, flags, env, VAR=value must all be skipped.
    set -l got (_ai_binaries 'sudo -E env FOO=1 kubectl get pods | jq .items[0]')
    if test "$got" = "kubectl jq"
        _ok "_ai_binaries skips sudo/env/assignments"
    else
        _fail "_ai_binaries returned '$got', expected 'kubectl jq'"
    end

    # Builtins and keywords must never be treated as packages.
    set -l got (_ai_binaries 'for f in *.txt
    echo $f
end')
    if test -z "$got"
        _ok "_ai_binaries ignores fish builtins"
    else
        _fail "_ai_binaries returned '$got' for a builtin-only snippet"
    end

    set -l got (_ai_binaries '/usr/local/bin/mytool --flag')
    if test "$got" = "mytool"
        _ok "_ai_binaries strips leading paths"
    else
        _fail "_ai_binaries returned '$got', expected 'mytool'"
    end

    # Fence stripping, including the language tag on its own line.
    set -l cleaned (printf '```fish\nfor f in *.txt\n    echo $f\nend\n```\n' | _ai_clean)
    if test "$cleaned[1]" = "for f in *.txt"; and not string match -q '*```*' -- "$cleaned"
        _ok "_ai_clean removes fences and language tags"
    else
        _fail "_ai_clean left fence artifacts: first line was '$cleaned[1]'"
    end

    # Shadow detection.
    function __cs_probe
    end
    set -l got (_ai_shadowed __cs_probe definitely-not-a-real-command)
    functions --erase __cs_probe
    if test "$got" = "__cs_probe"
        _ok "_ai_shadowed detects fish functions"
    else
        _fail "_ai_shadowed returned '$got', expected '__cs_probe'"
    end

    # The prose guard must be in the INSTALLED aix, not just the repo.
    if test -e ~/.config/fish/functions/aix.fish
        if grep -q 'returned prose' ~/.config/fish/functions/aix.fish
            _ok "aix prose guard present in installed copy"
        else
            _fail "installed aix.fish predates the prose guard"
        end
        if grep -q '_ai_shadowed' ~/.config/fish/functions/aix.fish
            _ok "aix shadow detection present in installed copy"
        else
            _fail "installed aix.fish predates shadow detection"
        end
    end
end

function _check_pacman_db
    type -q pacman; or return 0

    _section "Pacman files database"

    set -l repos
    type -q pacman-conf; and set repos (pacman-conf --repo-list 2>/dev/null)
    test (count $repos) -eq 0; and set repos core extra multilib

    set -l missing
    for r in $repos
        test -f /var/lib/pacman/sync/$r.files; or set -a missing $r
    end

    if test (count $missing) -eq 0
        _ok "files database synced for all "(count $repos)" repos"

        # Prove resolution works on a binary whose package name differs.
        set -l hits (pacman -Fq usr/bin/rg 2>/dev/null)
        if test (count $hits) -gt 0
            _ok "binary->package resolution works (rg -> $hits[1])"
        else
            _warn "pacman -Fq found nothing for usr/bin/rg; resolution may be unreliable"
        end
    else
        _warn "files database not synced for: $missing"
        echo "         aix cannot resolve packages until you run: sudo pacman -Fy"
    end
end

function _check_claude
    type -q claude; or return 0

    _section "Claude Code"

    if test -f ~/.claude.json
        _ok "~/.claude.json exists (trust decisions persist)"
        if test -w ~/.claude.json
            _ok "~/.claude.json writable"
        else
            _fail "~/.claude.json not writable; trust prompt will reappear every session"
        end
    else
        _warn "no ~/.claude.json yet; run 'cd ~/shell && claude' once to accept trust"
    end

    if test -d ~/shell
        _ok "~/shell workspace exists"
    else
        _warn "~/shell missing; 'cs' will create it on first run"
    end
end

# ---------------------------------------------------------------- main

set -l mode both
switch "$argv[1]"
    case --check
        set mode check
    case --link
        set mode link
    case -h --help
        _usage
        exit 0
    case ''
        set mode both
    case '*'
        echo "unknown option: $argv[1]" >&2
        _usage
        exit 2
end

set_color --bold; echo "claude-shell  ($REPO)"; set_color normal

if contains -- $mode both link
    _do_link
end

if contains -- $mode both check
    _check_prereqs
    _check_links
    _check_syntax
    _check_units
    _check_pacman_db
    _check_claude
end

echo
set -l rc 0
if test $FAIL -gt 0
    set rc 1
    set_color --bold red
    echo "$FAIL failed, $WARN warnings, $PASS passed"
    set_color normal
    echo "See TESTING.md for the interactive tests that cannot be automated."
else if test $WARN -gt 0
    set_color --bold yellow
    echo "$PASS passed, $WARN warnings"
    set_color normal
else
    set_color --bold green
    echo "$PASS passed"
    set_color normal
end

if contains -- $mode both link
    echo
    echo "Next steps:"
    type -q claude; or echo "  install Claude Code   # https://code.claude.com/docs/en/setup"
    type -q glow; or echo "  paru -S glow          # required by aim"
    echo "  cd ~/shell && claude  # accept the trust prompt once"
    echo "  see TESTING.md        # interactive tests"
end

exit $rc
