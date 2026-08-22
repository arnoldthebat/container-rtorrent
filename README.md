# Rtorrent Image

A relatively minimal rtorrent deployment with XMLRPC enabled.

Runs as a tmux session rather than running as a daemon so easy to view/control manually if need without all the overhead of rutorrent.

## Building

```bash
docker build -t container-rtorrent .
```

Or

```bash
docker compose build
```

## Push

```bash
docker compose push
```

## Testing

```bash
mkdir -p ${HOME}/dev/cobbling/rtorrent \
    ${HOME}/dev/cobbling/rtorrent/config \
    ${HOME}/dev/cobbling/rtorrent/download \
    ${HOME}/dev/cobbling/rtorrent/.session \
    ${HOME}/dev/cobbling/rtorrent/watch \
    ${HOME}/dev/cobbling/rtorrent/logs
```

```bash
cp ${HOME}/dev/container-rtorrent/examples/.rtorrent.rc ${HOME}/dev/cobbling/rtorrent/config/
```

```bash
docker run --rm -it --name rtorrent  -v "${HOME}/dev/cobbling/rtorrent:/data/rtorrent" \
    -p 55555:55555 -p 8000:8000 \
    arnoldthebat/rtorrent:latest
```

```bash
docker exec -it -u rtorrent rtorrent tmux attach-session -t rtorrent-session
```

## Run

```bash
docker compose up -d
```
