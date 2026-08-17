function cs --description 'Claude Code interactive session in ~/shell'
    if not test -d ~/shell
        mkdir -p ~/shell
    end
    pushd ~/shell
    claude $argv
    set -l rc $status
    popd
    return $rc
end
