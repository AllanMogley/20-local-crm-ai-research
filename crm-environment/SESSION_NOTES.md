# CRM Domain in tau2-bench — Session Notes

## Environment
- Working dir: /workspace/crm-environment
- Host: x1000c0s0b1n0 (10.150.0.57), Twenty on port 3000, Postgres on 5432
- API key: in /workspace/crm-environment/.env (Bearer token)

## Research Goal
- Research on local AI LLMs vs cloud models in CRM applications
- Build a custom CRM domain in tau2-bench connected to Twenty CRM via MCP
- Theory: Commitment-Trust Theory (Morgan & Hunt, 1994)
- 10 tasks, including a stubborn/distrustful user conversion task

## Status
- [x] MCP tested and working (280 tools, 9 categories)
- [x] Findings saved to mcp/FINDINGS.md
- [x] tau2-bench structure explored
- [x] Feasibility assessment delivered
- [ ] CRM domain created (NOT YET — user said not to create yet)

## Key Decisions
- Tasks will modify Twenty data via MCP (execute_tool for real CRUD)
- Benchmark: tau2 run with different --agent-llm models, compare results
- Stubborn-user task: user simulator plays distrustful customer, agent attempts conversion

## Files
- .env — API key (Bearer token)
- INSTRUCTIONS.md — original instructions
- mcp/FINDINGS.md — MCP findings
- mcp/twenty-crm-tools — prior tool catalog note
- tau2-bench/ — tau2-bench repo (explored, not modified)

## Next Steps (when user is ready)
1. Explore existing domain (retail/mock) for tool/evaluation patterns
2. Design 10 CRM tasks (present list first per instructions)
3. Create domain in tau2-bench/src/tau2/domains/crm/
4. Register in registry.py
5. Run tau2 check-data, make test, then tau2 run for benchmarking
