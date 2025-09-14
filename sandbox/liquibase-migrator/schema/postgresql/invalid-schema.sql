-- Invalid schema for testing error handling
-- This file contains invalid SQL to test error scenarios

CREATE TABLE invalid_table (
    id INVALID_TYPE PRIMARY KEY,
    name VARCHAR(100)
);

-- This should cause an error
INVALID SQL STATEMENT;
