FROM liquibase/liquibase:latest

LABEL org.opencontainers.image.title="Liquibase Migrator"
LABEL org.opencontainers.image.description="Liquibase database migration tool with custom scripts"
LABEL org.opencontainers.image.version="0.1.0"
LABEL org.opencontainers.image.source="https://github.com/migkit/migkit"
LABEL org.opencontainers.image.licenses="MIT"

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

WORKDIR /liquibase
RUN mkdir -p changelog schema

COPY scripts/migrate.sh /usr/local/bin/migrate
COPY scripts/rollback-sql.py /liquibase/
COPY scripts/rollback-xml.py /liquibase/

COPY changelog-schema/changelog.json /liquibase/changelog/changelog.json
COPY changelog-schema/changelog.xml /liquibase/changelog/changelog.xml

COPY liquibase-default.properties /liquibase/liquibase.properties

RUN chmod +x /usr/local/bin/migrate

ENTRYPOINT ["migrate"]
CMD ["--init"]
