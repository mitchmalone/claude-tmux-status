#!/usr/bin/env bash
# Keep a Claude Code /rename title as the tmux window base, plus a state suffix.
# Usage: tmux-rename.sh <state> | --render | --stop

set -euo pipefail
[[ -z "${TMUX_PANE:-}" ]] && exit 0

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
WATCHER="${PLUGIN_ROOT}/scripts/tmux-title-watch.sh"
STATE_OPTION='@claude-tmux-status-state'
BASE_OPTION='@claude-tmux-status-base'

get_option() {
  tmux show-window-options -v -t "$TMUX_PANE" "$1" 2>/dev/null || true
}

set_option() {
  tmux set-window-option -t "$TMUX_PANE" "$1" "$2"
}

claude_title() {
  local title
  title=$(tmux display-message -p -t "$TMUX_PANE" '#{pane_title}')
  # Claude Code prefixes its custom /rename terminal title with this glyph.
  if [[ "$title" == '✳ '* && -n "${title#✳ }" ]]; then
    printf '%s\n' "${title#✳ }"
  fi
}

base_name() {
  local title base current
  title=$(claude_title)
  if [[ -n "$title" ]]; then
    set_option "$BASE_OPTION" "$title"
    printf '%s\n' "$title"
    return
  fi

  base=$(get_option "$BASE_OPTION")
  if [[ -n "$base" ]]; then
    printf '%s\n' "$base"
    return
  fi

  current=$(tmux display-message -p -t "$TMUX_PANE" '#W')
  printf '%s\n' "$(printf '%s' "$current" | sed -E 's/ \[[^][]*\]$//')"
}

icon_for() {
  local state="$1" icon conf
  conf="${PLUGIN_ROOT}/config/active.conf"
  icon=""
  if [[ -f "$conf" ]]; then
    icon=$(grep "^${state}=" "$conf" 2>/dev/null | cut -d= -f2- || true)
  fi
  if [[ -z "$icon" ]]; then
    case "$state" in
      idle) icon='😴' ;;
      processing) icon='🤖' ;;
      attention) icon='👀' ;;
      *) icon="$state" ;;
    esac
  fi
  printf '%s\n' "$icon"
}

render() {
  local base state icon
  base=$(base_name)
  state=$(get_option "$STATE_OPTION")
  if [[ -n "$state" ]]; then
    icon=$(icon_for "$state")
    tmux rename-window -t "$TMUX_PANE" "${base} [${icon}]"
  else
    tmux rename-window -t "$TMUX_PANE" "$base"
  fi
}

case "${1:-}" in
  --render)
    render
    ;;
  --stop)
    "$WATCHER" stop "$TMUX_PANE" || true
    tmux set-window-option -t "$TMUX_PANE" -u "$STATE_OPTION" 2>/dev/null || true
    render
    ;;
  '')
    "$WATCHER" stop "$TMUX_PANE" || true
    tmux set-window-option -t "$TMUX_PANE" -u "$STATE_OPTION" 2>/dev/null || true
    render
    ;;
  *)
    set_option "$STATE_OPTION" "$1"
    "$WATCHER" ensure "$TMUX_PANE" "$PLUGIN_ROOT"
    render
    ;;
esac
