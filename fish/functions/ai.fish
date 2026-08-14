function ai --description 'One-shot Claude query; accepts piped stdin'
    set -l style "You are answering inside a terminal. Output plain text only: no markdown fences, no headers, no bold. If the answer is a multi-line command, preserve the line breaks exactly as you would type them into a shell. Then either stop, or add exactly one declarative sentence. Never revise yourself mid-sentence. Never mention flags, variables, or settings unless you are certain they exist. No alternatives, no caveats, no restating the question."

    if isatty stdin
        claude -p "$argv" --append-system-prompt "$style" | _ai_clean
    else
        set -l piped (cat | string collect)
        printf '%s\n\n--- input ---\n%s\n' "$argv" "$piped" \
            | claude -p --append-system-prompt "$style" | _ai_clean
    end
end
