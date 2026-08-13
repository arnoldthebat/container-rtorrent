# Rtorrent Image

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
docker run --rm -it --name rtorrent  -v "$HOME/dev/cobbling/rtorrent:/data/rtorrent" -p 51234:51234 -p 8000:8000 container-rtorrent:latest
```

## Run

```bash
docker compose up -d
```
