#!/usr/bin/env bash

set -e

MESSAGE="$1"

# ==========================================
# Validate message
# ==========================================

if [ -z "$MESSAGE" ]; then

  echo "❌ Empty Telegram message"

  exit 1

fi

# ==========================================
# Time metadata
# ==========================================

LOCAL_TIME=$(TZ="$SUMMARY_TIMEZONE" \
  date +"%d %b %Y | %I:%M %p")

UTC_TIME=$(date -u +"%H:%M UTC")

# ==========================================
# Footer metadata
# ==========================================

FOOTER="

━━━━━━━━━━━━━━━━━━

🤖 Sumit Observability Stack
📡 Delivered via Telegram Monitoring Bot
🕒 $LOCAL_TIME | 🌍 $UTC_TIME"

FINAL_MESSAGE="$MESSAGE$FOOTER"

# ==========================================
# Telegram message limits
# ==========================================
#
# Telegram max:
# 4096 characters
#
# Keep safe margin for metadata.
#
# ==========================================

MAX_LENGTH=3900

if [ ${#FINAL_MESSAGE} -gt $MAX_LENGTH ]; then

  echo "⚠️ Telegram message too large"
  echo "Truncating payload"

  FINAL_MESSAGE="${FINAL_MESSAGE:0:$MAX_LENGTH}

...[message truncated]"
fi

echo "=================================="
echo "📨 Telegram Delivery Pipeline"
echo "=================================="

echo "Message length: ${#FINAL_MESSAGE}"

# ==========================================
# Build Telegram payload
# ==========================================

if [ -n "$THREAD_ID" ] && [ "$THREAD_ID" != "null" ]; then

  PAYLOAD=$(jq -n \
    --arg chat_id "$CHAT_ID" \
    --arg text "$FINAL_MESSAGE" \
    --argjson thread_id "$THREAD_ID" \
    '{
      chat_id: $chat_id,
      message_thread_id: $thread_id,
      text: $text,
      disable_web_page_preview: true
    }')

else

  # ========================================
  # Non-topic Telegram chats
  # ========================================

  PAYLOAD=$(jq -n \
    --arg chat_id "$CHAT_ID" \
    --arg text "$FINAL_MESSAGE" \
    '{
      chat_id: $chat_id,
      text: $text,
      disable_web_page_preview: true
    }')

fi

# ==========================================
# Telegram retry logic
# ==========================================

MAX_RETRIES=5

RETRY=1

SUCCESS=false

while [ $RETRY -le $MAX_RETRIES ]; do

  echo "=================================="
  echo "📡 Telegram delivery attempt $RETRY"
  echo "=================================="

  RESPONSE=$(curl -s \
    --max-time 30 \
    --retry 2 \
    --retry-delay 3 \
    -X POST \
    "https://api.telegram.org/bot$TG_TOKEN/sendMessage" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD")

  echo "Telegram API Response:"
  echo "$RESPONSE"

  # ========================================
  # Success detection
  # ========================================

  if echo "$RESPONSE" | grep -q '"ok":true'; then

    SUCCESS=true

    echo "✅ Telegram alert delivered"

    break

  fi

  echo "⚠️ Telegram delivery failed"

  # ========================================
  # Parse Telegram error
  # ========================================

  ERROR_DESC=$(echo "$RESPONSE" \
    | jq -r '.description // "Unknown error"')

  echo "Error: $ERROR_DESC"

  sleep 5

  RETRY=$((RETRY + 1))

done

# ==========================================
# Hard failure handling
# ==========================================

if [ "$SUCCESS" != true ]; then

  echo "=================================="
  echo "❌ Telegram delivery failed"
  echo "=================================="

  exit 1

fi

echo "=================================="
echo "✅ Telegram pipeline completed"
echo "=================================="
