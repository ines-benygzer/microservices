#!/usr/bin/env bash
# Traffic generator script for Istio load balancing experiments

GATEWAY_URL=${GATEWAY_URL:-"http://localhost:8080/productpage"}
MODE=${1:-"continuous"}
REQUEST_COUNT=${2:-100}

case "$MODE" in
  "continuous")
    echo "Generating continuous traffic to $GATEWAY_URL (Ctrl+C to stop)..."
    while true; do
      curl -s "$GATEWAY_URL" > /dev/null
      echo -n "."
      sleep 0.2
    done
    ;;

  "header")
    echo "Simulating sessions for user1 and user2 (Consistent Hashing)..."
    for i in $(seq 1 $REQUEST_COUNT); do
      USER="user$(( (RANDOM % 2) + 1 ))"
      curl -s -H "x-user: $USER" "$GATEWAY_URL" > /dev/null
      echo "Sent request with header x-user: $USER"
      sleep 0.1
    done
    ;;

  "burst")
    echo "Sending $REQUEST_COUNT rapid concurrent requests to test Least Connections..."
    for i in $(seq 1 $REQUEST_COUNT); do
      curl -s "$GATEWAY_URL" > /dev/null &
    done
    wait
    echo "Burst complete."
    ;;

  *)
    echo "Usage: $0 [continuous|header|burst] [request_count]"
    exit 1
    ;;
esac
