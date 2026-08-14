function explain --description 'Explain a shell command and its risks'
    claude -p "Explain this command, what it does, and anything risky about it. Be terse. Command: $argv"
end
