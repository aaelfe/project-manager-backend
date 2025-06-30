-- Database Schema for Project Management System
-- Using PostgreSQL (Supabase/Neon compatible)

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Projects table
CREATE TABLE projects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'archived')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    markdown_file VARCHAR(500), -- Path to project markdown file in repo
    github_repo VARCHAR(255), -- Format: "owner/repo"
    
    -- Indexes
    CONSTRAINT projects_name_unique UNIQUE (name)
);

-- Tasks table
CREATE TABLE tasks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(500) NOT NULL,
    description TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'todo' CHECK (status IN ('todo', 'in-progress', 'done', 'blocked', 'cancelled')),
    priority VARCHAR(10) DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    due_date TIMESTAMP WITH TIME ZONE,
    markdown_file VARCHAR(500), -- Path to task markdown file in repo
    github_repo VARCHAR(255) -- Format: "owner/repo"
);

-- Tags table for flexible labeling
CREATE TABLE tags (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    color VARCHAR(7), -- Hex color code
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT tags_name_unique UNIQUE (name)
);

-- Task-Tag relationships (many-to-many)
CREATE TABLE task_tags (
    task_id UUID REFERENCES tasks(id) ON DELETE CASCADE,
    tag_id UUID REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (task_id, tag_id)
);

-- Task relationships (dependencies, subtasks, etc.)
CREATE TABLE task_relationships (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_task_id UUID REFERENCES tasks(id) ON DELETE CASCADE,
    target_task_id UUID REFERENCES tasks(id) ON DELETE CASCADE,
    relationship_type VARCHAR(20) NOT NULL CHECK (relationship_type IN ('depends_on', 'blocks', 'subtask', 'related', 'duplicate')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Prevent self-references and duplicates
    CONSTRAINT no_self_reference CHECK (source_task_id != target_task_id),
    CONSTRAINT unique_relationship UNIQUE (source_task_id, target_task_id, relationship_type)
);

-- Comments/Notes on tasks
CREATE TABLE task_comments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    task_id UUID REFERENCES tasks(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Time tracking
CREATE TABLE time_entries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    task_id UUID REFERENCES tasks(id) ON DELETE CASCADE,
    description TEXT,
    start_time TIMESTAMP WITH TIME ZONE NOT NULL,
    end_time TIMESTAMP WITH TIME ZONE,
    duration_minutes INTEGER, -- Calculated field
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes separately (PostgreSQL syntax)
CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_tasks_project ON tasks(project_id);
CREATE INDEX idx_tasks_due_date ON tasks(due_date);
CREATE INDEX idx_tasks_created ON tasks(created_at);
CREATE INDEX idx_comments_task ON task_comments(task_id);
CREATE INDEX idx_comments_created ON task_comments(created_at);
CREATE INDEX idx_time_entries_task ON time_entries(task_id);
CREATE INDEX idx_time_entries_start ON time_entries(start_time);

-- Update timestamps trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply update triggers
CREATE TRIGGER update_projects_updated_at BEFORE UPDATE ON projects FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_tasks_updated_at BEFORE UPDATE ON tasks FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Useful views for common queries
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

CREATE VIEW project_summary AS
SELECT 
    p.id,
    p.name,
    p.description,
    p.status,
    p.created_at,
    p.updated_at,
    p.markdown_file,
    COUNT(t.id) as total_tasks,
    COUNT(CASE WHEN t.status = 'done' THEN 1 END) as completed_tasks,
    COUNT(CASE WHEN t.status = 'todo' THEN 1 END) as pending_tasks,
    COUNT(CASE WHEN t.status = 'in-progress' THEN 1 END) as active_tasks,
    COALESCE(SUM(te.duration_minutes), 0) as total_time_minutes
FROM projects p
LEFT JOIN tasks t ON p.id = t.project_id
LEFT JOIN time_entries te ON t.id = te.task_id
GROUP BY p.id;

-- Sample data (optional)
INSERT INTO projects (name, description, github_repo, markdown_file) VALUES
('Web Redesign', 'Complete redesign of company website', 'yourname/obsidian-vault', 'Projects/Web Redesign/project.md'),
('Database Migration', 'Migrate legacy database to new schema', 'yourname/obsidian-vault', 'Projects/Database Migration/project.md');

INSERT INTO tags (name, color) VALUES
('urgent', '#ff4444'),
('design', '#44ff44'),
('backend', '#4444ff'),
('frontend', '#ffff44'),
('research', '#ff44ff');

-- Example tasks
INSERT INTO tasks (title, description, project_id, status, priority, markdown_file, github_repo) 
SELECT 
    'Design homepage mockup',
    'Create initial design concepts for new homepage',
    p.id,
    'todo',
    'high',
    'Projects/Web Redesign/tasks/homepage-design.md',
    'yourname/obsidian-vault'
FROM projects p WHERE p.name = 'Web Redesign';

INSERT INTO tasks (title, description, project_id, status, priority, markdown_file, github_repo)
SELECT 
    'Set up development environment',
    'Configure local dev environment for new site',
    p.id,
    'in-progress',
    'medium',
    'Projects/Web Redesign/tasks/dev-setup.md',
    'yourname/obsidian-vault'
FROM projects p WHERE p.name = 'Web Redesign';