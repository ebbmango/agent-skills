#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")/.." rev-parse --show-toplevel)"
SKILLS_DIR="$REPO_ROOT/skills"
CANONICAL_REPO_ROOT="$(realpath -e -- "$REPO_ROOT")"

error_count=0
skill_count=0

report_error() {
    printf 'ERROR: %s\n' "$*" >&2
    error_count=$((error_count + 1))
}

validate_frontmatter() {
    local skill_file="$1"

    awk '
        function has_scalar_content(value, normalized) {
            normalized = value
            sub(/^[[:space:]]+/, "", normalized)
            sub(/[[:space:]]+$/, "", normalized)

            return normalized != "" &&
                normalized !~ /^#.*$/ &&
                normalized !~ /^(""|\047\047)([[:space:]]+#.*)?$/ &&
                normalized !~ /^(null|Null|NULL|~)([[:space:]]+#.*)?$/
        }

        NR == 1 {
            sub(/\r$/, "")
            if ($0 != "---") {
                exit 1
            }
            next
        }

        {
            sub(/\r$/, "")
        }

        $0 == "---" {
            closed = 1
            exit !(has_name && has_description)
        }

        /^name:[[:space:]]*/ {
            value = $0
            sub(/^name:[[:space:]]*/, "", value)
            if (has_scalar_content(value)) {
                has_name = 1
            }
            next
        }

        /^description:[[:space:]]*/ {
            value = $0
            sub(/^description:[[:space:]]*/, "", value)
            if (value ~ /^[>|][+-]?([[:space:]]+#.*)?$/) {
                description_block = 1
            } else if (has_scalar_content(value)) {
                has_description = 1
            }
            next
        }

        description_block && /^[[:space:]]+[^[:space:]#]/ {
            has_description = 1
        }

        END {
            if (!closed || !has_name || !has_description) {
                exit 1
            }
        }
    ' "$skill_file"
}

if [ ! -d "$SKILLS_DIR" ]; then
    printf 'ERROR: approved skills directory does not exist: %s\n' "$SKILLS_DIR" >&2
    exit 1
fi

shopt -s nullglob
for entry in "$SKILLS_DIR"/*; do
    if [ ! -L "$entry" ] && [ -f "$entry" ]; then
        printf 'Ignoring non-skill file: %s\n' "${entry#"$REPO_ROOT"/}"
        continue
    fi

    skill_count=$((skill_count + 1))
    relative_entry="${entry#"$REPO_ROOT"/}"

    if ! resolved_entry="$(realpath -e -- "$entry" 2>/dev/null)"; then
        report_error "$relative_entry does not resolve to an existing path"
        continue
    fi

    case "$resolved_entry" in
        "$CANONICAL_REPO_ROOT"|"$CANONICAL_REPO_ROOT"/*) ;;
        *)
            report_error "$relative_entry resolves outside the repository: $resolved_entry"
            continue
            ;;
    esac

    if [ ! -d "$resolved_entry" ]; then
        report_error "$relative_entry does not resolve to a directory"
        continue
    fi

    skill_file="$resolved_entry/SKILL.md"
    if [ ! -r "$skill_file" ]; then
        report_error "$relative_entry does not contain a readable SKILL.md"
        continue
    fi

    if ! validate_frontmatter "$skill_file"; then
        report_error "$relative_entry has invalid frontmatter (required: opening/closing ---, name, description)"
        continue
    fi

    printf 'Validated approved skill: %s\n' "$(basename -- "$entry")"
done

if [ "$error_count" -ne 0 ]; then
    printf 'Validation failed with %d error(s).\n' "$error_count" >&2
    exit 1
fi

printf 'Validated %d approved skill(s).\n' "$skill_count"
