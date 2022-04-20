#!/usr/bin/env bash

if ! which cfssl >/dev/null || ! which cfssljson >/dev/null ; then
  echo "FATAL: cfssl or cfssljson missing"
  exit 1
fi

# #############################################################################
# Globals

NET_NAME=${1:-kubenet}
NO_CONTROLLERS=${2:-3}
NO_WORKERS=${3:-3}

# #############################################################################
# Prep

mkdir ./current
cd ./current
if [[ $PWD = */gcp/current ]] ; then
  rm -rf ./*.pem
else
  echo "FATAL: not in expected dir (.../gcp/current)"
  exit 1
fi

# #############################################################################
# Certificate Authority

cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF

# Signing request:

cat > ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "CA",
      "ST": "Oregon"
    }
  ]
}
EOF

# Generate the CA certificate and private key:

cfssl gencert -initca ca-csr.json | cfssljson -bare ca

# Results:

ls -l ca-key.pem ca.pem

# #############################################################################
# Admin Client Certificate

# Request:

cat > admin-csr.json <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:masters",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

# Generate:

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  admin-csr.json | cfssljson -bare admin

# Results:

ls -l admin-key.pem admin.pem

# #############################################################################
# Kubelet Client Certificates

for instance in worker-0 worker-1 worker-2; do
cat > ${instance}-csr.json <<EOF
{
  "CN": "system:node:${instance}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:nodes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

EXTERNAL_IP=$(gcloud compute instances describe ${instance} \
  --format 'value(networkInterfaces[0].accessConfigs[0].natIP)')

INTERNAL_IP=$(gcloud compute instances describe ${instance} \
  --format 'value(networkInterfaces[0].networkIP)')

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=${instance},${EXTERNAL_IP},${INTERNAL_IP} \
  -profile=kubernetes \
  ${instance}-csr.json | cfssljson -bare ${instance}
done

# Results:

ls -l workers*.pem

# #############################################################################
# kube-proxy Client Certificate

# Request:

cat > kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:node-proxier",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

# Generate:

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-proxy-csr.json | cfssljson -bare kube-proxy

# Results:

ls -l kube-proxy*pem

# #############################################################################
# Kubernetes API Server Certificate

KUBE_PUBLIC_ADDRESS=$(gcloud compute addresses describe ${NET_NAME} \
  --region $(gcloud config get-value compute/region) \
  --format 'value(address)')

# Request:

cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

# Generate:

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=10.32.0.1,10.240.0.10,10.240.0.11,10.240.0.12,${KUBE_PUBLIC_ADDRESS},127.0.0.1,kubernetes.default \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes

# Results:

ls -l kubernetes*.pem

# #############################################################################
# Distribute the Client and Server Certificates

for instance in $(seq 0 "$((NO_WORKERS-1))" | sed -e 's/^/worker-/'); do
  gcloud compute scp ca.pem ${instance}-key.pem ${instance}.pem ${instance}:~/
done

for instance in $(seq 0 "$((NO_CONTROLLERS-1))" | sed -e 's/^/controller-/'); do
  gcloud compute scp ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem ${instance}:~/
done
