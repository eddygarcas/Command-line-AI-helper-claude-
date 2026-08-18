#!/usr/bin/env fish
#
# Benchmark claude -p configurations to find where aix latency actually goes.
#
#   ./bench.fish              3 runs per config
#   ./bench.fish -n 5         5 runs per config
#   ./bench.fish --verify     also check each config still produces a valid command
#
# Costs real API calls: roughly (configs x runs) short requests.

set -g RUNS 3
set -g VERIFY 0

set -l i 1
while test $i -le (count $argv)
    switch $argv[$i]
        case -n --runs
            set i (math $i + 1)
            set RUNS $argv[$i]
        case --verify
            set VERIFY 1
        case -h --help
            echo "usage: ./bench.fish [-n RUNS] [--verify]"
            exit 0
        case '*'
            echo "unknown option: $argv[$i]" >&2
            exit 2
    end
    set i (math $i + 1)
end

if not type -q claude
    echo "bench: claude not on PATH" >&2
    exit 1
end

if not string match -qr '^[0-9]+$' -- $RUNS; or test $RUNS -lt 1
    echo "bench: -n must be a positive integer" >&2
    exit 2
end

# --verify needs the validator. Autoload only sees ~/.config/fish/functions,
# and we want to test the repo copy, so source it explicitly.
if test $VERIFY -eq 1; and not functions -q _ai_validate
    set -l repo (realpath (dirname (status --current-filename)))
    if test -f $repo/fish/functions/_ai_validate.fish
        source $repo/fish/functions/_ai_validate.fish
    else
        echo "bench: _ai_validate.fish not found; --verify will only print output" >&2
    end
end

# A representative aix request: short, structured output.
set -g PROMPT "show the 10 largest directories under /var with human-readable sizes"
set -g STYLE "You are a shell command generator. Output ONLY the command, no prose,
no markdown, no fences. One command or pipeline. Use fish syntax. Assume GNU
coreutils. Never explain. Never ask questions."

# Config name, then the flags. Each entry is a name plus a flag string that gets
# split on spaces -- so no flag values containing spaces here.
set -g NAMES \
    "sonnet (default)" \
    "sonnet --bare" \
    "haiku" \
    "haiku --bare"

set -g FLAGSETS \
    "" \
    "--bare" \
    "--model haiku" \
    "--model haiku --bare"

function _median
    set -l sorted (printf '%s\n' $argv | command sort -n)
    set -l n (count $sorted)
    if test (math "$n % 2") -eq 1
        echo $sorted[(math "($n + 1) / 2")]
    else
        set -l a $sorted[(math "$n / 2")]
        set -l b $sorted[(math "$n / 2 + 1")]
        math "($a + $b) / 2"
    end
end

function _run_one --description 'One timed call; echoes "millis<TAB>output"'
    set -l extra $argv
    set -l start (command date +%s%3N)
    set -l out (command claude -p "$PROMPT" \
        --tools "" --disallowedTools "mcp__*" --max-turns 1 \
        $extra --system-prompt "$STYLE" 2>/dev/null | command tr '\n' ' ')
    set -l stop (command date +%s%3N)
    printf '%s\t%s\n' (math "$stop - $start") "$out"
end

set_color --bold
echo "claude -p benchmark  ($RUNS runs per config)"
set_color normal
echo "prompt: $PROMPT"
echo

printf '%-22s %8s %8s %8s\n' CONFIG MEDIAN MIN MAX
echo "-------------------------------------------------------"

set -g FAILED 0

for idx in (seq (count $NAMES))
    set -l name $NAMES[$idx]
    set -l flags (string split -n ' ' -- $FLAGSETS[$idx])

    set -l times
    set -l lastout ""
    set -l errored 0

    for r in (seq $RUNS)
        set -l res (_run_one $flags)
        set -l ms (string split \t -- $res)[1]
        set -l out (string split \t -- $res)[2..-1]
        set -l out (string join ' ' -- $out)

        if test -z "$out"
            set errored 1
        end
        set -a times $ms
        set lastout "$out"
    end

    if test $errored -eq 1
        printf '%-22s %8s\n' "$name" "ERROR"
        set FAILED 1
        continue
    end

    set -l sorted (printf '%s\n' $times | command sort -n)
    printf '%-22s %8s %8s %8s\n' \
        "$name" (_median $times)"ms" $sorted[1]"ms" $sorted[-1]"ms"

    if test $VERIFY -eq 1
        set -l trimmed (string trim -- $lastout)
        if functions -q _ai_validate
            set -l reason (_ai_validate "$trimmed")
            if test $status -eq 0
                set_color green
                echo "                       valid: $trimmed"
                set_color normal
            else
                set_color red
                echo "                       INVALID ($reason): $trimmed"
                set_color normal
                set FAILED 1
            end
        else
            echo "                       output: $trimmed"
        end
    end
end

echo
echo "Interpreting this:"
echo "  --bare much faster  -> startup discovery dominates; set -Ux AIX_BARE 1"
echo "  haiku much faster   -> generation dominates; set -Ux AIX_MODEL haiku"
echo "  neither helps       -> network latency; a local model may be worth trying"
echo
echo "Always check --verify output before switching. A faster config that"
echo "produces wrong flags costs more than the seconds it saves."

exit $FAILED
