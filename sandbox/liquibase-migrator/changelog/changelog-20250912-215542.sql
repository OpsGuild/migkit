-- liquibase formatted sql

-- changeset liquibase-user:1757714149276-1 splitStatements:false
ALTER TABLE "public"."categories" ALTER COLUMN  "created_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "public".categories ALTER COLUMN "created_at" DROP DEFAULT;

-- changeset liquibase-user:1757714149276-2 splitStatements:false
ALTER TABLE "public"."comments" ALTER COLUMN  "created_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "public".comments ALTER COLUMN "created_at" DROP DEFAULT;

-- changeset liquibase-user:1757714149276-3 splitStatements:false
ALTER TABLE "public"."posts" ALTER COLUMN  "created_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "public".posts ALTER COLUMN "created_at" DROP DEFAULT;

-- changeset liquibase-user:1757714149276-4 splitStatements:false
ALTER TABLE "public"."tags" ALTER COLUMN  "created_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "public".tags ALTER COLUMN "created_at" DROP DEFAULT;

-- changeset liquibase-user:1757714149276-5 splitStatements:false
ALTER TABLE "public"."user_profiles" ALTER COLUMN  "created_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "public".user_profiles ALTER COLUMN "created_at" DROP DEFAULT;

-- changeset liquibase-user:1757714149276-6 splitStatements:false
ALTER TABLE "public"."user_sessions" ALTER COLUMN  "created_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "public".user_sessions ALTER COLUMN "created_at" DROP DEFAULT;

-- changeset liquibase-user:1757714149276-7 splitStatements:false
ALTER TABLE "public"."users" ALTER COLUMN  "created_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "public".users ALTER COLUMN "created_at" DROP DEFAULT;

-- changeset liquibase-user:1757714149276-8 splitStatements:false
ALTER TABLE "public"."categories" ALTER COLUMN  "updated_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "public".categories ALTER COLUMN "updated_at" DROP DEFAULT;

-- changeset liquibase-user:1757714149276-9 splitStatements:false
ALTER TABLE "public"."comments" ALTER COLUMN  "updated_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "public".comments ALTER COLUMN "updated_at" DROP DEFAULT;

-- changeset liquibase-user:1757714149276-10 splitStatements:false
ALTER TABLE "public"."posts" ALTER COLUMN  "updated_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "public".posts ALTER COLUMN "updated_at" DROP DEFAULT;

-- changeset liquibase-user:1757714149276-11 splitStatements:false
ALTER TABLE "public"."tags" ALTER COLUMN  "updated_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "public".tags ALTER COLUMN "updated_at" DROP DEFAULT;

-- changeset liquibase-user:1757714149276-12 splitStatements:false
ALTER TABLE "public"."user_profiles" ALTER COLUMN  "updated_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "public".user_profiles ALTER COLUMN "updated_at" DROP DEFAULT;

-- changeset liquibase-user:1757714149276-13 splitStatements:false
ALTER TABLE "public"."users" ALTER COLUMN  "updated_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "public".users ALTER COLUMN "updated_at" DROP DEFAULT;
