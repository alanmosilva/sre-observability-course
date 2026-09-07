# Módulo 06 — SLI, SLO, SLA, Error Budget e Burn Rate

## Objetivo

Parar de olhar apenas CPU e começar a medir confiabilidade do ponto de vista do usuário.

---

## SLI

É o indicador real medido.

Exemplo:

```text
Availability = 99.92%
```

---

## SLO

É a meta interna.

Neste curso:

```text
Availability SLO = 99.9%
Latency SLO      = 99% das requests abaixo de 500ms
```

---

## SLA

É um compromisso formal/contratual. Não confunda com SLO.

---

## Error Budget

Para Availability SLO de 99.9%:

```text
100% - 99.9% = 0.1%
```

Logo:

```text
Error Budget = 0.001
```

---

## Burn Rate

```text
Burn Rate = Error Ratio / Error Budget
```

Exemplo:

```text
Error Ratio = 1%
Budget      = 0.1%
Burn Rate   = 10x
```

---

## 1. Criar recording rules

Recording rules deixam consultas complexas mais rápidas, reutilizáveis e padronizadas. Elas são muito úteis para SLIs, SLOs, dashboards e alertas.

Exemplo: em vez de o Grafana calcular toda hora uma query grande de Availability:

```text
1 -
(
  sum(rate(sre_demo_http_requests_total{status=~"5.."}[5m]))
  /
  sum(rate(sre_demo_http_requests_total[5m]))
)
```

você cria uma recording rule como:

```text
sre_demo:http_availability:ratio5m
```

Aí depois o dashboard, alerta ou outra regra consulta só:

```text
sre_demo:http_availability:ratio5m
```

Crie:

```bash
kubectl apply -f sre-demo-sli.yaml
```

Valide:

```bash
kubectl get prometheusrule -n monitoring sre-demo-sli
```

---

## 2. Por que `release=monitoring`?

Nosso Prometheus usa selector de regras:

```text
release=monitoring
```

Sem esse label o objeto pode existir no Kubernetes, mas o Prometheus não carrega a regra.

Esse foi um erro real encontrado durante o laboratório.

Valide a regra no Prometheus:

```bash
kubectl exec -n sre-lab loadgen -- \
curl -s \
'http://monitoring-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090/api/v1/rules' \
| grep -o 'sre_demo:http_requests:rate5m'
```

---

## 3. Consultar recording rules

```promql
sre_demo:http_requests:rate5m
```

```promql
sre_demo:http_error_ratio:rate5m
```

```promql
sre_demo:http_availability:ratio5m
```

---

## Regra mental

```text
SLI mede.
SLO define a meta.
Error Budget diz quanto pode falhar.
Burn Rate diz quão rápido estamos gastando esse orçamento.
```
