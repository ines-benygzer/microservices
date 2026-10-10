#!/usr/bin/env bash
# Expose Istio Ingress Gateway and Telemetry Dashboards (Kiali, Jaeger, Grafana)

echo "Starting port-forwarding tunnels..."

# Istio Ingress Gateway
echo "[*] Ingress Gateway:  http://localhost:8080/productpage"
kubectl port-forward svc/istio-ingressgateway -n istio-system 8080:80 &
INGRESS_PID=$!

# Kiali Dashboard
echo "[*] Kiali Dashboard:  http://localhost:20001/kiali"
kubectl port-forward svc/kiali -n istio-system 20001:20001 &
KIALI_PID=$!

# Jaeger Distributed Tracing
echo "[*] Jaeger Tracing:   http://localhost:16686"
kubectl port-forward svc/tracing -n istio-system 16686:80 &
JAEGER_PID=$!

# Grafana Monitoring
echo "[*] Grafana:          http://localhost:3000"
kubectl port-forward svc/grafana -n istio-system 3000:3000 &
GRAFANA_PID=$!

trap "kill $INGRESS_PID $KIALI_PID $JAEGER_PID $GRAFANA_PID 2>/dev/null; exit" SIGINT SIGTERM EXIT

echo "--------------------------------------------------------"
echo "All dashboards ready. Press Ctrl+C to stop all tunnels."
echo "--------------------------------------------------------"
wait
