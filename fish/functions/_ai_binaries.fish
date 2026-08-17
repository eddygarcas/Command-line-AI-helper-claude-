function _ai_binaries --description 'Extract external command names from a fish snippet'
    # Fish keywords and builtins that are never installable packages.
    set -l skip for end in if else while switch case function begin and or not \
        set test echo string count math printf read cd source eval exec builtin \
        command type return break continue true false contains abbr alias \
        fish_add_path status pushd popd time else\ if

    set -l found

    # Split on statement and pipeline separators, then take the leading word.
    for line in (string split \n -- "$argv")
        for seg in (string split -n '|' -- $line | string split -n ';' -- | string split -n '&&' -- | string split -n '||' --)
            set -l words (string split -n ' ' -- (string trim -- $seg))
            test (count $words) -eq 0; and continue

            set -l first $words[1]

            # Step past sudo / doas / env and their flags.
            set -l i 1
            while contains -- $first sudo doas env
                set i (math $i + 1)
                test $i -gt (count $words); and break
                set first $words[$i]
                # skip VAR=value and flags
                while string match -qr '^(-|[A-Za-z_][A-Za-z0-9_]*=)' -- $first
                    set i (math $i + 1)
                    test $i -gt (count $words); and break 2
                    set first $words[$i]
                end
            end

            # Strip a leading path, opening paren, or quote.
            set first (string replace -r '^[\(\'"]+' '' -- $first)
            set first (basename -- $first 2>/dev/null; or echo $first)

            # Reject anything that isn't a plausible command name.
            string match -qr '^[A-Za-z0-9_.+-]+$' -- $first; or continue
            contains -- $first $skip; and continue
            contains -- $first $found; and continue

            set -a found $first
        end
    end

    for f in $found
        echo $f
    end
end
