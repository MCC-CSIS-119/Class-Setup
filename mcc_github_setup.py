"""GitHub setup for MCC CSIS-119."""

import os
import json

import requests

CANVAS_COURSE_ID = os.environ["CANVAS_COURSE_ID"]
CANVAS_BASE_URL = f"https://mcckc.instructure.com/api/v1/courses/{CANVAS_COURSE_ID}"
CANVAS_TOKEN = os.environ["CANVAS_TOKEN"]
CANVAS_HEADERS = {"Authorization": f"Bearer {CANVAS_TOKEN}"}

GITHUB_ORG = "MCC-CSIS-119"
GITHUB_BASE_URL = "https://api.github.com"
GITHUB_ORG_BASE_URL = f"{GITHUB_BASE_URL}/orgs/{GITHUB_ORG}"
GITHUB_PAT = os.environ["GITHUB_PAT"]
# GITHUB_ADMIN_ID = "dnlloyd"

GITHUB_HEADERS = {
    "Authorization": f"Bearer {GITHUB_PAT}",
    "Accept": "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28",
}


def fetch_students():
    """Fetch all student info from Canvas."""
    response = requests.get(
        f"{CANVAS_BASE_URL}/users?per_page=50",
        headers=CANVAS_HEADERS,
        timeout=10,
    )

    response.raise_for_status()
    return json.loads(response.content.decode())


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
    """Create GitHub repo for student."""
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
    return response


if __name__ == "__main__":
    # student_info = fetch_students()
    student_info = ["Fake-Student"]

    for student in student_info:
        create_repo(student, "Scripting fundamentals")
        sha = fetch_main_ref(student)
        print(sha)


# TODO:
# 1) Grant users "Write" access to repo
# 2) Create default dev branch
