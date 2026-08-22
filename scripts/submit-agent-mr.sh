#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/submit-agent-mr.sh \
    --title <mr-title> \
    --summary <summary> \
    --verification <verification> \
    --risk <risk-and-rollback> \
    [--agent-name <name>] \
    [--agent-id <id>] \
    [--dry-run]

Pushes the current committed branch to Echo GitLab and creates or updates its
Merge Request to main. The MR always includes the submitting Agent's identity.

Agent identity defaults:
  name: ECHO_AGENT_NAME, MULTICA_AGENT_NAME, or "Codex" in a Codex task
  id:   ECHO_AGENT_ID, MULTICA_AGENT_ID, CODEX_THREAD_ID, or CODEX_SESSION_ID

Agents without one of these identifiers must pass --agent-name and --agent-id.
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

require_value() {
  local option="$1"
  local value="${2:-}"
  [[ -n "$value" ]] || die "$option requires a non-empty value"
}

title=""
summary=""
verification=""
risk=""
agent_name=""
agent_id=""
dry_run=0

while (($# > 0)); do
  case "$1" in
    --title)
      require_value "$1" "${2:-}"
      title="$2"
      shift 2
      ;;
    --summary)
      require_value "$1" "${2:-}"
      summary="$2"
      shift 2
      ;;
    --verification)
      require_value "$1" "${2:-}"
      verification="$2"
      shift 2
      ;;
    --risk)
      require_value "$1" "${2:-}"
      risk="$2"
      shift 2
      ;;
    --agent-name)
      require_value "$1" "${2:-}"
      agent_name="$2"
      shift 2
      ;;
    --agent-id)
      require_value "$1" "${2:-}"
      agent_id="$2"
      shift 2
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

[[ -n "$title" ]] || die "--title is required"
[[ -n "$summary" ]] || die "--summary is required"
[[ -n "$verification" ]] || die "--verification is required"
[[ -n "$risk" ]] || die "--risk is required"

if [[ -z "$agent_name" ]]; then
  agent_name="${ECHO_AGENT_NAME:-${MULTICA_AGENT_NAME:-}}"
fi
if [[ -z "$agent_name" && ( -n "${CODEX_THREAD_ID:-}" || -n "${CODEX_SESSION_ID:-}" ) ]]; then
  agent_name="Codex"
fi

if [[ -z "$agent_id" ]]; then
  agent_id="${ECHO_AGENT_ID:-${MULTICA_AGENT_ID:-${CODEX_THREAD_ID:-${CODEX_SESSION_ID:-}}}}"
fi

[[ -n "$agent_name" ]] || die "Agent name is required; set ECHO_AGENT_NAME or pass --agent-name"
[[ -n "$agent_id" ]] || die "Agent ID is required; set ECHO_AGENT_ID or pass --agent-id"

[[ "$agent_name" != *$'\n'* && "$agent_name" != *$'\r'* && "$agent_name" != *'`'* ]] ||
  die "Agent name must be a single line without backticks"
[[ "$agent_id" =~ ^[A-Za-z0-9._:@/-]+$ ]] ||
  die "Agent ID may contain only letters, numbers, dot, underscore, colon, at, slash, and hyphen"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not inside a Git worktree"

branch="$(git symbolic-ref --quiet --short HEAD)" || die "detached HEAD is not supported"
[[ "$branch" != "main" ]] || die "refusing to submit directly from protected branch main"
[[ -z "$(git status --porcelain)" ]] || die "working tree must be clean; commit all changes first"

origin_url="$(git remote get-url origin 2>/dev/null)" || die "origin remote is missing"
case "$origin_url" in
  git@g.echo.tech:toolkit/multica.git | https://g.echo.tech/toolkit/multica | https://g.echo.tech/toolkit/multica.git)
    repo_slug="toolkit/multica"
    ;;
  git@g.echo.tech:toolkit/multica-cli.git | https://g.echo.tech/toolkit/multica-cli | https://g.echo.tech/toolkit/multica-cli.git)
    repo_slug="toolkit/multica-cli"
    ;;
  *)
    die "origin must be an approved Echo GitLab repository, got: $origin_url"
    ;;
esac

git rev-parse --verify 'origin/main^{commit}' >/dev/null 2>&1 ||
  die "origin/main is missing; fetch the internal baseline first"
git merge-base --is-ancestor origin/main HEAD ||
  die "current branch must contain the origin/main baseline"

head_sha="$(git rev-parse HEAD)"
commit_list="$(git log --format='- `%h` %s' origin/main..HEAD)"
[[ -n "$commit_list" ]] || die "current branch has no commits beyond origin/main"

description="$(cat <<EOF
## Summary

$summary

## Commits

$commit_list

## Verification

$verification

## Risk and rollback

$risk

## Agent identity

- Agent: \`$agent_name\`
- Agent ID: \`$agent_id\`
- Source branch: \`$branch\`
- Head commit: \`$head_sha\`
EOF
)"

if ((dry_run)); then
  printf 'Repository: %s\n' "$repo_slug"
  printf 'Target: main\n'
  printf 'Title: %s\n\n' "$title"
  printf '%s\n' "$description"
  exit 0
fi

command -v glab >/dev/null 2>&1 || die "glab is required"
command -v jq >/dev/null 2>&1 || die "jq is required"

git fetch origin main
git merge-base --is-ancestor origin/main HEAD ||
  die "current branch is behind the latest origin/main; update it before submitting"
git push -u origin "$branch"

mr_json="$(
  glab mr list \
    --repo "$repo_slug" \
    --source-branch "$branch" \
    --target-branch main \
    --output json
)"
mr_iid="$(jq -r '.[0].iid // empty' <<<"$mr_json")"

if [[ -n "$mr_iid" ]]; then
  glab mr update "$mr_iid" \
    --repo "$repo_slug" \
    --target-branch main \
    --title "$title" \
    --description "$description" \
    --yes
else
  glab mr create \
    --repo "$repo_slug" \
    --source-branch "$branch" \
    --target-branch main \
    --title "$title" \
    --description "$description" \
    --yes
fi
