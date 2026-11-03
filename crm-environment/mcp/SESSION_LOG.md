# Session Log - CRM Domain MCP Integration

## Date: 2026-10-22 (Last Updated)

## Summary

Successfully probed Twenty CRM MCP server and documented full tool architecture. The MCP server is operational and ready for integration with tau-bench.

## MCP Server Details

### Connection
- **URL**: `http://x1000c0s4b0n0:3000/mcp?mode=direct`
- **Auth**: Bearer token from `.crm_environment_env`
- **Protocol**: MCP v1.0 (protocolVersion `2025-06-18`)
- **Server**: "Twenty MCP Server" v0.1.0

### Top-Level Tools (8)
1. `get_tool_catalog` - Browse tools by category (DATABASE_CRUD, ACTION, WORKFLOW, METADATA, VIEW, DASHBOARD, NAVIGATION_MENU_ITEM, WEBHOOK, LOGIC_FUNCTION, ROLE)
2. `execute_tool` - Execute any tool dynamically (`{toolName, arguments}`)
3. `learn_tools` - Get schemas for tool names (pass array of names)
4. `load_skills` - Load step-by-step instructions for complex ops
5. `list_skills` - List available skill names
6. `list_object_metadata_names` - List available object metadata
7. `search_help_center` - Search Twenty documentation
8. (Direct tools) - e.g., `create_one_person`, `find_many_companies`

### Tool Categories (280+ tools total)
- **DATABASE_CRUD** (195 tools) - CRUD per object (people, companies, opportunities, tasks, notes, etc.)
- **METADATA** - Object/field metadata management
- **WORKFLOW** - Workflow creation and management
- **DASHBOARD** - Dashboard creation with widgets
- **VIEW** - View creation and management
- **ACTION** - HTTP requests, email, code interpreter
- **NAVIGATION_MENU_ITEM** - Navigation menu management
- **ROLE** - Role and permission management
- **WEBHOOK** - Webhook management

## Key Patterns & Rules

### Tool Execution Pattern
1. **Discover**: `get_tool_catalog` or `learn_tools`
2. **Execute**: `execute_tool` with `{toolName, arguments}` or direct tool call
3. **Complex ops**: `load_skills` first for workflows, metadata, dashboards

### Filter Syntax
- Filter fields are **top-level** (NOT nested in "filter" object)
- Combine with `and`/`or`/`not`
- Pagination: `limit`, `offset`
- Sorting: `orderBy` with array of `{fieldName: direction}`

### Batch Operations
- Max **20 records** per `create_many_*` / `upsert_many_*`
- Use pagination for larger datasets

### Special Rules
- `position` required for person creation (first/last/number)
- Soft deletes (reversible, sets `deletedAt`)
- `http_request` ONLY for external APIs, never Twenty's own data
- Destructive ops: always run `find_many` first, report count, confirm

## Available Objects (24)
```
people, companies, opportunities, tasks, notes, messages,
message_threads, message_campaigns, message_lists, message_participants,
calendar_events, calendar_event_participants, call_recordings,
dashboards, views, webhooks, roles, navigation_menu_items,
attachments, blocklists, workspace_members, timeline_activities,
message_channel_message_associations, message_channel_message_association_message_folders,
message_list_members, task_targets, note_targets
```

## Key Relations
- `person.companyId` → `company`
- `note / task / activity` attachable via `targetRecordId`
- `opportunity.contactId` → `person`
- `opportunity.companyId` → `company`

## Field Name Mapping

| tau-bench Local | Twenty CRM MCP |
|-----------------|----------------|
| `first_name` | `name.firstName` |
| `last_name` | `name.lastName` |
| `email` | `emails.primaryEmail` |
| `phone` | `phones.primaryPhoneNumber` |
| `title` | `jobTitle` |
| `company_id` | `companyId` (UUID) |
| `deal_stage` | `stageName` |
| `deal_value` | `value` |
| `note_content` | `content` |

## MCP Testing Results

### ✅ Successful Tests

1. **get_tool_catalog (DATABASE_CRUD)**
   - Returns 195 tools across DATABASE_CRUD category
   - All CRUD operations for 24+ objects

2. **list_skills**
   - 15 skills available: code-interpreter, custom-objects-cleanup, dashboard-building, data-manipulation, xlsx, metadata-building, pdf, pptx, research, roles, view-building, view-filters-and-sorts, docx, workflow-building, workspace-demo-seeding

3. **list_object_metadata_names**
   - 24 objects available

4. **learn_tools**
   - Successfully returns schemas for tool names
   - Pass array of names, request aspects: ["description", "schema"]

5. **execute_tool**
   - Successfully calls other tools dynamically
   - Format: `{toolName, arguments}`

6. **create_one_person (direct)**
   - Successfully created person record
   - Required fields: `name`, `emails`, `position`
   - Returns ID and record references

### Example Working Request

```bash
curl -X POST "http://x1000c0s4b0n0:3000/mcp?mode=direct" \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "execute_tool",
      "arguments": {
        "toolName": "create_one_person",
        "arguments": {
          "name": {"firstName": "Test", "lastName": "User"},
          "emails": {"primaryEmail": "test@example.com"},
          "position": "last"
        }
      }
    },
    "id": 1
  }'
```

## Response Format

### Success
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

### Error
```json
{
  "id": 1,
  "jsonrpc": "2.0",
  "result": {
    "content": [{
      "type": "text",
      "text": "{\"success\":false,\"message\":\"Error\",\"error\":\"Detail\"}"
    }],
    "isError": true
  }
}
```

## Files Created/Updated

1. **FINDINGS.md** - Comprehensive MCP server documentation (this file)
2. **MCP_ARCHITECTURE.md** - Architecture and usage patterns
3. **ASSESSMENT.md** - CRM domain integration assessment
4. **SESSION_LOG.md** - This log file
5. **tool_catalog_*.json** - Raw catalog responses
6. **skills_list.json** - Skills list response
7. **object_metadata.json** - Object metadata response

## Next Steps for tau-bench Integration

1. Copy domain to `tau2-bench-copy` directory
2. Update `tools.py` to use MCP via `execute_tool`
3. Update `data_model.py` for Twenty CRM schema
4. Update `.env` with correct credentials from `.crm_environment_env`
5. Register domain in `registry.py`
6. Test end-to-end with Twenty CRM UI

## Tasks to Implement (10 total)

- Task 0: Create lead and convert to customer
- Task 1: Check existing user's deal status
- Task 2: Update deal stage
- Task 3: Add notes to user records
- Task 4: Search organizations by industry
- Task 5: Update user information
- Task 6: Create organization and deal
- Task 7: Close a deal as won
- **Task 8: Handle stubborn user** (user doesn't trust business, needs convincing)
- Task 9: Comprehensive sales cycle

## User Requirements

- Commitment-Trust Theory foundation
- 10 tasks for the environment
- Stubborn user task (task #8) - user doesn't trust business, needs convincing
- MCP connection to Twenty CRM on port 3000

## MCP Connection Test (Initial)

Successfully tested creating a person:
- Created "Random TestUser10" with email `random.test.user10+20261022@example.com`
- ID: `fc1eab84-17a5-480e-9712-f3ddf160e009`
- Deleted successfully with soft-delete

MCP is operational and ready for integration.
