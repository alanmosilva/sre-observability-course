# Módulo 08 — Logs com Loki + Grafana Alloy

## Objetivo

Construir:

```text
Pod stdout/stderr
      ↓
Grafana Alloy
      ↓
Loki
      ↓
Grafana
```

---

## Loki

Loki é o backend de logs.

No laboratório usamos modo:

```text
Monolithic
filesystem
replication_factor=1
```

Essa configuração é para laboratório, não para desenho de produção.

---

## Alloy

Alloy executa como DaemonSet e descobre Pods Kubernetes.

No curso ele mantém somente logs do namespace:

```text
sre-lab
```

Labels de baixa cardinalidade:

```text
namespace
pod
container
app
node
cluster
 environment
```

---

## 1. Adicionar repositório Grafana

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

---

## 2. Instalar Loki

```bash
helm upgrade --install loki grafana/loki \
  -n loki \
  --create-namespace \
  -f loki-values.yaml
```

Valide:

```bash
kubectl get pods -n loki
kubectl get svc -n loki
```

O endpoint usado pelo Alloy será:

```text
http://loki-gateway.loki.svc.cluster.local/loki/api/v1/push
```

---

## 3. Instalar Alloy

```bash
helm upgrade --install alloy grafana/alloy \
  -n alloy \
  --create-namespace \
  -f alloy-values.yaml
```

Valide:

```bash
kubectl get pods -n alloy -o wide
```

Como controller é `daemonset`, normalmente haverá um Alloy por node.

---

## 4. Validar datasource Loki

Grafana:

```text
Connections → Data sources → Loki
```

URL provisionada:

```text
http://loki-gateway.loki.svc.cluster.local
```

---

## 5. Testar no Explore

Enquanto a v1 estiver rodando, os logs ainda serão pouco estruturados.

```logql
{namespace="sre-lab"}
```

Depois da v2 teremos queries muito melhores com `| json`.
