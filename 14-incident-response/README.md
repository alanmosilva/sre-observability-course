# Módulo 14 — Incident Response, Severity e Runbook

## Objetivo

Aprender o que acontece **depois que o alerta chega**.

---

## Severidade

Modelo didático deste curso:

```text
SEV1 = indisponibilidade crítica / impacto amplo
SEV2 = degradação relevante / SLO em risco
SEV3 = degradação menor / sem impacto crítico imediato
```

---

## O que é um Runbook?

O alerta diz:

> Existe um problema.

O runbook diz:

> O que o SRE deve fazer agora.

Arquivo deste módulo:

```text
runbooks/sre-demo-availability.md
```

---

## Fluxo do Runbook

```text
Alerta
 ↓
Confirmar impacto
 ↓
Availability / Error Rate / Burn Rate
 ↓
CPU / Memory / HPA / Pods
 ↓
Prometheus
 ↓
Exemplar
 ↓
Tempo
 ↓
trace_id
 ↓
Loki
 ↓
Mitigação
 ↓
Recovery
```

---

## 1. Simulação controlada

Marque o início:

```bash
echo "INCIDENT START"
date -Is
```

Crie o fault injector:

```bash
kubectl apply -f incident-generator.yaml
```

---

## 2. Quando o alerta/e-mail chegar

```bash
echo "DETECTED"
date -Is
```

Quando você assumir:

```bash
echo "ACKNOWLEDGED"
date -Is
```

---

## 3. Investigar usando o Runbook

Comece pelo impacto no Grafana.

Depois:

```bash
kubectl get hpa sre-demo -n sre-lab
kubectl top pods -n sre-lab -l app=sre-demo
kubectl get pods -n sre-lab -l app=sre-demo -o wide
```

Use Exemplar → Tempo → Loki para correlacionar uma request real.

---

## 4. Mitigar

Marque:

```bash
echo "MITIGATION START"
date -Is
```

Como neste GameDay sabemos que `incident-generator` é a fonte sintética:

```bash
kubectl delete pod incident-generator -n sre-lab
```

---

## 5. Confirmar recuperação

Não marque restore apenas porque deletou o Pod.

Confirme:

```text
Availability recuperando
Error Rate caindo
Latency normalizando
Burn Rate caindo
serviço HTTP 200
```

Então:

```bash
echo "SERVICE RESTORED"
date -Is
```

---

## Regra operacional

Durante SEV1:

```text
restaurar serviço primeiro
investigar profundamente depois
```
