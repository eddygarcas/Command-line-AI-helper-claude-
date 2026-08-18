function _ai_clean --description 'Strip markdown fences and backticks from terminal output'
    # 'command' bypasses fish functions and aliases. Without it, a cat->bat or
    # sed->sd wrapper in the user's config breaks this filter -- which is the
    # same class of bug _ai_shadowed exists to catch in generated commands.
    command sed -E '/^[[:space:]]*```/d' | string replace -a '`' '' | command cat -s
end
