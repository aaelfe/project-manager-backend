-- Migration: Add working_directory to projects and epic to tasks
-- Date: 2025-07-06

-- Add working_directory field to projects table
ALTER TABLE projects 
ADD COLUMN working_directory VARCHAR(500);

-- Add epic field to tasks table
ALTER TABLE tasks 
ADD COLUMN epic VARCHAR(255);

-- Add index for epic field to improve search performance
CREATE INDEX idx_tasks_epic ON tasks(epic);

-- Update the task_summary view to include epic field
DROP VIEW task_summary;

CREATE VIEW task_summary AS
SELECT 
    t.id,
    t.title,
    t.status,
    t.priority,
    t.due_date,
    t.created_at,
    t.updated_at,
    t.markdown_file,
    t.epic,
    p.name as project_name,
    p.id as project_id,
    ARRAY_AGG(tag.name) FILTER (WHERE tag.name IS NOT NULL) as tags,
    COUNT(tr.target_task_id) as dependency_count,
    COUNT(te.id) as time_entry_count,
    COALESCE(SUM(te.duration_minutes), 0) as total_time_minutes
FROM tasks t
LEFT JOIN projects p ON t.project_id = p.id
LEFT JOIN task_tags tt ON t.id = tt.task_id
LEFT JOIN tags tag ON tt.tag_id = tag.id
LEFT JOIN task_relationships tr ON t.id = tr.source_task_id AND tr.relationship_type = 'depends_on'
LEFT JOIN time_entries te ON t.id = te.task_id
GROUP BY t.id, p.name, p.id;

-- Update the project_summary view to include working_directory
DROP VIEW project_summary;

CREATE VIEW project_summary AS
SELECT 
    p.id,
    p.name,
    p.description,
    p.status,
    p.created_at,
    p.updated_at,
    p.markdown_file,
    p.github_repo,
    p.working_directory,
    COUNT(t.id) as total_tasks,
    COUNT(CASE WHEN t.status = 'done' THEN 1 END) as completed_tasks,
    COUNT(CASE WHEN t.status = 'todo' THEN 1 END) as pending_tasks,
    COUNT(CASE WHEN t.status = 'in-progress' THEN 1 END) as active_tasks,
    COALESCE(SUM(te.duration_minutes), 0) as total_time_minutes
FROM projects p
LEFT JOIN tasks t ON p.id = t.project_id
LEFT JOIN time_entries te ON t.id = te.task_id
GROUP BY p.id;