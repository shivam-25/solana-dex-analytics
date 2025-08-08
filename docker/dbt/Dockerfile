FROM python:3.10-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /usr/app

# Install dbt and clickhouse adapter
RUN pip install --no-cache-dir \
    dbt-core==1.7.4 \
    dbt-clickhouse==1.7.2 \
    clickhouse-driver \
    clickhouse-cityhash

# Create dbt directory structure
RUN mkdir -p /usr/app/dbt

# Set environment variables
ENV DBT_PROFILES_DIR=/usr/app/dbt

# Copy dbt project files (will be mounted as volume)
COPY entrypoint.sh /usr/app/entrypoint.sh
RUN chmod +x /usr/app/entrypoint.sh

ENTRYPOINT ["/usr/app/entrypoint.sh"]
CMD ["tail", "-f", "/dev/null"]