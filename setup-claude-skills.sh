#!/usr/bin/env bash
#
# Setup Claude Code Skills for Sage Recovery CRM
# Run this once per developer machine: ./scripts/setup-claude-skills.sh
#

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo "================================================"
echo "  Sage Recovery CRM - Claude Code Skills Setup"
echo "================================================"
echo ""

# Check Claude Code is installed
if ! command -v claude &> /dev/null; then
    echo -e "${RED}Error: Claude Code CLI not found.${NC}"
    echo "Install it first: https://docs.anthropic.com/en/docs/claude-code"
    exit 1
fi

echo -e "${GREEN}Claude Code detected:${NC} $(claude --version)"
echo ""

# Track failures
FAILED=()

# --- 1. Graphify (skill file, not a plugin) ---
echo "--- [1/4] Graphify ---"
echo "  Knowledge graph indexer (~71x token savings per query)"
mkdir -p ~/.claude/skills/graphify
if curl -fsSL https://raw.githubusercontent.com/safishamsi/graphify/v1/skills/graphify/skill.md -o ~/.claude/skills/graphify/SKILL.md 2>/dev/null; then
    echo -e "  ${GREEN}Installed${NC} -> ~/.claude/skills/graphify/SKILL.md"
else
    echo -e "  ${RED}Failed${NC} - check network connection"
    FAILED+=("Graphify")
fi
echo ""

# --- 2. Caveman (plugin marketplace) ---
echo "--- [2/4] Caveman ---"
echo "  Output compression (~65% token savings)"
if claude plugin marketplace add JuliusBrussee/caveman 2>&1 | tail -1 | grep -q "Successfully\|already"; then
    echo -e "  ${GREEN}Marketplace added${NC}"
else
    echo -e "  ${YELLOW}Marketplace may already exist, continuing...${NC}"
fi
if claude plugin install caveman@caveman 2>&1 | tail -1 | grep -q "Successfully\|already"; then
    echo -e "  ${GREEN}Installed${NC}"
else
    echo -e "  ${RED}Failed to install${NC}"
    FAILED+=("Caveman")
fi
echo ""

# --- 3. Superpowers (separate marketplace repo) ---
echo "--- [3/4] Superpowers ---"
echo "  Structured dev workflow with TDD enforcement"
if claude plugin marketplace add obra/superpowers-marketplace 2>&1 | tail -1 | grep -q "Successfully\|already"; then
    echo -e "  ${GREEN}Marketplace added${NC}"
else
    echo -e "  ${YELLOW}Marketplace may already exist, continuing...${NC}"
fi
if claude plugin install superpowers@superpowers-marketplace 2>&1 | tail -1 | grep -q "Successfully\|already"; then
    echo -e "  ${GREEN}Installed${NC}"
else
    echo -e "  ${RED}Failed to install${NC}"
    FAILED+=("Superpowers")
fi
echo ""

# --- 4. UI-UX-Pro-Max (plugin marketplace) ---
echo "--- [4/4] UI-UX-Pro-Max ---"
echo "  Cached design system with industry-specific rules"
if claude plugin marketplace add nextlevelbuilder/ui-ux-pro-max-skill 2>&1 | tail -1 | grep -q "Successfully\|already"; then
    echo -e "  ${GREEN}Marketplace added${NC}"
else
    echo -e "  ${YELLOW}Marketplace may already exist, continuing...${NC}"
fi
if claude plugin install ui-ux-pro-max@ui-ux-pro-max-skill 2>&1 | tail -1 | grep -q "Successfully\|already"; then
    echo -e "  ${GREEN}Installed${NC}"
else
    echo -e "  ${RED}Failed to install${NC}"
    FAILED+=("UI-UX-Pro-Max")
fi
echo ""

# --- Summary ---
echo "================================================"
if [ ${#FAILED[@]} -eq 0 ]; then
    echo -e "  ${GREEN}All 4 skills installed successfully.${NC}"
    echo ""
    echo "  Restart your Claude Code session to activate."
    echo ""
    echo "  Quick reference:"
    echo "    /graphify        - Index codebase into knowledge graph"
    echo "    /caveman         - Toggle terse output mode"
    echo "    /caveman-compress - Compress CLAUDE.md for fewer input tokens"
    echo "    /ui-ux-pro-max   - Generate/load cached design system"
    echo "    Superpowers      - Active automatically (design-first workflow)"
else
    echo -e "  ${YELLOW}Completed with errors:${NC}"
    for f in "${FAILED[@]}"; do
        echo -e "    ${RED}Failed: $f${NC}"
    done
    echo ""
    echo "  Re-run this script or install failed skills manually."
fi
echo "================================================"
echo ""
