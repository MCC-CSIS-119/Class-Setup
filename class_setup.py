"""GitHub setup for MCC CSIS-119."""

import os
import json
import csv

import requests

CANVAS_COURSE_ID = os.environ["CANVAS_COURSE_ID"]
CANVAS_BASE_URL = f"https://mcckc.instructure.com/api/v1/courses/{CANVAS_COURSE_ID}"
CANVAS_TOKEN = os.environ["CANVAS_TOKEN"]
CANVAS_HEADERS = {"Authorization": f"Bearer {CANVAS_TOKEN}"}
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
