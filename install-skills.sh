#!/usr/bin/env bash
# Install these authoring skills for Claude Code by symlinking each skills/*/ into
# the personal skills directory. (There is no `claude` CLI command for this - that
# directory *is* the install location; `claude plugin install` is only for plugins
# published to a marketplace.) Symlinks mean edits in this repo stay live.
#   CLAUDE_SKILLS_DIR=/path ./install-skills.sh   # override the destination
set -euo pipefail
src="$(cd "$(dirname "$0")/skills" && pwd)"
dest="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
mkdir -p "$dest"
for d in "$src"/*/; do
  ln -sfn "${d%/}" "$dest/$(basename "$d")" && echo "linked $(basename "$d")"
done
echo "-> $dest"
