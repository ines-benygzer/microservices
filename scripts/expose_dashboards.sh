#!/usr/bin/env bash
# Expose Istio Dashboards (Grafana, Jaeger, Kiali) and Ingress Gateway

echo "=========================================================="
echo " Starting Port-Forwarding Tunnels for Observability Stack"
echo "=========================================================="

# Istio Ingress Gateway
echo "[*] Ingress Gateway:  http://localhost:8080/productpage"
kubectl port-forward svc/istio-ingressgateway -n istio-system 8080:80 &
PID_INGRESS=$!

# Grafana (Used for 20 threads & 200 threads tests)
echo "[*] Grafana:          http://localhost:3000"
kubectl port-forward svc/grafana -n istio-system 3000:3000 &
PID_GRAFANA=$!

# Jaeger (Used for 30 threads with 5s delay tracing)
echo "[*] Jaeger Tracing:   http://localhost:16686"
kubectl port-forward svc/tracing -n istio-system 16686:80 &
PID_JAEGER=$!

# Kiali (Used for Service Graph & Traffic distribution)
echo "[*] Kiali Console:    http://localhost:20001/kiali"
kubectl port-forward svc/kiali -n istio-system 20001:20001 &
PID_KIALI=$!

trap "kill $PID_INGRESS $PID_GRAFANA $PID_JAEGER $PID_KIALI 2>/dev/null; exit" SIGINT SIGTERM EXIT

echo "----------------------------------------------------------"
echo "All dashboards are accessible. Press Ctrl+C to terminate."
echo "----------------------------------------------------------"
wait
