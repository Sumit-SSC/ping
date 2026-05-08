#!/usr/bin/env bash

# ==========================================
# RCA / Root Cause Analysis Engine
# ==========================================
#
# Purpose:
#
# Generates:
# - probable root cause
# - suggested operator checks
# - estimated recovery window
# - severity classification
#
# Inputs:
# - site name
# - latency
#
# Outputs:
# - RCA
# - CHECKS
# - ETA
# - SEVERITY
#
# ==========================================

generate_rca() {

  local SITE="$1"

  local LATENCY="$2"

  RCA=""
  CHECKS=""
  ETA=""
  SEVERITY="⚠️ Minor"

  LOWER=$(echo "$SITE" \
    | tr '[:upper:]' '[:lower:]')

  # ========================================
  # TEST / STAGING ENVIRONMENTS
  # ========================================

  if [[ "$LOWER" =~ test|debug|sandbox|staging|dev ]]; then

    RCA="Possible deployment or testing instability detected."

    CHECKS="• Verify CI/CD pipelines
• Inspect deployment logs
• Review recent commits
• Validate API endpoints
• Check feature flags
• Inspect staging environment health"

    ETA="Likely short-lived"

    SEVERITY="🧪 Testing"

    return
  fi

  # ========================================
  # LARGE PUBLIC SERVICES / CDN
  # ========================================

  if [[ "$LOWER" =~ google|wikipedia|github|cloudflare|amazon|flipkart|youtube|instagram ]]; then

    RCA="Likely provider-side instability or CDN routing disruption."

    CHECKS="• Retry from another network
• Validate local DNS resolution
• Check public outage trackers
• Verify ISP connectivity
• Monitor CDN/provider status pages"

    ETA="Usually transient"

    SEVERITY="🌐 External"

    return
  fi

  # ========================================
  # UNKNOWN LATENCY
  # Usually:
  # - DNS
  # - SSL
  # - hard outage
  # - upstream timeout
  # ========================================

  if [ "$LATENCY" = "unknown" ]; then

    RCA="DNS resolution failure or upstream connectivity disruption."

    CHECKS="• Verify DNS records
• Check SSL certificates
• Inspect Cloudflare dashboard
• Validate hosting provider health
• Verify reverse proxy routing
• Test server reachability"

    ETA="Dependent on infrastructure/provider recovery"

    SEVERITY="🛑 Critical"

    return
  fi

  # ========================================
  # Invalid latency fallback
  # ========================================

  if ! [[ "$LATENCY" =~ ^[0-9]+$ ]]; then

    RCA="Telemetry corruption or invalid latency metrics detected."

    CHECKS="• Verify monitoring agents
• Inspect telemetry ingestion
• Validate Upptime history files
• Check observability persistence"

    ETA="Monitoring telemetry recovery"

    SEVERITY="⚠️ Minor"

    return
  fi

  # ========================================
  # CRITICAL LATENCY
  # ========================================

  if [ "$LATENCY" -gt 5000 ]; then

    RCA="Severe infrastructure overload or upstream service collapse."

    CHECKS="• Check server CPU/RAM utilization
• Inspect database saturation
• Validate reverse proxy health
• Review hosting provider metrics
• Check DDoS / traffic spikes
• Verify deployment stability
• Inspect upstream APIs"

    ETA="15–45 mins"

    SEVERITY="🛑 Critical"

  # ========================================
  # MAJOR LATENCY
  # ========================================

  elif [ "$LATENCY" -gt 3000 ]; then

    RCA="Progressive backend degradation or infrastructure instability."

    CHECKS="• Review application logs
• Inspect resource utilization
• Monitor upstream dependencies
• Validate database responsiveness
• Check container orchestration health"

    ETA="10–30 mins"

    SEVERITY="🚨 Major"

  # ========================================
  # HIGH LATENCY
  # ========================================

  elif [ "$LATENCY" -gt 1500 ]; then

    RCA="High upstream latency and degraded application responsiveness."

    CHECKS="• Verify API response times
• Inspect hosting stability
• Review network bottlenecks
• Monitor DNS performance
• Inspect cache/CDN behavior"

    ETA="5–15 mins"

    SEVERITY="🚨 Major"

  # ========================================
  # MODERATE LATENCY
  # ========================================

  elif [ "$LATENCY" -gt 700 ]; then

    RCA="Elevated latency detected prior to outage event."

    CHECKS="• Verify upstream APIs
• Inspect hosting health
• Review transient traffic spikes
• Monitor DNS health
• Validate SSL handshakes"

    ETA="Monitoring stabilization"

    SEVERITY="⚠️ Moderate"

  # ========================================
  # LOW LATENCY FAILURE
  # Usually:
  # - transient networking
  # - SSL handshake
  # - brief routing issue
  # ========================================

  else

    RCA="Temporary network instability or transient connectivity disruption."

    CHECKS="• Verify SSL certificate validity
• Inspect routing/network path
• Review transient connectivity issues
• Validate upstream reachability"

    ETA="Likely transient"

    SEVERITY="⚠️ Minor"

  fi

  # ========================================
  # Flapping signal enrichment
  # ========================================

  if [ -f "observability/incident-metrics.json" ]; then

    FLAP_COUNT=$(jq -r \
      --arg slug "$(echo "$LOWER" | sed 's/ /-/g')" \
      '.[$slug].incidents // 0' \
      observability/incident-metrics.json)

    if [ "$FLAP_COUNT" -gt 5 ]; then

      RCA="$RCA

Repeated instability patterns detected over historical monitoring."

      CHECKS="$CHECKS
• Inspect recurring failure patterns
• Validate autoscaling behavior
• Review historical incident trends"

      ETA="Potential recurring infrastructure instability"

    fi
  fi
}
