function _ai_install --argument-names bin --description 'Install the package owning a missing binary'
    if test -z "$bin"
        echo "_ai_install: no binary name given" >&2
        return 2
    end

    set_color yellow
    echo "Missing command: $bin"
    set_color normal

    # ------------------------------------------------------------------
    # 1. Files database must be present for EVERY configured repo. These
    #    map a binary path to its owning package, are not synced by -Syu,
    #    and each repo has its own. On CachyOS that means cachyos-znver4,
    #    cachyos-core-znver4 etc, not just core/extra -- so enumerate.
    # ------------------------------------------------------------------
    set -l repos
    if type -q pacman-conf
        set repos (command pacman-conf --repo-list 2>/dev/null)
    end
    test (count $repos) -eq 0; and set repos core extra multilib

    set -l missing
    for r in $repos
        test -f /var/lib/pacman/sync/$r.files; or set -a missing $r
    end

    if test (count $missing) -gt 0
        echo "Files database not synced for: $missing"
        read -l -P "Run 'sudo pacman -Fy'? [Y/n] " ok
        switch $ok
            case n N
                echo "Cannot resolve package without the files database." >&2
                return 1
            case '*'
                command sudo command pacman -Fy; or return 1
        end
    end

    # ------------------------------------------------------------------
    # 2. Resolve binary -> package by owned path. Names diverge often:
    #    rg->ripgrep, dig->bind, convert->imagemagick.
    # ------------------------------------------------------------------
    set -l hits (command pacman -Fq "usr/bin/$bin" 2>/dev/null | string trim | string match -v '')
    if test (count $hits) -eq 0
        set hits (command pacman -Fq "usr/sbin/$bin" 2>/dev/null | string trim | string match -v '')
    end

    if test (count $hits) -gt 0
        set -l choice $hits[1]

        if test (count $hits) -gt 1
            echo "Multiple repos provide $bin:"
            for i in (seq (count $hits))
                echo "  $i) $hits[$i]"
            end
            read -l -P "Which? [1] " n
            if test -n "$n"
                if string match -qr '^[0-9]+$' -- $n; and test $n -ge 1 -a $n -le (count $hits)
                    set choice $hits[$n]
                else
                    echo "Invalid selection." >&2
                    return 1
                end
            end
        end

        # Strip repo prefix and any trailing version column. Note pacman
        # resolves the repo itself by pacman.conf order, so the menu is
        # informational -- use 'pacman -S repo/pkg' to force one.
        set -l pkg (string replace -r '^[^/]+/' '' -- $choice | string replace -r '\s.*$' '')

        read -l -P "Install $choice ? [y/N] " ok
        switch $ok
            case y Y
                command sudo command pacman -S --needed $pkg; or return 1
            case '*'
                echo "Skipped."
                return 1
        end
    else
        # --------------------------------------------------------------
        # 3. Not in the repos. Fall back to an AUR helper if present.
        # --------------------------------------------------------------
        set -l helper
        for h in paru yay pikaur aura
            if type -q $h
                set helper $h
                break
            end
        end

        if test -z "$helper"
            echo "No repo package owns usr/bin/$bin, and no AUR helper found." >&2
            echo "Install one with: sudo pacman -S paru" >&2
            return 1
        end

        echo "No repo package provides $bin. Searching AUR with $helper..."
        command $helper -Ss "^$bin\$" 2>/dev/null | command head -20

        read -l -P "Install '$bin' via $helper? [y/N] " ok
        switch $ok
            case y Y
                command $helper -S --needed $bin; or return 1
            case '*'
                echo "Skipped."
                return 1
        end
    end

    # ------------------------------------------------------------------
    # 4. Confirm it is callable now.
    # ------------------------------------------------------------------
    hash -r 2>/dev/null

    if type -q $bin
        set_color green
        echo "$bin is now available."
        set_color normal
        return 0
    else
        set_color red
        echo "$bin still not on PATH after install."
        set_color normal
        echo "Check where it landed with: pacman -Ql <package> | grep bin/" >&2
        return 1
    end
end
