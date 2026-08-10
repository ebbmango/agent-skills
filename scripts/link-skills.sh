#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")/.." rev-parse --show-toplevel)"
SKILLS_DIR="$REPO_ROOT/skills"

link_skills() {
    target="$1"

    mkdir -p "$(dirname "$target")"

    if [ -L "$target" ]; then
        existing="$(readlink "$target")"

        if [ "$existing" = "$SKILLS_DIR" ]; then
            echo "Already linked: $target -> $SKILLS_DIR"
            return
        fi

        echo "Refusing to replace existing symlink: $target -> $existing" >&2
        exit 1
    fi

    if [ -e "$target" ]; then
        echo "Refusing to replace existing path: $target" >&2
        exit 1
    fi

    ln -s "$SKILLS_DIR" "$target"
    echo "Linked: $target -> $SKILLS_DIR"
}

link_skills "$HOME/.agents/skills"
link_skills "$HOME/.claude/skills"
