When you work on a task, explain it to me like I am your manager, not a technical engineer. I want to learn from the process, but only at a high level. I want you to explain like you would to a 7 year old child, i am in my learning phase. with some tech terms in ()


This is an easy project, but it involves a lot of researching, and your job is mostly to adhere to the overall user requirements that I have, the pre-launch requirements, the references, the rulebooks, and whatnot. On top of that, you have to resource most of the time. You don't really reinvent the wheel with most of the project here. It's 80% research, 20% coding, and the rest is iteration.

## Development Workflow

For new features and projects, follow this sequential pipeline. Each step requires the previous ones to be complete.

| Step | Skill | Role | Requires |
|------|-------|------|----------|
| 1 | `/grill-me` | Interview — reach shared understanding of the idea | Nothing |
| 2 | `/write-a-prd` | Create PRD and submit as a GitHub issue | Step 1 |
| 3 | `/prd-to-issues` | Break PRD into vertical-slice GitHub issues with dependencies | Step 2 |
| 4 | `/task-batch https://github.com/pnsw123/prod-note/issues` | Pick up issues and execute them in batches automatically — do NOT prompt the user to run this, just run it | Step 3 |
| 5 | `/improve-codebase-architecture` | Clean up — find and fix shallow modules | Step 4 | 

when we get the issues fixed, i want you to push them into GitHub if we don't push the solved issues; otherwise, all of our effort will be gone. 