# claude-setup

Reproduces this machine's Claude Code setup (CLI, plugins, skills, settings)
on a fresh machine, for either API backend in use.

## Usage

```sh
./install.sh default       # direct Anthropic API (claude login / ANTHROPIC_API_KEY)
./install.sh metacentrum   # e-infra.cz-hosted model gateway
```

For `metacentrum`, either export `CLAUDE_METACENTRUM_TOKEN` beforehand or the
script will prompt for it. The token is never written to this repo — only
injected into `~/.claude/settings.json` at install time.

## What it installs

- **Claude Code CLI** — official native installer, if not already present.
- **Plugins** (via `claude plugin install`, same set for both profiles):
  `ponytail`, `agent-skills`, `frontend-design`, `superpowers`, `github`,
  `mattpocock-skills`. `gitkraken-hooks` is attempted too but only works if
  GitKraken Desktop is installed (it owns that marketplace locally).
- **graphify** skill — via `uv tool install graphifyy` +
  `graphify install --platform claude`.
- **`~/.claude/CLAUDE.md`** — global memory/instructions.
- **`~/.claude/settings.json`** — `settings.base.json` deep-merged with the
  chosen `profiles/*.json` overlay. Existing `enabledPlugins` /
  `extraKnownMarketplaces` written by the plugin-install step are preserved.

Any existing `settings.json` / `CLAUDE.md` are backed up with a timestamp
suffix before being overwritten.

## Adding a new profile

Drop a `profiles/<name>.json` with just the keys that differ from
`settings.base.json` (e.g. `env`, `model`, `permissions.defaultMode`), then
run `./install.sh <name>`. Never commit real tokens — use the
`__CLAUDE_SETUP_TOKEN__` placeholder plus a `CLAUDE_<NAME>_TOKEN`-style env
var, following the `metacentrum` profile as an example.
