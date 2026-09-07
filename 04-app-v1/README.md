# Módulo 04 — App v1 + Docker Hub + primeiras métricas

## Objetivo

Criar a primeira versão da aplicação e publicar a imagem em:

```text
alanmosilva/sre-demo:v1
```

A v1 terá apenas observabilidade baseada em **métricas Prometheus**.

---

## 1. Criar o repository no Docker Hub

No Docker Hub, faça login com a conta:

```text
alanmosilva
```

No portal:

```text
My Hub → Repositories → Create repository
```

Nome:

```text
sre-demo
```

Para este laboratório, `Public` simplifica o pull do Kubernetes.

> No Docker Hub o termo correto é **repository**, não diretório.

Ao final teremos:

```text
alanmosilva/sre-demo
```

As versões serão representadas por tags:

```text
alanmosilva/sre-demo:v1
alanmosilva/sre-demo:v2
```

---

## 2. Entrar no diretório da aplicação

```bash
cd 04-app-v1/app
```

Arquivos:

```text
app.py
requirements.txt
Dockerfile
```

---

## 3. Entender as métricas

A aplicação possui:

### Counter

```text
sre_demo_http_requests_total
```

Cresce a cada request.

Labels:

```text
method
route
status
```

### Histogram

```text
sre_demo_http_request_duration_seconds
```

Armazena a distribuição de latência e permitirá calcular p95/p99.

### Gauge

```text
sre_demo_http_requests_in_progress
```

Representa requests simultaneamente em processamento.

---

## 4. Login no Docker Hub

```bash
docker login
```

Informe seu usuário:

```text
alanmosilva
```

Use senha/token quando solicitado.

---

## 5. Build da imagem v1

```bash
docker build -t alanmosilva/sre-demo:v1 .
```

Valide:

```bash
docker images | grep sre-demo
```

---

## 6. Testar a imagem localmente

```bash
docker run --rm -p 8080:8080 alanmosilva/sre-demo:v1
```

Em outro terminal:

```bash
curl http://localhost:8080/
curl http://localhost:8080/slow
curl -i http://localhost:8080/error
curl http://localhost:8080/metrics | head
```

Pare o container com `Ctrl+C`.

---

## 7. Push para Docker Hub

```bash
docker push alanmosilva/sre-demo:v1
```

Depois confira no Docker Hub se a tag `v1` apareceu no repository `sre-demo`.

---

## 8. Deploy no Kubernetes

Volte para o diretório do módulo:

```bash
cd ..
```

Aplique os manifests:

```bash
kubectl apply -f k8s/00-namespace.yaml
kubectl apply -f k8s/01-deployment.yaml
kubectl apply -f k8s/02-service.yaml
kubectl apply -f k8s/03-servicemonitor.yaml
kubectl apply -f k8s/04-loadgen.yaml
```

---

## 9. Validar

```bash
kubectl get pods -n sre-lab
kubectl get svc -n sre-lab
kubectl get servicemonitor -n sre-lab
```

Testar por dentro do cluster:

```bash
kubectl exec -n sre-lab loadgen -- \
  curl -s http://sre-demo.sre-lab.svc.cluster.local/
```

---

## 10. Gerar tráfego

```bash
kubectl exec -n sre-lab loadgen -- sh -c '
BASE=http://sre-demo.sre-lab.svc.cluster.local

for i in $(seq 1 100); do
  curl -s $BASE/ >/dev/null
done

for i in $(seq 1 10); do
  curl -s $BASE/slow >/dev/null
done

for i in $(seq 1 5); do
  curl -s $BASE/error >/dev/null
done
'
```

---

## 11. Validar no Prometheus

Abra no painel do Grafana > Explore > selecione Prometheus e execute:

```promql
sre_demo_http_requests_total
```

Depois:

```promql
sum(rate(sre_demo_http_requests_total[5m]))
```

Se retornar dados, concluímos o primeiro pipeline:

```text
App v1 → /metrics → ServiceMonitor → Prometheus
```

---

## Limitações intencionais da v1

A v1 ainda não possui:

```text
logs estruturados
trace_id
OpenTelemetry
Tempo
Exemplars
/healthz dedicado
/cpu
/exception
```

Essas limitações serão corrigidas na v2.
