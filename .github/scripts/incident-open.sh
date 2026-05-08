#!/usr/bin/env bash

source .github/scripts/metrics-helper.sh
source .github/scripts/rca-engine.sh
source .github/scripts/tg-send.sh
source .github/scripts/issue-comment.sh

TITLE="${GITHUB_EVENT_ISSUE_TITLE:-${{ github.event.issue.title }}}"

SITE=$(echo "$TITLE" \
  | sed -E 's/ is down.*//' \
  | xargs)

SLUG=$(get_slug "$SITE")

LATENCY=$(get_latency "$SLUG")

UPTIME=$(get_uptime "$SITE")

INCIDENTS=$(get_incidents "$SLUG")

generate_rca "$SITE" "$LATENCY"

MESSAGE="$SEVERITY INCIDENT DETECTED

🌐 Site: $SITE
📡 Status: DOWN
📈 Uptime: $UPTIME
⚡ Last Latency: $LATENCY ms
📉 Incident Count: $INCIDENTS

🛠 Probable Cause:
$RCA

🔍 Suggested Checks:
$CHECKS

⏳ ETA:
$ETA"

send_tg "$MESSAGE"

COMMENT="🤖 Automated Incident Analysis

Severity:
$SEVERITY

Probable Cause:
$RCA

Suggested Checks:
$CHECKS

ETA:
$ETA"

comment_issue "$COMMENT"
