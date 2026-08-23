ARG CARES_VERSION=1.34.6
ARG CARES_SHA256=912dd7cc3b3e8a79c52fd7fb9c0f4ecf0aaa73e45efda880266a2d6e26b84ef5
ARG CURL_VERSION=8.20.0
ARG CURL_SHA256=fc5819cad3f9f5482669adcdc49a782c15f36d2a0715b395b06d9173593d2dc0
ARG ALPINE_VERSION=3.24.1
# libtorrent v0.16.19
ARG LIBTORRENT_COMMIT=74b88c154d634c4fc6ee32a6a9e49f1da75725f8
# rTorrent v0.16.19
ARG RTORRENT_COMMIT=247ae7621a7d2596a7f3df69e417b0835b5409cb
# mktorrent v1.1
ARG MKTORRENT_COMMIT=b20ef699b4ee5ded2f078ead776c7deac969e19a

FROM --platform=${BUILDPLATFORM} alpine:${ALPINE_VERSION} AS src
RUN apk --update --no-cache add curl git tar tree sed xz
WORKDIR /src

FROM src AS src-cares
ARG CARES_VERSION
ARG CARES_SHA256
RUN curl --fail --silent --show-error --location \
        --output c-ares.tar.gz \
        "https://github.com/c-ares/c-ares/releases/download/v${CARES_VERSION}/c-ares-${CARES_VERSION}.tar.gz" \
    && echo "${CARES_SHA256}  c-ares.tar.gz" | sha256sum -c - \
    && tar xzf c-ares.tar.gz --strip-components=1 \
    && rm c-ares.tar.gz

FROM src AS src-curl
ARG CURL_VERSION
ARG CURL_SHA256
RUN curl --fail --silent --show-error --location \
        --output curl.tar.gz \
        "https://curl.se/download/curl-${CURL_VERSION}.tar.gz" \
    && echo "${CURL_SHA256}  curl.tar.gz" | sha256sum -c - \
    && tar xzf curl.tar.gz --strip-components=1 \
    && rm curl.tar.gz

FROM src AS src-libtorrent
RUN git init . && git remote add origin "https://github.com/rakshasa/libtorrent.git"
ARG LIBTORRENT_COMMIT
RUN git fetch origin "${LIBTORRENT_COMMIT}" && git checkout -q FETCH_HEAD

FROM src AS src-rtorrent
RUN git init . && git remote add origin "https://github.com/rakshasa/rtorrent.git"
ARG RTORRENT_COMMIT
RUN git fetch origin "${RTORRENT_COMMIT}" && git checkout -q FETCH_HEAD

FROM src AS src-mktorrent
RUN git init . && git remote add origin "https://github.com/pobrn/mktorrent.git"
ARG MKTORRENT_COMMIT
RUN git fetch origin "${MKTORRENT_COMMIT}" && git checkout -q FETCH_HEAD

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
    shadow \
    su-exec \
    tmux \
    tzdata \
    util-linux \
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

COPY healthcheck.sh /healthcheck.sh
RUN chmod +x /healthcheck.sh

HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD /healthcheck.sh

ENTRYPOINT ["/entrypoint.sh"]
