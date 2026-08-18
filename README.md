# agent-skills

A portable collection of reusable Agent Skills for Codex, Claude Code, and other compatible AI development agents.

## Architecture

- `upstream/` contains pinned external source repositories, normally as Git submodules.
- `skills/` is the explicit audited allowlist. An approved entry may be a repository-relative symlink to the exact skill directory under `upstream/`; it is not a second source copy.
- `~/.agents/skills` and `~/.claude/skills` are normal runtime directories containing generated copies of approved skills. They are independent of this repository.

`scripts/install-skills.sh` copies every approved skill directory in full and marks each runtime copy with `.managed-by-ebbmango-agent-skills`. This lets future runs update or remove installations owned by this repository while preserving unrelated skills.

## Security model

- Upstream repositories and approved skill sources are pinned.
- Third-party repositories are never exposed or recursively installed merely because they exist under `upstream/`.
- The complete candidate skill directory, including referenced scripts, assets, references, and other support files, must be audited before an entry is added to `skills/`.
- Allowlist entries must resolve inside this repository and contain valid `SKILL.md` frontmatter.
- Existing runtime skills without this repository's management marker are never overwritten or removed.
- Setup initializes the recorded submodule commits but never advances upstream pins automatically.

## Codespaces

### This repository's own Codespace

`.devcontainer/devcontainer.json` runs `scripts/setup-codespace.sh`. The script initializes pinned submodules, validates the allowlist, and installs runtime copies.

### Every personal Codespace

Configure `ebbmango/agent-skills` as your personal **Codespaces dotfiles repository** in GitHub account settings. GitHub can then use the root `install.sh` entrypoint when creating Codespaces for other repositories. This account-level setting is separate from this repository's `.devcontainer` configuration.

## Adding a third-party skill

1. Add and pin the upstream repository, normally as a Git submodule under `upstream/`.
2. Inspect the complete candidate skill directory.
3. Inspect all referenced scripts, assets, references, and support files.
4. Review commands, network access, filesystem writes, destructive behavior, tool requirements, and permission implications.
5. Confirm provenance and license.
6. Validate the candidate's `SKILL.md` and frontmatter.
7. Add only the approved skill to `skills/`, normally with a relative symlink to its exact upstream directory.
8. Run `./scripts/validate-skills.sh` and the installer tests.
9. Commit the allowlist and pin changes together.

## Updating upstream

Never use automatic remote advancement as routine setup. In particular, do not run `git submodule update --remote` as part of installation.

Review upstream changes and re-audit affected skill directories first. Then deliberately update and commit the pinned submodule revision.

## Current approved skills

- `batch-commit` — groups working-tree changes into functional commits and uses `caveman-commit`
  for their messages.
- `caveman-commit` — commit-message generator from [`JuliusBrussee/caveman`](https://github.com/JuliusBrussee/caveman), pinned through the Caveman submodule.
