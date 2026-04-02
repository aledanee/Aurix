# Stage 1: Build
FROM erlang:27-alpine AS builder

RUN apk add --no-cache git make gcc g++ libc-dev

WORKDIR /app

COPY rebar.config rebar.lock* ./
RUN rebar3 compile || true

COPY config/ config/
COPY src/ src/
COPY include/ include/

RUN rebar3 as prod release

# Stage 2: Runtime
FROM alpine:3.19

RUN apk add --no-cache openssl ncurses-libs libstdc++ libgcc

WORKDIR /app

COPY --from=builder /app/_build/prod/rel/aurix ./

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD wget -qO- http://localhost:8080/health || exit 1

ENTRYPOINT ["/app/bin/aurix"]
CMD ["foreground"]
