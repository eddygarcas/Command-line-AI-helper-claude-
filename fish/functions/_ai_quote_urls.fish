function _ai_quote_urls --argument-names cmd --description 'Single-quote bare URLs containing & or ?'
    # A URL with a query string is a shell hazard. In fish, '&' only backgrounds
    # when followed by whitespace, so '?v=x&t=35s' happens to survive -- but
    # that is luck, not correctness, and it breaks the moment the command is
    # copied into bash or saved to a script. '?' and '*' are also glob
    # characters. Quote defensively.
    #
    # Already-quoted URLs are left alone: the character class excludes quotes,
    # so a URL inside them never matches.
    string replace -ra "(^|[[:space:]])(https?://[^[:space:]'\"]*[&?*][^[:space:]'\"]*)" "\$1'\$2'" -- $cmd
end
