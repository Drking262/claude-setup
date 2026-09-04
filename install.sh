#!/usr/bin/env bash
# Reproduce this machine's Claude Code setup on a fresh install.
# Usage: ./install.sh [default|metacentrum]
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

PROFILE="${1:-default}"
PROFILE_FILE="profiles/${PROFILE}.json"
if [[ ! -f "$PROFILE_FILE" ]]; then
  echo "Unknown profile '$PROFILE'. Available: $(ls profiles | sed 's/\.json$//' | tr '\n' ' ')" >&2
  exit 1
fi

echo "==> Profile: $PROFILE"

# 1. Claude Code CLI itself
if ! command -v claude >/dev/null 2>&1; then
  echo "==> Installing Claude Code CLI"
  curl -fsSL https://claude.ai/install.sh | bash
  export PATH="$HOME/.local/bin:$PATH"
else
  echo "==> Claude Code CLI already installed ($(command -v claude))"
fi

# 2. Global memory (CLAUDE.md)
mkdir -p "$HOME/.claude"
if [[ -f "$HOME/.claude/CLAUDE.md" ]] && ! cmp -s CLAUDE.md "$HOME/.claude/CLAUDE.md"; then
  cp "$HOME/.claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md.bak.$(date +%s)"
fi
cp CLAUDE.md "$HOME/.claude/CLAUDE.md"

# 3. Plugin marketplaces + plugins
echo "==> Adding marketplaces"
claude plugin marketplace add anthropics/claude-plugins-official || true
claude plugin marketplace add DietrichGebert/ponytail || true
claude plugin marketplace add addyosmani/agent-skills || true

echo "==> Installing plugins"
for p in \
  ponytail@ponytail \
  agent-skills@addy-agent-skills \
  frontend-design@claude-plugins-official \
  superpowers@claude-plugins-official \
  github@claude-plugins-official \
  mattpocock-skills@claude-plugins-official \
; do
  claude plugin install "$p" || echo "  (skipped $p — already installed or install failed)"
done

# gitkraken-hooks only makes sense if GitKraken Desktop is installed (it manages
# that marketplace itself as a local directory) — best effort, non-fatal.
claude plugin install gitkraken-hooks@gitkraken 2>/dev/null || \
  echo "==> Skipping gitkraken-hooks (install GitKraken Desktop first if you want it)"

# 4. graphify skill
if ! command -v uv >/dev/null 2>&1; then
  echo "==> Installing uv (for graphify)"
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
fi
echo "==> Installing graphify"
uv tool install graphifyy --quiet 2>/dev/null || uv tool upgrade graphifyy
graphify install --platform claude

# 5. settings.json: base + profile overlay, deep-merged, plugin fields left untouched
echo "==> Writing settings.json"
if [[ -f "$HOME/.claude/settings.json" ]]; then
  cp "$HOME/.claude/settings.json" "$HOME/.claude/settings.json.bak.$(date +%s)"
fi

TOKEN_ARG=""
if [[ "$PROFILE" == "metacentrum" ]]; then
  if [[ -z "${CLAUDE_METACENTRUM_TOKEN:-}" ]]; then
    read -rsp "Metacentrum API token (ANTHROPIC_AUTH_TOKEN): " CLAUDE_METACENTRUM_TOKEN
    echo
  fi
  TOKEN_ARG="$CLAUDE_METACENTRUM_TOKEN"
fi

python3 - "$PROFILE_FILE" "$TOKEN_ARG" <<'PY'
import json, sys, os

profile_file, token = sys.argv[1], sys.argv[2]
settings_path = os.path.expanduser("~/.claude/settings.json")

def deep_merge(base, overlay):
    for k, v in overlay.items():
        if k.startswith("_"):
            continue
        if isinstance(v, dict) and isinstance(base.get(k), dict):
            deep_merge(base[k], v)
        else:
            base[k] = v
    return base

base = json.load(open("settings.base.json"))
overlay = json.load(open(profile_file))
deep_merge(base, overlay)

if token:
    env = base.get("env", {})
    if env.get("ANTHROPIC_AUTH_TOKEN") == "__CLAUDE_SETUP_TOKEN__":
        env["ANTHROPIC_AUTH_TOKEN"] = token

existing = {}
if os.path.exists(settings_path):
    existing = json.load(open(settings_path))

# Keep whatever the plugin installs above wrote (enabledPlugins, extraKnownMarketplaces).
for k in ("enabledPlugins", "extraKnownMarketplaces"):
    if k in existing:
        base[k] = existing[k]

json.dump(base, open(settings_path, "w"), indent=2)
print(f"wrote {settings_path}")
PY

echo "==> Done. Restart any running Claude Code sessions to pick up the new settings."
