#!/usr/bin/env bash
# Helper script to activate individual experimental scenarios (1 to 7)

EXP=${1:-"help"}
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

case "$EXP" in
  1)
    echo ">> Activating Experiment 1: Ratings 3 replicas (Default Traffic)"
    kubectl scale deployment ratings-v1 -n bookinfo --replicas=3
    kubectl delete dr ratings -n bookinfo --ignore-not-found
    ;;
  2)
    echo ">> Activating Experiment 2: Round Robin DestinationRule (20 threads on Grafana)"
    kubectl apply -f "$BASE_DIR/manifests/02-destination-rules/dr-ratings-round-robin.yaml"
    ;;
  3)
    echo ">> Activating Experiment 3: Least Connections DestinationRule (20 threads on Grafana)"
    kubectl apply -f "$BASE_DIR/manifests/02-destination-rules/dr-ratings-least-conn.yaml"
    ;;
  4)
    echo ">> Activating Experiment 4: VirtualService with Weights (4 pods) & Fault Injection"
    kubectl scale deployment ratings-v1 -n bookinfo --replicas=4
    kubectl apply -f "$BASE_DIR/manifests/03-virtual-services/vs-reviews-weights.yaml"
    ;;
  5)
    echo ">> Activating Experiment 5: 5s Fault Injection (200 threads stress test)"
    kubectl apply -f "$BASE_DIR/manifests/04-fault-injection/envoyfilter-ratings-delay-5s.yaml"
    ;;
  6)
    echo ">> Activating Experiment 6: Jaeger Tracing (30 threads with 5s delay)"
    kubectl apply -f "$BASE_DIR/manifests/05-telemetry/tracing-telemetry.yaml"
    kubectl apply -f "$BASE_DIR/manifests/04-fault-injection/envoyfilter-ratings-delay-5s.yaml"
    ;;
  7)
    echo ">> Activating Experiment 7: Consistent Hashing (Header x-user)"
    kubectl delete envoyfilter ratings-single-pod-latency -n bookinfo --ignore-not-found
    kubectl scale deployment ratings-v1 -n bookinfo --replicas=3
    kubectl apply -f "$BASE_DIR/manifests/02-destination-rules/dr-ratings-consistent-hash.yaml"
    ;;
  *)
    echo "Usage: $0 [1|2|3|4|5|6|7]"
    echo "  1: Scaled ratings (3 replicas, default traffic)"
    echo "  2: Round Robin (20 threads on Grafana)"
    echo "  3: Least Connection (20 threads on Grafana)"
    echo "  4: VirtualService Weights (4 pods) & Fault Injection"
    echo "  5: 5s Fault Injection (200 threads)"
    echo "  6: Jaeger Tracing (30 threads with 5s delay)"
    echo "  7: Consistent Hashing (Header x-user vs productpage loss)"
    exit 1
    ;;
esac
