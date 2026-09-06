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

Depois instala Calico via tigera-operator e configura `~/.kube/config` para o usuário que chamou `sudo`.

### Duas variáveis que talvez você precise

**`SINGLE_NODE`** — padrão `true`, que **remove o taint do control-plane**.

Sem isso, num cluster de nó único todo pod fica `Pending` com `node(s) had untolerated taint(s)`, porque o control-plane recusa workloads. Se você **vai adicionar workers** e prefere manter o control-plane dedicado:

```bash
sudo SINGLE_NODE=false ./k8s-lab-install-course.sh master
```

Dá para reverter depois, sem reinstalar:

```bash
# remover o taint
kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule-

# recolocar
kubectl taint nodes --all node-role.kubernetes.io/control-plane=:NoSchedule
```

**`APISERVER_ADVERTISE_ADDRESS`** — vazio por padrão; o kubeadm escolhe pela rota default, o que serve para a maioria dos servidores.

Defina se a máquina tem **várias interfaces** e o kubeadm escolher a errada — sintoma típico é o worker não conseguir se juntar, ou o `kubeadm join` apontar para um IP inacessível:

```bash
sudo APISERVER_ADVERTISE_ADDRESS=192.168.90.17 \
  ./k8s-lab-install-course.sh master
```

Para ver todas as variáveis: `./k8s-lab-install-course.sh` sem argumento.

### O que esperar da saída

O script aguarda, nesta ordem: a CRD do Calico ficar disponível, o `Installation` ser criado, e o node ficar `Ready`. Se o node não ficar `Ready` em 300s, ele imprime os comandos de diagnóstico em vez de seguir em silêncio.

Ao final será exibido um comando semelhante a:

```text
kubeadm join 192.168.x.x:6443 --token ... --discovery-token-ca-cert-hash sha256:...
```

Guarde esse comando.

### Se o CoreDNS ficar `Pending`

```text
0/1 nodes are available: 1 node(s) had untolerated taint(s)
```

**Isso quase nunca é problema do CoreDNS.** É o taint `node.kubernetes.io/not-ready:NoSchedule`, aplicado enquanto o node está `NotReady` — e o node fica `NotReady` até haver CNI. O CoreDNS tolera `control-plane:NoSchedule` e `not-ready:NoExecute`, mas **não** `not-ready:NoSchedule`.

Ou seja: o problema é o Calico. Verifique nesta ordem:

```bash
kubectl get nodes
kubectl get pods -n tigera-operator
kubectl get installation default          # <- o passo que mais falha
kubectl get pods -n calico-system
```

Se `kubectl get installation` retornar `No resources found`, o operator está rodando sem nada para reconciliar. Aplique o CR à mão:

```bash
kubectl apply -f - <<'EOF'
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
    ipPools:
      - name: default-ipv4-ippool
        blockSize: 26
        cidr: 10.244.0.0/16
        encapsulation: VXLANCrossSubnet
        natOutgoing: Enabled
        nodeSelector: all()
EOF
```

Em ~1 minuto o `calico-node` sobe, o node vira `Ready`, o taint sai e o CoreDNS é agendado sozinho.

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
