#!/usr/bin/env bash

! which gcloud >/dev/null && echo "FATAL: gcloud missing" && exit 1

# #############################################################################
# Globals

NET_NAME=${1:-kubenet}

# #############################################################################
# Networks

gcloud compute networks create ${NET_NAME} --subnet-mode custom

gcloud compute networks subnets create kubernetes \
  --network ${NET_NAME} \
  --range 10.240.0.0/24

# #############################################################################
# Firewall

gcloud compute firewall-rules create ${NET_NAME}-allow-internal \
  --allow tcp,udp,icmp \
  --network ${NET_NAME} \
  --source-ranges 10.240.0.0/24,10.200.0.0/16

gcloud compute firewall-rules create ${NET_NAME}-allow-external \
  --allow tcp:22,tcp:6443,icmp \
  --network ${NET_NAME} \
  --source-ranges 0.0.0.0/0

gcloud compute firewall-rules list --filter "network: ${NET_NAME}"

# #############################################################################
# Static IP Address

gcloud compute addresses create ${NET_NAME} \
  --region $(gcloud config get-value compute/region)

gcloud compute addresses list --filter="name=: '${NET_NAME}'"
