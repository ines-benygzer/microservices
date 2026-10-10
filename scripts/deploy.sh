#!/usr/bin/env bash
set -e

echo "=== 1. Deploying Bookinfo namespace and application ==="
kubectl create namespace bookinfo --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace bookinfo istio-injection=enabled --overwrite

kubectl apply -n bookinfo -f ../manifests/bookinfo.yaml
kubectl apply -n bookinfo -f ../manifests/bookinfo-gateway.yaml

echo "=== 2. Scaling ratings-v1 to 3 replicas ==="
kubectl scale deployment ratings-v1 -n bookinfo --replicas=3

echo "=== 3. Enabling Mesh Telemetry ==="
kubectl apply -f ../telemetry/tracing-telemetry.yaml

echo "=== 4. Waiting for deployment to be ready ==="
kubectl rollout status deployment/ratings-v1 -n bookinfo

echo "=== Deployment finished successfully! ==="
