# Twenty CRM MCP Server — Findings

## Connection
- Host: `http://x1000c0s0b1n0:3000/mcp` (10.150.0.57)
- Auth: Bearer key from `/workspace/crm-environment/.env`
- Protocol: MCP (initialize returns protocolVersion `2025-06-18`)
- Server: "Twenty MCP Server" v0.1.0

## Top-level MCP tools (7)
| Tool | Purpose |
|---|---|
| `search_help_center` | Search Twenty docs/help center |
| `get_tool_catalog` | Browse tools by category (DATABASE_CRUD, ACTION, WORKFLOW, METADATA, VIEW, DASHBOARD, NAVIGATION_MENU_ITEM, WEBHOOK, LOGIC_FUNCTION, ROLE) |
| `execute_tool` | Run any tool by name with args (`{toolName, arguments}`) |
| `load_skills` | Load step-by-step skill instructions by name |
| `list_object_metadata_names` | List object metadata names |
| `list_skills` | List available skills |
| `learn_tools` | Get input schemas for tool names (pass array of names in one call) |

## Tool counts
- **280 tools** across 9 categories (from live `get_tool_catalog` call)

## Categories
- **DATABASE_CRUD** — per-object CRUD. For each object (people, companies, opportunities, notes, tasks, messages, etc.):
  - Read: `find_many_{objects}`, `find_one_{object}`, `group_by_{objects}`
  - Write: `create_one_{object}`, `create_many_{objects}`, `update_one_{object}`, `update_many_{objects}`, `upsert_many_{objects}`, `delete_one_{object}`, `delete_many_{objects}`
- **METADATA** — object/field metadata: get/create/update/delete for objects and fields, plus relation fields
- **NAVIGATION_MENU_ITEM** — list/create/update/delete navigation menu items (folders, links, favorites)
- **ROLE** — list/create/update/delete roles, assign roles, upsert object permissions, row-level permission rules
- **VIEW** — views, view fields/filters/sorts, `upsert_complete_view` (declarative replace semantics)
- **WEBHOOK** — list/create/update/delete webhooks
- **WORKFLOW** — `create_complete_workflow`, step/edge management, logic functions, agents, validate_workflow
- **DASHBOARD** — `create_complete_dashboard`, widgets (AGGREGATE/BAR/LINE/PIE chart, IFRAME, STANDALONE_RICH_TEXT, RECORD_TABLE), tabs
- **ACTION** — `http_request`, `send_email`, `draft_email`, `navigate_app`, `code_interpreter`, `search_help_center`

## Key patterns / rules (from initialize + catalog)
- CRUD tool names are constructed, not discovered: `find_many_companies`, `create_one_person`, etc.
- Batch operations: max 20 records per `create_many_*` / `upsert_many_*` call
- `learn_tools` must be called before `execute_tool` (pass all needed tool names in one array)
- `load_skills` must be called before complex ops (workflows, metadata, dashboards)
- Skills available: code-interpreter, custom-objects-cleanup, dashboard-building, data-manipulation, xlsx, metadata-building, pdf, pptx, research, roles, view-building, view-filters-and-sorts, docx, workflow-building, workspace-demo-seeding
- Filters: top-level args (NOT wrapped in a "filter" object). Combine with and/or/not. Pagination via limit/offset, sorting via orderBy
- `group_by_{objects}` supports COUNT, SUM, AVG, MIN, MAX
- `delete_one/many` are soft-deletes (reversible)
- `http_request` is ONLY for external third-party APIs, never Twenty's own data
- Destructive ops: run `find_many_{objects}` with same filter first, report count, then execute after confirmation

## Available objects (from initialize)
attachments, blocklists, calendar_channel_event_associations, calendar_event_participants, calendar_events, call_recordings, companies, dashboards, message_campaigns, message_channel_message_association_message_folders, message_channel_message_associations, message_list_members, message_lists, message_participants, message_threads, messages, note_targets, notes, opportunities, people, task_targets, tasks, timeline_activities, workspace_members

## Key relations
- person.companyId → company
- note / task / activity attachable to any object via targetRecordId

## Raw catalog dump
- Full `get_tool_catalog` JSON response saved at `/tmp/catalog.json` (103 KB)
