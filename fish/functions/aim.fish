function aim --description 'Claude query, markdown-rendered'
    if isatty stdin
        claude -p "$argv" | glow -w 100 -
    else
        set -l piped (cat | string collect)
        printf '%s\n\n--- input ---\n%s\n' "$argv" "$piped" | claude -p | glow -w 100 -
    end
end
