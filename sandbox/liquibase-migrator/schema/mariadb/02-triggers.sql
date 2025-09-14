-- Database triggers for MariaDB/MySQL
-- This script contains triggers for maintaining data consistency

-- Create triggers for all tables with updated_at columns
DELIMITER $$

-- Users table trigger
DROP TRIGGER IF EXISTS update_users_updated_at$$
CREATE TRIGGER update_users_updated_at 
    BEFORE UPDATE ON users 
    FOR EACH ROW 
BEGIN
    SET NEW.updated_at = CURRENT_TIMESTAMP;
END$$

-- Categories table trigger
DROP TRIGGER IF EXISTS update_categories_updated_at$$
CREATE TRIGGER update_categories_updated_at 
    BEFORE UPDATE ON categories 
    FOR EACH ROW 
BEGIN
    SET NEW.updated_at = CURRENT_TIMESTAMP;
END$$

-- Posts table trigger
DROP TRIGGER IF EXISTS update_posts_updated_at$$
CREATE TRIGGER update_posts_updated_at 
    BEFORE UPDATE ON posts 
    FOR EACH ROW 
BEGIN
    SET NEW.updated_at = CURRENT_TIMESTAMP;
END$$

-- Tags table trigger
DROP TRIGGER IF EXISTS update_tags_updated_at$$
CREATE TRIGGER update_tags_updated_at 
    BEFORE UPDATE ON tags 
    FOR EACH ROW 
BEGIN
    SET NEW.updated_at = CURRENT_TIMESTAMP;
END$$

-- Comments table trigger
DROP TRIGGER IF EXISTS update_comments_updated_at$$
CREATE TRIGGER update_comments_updated_at 
    BEFORE UPDATE ON comments 
    FOR EACH ROW 
BEGIN
    SET NEW.updated_at = CURRENT_TIMESTAMP;
END$$

-- User profiles table trigger
DROP TRIGGER IF EXISTS update_user_profiles_updated_at$$
CREATE TRIGGER update_user_profiles_updated_at 
    BEFORE UPDATE ON user_profiles 
    FOR EACH ROW 
BEGIN
    SET NEW.updated_at = CURRENT_TIMESTAMP;
END$$

DELIMITER ;