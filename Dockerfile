# Stage 1: Build
FROM erlang:27-alpine AS builder

RUN apk add --no-cache git make gcc g++ libc-dev bsd-compat-headers

WORKDIR /app

COPY rebar.config rebar.lock* ./
RUN rebar3 compile || true

COPY config/ config/
COPY src/ src/
COPY include/ include/
COPY priv/ priv/

RUN rebar3 as prod release

# Stage 2: Runtime
FROM erlang:27-alpine

RUN apk add --no-cache curl

WORKDIR /app

COPY --from=builder /app/_build/prod/rel/aurix ./

EXPOSE 8080

HEALTHCHECK --interval=10s --timeout=5s --start-period=15s --retries=3 \
    CMD curl -sf http://localhost:8080/health || exit 1

ENTRYPOINT ["/app/bin/aurix"]
CMD ["foreground"]
