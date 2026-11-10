# CRM Domain Creation Session - 2026-10-17

## Summary

Created a custom CRM domain for tau-bench connected to Twenty CRM via MCP protocol.

## What Was Created

### Domain Structure

**Location:** `/workspace/crm-environment/tau2-bench-backup/src/tau2/domains/crm/`

**Files:**
- `__init__.py` - Module initialization
- `utils.py` - Data path utilities
- `data_model.py` - Pydantic models (CRMUser, CRMOrganization, CRMDeal, CRMNote, TwentyCRMDB)
- `tools.py` - 20+ tools for CRM operations via MCP
- `environment.py` - Domain factory functions

### Data Files

**Location:** `/workspace/crm-environment/tau2-bench-backup/data/tau2/domains/crm/`

- `db.json` - Initial database with 3 users, 3 organizations, 2 deals, 2 notes
- `policy.md` - Agent instructions for CRM/sales operations
- `tasks.json` - 10 comprehensive tasks
- `split_tasks.json` - Training (0-5) and test (6-9) splits
- `.env` - MCP configuration (URL and token)
- `.env.example` - Configuration template

### Key Features

**MCP Integration:**
- Connects to Twenty CRM at `http://x1000c0s3b0n0:3000/mcp`
- Uses Bearer token authentication
- All tools call MCP via `tools/call` JSON-RPC method

**Tasks (10 total):**
1. Create new lead and convert to customer
2. Lookup user and check deals
3. Update deal stage
4. Add notes to user records
5. Search organizations by industry
6. Update user information
7. Create deal for new organization
8. **Stubborn user handling** - Test persuasion techniques
9. Complete sales cycle
10. Comprehensive CRM workflow

**Configuration:**
- Read from `.env` file in domain data directory
- Environment variables: `CRM_MCP_URL`, `CRM_MCP_TOKEN`
- Fallback to hardcoded defaults if not set

## Architecture

```
tau-bench → CRMTools → MCP Server (port 3000) → Twenty CRM
```

## State Management

- Each task gets a fresh database state (from `db.json`)
- Changes to Twenty CRM **persist** (MCP modifies actual database)
- Changes are immediately visible in Twenty web UI

## Next Steps

Run evaluation:
```bash
cd /workspace/crm-environment/tau2-bench-backup
tau2 run --domain crm --agent-llm gpt-4.1 --user-llm gpt-4.1 \
  --num-trials 1 --num-tasks 10
```

View results:
```bash
tau2 view
```
