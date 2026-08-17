function aim --description 'Claude query, markdown-rendered via glow'
    if not type -q glow
        echo "aim: glow not installed. Run: paru -S glow" >&2
        return 1
    end

    if isatty stdin
        claude -p "$argv" | glow -w 100 -
    else
        set -l piped (cat | string collect)
        printf '%s\n\n--- input ---\n%s\n' "$argv" "$piped" | claude -p | glow -w 100 -
    end
end
