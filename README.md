# Class-Setup

## GitHub Classroom and auto-grader

1. Create a GitHub Education classroom (Manual)
    - https://classroom.github.com/classrooms
1. Create template repo for each assignment
    - `main` should the default branch
    - Add appropriate GitHub workflows and tests
1. Add students to roster (`class_setup.py`)
1. Create Canvas assignment (Manual)
1. Create GitHub Classroom assignment and add link to Canvas assignment (Manual)

### Automation

```
export CANVAS_COURSE_ID="22251"
export STUDENT_DATA_PATH="${HOME}/Documents/MCC/CSIS-119--Scripting-Fundamentals/2025-Fall"
export CANVAS_TOKEN="abcd-1234567890"
```

```
python class_setup.py
```

### Assignments

- Students will add commits to `main` branch.
- Feedback will automatically make the PR
- Students will need to check that PR commit is passing.

### Classroom Roster CSV Upload

Export a roster from Canvas with names. Upload the CSV to GitHub Classroom. Classroom matches them as students accept assignment invite. You'll see both names and GitHub handles in the dashboard.

## Classroom to GitHub Team script

This script can be used to add all students from GitHub Classroom to a GitHub Org team

```sh
python classroom_to_team.py \
  --org MCC-CSIS-119 \
  --team-slug class-of-2025 \
  --classroom-name "Scripting-Fundamentals-2025-Fall" \
  --dry-run
```

## Linux server check student login script

[student_login_check.sh](student_login_check.sh)