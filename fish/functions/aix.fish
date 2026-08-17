function aix --description 'Ask Claude for a command, install what it needs, then run it'
    if test (count $argv) -eq 0
        echo "usage: aix <what you want to do>" >&2
        return 2
    end

    set -l style "You generate commands to run on Arch Linux (CachyOS) in the fish shell.

Rules:
- Output ONLY the command. No prose, no markdown, no fences, no backticks.
- Use fish syntax, never bash: command substitution is (cmd) not \$(cmd); use
  'set -x VAR val' not 'export'; use 'test' not [[ ]]; no heredocs.
- Multi-statement answers: one statement per line, valid fish.
- If the task needs values you cannot know (filenames, hosts, IDs), write it as
  a reusable script using \$argv[1], \$argv[2] and so on, and make the VERY FIRST
  line exactly: #!SCRIPT
- If the request is destructive or you cannot do it safely in one command,
  output exactly: CANNOT followed by a one-line reason."

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

    # Script mode: the model decided this needs parameters.
    set -l is_script 0
    if string match -q '#!SCRIPT*' -- $out[1]
        set is_script 1
        set cmd (string join \n -- $out[2..-1] | string trim)
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
        echo "This needs parameters — saving as a script."
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
            eval $EDITOR $tmp; or vi $tmp
            set -l edited (cat $tmp | string trim)
            rm -f $tmp
            test -z "$edited"; and return 1
            echo
            eval $edited
        case s S
            _ai_save "$cmd" "$argv"
        case '*'
            echo "Not run."
            return 1
    end
end
