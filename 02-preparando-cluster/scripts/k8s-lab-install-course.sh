#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# Kubernetes Lab Bootstrap - kubeadm + Calico + MetalLB
# Ingress NGINX + Gateway API + local-path storage + Metrics Server
# Prometheus/Grafana + AWS CLI + Docker + crictl
# SSH keepalive + ECR imagePullSecret
#
# Default target: Ubuntu 22.04/24.04 + Kubernetes v1.35
#
# USAGE:
#   sudo ./k8s-lab-install.sh common
#   sudo ./k8s-lab-install.sh master
#   sudo ./k8s-lab-install.sh worker "<kubeadm join ...>"
#   sudo ./k8s-lab-install.sh addons
#   sudo ./k8s-lab-install.sh ecr
#   sudo ./k8s-lab-install.sh ssh
#
# Typical sequence:
#
# MASTER:
#   sudo ./k8s-lab-install.sh common
#   sudo ./k8s-lab-install.sh master
#   ./k8s-lab-install.sh addons
#
# WORKER:
#   sudo ./k8s-lab-install.sh common
#   sudo ./k8s-lab-install.sh worker "kubeadm join ..."
#
# ECR:
#   ./k8s-lab-install.sh ecr
#
# IMPORTANT:
# - Review the variables below before use.
# - METALLB_POOL must contain FREE IPs on your LAN.
# - POD_CIDR must NOT overlap your physical network.
# ============================================================

# ----------------------------
# USER CONFIGURATION
# ----------------------------
K8S_MINOR="${K8S_MINOR:-v1.35}"
POD_CIDR="${POD_CIDR:-10.244.0.0/16}"

# kubeadm default; declared here so the MetalLB pool can be validated against it
SERVICE_CIDR="${SERVICE_CIDR:-10.96.0.0/12}"

CALICO_VERSION="${CALICO_VERSION:-v3.32.1}"
METALLB_VERSION="${METALLB_VERSION:-v0.16.1}"

# Rancher local-path-provisioner: node-local PersistentVolumes under LOCAL_PATH_DIR.
# Set LOCAL_PATH_DEFAULT_CLASS=false to install it without making it the default class.
LOCAL_PATH_VERSION="${LOCAL_PATH_VERSION:-v0.0.37}"
LOCAL_PATH_DEFAULT_CLASS="${LOCAL_PATH_DEFAULT_CLASS:-true}"

# MetalLB pool of FREE IPs on your LAN, as "START-END" or a CIDR.
# Leave empty to derive it from this host's primary LAN subnet (x.y.z.240-x.y.z.250).
# It must be on the same L2 segment as the nodes, otherwise services get an
# EXTERNAL-IP that nothing on the network can reach.
METALLB_POOL="${METALLB_POOL:-}"

# Gateway API standard CRDs
GATEWAY_API_VERSION="${GATEWAY_API_VERSION:-v1.4.0}"

# Namespace used by the application lab
APP_NAMESPACE="${APP_NAMESPACE:-sre-lab}"

# AWS / ECR
AWS_REGION="${AWS_REGION:-sa-east-1}"
ECR_SECRET_NAME="${ECR_SECRET_NAME:-ecr-secret}"

# Monitoring
MONITORING_NAMESPACE="${MONITORING_NAMESPACE:-monitoring}"

# Course edition: monitoring is installed later with persistent Grafana values.
INSTALL_MONITORING="${INSTALL_MONITORING:-false}"

# Set to true if this is a lab where kubelet cert validation blocks Metrics Server
METRICS_INSECURE_TLS="${METRICS_INSECURE_TLS:-true}"

# ----------------------------
# HELPERS
# ----------------------------
log() {
  echo
  echo "============================================================"
  echo ">>> $*"
  echo "============================================================"
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

require_root() {
  [[ "${EUID}" -eq 0 ]] || die "Run this command with sudo/root."
}

require_non_root_kubectl() {
  command -v kubectl >/dev/null 2>&1 || die "kubectl not found."
  kubectl cluster-info >/dev/null 2>&1 || die "kubectl cannot reach the cluster."
}

wait_for_rollout() {
  local kind="$1"
  local name="$2"
  local ns="$3"
  kubectl rollout status "${kind}/${name}" -n "${ns}" --timeout=180s || true
}

# ----------------------------
# IP RANGE HELPERS (MetalLB validation)
# ----------------------------
ip_to_int() {
  local IFS=. a b c d
  read -r a b c d <<<"$1"
  echo $(( (a << 24) + (b << 16) + (c << 8) + d ))
}

# Prints "first last" as integers for either "A.B.C.D-A.B.C.E" or "A.B.C.D/N"
range_bounds() {
  local r="$1" net bits first mask

  if [[ "${r}" == */* ]]; then
    net="${r%/*}"
    bits="${r#*/}"
    first="$(ip_to_int "${net}")"
    mask=$(( (0xFFFFFFFF << (32 - bits)) & 0xFFFFFFFF ))
    first=$(( first & mask ))
    echo "${first} $(( first | (~mask & 0xFFFFFFFF) ))"
  else
    echo "$(ip_to_int "${r%%-*}") $(ip_to_int "${r##*-}")"
  fi
}

ranges_overlap() {
  local a1 a2 b1 b2
  read -r a1 a2 <<<"$(range_bounds "$1")"
  read -r b1 b2 <<<"$(range_bounds "$2")"
  (( a1 <= b2 && b1 <= a2 ))
}

# This host's primary LAN IPv4 (the source address used to reach the default gateway)
primary_ipv4() {
  ip -4 route get 1.1.1.1 2>/dev/null \
    | awk '{ for (i = 1; i <= NF; i++) if ($i == "src") { print $(i + 1); exit } }'
}

derive_metallb_pool() {
  local ip prefix
  ip="$(primary_ipv4)"
  [[ -n "${ip}" ]] || return 1
  prefix="${ip%.*}"
  echo "${prefix}.240-${prefix}.250"
}

# Refuses pools that overlap the cluster's internal CIDRs or sit off the node subnet
validate_metallb_pool() {
  local pool="$1" node_ip node_prefix pool_start

  if ranges_overlap "${pool}" "${POD_CIDR}"; then
    die "METALLB_POOL (${pool}) overlaps POD_CIDR (${POD_CIDR}). Pick free IPs on your LAN."
  fi

  if ranges_overlap "${pool}" "${SERVICE_CIDR}"; then
    die "METALLB_POOL (${pool}) overlaps SERVICE_CIDR (${SERVICE_CIDR}). Pick free IPs on your LAN."
  fi

  node_ip="$(primary_ipv4)"
  if [[ -n "${node_ip}" ]]; then
    node_prefix="${node_ip%.*}"
    pool_start="${pool%%-*}"
    pool_start="${pool_start%%/*}"

    if [[ "${pool_start%.*}" != "${node_prefix}" ]]; then
      echo "WARNING: METALLB_POOL (${pool}) is not on this node's subnet (${node_prefix}.0/24)." >&2
      echo "         L2 mode only answers ARP on the node's own segment, so those" >&2
      echo "         EXTERNAL-IPs will be unreachable unless your network routes them here." >&2
    fi
  fi
}

# Enforces the "POD_CIDR must NOT overlap your physical network" rule from the header
validate_pod_cidr() {
  local cidr="$1" node_ip node_prefix

  node_ip="$(primary_ipv4)"
  [[ -n "${node_ip}" ]] || return 0

  node_prefix="${node_ip%.*}"

  if ranges_overlap "${cidr}" "${node_prefix}.0/24"; then
    die "POD_CIDR (${cidr}) overlaps this node's LAN (${node_prefix}.0/24). Use a range outside it, e.g. 10.244.0.0/16"
  fi
}

# ----------------------------
# COMMON NODE PREPARATION
# ----------------------------
install_common() {
  require_root

  log "Disabling swap"
  swapoff -a
  sed -ri '/\sswap\s/s/^#?/#/' /etc/fstab || true

  log "Loading kernel modules"
  cat >/etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF

  modprobe overlay
  modprobe br_netfilter

  cat >/etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

  sysctl --system >/dev/null

  log "Installing base packages"
  apt-get update
  apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gpg \
    wget \
    unzip \
    jq \
    conntrack \
    socat

  # ----------------------------------------------------------
  # Docker Engine + containerd.io
  # Kubernetes will continue to use containerd directly.
  # ----------------------------------------------------------
  log "Installing Docker Engine and containerd"

  install -m 0755 -d /etc/apt/keyrings

  if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
      | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
  fi

  . /etc/os-release

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
    >/etc/apt/sources.list.d/docker.list

  apt-get update

  apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

  systemctl enable --now docker
  systemctl enable --now containerd

  log "Configuring containerd with systemd cgroups"

  mkdir -p /etc/containerd
  containerd config default >/etc/containerd/config.toml

  sed -i \
    's/SystemdCgroup = false/SystemdCgroup = true/' \
    /etc/containerd/config.toml

  systemctl restart containerd

  # ----------------------------------------------------------
  # Kubernetes
  # ----------------------------------------------------------
  log "Installing kubeadm, kubelet and kubectl (${K8S_MINOR})"

  install -m 0755 -d /etc/apt/keyrings

  curl -fsSL "https://pkgs.k8s.io/core:/stable:/${K8S_MINOR}/deb/Release.key" \
    | gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

  echo \
    "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_MINOR}/deb/ /" \
    >/etc/apt/sources.list.d/kubernetes.list

  apt-get update
  apt-get install -y kubelet kubeadm kubectl
  apt-mark hold kubelet kubeadm kubectl

  systemctl enable --now kubelet || true

  # ----------------------------------------------------------
  # crictl
  # Match crictl minor to Kubernetes minor.
  # Example: v1.35 -> v1.35.0
  # ----------------------------------------------------------
  local crictl_version
  crictl_version="${K8S_MINOR}.0"

  log "Installing crictl ${crictl_version}"

  local arch
  arch="$(dpkg --print-architecture)"
  case "$arch" in
    amd64) cri_arch="amd64" ;;
    arm64) cri_arch="arm64" ;;
    *) die "Unsupported architecture for crictl: $arch" ;;
  esac

  curl -fsSLO \
    "https://github.com/kubernetes-sigs/cri-tools/releases/download/${crictl_version}/crictl-${crictl_version}-linux-${cri_arch}.tar.gz"

  tar -xzf "crictl-${crictl_version}-linux-${cri_arch}.tar.gz" -C /usr/local/bin
  rm -f "crictl-${crictl_version}-linux-${cri_arch}.tar.gz"

  cat >/etc/crictl.yaml <<EOF
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF

  log "Configuring SSH keepalive"

  if grep -qE '^[# ]*ClientAliveInterval' /etc/ssh/sshd_config; then
    sed -ri 's/^[# ]*ClientAliveInterval.*/ClientAliveInterval 60/' /etc/ssh/sshd_config
  else
    echo 'ClientAliveInterval 60' >>/etc/ssh/sshd_config
  fi

  if grep -qE '^[# ]*ClientAliveCountMax' /etc/ssh/sshd_config; then
    sed -ri 's/^[# ]*ClientAliveCountMax.*/ClientAliveCountMax 10/' /etc/ssh/sshd_config
  else
    echo 'ClientAliveCountMax 10' >>/etc/ssh/sshd_config
  fi

  if grep -qE '^[# ]*TCPKeepAlive' /etc/ssh/sshd_config; then
    sed -ri 's/^[# ]*TCPKeepAlive.*/TCPKeepAlive yes/' /etc/ssh/sshd_config
  else
    echo 'TCPKeepAlive yes' >>/etc/ssh/sshd_config
  fi

  sshd -t
  systemctl restart ssh

  log "Common node preparation complete"

  echo "Versions:"
  kubeadm version -o short || true
  kubectl version --client || true
  kubelet --version || true
  containerd --version || true
  docker --version || true
  crictl --version || true
}

# ----------------------------
# CONTROL PLANE
# ----------------------------
init_master() {
  require_root

  log "Initializing Kubernetes control plane"

  if [[ -f /etc/kubernetes/admin.conf ]]; then
    echo "/etc/kubernetes/admin.conf already exists."
    echo "Skipping kubeadm init."
  else
    kubeadm init \
      --pod-network-cidr="${POD_CIDR}"
  fi

  # Configure kubectl for the original sudo user
  local target_user="${SUDO_USER:-root}"
  local target_home

  if [[ "${target_user}" == "root" ]]; then
    target_home="/root"
  else
    target_home="$(getent passwd "${target_user}" | cut -d: -f6)"
  fi

  mkdir -p "${target_home}/.kube"
  cp -f /etc/kubernetes/admin.conf "${target_home}/.kube/config"
  chown -R "${target_user}:${target_user}" "${target_home}/.kube"

  export KUBECONFIG=/etc/kubernetes/admin.conf

  log "Installing Calico ${CALICO_VERSION} (tigera-operator)"

  validate_pod_cidr "${POD_CIDR}"

  # Server-side apply: tigera-operator.yaml carries CRDs too large for the
  # client-side last-applied-configuration annotation.
  kubectl apply --server-side --force-conflicts -f \
    "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/tigera-operator.yaml"

  kubectl wait \
    --namespace tigera-operator \
    --for=condition=Available \
    deployment/tigera-operator \
    --timeout=180s || true

  # NOT using the upstream custom-resources.yaml: it hardcodes
  # cidr: 192.168.0.0/16, which collides with most home/office LANs.
  # Render the Installation with POD_CIDR instead.
  cat <<EOF | kubectl apply -f -
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
    ipPools:
      - name: default-ipv4-ippool
        blockSize: 26
        cidr: ${POD_CIDR}
        encapsulation: VXLANCrossSubnet
        natOutgoing: Enabled
        nodeSelector: all()
---
apiVersion: operator.tigera.io/v1
kind: APIServer
metadata:
  name: default
spec: {}
EOF

  echo
  echo "Waiting for node readiness..."
  kubectl wait --for=condition=Ready node --all --timeout=300s || true

  log "Control plane initialized"

  echo
  echo "Worker join command:"
  kubeadm token create --print-join-command
}

# ----------------------------
# WORKER JOIN
# ----------------------------
join_worker() {
  require_root

  local join_cmd="${1:-}"

  [[ -n "${join_cmd}" ]] || die \
    'Pass the full join command, for example:
sudo ./k8s-lab-install.sh worker "kubeadm join 192.168.30.201:6443 --token ... --discovery-token-ca-cert-hash sha256:..."'

  log "Joining worker to cluster"

  # Allow string beginning with optional sudo.
  join_cmd="${join_cmd#sudo }"

  bash -c "${join_cmd}"

  log "Worker joined"
}

# ----------------------------
# HELM
# ----------------------------
install_helm() {
  if command -v helm >/dev/null 2>&1; then
    echo "Helm already installed: $(helm version --short)"
    return
  fi

  log "Installing Helm"

  curl -fsSL \
    https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
    | bash
}

# ----------------------------
# METALLB
# ----------------------------
install_metallb() {
  log "Installing MetalLB ${METALLB_VERSION}"

  kubectl apply -f \
    "https://raw.githubusercontent.com/metallb/metallb/${METALLB_VERSION}/config/manifests/metallb-native.yaml"

  kubectl wait \
    --namespace metallb-system \
    --for=condition=Available \
    deployment/controller \
    --timeout=180s || true

  # An existing pool wins: creating a second autoAssign pool makes address
  # allocation non-deterministic between the two.
  local existing
  existing="$(kubectl get ipaddresspool -n metallb-system \
    -o jsonpath='{range .items[*]}{.metadata.name}={.spec.addresses}{"\n"}{end}' 2>/dev/null || true)"

  if [[ -n "${existing}" ]]; then
    log "MetalLB pool already configured, keeping it"
    echo "${existing}"
    echo
    echo "To replace it, delete the pool first:"
    echo "  kubectl delete ipaddresspool,l2advertisement -n metallb-system --all"
    return 0
  fi

  if [[ -z "${METALLB_POOL}" ]]; then
    METALLB_POOL="$(derive_metallb_pool)" \
      || die "Could not detect the LAN subnet. Set METALLB_POOL explicitly, e.g. METALLB_POOL=192.168.90.240-192.168.90.250"
    log "Derived METALLB_POOL from this host's subnet: ${METALLB_POOL}"
  fi

  validate_metallb_pool "${METALLB_POOL}"

  cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
    - ${METALLB_POOL}
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default-l2
  namespace: metallb-system
spec:
  ipAddressPools:
    - default-pool
EOF
}

# ----------------------------
# INGRESS NGINX
# ----------------------------
install_ingress_nginx() {
  log "Installing ingress-nginx"

  kubectl apply -f \
    https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.15.1/deploy/static/provider/baremetal/deploy.yaml

  wait_for_rollout deployment ingress-nginx-controller ingress-nginx

  log "Converting ingress-nginx Service to LoadBalancer"

  kubectl patch svc ingress-nginx-controller \
    -n ingress-nginx \
    -p '{"spec":{"type":"LoadBalancer"}}'

  # Ensure Ingress ADDRESS publishes the MetalLB service address
  if ! kubectl -n ingress-nginx get deploy ingress-nginx-controller \
       -o jsonpath='{.spec.template.spec.containers[0].args}' \
       | grep -q -- '--publish-service='; then

    kubectl patch deployment ingress-nginx-controller \
      -n ingress-nginx \
      --type='json' \
      -p='[
        {
          "op":"add",
          "path":"/spec/template/spec/containers/0/args/-",
          "value":"--publish-service=$(POD_NAMESPACE)/ingress-nginx-controller"
        }
      ]'
  fi

  wait_for_rollout deployment ingress-nginx-controller ingress-nginx

  echo
  kubectl get svc -n ingress-nginx
}

# ----------------------------
# GATEWAY API
# ----------------------------
install_gateway_api() {
  log "Installing Gateway API CRDs ${GATEWAY_API_VERSION}"

  kubectl apply --server-side -f \
    "https://github.com/kubernetes-sigs/gateway-api/releases/download/${GATEWAY_API_VERSION}/standard-install.yaml"

  echo
  echo "NOTE: These are the Gateway API CRDs."
  echo "A Gateway controller/implementation is still required for actual traffic."
}

# ----------------------------
# METRICS SERVER
# ----------------------------
# ----------------------------
# STORAGE CLASS (local-path-provisioner)
# ----------------------------
install_storage_class() {
  log "Installing local-path-provisioner ${LOCAL_PATH_VERSION}"

  kubectl apply -f \
    "https://raw.githubusercontent.com/rancher/local-path-provisioner/${LOCAL_PATH_VERSION}/deploy/local-path-storage.yaml"

  wait_for_rollout deployment local-path-provisioner local-path-storage

  if [[ "${LOCAL_PATH_DEFAULT_CLASS}" == "true" ]]; then
    # Clear the flag on any other class first: two defaults make the choice
    # undefined and PVCs without storageClassName stay Pending.
    local sc
    for sc in $(kubectl get storageclass -o name 2>/dev/null); do
      if [[ "${sc}" != "storageclass.storage.k8s.io/local-path" ]]; then
        kubectl patch "${sc}" \
          -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}' \
          >/dev/null 2>&1 || true
      fi
    done

    log "Marking local-path as the default StorageClass"

    kubectl patch storageclass local-path \
      -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
  fi

  kubectl get storageclass
}

install_metrics_server() {
  log "Installing Metrics Server"

  kubectl apply -f \
    https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

  if [[ "${METRICS_INSECURE_TLS}" == "true" ]]; then
    if ! kubectl -n kube-system get deployment metrics-server \
      -o jsonpath='{.spec.template.spec.containers[0].args}' \
      | grep -q -- '--kubelet-insecure-tls'; then

      kubectl patch deployment metrics-server \
        -n kube-system \
        --type='json' \
        -p='[
          {
            "op":"add",
            "path":"/spec/template/spec/containers/0/args/-",
            "value":"--kubelet-insecure-tls"
          }
        ]'
    fi
  fi

  wait_for_rollout deployment metrics-server kube-system
}

# ----------------------------
# PROMETHEUS / GRAFANA
# ----------------------------
install_monitoring() {
  install_helm

  log "Installing kube-prometheus-stack"

  kubectl create namespace "${MONITORING_NAMESPACE}" \
    --dry-run=client -o yaml | kubectl apply -f -

  helm repo add prometheus-community \
    https://prometheus-community.github.io/helm-charts \
    --force-update

  helm repo update

  helm upgrade --install monitoring \
    prometheus-community/kube-prometheus-stack \
    -n "${MONITORING_NAMESPACE}"

  echo
  kubectl get pods -n "${MONITORING_NAMESPACE}"
}

# ----------------------------
# MONITORING INGRESS
# ----------------------------
install_monitoring_ingress() {
  log "Creating Grafana and Prometheus Ingress resources"

  local grafana_svc
  local prometheus_svc

  grafana_svc="$(kubectl get svc -n "${MONITORING_NAMESPACE}" \
    -l app.kubernetes.io/name=grafana \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"

  if [[ -z "${grafana_svc}" ]]; then
    grafana_svc="monitoring-grafana"
  fi

  prometheus_svc="$(kubectl get svc -n "${MONITORING_NAMESPACE}" \
    -o name | sed 's#service/##' | grep 'prometheus$' | head -n1 || true)"

  if [[ -z "${prometheus_svc}" ]]; then
    prometheus_svc="monitoring-kube-prometheus-prometheus"
  fi

  cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana
  namespace: ${MONITORING_NAMESPACE}
spec:
  ingressClassName: nginx
  rules:
    - host: grafana.lab.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: ${grafana_svc}
                port:
                  number: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: prometheus
  namespace: ${MONITORING_NAMESPACE}
spec:
  ingressClassName: nginx
  rules:
    - host: prometheus.lab.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: ${prometheus_svc}
                port:
                  number: 9090
EOF
}

# ----------------------------
# ADDONS
# ----------------------------
install_addons() {
  require_non_root_kubectl

  install_metallb
  install_ingress_nginx
  install_gateway_api
  install_storage_class
  install_metrics_server
  install_helm

  if [[ "${INSTALL_MONITORING}" == "true" ]]; then
    install_monitoring
    install_monitoring_ingress
  else
    log "Skipping monitoring stack in cluster bootstrap (course flow)"
    echo "Prometheus/Grafana will be installed in Module 03 with persistence and fixed datasource UIDs."
  fi

  log "Creating application namespace ${APP_NAMESPACE}"

  kubectl create namespace "${APP_NAMESPACE}" \
    --dry-run=client -o yaml | kubectl apply -f -

  log "Addon installation complete"

  echo
  echo "Nodes:"
  kubectl get nodes -o wide

  echo
  echo "Ingress controller:"
  kubectl get svc -n ingress-nginx

  echo
  echo "Ingresses:"
  kubectl get ingress -n "${MONITORING_NAMESPACE}" || true

  echo
  echo "MetalLB:"
  kubectl get ipaddresspool,l2advertisement -n metallb-system

  echo
  echo "StorageClass:"
  kubectl get storageclass

  echo
  echo "Monitoring:"
  kubectl get pods -n "${MONITORING_NAMESPACE}"

  echo
  echo "Metrics Server:"
  kubectl top nodes || true

  echo
  echo "IMPORTANT:"
  echo "Add the MetalLB Ingress IP to your workstation hosts file:"
  echo
  echo "<METALLB_IP> grafana.lab.local"
  echo "<METALLB_IP> prometheus.lab.local"
}

# ----------------------------
# AWS CLI
# ----------------------------
install_aws_cli() {
  local use_sudo=""

  if [[ "${EUID}" -ne 0 ]]; then
    use_sudo="sudo"
  fi

  log "Installing AWS CLI v2"

  local arch
  arch="$(uname -m)"

  case "${arch}" in
    x86_64) aws_arch="x86_64" ;;
    aarch64|arm64) aws_arch="aarch64" ;;
    *) die "Unsupported architecture for AWS CLI: ${arch}" ;;
  esac

  rm -rf /tmp/aws /tmp/awscliv2.zip

  curl -fsSL \
    "https://awscli.amazonaws.com/awscli-exe-linux-${aws_arch}.zip" \
    -o /tmp/awscliv2.zip

  unzip -q /tmp/awscliv2.zip -d /tmp

  if command -v aws >/dev/null 2>&1; then
    ${use_sudo} /tmp/aws/install --update
  else
    ${use_sudo} /tmp/aws/install
  fi

  rm -rf /tmp/aws /tmp/awscliv2.zip

  aws --version
}

# ----------------------------
# ECR SECRET
# ----------------------------
configure_ecr() {
  require_non_root_kubectl

  if ! command -v aws >/dev/null 2>&1; then
    install_aws_cli
  fi

  log "Creating ECR imagePullSecret in namespace ${APP_NAMESPACE}"

  aws sts get-caller-identity >/dev/null 2>&1 || die \
    "AWS credentials are not configured. Run: aws configure"

  local aws_account_id
  local ecr_registry

  aws_account_id="$(aws sts get-caller-identity --query Account --output text)"
  ecr_registry="${aws_account_id}.dkr.ecr.${AWS_REGION}.amazonaws.com"

  kubectl create namespace "${APP_NAMESPACE}" \
    --dry-run=client -o yaml | kubectl apply -f -

  kubectl delete secret "${ECR_SECRET_NAME}" \
    -n "${APP_NAMESPACE}" \
    --ignore-not-found

  kubectl create secret docker-registry "${ECR_SECRET_NAME}" \
    --docker-server="${ecr_registry}" \
    --docker-username=AWS \
    --docker-password="$(aws ecr get-login-password --region "${AWS_REGION}")" \
    -n "${APP_NAMESPACE}"

  kubectl patch serviceaccount default \
    -n "${APP_NAMESPACE}" \
    --type=merge \
    -p "{\"imagePullSecrets\":[{\"name\":\"${ECR_SECRET_NAME}\"}]}"

  echo
  echo "ECR registry: ${ecr_registry}"
  echo "Secret: ${APP_NAMESPACE}/${ECR_SECRET_NAME}"
  echo
  echo "WARNING: ECR authorization tokens expire after 12 hours."
}

# ----------------------------
# SSH ONLY
# ----------------------------
configure_ssh_only() {
  require_root

  log "Configuring SSH keepalive"

  cat >/etc/ssh/sshd_config.d/99-keepalive.conf <<EOF
ClientAliveInterval 60
ClientAliveCountMax 10
TCPKeepAlive yes
EOF

  sshd -t
  systemctl restart ssh

  echo "SSH keepalive configured."
}

# ----------------------------
# STATUS
# ----------------------------
status() {
  require_non_root_kubectl

  echo "===== NODES ====="
  kubectl get nodes -o wide

  echo
  echo "===== PODS ====="
  kubectl get pods -A

  echo
  echo "===== INGRESS ====="
  kubectl get ingress -A || true

  echo
  echo "===== INGRESS SERVICE ====="
  kubectl get svc -n ingress-nginx || true

  echo
  echo "===== METALLB ====="
  kubectl get ipaddresspool,l2advertisement -n metallb-system || true

  echo
  echo "===== STORAGE ====="
  kubectl get storageclass || true
  kubectl get pvc -A || true

  echo
  echo "===== METRICS ====="
  kubectl top nodes || true
}

# ----------------------------
# MAIN
# ----------------------------
usage() {
  cat <<EOF

Kubernetes Lab Installer

Usage:
  $0 common
      Prepare Ubuntu node:
      - swap/kernel/sysctl
      - Docker
      - containerd
      - kubeadm/kubelet/kubectl
      - crictl
      - SSH keepalive

  $0 master
      Run kubeadm init and install Calico.

  $0 worker "kubeadm join ..."
      Join a worker node.

  $0 addons
      Install:
      - MetalLB
      - ingress-nginx as LoadBalancer
      - Gateway API CRDs
      - local-path-provisioner (default StorageClass)
      - Metrics Server
      - Helm
      - Prometheus/Grafana
      - Grafana/Prometheus Ingress

  $0 aws
      Install AWS CLI v2.

  $0 ecr
      Create ECR imagePullSecret in ${APP_NAMESPACE}
      and attach it to the default ServiceAccount.

  $0 ssh
      Configure SSH keepalive only.

  $0 status
      Show main cluster resources.

Environment variables:
  K8S_MINOR=${K8S_MINOR}
  POD_CIDR=${POD_CIDR}
  CALICO_VERSION=${CALICO_VERSION}
  METALLB_VERSION=${METALLB_VERSION}
  METALLB_POOL=${METALLB_POOL}
  LOCAL_PATH_VERSION=${LOCAL_PATH_VERSION}
  LOCAL_PATH_DEFAULT_CLASS=${LOCAL_PATH_DEFAULT_CLASS}
  GATEWAY_API_VERSION=${GATEWAY_API_VERSION}
  APP_NAMESPACE=${APP_NAMESPACE}
  AWS_REGION=${AWS_REGION}
  ECR_SECRET_NAME=${ECR_SECRET_NAME}
  MONITORING_NAMESPACE=${MONITORING_NAMESPACE}
  INSTALL_MONITORING=${INSTALL_MONITORING}

Example with custom MetalLB pool:

  METALLB_POOL=192.168.50.230-192.168.50.240 $0 addons

EOF
}

cmd="${1:-}"

case "${cmd}" in
  common)
    install_common
    ;;
  master)
    init_master
    ;;
  worker)
    join_worker "${2:-}"
    ;;
  addons)
    install_addons
    ;;
  aws)
    install_aws_cli
    ;;
  ecr)
    configure_ecr
    ;;
  ssh)
    configure_ssh_only
    ;;
  status)
    status
    ;;
  *)
    usage
    exit 1
    ;;
esac
