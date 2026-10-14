#!/bin/bash
set -euo pipefail

# Evitar inicializacao duplicada
if [ -f /etc/kubernetes/admin.conf ]; then
  echo "Control Plane ja inicializado."
  exit 0
fi

# Inicializar Kubernetes
kubeadm init \
  --apiserver-advertise-address="$(hostname -I | awk '{print $1}')" \
  --pod-network-cidr=192.168.0.0/16

# Configurar kubectl para o usuario ubuntu
mkdir -p /home/ubuntu/.kube

cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config

chown -R ubuntu:ubuntu /home/ubuntu/.kube

chmod 600 /home/ubuntu/.kube/config

echo "Control Plane inicializado com sucesso."
echo "Proxima etapa: instalar o CNI e associar o Worker."