#!/usr/bin/env bash

# ==========================================
# RCA Engine
# ==========================================

generate_rca() {

  local SITE="$1"
  local LATENCY="$2"

  RCA=""
  CHECKS=""
  ETA=""
  SEVERITY="⚠ Minor"

  LOWER=$(echo "$SITE" | tr '[:upper:]' '[:lower:]')

  # ========================================
  # Test / staging sites
  # ========================================

  if [[ "$LOWER" =~ test|staging|sandbox|debug|dev ]]; then

    RCA="Possible deployment/testing instability."

    CHECKS="• CI/CD logs
• API endpoints
• Recent deployments
• Temporary feature toggles"

    ETA="Likely short-lived"

    return
  fi

  # ========================================
  # Public sites
  # ========================================

  if [[ "$LOWER" =~ google|wikipedia ]]; then

    RCA="Likely CDN or provider-side instability."

    CHECKS="• Retry from another network
• Verify local DNS
• Check public outage trackers"

    ETA="Usually transient"

    return
  fi

  # ========================================
  # Latency-based RCA
  # ========================================

  if [[ "$LATENCY" =~ ^[0-9]+$ ]]; then

    if [ "$LATENCY" -gt 2500 ]; then

      RCA="Progressive backend degradation or infrastructure overload."

      CHECKS="• CPU/RAM usage
• Reverse proxy health
• Database latency
• Cloudflare analytics
• Hosting dashboard"

      ETA="10–30 mins"

      SEVERITY="🛑 Critical"

    elif [ "$LATENCY" -gt 1000 ]; then

      RCA="High latency and degraded upstream performance."

      CHECKS="• API response times
• Hosting metrics
• Recent deployments"

      ETA="5–15 mins"

      SEVERITY="🚨 Major"

    else

      RCA="Temporary connectivity instability."

      CHECKS="• DNS health
• SSL validity
• Network routing"

      ETA="Monitoring recovery"

    fi

  else

    RCA="DNS resolution or upstream connectivity issue."

    CHECKS="• DNS records
• SSL certificates
• Hosting provider status
• Cloudflare dashboard"

    ETA="Dependent on provider recovery"

    SEVERITY="🛑 Critical"

  fi
}
