#!/bin/bash

# VPN server container launch script
# - launched as root to handle VPN

# Adapted from Fed-BioMed (Apache-2.0):
# https://github.com/fedbiomed/fedbiomed/blob/v6.4.1/envs/vpn/docker/vpnserver/build_files/entrypoint.bash

# read functions
source /entrypoint_functions.bash

# set base directory for configuration files
CONFIG_DIR=/config

# read config.env (copied from config.env.sample)
[ -f $CONFIG_DIR/config.env ] && source $CONFIG_DIR/config.env

# content of VPN environ is not the same for VPN server
check_vpn_environ 'VPN_IP VPN_SUBNET_PREFIX VPN_MANAGEMENT_IP_ASSIGN VPN_NODE_IP_ASSIGN VPN_RESEARCHER_IP_ASSIGN VPN_SERVER_PUBLIC_ADDR VPN_SERVER_PORT'

init_misc_environ
start_wireguard
configure_wireguard

trap finish TERM INT QUIT

# VPN server additional directories
for dir in ip_assign config_peers
do
    mkdir -p $CONFIG_DIR/$dir
    if [ "$?" -ne 0 ]
    then
        echo "CRITICAL: could not create vpn server config directory ${CONFIG_DIR}/$dir"
        exit 1
    fi
    # configure_peer writes there with the identity of the config directory owner
    chown --reference=$CONFIG_DIR $CONFIG_DIR/$dir
done

# VPN server setup
wg set wg0 listen-port $VPN_SERVER_PORT
if [ "$?" -ne 0 ]
then
    echo "CRITICAL: could not set wireguard server listening port"
    exit 1
fi

echo "VPN server container is ready"
sleep infinity &

wait $!
