-- Test data for migration testing
-- This data will be inserted into the reference database

-- Insert test users
INSERT INTO users (username, email, first_name, last_name, status) VALUES
('john_doe', 'john@example.com', 'John', 'Doe', 'active'),
('jane_smith', 'jane@example.com', 'Jane', 'Smith', 'active'),
('bob_wilson', 'bob@example.com', 'Bob', 'Wilson', 'active'),
('alice_brown', 'alice@example.com', 'Alice', 'Brown', 'active'),
('charlie_davis', 'charlie@example.com', 'Charlie', 'Davis', 'active');

-- Insert test categories
INSERT INTO categories (name, description, is_active) VALUES
('Technology', 'Posts about technology and programming', true),
('Lifestyle', 'Posts about lifestyle and personal experiences', true),
('Business', 'Posts about business and entrepreneurship', true);

-- Insert test posts
INSERT INTO posts (title, slug, content, excerpt, user_id, category_id, status, published_at) VALUES
('Getting Started with Docker', 'getting-started-with-docker', 'Docker is a powerful containerization platform...', 'Learn the basics of Docker', 1, 1, 'published', CURRENT_TIMESTAMP),
('Healthy Living Tips', 'healthy-living-tips', 'Maintaining a healthy lifestyle is important...', 'Tips for a healthier life', 2, 2, 'published', CURRENT_TIMESTAMP),
('Startup Success Stories', 'startup-success-stories', 'Many successful startups share common traits...', 'What makes startups successful', 3, 3, 'draft', NULL),
('Advanced SQL Techniques', 'advanced-sql-techniques', 'SQL can be much more powerful than basic queries...', 'Master advanced SQL', 1, 1, 'published', CURRENT_TIMESTAMP),
('Work-Life Balance', 'work-life-balance', 'Finding the right balance between work and life...', 'Balancing work and personal life', 4, 2, 'published', CURRENT_TIMESTAMP);

-- Insert test tags
INSERT INTO tags (name, color) VALUES
('docker', '#007bff'),
('programming', '#28a745'),
('health', '#dc3545'),
('business', '#ffc107'),
('sql', '#17a2b8'),
('lifestyle', '#6f42c1');

-- Insert post tags
INSERT INTO post_tags (post_id, tag_id) VALUES
(1, 1), (1, 2), (2, 3), (2, 6), (3, 4), (4, 2), (4, 5), (5, 6);

-- Insert test comments
INSERT INTO comments (post_id, user_id, content, status) VALUES
(1, 2, 'Great introduction to Docker!', 'approved'),
(1, 3, 'Very helpful, thanks for sharing.', 'approved'),
(2, 1, 'These tips are really practical.', 'approved'),
(4, 2, 'Advanced SQL is so powerful!', 'approved'),
(5, 3, 'Work-life balance is crucial.', 'approved');

-- Insert user profiles
INSERT INTO user_profiles (user_id, bio, website, location) VALUES
(1, 'Software developer passionate about DevOps', 'https://johndoe.dev', 'San Francisco, CA'),
(2, 'Health and wellness enthusiast', 'https://janesmith.health', 'New York, NY'),
(3, 'Entrepreneur and business consultant', 'https://bobwilson.biz', 'Austin, TX'),
(4, 'Life coach and productivity expert', 'https://alicebrown.life', 'Seattle, WA'),
(5, 'Tech writer and developer advocate', 'https://charliedavis.tech', 'Boston, MA');
