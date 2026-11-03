# CRM Domain Assessment and MCP Integration Plan

## Current State

The CRM domain in `tau2-bench-backup` has a **local simulation implementation** that does NOT actually interact with Twenty CRM.

### What Exists

- **Local DB**: `TwentyCRMDB` with `CRMUser`, `CRMOrganization`, `CRMDeal`, `CRMNote` models
- **Local Tools**: 20+ tools that operate on local database only
- **MCP Code**: Partial implementation in `_call_mcp_tool()` that is never actually used
- **Tasks**: 10 tasks defined (including stubborn user task #8)

### Why It Won't Work

1. **Wrong Tool Implementation** - All tools use `self.db.users[user_id] = user` instead of MCP calls
2. **Schema Mismatch** - Local models use `first_name/last_name`, Twenty CRM uses `firstName/lastName`
3. **MCP Protocol Not Used** - `_call_mcp_tool()` exists but tools don't call it
4. **Wrong MCP Endpoint** - `.env` points to different server (`x1000c4s2b0n0` instead of `x1000c0s4b0n0`)

## Required Changes

### 1. Tools Layer (tools.py)
- Rewrite all tools to call Twenty CRM MCP via `execute_tool`
- Use correct tool names: `people.create_one`, `people.find_many`, `companies.create_one`, etc.
- Handle MCP response format: nested JSON in `result.content[].text`
- Map field names: `first_name` → `firstName`, `primaryEmail`, etc.

### 2. Data Models (data_model.py)
- Update to match Twenty CRM schema
- `Name`: `{firstName: str, lastName: str}`
- `CRMUser`: `emails: {primaryEmail: str, additionalEmails: [str]}`
- `Address`: Keep same structure but match Twenty CRM format

### 3. Authentication (.env)
- Update `CRM_MCP_URL` to `http://x1000c0s4b0n0:3000/mcp?mode=direct`
- Update token from `.crm_environment_env` file

### 4. Registry Registration
- Add domain to `src/tau2/registry.py`

## MCP Tool Mapping

| Local Tool | Twenty CRM MCP Tool | Notes |
|------------|---------------------|-------|
| `search_users` | `people.find_many` | Filter by name, email, company |
| `get_user_details` | `people.find_one` | By ID |
| `create_user` | `create_one_person` | Requires `position`, `emails` |
| `update_user_info` | `upsert_many_people` | Upsert with specific ID |
| `delete_user` | `delete_one_person` | Soft delete |
| `search_organizations` | `companies.find_many` | Filter by name, industry |
| `get_organization_details` | `companies.find_one` | By ID |
| `create_organization` | `create_one_company` | |
| `list_deals` | `opportunities.find_many` | Filter by org, stage |
| `get_deal_details` | `opportunities.find_one` | By ID |
| `create_deal` | `create_one_opportunity` | |
| `update_deal_stage` | `upsert_many_opportunities` | Upsert with stage update |
| `update_deal_value` | `upsert_many_opportunities` | Upsert with value update |
| `get_user_deals` | `opportunities.find_many` | Filter by contact_id |
| `get_organization_deals` | `opportunities.find_many` | Filter by organization_id |
| `add_note` | `create_one_note` | Or similar |
| `get_user_notes` | `notes.find_many` | Filter by user_id |

## Field Name Mapping

| Local | Twenty CRM |
|-------|------------|
| `first_name` | `name.firstName` |
| `last_name` | `name.lastName` |
| `email` | `emails.primaryEmail` |
| `phone` | `phones.primaryPhoneNumber` |
| `company` | (linked via organization) |
| `title` | `jobTitle` |
| `lead_score` | (custom field or ignored) |
| `status` | (custom field or ignored) |
| `org_id` | `id` |
| `deal_id` | `id` |
| `note_id` | `id` |

## Next Steps

1. Copy domain to `tau2-bench-copy`
2. Update `tools.py` to use MCP
3. Update `data_model.py` for Twenty CRM schema
4. Update `.env` with correct credentials
5. Register domain in `registry.py`
6. Test with a simple task
7. Verify interaction with Twenty CRM UI

## Tasks for User

1. Review task list (10 tasks total)
2. Confirm stubborn user task (#8) requirements
3. Verify Twenty CRM schema matches expectations
4. Test MCP connection with sample user creation
