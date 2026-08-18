function _ai_validate --argument-names cmd --description 'Check a string is a runnable fish command; echoes a reason and returns 1 if not'
    if test -z (string trim -- "$cmd" | string collect)
        echo "empty output"
        return 1
    end

    # 1. Questions are never commands. This is the common failure: an
    #    underspecified prompt makes the model ask for the missing detail.
    if string match -qr '\?\s*$' -- $cmd
        echo "the model asked a question instead of answering"
        return 1
    end

    # 2. First token must look like a command name. Commands are lowercase or
    #    a path; prose starts with a capital ('Please', 'Go', 'What'), and
    #    contractions carry an apostrophe that also breaks parsing.
    set -l firstline (string split \n -- $cmd)[1]
    set -l first (string split -n ' ' -- (string trim -- $firstline))[1]
    if not string match -qr '^[a-z_./~][A-Za-z0-9_.+/-]*$' -- $first
        echo "first word '$first' is not a command name"
        return 1
    end

    # 2b. A bare path is an answer, not a command. If the first token looks
    #     like a filesystem path it must actually be executable -- otherwise
    #     the model answered the question ('db/schema.rb') instead of giving
    #     a command that produces the answer.
    set -l probe (string replace -r '^~' "$HOME" -- $first)
    if string match -q '*/*' -- $first
        if not test -e $probe
            echo "'$first' does not exist; the model answered with a path, not a command"
            return 1
        else if not test -x $probe
            echo "'$first' is a file, not an executable; the model answered the question instead of giving a command"
            return 1
        end
    end

    # 2c. Data-file extensions are never command names.
    if string match -qr '\.(rb|py|rs|go|zig|js|ts|jsx|tsx|json|ya?ml|md|txt|log|csv|tsv|sql|lock|toml|ini|conf|cfg|xml|html|css|scss|erb|env)$' -- $first
        echo "'$first' looks like a filename, not a command"
        return 1
    end

    # 3. It must actually parse as fish. This catches unbalanced quotes, which
    #    would otherwise crash eval, and most free-form prose.
    set -l tmp (command mktemp /tmp/aixchk.XXXXXX.fish)
    printf '%s\n' $cmd >$tmp
    if not command fish --no-execute $tmp 2>/dev/null
        command rm -f $tmp
        echo "output is not valid fish syntax"
        return 1
    end
    command rm -f $tmp

    # 4. Residual prose detection for text that happens to parse.
    if string match -qr '(?i)\b(worth|almost certainly|probably|you (can|could|should|might|may|will)|note that|if you want|keep in mind|be aware|go ahead|let me know|please provide|share the)\b' -- $cmd
        echo "output reads as prose, not a command"
        return 1
    end
    if string match -qr '[a-z]{3,}\.\s+[A-Z]' -- $cmd
        echo "output reads as prose, not a command"
        return 1
    end

    return 0
end
