# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Build and Run
- `npm run build` - Compile TypeScript to JavaScript
- `npm run dev` - Run in development mode with hot reload using tsx
- `npm start` - Run the compiled server from dist/

### Database Operations
- Database migrations are in `supabase/migrations/`
- Run migrations manually through Supabase CLI or dashboard
- Latest migration: `20250708000001_create_epics_table.sql` (creates epics table and updates task relationships)

## Architecture Overview

This is a Model Context Protocol (MCP) server that provides project and task management capabilities through Claude AI integration. The system follows a clean architecture with these key components:

### Core Structure
- **MCP Server**: `src/mcp-server.ts` - Main server implementation using @modelcontextprotocol/sdk
- **Database Types**: `src/types/database.ts` - Auto-generated TypeScript types from Supabase
- **Database**: PostgreSQL via Supabase with comprehensive schema for projects, tasks, epics, tags, and relationships

### Key Domain Models
- **Projects**: Core project entities with GitHub integration and working directory support
- **Tasks**: Individual work items with status, priority, and epic organization
- **Epics**: Higher-level containers for organizing related tasks (migrated from string to proper table)
- **Tags**: Flexible labeling system with color coding
- **Relationships**: Task dependencies and hierarchical structures
- **Time Tracking**: Duration tracking for tasks (schema ready)

### Database Schema Evolution
The database has undergone significant evolution:
- Initial schema with basic project/task structure
- Added epic string field for task organization
- Recently migrated to proper epics table with full entity support
- Epic migration preserves existing data while establishing proper relationships

### MCP Integration
The server exposes resources and tools through the Model Context Protocol:
- **Resources**: `project://tasks`, `project://projects`, `project://task-summary`, `project://project-summary`
- **Tools**: CRUD operations for tasks/projects, advanced search, task linking, commenting
- **Validation**: Uses Zod schemas for input validation

## Important Implementation Notes

### Epic System Migration
The system recently migrated from string-based epics to a proper epics table:
- Old: `tasks.epic` (string field)
- New: `tasks.epic_id` (UUID reference to epics table)
- Migration preserves all existing epic data
- Views updated to include epic information

### Search and Filtering
- Multi-field project search prioritizes GitHub repo, working directory, then project name
- Advanced task filtering supports epic, tag, status, priority, and date ranges
- Uses PostgreSQL views for efficient summary data retrieval

### GitHub Integration
Both projects and tasks support:
- `github_repo` field in "owner/repo" format
- `markdown_file` field for file paths within repos
- `working_directory` field for local development paths (projects only)

## Environment Requirements

Required environment variables:
- `SUPABASE_URL` - Supabase project URL
- `SUPABASE_ANON_KEY` - Supabase anonymous key

## Development Notes

### Type Safety
- Full TypeScript implementation with strict mode enabled
- Auto-generated database types from Supabase
- Zod validation for all MCP tool inputs

### Module System
- Uses ES modules (`"type": "module"` in package.json)
- NodeNext module resolution
- Requires `.js` extensions in imports for compiled output

### Error Handling
- Comprehensive error handling in MCP tool implementations
- Database errors properly caught and returned as tool errors
- Input validation failures return descriptive error messages

## Testing

Currently no test framework is configured. The `npm test` command shows "Error: no test specified". Consider adding a testing framework like Jest or Vitest for future development.