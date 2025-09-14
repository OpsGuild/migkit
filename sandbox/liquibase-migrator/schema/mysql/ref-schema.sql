-- Reference schema for migration testing (MariaDB/MySQL version)
-- This schema has additional changes that will be used to generate changelogs

-- Users table with additional fields
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended')),
    phone VARCHAR(20),  -- Additional field
    last_login TIMESTAMP NULL,  -- Additional field
    created_at TIMESTAMP DEFAULT '1970-01-01 00:00:01',
    updated_at TIMESTAMP DEFAULT '1970-01-01 00:00:01'
);

-- Categories table
CREATE TABLE categories (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    parent_id INT,
    is_active TINYINT(1) DEFAULT 1,
    created_at TIMESTAMP DEFAULT '1970-01-01 00:00:01',
    updated_at TIMESTAMP DEFAULT '1970-01-01 00:00:01',
    FOREIGN KEY (parent_id) REFERENCES categories(id)
);

-- Posts table with additional fields
CREATE TABLE posts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    category_id INT,
    title VARCHAR(200) NOT NULL,
    slug VARCHAR(250) UNIQUE NOT NULL,
    content TEXT,
    excerpt TEXT,
    status VARCHAR(20) DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'archived')),
    view_count INT DEFAULT 0,  -- Additional field
    featured TINYINT(1) DEFAULT 0,  -- Additional field
    published_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT '1970-01-01 00:00:01',
    updated_at TIMESTAMP DEFAULT '1970-01-01 00:00:01',
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
);

-- Tags table
CREATE TABLE tags (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    color VARCHAR(7) DEFAULT '#007bff',
    created_at TIMESTAMP DEFAULT '1970-01-01 00:00:01',
    updated_at TIMESTAMP DEFAULT '1970-01-01 00:00:01'
);

-- Post tags junction table
CREATE TABLE post_tags (
    post_id INT,
    tag_id INT,
    PRIMARY KEY (post_id, tag_id),
    FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
    FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
);

-- Comments table
CREATE TABLE comments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    post_id INT,
    user_id INT,
    parent_id INT,
    content TEXT NOT NULL,
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'spam')),
    created_at TIMESTAMP DEFAULT '1970-01-01 00:00:01',
    updated_at TIMESTAMP DEFAULT '1970-01-01 00:00:01',
    FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (parent_id) REFERENCES comments(id) ON DELETE CASCADE
);

-- User profiles table
CREATE TABLE user_profiles (
    user_id INT PRIMARY KEY,
    bio TEXT,
    avatar_url VARCHAR(500),
    website VARCHAR(200),
    location VARCHAR(100),
    birth_date DATE,
    created_at TIMESTAMP DEFAULT '1970-01-01 00:00:01',
    updated_at TIMESTAMP DEFAULT '1970-01-01 00:00:01',
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Additional table for user sessions
CREATE TABLE user_sessions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    session_token VARCHAR(255) UNIQUE NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT '1970-01-01 00:00:01',
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Create indexes for better performance
CREATE INDEX idx_posts_user_id ON posts(user_id);
CREATE INDEX idx_posts_category_id ON posts(category_id);
CREATE INDEX idx_posts_status ON posts(status);
CREATE INDEX idx_posts_published_at ON posts(published_at);
CREATE INDEX idx_posts_created_at ON posts(created_at);
CREATE INDEX idx_posts_slug ON posts(slug);
CREATE INDEX idx_posts_featured ON posts(featured);  -- Additional index
CREATE INDEX idx_posts_view_count ON posts(view_count);  -- Additional index

CREATE INDEX idx_comments_post_id ON comments(post_id);
CREATE INDEX idx_comments_user_id ON comments(user_id);
CREATE INDEX idx_comments_parent_id ON comments(parent_id);
CREATE INDEX idx_comments_status ON comments(status);
CREATE INDEX idx_comments_created_at ON comments(created_at);

CREATE INDEX idx_categories_parent_id ON categories(parent_id);
CREATE INDEX idx_categories_is_active ON categories(is_active);

CREATE INDEX idx_post_tags_post_id ON post_tags(post_id);
CREATE INDEX idx_post_tags_tag_id ON post_tags(tag_id);

CREATE INDEX idx_user_sessions_user_id ON user_sessions(user_id);  -- Additional index
CREATE INDEX idx_user_sessions_expires_at ON user_sessions(expires_at);  -- Additional index