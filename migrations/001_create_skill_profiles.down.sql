-- Rollback skill_profiles migration

DROP TRIGGER IF EXISTS trigger_skill_profiles_updated_at ON skill_profiles;
DROP FUNCTION IF EXISTS update_skill_profiles_updated_at();
DROP INDEX IF EXISTS idx_skill_profiles_application;
DROP TABLE IF EXISTS skill_profiles;
