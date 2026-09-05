# Módulo 09 — Traces com Tempo + OpenTelemetry Collector

## Objetivo

Construir:

```text
App v2
  ↓ OTLP/HTTP :4318
OpenTelemetry Collector
  ↓ OTLP/gRPC :4317
Tempo
  ↓
Grafana
```

---

## O que é OpenTelemetry?

É um padrão aberto para instrumentação e transporte de telemetria.

Neste laboratório a aplicação usa OpenTelemetry SDK e envia traces via OTLP.

---

## O que é o Collector?

O Collector desacopla a aplicação do backend.

Ele pode:

```text
receber
processar
filtrar
enriquecer
exportar
```

---

## 1. Instalar Tempo

```bash
kubectl apply -f tempo-k8s.yaml
```

Valide:

```bash
kubectl get pods -n tempo
kubectl get svc -n tempo
```

Portas:

```text
3200 Tempo HTTP API
4317 OTLP/gRPC
4318 OTLP/HTTP
```

---

## 2. Instalar OTel Collector

```bash
kubectl apply -f otel-collector.yaml
```

Valide:

```bash
kubectl get pods -n otel
kubectl get svc -n otel
```

---

## 3. Testar portas a partir do cluster

```bash
kubectl run netshoot \
  -n sre-lab \
  --rm -it \
  --restart=Never \
  --image=nicolaka/netshoot -- \
  nc -vz tempo.tempo.svc.cluster.local 3200
```

Repita para `4317` e `4318`.

---

## Troubleshooting real: Tempo 3.0.2

Durante o lab original usamos um bloco antigo:

```yaml
compactor:
  compaction:
    block_retention: 24h
```

Com a imagem Tempo `3.0.2`, a configuração falhou com erro semelhante a:

```text
field compactor not found in type app.Config
```

O manifesto deste curso já remove esse bloco.

---

## 4. Validar datasource Tempo

Grafana → Data sources → Tempo.

URL:

```text
http://tempo.tempo.svc.cluster.local:3200
```

Agora o `Save & test` deve alcançar o serviço.

---

## Observação de produção

Neste lab o Tempo usa `emptyDir` e armazenamento local.

Isso é intencional para estudo e **não representa arquitetura de produção**.
