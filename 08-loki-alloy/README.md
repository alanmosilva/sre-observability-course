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

## Loki — modos de deployment

Loki é o backend responsável por **receber, armazenar e consultar logs**.

Uma característica importante é que o Loki pode rodar de formas diferentes dependendo do tamanho e da criticidade do ambiente.

Hoje existem três modos principais:

| Modo | Como funciona | Quando usar |
|---|---|---|
| **Monolithic** | Todos os componentes do Loki rodam juntos em um único processo/binário. | Labs, ambientes pequenos e cenários simples. |
| **Simple Scalable (SSD)** | Separa Loki em `read`, `write` e `backend`, permitindo escalar essas partes separadamente. | Ambientes intermediários, mas está sendo descontinuado. |
| **Microservices / Distributed** | Cada componente do Loki roda como serviço separado. | Produção em larga escala, alta disponibilidade e necessidade de controle fino. |

### 1. Monolithic

No modo **Monolithic**, todos os componentes ficam dentro do mesmo processo:

```text
        Loki
         │
 ┌───────┼────────┐
 │       │        │
Write   Read   Backend

No nosso laboratório usamos:

deploymentMode: Monolithic
filesystem
replication_factor: 1

Ou seja:

```text
Alloy
  ↓
Loki
  ↓
disco local / filesystem
```

Essa arquitetura é adequada para:

aprendizado;
laboratório;
desenvolvimento;
baixo volume de logs;
ambientes onde perder dados não representa risco crítico.

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

O Alloy pode coletar logs de qualquer aplicação, de todos os Pods de um namespace ou até do cluster inteiro. No nosso curso nós limitamos para sre-lab apenas para deixar o laboratório controlado.

Se você quiser somente uma aplicação específica, por exemplo meuapp dentro do namespace meunamespace:

```text
discovery.relabel "pods" {
  targets = discovery.kubernetes.pods.targets

  rule {
    source_labels = ["__meta_kubernetes_namespace"]
    regex         = "meunamespace"
    action        = "keep"
  }

  rule {
    source_labels = ["__meta_kubernetes_pod_label_app"]
    regex         = "meuapp"
    action        = "keep"
  }
}
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
