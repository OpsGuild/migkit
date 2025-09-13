--liquibase formatted sql

--changeset migkit:add-user-fields
-- Add new columns to users table
ALTER TABLE users ADD COLUMN phone VARCHAR(20);
ALTER TABLE users ADD COLUMN last_login TIMESTAMP;
ALTER TABLE users ADD COLUMN is_active BOOLEAN DEFAULT true;

--changeset migkit:add-user-sessions-table
-- Create user sessions table
CREATE TABLE user_sessions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    session_token VARCHAR(255) UNIQUE NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_user_sessions_user_id ON user_sessions(user_id);
CREATE INDEX idx_user_sessions_expires_at ON user_sessions(expires_at);

--changeset migkit:add-post-fields
-- Add new columns to posts table
ALTER TABLE posts ADD COLUMN view_count INTEGER DEFAULT 0;
ALTER TABLE posts ADD COLUMN featured BOOLEAN DEFAULT false;
ALTER TABLE posts ADD COLUMN published_at TIMESTAMP;

CREATE INDEX idx_posts_featured ON posts(featured);
CREATE INDEX idx_posts_view_count ON posts(view_count);
CREATE INDEX idx_posts_published_at ON posts(published_at);

--changeset migkit:add-audit-table
-- Create audit log table
CREATE TABLE audit_log (
    id SERIAL PRIMARY KEY,
    table_name VARCHAR(100) NOT NULL,
    record_id INTEGER NOT NULL,
    action VARCHAR(20) NOT NULL,
    old_values JSONB,
    new_values JSONB,
    changed_by INTEGER REFERENCES users(id),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_audit_log_table_record ON audit_log(table_name, record_id);
CREATE INDEX idx_audit_log_changed_at ON audit_log(changed_at);

--changeset migkit:add-data-constraints
-- Add check constraints
ALTER TABLE users ADD CONSTRAINT chk_email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');
ALTER TABLE posts ADD CONSTRAINT chk_status_values CHECK (status IN ('draft', 'published', 'archived'));
ALTER TABLE user_sessions ADD CONSTRAINT chk_expires_future CHECK (expires_at > created_at);

--changeset migkit:insert-test-data
-- Insert test data for new features
INSERT INTO user_sessions (user_id, session_token, expires_at) VALUES
(1, 'session_token_1', CURRENT_TIMESTAMP + INTERVAL '1 day'),
(2, 'session_token_2', CURRENT_TIMESTAMP + INTERVAL '2 days'),
(3, 'session_token_3', CURRENT_TIMESTAMP + INTERVAL '1 hour');

UPDATE posts SET published_at = created_at WHERE status = 'published';
UPDATE posts SET view_count = FLOOR(RANDOM() * 1000) WHERE status = 'published';
UPDATE posts SET featured = true WHERE id IN (1, 4);

--changeset migkit:add-complex-view
-- Create a complex view
CREATE VIEW post_statistics AS
SELECT 
    p.id,
    p.title,
    p.status,
    p.view_count,
    p.featured,
    u.username as author,
    c.name as category,
    COUNT(DISTINCT cm.id) as comment_count,
    COUNT(DISTINCT pt.tag_id) as tag_count,
    p.created_at,
    p.published_at
FROM posts p
LEFT JOIN users u ON p.user_id = u.id
LEFT JOIN categories c ON p.category_id = c.id
LEFT JOIN comments cm ON p.id = cm.post_id
LEFT JOIN post_tags pt ON p.id = pt.post_id
GROUP BY p.id, p.title, p.status, p.view_count, p.featured, u.username, c.name, p.created_at, p.published_at;

--changeset migkit:add-stored-procedure
-- Create stored procedure
CREATE OR REPLACE FUNCTION update_post_view_count(post_id INTEGER)
RETURNS VOID AS $$
BEGIN
    UPDATE posts 
    SET view_count = view_count + 1 
    WHERE id = post_id;
    
    INSERT INTO audit_log (table_name, record_id, action, new_values, changed_at)
    VALUES ('posts', post_id, 'UPDATE', jsonb_build_object('view_count', view_count + 1), CURRENT_TIMESTAMP);
END;
$$ LANGUAGE plpgsql;

--changeset migkit:add-trigger
-- Create trigger for updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_posts_updated_at
    BEFORE UPDATE ON posts
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
