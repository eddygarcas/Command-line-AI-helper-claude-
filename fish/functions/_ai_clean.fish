function _ai_clean --description 'Strip markdown fences from terminal output'
    sed -E '/^[[:space:]]*```/d' | string replace -a '`' '' | cat -s
end
