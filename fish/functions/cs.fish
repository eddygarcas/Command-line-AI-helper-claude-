function cs --description 'Claude Code shell session in ~/shell'
    pushd ~/shell
    claude $argv
    popd
end
