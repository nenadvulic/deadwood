# Deadwood

Report the dead code a change introduces — scoped to your git diff, powered by [Periphery](https://github.com/peripheryapp/periphery).

Periphery finds unused declarations across the whole project. Deadwood runs it, then keeps only the findings located in the lines your change touched, so you see *what this PR/commit made dead*, not a wall of pre-existing debt.

## Requirements

- [Periphery](https://github.com/peripheryapp/periphery) installed and configured (a `.periphery.yml`, or pass its args after `--`).

## Usage

```bash
# Dead code introduced by your working-tree changes:
deadwood

# Dead code introduced by a branch vs its base (CI/PR):
deadwood --since origin/main...HEAD

# JSON output:
deadwood --format json

# Pass arguments through to `periphery scan`:
deadwood -- --project App.xcodeproj --schemes App
```

Exit code is `1` when new dead code is found (so it can gate CI), `0` otherwise. Use `--no-fail` to always exit `0`.

## How it works

`periphery scan --format json` → keep findings whose location falls in the changed lines of `git diff --unified=0 <since>` → report (text/json).

## License

MIT
