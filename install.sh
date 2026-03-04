#!/bin/bash

SKILLS_DIR="${1:-$HOME}/.claude/skills"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$SKILLS_DIR"

ln -sfv "$SCRIPT_DIR/figma-qa-screen" "$SKILLS_DIR/figma-qa-screen"
ln -sfv "$SCRIPT_DIR/figma-qa-component" "$SKILLS_DIR/figma-qa-component"
