-- Add description field to task_summary view
DROP VIEW IF EXISTS task_summary;

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
GROUP BY t.id, t.title, t.description, t.status, t.priority, t.due_date, t.created_at, t.updated_at, t.markdown_file, p.name, p.id;