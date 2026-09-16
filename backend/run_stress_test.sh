#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_ENV_FILE="$SCRIPT_DIR/../.env"
API_BASE_URL="${CATU_API_URL:-${PUBLIC_API_URL:-}}"
if [ -z "$API_BASE_URL" ] && [ -f "$ROOT_ENV_FILE" ]; then
  API_BASE_URL=$(sed -n 's/^PUBLIC_API_URL=//p' "$ROOT_ENV_FILE" | head -1)
fi
if [ -z "$API_BASE_URL" ]; then
  echo "Set CATU_API_URL or PUBLIC_API_URL before running this script."
  exit 1
fi

# Obtain JWT Token
echo "Obtaining JWT Token..."
TOKEN=$(curl -s -X POST "$API_BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"phoneNumber":"08098890098","password":"Password123"}' | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
  echo "Failed to obtain JWT token!"
  exit 1
fi
echo "JWT Token obtained successfully."

OUTPUT_FILE="/Users/admin/.gemini/antigravity-cli/brain/4ca0fedb-b965-4717-8685-7b3dc19f9241/stress_test_raw_results.txt"
echo "==========================================================" > "$OUTPUT_FILE"
echo "CATU FULL SYSTEM STRESS TEST REPORT" >> "$OUTPUT_FILE"
echo "Date: $(date)" >> "$OUTPUT_FILE"
echo "Target: $API_BASE_URL" >> "$OUTPUT_FILE"
echo "==========================================================" >> "$OUTPUT_FILE"

# 1. Login Endpoint (POST)
echo ""
echo "[1/8] Stress Testing: POST /auth/login (Auth + Bcrypt + JWT)..."
LOGIN_PAYLOAD="/tmp/catu_login_payload.json"
echo '{"phoneNumber":"08098890098","password":"Password123"}' > "$LOGIN_PAYLOAD"
echo "" >> "$OUTPUT_FILE"
echo "=== FEATURE 1: POST /auth/login (Auth + Bcrypt Verification + JWT) ===" >> "$OUTPUT_FILE"
ab -n 100 -c 10 -p "$LOGIN_PAYLOAD" -T "application/json" "$API_BASE_URL/auth/login" >> "$OUTPUT_FILE" 2>&1
echo "Completed Login test."

# Helper function for GET endpoints
benchmark_get() {
  local feature_num="$1"
  local feature_name="$2"
  local url="$3"
  local count="$4"
  local concurrency="$5"
  
  echo "" >> "$OUTPUT_FILE"
  echo "=== FEATURE $feature_num: $feature_name ($count reqs, c=$concurrency) ===" >> "$OUTPUT_FILE"
  ab -n "$count" -c "$concurrency" -H "Authorization: Bearer $TOKEN" "$url" >> "$OUTPUT_FILE" 2>&1
}

# 2. Keuskupan
echo "[2/8] Stress Testing: GET /auth/keuskupan..."
benchmark_get "2" "GET /auth/keuskupan (Master Data)" "$API_BASE_URL/auth/keuskupan" 500 25
echo "Completed Keuskupan test."

# 3. Paroki
echo "[3/8] Stress Testing: GET /auth/paroki..."
benchmark_get "3" "GET /auth/paroki?keuskupanId=30 (Filtered Master Data)" "$API_BASE_URL/auth/paroki?keuskupanId=30" 500 25
echo "Completed Paroki test."

# 4. News
echo "[4/8] Stress Testing: GET /news?limit=10..."
benchmark_get "4" "GET /news?limit=10 (Public Portal & Feed)" "$API_BASE_URL/news?limit=10" 500 25
echo "Completed News test."

# 5. Orders
echo "[5/8] Stress Testing: GET /orders?userId=9..."
benchmark_get "5" "GET /orders?userId=9 (Transactional Orders List)" "$API_BASE_URL/orders?userId=9" 500 25
echo "Completed Orders test."

# 6. Notifications
echo "[6/8] Stress Testing: GET /notifications?userId=9..."
benchmark_get "6" "GET /notifications?userId=9 (Push Notification History)" "$API_BASE_URL/notifications?userId=9" 500 25
echo "Completed Notifications test."

# 7. Chat Groups (Optimized)
echo "[7/8] Stress Testing: GET /chat/groups?userId=9..."
benchmark_get "7" "GET /chat/groups?userId=9 (Chat Conversation List - Optimized)" "$API_BASE_URL/chat/groups?userId=9" 500 25
echo "Completed Chat Groups test."

# 8. Chat Messages
echo "[8/8] Stress Testing: GET /chat/groups/42/messages?userId=9..."
benchmark_get "8" "GET /chat/groups/42/messages?userId=9 (Chat Message History)" "$API_BASE_URL/chat/groups/42/messages?userId=9" 500 25
echo "Completed Chat Messages test."

echo "" >> "$OUTPUT_FILE"
echo "=== ALL BENCHMARKS COMPLETED SUCCESSFULLY ===" >> "$OUTPUT_FILE"
echo "Stress test script finished successfully."
