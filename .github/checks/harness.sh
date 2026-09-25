# The shell's half of the checks that drive a real editor behind a socket
# (.github/scripts/motions, restart, tabline and diagnostics). Sourced, never
# run, by a script that has set $name, the check's name, first.
#
# The editor runs on a pty, which `script` (util-linux) provides, and every
# question goes to it over the socket. The editor is the working copy, through
# NVIM_APPNAME=mivn, unless the environment already names one; CI has only
# ~/.config/nvim and says so.
#
# shellcheck shell=bash

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

export NVIM_APPNAME="${NVIM_APPNAME:-mivn}"

die() {
  echo "$name: $1" >&2
  exit 1
}

only="${1:-}"
status=0

sock="${XDG_RUNTIME_DIR:-/tmp}/mivn-$name.$$.sock"
work=$(mktemp -d) || die "could not make a scratch directory"
trap 'rm -rf "$work" "$sock"' EXIT

# The editor's own Lua half of this check.
cases="$PWD/.github/checks/$name.lua"

# Starts an editor on the files given, listening on $sock; with none, the
# banner is what comes up. $cols and $rows size the pty when set, and
# $editor_env is put in front of nvim as `NAME=value` words. setsid keeps it
# off this shell's terminal; the screen goes nowhere.
# shellcheck disable=SC2120
start() {
  local args="" size=""

  for arg in "$@"; do
    args+=" '$arg'"
  done

  if [ -n "${cols:-}" ]; then
    size="stty cols $cols rows $rows; "
  fi

  rm -f "$sock"
  setsid script -qec "${size}env TERM=xterm-256color ${editor_env:-} nvim --listen '$sock'$args" \
    /dev/null > /dev/null 2>&1 &

  for _ in $(seq 1 100); do
    [ -S "$sock" ] && break
    sleep 0.1
  done

  [ -S "$sock" ] || die "the editor never listened on $sock"
  sleep 1
}

# Asks the editor for an expression. Bounded, so an editor that stops answering
# fails the run rather than holding it.
nv() {
  timeout 15 nvim --server "$sock" --remote-expr "$1"
}

# Loads the check's Lua half into the editor, which leaves it as `M`.
load() {
  nv "luaeval('dofile(_A)', '$cases')" > /dev/null
}

# The indexes of the cases matching the pattern this script was given.
matching() {
  nv "luaeval('table.concat(M.matching(_A), \" \")', '$only')"
}

stop() {
  nv 'execute("qa!")' > /dev/null 2>&1 || true
}

# Prints a case's row, and remembers a FAIL for the exit status.
report() {
  printf '%s\n' "$1"

  case $1 in
    *FAIL*) status=1 ;;
  esac
}
