# Write a PRD

Create a Product Requirements Document by asking questions, then outputting `prd.json` and `requirements.md`.

## When to Use

- Starting a new feature from scratch
- User describes something they want built
- Need to break down an idea into tasks

## Process

### Step 1: Ask Questions (ONE AT A TIME)

Ask these questions sequentially, waiting for each answer before the next:

1. **Feature name**: "What should we call this feature?"
2. **Problem**: "What problem does this solve? Who has this problem?"
3. **Desired outcome**: "What should the user experience be when this is done?"
4. **Context**: "Where does this live in the app? What exists already?"
5. **Constraints**: "Any technical constraints, deadlines, or must-haves?"
6. **Out of scope**: "What should we explicitly NOT include?"
7. **Success**: "How will we know if this works?"

**Important**: Ask ONE question, wait for answer. Don't dump all questions at once.

### Step 2: Break Down into Stories and Tasks

After gathering answers:

1. **Identify stories** - Group related functionality into user stories
2. **Break into tasks** - Smallest possible units of work (15-45 min each)
3. **Order by dependency** - What needs to be built first?

### Step 3: Output Files

Generate both files in the project root (or specified directory).

## Output

Generate TWO files:

### 1. `prd.json` - Machine-readable task tracking

Use structure from `templates/prd.json.template`:

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

### 2. `requirements.md` - Human-readable requirements

Use structure from `templates/requirements.md.template`:

```markdown
# Requirements

## Story 1: Story Title

### Task 1-A: First small change

- Description of what to build
- Why it matters
- Priority: 1
```

## Task Guidelines

1. **Smallest unit** - Each task takes 15-45 minutes
2. **One change per task** - Don't bundle multiple changes
3. **Clear & specific** - "Add login button" not "Authentication"
4. **Dependencies first** - If Task B needs Task A, adjust priorities
5. **Testable** - Each task should be independently testable
6. **Actionable** - Developer knows exactly what to do

## Example Breakdown

**BAD** (too big):

- "Implement user authentication"

**GOOD** (small tasks):

- "Add login form HTML"
- "Add password validation"
- "Add form submission handler"
- "Add session storage"
- "Add logout button"
- "Add session check on page load"
