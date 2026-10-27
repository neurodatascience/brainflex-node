#!/bin/bash

# VPN client container launch script
# - launched as root to handle VPN

# Adapted from Fed-BioMed (Apache-2.0):
# https://github.com/fedbiomed/fedbiomed/blob/v6.4.1/envs/vpn/docker/node/build_files/entrypoint.bash

# read functions
source /entrypoint_functions.bash

# set base directory for configuration files
CONFIG_DIR=/config

# read config.env (provided by the VPN server administrator)
[ -f $CONFIG_DIR/config.env ] && source $CONFIG_DIR/config.env
check_vpn_environ

init_misc_environ
start_wireguard
configure_wireguard

trap finish TERM INT QUIT

# the VPN server administrator needs this key to register this peer
echo "info: wireguard public key for this peer: $(wg show wg0 public-key)"

echo "VPN container is ready"
sleep infinity &

wait $!
