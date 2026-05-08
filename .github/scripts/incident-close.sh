#!/usr/bin/env bash

set -e

source .github/scripts/metrics-helper.sh

# ==========================================
# Parse issue title
# ==========================================

TITLE="$ISSUE_TITLE"

SITE=$(echo "$TITLE" \
  | sed -E 's/ is down.*//' \
  | sed -E 's/ is up.*//' \
  | sed -E 's/^🟥 //g' \
  | sed -E 's/^🟩 //g' \
  | sed -E 's/^🛑 //g' \
  | xargs)

echo "Recovered site: $SITE"

# ==========================================
# Fetch metrics
# ==========================================

SLUG=$(get_slug "$SITE")

SITE_URL=$(get_site_url "$SITE")

LATENCY=$(get_latency "$SLUG")

UPTIME=$(get_uptime "$SITE")

INCIDENTS=$(get_incidents "$SLUG")

AVG_MTTR=$(get_mttr "$SLUG")

# ==========================================
# URLs
# ==========================================

INCIDENT_URL="$INCIDENT_BASE_URL/$ISSUE_NUMBER"

STATUS_URL="$STATUS_BASE_URL/$SLUG"

GITHUB_ISSUE_URL="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/issues/${ISSUE_NUMBER}"

# ==========================================
# Downtime calculation
# Uses GitHub timestamps
# ==========================================

START=$(date -d "$ISSUE_CREATED_AT" +%s)

END=$(date -d "$ISSUE_CLOSED_AT" +%s)

DIFF=$((END - START))

DOWNTIME_MIN=$((DIFF / 60))

# ==========================================
# Update rolling MTTR
# ==========================================

update_mttr "$SLUG" "$DOWNTIME_MIN"

AVG_MTTR=$(get_mttr "$SLUG")

# ==========================================
# Duration formatting
# ==========================================

HOURS=$((DIFF / 3600))

MINS=$(((DIFF % 3600) / 60))

if [ "$HOURS" -gt 0 ]; then

  DURATION="${HOURS}h ${MINS}m"

else

  DURATION="${MINS} mins"

fi

# ==========================================
# Recovery classification
# ==========================================

RECOVERY_STATE="Stable"

RECOVERY_NOTE="Transient outage auto-resolved."

if [ "$DIFF" -gt 3600 ]; then

  RECOVERY_STATE="Recovered After Extended Outage"

  RECOVERY_NOTE="Extended outage recovered successfully.

Possible contributing factors:
• infrastructure restart
• provider instability
• DNS propagation
• backend recovery"

elif [ "$DIFF" -gt 900 ]; then

  RECOVERY_STATE="Recovered After Major Degradation"

  RECOVERY_NOTE="Temporary service instability resolved automatically."

elif [ "$DIFF" -gt 300 ]; then

  RECOVERY_STATE="Recovered After Moderate Instability"

  RECOVERY_NOTE="Moderate service degradation resolved successfully."

fi

# ==========================================
# Health classification
# ==========================================

HEALTH="Healthy"

SPEED="⚪ Unknown"

if [[ "$LATENCY" =~ ^[0-9]+$ ]]; then

  # ========================================
  # Speed ladder
  # ========================================

  if [ "$LATENCY" -lt 100 ]; then

    SPEED="🚀 Excellent"

  elif [ "$LATENCY" -lt 300 ]; then

    SPEED="⚡ Fast"

  elif [ "$LATENCY" -lt 700 ]; then

    SPEED="🏎️ Responsive"

  elif [ "$LATENCY" -lt 1500 ]; then

    SPEED="🚗 Moderate"

  elif [ "$LATENCY" -lt 3000 ]; then

    SPEED="🐢 Slow"

  else

    SPEED="🐌 Severely Degraded"

  fi

  # ========================================
  # Recovery health
  # ========================================

  if [ "$LATENCY" -gt 2500 ]; then

    HEALTH="Still Degraded"

  elif [ "$LATENCY" -gt 1000 ]; then

    HEALTH="Partially Stabilized"

  elif [ "$LATENCY" -gt 500 ]; then

    HEALTH="Elevated Latency"

  fi
fi

# ==========================================
# Flapping recovery detection
# ==========================================

FLAP_WARNING=""

LAST_DOWN=$(jq -r \
  --arg slug "$SLUG" \
  '.[$slug].last_down // 0' \
  observability/incident-metrics.json)

NOW=$(date +%s)

if [ "$LAST_DOWN" -gt 0 ]; then

  GAP=$((NOW - LAST_DOWN))

  if [ "$GAP" -lt 7200 ]; then

    FLAP_WARNING="⚠️ Repeated instability detected after recent recovery."

  fi
fi

# ==========================================
# Time block
# ==========================================

LOCAL_TIME=$(TZ="$SUMMARY_TIMEZONE" \
  date +"%d %b %Y | %I:%M %p")

UTC_TIME=$(date -u +"%H:%M UTC")

# ==========================================
# Telegram recovery message
# ==========================================

MESSAGE="🟢 Incident Resolved

📡 Status: DOWN | 🧪 Environment: $ENVIRONMENT
🌐 Site: $SITE | 🔗 : $SITE_URL

📈 Uptime: $UPTIME
📊 Health: $HEALTH
⚡ Response Time: $LATENCY ms
🚦 Speed Class: $SPEED
📉 Incident Count: $INCIDENTS | #️⃣ Incident: #$ISSUE_NUMBER
📘 Avg MTTR: $MTTR mins

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🛠 Probable Cause:
$RCA

🔍 Suggested Checks:
$CHECKS

⏳ ETA: $ETA

$FLAP_WARNING
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔗 Status: $STATUS_URL
🛠 Issue: $GITHUB_ISSUE_URL
📄 Incident: $INCIDENT_URL

# 🕒 $LOCAL_TIME | 🌍 $UTC_TIME

echo "$MESSAGE"

# ==========================================
# Send Telegram recovery
# ==========================================

.github/scripts/tg-send.sh "$MESSAGE"

# ==========================================
# Recovery GitHub comment
# ==========================================

COMMENT="## 🟢 Automated Recovery Analysis

### 🌐 Recovery Overview

| Metric | Value |
|---|---|
| Site | $SITE |
| Endpoint | $SITE_URL |
| Status | HEALTHY |
| Recovery State | $RECOVERY_STATE |
| Health | $HEALTH |
| Current Latency | $LATENCY ms |
| Speed Class | $SPEED |
| Incident Count | $INCIDENTS |
| Avg MTTR | $AVG_MTTR mins |
| Downtime | $DURATION |

### 🛠 Recovery Summary

$RECOVERY_NOTE

### 📊 Stability Signals

$FLAP_WARNING

### 📈 Operational Notes

• Infrastructure recovered successfully
• Monitoring post-recovery latency stability
• Observability checks resumed normally

### 🔗 References

- Status Dashboard: $STATUS_URL
- GitHub Incident Log: $GITHUB_ISSUE_URL
- Incident Archive: $INCIDENT_URL

---

<sub>🤖 Automated RCA generated by Sumit's Observability Stack  
Maintainer: @Sumit-SC | Alerts via <a href="https://t.me/mitSutestBot">[Upptime-Alerts-Tracker] 
• Powered by <a href="upptime.js.org">Upptime</a> +  <a href="https://github.com/features/actions">Github-Actions</a></a>
</sub>

# ==========================================
# Post GitHub comment
# ==========================================

.github/scripts/issue-comment.sh "$COMMENT"

# ==========================================
# Add resolved label
# ==========================================

gh issue edit "$ISSUE_NUMBER" \
  --add-label "resolved" || true
