FROM liquibase/liquibase:latest

LABEL org.opencontainers.image.title="Liquibase Migrator"
LABEL org.opencontainers.image.description="Liquibase database migration tool with custom scripts"
LABEL org.opencontainers.image.version="0.1.0"
LABEL org.opencontainers.image.source="https://github.com/migkit/migkit"
LABEL org.opencontainers.image.licenses="MIT"

USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
      postgresql-client \
      mysql-client \
      sqlite3 \
      netcat-openbsd \
      jq \
      bash \
      curl \
      ca-certificates \
      wget \
    && rm -rf /var/lib/apt/lists/*

# Download and install MySQL JDBC driver
RUN wget -O /tmp/mysql-connector-java-8.0.33.jar \
    https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/8.0.33/mysql-connector-j-8.0.33.jar \
    && mkdir -p /liquibase/lib \
    && cp /tmp/mysql-connector-java-8.0.33.jar /liquibase/lib/ \
    && rm /tmp/mysql-connector-java-8.0.33.jar

# Create a user with UID 1000 to match the host user
RUN groupadd -g 1000 liquibase-user && \
    useradd -u 1000 -g 1000 -m liquibase-user

WORKDIR /liquibase
RUN mkdir -p changelog schema

COPY scripts/migrate.sh /usr/local/bin/migrate
COPY scripts/rollback-sql.sh /liquibase/
COPY scripts/rollback-xml.sh /liquibase/
COPY scripts/fix-changelog-order.sh /liquibase/
COPY scripts/deduplicate-constraints.sh /liquibase/

COPY changelog-schema/changelog.json /liquibase/changelog/changelog.json
COPY changelog-schema/changelog.xml /liquibase/changelog/changelog.xml

COPY liquibase-default.properties /liquibase/liquibase.properties

RUN chmod +x /usr/local/bin/migrate /liquibase/rollback-sql.sh /liquibase/rollback-xml.sh /liquibase/fix-changelog-order.sh /liquibase/deduplicate-constraints.sh

# Fix permissions for the liquibase-user
RUN chown -R liquibase-user:liquibase-user /liquibase && \
    chmod -R 755 /liquibase

# Switch to the liquibase-user
USER liquibase-user

ENTRYPOINT ["migrate"]
CMD ["--init"]
