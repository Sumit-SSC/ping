#!/usr/bin/env bash

set -e

# ==========================================
# Observability metrics DB
# ==========================================

DB="observability/incident-metrics.json"

mkdir -p observability

if [ ! -f "$DB" ]; then
  echo "{}" > "$DB"
fi

# ==========================================
# Normalize site names
# ==========================================

normalize_site() {

  echo "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/^[^[:alnum:]]*//' \
    | sed 's/[[:space:]]*$//' \
    | xargs
}

# ==========================================
# Get slug
# ==========================================

get_slug() {

  local SITE="$1"

  NORMALIZED=$(normalize_site "$SITE")

  SLUG=$(jq -r \
    --arg site "$NORMALIZED" \
    '.[] |
      select((.name | ascii_downcase) == $site) |
      .slug' \
    history/summary.json)

  # fallback slug generation

  if [ -z "$SLUG" ] || [ "$SLUG" = "null" ]; then

    SLUG=$(echo "$NORMALIZED" \
      | sed 's/ /-/g' \
      | sed 's/[^a-z0-9-]//g')

  fi

  echo "$SLUG"
}

# ==========================================
# Get site URL
# ==========================================

get_site_url() {

  local SITE="$1"

  NORMALIZED=$(normalize_site "$SITE")

  URL=$(yq e \
    '.sites[] |
      select((.name | downcase) == "'"$NORMALIZED"'") |
      .url' \
    .upptimerc.yml)

  if [ -z "$URL" ] || [ "$URL" = "null" ]; then
    echo "Unknown"
  else
    echo "$URL"
  fi
}

# ==========================================
# Get latency
# ==========================================

get_latency() {

  local SLUG="$1"

  local FILE="history/$SLUG.yml"

  if [ ! -f "$FILE" ]; then
    echo "unknown"
    return
  fi

  LAT=$(grep 'responseTime:' "$FILE" \
    | tail -1 \
    | awk '{print $2}')

  if [ -z "$LAT" ]; then
    echo "unknown"
  else
    echo "$LAT"
  fi
}

# ==========================================
# Get uptime
# ==========================================

get_uptime() {

  local SITE="$1"

  NORMALIZED=$(normalize_site "$SITE")

  VALUE=$(jq -r \
    --arg site "$NORMALIZED" \
    '.[] |
      select((.name | ascii_downcase) == $site) |
      .uptime' \
    history/summary.json)

  if [ -z "$VALUE" ] || [ "$VALUE" = "null" ]; then
    echo "Unknown"
  else
    echo "$VALUE"
  fi
}

# ==========================================
# Get MTTR historical avg
# ==========================================

get_mttr() {

  local SLUG="$1"

  VALUE=$(jq -r \
    --arg slug "$SLUG" \
    '.[$slug].mttr // 0' \
    "$DB")

  echo "${VALUE:-0}"
}

# ==========================================
# Get incident count
# ==========================================

get_incidents() {

  local SLUG="$1"

  VALUE=$(jq -r \
    --arg slug "$SLUG" \
    '.[$slug].incidents // 0' \
    "$DB")

  echo "${VALUE:-0}"
}

# ==========================================
# Increment incident count
# ==========================================

increment_incidents() {

  local SLUG="$1"

  TMP=$(mktemp)

  jq \
    --arg slug "$SLUG" \
    '.[$slug].incidents =
      ((.[$slug].incidents // 0) + 1)' \
    "$DB" > "$TMP"

  mv "$TMP" "$DB"
}

# ==========================================
# Store outage timestamp
# ==========================================

store_outage_start() {

  local SLUG="$1"

  NOW=$(date +%s)

  TMP=$(mktemp)

  jq \
    --arg slug "$SLUG" \
    --argjson now "$NOW" \
    '.[$slug].last_down = $now' \
    "$DB" > "$TMP"

  mv "$TMP" "$DB"
}

# ==========================================
# Calculate MTTR
# ==========================================

calculate_mttr() {

  local SLUG="$1"

  NOW=$(date +%s)

  START=$(jq -r \
    --arg slug "$SLUG" \
    '.[$slug].last_down // 0' \
    "$DB")

  if [ "$START" -gt 0 ]; then

    DURATION=$((NOW - START))

    TMP=$(mktemp)

    jq \
      --arg slug "$SLUG" \
      --argjson mttr "$DURATION" \
      '.[$slug].mttr = $mttr' \
      "$DB" > "$TMP"

    mv "$TMP" "$DB"

    echo "$DURATION"

  else

    echo "0"

  fi
}

# ==========================================
# Update rolling MTTR
# ==========================================

update_mttr() {

  local SLUG="$1"

  local NEW_MTTR="$2"

  CURRENT=$(jq -r \
    --arg slug "$SLUG" \
    '.[$slug].mttr // 0' \
    "$DB")

  INCIDENTS=$(get_incidents "$SLUG")

  # ========================================
  # First incident
  # ========================================

  if [ "$INCIDENTS" -le 1 ]; then

    AVG="$NEW_MTTR"

  else

    AVG=$(((CURRENT + NEW_MTTR) / 2))

  fi

  TMP=$(mktemp)

  jq \
    --arg slug "$SLUG" \
    --argjson mttr "$AVG" \
    '.[$slug].mttr = $mttr' \
    "$DB" > "$TMP"

  mv "$TMP" "$DB"

  echo "Updated MTTR: $AVG mins"
}
