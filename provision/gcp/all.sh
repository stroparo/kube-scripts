#!/usr/bin/env bash

# #############################################################################
# Globals

NET_NAME='kubenet'
NO_CONTROLLERS=${1:-3}
NO_WORKERS=${2:-3}

# #############################################################################
# Main

./net.sh "$NET_NAME"
./instances.sh "$NO_CONTROLLERS" "$NO_WORKERS"
./certs.sh "$NET_NAME" "$NO_CONTROLLERS" "$NO_WORKERS"
./authconfig.sh "$NET_NAME" "$NO_WORKERS"
./authencrypt.sh "$NET_NAME" "$NO_CONTROLLERS"

