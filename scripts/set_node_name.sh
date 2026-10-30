#!/bin/bash
#
# set the Fed-BioMed node name to FBM_NODE_NAME
#

set -e

if [ -z "$FBM_NODE_NAME" ]; then
    echo "[INFO] FBM_NODE_NAME not set, keeping the node name unchanged"
    exit 0
fi

CONFIG=/fbm-node/etc/config.ini

if [ -f "$CONFIG" ]; then
    # existing configuration: get the name line in the [default] section
    NAME_RE='^name[[:space:]]*[=:]' # delimiter can be `=` or `:`
    CURRENT_LINE=$(sed -n "/^\[default\]/,/^\[/ { /${NAME_RE}/Ip }" "$CONFIG")
    CURRENT_NAME=$(echo "$CURRENT_LINE" | sed "s/${NAME_RE}[[:space:]]*//I; s/[[:space:]]*$//")
    if [ -z "$CURRENT_LINE" ]; then
        # no name: add it at the start of the [default] section
        echo "[WARNING] No node name in $CONFIG, setting it to '${FBM_NODE_NAME}'"
        sed -i "/^\[default\]/a name = ${FBM_NODE_NAME}" "$CONFIG"
    elif [ "$CURRENT_NAME" != "$FBM_NODE_NAME" ]; then
        # replace it if it differs from FBM_NODE_NAME
        echo "[WARNING] Node name in $CONFIG is '${CURRENT_NAME}', replacing it with '${FBM_NODE_NAME}'"
        sed -i "/^\[default\]/,/^\[/ s|${NAME_RE}.*|name = ${FBM_NODE_NAME}|I" "$CONFIG"
    fi
elif grep -q -- '--exist-ok --name' /entrypoint.sh; then
    # no configuration yet but /entrypoint.sh already patched: do nothing
    :
else
    # append `--name` option to the `fedbiomed component create` command in /entrypoint.sh
    echo "[INFO] No node configuration yet: injecting --name '${FBM_NODE_NAME}' into the component creation command in /entrypoint.sh"
    sed -i "s|--exist-ok|--exist-ok --name '${FBM_NODE_NAME}'|" /entrypoint.sh
fi
