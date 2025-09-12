FROM liquibase/liquibase:latest

# Install postgres client, jq, python3
USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
      postgresql-client \
      jq \
      python3 \
      python3-pip \
      bash \
      curl \
      ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create working directory
WORKDIR /liquibase

# Copy migration script and helpers
COPY scripts/migrate.sh /usr/local/bin/migrate
COPY scripts/rollback-sql.py rollback-xml.py /liquibase/

# Copy changelogs schema
COPY changelogs-schema /liquibase/changelogs-schema

# Ensure script is executable
RUN chmod +x /usr/local/bin/migrate

# Default entrypoint
ENTRYPOINT ["migrate"]
CMD ["--init"]
