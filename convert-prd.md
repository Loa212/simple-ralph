# Convert PRD to JSON and Requirements

## TASK BREAKDOWN

Break down the issues into tasks. An issue may contain a single task (a small bugfix or visual tweak) or many, many tasks (a PRD or a large refactor).

Make each task the smallest possible unit of work. We don't want to outrun our headlights. Aim for one small change per task.

## Your Job

Given a PRD, you must:

1. **Parse requirements** into individual stories/features
2. **Break each into smallest tasks** - one change per task
3. **Output as JSON** to `prd.json`
4. **Output as Markdown** to `requirements.md`

## JSON Format (prd.json)

```json
{
  "project": "Project Name",
  "version": "1.0.0",
  "stories": [
    {
      "id": "STORY-1",
      "title": "Story Title",
      "priority": 1,
      "description": "What needs to be done",
      "tasks": [
        {
          "id": "TASK-1-A",
          "title": "First small change",
          "description": "What exactly to build",
          "priority": 1,
          "passes": false
        }
      ],
      "passes": false
    }
  ]
}
```

## Markdown Format (requirements.md)

```markdown
# Requirements

## Story 1: Story Title

### Task 1-A: First small change
- Description of what to build
- Why it matters
- Priority: 1

## Story 2: Another Story
...
```

## Guidelines

1. **Smallest unit** - Each task takes 15-45 minutes
2. **One change per task** - Don't bundle
3. **Clear & specific** - "Add login button" not "Authentication"
4. **Dependencies first** - Task B needs Task A? Adjust priorities
5. **Testable** - Each task independently testable
6. **Actionable** - Developer knows exactly what to do

## Example Breakdown

BAD (too big):
- "Implement user authentication"

GOOD (small tasks):
- "Add login form HTML"
- "Add password validation"
- "Add form submission handler"
- "Add session storage"
- "Add logout button"
- "Add session check on page load"

---RALPH_STATUS---
STATUS: IN_PROGRESS
TASKS_COMPLETED_THIS_LOOP: 0
FILES_MODIFIED: 0
TESTS_STATUS: NOT_RUN
WORK_TYPE: IMPLEMENTATION
EXIT_SIGNAL: false
RECOMMENDATION: Ready to receive PRD
---END_RALPH_STATUS---
