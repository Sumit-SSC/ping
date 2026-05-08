#!/usr/bin/env bash

set -e

COMMENT="$1"

export GH_TOKEN="$GH_TOKEN"

echo "=================================="
echo "💬 Posting GitHub issue comment"
echo "=================================="

gh issue comment "$ISSUE_NUMBER" \
  --body "$COMMENT"

echo "=================================="
echo "✅ GitHub comment posted"
echo "=================================="
