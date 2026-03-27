This is an easy project, but it involves a lot of researching, and your job is mostly to adhere to the overall user requirements that I have, the pre-launch requirements, the references, the rulebooks, and whatnot. On top of that, you have to resource most of the time. You don't really reinvent the wheel with most of the project here. It's 80% research, 20% coding, and the rest is iteration.

## Development Workflow

For new features and projects, follow this sequential pipeline. Each step requires the previous ones to be complete.

| Step | Skill | Role | Requires |
|------|-------|------|----------|
| 1 | `/grill-me` | Interview — reach shared understanding of the idea | Nothing |
| 2 | `/write-a-prd` | Create PRD and submit as a GitHub issue | Step 1 |
| 3 | `/prd-to-issues` | Break PRD into vertical-slice GitHub issues with dependencies | Step 2 |
| 4 | `/orchestrator` | Pick up issues and execute them (use `/tdd` inside for code quality) | Step 3 |
| 5 | `/improve-codebase-architecture` | Clean up — find and fix shallow modules | Step 4 | 