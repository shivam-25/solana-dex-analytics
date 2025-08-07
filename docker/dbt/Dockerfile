FROM python:3.10-slim

RUN apt-get update && apt-get install -y \
    git \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir \
    dbt-core==1.7.4 \
    dbt-clickhouse==1.7.2 \
    clickhouse-driver==0.2.6 \
    clickhouse-cityhash \
    lz4 \
    "protobuf>=3.20,<5"

WORKDIR /usr/app/dbt

ENTRYPOINT ["dbt"]