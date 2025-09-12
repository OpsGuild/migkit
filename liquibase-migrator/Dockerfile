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
      bash \
      curl \
      ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /liquibase
RUN mkdir -p changelog schema

COPY scripts/migrate.sh /usr/local/bin/migrate
COPY scripts/rollback-sql.sh /liquibase/
COPY scripts/rollback-xml.sh /liquibase/
COPY scripts/fix-changelog-order.sh /liquibase/

COPY changelog-schema/changelog.json /liquibase/changelog/changelog.json
COPY changelog-schema/changelog.xml /liquibase/changelog/changelog.xml

COPY liquibase-default.properties /liquibase/liquibase.properties

RUN chmod +x /usr/local/bin/migrate /liquibase/rollback-sql.sh /liquibase/rollback-xml.sh /liquibase/fix-changelog-order.sh

ENTRYPOINT ["migrate"]
CMD ["--init"]
