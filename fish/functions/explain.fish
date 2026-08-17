function explain --description 'Explain a shell command and its risks'
    if test (count $argv) -eq 0
        echo "usage: explain <command>" >&2
        return 2
    end
    claude -p "Explain this command, what it does, and anything risky about it. Be terse. Command: $argv" | _ai_clean
end
