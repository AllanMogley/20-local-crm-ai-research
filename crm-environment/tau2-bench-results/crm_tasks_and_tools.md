# CRM Domain — Tasks, Conversations & Expected Tool Calls

> Reflects current state: `reward_basis = ["NL_ASSERTION", "ENV_ASSERTION"]`.
> Each task is a two-sided conversation: **agent LLM** (CRM rep) vs **user-simulator LLM** (the persona), with the agent calling CRM tools that write to Twenty via MCP.

## Task conversations (what happens)

| # | Persona (Company) | Conversation focus | Expected CRM side effect |
|---|-------------------|--------------------|--------------------------|
| 0 | Skeptical Business Owner — Sarah Chen (TechStart Inc) | Exploring options; asks detailed implementation/support/success questions; tests honesty. | Create lead: Sarah Chen |
| 1 | Stubborn Decision Maker — Mark Reynolds (Enterprise Corp) | Burned before; resists upsell; demands concrete evidence; low trust. | Create lead + mark trust very low |
| 2 | Analytical Evaluation Manager — Priya Sharma (Growth Inc) | Methodical technical evaluation; checks follow-up accuracy and competence. | Lead + pilot opportunity |
| 3 | Evidence-Seeking Buyer — David Kim (ScaleUp Inc) | Wants data, case studies, references; challenges unproven claims. | Lead + trial opportunity |
| 4 | Cautious Commitment Tester — Emma Rodriguez (Midway Corp) | Makes small commitments to test reliability before going all-in. | Lead + small pilot opportunity |
| 5 | Strategic Decision Maker — James Wilson (FutureTech) | Focuses on long-term value, scalability, partnership. | Lead + strategic opportunity |
| 6 | Challenged Customer — Maria Garcia (Innovate Inc) | Technical problem; tests responsibility/communication during resolution. | Lead + opportunity moved to problem-resolution stage |
| 7 | Advocate Customer — Alex Thompson (Success LLC) | Willing to refer; asks about the referral program. | Lead + referral opportunity |
| 8 | Loyal Customer — Rachel Brown (Enterprise Co) | Wants more value, advanced features, best practices. | Lead + renewal/upsell opportunity |
| 9 | At-Risk Customer — Chris Martinez (Transition Corp) | Multiple bad experiences; one last chance to rebuild trust. | Lead + churn-risk opportunity |

**Arc:** tasks 0–5 build trust (skepticism → evidence → small commitments → long-term value); tasks 6–9 maintain/restore trust (problem, referral, loyalty, churn). In every task the customer explicitly asks the agent to create a lead (and, for 2–9, an opportunity) — this is the hook that triggers the CRM writes graded by `ENV_ASSERTION`.

## Expected tool calls per task

> `create_opportunity` links via `person_id`; `company_id` is optional (agent may optionally `create_company` first, but it's not required).

| # | Tool sequence |
|---|---------------|
| 0 | `create_person` (Sarah Chen) |
| 1 | `create_person` (Mark Reynolds) → `update_person_trust_commitment` (trust_level < 25) |
| 2 | `create_person` (Priya Sharma) → `create_opportunity` (pilot) |
| 3 | `create_person` (David Kim) → `create_opportunity` (trial) |
| 4 | `create_person` (Emma Rodriguez) → `create_opportunity` (small pilot) |
| 5 | `create_person` (James Wilson) → `create_opportunity` (strategic) |
| 6 | `create_person` (Maria Garcia) → `create_opportunity` → `update_opportunity_stage` ("problem-resolution" → PROPOSAL) |
| 7 | `create_person` (Alex Thompson) → `create_opportunity` (referral) |
| 8 | `create_person` (Rachel Brown) → `create_opportunity` (renewal/upsell) |
| 9 | `create_person` (Chris Martinez) → `create_opportunity` (churn-risk) |

### Read tools the agent may use during conversation
`find_people`, `find_companies`, `find_opportunities`, `find_tasks`, `get_person_details`, `get_company_details`, `get_opportunity_details`, `get_task_details`, `get_relationship_metrics`.

## How each task is scored
- **NL_ASSERTION** — LLM judge checks the `nl_assertions` (e.g. "acknowledge skepticism", "provide evidence", "don't push for immediate commitment").
- **ENV_ASSERTION** — `verify_*` methods read back from live Twenty:
  - 0: Sarah Chen exists.
  - 1: Mark Reynolds exists + trust < 25 (local).
  - 2–5, 7–9: person exists + opportunity exists.
  - 6: Maria Garcia exists + opportunity exists + stage == PROPOSAL.

`reward = NL_ASSERTION × ENV_ASSERTION` (binary per task).
