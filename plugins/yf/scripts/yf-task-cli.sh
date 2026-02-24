#!/bin/bash
# yf-task-cli.sh — CLI wrapper for yf-tasks.sh library
#
# Thin dispatch layer so agents can call:
#   bash "$CLAUDE_PLUGIN_ROOT/scripts/yf-task-cli.sh" <command> <args>
#
# Compatible with bash 3.2+ (macOS default).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/yf-tasks.sh"

COMMAND="${1:-}"
shift 2>/dev/null || true

case "$COMMAND" in
  # --- CRUD ---
  create)       yft_create "$@" ;;
  show)         yft_show "$@" ;;
  update)       yft_update "$@" ;;
  close)        yft_close "$@" ;;
  delete)        yft_delete "$@" ;;

  # --- Query ---
  list)         yft_list "$@" ;;
  count)        yft_count "$@" ;;
  ready)        yft_list --ready "$@" ;;

  # --- Labels ---
  label)
    local_cmd="${1:-}"
    shift 2>/dev/null || true
    case "$local_cmd" in
      list)   yft_label_list "$@" ;;
      add)    yft_label_add "$@" ;;
      remove) yft_label_remove "$@" ;;
      *)      echo "Usage: yf-task-cli.sh label <list|add|remove> <id> [label]" >&2; exit 1 ;;
    esac
    ;;

  # --- Dependencies ---
  dep)
    local_cmd="${1:-}"
    shift 2>/dev/null || true
    case "$local_cmd" in
      add)  yft_dep_add "$@" ;;
      *)    echo "Usage: yf-task-cli.sh dep add <dependent> <dependency>" >&2; exit 1 ;;
    esac
    ;;

  # --- Comments ---
  comment)      yft_comment "$@" ;;

  # --- Gates ---
  gate)
    local_cmd="${1:-}"
    shift 2>/dev/null || true
    case "$local_cmd" in
      list)    yft_gate_list "$@" ;;
      resolve) yft_gate_resolve "$@" ;;
      *)       echo "Usage: yf-task-cli.sh gate <list|resolve> [args]" >&2; exit 1 ;;
    esac
    ;;

  # --- Molecules ---
  mol)
    local_cmd="${1:-}"
    shift 2>/dev/null || true
    case "$local_cmd" in
      wisp)       yft_mol_wisp "$@" ;;
      show)       yft_mol_show "$@" ;;
      step-close) yft_mol_step_close "$@" ;;
      squash)     yft_mol_squash "$@" ;;
      *)          echo "Usage: yf-task-cli.sh mol <wisp|show|step-close|squash> [args]" >&2; exit 1 ;;
    esac
    ;;

  # --- Admin ---
  admin)
    local_cmd="${1:-}"
    shift 2>/dev/null || true
    case "$local_cmd" in
      cleanup) yft_cleanup "$@" ;;
      *)       echo "Usage: yf-task-cli.sh admin cleanup [--older-than <days>] [--ephemeral]" >&2; exit 1 ;;
    esac
    ;;

  # --- Help ---
  help|--help|-h|"")
    cat <<'USAGE'
Usage: yf-task-cli.sh <command> [args]

Commands:
  create    --type=<t> --title=<t> [-l <labels>] [--parent=<id>]
  show      <id> [--json] [--comments]
  update    <id> [--status=<s>] [--defer=<d>] [-l <labels>]
  close     <id> [--reason=<r>]
  delete    <id> [--force]
  list      [--type=<t>] [--status=<s>] [-l <labels>] [--ready] [--json]
  count     [--type=<t>] [--status=<s>] [-l <labels>]
  ready     [--type=<t>] [-l <labels>] [--json]
  label     <list|add|remove> <id> [label] [--json]
  dep       add <dependent> <dependency>
  comment   <id> "<protocol>: <content>"
  gate      <list|resolve> [id] [--reason=<r>] [--json]
  mol       <wisp|show|step-close|squash> [args]
  admin     cleanup [--older-than <days>] [--ephemeral] [--dry-run]
USAGE
    ;;

  *)
    echo "Unknown command: $COMMAND" >&2
    echo "Run: yf-task-cli.sh help" >&2
    exit 1
    ;;
esac
