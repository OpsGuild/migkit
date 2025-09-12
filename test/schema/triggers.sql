-- Database triggers
-- This script contains triggers for maintaining data consistency

-- Function to update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for all tables with updated_at columns
DO $$
DECLARE
    tbl_name TEXT;
    tables_with_updated_at TEXT[] := ARRAY[
        'users', 'categories', 'posts', 'tags', 'comments', 'user_profiles'
    ];
BEGIN
    FOREACH tbl_name IN ARRAY tables_with_updated_at
    LOOP
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = tbl_name AND table_schema = 'public') THEN
            EXECUTE format('DROP TRIGGER IF EXISTS update_%s_updated_at ON %I', tbl_name, tbl_name);
            EXECUTE format('CREATE TRIGGER update_%s_updated_at BEFORE UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION update_updated_at_column()', tbl_name, tbl_name);
        END IF;
    END LOOP;
END $$;
