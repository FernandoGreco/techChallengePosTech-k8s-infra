#!/bin/bash
set -euo pipefail

echo "Iniciando configuracao do Kubernetes Control Plane..."

# Evitar inicializacao duplicada
if [ -f /etc/kubernetes/admin.conf ]; then
  echo "Control Plane ja inicializado."
  exit 0
fi

# Obter IP privado da instancia
NODE_IP=$(ip -4 route get 1.1.1.1 | awk '{print $7; exit}')

if [ -z "$NODE_IP" ]; then
  echo "ERRO: nao foi possivel identificar o IP da instancia."
  exit 1
fi

echo "IP do Control Plane: $NODE_IP"

# Inicializar Kubernetes
kubeadm init \
  --apiserver-advertise-address="$NODE_IP" \
  --pod-network-cidr=192.168.0.0/16

# Configurar kubectl para usuario ubuntu
install -d -m 700 -o ubuntu -g ubuntu /home/ubuntu/.kube

install -m 600 -o ubuntu -g ubuntu \
  /etc/kubernetes/admin.conf \
  /home/ubuntu/.kube/config

echo "Control Plane inicializado com sucesso."
echo "Proxima etapa: instalar Calico e associar o Worker."

echo ""
echo "Gerando comando de associacao do Worker..."

kubeadm token create --print-join-command > /home/ubuntu/kubeadm-join.sh

chmod 600 /home/ubuntu/kubeadm-join.sh
chown ubuntu:ubuntu /home/ubuntu/kubeadm-join.sh

echo "Comando de associacao gerado com sucesso."