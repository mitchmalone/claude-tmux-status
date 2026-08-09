#!/usr/bin/env bash
# Watch a Claude pane title so `/rename` updates the tmux window immediately.

set -euo pipefail

command_name="${1:-}"
pane="${2:-}"
plugin_root="${3:-}"
pid_option='@claude-tmux-status-watcher-pid'

case "$command_name" in
  ensure)
    [[ -n "$pane" && -n "$plugin_root" ]] || exit 2
    existing=$(tmux show-window-options -v -t "$pane" "$pid_option" 2>/dev/null || true)
    if [[ -n "$existing" ]] && kill -0 "$existing" 2>/dev/null; then
      exit 0
    fi
    nohup "$0" watch "$pane" "$plugin_root" >/dev/null 2>&1 &
    tmux set-window-option -t "$pane" "$pid_option" "$!"
    ;;
  stop)
    [[ -n "$pane" ]] || exit 2
    existing=$(tmux show-window-options -v -t "$pane" "$pid_option" 2>/dev/null || true)
    if [[ -n "$existing" ]]; then
      kill "$existing" 2>/dev/null || true
    fi
    tmux set-window-option -t "$pane" -u "$pid_option" 2>/dev/null || true
    ;;
  watch)
    [[ -n "$pane" && -n "$plugin_root" ]] || exit 2
    last_title=''
    while tmux display-message -p -t "$pane" '#{pane_id}' >/dev/null 2>&1; do
      current_title=$(tmux display-message -p -t "$pane" '#{pane_title}')
      if [[ "$current_title" != "$last_title" ]]; then
        TMUX_PANE="$pane" CLAUDE_PLUGIN_ROOT="$plugin_root" "$plugin_root/scripts/tmux-rename.sh" --render
        last_title="$current_title"
      fi
      sleep 0.2
    done
    ;;
  *)
    exit 2
    ;;
esac
