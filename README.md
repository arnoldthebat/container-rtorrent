# rTorrent

A compact, self-contained [rTorrent](https://github.com/rakshasa/rtorrent) image with XML-RPC access provided by Nginx. It runs rTorrent in a `tmux` session, making the terminal interface available for troubleshooting without bundling a web UI such as ruTorrent.

The image includes rTorrent, libtorrent, mktorrent, Nginx, and a health check that verifies Nginx, the rTorrent process, its `tmux` session, and the XML-RPC endpoint.

> This image provides the rTorrent daemon and XML-RPC endpoint only. It does not include a web-based torrent client.

## Quick start

Create a persistent data directory and copy the supplied configuration:

```bash
mkdir -p "$HOME/rtorrent"/{config,download,.session,watch,logs}
curl -fsSL https://raw.githubusercontent.com/arnoldthebat/container-rtorrent/main/examples/.rtorrent.rc \
  -o "$HOME/rtorrent/config/.rtorrent.rc"
```

Run the image:

```bash
docker run -d \
  --name rtorrent \
  --restart unless-stopped \
  -p 55555:55555/tcp \
  -p 55555:55555/udp \
  -p 8000:8000 \
  -v "$HOME/rtorrent:/data/rtorrent" \
  ghcr.io/arnoldthebat/rtorrent:latest
```

The container is ready when Docker reports it as healthy:

```bash
docker ps --filter name=rtorrent
```

## Ports

| Container port | Purpose | Required |
| --- | --- | --- |
| `55555` | Incoming BitTorrent peer traffic (TCP and UDP) | Yes, for optimal connectivity |
| `8000` | XML-RPC endpoint at `/RPC2` | Only for an XML-RPC client or reverse proxy |

The supplied [`examples/.rtorrent.rc`](examples/.rtorrent.rc) configures rTorrent to use port `55555`. If you choose another peer port, update both the configuration and your Docker port mappings. If you expose the XML-RPC port beyond a trusted network, place it behind an authenticated reverse proxy or restrict it with firewall rules.

## Persistent data

Mount a host directory at `/data/rtorrent`. The supplied configuration uses the following layout:

| Path | Purpose |
| --- | --- |
| `config/.rtorrent.rc` | rTorrent configuration file |
| `download/` | Completed and active download data |
| `.session/` | rTorrent session state |
| `watch/` | Watch directories for torrent files |
| `logs/` | rTorrent and XML-RPC logs |

## Docker Compose

The repository includes a Compose example. Before starting it:

1. Create the persistent directory and configuration as shown in [Quick start](#quick-start).
2. Update the host volume path in [`docker-compose.yml`](docker-compose.yml) if needed.
3. Change the peer-port mapping to `55555:55555` and add a second `55555:55555/udp` mapping when using the bundled configuration.

Then build and start the service:

```bash
docker compose up -d --build
```

## Access the rTorrent terminal

rTorrent runs as the `rtorrent` user in a `tmux` session named `rtorrent-session`. Attach to it with:

```bash
docker exec -it -u rtorrent rtorrent tmux attach-session -t rtorrent-session
```

Detach without stopping rTorrent with `Ctrl-b`, then `d`.

Useful operational commands:

```bash
docker logs -f rtorrent
docker exec -it rtorrent sh
docker stop rtorrent
```

## XML-RPC

Nginx proxies XML-RPC requests to rTorrent at:

```text
http://<host>:8000/RPC2
```

XML-RPC has no authentication in this image. Do not publish port `8000` directly to the internet.

## Build from source

Build a local image from this repository:

```bash
docker build -t arnoldthebat/rtorrent:local .
```

Or use Compose:

```bash
docker compose build
```

To publish the tags configured in `docker-compose.yml`, authenticate to Docker Hub and run:

```bash
docker login
docker compose push
```

## Notes

- The image creates and runs rTorrent as UID and GID `1000` by default. Ensure the mounted directory is writable by that user.
