# Project Manager Backend

A Model Context Protocol (MCP) server for comprehensive project and task management, built with TypeScript and Supabase.

## Overview

This MCP server provides a unified interface for managing projects, tasks, tags, and relationships through Claude AI. It uses Supabase as the backend database and exposes resources and tools for project management workflows.

## Features

- **Project Management**: Create, update, and organize projects with status tracking
- **Task Management**: Full CRUD operations for tasks with priority levels, due dates, and status tracking
- **Tag System**: Flexible tagging system for categorizing tasks and projects
- **Task Relationships**: Support for dependencies, subtasks, and other relationships between tasks
- **Comments**: Add comments and notes to tasks
- **Time Tracking**: Track time spent on tasks (database schema ready)
- **Search & Filtering**: Advanced search capabilities with multiple filter options
- **GitHub Integration**: Link projects and tasks to GitHub repositories and markdown files

## Database Schema

The system uses PostgreSQL (Supabase) with the following main entities:

- **Projects**: Core project information with status and GitHub integration
- **Tasks**: Individual tasks with priorities, due dates, and project associations
- **Tags**: Flexible labeling system with color coding
- **Task Relationships**: Dependencies and other relationships between tasks
- **Task Comments**: Comments and notes on tasks
- **Time Entries**: Time tracking for tasks

## Available Resources

- `project://tasks` - Complete list of all tasks
- `project://projects` - Complete list of all projects  
- `project://task-summary` - Tasks with project names, tags, and metadata
- `project://project-summary` - Projects with task counts and progress

## Available Tools

### Task Management
- `create_task` - Create a new task with optional project assignment and tags
- `update_task` - Update existing task properties including status and priority
- `delete_task` - Remove a task from the system
- `search_tasks` - Advanced search with filters for status, priority, dates, and text
- `add_task_comment` - Add comments to tasks

### Project Management
- `create_project` - Create a new project with GitHub integration
- `update_project` - Update project properties and status

### Relationships
- `link_tasks` - Create relationships between tasks (dependencies, subtasks, etc.)

## Setup

1. **Environment Variables**
   ```bash
   SUPABASE_URL=your_supabase_url
   SUPABASE_ANON_KEY=your_supabase_anon_key
   ```

2. **Install Dependencies**
   ```bash
   npm install
   ```

3. **Database Setup**
   - Run the migration in `supabase/migrations/20250630055242_initial_schema.sql`
   - This creates all tables, indexes, views, and sample data

4. **Build & Run**
   ```bash
   npm run build
   npm start
   ```

   For development:
   ```bash
   npm run dev
   ```

## Task Status Options
- `todo` - Not started
- `in-progress` - Currently being worked on
- `done` - Completed
- `blocked` - Cannot proceed
- `cancelled` - No longer needed

## Priority Levels
- `low` - Can be done later
- `medium` - Standard priority
- `high` - Important task
- `urgent` - Needs immediate attention

## Project Status Options
- `active` - Currently being worked on
- `completed` - Project finished
- `archived` - No longer active

## Relationship Types
- `depends_on` - Source task depends on target task
- `blocks` - Source task blocks target task
- `subtask` - Source task is a subtask of target task
- `related` - Tasks are related
- `duplicate` - Tasks are duplicates

## GitHub Integration

Both projects and tasks support GitHub integration through:
- `github_repo` - Repository in "owner/repo" format
- `markdown_file` - Path to associated markdown file in the repository

This enables integration with note-taking systems like Obsidian or other markdown-based workflows.

## MCP Configuration

Add this server to your MCP configuration:

```json
{
  "mcpServers": {
    "project-manager": {
      "command": "node",
      "args": ["/path/to/project-manager-backend/dist/mcp-server.js"],
      "env": {
        "SUPABASE_URL": "your_supabase_url",
        "SUPABASE_ANON_KEY": "your_supabase_anon_key"
      }
    }
  }
}
```

## Development

The codebase uses:
- **TypeScript** for type safety
- **Zod** for input validation
- **Supabase** for database operations
- **MCP SDK** for Model Context Protocol implementation

Key files:
- `src/mcp-server.ts` - Main server implementation
- `src/types/database.ts` - TypeScript database types
- `supabase/migrations/` - Database schema and migrations

## License

ISC