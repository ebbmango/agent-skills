---
name: batch-commit
description: >
  Stage and commit Git working-tree changes in coherent, functionally related batches, using
  caveman-commit for terse Conventional Commit messages. Use when the user asks to commit current
  changes, commit the working tree, split changes into atomic commits, make multiple logical
  commits, batch commit, or invokes /batch-commit. This skill performs git add and git commit; use
  caveman-commit alone when the user only wants a message.
---

# Batch Commit

Turn the requested working-tree changes into reviewable commits. Keep each commit independently
coherent and leave unrelated user changes untouched.

## Establish the Repository State

1. Confirm the working directory belongs to a Git repository and identify its root.
2. Read applicable repository instructions and inspect recent commit subjects for local
   conventions.
3. Inspect staged, unstaged, deleted, renamed, and untracked paths. Inspect the actual diffs and
   relevant untracked file contents; do not infer intent from filenames alone.
4. Stop and report a clean tree instead of creating an empty commit.
5. Stop for unresolved conflicts, an in-progress merge, rebase, cherry-pick, or revert, or a
   detached HEAD unless the user explicitly authorizes work in that state.
6. Screen the candidate paths and diffs for credentials, private keys, tokens, environment files,
   and other likely secrets. Do not stage suspected secrets; pause and identify the concern.

## Question Pre-existing Staged Changes

Treat anything staged before this skill begins as an explicit user boundary. Before changing the
index, summarize the staged paths and ask the user to choose whether to:

- commit the staged set exactly as the first batch;
- permit index-only unstaging so all changes can be regrouped; or
- stop without changing the index.

Ask even when the staged set appears coherent. Do not add files to it, split it, unstage it, or
otherwise reinterpret it without the user's answer. If regrouping is authorized, preserve all
working-tree content while changing only the index. Do not repeat this question for batches staged
by this skill during the same run.

## Plan Functional Batches

Plan all batches before staging new changes. Give every batch one purpose that can be explained
without "and" joining unrelated work.

- Keep an implementation with its focused tests and necessary documentation.
- Keep a schema or data migration with the code needed to use it safely.
- Keep dependency manifests with their corresponding lockfiles.
- Keep generated output with the source change that requires it.
- Preserve buildable, testable intermediate states when practical.
- Avoid grouping solely by file type, directory, or diff size.
- Avoid splitting tightly coupled changes merely to increase the commit count.
- Exclude changes outside the user's requested scope and report them as remaining.

Share the concise batch plan before mutating the index. The original request to commit authorizes
the planned staging and commits; request another decision only when intent or ownership is genuinely
ambiguous.

## Stage One Batch at a Time

1. Stage exact paths when an entire file belongs to the batch. Never use blanket staging while
   unrelated changes are present.
2. Use hunk-level staging only when a file contains separable concerns and the selected patch is
   unambiguous. If overlapping edits cannot be separated safely, keep them together or ask the user.
3. Inspect the complete cached diff and its stat before every commit.
4. Run the cached whitespace/error check and confirm the index contains only the current batch.
5. Do not edit working-tree files merely to manufacture cleaner batches.

## Generate the Message with Caveman

Load the installed `caveman-commit` skill and use it as the single source of truth for every commit
message. Give it only the current cached diff and relevant repository convention. Let
`caveman-commit` perform message generation only; this enclosing skill owns staging and executing
the commit.

If `caveman-commit` is unavailable, stop before the first commit and report the missing dependency.
Do not silently invent a replacement message style. Derive each message from the staged batch, not
from the full remaining working tree.

## Validate and Commit

1. Run repository-required checks and proportionate targeted checks for the batch when available.
   Stop and report failures rather than committing known-broken changes or making unrelated fixes.
2. Run `git commit` with the Caveman-generated message. Allow configured hooks to run.
3. Never bypass hooks, amend an existing commit, force an operation, alter Git configuration, or
   add attribution unless repository or user instructions require it.
4. If a hook fails, stop. Preserve the resulting index and working tree, report any hook mutations,
   and do not retry with `--no-verify`.
5. After success, verify the new commit's hash, subject, and changed paths, then re-inspect the
   working tree before staging the next batch.
6. If hooks changed files after a successful commit, reassess those changes instead of silently
   amending or folding them into the next batch.

## Finish

Report commits in creation order with short hashes and subjects. Report any staged, unstaged, or
untracked changes left behind and why. Do not push; publishing is outside this skill's scope.
