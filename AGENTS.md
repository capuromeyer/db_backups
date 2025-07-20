# Contribution Guidelines

This repository contains Bash scripts for automating database backups.

## Commit Messages
- Use a short, present-tense summary (max 72 characters).
- Prefix documentation-only changes with `Docs:`.

## Code Checks
- Run `bash -n` on all `*.sh` files before committing:
  ```bash
  bash -n $(git ls-files '*.sh')
  ```
- If `shellcheck` is available, run it on changed scripts.

## Documentation
- Keep `README.md` up to date with features and usage.

