# Módulo 10 — Deploy da App v2 e validação dos três sinais

## Objetivo

Substituir v1 por v2 e validar:

```text
Metrics → Prometheus
Logs    → Loki
Traces  → Tempo
```

---

## 1. Aplicar Deployment v2

```bash
kubectl apply -f k8s/01-deployment-v2.yaml
kubectl apply -f k8s/02-service.yaml
kubectl apply -f k8s/03-servicemonitor.yaml
```

---

## 2. Acompanhar rollout

```bash
kubectl rollout status deployment/sre-demo -n sre-lab
```

Confira imagem:

```bash
kubectl get deploy sre-demo -n sre-lab \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

Esperado:

```text
alanmosilva/sre-demo:v2
```

---

## 3. Gerar requests

```bash
kubectl exec -n sre-lab loadgen -- sh -c '
BASE=http://sre-demo.sre-lab.svc.cluster.local

curl -s $BASE/
curl -s $BASE/slow
curl -s $BASE/cpu
curl -s $BASE/error
curl -s $BASE/exception
'
```

---

## 4. Validar Metrics

Prometheus:

```promql
sum(rate(sre_demo_http_requests_total[5m]))
```

---

## 5. Validar Logs

Grafana Explore → Loki:

```logql
{namespace="sre-lab", app="sre-demo"}
| json
| event="http_request"
```

Erros:

```logql
{namespace="sre-lab", app="sre-demo"}
| json
| status >= 500
```

Lentos:

```logql
{namespace="sre-lab", app="sre-demo"}
| json
| duration_ms > 500
```

---

## 6. Validar Traces

Grafana Explore → Tempo:

```traceql
{ resource.service.name = "sre-demo" }
```

Para `/slow`, procure:

```text
GET /slow
└── simulated.wait
```

Para `/cpu`:

```text
GET /cpu
└── simulated.cpu_work
```

---

## Checkpoint

Não avance enquanto os três sinais não estiverem presentes.
