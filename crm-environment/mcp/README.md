# Twenty CRM MCP Server - Quick Reference

## Connection

```
URL: http://x1000c0s4b0n0:3000/mcp?mode=direct
Auth: Bearer <token> (from .crm_environment_env)
Protocol: MCP v1.0 (protocolVersion 2025-06-18)
```

## Authentication

```bash
export MCP_TOKEN="eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6ImViNWUyMDUxLWFlYmYtNDU0NC04ODQyLTMxOWI0NzczZTdlMCJ9.eyJzdWIiOiJjYzNlODFmOC05YmQzLTQ0Y2QtYmMzOS01YTQ0ZTg3Y2ZkNTgiLCJ0eXBlIjoiQVBJX0tFWSIsIndvcmtzcGFjZUlkIjoiY2MzZTgxZjgtOWJkMy00NGNkLWJjMzktNWE0NGU4N2NmZDU4IiwiaWF0IjoxNzkyNjc3OTIyLCJleHAiOjQ5NDYyNzc5MjEsImp0aSI6IjE3NWZmZDk2LTVjYjctNDNhYy05MmNlLTAzNmQ2Yzk1ZTE5OCJ9.JAYa5Hd6YtIRqN5ziCnyIXNsS4dbMP2Fi3M_f8lsLJl4sEocmyhJ-h0XDmX9dN9scZ37tBE1xzHNlVoHwBeKFg"
```

## Top-Level Tools (8)

1. `get_tool_catalog` - Browse tools by category
2. `execute_tool` - Execute any tool dynamically
3. `learn_tools` - Get schemas for tool names
4. `load_skills` - Load step-by-step instructions
5. `list_skills` - List available skill names
6. `list_object_metadata_names` - List available objects
7. `search_help_center` - Search Twenty docs
8. (Direct tools) - e.g., `create_one_person`

## Tool Categories (280+ tools)

- **DATABASE_CRUD** (195 tools) - CRUD operations
- **METADATA** - Object/field metadata
- **WORKFLOW** - Workflow management
- **DASHBOARD** - Dashboard creation
- **VIEW** - View management
- **ACTION** - HTTP requests, email
- **NAVIGATION_MENU_ITEM** - Navigation
- **ROLE** - Roles and permissions
- **WEBHOOK** - Webhook management

## Available Objects (24)

people, companies, opportunities, tasks, notes, messages, message_threads, message_campaigns, message_lists, message_participants, calendar_events, calendar_event_participants, call_recordings, dashboards, views, webhooks, roles, navigation_menu_items, attachments, blocklists, workspace_members, timeline_activities, message_channel_message_associations, message_channel_message_association_message_folders, message_list_members, task_targets, note_targets

## Example: Create Person

```bash
curl -X POST "http://x1000c0s4b0n0:3000/mcp?mode=direct" \
  -H "Authorization: Bearer $MCP_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "execute_tool",
      "arguments": {
        "toolName": "create_one_person",
        "arguments": {
          "name": {"firstName": "John", "lastName": "Doe"},
          "emails": {"primaryEmail": "john@example.com"},
          "position": "last"
        }
      }
    },
    "id": 1
  }'
```

## Example: Find People

```bash
curl -X POST "http://x1000c0s4b0n0:3000/mcp?mode=direct" \
  -H "Authorization: Bearer $MCP_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "find_many_people",
      "arguments": {
        "name": {"firstName": {"ilike": "%john%"}},
        "limit": 10,
        "offset": 0,
        "select": ["id", "name", "emails", "jobTitle"]
      }
    },
    "id": 2
  }'
```

## Key Rules

1. Always use `?mode=direct` query parameter
2. Person creation requires `position` field (first/last/number)
3. Batch operations: max 20 records per call
4. Soft deletes (reversible)
5. Filters: top-level args (NOT nested in "filter" object)
6. Learn tools before first use: `learn_tools`
7. Load skills for complex ops: `load_skills`
8. Destructive ops: run `find_many` first, confirm

## Response Format

```json
{
  "id": 1,
  "jsonrpc": "2.0",
  "result": {
    "content": [{
      "type": "text",
      "text": "{\"success\":true,\"message\":\"...\",\"result\":{\"id\":\"...\"},\"recordReferences\":[...]}"
    }],
    "isError": false
  }
}
```

## Field Mapping

| tau-bench | Twenty CRM |
|-----------|------------|
| first_name | name.firstName |
| last_name | name.lastName |
| email | emails.primaryEmail |
| phone | phones.primaryPhoneNumber |
| title | jobTitle |
| company_id | companyId (UUID) |

## Files

- **FINDINGS.md** - Comprehensive server documentation
- **MCP_ARCHITECTURE.md** - Architecture and usage patterns
- **ASSESSMENT.md** - CRM domain integration assessment
- **SESSION_LOG.md** - Session log and test results
- **tool_catalog_*.json** - Raw catalog responses
- **skills_list.json** - Skills list
- **object_metadata.json** - Object metadata
