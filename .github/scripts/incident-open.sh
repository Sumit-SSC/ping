#!/usr/bin/env bash

set -e

source .github/scripts/metrics-helper.sh
source .github/scripts/rca-engine.sh

# ==========================================
# Parse issue title
# ==========================================

TITLE="$ISSUE_TITLE"

SITE=$(echo "$TITLE" \
  | sed -E 's/ is down.*//' \
  | sed -E 's/^🟥 //g' \
  | xargs)

echo "Detected site: $SITE"

# ==========================================
# Fetch metrics
# ==========================================

SLUG=$(get_slug "$SITE")

LATENCY=$(get_latency "$SLUG")

UPTIME=$(get_uptime "$SITE")

INCIDENTS=$(get_incidents "$SLUG")

MTTR=$(get_mttr "$SLUG")

# ==========================================
# Generate RCA
# ==========================================

generate_rca "$SITE" "$LATENCY"

# ==========================================
# Environment detection
# ==========================================

ENVIRONMENT="Production"

LOWER=$(echo "$SITE" | tr '[:upper:]' '[:lower:]')

if [[ "$LOWER" =~ test|debug|sandbox|staging|dev ]]; then
  ENVIRONMENT="Testing / Staging"
fi

# ==========================================
# URLs
# ==========================================

INCIDENT_URL="$INCIDENT_BASE_URL/$ISSUE_NUMBER"

STATUS_URL="$STATUS_BASE_URL/$SLUG"

# ==========================================
# Health classification
# ==========================================

HEALTH="Stable"

if [ "$LATENCY" != "unknown" ]; then

  if [ "$LATENCY" -gt 3000 ]; then
    HEALTH="Severely Degraded"
  elif [ "$LATENCY" -gt 1500 ]; then
    HEALTH="Degraded"
  elif [ "$LATENCY" -gt 700 ]; then
    HEALTH="Elevated Latency"
  fi
fi

# ==========================================
# Time block
# ==========================================

LOCAL_TIME=$(TZ="$SUMMARY_TIMEZONE" \
  date +"%d %b %Y | %I:%M %p")

UTC_TIME=$(date -u +"%H:%M UTC")

# ==========================================
# Build Telegram message
# ==========================================

MESSAGE="🚨 Incident Detected

🌐 Site: $SITE
🧪 Environment: $ENVIRONMENT
📡 Status: DOWN
📈 Uptime: $UPTIME
📊 Health: $HEALTH
⚡ Response Time: $LATENCY ms
📉 Incident Count: $INCIDENTS
📘 MTTR: $MTTR mins
#️⃣ Incident: #$ISSUE_NUMBER

🛠 Probable Cause:
$RCA

🔍 Suggested Checks:
$CHECKS

⏳ ETA:
$ETA

🔗 Incident:
$INCIDENT_URL

🔗 Status:
$STATUS_URL

🕒 $LOCAL_TIME | 🌍 $UTC_TIME"

echo "$MESSAGE"

# ==========================================
# Send Telegram
# ==========================================

.github/scripts/tg-send.sh "$MESSAGE"

# ==========================================
# GitHub comment
# ==========================================

COMMENT="## 🤖 Automated Incident Analysis

| Metric | Value |
|---|---|
| Severity | $SEVERITY |
| Environment | $ENVIRONMENT |
| Health | $HEALTH |
| Response Time | $LATENCY ms |
| Incident Count | $INCIDENTS |

### 🛠 Probable Cause
$RCA

### 🔍 Suggested Checks
$CHECKS

### ⏳ Estimated Recovery
$ETA

---
Generated automatically by observability pipeline."

.github/scripts/issue-comment.sh "$COMMENT"
