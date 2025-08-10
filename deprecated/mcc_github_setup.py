"""GitHub setup for MCC CSIS-119."""

import os
import json

import requests
import csv

CANVAS_COURSE_ID = os.environ["CANVAS_COURSE_ID"]
CANVAS_BASE_URL = f"https://mcckc.instructure.com/api/v1/courses/{CANVAS_COURSE_ID}"
CANVAS_TOKEN = os.environ["CANVAS_TOKEN"]
CANVAS_HEADERS = {"Authorization": f"Bearer {CANVAS_TOKEN}"}

GITHUB_ORG = "MCC-CSIS-119"
GITHUB_BASE_URL = "https://api.github.com"
GITHUB_ORG_BASE_URL = f"{GITHUB_BASE_URL}/orgs/{GITHUB_ORG}"
GITHUB_PAT = os.environ["GITHUB_PAT"]

GITHUB_HEADERS = {
    "Authorization": f"Bearer {GITHUB_PAT}",
    "Accept": "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28",
}

# E.g. /Users/dan/Documents/MCC/CSIS-119--Scripting-Fundamentals/2025-Fall
STUDENT_DATA_PATH = os.environ["STUDENT_DATA_PATH"]


def fetch_students():
    """Fetch all student info from Canvas."""
    print("Fetching students from Canvas...")
    response = requests.get(
        f"{CANVAS_BASE_URL}/users?per_page=50",
        headers=CANVAS_HEADERS,
        timeout=10,
    )

    response.raise_for_status()
    return json.loads(response.content.decode())


def write_full_names_to_csv(students):
    """Create 'full_name' for each student and write to CSV."""
    # Add 'full_name' to each dictionary
    for student in students:
        # Replace spaces with hyphens in the 'name' field
        student['full_name'] = student['name'].replace(" ", "-")

    # Write to CSV
    output_file = os.path.join(STUDENT_DATA_PATH, "students-full-names.csv")
    print("Writing student names to #{output_file}")

    with open(output_file, mode='w', newline='', encoding='utf-8') as csv_file:
        writer = csv.writer(csv_file)

        for student in students:
            writer.writerow([student['full_name'], ""])  # name, empty cell (adds comma)


def fetch_main_ref(repo_name):
    """Fetch main ref."""

    response = requests.get(
        f"{GITHUB_BASE_URL}/repos/{GITHUB_ORG}/{repo_name}/git/ref/heads/main",
        headers=GITHUB_HEADERS,
        timeout=10,
    )

    response.raise_for_status()
    return response.json()["object"]["sha"]


def create_repo(repo_name, class_name):
    """Create GitHub repo for student if it doesn't already exist."""

    # First, check if repo exists
    check_response = requests.get(
        f"{GITHUB_BASE_URL}/repos/{GITHUB_ORG}/{repo_name}",
        headers=GITHUB_HEADERS,
        timeout=10,
    )

    if check_response.status_code == 200:
        print(f"Repository '{repo_name}' already exists.")
        return None

    if check_response.status_code != 404:
        # Something unexpected went wrong
        check_response.raise_for_status()

    # Repo does not exist, proceed to create it
    github_data = {
        "name": repo_name,
        "description": f"{repo_name}'s repo for {class_name}",
        "visibility": "private",
        "has_issues": False,
        "has_projects": False,
        "has_wiki": False,
        "auto_init": True,
        "gitignore_template": "Python",
    }

    response = requests.post(
        f"{GITHUB_ORG_BASE_URL}/repos",
        headers=GITHUB_HEADERS,
        json=github_data,
        timeout=10,
    )

    response.raise_for_status()
    print(f"Repository '{repo_name}' created.")
    return response



if __name__ == "__main__":
    current_students = fetch_students()

    write_full_names_to_csv(current_students)

    # student_info = fetch_students()
    # student_info = ["Fake-Student"]

    # for student in student_info:
    #     create_repo(student, "Scripting fundamentals")

    #     sha = fetch_main_ref(student)
    #     print(sha)


# TODO:
# 1) Grant users "Write" access to repo
# 2) Create default dev branch
