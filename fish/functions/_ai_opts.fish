function _ai_opts --description 'Populate $_ai_opts_list with common claude -p flags'
    # Baseline: no agency at all. --tools "" removes built-in tools,
    # --disallowedTools "mcp__*" covers MCP tools (which --tools does not
    # reach), --max-turns 1 prevents any agentic loop.
    set -g _ai_opts_list --tools "" --disallowedTools "mcp__*" --max-turns 1

    # Optional model override. Command generation is short, highly structured
    # output -- often a haiku job rather than a sonnet one.
    #   set -Ux AIX_MODEL haiku
    if set -q AIX_MODEL; and test -n "$AIX_MODEL"
        set -a _ai_opts_list --model $AIX_MODEL
    end

    # Skip auto-discovery of hooks, skills, plugins, MCP servers, auto memory,
    # and CLAUDE.md. Big startup win for scripted calls. Safe for aix because
    # it replaces the system prompt anyway, so CLAUDE.md is unused.
    #   set -Ux AIX_BARE 1
    if set -q AIX_BARE; and test "$AIX_BARE" = 1
        set -a _ai_opts_list --bare
    end
end
