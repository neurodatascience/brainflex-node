# brainflex-node
Starting repo for nodes participating in the FL experiment

## Running the Fed-BioMed node

The node runs with Docker Compose as two containers:

- `vpn`: a WireGuard client that connects to the brainflex VPN server
- `node`: the published [`fedbiomed/node`](https://hub.docker.com/r/fedbiomed/node) image, using the network of the `vpn` container to reach the researcher

### Requirements

- Docker with the Compose plugin (`docker compose`)
- Outbound UDP access to the VPN server

### Setup

1. Create the `.env` file and set `CONTAINER_UID`/`CONTAINER_GID` to the output of `id -u`/`id -g`:

   ```bash
   cp .env.example .env
   ```

2. Get your `config.env` file from the brainflex VPN administrator and place it in `vpn_config/`. Keep this file private.

3. Build and start the containers:

   ```bash
   docker compose up -d --build
   ```

   The first build compiles the WireGuard userspace implementation and takes a few minutes.

4. Send the node's WireGuard public key to the VPN administrator, who registers it on the VPN server:

   ```bash
   docker compose logs vpn | grep 'public key'
   ```

   The key is kept in `vpn_config/wireguard/wg0.conf` and reused when the containers are restarted.

5. Once the key is registered, check that the VPN server and the researcher are reachable, and that the node is running:

   ```bash
   scripts/vpn_status vpn node
   docker compose exec -u fedbiomed node fedbiomed node -p /fbm-node status
   ```

### Usage

Fed-BioMed node files (configuration, database, data) are in `fbm-node`, mounted at `/fbm-node` in the `node` container.

Register a dataset:

```bash
docker compose exec -u fedbiomed node fedbiomed node -p /fbm-node dataset add
```

Stop the containers:

```bash
docker compose down
```

## Testing with a local researcher and VPN server

`docker-compose.yml` also has a researcher and a VPN server, for testing the whole setup on one machine. They only start with `--profile researcher` and `--profile vpnserver`, so the commands above never start them.

- `vpnserver`: a WireGuard server built on top of the `vpn` image, with Fed-BioMed's `configure_peer` tool. Files are in `vpnserver_config/`.
- `researcher-vpn`: a second WireGuard client for the researcher. Files are in `researcher_vpn_config/`.
- `researcher`: the published [`fedbiomed/researcher`](https://hub.docker.com/r/fedbiomed/researcher) image, with Jupyter on http://localhost:8888. Files are in `fbm-researcher/`.

1. Create the `.env` file as in the node setup.

2. Create the VPN server configuration. Set `VPN_SERVER_PUBLIC_ADDR` to an address of the host that containers can reach, not `localhost`:

   ```bash
   cp docker/vpnserver/config.env.sample vpnserver_config/config.env
   sed -i "s/replace_with.myserver.mydomain/$(hostname -I | cut -d' ' -f1)/" vpnserver_config/config.env
   ```

3. Start the VPN server:

   ```bash
   docker compose --profile vpnserver up -d --build vpnserver
   ```

4. Create the researcher and node peers, and copy their configurations to the clients. The first researcher gets the VPN address `10.222.0.2`, the first node `10.221.0.2`:

   ```bash
   docker compose --profile vpnserver exec vpnserver configure_peer genconf researcher researcher1
   docker compose --profile vpnserver exec vpnserver configure_peer genconf node node1
   cp vpnserver_config/config_peers/researcher/researcher1/config.env researcher_vpn_config/
   cp vpnserver_config/config_peers/node/node1/config.env vpn_config/
   ```

5. Start the node and the researcher:

   ```bash
   docker compose --profile researcher up -d --build
   ```

6. Register the public keys of the clients on the server:

   ```bash
   docker compose --profile '*' exec vpnserver configure_peer add node node1 "$(docker compose exec -T vpn wg show wg0 public-key)"
   docker compose --profile '*' exec vpnserver configure_peer add researcher researcher1 "$(docker compose --profile researcher exec -T researcher-vpn wg show wg0 public-key)"
   docker compose --profile '*' exec vpnserver configure_peer list
   ```

7. Check that all containers are running and can ping each other through the VPN. A client may need up to 25 seconds to reconnect after the VPN server restarts:

   ```bash
   scripts/vpn_status
   ```

8. Add the MNIST dataset to the node:

   ```bash
   docker compose exec -u fedbiomed node fedbiomed node -p /fbm-node dataset add --mnist /fbm-node/data
   ```

   Then open http://localhost:8888 and run `101_getting-started.ipynb`. The node log shows `Successfully connected to researcher server at 10.222.0.2:50051`:

   ```bash
   grep 'Successfully connected' fbm-node/log/*.log
   ```

9. Stop everything:

   ```bash
   docker compose --profile '*' down
   ```

   Keys and peers are kept in the `*_config/` folders, so step 5 and step 7 are enough to start again. To start from scratch, delete everything in `vpnserver_config/`, `researcher_vpn_config/`, `vpn_config/`, `fbm-node/` and `fbm-researcher/` except `.gitkeep`.
