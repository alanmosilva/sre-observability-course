# Módulo 13 — Alerting com PrometheusRule + Alertmanager + AWS SES

## Objetivo

Criar um alerta de **Fast Burn de Availability** e entregar o alerta por e-mail.

Fluxo:

```text
PrometheusRule
   ↓
Prometheus
   ↓
Alertmanager
   ↓ SMTP/TLS
AWS SES sa-east-1
   ↓
E-mail
```

---

## 1. Criar alerta

```bash
kubectl apply -f sre-demo-alerts.yaml
```

Valide:

```bash
kubectl get prometheusrule sre-demo-alerts -n monitoring
```

API do Prometheus:

```bash
kubectl exec -n sre-lab loadgen -- \
curl -s \
'http://monitoring-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090/api/v1/rules?type=alert' \
| grep -o 'SREDemoAvailabilityFastBurn'
```

---

## 2. Por que duas janelas?

O alerta usa:

```text
5m  > 14.4x
AND
1h  > 14.4x
```

Isso reduz ruído de picos muito curtos.

---

## 3. Confirmar versão do AlertmanagerConfig

```bash
kubectl get crd alertmanagerconfigs.monitoring.coreos.com \
  -o jsonpath='{range .spec.versions[*]}{.name}{" served="}{.served}{" storage="}{.storage}{"\n"}{end}'
```

No ambiente deste curso observamos:

```text
v1alpha1 served=true storage=true
```

Por isso o template usa `monitoring.coreos.com/v1alpha1`.

---

## 4. Testar conectividade SMTP

Antes de culpar credenciais:

```bash
kubectl run smtp-test \
  -n sre-lab \
  --rm -it \
  --restart=Never \
  --image=nicolaka/netshoot -- \
  nc -vz email-smtp.sa-east-1.amazonaws.com 587
```

Esperado:

```text
succeeded
```

---

## 5. Criar Secret da senha SMTP

Nunca coloque a senha no YAML versionado.

```bash
read -s -p "SES SMTP password: " SMTP_PASS
echo
```

```bash
kubectl create secret generic aws-ses-smtp \
  -n sre-lab \
  --from-literal=password="$SMTP_PASS" \
  --dry-run=client -o yaml | kubectl apply -f -
```

```bash
unset SMTP_PASS
```

---

## 6. Preparar AlertmanagerConfig

Copie o template:

```bash
cp sre-demo-alertmanagerconfig.yaml.template sre-demo-alertmanagerconfig.yaml
```

Edite somente:

```text
<ALERT_DESTINATION_EMAIL>
<SES_VERIFIED_FROM_EMAIL>
<SES_SMTP_USERNAME>
```

Não versione o arquivo final se ele contiver informação sensível que você não deseja publicar.

---

## 7. Dry-run no API Server

```bash
kubectl apply --dry-run=server -f sre-demo-alertmanagerconfig.yaml
```

Depois:

```bash
kubectl apply -f sre-demo-alertmanagerconfig.yaml
```

---

## 8. Gerar Fast Burn

```bash
kubectl exec -n sre-lab loadgen -- sh -c '
BASE=http://sre-demo.sre-lab.svc.cluster.local

echo "Starting Availability incident..."

for w in 1 2 3 4 5 6 7 8 9 10; do
  (
    i=0
    while [ "$i" -lt 180 ]; do
      curl -s "$BASE/error" >/dev/null
      sleep 1
      i=$((i+1))
    done
  ) &
done

wait
'
```

---

## 9. Acompanhar estado do alerta

```bash
watch -n 5 "kubectl exec -n sre-lab loadgen -- \\
curl -sG \\
'http://monitoring-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090/api/v1/query' \\
--data-urlencode 'query=ALERTS{alertname=\"SREDemoAvailabilityFastBurn\"}'"
```

Ciclo:

```text
inactive
 ↓
pending
 ↓ for: 2m
firing
 ↓
AWS SES
 ↓
e-mail
```

Como `sendResolved: true`, após recuperação haverá também um e-mail `RESOLVED`.
