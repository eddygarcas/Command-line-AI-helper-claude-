function _ai_install --argument-names bin --description 'Install the package owning a missing binary'
    set_color yellow
    echo "Missing command: $bin"
    set_color normal

    # The files database is what maps a binary path to a package.
    # It is not synced by -Syu, so sync it on first use or if stale.
    if not test -f /var/lib/pacman/sync/core.files
        echo "Syncing pacman files database..."
        sudo pacman -Fy; or return 1
    end

    # Binary name and package name are frequently different (rg -> ripgrep,
    # dig -> bind, convert -> imagemagick), so resolve by owned path.
    set -l pkgs (pacman -Fq "usr/bin/$bin" 2>/dev/null | string replace -r '^[^/]+/' '' | string replace -r ' .*$' '')

    if test (count $pkgs) -gt 0
        set -l pkg $pkgs[1]
        if test (count $pkgs) -gt 1
            echo "Repo packages providing $bin:"
            for i in (seq (count $pkgs))
                echo "  $i) $pkgs[$i]"
            end
            read -l -P "Which? [1] " n
            test -n "$n"; and set pkg $pkgs[$n]
        end

        read -l -P "Install $pkg from repos? [y/N] " ok
        switch $ok
            case y Y
                sudo pacman -S --needed $pkg; or return 1
            case '*'
                return 1
        end
    else
        # Nothing in the repos. Fall back to whichever AUR helper is present.
        set -l helper
        for h in paru yay
            if type -q $h
                set helper $h
                break
            end
        end

        if test -z "$helper"
            echo "Not in repos, and no AUR helper (paru/yay) installed." >&2
            return 1
        end

        echo "Not in the official repos. Searching AUR with $helper..."
        $helper -Ss "^$bin\$" 2>/dev/null | head -20

        read -l -P "Install '$bin' via $helper? [y/N] " ok
        switch $ok
            case y Y
                $helper -S --needed $bin; or return 1
            case '*'
                return 1
        end
    end

    # Fish caches PATH lookups; clear so the new binary is visible immediately.
    if functions -q fish_command_not_found
        # no-op, just documenting intent
    end
    hash -r 2>/dev/null
    type -q $bin
end
