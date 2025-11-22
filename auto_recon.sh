#!/bin/bash
# auto_recon.sh - simple recon helper (lab-only)
# Usage: ./auto_recon.sh <target|url>
set -euo pipefail

if [ -z "${1-}" ]; then
  echo "Usage: $0 <target|url>"
  exit 1
fi

# tools we need
REQUIRED_TOOLS=(whois dig curl nmap)
MISSING=()
for t in "${REQUIRED_TOOLS[@]}"; do
  if ! command -v "$t" >/dev/null 2>&1; then
    MISSING+=("$t")
  fi
done

if [ "${#MISSING[@]}" -ne 0 ]; then
  echo "Missing tools: ${MISSING[*]}"
  echo "Install them with: sudo apt update && sudo apt install -y ${MISSING[*]}"
  exit 2
fi

RAW="$1"
TARGET_DOMAIN=$(echo "$RAW" | sed -E 's#^https?://##' | sed -E 's#/$##')
OUT="recon_${TARGET_DOMAIN//:/_}.txt"

echo "Recon for: $RAW" > "$OUT"
echo "WHOIS:" >> "$OUT"
whois "$TARGET_DOMAIN" 2>/dev/null | head -n 80 >> "$OUT" || true

echo -e "\nDNS:" >> "$OUT"
dig +short ANY "$TARGET_DOMAIN" 2>/dev/null >> "$OUT" || true

# If user passed a scheme, use that; otherwise assume http
if echo "$RAW" | grep -qE '^https?://'; then
  CURL_URL="$RAW"
else
  CURL_URL="http://$TARGET_DOMAIN"
fi

echo -e "\nHTTP headers: ($CURL_URL)" >> "$OUT"
curl -I -s --max-time 10 "$CURL_URL" | head -n 40 >> "$OUT" || true

echo -e "\nNmap top 100 ports (quick):" >> "$OUT"
# prefer SYN scan if run as root, otherwise use TCP connect scan
if [ "$(id -u)" -eq 0 ]; then
  nmap -sS -Pn -T4 --top-ports 100 "$TARGET_DOMAIN" | grep open >> "$OUT" 2>/dev/null || true
else
  nmap -sT -Pn -T4 --top-ports 100 "$TARGET_DOMAIN" | grep open >> "$OUT" 2>/dev/null || true
fi

echo "Saved -> $OUT"
