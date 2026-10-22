# Twenty CRM MCP Server — Findings (Updated)

## Connection
- **Host**: `http://x1000c0s4b0n0:3000/mcp` (from `.crm_environment_env` file)
- **Auth**: Bearer token from `/workspace/crm-environment/.crm_environment_env`
- **Protocol**: MCP (protocolVersion `2025-06-18`)
- **Server**: "Twenty MCP Server" v0.1.0

## Connection String Format
```
http://x1000c0s4b0n0:3000/mcp?mode=direct
```

## Top-level MCP tools (8)
| Tool | Purpose |
|---|---|
| `search_help_center` | Search Twenty docs/help center |
| `get_tool_catalog` | Browse tools by category |
| `execute_tool` | Run any tool by name with args (`{toolName, arguments}`) |
| `load_skills` | Load step-by-step skill instructions by name |
| `list_object_metadata_names` | List available object metadata names |
| `list_skills` | List available skill names |
| `learn_tools` | Get input schemas for tool names (pass array of names) |
| (direct tools) | Direct tool names like `people.create_one` |

## Tool Execution Pattern

### Two-Level Execution (Recommended)
1. **`execute_tool`** - Meta-tool that dynamically calls other tools
2. **Actual tool** - e.g., `create_one_person`, `find_many_companies`

### Direct Tool Execution
Some tools can be called directly by name in `tools/call`:
- `people.create_one`
- `companies.find_many`
- `opportunities.update_one`

## Tool Counts
- **280+ tools** across 9+ categories (from live `get_tool_catalog` call)

## Categories (from get_tool_catalog)

### DATABASE_CRUD (195 tools)
Per-object CRUD operations for 24+ objects:
- **Read**: `find_many_{object}`, `find_one_{object}`, `group_by_{objects}`
- **Write**: `create_one_{object}`, `create_many_{objects}`, `update_one_{object}`, `update_many_{objects}`, `upsert_many_{objects}`, `delete_one_{object}`, `delete_many_{objects}`

Available objects:
- people, companies, opportunities, tasks, notes
- messages, message_threads, message_campaigns, message_lists, message_participants
- calendar_events, calendar_event_participants, call_recordings
- dashboards, views, webhooks, roles, navigation_menu_items
- attachments, blocklists, workspace_members, timeline_activities
- message_channel_message_associations, message_channel_message_association_message_folders
- message_list_members, task_targets, note_targets

### METADATA
- `get_object_metadata` - List object metadata with fields
- `create_object_metadata` - Create new objects in data model
- `update_object_metadata` - Update object definitions
- `delete_object_metadata` - Delete objects
- `get_field_metadata` - List field definitions
- `create_field_metadata`, `update_field_metadata`, `delete_field_metadata`

### WORKFLOW
- `create_complete_workflow` - Create workflows with steps and edges
- `validate_workflow` - Validate workflow syntax
- Logic functions, agents

### DASHBOARD
- `create_complete_dashboard` - Create dashboards with widgets
- Widgets: AGGREGATE, BAR, LINE, PIE, IFRAME, STANDALONE_RICH_TEXT, RECORD_TABLE
- Tabs management

### VIEW
- `upsert_complete_view` - Declarative view replacement
- View fields, filters, sorts

### ACTION
- `http_request` - External API calls (NOT Twenty's own data)
- `send_email`, `draft_email`, `navigate_app`, `code_interpreter`

### NAVIGATION_MENU_ITEM
- List/create/update/delete navigation menu items

### ROLE
- List/create/update/delete roles
- Assign roles, upsert permissions, row-level rules

### WEBHOOK
- List/create/update/delete webhooks

## Key Patterns & Rules

### 1. Tool Naming
- CRUD tools follow pattern: `{action}_{object}_{count}`
- Examples: `create_one_person`, `find_many_companies`, `update_many_tasks`
- NOT `people.create_one` (though some direct tools may support this)

### 2. Execution Flow
1. Call `get_tool_catalog` or `learn_tools` to discover tools
2. For complex operations, call `load_skills` first
3. Execute via `execute_tool` with `toolName` and `arguments`

### 3. Batch Operations
- Max **20 records** per `create_many_*` / `upsert_many_*` call
- Use pagination via `limit`/`offset` for large datasets

### 4. Learning Tools
- Call `learn_tools` before `execute_tool` to get schemas
- Pass array of tool names in one call
- Request `description` and `schema` aspects

### 5. Skills
Available skills:
- code-interpreter
- custom-objects-cleanup
- dashboard-building
- data-manipulation
- xlsx
- metadata-building
- pdf
- pptx
- research
- roles
- view-building
- view-filters-and-sorts
- docx
- workflow-building
- workspace-demo-seeding

### 6. Filter Syntax
- Filter fields are **top-level args** (NOT wrapped in "filter" object)
- Combine with `and`/`or`/`not`
- Pagination: `limit`, `offset`
- Sorting: `orderBy`

Example:
```json
{
  "name": {
    "firstName": {
      "ilike": "%john%"
    }
  },
  "limit": 10,
  "offset": 0,
  "orderBy": [{"name": {"firstName": "AscNullsFirst"}}]
}
```

### 7. Aggregate Operations
- `group_by_{objects}` supports: COUNT, SUM, AVG, MIN, MAX
- Group by one or two fields

### 8. Soft Deletes
- `delete_one`/`delete_many` mark records with `deletedAt` (reversible)
- Not hard-deleted

### 9. Destructive Operations
- Always run `find_many` with same filter first
- Report count to user
- Execute only after confirmation

### 10. Special Rules
- `http_request` is ONLY for external third-party APIs, NEVER Twenty's own data
- Person records require `position` field (mandatory)
- Use `first`/`last` or number for position ordering

## Response Format

### Success Response
```json
{
  "id": 1,
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

### Error Response
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

## Key Relations
- `person.companyId` → `company`
- `note / task / timeline_activity` attachable to any object via `targetRecordId`
- `opportunity.contactId` → `person`
- `opportunity.companyId` → `company`

## Testing
Successfully tested:
- ✅ `get_tool_catalog` - Returns 280+ tools across 9+ categories
- ✅ `list_skills` - Returns 15 skills
- ✅ `list_object_metadata_names` - Returns 24 objects
- ✅ `learn_tools` - Returns schemas for tool names
- ✅ `execute_tool` with `create_one_person` - Creates person record
- ✅ `create_one_person` - Direct tool creation

## Available Objects (24 total)
```
attachments, blocklists, calendar_channel_event_associations,
calendar_event_participants, calendar_events, call_recordings,
companies, dashboards, message_campaigns,
message_channel_message_association_message_folders,
message_channel_message_associations, message_list_members,
message_lists, message_participants, message_threads, messages,
note_targets, notes, opportunities, people, task_targets, tasks,
timeline_activities, workspace_members
```

## Field Name Mapping (vs Local Models)

| Local Model | Twenty CRM MCP |
|-------------|----------------|
| `first_name` | `name.firstName` |
| `last_name` | `name.lastName` |
| `email` | `emails.primaryEmail` |
| `phone` | `phones.primaryPhoneNumber` |
| `title` | `jobTitle` |
| `company_id` | `companyId` (string UUID) |
| `deal_stage` | `stageName` |
| `deal_value` | `value` |
| `note_content` | `content` |

## Notes for tau-bench Integration

1. **Use `execute_tool` wrapper** - Always call `execute_tool` with `toolName` and `arguments`
2. **Load tools first** - Call `learn_tools` to get schemas before using a tool
3. **Handle nested JSON responses** - Response text is JSON string inside `result.content[].text`
4. **Position required** - Person creation requires `position` field
5. **Batch limits** - Max 20 records per batch operation
6. **Soft deletes** - Deletions are reversible
7. **Filter syntax** - Top-level args, not nested "filter" object

## Raw Data
- Full `get_tool_catalog` JSON saved at: `/workspace/crm-environment/mcp/tool_catalog_database_crud.json`
- Skills list: `/workspace/crm-environment/mcp/skills_list.json`
- Object metadata: `/workspace/crm-environment/mcp/object_metadata.json`
- Tool schemas: `/workspace/crm-environment/mcp/learn_tools_test.json`
