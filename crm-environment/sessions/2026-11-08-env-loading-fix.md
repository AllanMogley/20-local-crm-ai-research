# Session Notes — 2026-11-08

## Issue

`tau2 run --domain crm` failed with:

```
ValueError: TWENTY_MCP_TOKEN not found. Please create .env file in tau2-bench-copy directory
```

## Diagnosis

- tau2 runs inside an Apptainer container with the copy mounted at `/workspace/tau2-bench`
- `_load_mcp_credentials()` in `src/tau2/domains/crm/tools.py` climbed only 3 `os.path.dirname` levels up from `src/tau2/domains/crm`, landing in `src/` instead of the project root
- It looked for `/workspace/tau2-bench/src/.env` (doesn't exist) instead of `/workspace/tau2-bench/.env` (where `TWENTY_MCP_TOKEN` / `TWENTY_MCP_URL` live)
- `mcp_token` stayed `None` → `CRMMCPTools.__init__` raised ValueError

## Fix

`tau2-bench-copy/src/tau2/domains/crm/tools.py` — one more `os.path.dirname` (4 levels up to the project root):

```python
tau2_bench_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(crm_dir))))
```

Verified: path math resolves to `/workspace/tau2-bench`, so the container now reads `/workspace/tau2-bench/.env`.

## Status

- `tau2 run` with the CRM domain works again (MCP credentials load from `.env`)
