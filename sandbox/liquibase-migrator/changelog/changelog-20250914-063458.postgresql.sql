-- liquibase formatted sql

-- changeset liquibase-user:1757831709869-1 splitStatements:false
ALTER TABLE "public"."categories" ALTER COLUMN  "created_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "categories" ALTER COLUMN "created_at" DROP DEFAULT;

-- changeset liquibase-user:1757831709869-2 splitStatements:false
ALTER TABLE "public"."comments" ALTER COLUMN  "created_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "comments" ALTER COLUMN "created_at" DROP DEFAULT;

-- changeset liquibase-user:1757831709869-3 splitStatements:false
ALTER TABLE "public"."posts" ALTER COLUMN  "created_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "posts" ALTER COLUMN "created_at" DROP DEFAULT;

-- changeset liquibase-user:1757831709869-4 splitStatements:false
ALTER TABLE "public"."tags" ALTER COLUMN  "created_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "tags" ALTER COLUMN "created_at" DROP DEFAULT;

-- changeset liquibase-user:1757831709869-5 splitStatements:false
ALTER TABLE "public"."user_profiles" ALTER COLUMN  "created_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "user_profiles" ALTER COLUMN "created_at" DROP DEFAULT;

-- changeset liquibase-user:1757831709869-6 splitStatements:false
ALTER TABLE "public"."users" ALTER COLUMN  "created_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "users" ALTER COLUMN "created_at" DROP DEFAULT;

-- changeset liquibase-user:1757831709869-7 splitStatements:false
ALTER TABLE "public"."categories" ALTER COLUMN  "updated_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "categories" ALTER COLUMN "updated_at" DROP DEFAULT;

-- changeset liquibase-user:1757831709869-8 splitStatements:false
ALTER TABLE "public"."comments" ALTER COLUMN  "updated_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "comments" ALTER COLUMN "updated_at" DROP DEFAULT;

-- changeset liquibase-user:1757831709869-9 splitStatements:false
ALTER TABLE "public"."posts" ALTER COLUMN  "updated_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "posts" ALTER COLUMN "updated_at" DROP DEFAULT;

-- changeset liquibase-user:1757831709869-10 splitStatements:false
ALTER TABLE "public"."tags" ALTER COLUMN  "updated_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "tags" ALTER COLUMN "updated_at" DROP DEFAULT;

-- changeset liquibase-user:1757831709869-11 splitStatements:false
ALTER TABLE "public"."user_profiles" ALTER COLUMN  "updated_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "user_profiles" ALTER COLUMN "updated_at" DROP DEFAULT;

-- changeset liquibase-user:1757831709869-12 splitStatements:false
ALTER TABLE "public"."users" ALTER COLUMN  "updated_at" SET DEFAULT NOW();
-- rollback ALTER TABLE "users" ALTER COLUMN "updated_at" DROP DEFAULT;
