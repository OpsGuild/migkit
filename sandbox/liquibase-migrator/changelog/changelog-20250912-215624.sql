-- liquibase formatted sql

-- changeset liquibase-user:1757714191879-1 splitStatements:false
ALTER TABLE "public"."categories" ALTER COLUMN  "created_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "public".categories ALTER COLUMN "created_at" DROP DEFAULT;

-- changeset liquibase-user:1757714191879-2 splitStatements:false
ALTER TABLE "public"."comments" ALTER COLUMN  "created_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "public".comments ALTER COLUMN "created_at" DROP DEFAULT;

-- changeset liquibase-user:1757714191879-3 splitStatements:false
ALTER TABLE "public"."posts" ALTER COLUMN  "created_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "public".posts ALTER COLUMN "created_at" DROP DEFAULT;

-- changeset liquibase-user:1757714191879-4 splitStatements:false
ALTER TABLE "public"."tags" ALTER COLUMN  "created_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "public".tags ALTER COLUMN "created_at" DROP DEFAULT;

-- changeset liquibase-user:1757714191879-5 splitStatements:false
ALTER TABLE "public"."user_profiles" ALTER COLUMN  "created_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "public".user_profiles ALTER COLUMN "created_at" DROP DEFAULT;

-- changeset liquibase-user:1757714191879-6 splitStatements:false
ALTER TABLE "public"."user_sessions" ALTER COLUMN  "created_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "public".user_sessions ALTER COLUMN "created_at" DROP DEFAULT;

-- changeset liquibase-user:1757714191879-7 splitStatements:false
ALTER TABLE "public"."users" ALTER COLUMN  "created_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "public".users ALTER COLUMN "created_at" DROP DEFAULT;

-- changeset liquibase-user:1757714191879-8 splitStatements:false
ALTER TABLE "public"."categories" ALTER COLUMN  "updated_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "public".categories ALTER COLUMN "updated_at" DROP DEFAULT;

-- changeset liquibase-user:1757714191879-9 splitStatements:false
ALTER TABLE "public"."comments" ALTER COLUMN  "updated_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "public".comments ALTER COLUMN "updated_at" DROP DEFAULT;

-- changeset liquibase-user:1757714191879-10 splitStatements:false
ALTER TABLE "public"."posts" ALTER COLUMN  "updated_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "public".posts ALTER COLUMN "updated_at" DROP DEFAULT;

-- changeset liquibase-user:1757714191879-11 splitStatements:false
ALTER TABLE "public"."tags" ALTER COLUMN  "updated_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "public".tags ALTER COLUMN "updated_at" DROP DEFAULT;

-- changeset liquibase-user:1757714191879-12 splitStatements:false
ALTER TABLE "public"."user_profiles" ALTER COLUMN  "updated_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "public".user_profiles ALTER COLUMN "updated_at" DROP DEFAULT;

-- changeset liquibase-user:1757714191879-13 splitStatements:false
ALTER TABLE "public"."users" ALTER COLUMN  "updated_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "public".users ALTER COLUMN "updated_at" DROP DEFAULT;
