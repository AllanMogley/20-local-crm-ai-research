# MCP Server Architecture and Structure

## Overview

The Twenty CRM MCP server provides a JSON-RPC 2.0 interface for interacting with CRM data and tools.

## Connection Details

- **URL**: `http://x1000c0s4b0n0:3000/mcp?mode=direct`
- **Authentication**: Bearer token (from `/workspace/crm-environment/.crm_environment_env` file)
- **Query Parameter**: Use `?mode=direct` for full tool execution
- **Protocol Version**: 2025-06-18
- **Server**: "Twenty MCP Server" v0.1.0

## JSON-RPC Method: `tools/call`

The only top-level JSON-RPC method is `tools/call`. All tool execution happens through this single entry point.

## Two-Level Tool Execution Pattern

The MCP server uses a **two-level** approach:

1. **`tools/call`** - Main JSON-RPC method (entry point)
2. **`execute_tool`** - Meta-tool that executes other tools

### Why This Pattern?

The `execute_tool` wrapper provides:
- Consistent interface for all tool execution
- Tool name resolution
- Argument validation and routing
- Error handling

## Available Tools

### Built-in MCP Tools (via `execute_tool`):

1. **`get_tool_catalog`** - Browse tools by category
   - Arguments: `categories` (array: "DATABASE_CRUD", "ACTION", "WORKFLOW", "METADATA", etc.)
   - Use: Get tools grouped by category (280+ tools across 9+ categories)

2. **`execute_tool`** - Execute any tool by name
   - Arguments: `toolName` (string), `arguments` (object)
   - Use: Main execution tool for all other tools
   - Example: `{"toolName": "create_one_person", "arguments": {...}}`

3. **`learn_tools`** - Get input schemas for tools
   - Arguments: `toolNames` (array), `aspects` (array: "description", "schema")
   - Use: Discover available tools and their schemas before execution
   - Must be called before using a tool for the first time

4. **`list_skills`** - List available skills
   - Arguments: none
   - Use: Get available skill names (15 skills available)

5. **`load_skills`** - Load specialized skills
   - Arguments: `skillNames` (array)
   - Use: Get step-by-step instructions for complex operations (workflows, metadata, dashboards)
   - Must be called before complex operations

6. **`list_object_metadata_names`** - List available object metadata
   - Arguments: none
   - Use: Get fresh list of available objects (24 objects)

7. **`search_help_center`** - Search Twenty documentation
   - Arguments: `query` (string)
   - Use: Find help articles

### CRM Data Tools (DATABASE_CRUD category - 195 tools):

For **Person** records:
- `create_one_person` - Create a person (requires `position` field)
- `find_many_people` - Search people with filters
- `find_one_person` - Get person by ID
- `update_one_person` - Update a person
- `delete_one_person` - Delete a person (soft delete)
- `upsert_many_people` - Upsert multiple people (max 20)

For **Company** records:
- `create_one_company` - Create a company
- `find_many_companies` - Search companies
- `find_one_company` - Get company by ID
- `delete_one_company` - Delete a company

For **Opportunity** records:
- `create_one_opportunity` - Create an opportunity
- `find_many_opportunities` - Search opportunities
- `delete_one_opportunity` - Delete an opportunity

For **Task** records:
- `create_one_task` - Create a task
- `find_many_tasks` - Search tasks
- `delete_one_task` - Delete a task

For **Note** records:
- `create_one_note` - Create a note
- `find_many_notes` - Search notes
- `delete_one_note` - Delete a note

And many more (24+ objects total).

## Example Usage

### 1. Get Tool Catalog (Discover Available Tools)

```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "get_tool_catalog",
    "arguments": {
      "categories": ["DATABASE_CRUD"]
    }
  },
  "id": 1
}
```

### 2. Learn Tool Schema (Before First Use)

```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "learn_tools",
    "arguments": {
      "toolNames": ["create_one_person", "create_one_company"],
      "aspects": ["description", "schema"]
    }
  },
  "id": 2
}
```

### 3. Execute Tool (Two-Level Pattern)

```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "execute_tool",
    "arguments": {
      "toolName": "create_one_person",
      "arguments": {
        "name": {
          "firstName": "John",
          "lastName": "Doe"
        },
        "emails": {
          "primaryEmail": "john.doe@example.com",
          "additionalEmails": ["john2@example.com"]
        },
        "phones": {
          "primaryPhoneNumber": "+1234567890"
        },
        "jobTitle": "Software Engineer",
        "companyId": "uuid-here",
        "position": "last"
      }
    }
  },
  "id": 3
}
```

### 4. Direct Tool Call (Alternative Pattern)

```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "create_one_person",
    "arguments": {
      "name": {
        "firstName": "Jane",
        "lastName": "Smith"
      },
      "emails": {
        "primaryEmail": "jane.smith@example.com"
      },
      "position": "last"
    }
  },
  "id": 4
}
```

### 5. Find People with Filters

```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "find_many_people",
    "arguments": {
      "name": {
        "firstName": {
          "ilike": "%john%"
        }
      },
      "limit": 10,
      "offset": 0,
      "select": ["id", "name", "emails", "jobTitle"]
    }
  },
  "id": 5
}
```

## Response Format

Success response:
```json
{
  "id": 2,
  "jsonrpc": "2.0",
  "result": {
    "content": [{
      "type": "text",
      "text": "{\"success\":true,\"message\":\"Record created successfully\",\"result\":{\"id\":\"uuid\"},\"recordReferences\":[...]}"
    }],
    "isError": false
  }
}
```

Error response:
```json
{
  "id": 1,
  "jsonrpc": "2.0",
  "result": {
    "content": [{
      "type": "text",
      "text": "{\"success\":false,\"message\":\"Error message\",\"error\":\"Detailed error\"}"
    }],
    "isError": true
  }
}
```

## Key Points

1. **Always use `?mode=direct`** query parameter for full tool execution
2. **All tool calls go through `tools/call`** with `name` parameter
3. **Two execution patterns**:
   - Two-level: `execute_tool` → actual tool (recommended)
   - Direct: Call tool name directly (e.g., `create_one_person`)
4. **Learn tools first**: Call `learn_tools` before using a tool for the first time
5. **Load skills for complex ops**: Call `load_skills` before workflows, metadata, dashboards
6. **Person records require `position`**: Use "first", "last", or a number
7. **Batch limits**: Max 20 records per `create_many_*` / `upsert_many_*`
8. **Soft deletes**: Records marked with `deletedAt`, reversible
9. **Filter syntax**: Top-level args (NOT nested in "filter" object)
10. **Destructive ops**: Run `find_many` first, report count, confirm
