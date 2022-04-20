#!/usr/bin/env bash

INSTALL_DIR=/usr/local/bin
KUBE_URL=https://storage.googleapis.com/kubernetes-release/release/v1.8.0/bin/linux/amd64/kubectl

# #############################################################################
# Prep

cd /tmp

# #############################################################################
# K8s

wget "$KUBE_URL"
chmod -v 755 kubectl
sudo chown -v 0:0 kubectl
sudo mv -v kubectl "${INSTALL_DIR}"/
echo
ls -l "${INSTALL_DIR}"/kubectl
kubectl version --client

# #############################################################################
