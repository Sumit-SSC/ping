#!/usr/bin/env bash

set -e

source .github/scripts/metrics-helper.sh

TITLE="$ISSUE_TITLE"

SITE=$(echo "$TITLE" \
  | sed -E 's/ is up.*//' \
  | xargs)

echo "Recovered site: $SITE"

SLUG=$(get_slug "$SITE")

LATENCY=$(get_latency "$SLUG")

UPTIME=$(get_uptime "$SITE")

MTTR=$(get_mttr "$SLUG")

INCIDENTS=$(get_incidents "$SLUG")

RECOVERY_NOTE="Temporary instability resolved automatically."

if [ "$MTTR" -gt 3600 ]; then

  RECOVERY_NOTE="Extended outage recovered successfully.

Recommended:
• Verify application integrity
• Review provider analytics
• Continue latency monitoring"
fi

MESSAGE="🟢 INCIDENT RESOLVED

🌐 Site: $SITE
📡 Status: HEALTHY
📈 Uptime: $UPTIME
⚡ Current Latency: $LATENCY ms
📉 Incident Count: $INCIDENTS
📘 MTTR: $((MTTR / 60)) mins

🛠 Recovery Notes:
$RECOVERY_NOTE"

echo "$MESSAGE"

# TEMP DEBUG:
bash .github/scripts/tg-send.sh "$MESSAGE"

# TEMP DEBUG:
bash .github/scripts/issue-comment.sh "$MESSAGE"
