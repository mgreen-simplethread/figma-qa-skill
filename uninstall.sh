#!/bin/bash

SKILLS_DIR="${1:-$HOME}/.claude/skills"

rm -fv "$SKILLS_DIR/figma-qa-screen"
rm -fv "$SKILLS_DIR/figma-qa-component"
