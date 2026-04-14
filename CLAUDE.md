Use this as a prompt:

**Prompt:**

When you work on a task, explain it to me like I am your manager, not a technical engineer. I want to learn from the process, but only at a high level. I want you to explain like you would to a 7 year old child, i am in my learning phase. with some tech terms in (). Try to make your answers simple, clear, and short. I really don't have time to read all of your boring details that don't teach me anything. 

For every task, focus on explaining:

I care about the very short version of what you've done, which behavior was completed. I don't really care about how you did it, because I'm not learning how you did it. I care about the tools you use, when it was implemented, and whether it is enterprise-ready, code-ready, right, because there's no need to tell me what kind of coding you've done. You could reference that to yourself, but for me as a reader I don't care about what you have coded; I care about what was shipped at the end. I will be asking a lot of questions and requirements. Demands. What I care about is meeting these demands, not how you did them. 



Do **not** overload me with low-level technical details unless they are truly necessary. For example, I usually do **not** need to know about small code edits, metadata changes, or implementation details unless they affect the outcome in an important way.

What I care about most is:

1. the big-picture plan
2. what is being done
3. why it is being done
4. what result it is expected to produce

Your responses should be:

* high-level
* manager-friendly
* concise but informative
* organized in tables when possible
* focused on useful insights, not technical noise

I would rather see a clear table of decisions, tools, risks, status, and outcomes than a long wall of technical explanation.

If code changes are involved, summarize them briefly instead of making me read every detail. Only show the full technical detail when it is necessary for decision-making.

A good response should make me feel like I understand the strategy, the reasoning, and the progress without needing to be an expert.

## Development Workflow (Pocock Pipeline)

For new projects and features, follow this 5-step sequential workflow. Each step depends on the previous ones — you cannot skip ahead.

| Step | Skill | Role | Requires |
|------|-------|------|----------|
| 1 | `/grill-me` | Interview — reach shared understanding of the idea | Nothing |
| 2 | `/write-a-prd` | Create PRD and submit as a GitHub issue | Step 1 |
| 3 | `/prd-to-issues` | Break PRD into vertical-slice GitHub issues with dependencies | Step 2 |
| 4 | `/task-batch https://github.com/pnsw123/prod-note/issues` | Pick up issues and execute them (use `/tdd` inside for code quality) | Step 3 |
| 5 | `/improve-codebase-architecture` | Clean up — find and fix shallow modules | Step 4 |

**Rules:**
- Steps are sequential — never run step N without completing steps 1 through N-1
- Step 5 can also be run independently as periodic maintenance (weekly or after big sprints)
- `/tdd` is a coding methodology used *within* step 4, not a standalone step

when we get the issues fixed, i want you to push them into GitHub if we don't push the solved issues; otherwise, all of our effort will be gone. 



for any code/new functions etc/ verify this pattern works reliably before touching any code.

