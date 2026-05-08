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
# Get slug
# ==========================================

get_slug() {

  local SITE="$1"

  jq -r \
    --arg site "$(echo "$SITE" | tr '[:upper:]' '[:lower:]')" \
    '.[] |
      select((.name | ascii_downcase) == $site) |
      .slug' \
    history/summary.json
}


# ==========================================
# Get site URL
# ==========================================

get_site_url() {

  local SITE="$1"

  URL=$(yq e \
    ".sites[] | select(.name == \"$SITE\") | .url" \
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

  if [ -f "$FILE" ]; then

    LAT=$(grep 'responseTime:' "$FILE" | awk '{print $2}')

    if [ -n "$LAT" ]; then
      echo "$LAT"
    else
      echo "unknown"
    fi

  else
    echo "unknown"
  fi
}

# ==========================================
# Get uptime
# ==========================================

get_uptime() {

  local SITE="$1"

  VALUE=$(jq -r \
    --arg site "$SITE" \
    '.[] | select(.name == $site) | .uptime' \
    history/summary.json)

  if [ -z "$VALUE" ] || [ "$VALUE" = "null" ]; then
    echo "Unknown"
  else
    echo "$VALUE"
  fi
}

# ==========================================
# Get MTTR
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
    '.[$slug].incidents = ((.[$slug].incidents // 0) + 1)' \
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
