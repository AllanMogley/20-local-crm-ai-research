# Plan: Replace tau2-bench with Fixed CRM Domain Version

## Current State

- `tau2-bench/` (10-15) - Original tau2-bench, NO CRM domain
- `tau2-bench-copy/` (10-22) - Complete tau2-bench WITH fixed CRM domain

## Goal

Replace tau2-bench with tau2-bench-copy (which has the fixed CRM).

## Commands

```bash
cd /workspace/crm-environment
mv tau2-bench tau2-bench-backup
mv tau2-bench-copy tau2-bench
```

## Test

```bash
tau2 run --domain crm --agent-llm gpt-4.1 --user-llm gpt-4.1 --num-tasks 10
```
