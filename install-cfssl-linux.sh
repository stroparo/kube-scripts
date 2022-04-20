#!/usr/bin/env bash

INSTALL_DIR=/usr/local/bin
CFSSL_VER=R1.2
CFSSL_URL="https://pkg.cfssl.org/${CFSSL_VER}/cfssl_linux-amd64"
CFSSLJSON_URL="https://pkg.cfssl.org/${CFSSL_VER}/cfssljson_linux-amd64"

# #############################################################################
# Prep

cd /tmp

# #############################################################################
# cfssl

wget "$CFSSL_URL" "$CFSSLJSON_URL"
chmod -v 755 cfssl*
sudo chown -v 0:0 cfssl*
sudo mv -v cfssl_linux-amd64 "${INSTALL_DIR}"/cfssl
sudo mv -v cfssljson_linux-amd64 "${INSTALL_DIR}"/cfssljson
echo
ls -l "${INSTALL_DIR}"/cfssl*
which cfssl cfssljson

# #############################################################################
