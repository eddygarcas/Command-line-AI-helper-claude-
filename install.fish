#!/usr/bin/env fish
# Symlink Claude Code shell helpers into place.

set -l repo (realpath (dirname (status --current-filename)))

mkdir -p ~/.claude ~/.config/fish/functions ~/shell

for f in CLAUDE.md settings.json
    ln -sfv $repo/claude/$f ~/.claude/$f
end

for f in $repo/fish/functions/*.fish
    ln -sfv $f ~/.config/fish/functions/(basename $f)
end

echo ""
echo "Linked. Next steps:"
echo "  paru -S glow          # required by aim"
echo "  sudo pacman -Fy       # files database, needed by aix dependency install"
echo "  cd ~/shell && claude  # accept the trust prompt once"
