function _ai_shadowed --description 'List command names shadowed by fish functions/aliases'
    # Generated commands are written for the real binaries (GNU coreutils,
    # etc). If a name is a fish function -- 'ls' wrapping eza, 'cat' wrapping
    # bat, 'find' wrapping fd -- the flags will not match and the command
    # fails in confusing ways. Abbreviations do not matter here: they expand
    # at the command line, not inside eval.
    for bin in $argv
        if functions -q $bin
            echo $bin
        end
    end
end
