#!/usr/bin/env fish
# Symlink Claude Code shell helpers into place.

set -l repo (dirname (status --current-filename))
set -l repo (realpath $repo)

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
echo "  cd ~/shell && claude  # accept the trust prompt once"
