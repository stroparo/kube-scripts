#!/usr/bin/env bash

! which gcloud >/dev/null && echo "FATAL: gcloud missing" && exit 1
! which kubectl >/dev/null && echo "FATAL: kubectl missing" && exit 1

# #############################################################################
# Globals

NET_NAME=${1:-kubenet}
NO_CONTROLLERS=${2:-3}

# #############################################################################
# Prep

mkdir ./current
cd ./current
if ! [[ $PWD = */gcp/current ]] ; then
  echo "FATAL: not in expected dir (.../gcp/current)"
  exit 1
fi

# #############################################################################
# Fetch the public address

KUBERNETES_PUBLIC_ADDRESS=$(gcloud compute addresses describe ${NET_NAME} \
  --region $(gcloud config get-value compute/region) \
  --format 'value(address)')

# #############################################################################
# kubelet Kubernetes Configuration File

for instance in $(seq 0 "$((NO_WORKERS-1))" | sed -e 's/^/worker-/'); do
  kubectl config set-cluster ${NET_NAME} \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
    --kubeconfig=${instance}.kubeconfig

  kubectl config set-credentials system:node:${instance} \
    --client-certificate=${instance}.pem \
    --client-key=${instance}-key.pem \
    --embed-certs=true \
    --kubeconfig=${instance}.kubeconfig

  kubectl config set-context default \
    --cluster=${NET_NAME} \
    --user=system:node:${instance} \
    --kubeconfig=${instance}.kubeconfig

  kubectl config use-context default --kubeconfig=${instance}.kubeconfig
done

# Results:

ls -l worker-*.kubeconfig

# #############################################################################
# kube-proxy Kubernetes Configuration File

kubectl config set-cluster ${NET_NAME} \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config set-credentials kube-proxy \
  --client-certificate=kube-proxy.pem \
  --client-key=kube-proxy-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config set-context default \
  --cluster=${NET_NAME} \
  --user=kube-proxy \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig

# #############################################################################
# Distribute the Kubernetes Configuration Files

for instance in $(seq 0 "$((NO_WORKERS-1))" | sed -e 's/^/worker-/'); do
  gcloud compute scp ${instance}.kubeconfig kube-proxy.kubeconfig ${instance}:~/
done
