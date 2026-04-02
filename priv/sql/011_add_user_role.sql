-- 011_add_user_role.sql
-- Add role column for admin authorization.

ALTER TABLE users ADD COLUMN IF NOT EXISTS role varchar(32) NOT NULL DEFAULT 'user';

-- Partial index for efficient admin lookups
CREATE INDEX IF NOT EXISTS idx_users_role ON users (role) WHERE role = 'admin';
