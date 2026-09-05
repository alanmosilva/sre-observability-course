# Módulo 02 — Preparando o ambiente Kubernetes com kubeadm

## Objetivo

Criar um cluster Kubernetes de laboratório usando o script de bootstrap fornecido para o curso.

O script original instala e configura:

- Docker Engine;
- containerd;
- kubeadm;
- kubelet;
- kubectl;
- crictl;
- Calico;
- MetalLB;
- ingress-nginx;
- Gateway API CRDs;
- local-path-provisioner;
- Metrics Server;
- Helm;
- AWS CLI opcional;
- configuração de SSH keepalive;
- suporte opcional a ECR.

A versão original foi preservada em:

```text
scripts/k8s-lab-install-original.sh
```

Para o curso usaremos:

```text
scripts/k8s-lab-install-course.sh
```

A única mudança relevante da edição do curso é **não instalar Prometheus/Grafana automaticamente**. Faremos isso no próximo módulo com persistência, credenciais e UIDs de datasource definidos desde o primeiro deploy.

---

## 1. Topologia mínima recomendada

Exemplo:

```text
control-plane  2 vCPU / 4 GiB RAM
worker         2-4 vCPU / 4-8 GiB RAM
```

Sistema operacional:

```text
Ubuntu 22.04 ou 24.04
```

Kubernetes do curso:

```text
v1.35
```

Pod CIDR:

```text
10.244.0.0/16
```

> O `POD_CIDR` não pode sobrepor a rede física dos nodes.

---

## 2. Copiar o script para os nodes

No control-plane:

```bash
mkdir -p ~/sre-course
cd ~/sre-course
```

Copie `k8s-lab-install-course.sh` para esse diretório e dê permissão:

```bash
chmod +x k8s-lab-install-course.sh
```

Valide:

```bash
./k8s-lab-install-course.sh
```

Sem argumentos ele mostra a ajuda.

---

## 3. Preparar o control-plane

Execute como root porque essa fase altera kernel, swap, pacotes e serviços:

```bash
sudo ./k8s-lab-install-course.sh common
```

O comando executa, entre outras coisas:

```text
swapoff
br_netfilter
ip_forward
Docker
containerd + SystemdCgroup
kubeadm/kubelet/kubectl
crictl
SSH keepalive
```

Confira versões:

```bash
kubeadm version -o short
kubectl version --client
kubelet --version
containerd --version
docker --version
crictl --version
```

---

## 4. Inicializar o control-plane

```bash
sudo ./k8s-lab-install-course.sh master
```

Esse passo executa conceitualmente:

```bash
kubeadm init --pod-network-cidr=10.244.0.0/16
```

Depois instala Calico e configura `~/.kube/config` para o usuário que chamou `sudo`.

Ao final será exibido um comando semelhante a:

```text
kubeadm join 192.168.x.x:6443 --token ... --discovery-token-ca-cert-hash sha256:...
```

Guarde esse comando.

---

## 5. Preparar um worker

No worker:

```bash
chmod +x k8s-lab-install-course.sh
sudo ./k8s-lab-install-course.sh common
```

Depois utilize o comando de join entregue pelo control-plane:

```bash
sudo ./k8s-lab-install-course.sh worker "kubeadm join <CONTROL_PLANE_IP>:6443 --token <TOKEN> --discovery-token-ca-cert-hash sha256:<HASH>"
```

---

## 6. Validar nodes

No control-plane:

```bash
kubectl get nodes -o wide
```

Esperado:

```text
NAME            STATUS   ROLES           VERSION
control-plane   Ready    control-plane   v1.35.x
worker          Ready    <none>          v1.35.x
```

---

## 7. Instalar addons

Antes, escolha IPs livres para o MetalLB.

Exemplo:

```bash
export METALLB_POOL=192.168.30.230-192.168.30.240
```

> Troque pelo intervalo livre da sua LAN. Não copie esse exemplo sem confirmar a sua rede.

Execute **sem sudo**, porque o comando precisa usar o seu kubeconfig:

```bash
INSTALL_MONITORING=false \
METALLB_POOL="$METALLB_POOL" \
./k8s-lab-install-course.sh addons
```

Serão instalados:

```text
MetalLB
ingress-nginx
Gateway API CRDs
local-path-provisioner
Metrics Server
Helm
```

Prometheus/Grafana ficam para o Módulo 03.

---

## 8. Validar addons

```bash
./k8s-lab-install-course.sh status
```

Valide individualmente:

```bash
kubectl get pods -A
kubectl get storageclass
kubectl get svc -n ingress-nginx
kubectl get ipaddresspool,l2advertisement -n metallb-system
kubectl top nodes
```

A StorageClass `local-path` deve ser default.

---

## 9. Criar o namespace do laboratório

O script já cria `sre-lab` durante `addons`, mas valide:

```bash
kubectl get namespace sre-lab
```

Se necessário:

```bash
kubectl create namespace sre-lab
```

---

## Checkpoint

Antes de seguir você deve ter:

```text
[ ] control-plane Ready
[ ] worker Ready
[ ] Calico funcionando
[ ] MetalLB configurado
[ ] ingress-nginx com EXTERNAL-IP
[ ] local-path como StorageClass
[ ] Metrics Server respondendo kubectl top
[ ] Helm instalado
[ ] namespace sre-lab criado
```
