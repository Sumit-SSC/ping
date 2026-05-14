#!/usr/bin/env bash

set -e

COMMENT="$1"

echo "=================================="
echo "💬 GitHub Issue Enrichment Engine"
echo "=================================="

# ==========================================
# Export authentication token
# ==========================================

export GH_TOKEN="$GH_TOKEN"

# ==========================================
# Initial sync wait
# GitHub issue indexing can lag
# ==========================================

# ==========================================
# Wait for GitHub issue propagation
# ==========================================

echo "=================================="
echo "⏳ Waiting for GitHub issue sync"
echo "=================================="

MAX_SYNC_RETRIES=12

SYNC_RETRY=1

ISSUE_READY=false

while [ $SYNC_RETRY -le $MAX_SYNC_RETRIES ]; do

  echo "Sync attempt $SYNC_RETRY"

  if gh issue view "$ISSUE_NUMBER" >/dev/null 2>&1; then

    ISSUE_READY=true

    echo "✅ Issue fully propagated"

    break

  fi

  echo "Issue not ready yet..."

  sleep 5

  SYNC_RETRY=$((SYNC_RETRY + 1))

done

if [ "$ISSUE_READY" != true ]; then

  echo "❌ GitHub issue propagation timeout"

  exit 1

fi

# ==========================================
# Comment retry logic
# ==========================================

echo "=================================="
echo "💬 Posting GitHub comment"
echo "=================================="

MAX_RETRIES=5

RETRY=1

COMMENT_SUCCESS=false

while [ $RETRY -le $MAX_RETRIES ]; do

  echo "Attempt $RETRY of $MAX_RETRIES"

  if gh issue comment "$ISSUE_NUMBER" \
      --body "$COMMENT"; then

    COMMENT_SUCCESS=true

    echo "✅ GitHub comment posted"

    break

  fi

  echo "⚠️ Comment attempt failed"

  sleep 5

  RETRY=$((RETRY + 1))

done

# ==========================================
# Verify GitHub authentication
# ==========================================

echo "=================================="
echo "🔐 GitHub Authentication"
echo "=================================="

gh auth status || true

# ==========================================
# Hard failure handling
# ==========================================

if [ "$COMMENT_SUCCESS" != true ]; then

  echo "=================================="
  echo "❌ GitHub comment failed"
  echo "=================================="

  exit 1

fi

# ==========================================
# Build dynamic labels
# ==========================================

LABELS=()

# ==========================================
# Base observability labels
# ==========================================

LABELS+=("observability")
LABELS+=("automated-rca")

# ==========================================
# Incident lifecycle labels
# ==========================================

if [[ "$ISSUE_ACTION" =~ closed ]]; then

  LABELS+=("resolved")

  if [ "$GITHUB_ACTOR" = "github-actions[bot]" ]; then

    LABELS+=("auto-resolved")

  else

    LABELS+=("closed-by-user")

  fi

else

  LABELS+=("active-incident")
  LABELS+=("investigating")
  LABELS+=("ongoing")

fi

# ==========================================
# Severity labels
# ==========================================

if [[ "$SEVERITY" =~ Critical|🛑 ]]; then

  LABELS+=("critical")

elif [[ "$SEVERITY" =~ Major|🚨 ]]; then

  LABELS+=("major")

else

  LABELS+=("minor")

fi

# ==========================================
# RCA classification labels
# ==========================================

LOWER_RCA=$(echo "$RCA" \
  | tr '[:upper:]' '[:lower:]')

if [[ "$LOWER_RCA" =~ dns ]]; then

  LABELS+=("dns")

fi

if [[ "$LOWER_RCA" =~ overload|backend|server ]]; then

  LABELS+=("backend")

fi

if [[ "$LOWER_RCA" =~ deployment|testing|staging ]]; then

  LABELS+=("testing")

fi

if [[ "$LOWER_RCA" =~ cloudflare|cdn|provider ]]; then

  LABELS+=("external-service")

fi

if [[ "$LOWER_RCA" =~ network|latency|timeout ]]; then

  LABELS+=("network")

fi

# ==========================================
# Remove duplicate labels
# ==========================================

UNIQUE_LABELS=($(printf "%s\n" "${LABELS[@]}" \
  | sort -u))

# ==========================================
# Cleanup old lifecycle labels
# ==========================================

echo "=================================="
echo "🧹 Cleaning lifecycle labels"
echo "=================================="

if [[ "$ISSUE_ACTION" =~ closed ]]; then

  gh issue edit "$ISSUE_NUMBER" \
    --remove-label "active-incident" \
    --remove-label "investigating" \
    --remove-label "ongoing" || true

else

  gh issue edit "$ISSUE_NUMBER" \
    --remove-label "resolved" \
    --remove-label "auto-resolved" \
    --remove-label "closed-by-user" || true

fi

# ==========================================
# Apply labels
# ==========================================

echo "=================================="
echo "🏷 Applying labels"
echo "=================================="

for LABEL in "${UNIQUE_LABELS[@]}"; do

  echo "Adding label: $LABEL"

  gh issue edit "$ISSUE_NUMBER" \
    --add-label "$LABEL" || true

done

echo "✅ Labels applied"

# ==========================================
# Resolution attribution
# ==========================================

if [[ "$ISSUE_ACTION" =~ closed ]]; then

  if [ "$GITHUB_ACTOR" = "github-actions[bot]" ]; then

    META_COMMENT="🟢 Incident automatically resolved by Upptime recovery detection."

  else

    META_COMMENT="👨‍💻 Incident manually closed by operator @$GITHUB_ACTOR."

  fi

  gh issue comment "$ISSUE_NUMBER" \
    --body "$META_COMMENT" || true

fi

echo "=================================="
echo "✅ GitHub enrichment completed"
echo "=================================="
