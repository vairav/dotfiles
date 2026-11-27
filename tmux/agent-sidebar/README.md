# tmux-agent-sidebar, local build

tmux-agent-sidebar (github.com/hiroppy/tmux-agent-sidebar, MIT) is a tmux side pane that lists every
Claude Code, Codex and OpenCode pane with its status. We run upstream releases with one local patch,
`local-no-network.patch`, which turns off its two GitHub calls: the release check against
api.github.com and `gh pr view` for each agent's repo.

`sidebar-update.sh` keeps the build in step with upstream (Vairav chose this over an upstream PR on
2026-11-27). Every Sunday at 10:15 launchd runs it: it fetches the release tags, applies the patch to the
newest tag with `git apply --3way`, checks the two calls are still off, builds with
`cargo build --release --locked`, checks the version, and only then switches
`~/.local/share/tmux-agent-sidebar/current` and `~/.local/bin/tmux-agent-sidebar` to it. When the patch
or the build fails the old binary stays and one memroute open item is filed for that release.

    ./sidebar-update.sh --check      installed and newest tags
    ./sidebar-update.sh --now        run once by hand
    ./sidebar-update.sh --install    LaunchAgent local.vairav.sidebar-update
    ./sidebar-update.sh --uninstall

Log: `~/Library/Logs/sidebar-update.log`. TPM never manages this plugin, because its update key
would pull the unpatched upstream.
