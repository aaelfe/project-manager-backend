import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { createClient } from '@supabase/supabase-js';
import { z } from 'zod';
import type { Database } from './types/database.js';
import dotenv from 'dotenv';

dotenv.config();
const SUPABASE_URL = process.env.SUPABASE_URL!;
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY!;

// Initialize Supabase client
const supabase = createClient<Database>(SUPABASE_URL, SUPABASE_ANON_KEY);


class ProjectMCPServer {
    private server: McpServer;

    constructor() {
        this.server = new McpServer({
            name: "project-manager",
            version: "1.0.0"
        });

        this.setupHandlers();
    }

    private setupHandlers() {
        // Register resources
        this.server.registerResource(
            "tasks",
            "project://tasks",
            {
                title: "All Tasks",
                description: "Complete list of all tasks across projects",
                mimeType: "application/json"
            },
            async () => await this.getTasksResource()
        );

        this.server.registerResource(
            "projects",
            "project://projects",
            {
                title: "All Projects",
                description: "Complete list of all projects",
                mimeType: "application/json"
            },
            async () => await this.getProjectsResource()
        );

        this.server.registerResource(
            "task-summary",
            "project://task-summary",
            {
                title: "Task Summary",
                description: "Tasks with project names, tags, and metadata",
                mimeType: "application/json"
            },
            async () => await this.getTaskSummaryResource()
        );

        this.server.registerResource(
            "project-summary",
            "project://project-summary",
            {
                title: "Project Summary",
                description: "Projects with task counts and progress",
                mimeType: "application/json"
            },
            async () => await this.getProjectSummaryResource()
        );

        // Register tools with Zod schemas
        this.server.registerTool(
            "create_task",
            {
                title: "Create Task",
                description: "Create a new task",
                inputSchema: {
                    title: z.string().describe("Task title"),
                    description: z.string().optional().describe("Task description"),
                    project_id: z.string().optional().describe("Project ID"),
                    status: z.enum(["todo", "in-progress", "done", "blocked", "cancelled"]).default("todo"),
                    priority: z.enum(["low", "medium", "high", "urgent"]).default("medium"),
                    due_date: z.string().optional().describe("Due date (ISO format)"),
                    markdown_file: z.string().optional().describe("Path to markdown file in repo"),
                    github_repo: z.string().optional().describe("GitHub repo (owner/repo)"),
                    tags: z.array(z.string()).optional().describe("Task tags")
                }
            },
            async (args) => await this.createTask(args)
        );
        this.server.registerTool(
            "update_task",
            {
                title: "Update Task",
                description: "Update an existing task",
                inputSchema: {
                    id: z.string().describe("Task ID"),
                    title: z.string().optional(),
                    description: z.string().optional(),
                    status: z.enum(["todo", "in-progress", "done", "blocked", "cancelled"]).optional(),
                    priority: z.enum(["low", "medium", "high", "urgent"]).optional(),
                    due_date: z.string().optional().describe("Due date (ISO format)"),
                    markdown_file: z.string().optional(),
                    tags: z.array(z.string()).optional()
                }
            },
            async (args) => await this.updateTask(args)
        );
        this.server.registerTool(
            "delete_task",
            {
                title: "Delete Task",
                description: "Delete a task",
                inputSchema: {
                    id: z.string().describe("Task ID")
                }
            },
            async (args) => await this.deleteTask(args)
        );
        this.server.registerTool(
            "create_project",
            {
                title: "Create Project",
                description: "Create a new project",
                inputSchema: {
                    name: z.string().describe("Project name"),
                    description: z.string().optional().describe("Project description"),
                    status: z.enum(["active", "completed", "archived"]).default("active"),
                    markdown_file: z.string().optional().describe("Path to project markdown file"),
                    github_repo: z.string().optional().describe("GitHub repo (owner/repo)")
                }
            },
            async (args) => await this.createProject(args)
        );
        this.server.registerTool(
            "update_project",
            {
                title: "Update Project",
                description: "Update an existing project",
                inputSchema: {
                    id: z.string().describe("Project ID"),
                    name: z.string().optional(),
                    description: z.string().optional(),
                    status: z.enum(["active", "completed", "archived"]).optional(),
                    markdown_file: z.string().optional()
                }
            },
            async (args) => await this.updateProject(args)
        );
        this.server.registerTool(
            "link_tasks",
            {
                title: "Link Tasks",
                description: "Create a relationship between tasks",
                inputSchema: {
                    source_task_id: z.string().describe("Source task ID"),
                    target_task_id: z.string().describe("Target task ID"),
                    relationship_type: z.enum(["depends_on", "blocks", "subtask", "related", "duplicate"])
                }
            },
            async (args) => await this.linkTasks(args)
        );
        this.server.registerTool(
            "search_tasks",
            {
                title: "Search Tasks",
                description: "Search tasks with filters",
                inputSchema: {
                    status: z.array(z.enum(["todo", "in-progress", "done", "blocked", "cancelled"])).optional(),
                    project_id: z.string().optional(),
                    priority: z.array(z.enum(["low", "medium", "high", "urgent"])).optional(),
                    tags: z.array(z.string()).optional(),
                    due_before: z.string().optional().describe("Due before date (ISO format)"),
                    due_after: z.string().optional().describe("Due after date (ISO format)"),
                    search_text: z.string().optional().describe("Search in title/description")
                }
            },
            async (args) => await this.searchTasks(args)
        );
        this.server.registerTool(
            "add_task_comment",
            {
                title: "Add Task Comment",
                description: "Add a comment to a task",
                inputSchema: {
                    task_id: z.string().describe("Task ID"),
                    content: z.string().describe("Comment content")
                }
            },
            async (args) => await this.addTaskComment(args)
        );
    }

    // Resource methods
    private async getTasksResource() {
        const { data, error } = await supabase
            .from('tasks')
            .select('*')
            .order('created_at', { ascending: false });

        if (error) throw new Error(`Database error: ${error.message}`);

        return {
            contents: [{
                uri: "project://tasks",
                text: JSON.stringify(data, null, 2)
            }]
        };
    }

    private async getProjectsResource() {
        const { data, error } = await supabase
            .from('projects')
            .select('*')
            .order('created_at', { ascending: false });

        if (error) throw new Error(`Database error: ${error.message}`);

        return {
            contents: [{
                uri: "project://projects",
                text: JSON.stringify(data, null, 2)
            }]
        };
    }

    private async getTaskSummaryResource() {
        const { data, error } = await supabase
            .from('task_summary')
            .select('*')
            .order('created_at', { ascending: false });

        if (error) throw new Error(`Database error: ${error.message}`);

        return {
            contents: [{
                uri: "project://task-summary",
                text: JSON.stringify(data, null, 2)
            }]
        };
    }

    private async getProjectSummaryResource() {
        const { data, error } = await supabase
            .from('project_summary')
            .select('*')
            .order('created_at', { ascending: false });

        if (error) throw new Error(`Database error: ${error.message}`);

        return {
            contents: [{
                uri: "project://project-summary",
                text: JSON.stringify(data, null, 2)
            }]
        };
    }

    // Tool methods
    private async createTask(args: any) {
        const { tags, ...taskData } = args;
        
        const { data: task, error } = await supabase
            .from('tasks')
            .insert(taskData)
            .select()
            .single();

        if (error) throw new Error(`Failed to create task: ${error.message}`);

        // Handle tags if provided
        if (tags && tags.length > 0) {
            await this.addTagsToTask(task.id, tags);
        }

        return {
            content: [{
                type: "text" as const,
                text: `Created task: ${task.title} (ID: ${task.id})`
            }]
        };
    }

    private async updateTask(args: any) {
        const { id, tags, ...updates } = args;

        const { data: task, error } = await supabase
            .from('tasks')
            .update(updates)
            .eq('id', id)
            .select()
            .single();

        if (error) throw new Error(`Failed to update task: ${error.message}`);

        // Handle tags if provided
        if (tags) {
            await this.updateTaskTags(id, tags);
        }

        return {
            content: [{
                type: "text" as const,
                text: `Updated task: ${task.title}`
            }]
        };
    }

    private async deleteTask(args: any) {
        const { id } = args;

        const { error } = await supabase
            .from('tasks')
            .delete()
            .eq('id', id);

        if (error) throw new Error(`Failed to delete task: ${error.message}`);

        return {
            content: [{
                type: "text" as const,
                text: `Deleted task with ID: ${id}`
            }]
        };
    }

    private async createProject(args: any) {
        const { data: project, error } = await supabase
            .from('projects')
            .insert(args)
            .select()
            .single();

        if (error) throw new Error(`Failed to create project: ${error.message}`);

        return {
            content: [{
                type: "text" as const,
                text: `Created project: ${project.name} (ID: ${project.id})`
            }]
        };
    }

    private async updateProject(args: any) {
        const { id, ...updates } = args;

        const { data: project, error } = await supabase
            .from('projects')
            .update(updates)
            .eq('id', id)
            .select()
            .single();

        if (error) throw new Error(`Failed to update project: ${error.message}`);

        return {
            content: [{
                type: "text" as const,
                text: `Updated project: ${project.name}`
            }]
        };
    }

    private async linkTasks(args: any) {
        const { source_task_id, target_task_id, relationship_type } = args;

        const { error } = await supabase
            .from('task_relationships')
            .insert({
                source_task_id,
                target_task_id,
                relationship_type
            });

        if (error) throw new Error(`Failed to link tasks: ${error.message}`);

        return {
            content: [{
                type: "text" as const,
                text: `Created ${relationship_type} relationship between tasks`
            }]
        };
    }

    private async searchTasks(args: any) {
        let query = supabase.from('task_summary').select('*');

        if (args.status && args.status.length > 0) {
            query = query.in('status', args.status);
        }

        if (args.project_id) {
            query = query.eq('project_id', args.project_id);
        }

        if (args.priority && args.priority.length > 0) {
            query = query.in('priority', args.priority);
        }

        if (args.due_before) {
            query = query.lte('due_date', args.due_before);
        }

        if (args.due_after) {
            query = query.gte('due_date', args.due_after);
        }

        if (args.search_text) {
            query = query.or(`title.ilike.%${args.search_text}%,description.ilike.%${args.search_text}%`);
        }

        const { data, error } = await query.order('created_at', { ascending: false });

        if (error) throw new Error(`Search failed: ${error.message}`);

        return {
            content: [{
                type: "text" as const,
                text: `Found ${data.length} tasks:\n` + JSON.stringify(data, null, 2)
            }]
        };
    }

    private async addTaskComment(args: any) {
        const { task_id, content } = args;

        const { error } = await supabase
            .from('task_comments')
            .insert({ task_id, content })
            .select()
            .single();

        if (error) throw new Error(`Failed to add comment: ${error.message}`);

        return {
            content: [{
                type: "text" as const,
                text: `Added comment to task ${task_id}`
            }]
        };
    }

    // Helper methods
    private async addTagsToTask(taskId: string, tagNames: string[]) {
        for (const tagName of tagNames) {
            // Get or create tag
            let { data: tag } = await supabase
                .from('tags')
                .select('id')
                .eq('name', tagName)
                .single();

            if (!tag) {
                const { data: newTag } = await supabase
                    .from('tags')
                    .insert({ name: tagName })
                    .select()
                    .single();
                tag = newTag!;
            }

            // Link tag to task
            await supabase
                .from('task_tags')
                .insert({ task_id: taskId, tag_id: tag.id });
        }
    }

    private async updateTaskTags(taskId: string, tagNames: string[]) {
        // Remove existing tags
        await supabase
            .from('task_tags')
            .delete()
            .eq('task_id', taskId);

        // Add new tags
        if (tagNames.length > 0) {
            await this.addTagsToTask(taskId, tagNames);
        }
    }

    async run() {
        const transport = new StdioServerTransport();
        await this.server.connect(transport);
    }
}

// Start the server
if (process.argv[1] === new URL(import.meta.url).pathname) {
    const server = new ProjectMCPServer();
    server.run().catch(console.error);
}

export { ProjectMCPServer };