#!/usr/bin/env bash
# Multi-threaded load tester simulating concurrent users/threads

TARGET_URL=${TARGET_URL:-"http://localhost:8080/productpage"}
THREADS=${1:-20}
DURATION_SECONDS=${2:-30}

echo "=========================================================="
echo " Running Load Test on: $TARGET_URL"
echo " Concurrency (Threads): $THREADS"
echo " Duration:              ${DURATION_SECONDS}s"
echo "=========================================================="

END_TIME=$((SECONDS + DURATION_SECONDS))
PIDS=()

worker() {
  local id=$1
  local count=0
  while [ $SECONDS -lt $END_TIME ]; do
    curl -s "$TARGET_URL" > /dev/null
    ((count++))
  done
  echo "Thread #$id completed $count requests."
}

for ((i=1; i<=THREADS; i++)); do
  worker "$i" &
  PIDS+=($!)
done

# Wait for all thread workers to complete
for pid in "${PIDS[@]}"; do
  wait "$pid"
done

echo "=========================================================="
echo " Load test completed. Check Grafana / Jaeger / Kiali."
echo "=========================================================="
