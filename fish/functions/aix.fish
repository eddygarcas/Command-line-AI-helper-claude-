function aix --description 'Ask Claude for a command, install what it needs, then run it'
    if test (count $argv) -eq 0
        echo "usage: aix <what you want to do>" >&2
        return 2
    end

    # A COMPLETE system prompt, not an append. Claude Code's default prompt
    # frames the model as a coding agent with tools; with tools stripped it
    # replies "I don't have tools to do that" instead of writing a command.
    # Replacing the prompt removes that identity entirely. Per the CLI docs,
    # replacement also drops default safety guidance -- here the CANNOT rule,
    # _ai_validate, and the run confirmation are what stand in for it.
    set -l style "You are a shell command generator. You are not an assistant, not
an agent, and you have no tools. You cannot browse, read files, or run anything.
Your ONLY function is to translate a described goal into the command that
achieves it, for someone else to run.

Environment: Arch Linux (CachyOS), fish shell, mise for runtimes, pacman/paru
for packages, GNU coreutils.

Absolute rules:
- Output the COMMAND, never the answer, never an explanation, never a question.
- If the goal needs a tool you do not have, that is irrelevant -- the USER will
  run the command. Write the command that does it. 'Check the formats of a
  YouTube video' is not something you do; it is 'yt-dlp -F <url>'.
- Never say what you cannot do. Never describe your limitations. Never ask for
  clarification. You are a text transform, not a conversation.
- Output ONLY the command: no prose, no markdown, no fences, no backticks.
- Exactly ONE command or pipeline. No alternatives, no fallbacks.
- The command may reference a tool that is not installed. That is fine and
  expected -- it will be installed before running.
- Reach for whichever tool is standard for the job, whether or not it is likely
  installed: yt-dlp for video/audio metadata and downloads, ffmpeg for media
  conversion, jq for JSON, exiftool for image metadata, imagemagick for images,
  pandoc for document conversion, rsync for sync. Prefer the purpose-built tool
  over an awkward coreutils workaround.
- Use fish syntax, never bash: (cmd) not \$(cmd); 'set -x VAR val' not export;
  'test' not [[ ]]; no heredocs.
- Assume GNU coreutils. Do not assume eza/bat/fd/ripgrep unless named.
- Never parse ls output. Use find -printf or stat.
- Do not add 2>/dev/null unless asked.

Parameterised scripts:
- If the goal needs a value that must change between runs, use \$argv[1],
  \$argv[2] and make the VERY FIRST line exactly: #!SCRIPT
- 'this directory', 'here', 'current' are NOT parameters. Use . instead.
- A value given IN the request (a URL, a path, a name) is NOT a parameter --
  embed it in the command directly.
- When in doubt, do NOT use #!SCRIPT.

Only refusal:
- If no shell command could achieve the goal, output exactly CANNOT followed by
  one line saying why. Use this sparingly -- almost everything has a command."

    set -l out (command claude -p "$argv" --tools "" --disallowedTools "mcp__*" --max-turns 1 \
        --system-prompt "$style" | _ai_clean | string trim)
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
    # Validate. Underspecified prompts make the model ask a question
    # instead of answering, and _ai_binaries would then try to install
    # the first word of that question as a package.
    # ------------------------------------------------------------------
    set -l reason (_ai_validate "$cmd")
    if test $status -ne 0
        set_color red
        echo "aix: $reason"
        set_color normal
        echo
        printf '%s\n' $cmd
        echo
        set_color yellow
        if string match -q '*asked a question*' -- $reason
            echo "Your prompt is missing a value. Re-run with it included."
        else
            echo "The model explained instead of writing a command. Try:"
            echo "  - naming the tool:  aix \"use yt-dlp to list formats for <url>\""
            echo "  - phrasing it as a command:  aix \"command to ...\""
            echo "  - or use 'cs' if the task needs Claude to inspect things itself"
        end
        set_color normal
        return 1
    end

    # ------------------------------------------------------------------
    # Script mode. The model signals it, but verify: no $argv means it is
    # not actually parameterised, whatever it claimed.
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
    set -l bins (_ai_binaries "$cmd")
    for bin in $bins
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

    # ------------------------------------------------------------------
    # Alias shadowing. eval runs in THIS shell, so your functions apply.
    # A generated 'ls -t' written for coreutils will hit an eza wrapper
    # and fail on flags that mean something else. Warn and offer a clean
    # run in a child fish with the shadowing functions erased.
    # ------------------------------------------------------------------
    set -l shadowed (_ai_shadowed $bins)
    set -l menu "[r]un  [e]dit  [s]ave as script  [N]o? "

    if test (count $shadowed) -gt 0
        set_color yellow
        echo
        echo "Shadowed by your fish functions: $shadowed"
        echo "The command was written for the real binaries, so flags may not match."
        set_color normal
        set menu "[r]un as-is  [c]lean run (bypass aliases)  [e]dit  [s]ave  [N]o? "
    end

    echo
    read -l -P "$menu" answer

    switch $answer
        case r R
            echo
            eval $cmd
        case c C
            if test (count $shadowed) -eq 0
                echo "Nothing shadowed; use r."
                return 1
            end
            echo
            # Child fish loads config (so PATH stays intact), then erases the
            # shadowing functions before running. Note: cd will NOT persist.
            set -l erase
            for s in $shadowed
                set -a erase "functions --erase $s 2>/dev/null;"
            end
            command fish -c (string join ' ' -- $erase) " $cmd"
        case e E
            set -l tmp (command mktemp /tmp/aix.XXXXXX.fish)
            printf '%s\n' $cmd >$tmp
            set -l ed $EDITOR
            test -z "$ed"; and set ed vi
            $ed $tmp
            set -l edited (command cat $tmp | string trim)
            command rm -f $tmp
            set -l reason2 (_ai_validate "$edited")
            if test $status -ne 0
                set_color red
                echo "aix: $reason2 -- not run."
                set_color normal
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
