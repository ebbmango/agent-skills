#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")/.." rev-parse --show-toplevel)"

git -C "$REPO_ROOT" submodule update --init --recursive
"$REPO_ROOT/scripts/link-skills.sh"
