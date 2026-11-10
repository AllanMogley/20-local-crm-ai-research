# Session Notes — 2026-11-10 (DB checks + env_assertions for CRM domain)

## Goal
Make tau-bench score the CRM agent against the **live Twenty CRM state** (not just the local in-memory mirror), with checks that reflect each task's requirements.

## Key finding: how DB checks work
Tau-bench's `DB` reward compares `get_db_hash()` of the **local in-memory `CRMDB`**, never Twenty's Postgres. `EnvironmentEvaluator.calculate_reward` (`src/tau2/evaluator/evaluator_env.py`):
1. Gold env — replays `evaluation_criteria.actions` on a fresh env.
2. Predicted env — replays the agent's trajectory (`set_state`).
3. Compares `get_db_hash()` (== `get_pydantic_hash(self.db)`).

The MCP connection is only used for side effects (writes to Twenty), never for read-back during scoring. `db.json` is empty and reset per run.

## Decision: use ENV_ASSERTION to verify live Twenty
Added `verify_*` methods to `tools.py` that read back from Twenty via MCP, and wired them into `env_assertions` per task. Chose `reward_basis = ["NL_ASSERTION", "ENV_ASSERTION"]` (dropped `COMMUNICATE` — it was a no-op with empty `communicate_info`, and substring matching is a poor fit for trust-building quality; `NL_ASSERTION` already covers "good communication").

## Changes applied

### `src/tau2/domains/crm/tools.py`
- `_map_stage`: added `problem-resolution` → `PROPOSAL`.
- `_extract_find_many_records`: now also handles nested `result.records`.
- New read-back methods (plain, not `@is_tool`, so the agent can't call them):
  - `verify_person_exists(fn, ln)` — `find_many_people` by name.
  - `verify_opportunity_exists(fn, ln)` — finds person, then `find_many_opportunities` by `pointOfContactId`.
  - `verify_opportunity_stage(fn, ln, stage)` — checks an opportunity's `stage`.
  - `verify_person_trust_low(fn, ln, max_trust=25)` — local `CRMDB` mirror check.
- Dedup added to avoid eval-replay pollution: `_find_existing_opportunity_id(name, person_id)` + `_find_existing_task_id(subject)`; `create_opportunity` and `create_task` now reuse existing records.
- `create_person` `trust_level` default changed `0` → `50` so the task-1 "trust very low" assertion is meaningful.

### `data/tau2/domains/crm/tasks.json`
- All 10 tasks: `reward_basis = ["NL_ASSERTION", "ENV_ASSERTION"]`.
- `env_assertions` per task:
  - 0: Sarah Chen exists.
  - 1: Mark Reynolds exists + trust < 25 (local).
  - 2–5, 7–9: person exists + opportunity exists.
  - 6: Maria Garcia exists + opportunity exists + stage == PROPOSAL.

## Scoring flow (final)
`reward = NL_ASSERTION × ENV_ASSERTION` (binary 0/1 per task).
- NL_ASSERTION: LLM judge grades `nl_assertions` against transcript.
- ENV_ASSERTION: `verify_*` query live Twenty (trust check reads local mirror).

## Remaining / follow-ups (NOT done, need live env)
- Hostname drift: `.env` = `x1000c1s1b1n0`, `.crm_environment_env` = `x1000c1s2b1n1`. Reconcile before a real run.
- MCP unreachable from this sandbox; couldn't run `tau2 check-data` or a trial run (`uv`/pydantic not installed here).
- Verify manually after a run: records appear in Twenty Web UI + scores correct in `tau2 view`.

## Status: code/config complete; end-to-end verification pending on live environment.
