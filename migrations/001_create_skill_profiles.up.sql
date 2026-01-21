-- Skill Profiles Migration
--
-- This migration creates the skill_profiles table for storing
-- per-application skill configurations, learnings, and conventions.
--
-- Usage: Run this migration when setting up Brahmi (orchestrator API)
-- with PostgreSQL backend.

-- Create skill_profiles table
CREATE TABLE IF NOT EXISTS skill_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id UUID NOT NULL UNIQUE,
    skills TEXT[] NOT NULL DEFAULT '{}',
    learnings JSONB DEFAULT '[]'::jsonb,
    conventions JSONB DEFAULT '[]'::jsonb,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for fast lookups by application_id
CREATE INDEX IF NOT EXISTS idx_skill_profiles_application
    ON skill_profiles(application_id);

-- Trigger to auto-update updated_at
CREATE OR REPLACE FUNCTION update_skill_profiles_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_skill_profiles_updated_at
    BEFORE UPDATE ON skill_profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_skill_profiles_updated_at();

-- Comments
COMMENT ON TABLE skill_profiles IS 'Stores skill configurations and learnings per application';
COMMENT ON COLUMN skill_profiles.application_id IS 'Unique identifier for the application/repository';
COMMENT ON COLUMN skill_profiles.skills IS 'Array of skill IDs used by this application';
COMMENT ON COLUMN skill_profiles.learnings IS 'JSON array of learnings from failures and feedback';
COMMENT ON COLUMN skill_profiles.conventions IS 'JSON array of project-specific conventions';
