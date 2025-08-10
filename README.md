# Class-Setup

## Steps

1. Create a GitHub Education classroom (Manual)
    - https://classroom.github.com/classrooms
1. Create template repo with `student` and `main` branch (Manual)
    - `main` should the default branch
    - Add appropriate GitHub workflows from `gh_workflows` dir
1. Protect `main` branch with Org ruleset (Manual) 
1. Add students to roster (`class_setup.py`)
1. Create Canvas assignment (Manual)
1. Create GitHub Classroom assignment and add link to Canvas assignment (Manual)

## Automation

```
export CANVAS_COURSE_ID="22251"
export CANVAS_TOKEN="abcd-1234567890"
export STUDENT_DATA_PATH="${HOME}/Documents/MCC/CSIS-119--Scripting-Fundamentals/2025-Fall"
```

```
python class_setup.py
```

## Assignments

- Students will need to add commits to `students` branch.
- Students will not need to make a PR from `students` to `main` as this is automatic.
- Students will need to check that PR commit is passing.


## Reference

### Classroom Roster CSV Upload

Export a roster from Canvas with names. Upload the CSV to GitHub Classroom. Classroom matches them as students accept assignment invite. You'll see both names and GitHub handles in the dashboard.

## Todo

- Add linting exceptions
