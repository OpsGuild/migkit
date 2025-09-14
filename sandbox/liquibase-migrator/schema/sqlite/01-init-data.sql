-- Insert sample users (using basic schema first)
INSERT OR IGNORE INTO users (username, email) VALUES
('john_doe', 'john@example.com'),
('jane_smith', 'jane@example.com'),
('bob_wilson', 'bob@example.com'),
('alice_brown', 'alice@example.com'),
('charlie_davis', 'charlie@example.com');

-- Insert sample posts (using basic schema with required slug field)
INSERT OR IGNORE INTO posts (user_id, title, slug, content) VALUES
(1, 'Getting Started with React Hooks', 'getting-started-react-hooks', 'React Hooks are a powerful feature that allows you to use state and other React features in functional components...'),
(2, 'Advanced JavaScript Patterns', 'advanced-javascript-patterns', 'JavaScript has evolved significantly over the years, and with it, many advanced patterns have emerged...'),
(1, 'Building Mobile Apps with React Native', 'building-mobile-apps-react-native', 'React Native allows you to build mobile applications using React and JavaScript...'),
(4, 'My Trip to Japan', 'my-trip-japan', 'Last month I had the incredible opportunity to visit Japan for two weeks...'),
(5, 'Best Pizza in New York', 'best-pizza-new-york', 'After trying dozens of pizza places across New York City, here are my top recommendations...');

