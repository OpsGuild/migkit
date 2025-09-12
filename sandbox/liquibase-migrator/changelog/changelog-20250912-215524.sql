-- liquibase formatted sql

-- changeset liquibase-user:1757714131799-1 splitStatements:false
ALTER TABLE "public"."categories" ALTER COLUMN  "created_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "public".categories ALTER COLUMN "created_at" DROP DEFAULT;

-- changeset liquibase-user:1757714131799-2 splitStatements:false
ALTER TABLE "public"."comments" ALTER COLUMN  "created_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "public".comments ALTER COLUMN "created_at" DROP DEFAULT;

-- changeset liquibase-user:1757714131799-3 splitStatements:false
ALTER TABLE "public"."posts" ALTER COLUMN  "created_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "public".posts ALTER COLUMN "created_at" DROP DEFAULT;

-- changeset liquibase-user:1757714131799-4 splitStatements:false
ALTER TABLE "public"."tags" ALTER COLUMN  "created_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "public".tags ALTER COLUMN "created_at" DROP DEFAULT;

-- changeset liquibase-user:1757714131799-5 splitStatements:false
ALTER TABLE "public"."user_profiles" ALTER COLUMN  "created_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "public".user_profiles ALTER COLUMN "created_at" DROP DEFAULT;

-- changeset liquibase-user:1757714131799-6 splitStatements:false
ALTER TABLE "public"."user_sessions" ALTER COLUMN  "created_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "public".user_sessions ALTER COLUMN "created_at" DROP DEFAULT;

-- changeset liquibase-user:1757714131799-7 splitStatements:false
ALTER TABLE "public"."users" ALTER COLUMN  "created_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "public".users ALTER COLUMN "created_at" DROP DEFAULT;

-- changeset liquibase-user:1757714131799-8 splitStatements:false
ALTER TABLE "public"."categories" ALTER COLUMN  "updated_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "public".categories ALTER COLUMN "updated_at" DROP DEFAULT;

-- changeset liquibase-user:1757714131799-9 splitStatements:false
ALTER TABLE "public"."comments" ALTER COLUMN  "updated_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "public".comments ALTER COLUMN "updated_at" DROP DEFAULT;

-- changeset liquibase-user:1757714131799-10 splitStatements:false
ALTER TABLE "public"."posts" ALTER COLUMN  "updated_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "public".posts ALTER COLUMN "updated_at" DROP DEFAULT;

-- changeset liquibase-user:1757714131799-11 splitStatements:false
ALTER TABLE "public"."tags" ALTER COLUMN  "updated_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "public".tags ALTER COLUMN "updated_at" DROP DEFAULT;

-- changeset liquibase-user:1757714131799-12 splitStatements:false
ALTER TABLE "public"."user_profiles" ALTER COLUMN  "updated_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "public".user_profiles ALTER COLUMN "updated_at" DROP DEFAULT;

-- changeset liquibase-user:1757714131799-13 splitStatements:false
ALTER TABLE "public"."users" ALTER COLUMN  "updated_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "public".users ALTER COLUMN "updated_at" DROP DEFAULT;
