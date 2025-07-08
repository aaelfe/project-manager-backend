-- Migration: Create proper epics table and update task relationships
-- Date: 2025-07-08

-- Create epics table
CREATE TABLE epics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(500) NOT NULL,
    description TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'cancelled')),
    priority VARCHAR(10) DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    due_date TIMESTAMP WITH TIME ZONE,
    markdown_file VARCHAR(500), -- Path to epic markdown file in repo
    github_repo VARCHAR(255) -- Format: "owner/repo"
);

-- Create indexes for epics
CREATE INDEX idx_epics_status ON epics(status);
CREATE INDEX idx_epics_project ON epics(project_id);
CREATE INDEX idx_epics_due_date ON epics(due_date);
CREATE INDEX idx_epics_created ON epics(created_at);

-- Add update trigger for epics
CREATE TRIGGER update_epics_updated_at BEFORE UPDATE ON epics FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Migrate existing epic data from tasks table
-- First, create epics from unique epic values in tasks table
INSERT INTO epics (title, project_id, status, created_at, updated_at)
SELECT DISTINCT
    t.epic as title,
    t.project_id,
    'active' as status,
    MIN(t.created_at) as created_at,
    MAX(t.updated_at) as updated_at
FROM tasks t
WHERE t.epic IS NOT NULL AND t.epic != ''
GROUP BY t.epic, t.project_id;

-- Add epic_id column to tasks table
ALTER TABLE tasks 
ADD COLUMN epic_id UUID REFERENCES epics(id) ON DELETE SET NULL;

-- Update tasks to reference the new epic_id
UPDATE tasks 
SET epic_id = e.id
FROM epics e
WHERE tasks.epic = e.title AND tasks.project_id = e.project_id;

-- Create index for epic_id on tasks
CREATE INDEX idx_tasks_epic_id ON tasks(epic_id);

-- Remove the old epic string column
ALTER TABLE tasks DROP COLUMN epic;

-- Drop the old epic index
DROP INDEX IF EXISTS idx_tasks_epic;

-- Update task_summary view to include epic information
DROP VIEW task_summary;

CREATE VIEW task_summary AS
SELECT 
    t.id,
    t.title,
    t.description,
    t.status,
    t.priority,
    t.due_date,
    t.created_at,
    t.updated_at,
    t.markdown_file,
    t.epic_id,
    e.title as epic_title,
    e.status as epic_status,
    p.name as project_name,
    p.id as project_id,
    ARRAY_AGG(tag.name) FILTER (WHERE tag.name IS NOT NULL) as tags,
    COUNT(tr.target_task_id) as dependency_count,
    COUNT(te.id) as time_entry_count,
    COALESCE(SUM(te.duration_minutes), 0) as total_time_minutes
FROM tasks t
LEFT JOIN projects p ON t.project_id = p.id
LEFT JOIN epics e ON t.epic_id = e.id
LEFT JOIN task_tags tt ON t.id = tt.task_id
LEFT JOIN tags tag ON tt.tag_id = tag.id
LEFT JOIN task_relationships tr ON t.id = tr.source_task_id AND tr.relationship_type = 'depends_on'
LEFT JOIN time_entries te ON t.id = te.task_id
GROUP BY t.id, t.title, t.description, t.status, t.priority, t.due_date, t.created_at, t.updated_at, t.markdown_file, t.epic_id, e.title, e.status, p.name, p.id;

-- Create epic_summary view
CREATE VIEW epic_summary AS
SELECT 
    e.id,
    e.title,
    e.description,
    e.status,
    e.priority,
    e.due_date,
    e.created_at,
    e.updated_at,
    e.markdown_file,
    e.github_repo,
    p.name as project_name,
    p.id as project_id,
    COUNT(t.id) as total_tasks,
    COUNT(CASE WHEN t.status = 'done' THEN 1 END) as completed_tasks,
    COUNT(CASE WHEN t.status = 'todo' THEN 1 END) as pending_tasks,
    COUNT(CASE WHEN t.status = 'in-progress' THEN 1 END) as active_tasks,
    COUNT(CASE WHEN t.status = 'blocked' THEN 1 END) as blocked_tasks,
    COALESCE(SUM(te.duration_minutes), 0) as total_time_minutes,
    CASE 
        WHEN COUNT(t.id) = 0 THEN 0
        ELSE ROUND((COUNT(CASE WHEN t.status = 'done' THEN 1 END) * 100.0 / COUNT(t.id)), 2)
    END as completion_percentage
FROM epics e
LEFT JOIN projects p ON e.project_id = p.id
LEFT JOIN tasks t ON e.id = t.epic_id
LEFT JOIN time_entries te ON t.id = te.task_id
GROUP BY e.id, e.title, e.description, e.status, e.priority, e.due_date, e.created_at, e.updated_at, e.markdown_file, e.github_repo, p.name, p.id;