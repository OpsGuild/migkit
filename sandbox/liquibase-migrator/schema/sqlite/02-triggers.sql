-- Database triggers for SQLite
-- This script contains triggers for maintaining data consistency

-- Create triggers for all tables with updated_at columns

-- Users table trigger
DROP TRIGGER IF EXISTS update_users_updated_at;
CREATE TRIGGER update_users_updated_at 
    AFTER UPDATE ON users 
    FOR EACH ROW 
BEGIN
    UPDATE users SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- Categories table trigger
DROP TRIGGER IF EXISTS update_categories_updated_at;
CREATE TRIGGER update_categories_updated_at 
    AFTER UPDATE ON categories 
    FOR EACH ROW 
BEGIN
    UPDATE categories SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- Posts table trigger
DROP TRIGGER IF EXISTS update_posts_updated_at;
CREATE TRIGGER update_posts_updated_at 
    AFTER UPDATE ON posts 
    FOR EACH ROW 
BEGIN
    UPDATE posts SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- Tags table trigger
DROP TRIGGER IF EXISTS update_tags_updated_at;
CREATE TRIGGER update_tags_updated_at 
    AFTER UPDATE ON tags 
    FOR EACH ROW 
BEGIN
    UPDATE tags SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- Comments table trigger
DROP TRIGGER IF EXISTS update_comments_updated_at;
CREATE TRIGGER update_comments_updated_at 
    AFTER UPDATE ON comments 
    FOR EACH ROW 
BEGIN
    UPDATE comments SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- User profiles table trigger
DROP TRIGGER IF EXISTS update_user_profiles_updated_at;
CREATE TRIGGER update_user_profiles_updated_at 
    AFTER UPDATE ON user_profiles 
    FOR EACH ROW 
BEGIN
    UPDATE user_profiles SET updated_at = CURRENT_TIMESTAMP WHERE user_id = NEW.user_id;
END;

