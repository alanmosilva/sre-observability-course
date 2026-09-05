# Módulo 11 — Correlação Metrics → Traces → Logs

## Objetivo

Transformar três ferramentas separadas em um fluxo de investigação.

```text
Prometheus
   ↓ Exemplar
Tempo
   ↓ trace_id
Loki
```

---

# Parte A — Loki → Tempo

Grafana:

```text
Connections → Data sources → Loki → Derived fields
```

A configuração já foi provisionada pelo `monitoring-values.yaml`, mas confirme:

```text
Name: TraceID
Regex: "trace_id":"([0-9a-fA-F]{32})"
Internal link: ON
Data source: Tempo
Query: ${__value.raw}
URL label: View Trace
```

Teste:

```logql
{namespace="sre-lab", app="sre-demo"}
| json
| duration_ms > 500
```

Expanda um log e clique em `View Trace`.

---

# Parte B — Tempo → Loki

Tempo datasource → Trace to logs:

```text
Data source: Loki
Start shift: -2s
End shift: +2s
k8s.namespace.name → namespace
Filter by trace ID: ON
Filter by span ID: OFF
```

Teste:

```traceql
{ resource.service.name = "sre-demo" }
```

Abra um trace e use `Logs for this span`.

---

# Parte C — Prometheus → Tempo com Exemplars

Prometheus precisa de:

```text
--enable-feature=exemplar-storage
```

No curso isso já está habilitado em `monitoring-values.yaml`.

A App v2 expõe OpenMetrics e associa `trace_id` às observações do Histogram.

---

## Gerar tráfego lento/CPU

```bash
kubectl exec -n sre-lab loadgen -- sh -c '
BASE=http://sre-demo.sre-lab.svc.cluster.local

for i in $(seq 1 20); do curl -s $BASE/slow >/dev/null; done
for i in $(seq 1 20); do curl -s $BASE/cpu  >/dev/null; done
'
```

Explore → Prometheus:

```promql
sre_demo_http_request_duration_seconds_bucket{route="/slow"}
```

Use `Range` e habilite `Exemplars`.

Clique no marcador do exemplar → `View Trace`.

---

## Por que aparecem poucos Exemplars?

Um exemplar não representa cada request.

No Python client, requests que caem no mesmo bucket podem substituir o exemplar anterior antes do próximo scrape.

Por isso você pode ter centenas de requests e visualizar apenas alguns exemplars.

Isso é esperado.

---

## Validação direta na API do Prometheus

```bash
START=$(date -u -d '10 minutes ago' +%s)
END=$(date -u +%s)

kubectl exec -n sre-lab loadgen -- \
  curl -sG \
  'http://monitoring-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090/api/v1/query_exemplars' \
  --data-urlencode 'query=sre_demo_http_request_duration_seconds_bucket{route="/slow"}' \
  --data-urlencode "start=$START" \
  --data-urlencode "end=$END"
```

---

## Regra de ouro

```text
Métrica mostra QUE existe problema.
Trace mostra ONDE.
Log ajuda a explicar POR QUÊ.
```
