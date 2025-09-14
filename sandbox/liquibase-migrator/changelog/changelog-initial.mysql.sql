-- liquibase formatted sql

-- changeset liquibase-user:1757850219110-1 splitStatements:false
CREATE TABLE categories (id INT AUTO_INCREMENT NOT NULL, name VARCHAR(100) NOT NULL, `description` TEXT NULL, parent_id INT NULL, is_active BIT(1) DEFAULT 1 NULL, created_at TIMESTAMP(0) DEFAULT '1970-01-01 00:00:01' NULL, updated_at TIMESTAMP(0) DEFAULT '1970-01-01 00:00:01' NULL, CONSTRAINT PK_CATEGORIES PRIMARY KEY (id));
-- rollback -- Empty rollback (manual intervention required)

-- changeset liquibase-user:1757850219110-2 splitStatements:false
CREATE TABLE comments (id INT AUTO_INCREMENT NOT NULL, post_id INT NULL, user_id INT NULL, parent_id INT NULL, content TEXT NOT NULL, status VARCHAR(20) DEFAULT 'pending' NULL, created_at TIMESTAMP(0) DEFAULT '1970-01-01 00:00:01' NULL, updated_at TIMESTAMP(0) DEFAULT '1970-01-01 00:00:01' NULL, CONSTRAINT PK_COMMENTS PRIMARY KEY (id));
-- rollback -- Empty rollback (manual intervention required)

-- changeset liquibase-user:1757850219110-3 splitStatements:false
CREATE TABLE post_tags (post_id INT NOT NULL, tag_id INT NOT NULL, CONSTRAINT PK_POST_TAGS PRIMARY KEY (post_id, tag_id));
-- rollback -- Empty rollback (manual intervention required)

-- changeset liquibase-user:1757850219110-4 splitStatements:false
CREATE TABLE posts (id INT AUTO_INCREMENT NOT NULL, user_id INT NULL, category_id INT NULL, title VARCHAR(200) NOT NULL, slug VARCHAR(250) NOT NULL, content TEXT NULL, excerpt TEXT NULL, status VARCHAR(20) DEFAULT 'draft' NULL, published_at TIMESTAMP(0) NULL, created_at TIMESTAMP(0) DEFAULT '1970-01-01 00:00:01' NULL, updated_at TIMESTAMP(0) DEFAULT '1970-01-01 00:00:01' NULL, CONSTRAINT PK_POSTS PRIMARY KEY (id), UNIQUE (slug));
-- rollback -- Empty rollback (manual intervention required)

-- changeset liquibase-user:1757850219110-5 splitStatements:false
CREATE TABLE tags (id INT AUTO_INCREMENT NOT NULL, name VARCHAR(50) NOT NULL, color VARCHAR(7) DEFAULT '#007bff' NULL, created_at TIMESTAMP(0) DEFAULT '1970-01-01 00:00:01' NULL, updated_at TIMESTAMP(0) DEFAULT '1970-01-01 00:00:01' NULL, CONSTRAINT PK_TAGS PRIMARY KEY (id), UNIQUE (name));
-- rollback -- Empty rollback (manual intervention required)

-- changeset liquibase-user:1757850219110-6 splitStatements:false
CREATE TABLE user_profiles (user_id INT NOT NULL, bio TEXT NULL, avatar_url VARCHAR(500) NULL, website VARCHAR(200) NULL, location VARCHAR(100) NULL, birth_date date NULL, created_at TIMESTAMP(0) DEFAULT '1970-01-01 00:00:01' NULL, updated_at TIMESTAMP(0) DEFAULT '1970-01-01 00:00:01' NULL, CONSTRAINT PK_USER_PROFILES PRIMARY KEY (user_id));
-- rollback -- Empty rollback (manual intervention required)

-- changeset liquibase-user:1757850219110-7 splitStatements:false
CREATE TABLE users (id INT AUTO_INCREMENT NOT NULL, username VARCHAR(50) NOT NULL, email VARCHAR(100) NOT NULL, first_name VARCHAR(50) NULL, last_name VARCHAR(50) NULL, status VARCHAR(20) DEFAULT 'active' NULL, created_at TIMESTAMP(0) DEFAULT '1970-01-01 00:00:01' NULL, updated_at TIMESTAMP(0) DEFAULT '1970-01-01 00:00:01' NULL, CONSTRAINT PK_USERS PRIMARY KEY (id), UNIQUE (username), UNIQUE (email));
-- rollback -- Empty rollback (manual intervention required)

-- changeset liquibase-user:1757850219110-8 splitStatements:false
CREATE INDEX category_id ON posts(category_id);
-- rollback DROP INDEX IF EXISTS "category_id";

-- changeset liquibase-user:1757850219110-9 splitStatements:false
CREATE INDEX idx_categories_is_active ON categories(is_active);
-- rollback DROP INDEX IF EXISTS "idx_categories_is_active";

-- changeset liquibase-user:1757850219110-10 splitStatements:false
CREATE INDEX idx_comments_created_at ON comments(created_at);
-- rollback DROP INDEX IF EXISTS "idx_comments_created_at";

-- changeset liquibase-user:1757850219110-11 splitStatements:false
CREATE INDEX idx_comments_status ON comments(status);
-- rollback DROP INDEX IF EXISTS "idx_comments_status";

-- changeset liquibase-user:1757850219110-12 splitStatements:false
CREATE INDEX idx_posts_created_at ON posts(created_at);
-- rollback DROP INDEX IF EXISTS "idx_posts_created_at";

-- changeset liquibase-user:1757850219110-13 splitStatements:false
CREATE INDEX idx_posts_published_at ON posts(published_at);
-- rollback DROP INDEX IF EXISTS "idx_posts_published_at";

-- changeset liquibase-user:1757850219110-14 splitStatements:false
CREATE INDEX idx_posts_status ON posts(status);
-- rollback DROP INDEX IF EXISTS "idx_posts_status";

-- changeset liquibase-user:1757850219110-15 splitStatements:false
CREATE INDEX parent_id ON categories(parent_id);
-- rollback DROP INDEX IF EXISTS "parent_id";

-- changeset liquibase-user:1757850219110-16 splitStatements:false
CREATE INDEX parent_id ON comments(parent_id);
-- rollback DROP INDEX IF EXISTS "parent_id";

-- changeset liquibase-user:1757850219110-17 splitStatements:false
CREATE INDEX post_id ON comments(post_id);
-- rollback DROP INDEX IF EXISTS "post_id";

-- changeset liquibase-user:1757850219110-18 splitStatements:false
CREATE INDEX tag_id ON post_tags(tag_id);
-- rollback DROP INDEX IF EXISTS "tag_id";

-- changeset liquibase-user:1757850219110-19 splitStatements:false
CREATE INDEX user_id ON comments(user_id);
-- rollback DROP INDEX IF EXISTS "user_id";

-- changeset liquibase-user:1757850219110-20 splitStatements:false
CREATE INDEX user_id ON posts(user_id);
-- rollback DROP INDEX IF EXISTS "user_id";

-- changeset liquibase-user:1757850219110-21 splitStatements:false
ALTER TABLE categories ADD CONSTRAINT categories_ibfk_1 FOREIGN KEY (parent_id) REFERENCES categories (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
-- rollback -- Empty rollback (manual intervention required)

-- changeset liquibase-user:1757850219110-22 splitStatements:false
ALTER TABLE comments ADD CONSTRAINT comments_ibfk_1 FOREIGN KEY (post_id) REFERENCES posts (id) ON UPDATE RESTRICT ON DELETE CASCADE;
-- rollback -- Empty rollback (manual intervention required)

-- changeset liquibase-user:1757850219110-23 splitStatements:false
ALTER TABLE comments ADD CONSTRAINT comments_ibfk_2 FOREIGN KEY (user_id) REFERENCES users (id) ON UPDATE RESTRICT ON DELETE SET NULL;
-- rollback -- Empty rollback (manual intervention required)

-- changeset liquibase-user:1757850219110-24 splitStatements:false
ALTER TABLE comments ADD CONSTRAINT comments_ibfk_3 FOREIGN KEY (parent_id) REFERENCES comments (id) ON UPDATE RESTRICT ON DELETE CASCADE;
-- rollback -- Empty rollback (manual intervention required)

-- changeset liquibase-user:1757850219110-25 splitStatements:false
ALTER TABLE post_tags ADD CONSTRAINT post_tags_ibfk_1 FOREIGN KEY (post_id) REFERENCES posts (id) ON UPDATE RESTRICT ON DELETE CASCADE;
-- rollback -- Empty rollback (manual intervention required)

-- changeset liquibase-user:1757850219110-26 splitStatements:false
ALTER TABLE post_tags ADD CONSTRAINT post_tags_ibfk_2 FOREIGN KEY (tag_id) REFERENCES tags (id) ON UPDATE RESTRICT ON DELETE CASCADE;
-- rollback -- Empty rollback (manual intervention required)

-- changeset liquibase-user:1757850219110-27 splitStatements:false
ALTER TABLE posts ADD CONSTRAINT posts_ibfk_1 FOREIGN KEY (user_id) REFERENCES users (id) ON UPDATE RESTRICT ON DELETE CASCADE;
-- rollback -- Empty rollback (manual intervention required)

-- changeset liquibase-user:1757850219110-28 splitStatements:false
ALTER TABLE posts ADD CONSTRAINT posts_ibfk_2 FOREIGN KEY (category_id) REFERENCES categories (id) ON UPDATE RESTRICT ON DELETE SET NULL;
-- rollback -- Empty rollback (manual intervention required)

-- changeset liquibase-user:1757850219110-29 splitStatements:false
ALTER TABLE user_profiles ADD CONSTRAINT user_profiles_ibfk_1 FOREIGN KEY (user_id) REFERENCES users (id) ON UPDATE RESTRICT ON DELETE CASCADE;
-- rollback -- Empty rollback (manual intervention required)
