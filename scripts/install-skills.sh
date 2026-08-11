#!/usr/bin/env bash
set -euo pipefail

: "${HOME:?HOME must be set}"

REPO_ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")/.." rev-parse --show-toplevel)"
SKILLS_DIR="$REPO_ROOT/skills"
CANONICAL_REPO_ROOT="$(realpath -e -- "$REPO_ROOT")"
CANONICAL_SKILLS_DIR="$(realpath -e -- "$SKILLS_DIR")"
MARKER_NAME=".managed-by-ebbmango-agent-skills"
MANAGER_ID="ebbmango/agent-skills"
RUNTIME_ROOTS=(
    "$HOME/.agents/skills"
    "$HOME/.claude/skills"
)

declare -a SKILL_NAMES=()
declare -a SKILL_SOURCES=()
declare -A APPROVED_SKILLS=()
declare -A ROOT_STATES=()
ACTIVE_TEMPORARY_DIRECTORY=""
ACTIVE_BACKUP_DIRECTORY=""
ACTIVE_DESTINATION=""

cleanup_installation_artifacts() {
    if [ -n "$ACTIVE_BACKUP_DIRECTORY" ] && [ -d "$ACTIVE_BACKUP_DIRECTORY" ]; then
        if [ -n "$ACTIVE_DESTINATION" ] &&
            [ ! -e "$ACTIVE_DESTINATION" ] &&
            [ ! -L "$ACTIVE_DESTINATION" ]; then
            mv -- "$ACTIVE_BACKUP_DIRECTORY" "$ACTIVE_DESTINATION" 2>/dev/null || true
        else
            rm -rf -- "$ACTIVE_BACKUP_DIRECTORY" 2>/dev/null || true
        fi
    fi

    if [ -n "$ACTIVE_TEMPORARY_DIRECTORY" ]; then
        rm -rf -- "$ACTIVE_TEMPORARY_DIRECTORY" 2>/dev/null || true
    fi
}

trap cleanup_installation_artifacts EXIT

is_managed_directory() {
    local directory="$1"
    local marker="$directory/$MARKER_NAME"

    [ -d "$directory" ] &&
        [ ! -L "$directory" ] &&
        [ -f "$marker" ] &&
        [ ! -L "$marker" ] &&
        grep -Fqx -- "managed-by=$MANAGER_ID" "$marker"
}

preflight_runtime_root() {
    local runtime_root="$1"
    local resolved_target

    if [ -L "$runtime_root" ]; then
        if ! resolved_target="$(realpath -e -- "$runtime_root" 2>/dev/null)"; then
            printf 'ERROR: refusing unresolved runtime symlink: %s\n' "$runtime_root" >&2
            return 1
        fi

        if [ "$resolved_target" != "$CANONICAL_SKILLS_DIR" ]; then
            printf 'ERROR: refusing runtime symlink outside this repository: %s -> %s\n' \
                "$runtime_root" "$resolved_target" >&2
            return 1
        fi

        ROOT_STATES["$runtime_root"]="legacy-symlink"
        return
    fi

    if [ -e "$runtime_root" ]; then
        if [ ! -d "$runtime_root" ]; then
            printf 'ERROR: runtime root exists but is not a directory: %s\n' "$runtime_root" >&2
            return 1
        fi
        ROOT_STATES["$runtime_root"]="directory"
        return
    fi

    ROOT_STATES["$runtime_root"]="missing"
}

preflight_destination() {
    local destination="$1"

    if [ -L "$destination" ]; then
        printf 'ERROR: refusing unexpected skill symlink: %s\n' "$destination" >&2
        return 1
    fi

    if [ ! -e "$destination" ]; then
        return
    fi

    if ! is_managed_directory "$destination"; then
        printf 'ERROR: refusing to overwrite unmanaged skill: %s\n' "$destination" >&2
        return 1
    fi
}

prepare_runtime_root() {
    local runtime_root="$1"

    if [ "${ROOT_STATES[$runtime_root]}" = "legacy-symlink" ]; then
        rm -- "$runtime_root"
        mkdir -p -- "$runtime_root"
        printf 'Migrated legacy runtime symlink: %s\n' "$runtime_root"
        return
    fi

    mkdir -p -- "$runtime_root"
}

install_skill() {
    local runtime_root="$1"
    local skill_name="$2"
    local source_directory="$3"
    local destination="$runtime_root/$skill_name"
    local temporary_directory
    local backup_directory=""

    temporary_directory="$(mktemp -d -- "$runtime_root/.${skill_name}.tmp.XXXXXX")"
    ACTIVE_TEMPORARY_DIRECTORY="$temporary_directory"

    if ! cp -a -- "$source_directory/." "$temporary_directory/"; then
        rm -rf -- "$temporary_directory"
        ACTIVE_TEMPORARY_DIRECTORY=""
        printf 'ERROR: failed to copy approved skill: %s\n' "$skill_name" >&2
        return 1
    fi

    if [ -e "$temporary_directory/$MARKER_NAME" ] ||
        [ -L "$temporary_directory/$MARKER_NAME" ]; then
        rm -rf -- "$temporary_directory/$MARKER_NAME"
    fi

    if ! printf 'managed-by=%s\nskill=%s\nsource=skills/%s\n' \
        "$MANAGER_ID" "$skill_name" "$skill_name" >"$temporary_directory/$MARKER_NAME"; then
        rm -rf -- "$temporary_directory"
        ACTIVE_TEMPORARY_DIRECTORY=""
        printf 'ERROR: failed to write management marker for: %s\n' "$skill_name" >&2
        return 1
    fi

    if [ ! -r "$temporary_directory/SKILL.md" ]; then
        rm -rf -- "$temporary_directory"
        ACTIVE_TEMPORARY_DIRECTORY=""
        printf 'ERROR: copied skill is missing a readable SKILL.md: %s\n' "$skill_name" >&2
        return 1
    fi

    if [ -e "$destination" ] || [ -L "$destination" ]; then
        if ! is_managed_directory "$destination"; then
            rm -rf -- "$temporary_directory"
            ACTIVE_TEMPORARY_DIRECTORY=""
            printf 'ERROR: destination changed during installation: %s\n' "$destination" >&2
            return 1
        fi

        backup_directory="$(mktemp -d -- "$runtime_root/.${skill_name}.backup.XXXXXX")"
        if ! rmdir -- "$backup_directory"; then
            rm -rf -- "$temporary_directory" "$backup_directory"
            ACTIVE_TEMPORARY_DIRECTORY=""
            printf 'ERROR: failed to prepare managed-skill backup: %s\n' "$destination" >&2
            return 1
        fi

        ACTIVE_BACKUP_DIRECTORY="$backup_directory"
        ACTIVE_DESTINATION="$destination"

        if ! mv -- "$destination" "$backup_directory"; then
            rm -rf -- "$temporary_directory"
            ACTIVE_TEMPORARY_DIRECTORY=""
            ACTIVE_BACKUP_DIRECTORY=""
            ACTIVE_DESTINATION=""
            printf 'ERROR: failed to preserve existing managed skill: %s\n' "$destination" >&2
            return 1
        fi
    fi

    if ! mv -- "$temporary_directory" "$destination"; then
        if [ -n "$backup_directory" ] && [ -d "$backup_directory" ]; then
            mv -- "$backup_directory" "$destination"
            ACTIVE_BACKUP_DIRECTORY=""
            ACTIVE_DESTINATION=""
        fi
        rm -rf -- "$temporary_directory"
        ACTIVE_TEMPORARY_DIRECTORY=""
        printf 'ERROR: failed to activate installed skill: %s\n' "$destination" >&2
        return 1
    fi
    ACTIVE_TEMPORARY_DIRECTORY=""

    if [ -n "$backup_directory" ]; then
        rm -rf -- "$backup_directory"
        ACTIVE_BACKUP_DIRECTORY=""
        ACTIVE_DESTINATION=""
    fi

    printf 'Installed approved skill: %s -> %s\n' "$skill_name" "$destination"
}

remove_stale_managed_skills() {
    local runtime_root="$1"
    local entry
    local skill_name

    shopt -s dotglob nullglob
    for entry in "$runtime_root"/*; do
        if ! is_managed_directory "$entry"; then
            continue
        fi

        skill_name="$(basename -- "$entry")"
        if [ -z "${APPROVED_SKILLS[$skill_name]+approved}" ]; then
            rm -rf -- "$entry"
            printf 'Removed stale managed skill: %s\n' "$entry"
        fi
    done
}

# Validate the complete allowlist before inspecting or modifying runtime state.
"$REPO_ROOT/scripts/validate-skills.sh"

shopt -s nullglob
for entry in "$SKILLS_DIR"/*; do
    if [ ! -L "$entry" ] && [ -f "$entry" ]; then
        continue
    fi

    resolved_entry="$(realpath -e -- "$entry")"
    case "$resolved_entry" in
        "$CANONICAL_REPO_ROOT"|"$CANONICAL_REPO_ROOT"/*) ;;
        *)
            printf 'ERROR: approved skill escaped the repository after validation: %s\n' "$entry" >&2
            exit 1
            ;;
    esac

    skill_name="$(basename -- "$entry")"
    SKILL_NAMES+=("$skill_name")
    SKILL_SOURCES+=("$resolved_entry")
    APPROVED_SKILLS["$skill_name"]=1
done

# Refuse all known root and destination conflicts before changing either runtime.
for runtime_root in "${RUNTIME_ROOTS[@]}"; do
    preflight_runtime_root "$runtime_root"
done

for runtime_root in "${RUNTIME_ROOTS[@]}"; do
    if [ "${ROOT_STATES[$runtime_root]}" != "legacy-symlink" ]; then
        for skill_name in "${SKILL_NAMES[@]}"; do
            preflight_destination "$runtime_root/$skill_name"
        done
    fi
done

for runtime_root in "${RUNTIME_ROOTS[@]}"; do
    prepare_runtime_root "$runtime_root"

    for index in "${!SKILL_NAMES[@]}"; do
        install_skill "$runtime_root" "${SKILL_NAMES[$index]}" "${SKILL_SOURCES[$index]}"
    done

    remove_stale_managed_skills "$runtime_root"
done
