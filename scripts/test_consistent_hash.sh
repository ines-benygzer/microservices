#!/usr/bin/env bash
# Demonstrates Experiment 7: Consistent Hashing & Header Propagation Pitfall

echo "=========================================================="
echo " EXPERIMENT 7: Consistent Hashing & Header Propagation"
echo "=========================================================="

echo ""
echo "--- TEST 1: Request via Productpage (Header Lost in Transit) ---"
echo "Sending requests with header 'x-user: user1' to Ingress Gateway..."
echo "Note: The Bookinfo application does NOT propagate 'x-user' to ratings."
echo "Envoy on ratings receives no header -> falls back to ROUND_ROBIN across 3 pods."
echo ""
for i in {1..6}; do
  curl -s -o /dev/null -w "Request $i HTTP Status: %{http_code}\n" -H "x-user: user1" "http://localhost:8080/productpage"
  sleep 0.2
done

echo ""
echo "--- TEST 2: Direct Request to Ratings Service (Header Intact) ---"
echo "We send requests directly to ratings from inside the mesh using curl in a sleep pod."
echo "Here, Envoy receives 'x-user' directly -> Perfect Consistent Hashing stickiness!"
echo ""

# Find a sleep pod or run a test container
RATINGS_CLUSTER_IP=$(kubectl get svc ratings -n bookinfo -o jsonpath='{.spec.clusterIP}')
POD_NAME=$(kubectl get pods -n bookinfo -l app=productpage -o jsonpath='{.items[0].metadata.name}')

echo "Executing curl directly from pod $POD_NAME to ratings ($RATINGS_CLUSTER_IP:9080/ratings/0)..."
echo "[User 1 requests -> should hit same replica consistently]"
for i in {1..4}; do
  kubectl exec -n bookinfo "$POD_NAME" -c productpage -- curl -s -H "x-user: user1" "http://ratings:9080/ratings/0"
  echo ""
done

echo ""
echo "[User 2 requests -> should hit replica dedicated to user2]"
for i in {1..4}; do
  kubectl exec -n bookinfo "$POD_NAME" -c productpage -- curl -s -H "x-user: user2" "http://ratings:9080/ratings/0"
  echo ""
done

echo "=========================================================="
echo " Test complete. Inspect Kiali and ratings pod logs!"
echo "=========================================================="
