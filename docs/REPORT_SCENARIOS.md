# Comprehensive Experimental Report: Istio Service Mesh Load Balancing & Traffic Routing

**Environment:** Kubernetes (Minikube) & Istio Service Mesh  
**Target Application:** Istio Bookinfo Sample (`productpage`, `reviews`, `ratings`, `details`)  
**Observability Stack:** Grafana, Jaeger (Distributed Tracing), Kiali (Service Mesh Topology Graph)

---

## Executive Summary & Experimental Scenarios

1. [Experiment 1: Service Replication & Default Traffic Observation (3 Pods)](#experiment-1-service-replication--default-traffic-observation-3-pods)
2. [Experiment 2: DestinationRule Round Robin with Grafana (20 Threads)](#experiment-2-destinationrule-round-robin-with-grafana-20-threads)
3. [Experiment 3: DestinationRule Least Connections with Grafana (20 Threads)](#experiment-3-destinationrule-least-connections-with-grafana-20-threads)
4. [Experiment 4: VirtualService Weight-Based Routing (4 Pods) & Fault Injection](#experiment-4-virtualservice-weight-based-routing-4-pods--fault-injection)
5. [Experiment 5: 5-Second Fault Injection Stress Test (200 Threads)](#experiment-5-5-second-fault-injection-stress-test-200-threads)
6. [Experiment 6: Distributed Tracing with Jaeger (30 Threads, 5s Delay, 3 Pods)](#experiment-6-distributed-tracing-with-jaeger-30-threads-5s-delay-3-pods)
7. [Experiment 7: Consistent Hashing & The HTTP Header Propagation Pitfall](#experiment-7-consistent-hashing--the-http-header-propagation-pitfall)

---

## Experiment 1: Service Replication & Default Traffic Observation (3 Pods)

### Objective

Examine how Istio / Envoy natively handles traffic distribution across identical service endpoints without any user-defined `DestinationRule`.

### Protocol & Setup

1. Scaled `ratings-v1` deployment to 3 replicas:
   ```bash
   kubectl scale deployment ratings-v1 -n bookinfo --replicas=3
   ```
2. Injected baseline continuous traffic through the Ingress Gateway:
   ```bash
   curl http://localhost:8080/productpage
   ```

### Findings & Observations

By default, the Envoy sidecar proxies attached to caller services (`reviews-v2` / `reviews-v3`) apply a built-in pseudo-Round Robin load balancing algorithm across all healthy endpoints in the Kubernetes cluster. In Kiali, the traffic is evenly spread across the 3 pods (~33.3% per pod).

_(Screenshot placeholder: `docs/images/exp1-ratings-replication/`)_

---

## Experiment 2: DestinationRule Round Robin with Grafana (20 Threads)

### Objective

Explicitly declare a `ROUND_ROBIN` load balancing policy using an Istio `DestinationRule` and quantitatively analyze request distribution under a stable multi-threaded workload.

### Applied Configuration

```yaml
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: ratings
  namespace: bookinfo
spec:
  host: ratings
  trafficPolicy:
    loadBalancer:
      simple: ROUND_ROBIN
```

### Load Profile & Observability

- **Concurrency:** 20 concurrent worker threads executing continuous HTTP requests.
- **Observability Tool:** **Grafana** (Istio Workload / Service Dashboard displaying Envoy `upstream_rq_completed` and RPS per pod).

### Results & Analysis

On the Grafana dashboard, the request-per-second curves for each of the 3 `ratings` pods overlap almost identically. Sequential dispatching ensures strict mathematical parity among backend replicas when per-request processing times remain uniform.

_(Screenshot placeholder for your 2 Grafana captures: `docs/images/exp2-round-robin-grafana-20threads/`)_

---

## Experiment 3: DestinationRule Least Connections with Grafana (20 Threads)

### Objective

Evaluate the `LEAST_CONN` load balancing algorithm, which directs incoming requests to the backend pod currently handling the lowest number of active TCP/HTTP connections.

### Applied Configuration

```yaml
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: ratings
  namespace: bookinfo
spec:
  host: ratings
  trafficPolicy:
    loadBalancer:
      simple: LEAST_CONN
```

### Results & Comparative Analysis

Under a benchmark of **20 concurrent threads** with rapid, non-blocking HTTP requests (<10ms per response), the distribution on Grafana closely mimics Round Robin. Because transactions complete almost instantly, the active connection pool drains continuously, preventing significant connection disparity. `LEAST_CONN` proves its true value when workloads exhibit variable latency or long-lived I/O operations.

_(Screenshot placeholder for your Grafana capture: `docs/images/exp3-least-connection-grafana-20threads/`)_

---

## Experiment 4: VirtualService Weight-Based Routing (4 Pods) & Fault Injection

### Objective

Investigate how Layer 7 routing rules in a `VirtualService` (percentage weight splitting across 4 pods / subsets) interact with `DestinationRule` load balancing algorithms (`LEAST_CONN` and `ROUND_ROBIN`), while introducing intentional faults into the system.

### Applied Configuration

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: ratings
  namespace: bookinfo
spec:
  hosts:
    - ratings
  http:
    - route:
        - destination:
            host: ratings
            subset: v1
          weight: 75
        - destination:
            host: ratings
            subset: v2
          weight: 25
```

### Key Architectural Finding

Routing precedence is strictly hierarchical:

1. The **`VirtualService` weight rule** evaluates first at the routing phase (directing 75% of total requests to subset `v1` and 25% to subset `v2`).
2. The **`DestinationRule` load balancing policy** (`ROUND_ROBIN` or `LEAST_CONN`) then independently arbitrates traffic _within_ the selected subset's underlying pods.
3. Injected faults or latency affect the subset according to its declared traffic weight, proving that weights govern upstream route selection prior to downstream connection dispatching.

_(Screenshot placeholder: `docs/images/exp4-virtualservice-weights-fault-injection/`)_

---

## Experiment 5: 5-Second Fault Injection Stress Test (200 Threads)

### Objective

Stress-test Service Mesh resilience and connection pooling by deliberately injecting a massive **5-second latency** (`fixed_delay: 5s`) onto a targeted backend pod while bombarding the mesh with **200 concurrent threads**.

### Fault Injection Manifest (EnvoyFilter)

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: ratings-single-pod-latency
  namespace: bookinfo
spec:
  workloadSelector:
    labels:
      app: ratings
      status: slow
  configPatches:
    - applyTo: HTTP_FILTER
      patch:
        value:
          name: envoy.filters.http.fault
          typed_config:
            "@type": type.googleapis.com/envoy.extensions.filters.http.fault.v3.HTTPFault
            delay:
              fixed_delay: 5s
              percentage:
                numerator: 100
                denominator: HUNDRED
```

### Extreme Concurrency Analysis

- **Under Round Robin:** Envoy continues cycling traffic blindly to the delayed pod (1 out of every 3 requests). As a result, client threads freeze for 5 seconds, worker pools exhaust, and overall system throughput crashes catastrophically.
- **Under Least Connections:** As the first requests hit the slow pod, its active connection count explodes (accumulating dozens of pending connections). Envoy immediately detects this backlog and reroutes subsequent incoming traffic to the healthy, fast replicas. The overall system stays responsive with normal sub-second latencies!

_(Screenshot placeholder: `docs/images/exp5-fault-injection-5s-200threads/`)_

---

## Experiment 6: Distributed Tracing with Jaeger (30 Threads, 5s Delay, 3 Pods)

### Objective

Inspect end-to-end distributed transaction spans across microservices (`productpage` $\to$ `reviews` $\to$ `ratings`) using **Jaeger** to visualize request latency propagation under a 30-thread load with a 5s delay on 3 pods.

### Protocol

- Configured Istio `Telemetry` resource with 100% trace sampling.
- Applied the 5-second delay filter on one pod replica.
- Generated a continuous 30-thread workload.

### Jaeger Trace Inspection

In the Jaeger UI:

1. Spans clearly decompose latency per microservice hop.
2. Under **Round Robin**, traces illustrate a distinct cyclic pattern: 1 out of 3 traces contains a massive 5000ms duration span on the `ratings` hop, holding the entire upstream chain open.
3. Under **Least Connections**, only the initial burst traces register the 5s penalty; all subsequent traces show that Envoy dynamically bypasses the congested pod, completing the trace in <20ms.

_(Screenshot placeholder for your Jaeger traces: `docs/images/exp6-jaeger-tracing-5s-30threads/`)_

---

## Experiment 7: Consistent Hashing & The HTTP Header Propagation Pitfall

### Objective & Crucial Mesh Discovery

Configure session affinity using a `CONSISTENT_HASH` policy based on a custom HTTP header (`x-user`) and investigate why real-world microservice architectures often break this policy if headers are not explicitly propagated.

### The Header Loss Discovery (Productpage Fallback)

When calling the application from the edge through the Ingress Gateway:

```bash
curl -H "x-user: user1" http://localhost:8080/productpage
```

**Observation:** Traffic continues to be distributed via **Round Robin across all 3 pods**!  
**Root Cause:** The default Python / Node.js application code of `productpage` and `reviews` forwards standard tracing headers (`x-request-id`, `x-b3-*`), but **discards** custom headers such as `x-user`. When the downstream Envoy sidecar on `ratings` receives the request, the `x-user` header is missing. Istio therefore falls back to its default load balancing behavior (**Round Robin**).

### Validating True Consistent Hashing (Direct Ratings Request)

To verify that the Istio `DestinationRule` configuration is valid, requests were dispatched directly to `ratings` within the mesh, preserving the header:

```bash
curl -H "x-user: user1" http://ratings:9080/ratings/0
```

**Result:**

- Requests with `x-user: user1` are **100% routed to Replica #1**.
- Requests with `x-user: user2` are **100% routed to Replica #2**.
- True deterministic session stickiness is established without state replication.

_(Screenshot placeholder for the 2 figures: `docs/images/exp7-consistent-hashing-header-propagation/`)_

---

## Key Engineering Takeaways

1. **Telemetry Triad:** Grafana gives aggregate RPS and connection health; Jaeger visualizes per-hop latency cascades; Kiali proves topological route distribution.
2. **Resilience Engineering:** `LEAST_CONN` acts as an automated circuit-level shock absorber during partial service degradation or latency spikes.
3. **Application Contract:** Layer 7 service mesh intelligence requires microservices to strictly propagate context headers throughout all internal downstream hops.
