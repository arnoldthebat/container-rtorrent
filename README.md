# Rtorrent Image

## Building

```bash
docker build -t container-rtorrent .
```

```bash
docker compose build
```

## Testing

```bash
docker run --rm -it --name rtorrent  -v "$HOME/dev/cobbling/rtorrent:/data/rtorrent" -p 51234:51234 -p 8000:8000 container-rtorrent:latest
```

## Debugging

```bash
docker exec -it -u rtorrent rtorrent tmux a -t rtorrent
```

## Push

```bash
docker compose push
```
