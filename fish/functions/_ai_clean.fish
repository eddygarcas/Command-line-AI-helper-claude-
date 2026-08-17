function _ai_clean --description 'Strip markdown fences and backticks from terminal output'
    # Delete whole fence lines (including the language tag, e.g. ```fish),
    # then strip inline backticks from prose, then collapse blank runs.
    sed -E '/^[[:space:]]*```/d' | string replace -a '`' '' | cat -s
end
