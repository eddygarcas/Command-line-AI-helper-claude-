function aix --description 'Ask Claude for a command, install what it needs, then run it'
    if test (count $argv) -eq 0
        echo "usage: aix <what you want to do>" >&2
        return 2
    end

    set -l style "You generate a command to run on Arch Linux (CachyOS) in the fish shell.

Output rules:
- Output ONLY the command. No prose, no explanation, no commentary, no markdown,
  no fences, no backticks. Not one word of English outside the command itself.
- Output exactly ONE command or pipeline. Never offer alternatives or fallbacks.
- Use fish syntax, never bash: command substitution is (cmd) not \$(cmd);
  'set -x VAR val' not 'export'; 'test' not [[ ]]; no heredocs.
- Do not suppress errors with 2>/dev/null unless the task explicitly asks.

Parameterised scripts:
- Use \$argv[1], \$argv[2] and make the VERY FIRST line exactly #!SCRIPT ONLY IF
  the request explicitly asks for arguments, or names a value that must change
  between runs.
- 'this directory', 'here', 'current' are NOT parameters. Use . instead.
- When in doubt, do NOT use #!SCRIPT.

Refusal:
- If the request is destructive or cannot be done safely in one command, output
  exactly CANNOT followed by a one-line reason."

    set -l out (claude -p "$argv" --append-system-prompt "$style" | _ai_clean | string trim)
    set -l cmd (string join \n -- $out | string trim)

    if test -z "$cmd"
        echo "aix: empty response" >&2
        return 1
    end

    if string match -q 'CANNOT*' -- $cmd
        set_color red
        echo (string replace 'CANNOT' 'Refused:' -- $cmd)
        set_color normal
        return 1
    end

    # ------------------------------------------------------------------
    # Prose guard. The model sometimes answers in English despite the
    # style prompt, and _ai_binaries will happily extract a word from a
    # sentence and try to install it. Detect and bail rather than trust.
    # ------------------------------------------------------------------
    if string match -qr '(?i)\b(worth|almost certainly|probably|you (can|could|should|might|may|will)|note that|if you want|instead of|keep in mind|be aware)\b' -- $cmd
        set_color red
        echo "aix: model returned prose, not a command. Raw output:"
        set_color normal
        printf '%s\n' $cmd
        return 1
    end
    # Sentence-shaped output: capitalised word followed by a full stop and a space.
    if string match -qr '[a-z]{3,}\.\s+[A-Z]' -- $cmd
        set_color red
        echo "aix: model returned prose, not a command. Raw output:"
        set_color normal
        printf '%s\n' $cmd
        return 1
    end

    # ------------------------------------------------------------------
    # Script mode. The model signals it, but we verify: no $argv in the
    # snippet means it isn't actually parameterised, whatever it claimed.
    # ------------------------------------------------------------------
    set -l is_script 0
    if string match -q '#!SCRIPT*' -- $out[1]
        set cmd (string join \n -- $out[2..-1] | string trim)
        if string match -q '*$argv*' -- $cmd
            set is_script 1
        else
            set_color yellow
            echo "aix: ignoring #!SCRIPT (no \$argv in output)"
            set_color normal
        end
    end

    echo
    set_color --bold yellow
    printf '%s\n' $cmd
    set_color normal

    # Dependency check.
    for bin in (_ai_binaries "$cmd")
        if not type -q $bin
            _ai_install $bin
            or begin
                echo "aix: aborting, $bin unavailable" >&2
                return 1
            end
        end
    end

    if test $is_script -eq 1
        echo
        set_color cyan
        echo "Parameterised — saving as a script."
        set_color normal
        _ai_save "$cmd" "$argv"
        return $status
    end

    echo
    read -l -P "[r]un  [e]dit  [s]ave as script  [N]o? " answer

    switch $answer
        case r R
            echo
            eval $cmd
        case e E
            set -l tmp (mktemp /tmp/aix.XXXXXX.fish)
            printf '%s\n' $cmd >$tmp
            set -l ed $EDITOR
            test -z "$ed"; and set ed vi
            $ed $tmp
            set -l edited (cat $tmp | string trim)
            rm -f $tmp
            if test -z "$edited"
                echo "Empty after edit, not run."
                return 1
            end
            echo
            eval $edited
        case s S
            _ai_save "$cmd" "$argv"
        case '*'
            echo "Not run."
            return 1
    end
end
