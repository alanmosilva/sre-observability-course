# Módulo 12 — Dashboard SRE profissional + HPA + saturação

## Objetivo

Importar o dashboard completo e provocar um incidente de CPU + latência + erros.

---

## 1. Importar dashboard

Grafana:

```text
Dashboards → Import
```

Arquivo:

```text
dashboard-v2-professional.json
```

Ele usa UIDs fixos:

```text
Prometheus = prometheus
Loki       = loki
Tempo      = tempo
```

---

## 2. Aplicar HPA

```bash
kubectl apply -f hpa.yaml
```

Valide:

```bash
kubectl get hpa sre-demo -n sre-lab
```

Configuração:

```text
minReplicas = 2
maxReplicas = 5
CPU target  = 70%
```

---

## 3. Observar baseline

```bash
kubectl top pods -n sre-lab -l app=sre-demo
kubectl get hpa sre-demo -n sre-lab
```

---

## 4. Executar incidente misto

Copie `load-incident.sh` para o `loadgen`:

```bash
kubectl cp load-incident.sh sre-lab/loadgen:/tmp/load-incident.sh
```

Execute:

```bash
kubectl exec -n sre-lab loadgen -- sh /tmp/load-incident.sh
```

Em outro terminal:

```bash
watch -n 2 'kubectl get hpa sre-demo -n sre-lab; echo; kubectl top pods -n sre-lab -l app=sre-demo'
```

---

## 5. O que observar

```text
Traffic ↑
CPU ↑
HPA replicas ↑
p95/p99 ↑
Error Rate ↑
Availability ↓
Burn Rate ↑
```

No nosso exercício real observamos o HPA chegando a:

```text
cpu: 234%/70%
replicas: 5/5
```

Mesmo no máximo de réplicas ainda havia pressão de CPU.

Essa leitura significa:

```text
HPA reagiu corretamente
+
atingiu o teto
+
demanda ainda supera capacidade configurada
```

---

## 6. Ordem correta de investigação

Não comece pela CPU.

```text
1. Availability / Error Rate / Latency
2. SLO / Burn Rate
3. CPU / HPA / Pods
4. Exemplar
5. Tempo
6. Loki
```

Essa ordem começa pelo impacto ao usuário e depois desce para a causa.
