ARG CARES_VERSION=1.34.6
ARG CURL_VERSION=8.20.0
ARG ALPINE_VERSION=3.24.1
ARG LIBTORRENT_VERSION=v0.16.19
ARG RTORRENT_VERSION=v0.16.19
ARG MKTORRENT_VERSION=v1.1

FROM --platform=${BUILDPLATFORM} alpine:${ALPINE_VERSION} AS src
RUN apk --update --no-cache add curl git tar tree sed xz
WORKDIR /src

FROM src AS src-cares
ARG CARES_VERSION
RUN curl -sSL "https://github.com/c-ares/c-ares/releases/download/v${CARES_VERSION}/c-ares-${CARES_VERSION}.tar.gz" | tar xz --strip 1

FROM src AS src-curl
ARG CURL_VERSION
RUN curl -sSL "https://curl.se/download/curl-${CURL_VERSION}.tar.gz" | tar xz --strip 1

FROM src AS src-libtorrent
RUN git init . && git remote add origin "https://github.com/rakshasa/libtorrent.git"
ARG LIBTORRENT_VERSION
RUN git fetch origin "${LIBTORRENT_VERSION}" && git checkout -q FETCH_HEAD

FROM src AS src-rtorrent
RUN git init . && git remote add origin "https://github.com/rakshasa/rtorrent.git"
ARG RTORRENT_VERSION
RUN git fetch origin "${RTORRENT_VERSION}" && git checkout -q FETCH_HEAD

FROM src AS src-mktorrent
RUN git init . && git remote add origin "https://github.com/pobrn/mktorrent.git"
ARG MKTORRENT_VERSION
RUN git fetch origin "${MKTORRENT_VERSION}" && git checkout -q FETCH_HEAD

FROM alpine:${ALPINE_VERSION} AS builder
RUN apk --update --no-cache add \
    autoconf \
    automake \
    binutils \
    brotli-dev \
    build-base \
    cppunit-dev \
    cmake \
    gd-dev \
    libpsl-dev \
    libsigc++-dev \
    libtool \
    libxslt-dev \
    linux-headers \
    ncurses-dev \
    nghttp2-dev \
    openssl-dev \
    pcre-dev \
    tar \
    tree \
    xz \
    zlib-dev

ENV DIST_PATH="/dist"

WORKDIR /usr/local/src/cares
COPY --from=src-cares /src .
RUN cmake . -D CARES_SHARED=ON -D CMAKE_INSTALL_LIBDIR=lib -D CMAKE_BUILD_TYPE:STRING="Release" -D CMAKE_C_FLAGS_RELEASE:STRING="-O3 -flto -pipe" \
    && cmake --build . --clean-first --parallel $(nproc) \
    && make install -j$(nproc) \
    && make DESTDIR=${DIST_PATH} install -j$(nproc)

WORKDIR /usr/local/src/curl
COPY --from=src-curl /src .
RUN cmake . -D ENABLE_ARES=ON -D CURL_LTO=ON -D CURL_USE_OPENSSL=ON -D CURL_BROTLI=ON -D CURL_ZSTD=ON -D BUILD_SHARED_LIBS=ON -D CMAKE_INSTALL_LIBDIR=lib -D CMAKE_PREFIX_PATH=/usr/local -D CMAKE_BUILD_TYPE:STRING="Release" -D CMAKE_C_FLAGS_RELEASE:STRING="-O3 -flto -pipe" \
    && cmake --build . --clean-first --parallel $(nproc) \
    && make install -j$(nproc) \
    && make DESTDIR=${DIST_PATH} install -j$(nproc)

WORKDIR /usr/local/src/libtorrent
COPY --from=src-libtorrent /src .
RUN autoreconf -vfi \
    && ./configure --enable-aligned --prefix=/usr/local \
    && make -j$(nproc) CXXFLAGS="-w -O3 -flto -Werror=odr -Werror=lto-type-mismatch -Werror=strict-aliasing" \
    && make install -j$(nproc) \
    && make DESTDIR=${DIST_PATH} install -j$(nproc)

WORKDIR /usr/local/src/rtorrent
COPY --from=src-rtorrent /src .
RUN autoreconf -vfi \
    && ./configure --with-xmlrpc-tinyxml2 --with-ncurses --prefix=/usr/local \
    && make -j$(nproc) CXXFLAGS="-w -O3 -flto -Werror=odr -Werror=lto-type-mismatch -Werror=strict-aliasing" \
    && make install -j$(nproc) \
    && make DESTDIR=${DIST_PATH} install -j$(nproc)

WORKDIR /usr/local/src/mktorrent
COPY --from=src-mktorrent /src .
RUN make -j$(nproc) CC=gcc CFLAGS="-w -flto -O3" USE_PTHREADS=1 USE_OPENSSL=1 \
    && make install -j$(nproc) \
    && make DESTDIR=${DIST_PATH} install -j$(nproc)

FROM alpine:${ALPINE_VERSION}
COPY --from=builder /dist /

ENV PUID="1000" \
    PGID="1000" \
    PATH="/usr/local/bin:${PATH}"

RUN apk --update --no-cache add \
    bash \
    brotli \
    ca-certificates \
    libidn2 \
    libpsl \
    libsigc++ \
    libstdc++ \
    ncurses \
    nghttp2 \
    nginx \
    openssl \
    python3 \
    py3-pip \
    shadow \
    su-exec \
    tmux \
    tzdata \
    util-linux \
    zip \
    zstd


RUN addgroup -g ${PGID} rtorrent \
  && adduser -D -H -u ${PUID} -G rtorrent -s /bin/sh rtorrent \
  && ldconfig /usr/local/lib || true

RUN mkdir -p /data/rtorrent/.session /data/rtorrent/download \
    /data/rtorrent/watch /data/rtorrent/config /data/rtorrent/logs \
    && chown -R rtorrent:rtorrent /data/rtorrent

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

COPY etc /etc

# Setup NGINX
RUN mkdir -p /run/nginx /var/lib/nginx/tmp /var/log/nginx /var/cache/nginx && \
    chown -R nginx:nginx /run/nginx /var/lib/nginx /var/log/nginx /var/cache/nginx /etc/nginx && \
    chmod -R u+rwX,g+rwX /run/nginx /var/lib/nginx /var/log/nginx /var/cache/nginx /etc/nginx

RUN chmod +x /usr/local/bin/rtorrent

VOLUME [ "/data/rtorrent" ]

ENTRYPOINT ["/entrypoint.sh"]
