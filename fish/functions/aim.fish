function aim --description 'Claude query, markdown-rendered via glow'
    if not type -q glow
        echo "aim: glow not installed. Run: paru -S glow" >&2
        return 1
    end

    if isatty stdin
        command claude -p "$argv" --tools "" --disallowedTools "mcp__*" --max-turns 1 | command glow -w 100 -
    else
        set -l piped (command cat | string collect)
        printf '%s\n\n--- input ---\n%s\n' "$argv" "$piped" \
            | command claude -p --tools "" --disallowedTools "mcp__*" --max-turns 1 | command glow -w 100 -
    end
end
