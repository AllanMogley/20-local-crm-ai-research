# CRM Domain Assessment - tau2-bench-backup

## Executive Summary

**The CRM domain in tau2-bench-backup will NOT work with the Twenty CRM MCP server as-is.**

## Critical Issues

### 1. **Tools Don't Call MCP Server** ❌
The `CRMTools` class has a `_call_mcp_tool()` method that is **never called** by any tool.

**Current behavior:**
- All tools (create_user, search_users, create_deal, etc.) operate on **local in-memory database only**
- Data is stored in `self.db.users[user_id] = user` format
- MCP connection exists but is completely unused

**Evidence from tools.py:**
```python
# Line 208-221: create_user does NOT call MCP
def create_user(self, first_name: str, ...) -> CRMUser:
    user_id = self._get_new_user_id()
    user = CRMUser(
        user_id=user_id,
        name=Name(first_name=first_name, last_name=last_name),
        ...
    )
    self.db.users[user_id] = user  # ← Local DB only, no MCP call!
    return user
```

### 2. **Wrong MCP Server Credentials** ❌
The `.env` file in the CRM domain data directory points to a different server:

```
CRM_MCP_URL=http://x1000c4s2b0n0:3000/mcp
CRM_MCP_TOKEN=<token for x1000c4s2b0n0>
```

**Correct server (from .crm_environment_env):**
```
TWENTY_HOSTNAME='x1000c0s4b0n0'
```

### 3. **Schema Mismatch** ⚠️
The domain uses local data models that don't match Twenty CRM's schema:

| tau2-bench Model | Twenty CRM Schema |
|-----------------|-------------------|
| `CRMUser.name.first_name` | `people.name.firstName` |
| `CRMUser.email` | `people.emails.primaryEmail` |
| `CRMOrganization.name` | `companies.name` |
| `CRMDeal.name` | `opportunities.name` |

### 4. **Field Name Mismatch** ⚠️
- Local: `first_name`, `last_name`, `email`, `phone`, `company`
- Twenty CRM: `name.firstName`, `name.lastName`, `emails.primaryEmail`, `phones.primaryPhoneNumber`, `companyId` (linked via organization)

## What Needs to Be Fixed

### 1. Rewrite All Tools to Call MCP

Every tool must call `_call_mcp_tool()` or use direct MCP calls.

**Example fix for create_user:**
```python
@is_tool(ToolType.WRITE)
def create_user(self, first_name: str, ...) -> CRMUser:
    # Call MCP instead of local DB
    result = self._call_mcp_tool("create_one_person", {
        "name": {"firstName": first_name, "lastName": last_name},
        "emails": {"primaryEmail": email},
        "phones": {"primaryPhoneNumber": phone or ""},
        "jobTitle": title,
        "position": "last"
    })
    
    # Parse response and return local CRMUser
    response_text = result.get("content", [{}])[0].get("text", "{}")
    response_data = json.loads(response_text)
    
    user_id = response_data.get("result", {}).get("id")
    return CRMUser(
        user_id=user_id,
        name=Name(first_name=first_name, last_name=last_name),
        ...
    )
```

### 2. Update .env File
```env
CRM_MCP_URL=http://x1000c0s4b0n0:3000/mcp?mode=direct
CRM_MCP_TOKEN=<token from .crm_environment_env>
```

### 3. Map Tool Calls to Twenty CRM MCP Tools

| tau2-bench Tool | Twenty CRM MCP Tool | Arguments Mapping |
|-----------------|---------------------|-------------------|
| `create_user` | `create_one_person` | `name.firstName/lastName`, `emails.primaryEmail`, `phones.primaryPhoneNumber`, `jobTitle`, `companyId`, `position` |
| `search_users` | `find_many_people` | `name.firstName.ilike`, `emails.primaryEmail.ilike`, `jobTitle` |
| `get_user_details` | `find_one_person` | `id` |
| `update_user_info` | `upsert_many_people` | `id`, `name`, `emails`, `phones`, `jobTitle` |
| `delete_user` | `delete_one_person` | `id` |
| `create_organization` | `create_one_company` | `name`, `industry`, `annual_revenue`, `employees`, `website`, `phone` |
| `search_organizations` | `find_many_companies` | `name.ilike`, `industry` |
| `create_deal` | `create_one_opportunity` | `name`, `companyId`, `value`, `stageName`, `probability` |
| `update_deal_stage` | `upsert_many_opportunities` | `id`, `stageName` |
| `add_note` | `create_one_note` | `content`, `targetRecordId`, `targetObjectName` |

### 4. Handle MCP Response Format

MCP returns nested JSON in `result.content[].text`:
```json
{
  "content": [{
    "text": "{\"success\":true,\"result\":{\"id\":\"uuid\"},...}"
  }],
  "isError": false
}
```

## Tasks Status

**10 tasks are defined** in tasks.json, all requiring MCP integration:

1. ✅ Create lead and convert to customer
2. ✅ Check existing user's deal status
3. ✅ Update deal stage
4. ✅ Add notes to user records
5. ✅ Search organizations by industry
6. ✅ Update user information
7. ✅ Create organization and deal
8. ✅ Close a deal as won
9. ✅ Handle stubborn user (user's requirement)
10. ✅ Comprehensive sales cycle

**All 10 tasks will fail** without MCP integration.

## Additional Issues

### 1. No MCP Tool Discovery
The tools don't call `learn_tools` or `get_tool_catalog` to discover available tools.

### 2. No Error Handling
Missing error handling for MCP failures (network issues, authentication, rate limits).

### 3. No Retry Logic
No retry mechanism for transient failures.

### 4. No Rate Limiting
MCP servers may have rate limits that aren't being respected.

## Recommendations

### Option A: Quick Fix (2-4 hours)
1. Update `.env` with correct credentials
2. Rewrite all 14 tools to call MCP
3. Add error handling and retry logic
4. Test with Twenty CRM UI

### Option B: Reuse Existing Assessment
The assessment files already exist in `/workspace/crm-environment/mcp/`:
- `FINDINGS.md` - Complete MCP server documentation
- `MCP_ARCHITECTURE.md` - Usage patterns and examples
- `ASSESSMENT.md` - Integration plan

### Option C: Create tau2-bench-copy
Copy the domain to a new location and build the MCP integration from scratch:
```bash
cp -r tau2-bench-backup src/tau2/domains/crm tau2-bench-copy/
```

## Testing Requirements

After fixing, verify:

1. ✅ `create_user` creates person in Twenty CRM (visible in UI)
2. ✅ `search_users` finds people from Twenty CRM
3. ✅ `create_deal` creates opportunity in Twenty CRM
4. ✅ `get_user_details` reads from Twenty CRM
5. ✅ All tools handle MCP errors gracefully

## Conclusion

**The CRM domain is a local simulation that looks like MCP integration but doesn't actually call the Twenty CRM server.** To make it work, you must:

1. Fix the `.env` file (wrong server)
2. Rewrite all tools to call MCP via `execute_tool`
3. Map field names to Twenty CRM schema
4. Handle MCP response format

Without these changes, **the domain will only work with local data and won't interact with Twenty CRM at all.**
