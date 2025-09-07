#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
classroom_to_team.py

Create/sync a GitHub Organization team from a GitHub Classroom roster.

What it does
------------
1) Resolves a classroom (by ID or name) and lists all assignments in it.
2) For each assignment, lists "accepted assignments" and collects the student GitHub logins.
3) Optionally creates the target team if it doesn't exist.
4) Adds each student to the team (role=member by default).
    - If a user isn't in the org, they'll be invited and show as PENDING until acceptance.

Auth & Permissions
------------------
- Provide a token via env GITHUB_TOKEN or --token.
- Classroom API: must be a classroom admin; FG-PATs require no extra perms. 
    Docs: https://docs.github.com/en/rest/classroom/classroom  (API v2022-11-28)
- Teams membership: org owner or team maintainer; FG-PAT "Members: write" or classic PAT "admin:org".
    Docs: Add/Update team membership: /orgs/{org}/teams/{team_slug}/memberships/{username}

Usage
-----
python classroom_to_team.py \\
    --org my-org \\
    --team-slug csis-119-fall-2025 \\
    --classroom-name "CSIS-119 Fall 2025"

# or, if you know the classroom ID:
python classroom_to_team.py --org my-org --team-slug csis-119 --classroom-id 1337

# create the team if missing, and set members as maintainers:
python classroom_to_team.py --org my-org --team-slug csis-119 --classroom-id 1337 --create-team "CSIS 119 (Fall 2025)" --team-role maintainer

# restrict to specific assignment IDs (comma-separated):
python classroom_to_team.py --org my-org --team-slug csis-119 --classroom-id 1337 --assignment-ids 111,222,333

Notes
-----
- Only students who have **accepted at least one assignment** have a resolvable GitHub username via the API.
- IdP-synchronized teams can’t be modified via API; you’ll get a helpful error if that’s the case.
"""

import argparse
import os
import sys
import time
from typing import Dict, Iterable, List, Optional, Set

import requests

API_VERSION = "2022-11-28"
DEFAULT_API = "https://api.github.com"

def api(base: str, path: str) -> str:
    return f"{base.rstrip('/')}/{path.lstrip('/')}"

def gh(method: str, url: str, token: str, **kwargs) -> requests.Response:
    headers = kwargs.pop("headers", {})
    headers.update({
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": API_VERSION,
        "Authorization": f"Bearer {token}",
        "User-Agent": "classroom-to-team/1.0",
    })
    resp = requests.request(method, url, headers=headers, **kwargs)
    if resp.status_code == 429 or (resp.status_code == 403 and "rate limit" in resp.text.lower()):
        # crude backoff; rethrow after sleep
        time.sleep(5)
    if not (200 <= resp.status_code < 300):
        try:
            detail = resp.json()
        except Exception:
            detail = resp.text
        raise RuntimeError(f"{method} {url} -> {resp.status_code}: {detail}")
    return resp

# ---------- Classroom helpers (docs: REST Classroom endpoints) ----------
def list_classrooms(base: str, token: str) -> List[Dict]:
    out, page = [], 1
    while True:
        r = gh("GET", api(base, "/classrooms"), token, params={"page": page, "per_page": 100})
        batch = r.json()
        if not batch:
            break
        out.extend(batch)
        page += 1
    return out  # items like {"id": ..., "name": ...}
# Docs show: List classrooms & Get a classroom. Also see "List assignments for a classroom" and "List accepted assignments".
# 

def get_classroom_by_name(base: str, token: str, name: str) -> Optional[Dict]:
    for c in list_classrooms(base, token):
        if c.get("name", "").strip().lower() == name.strip().lower():
            return c
    return None

def list_assignments_for_classroom(base: str, token: str, classroom_id: int) -> List[Dict]:
    out, page = [], 1
    while True:
        r = gh("GET", api(base, f"/classrooms/{classroom_id}/assignments"), token, params={"page": page, "per_page": 100})
        batch = r.json()
        if not batch:
            break
        out.extend(batch)
        page += 1
    return out  # items contain assignment 'id', 'title', 'accepted' counts, etc.
# 

def list_accepted_assignments(base: str, token: str, assignment_id: int) -> List[Dict]:
    out, page = [], 1
    while True:
        r = gh("GET", api(base, f"/assignments/{assignment_id}/accepted_assignments"),
                token, params={"page": page, "per_page": 100})
        batch = r.json()
        if not batch:
            break
        out.extend(batch)
        page += 1
    return out  # each item includes "students": [{"login": "..."}], plus repo info.
# 

def collect_usernames_from_classroom(base: str, token: str, classroom_id: int, restrict_ids: Optional[Iterable[int]] = None) -> Set[str]:
    usernames: Set[str] = set()
    assignments = list_assignments_for_classroom(base, token, classroom_id)
    ids = [a["id"] for a in assignments]
    if restrict_ids:
        ids = [i for i in ids if i in set(int(x) for x in restrict_ids)]
    for aid in ids:
        for rec in list_accepted_assignments(base, token, aid):
            for stu in rec.get("students", []):
                login = (stu.get("login") or "").strip()
                if login:
                    usernames.add(login)
    return usernames

# ---------- Teams helpers ----------
def get_team(base: str, token: str, org: str, team_slug: str) -> Optional[Dict]:
    try:
        r = gh("GET", api(base, f"/orgs/{org}/teams/{team_slug}"), token)
        return r.json()
    except RuntimeError as e:
        if "404" in str(e):
            return None
        raise

def create_team(base: str, token: str, org: str, name: str) -> Dict:
    # POST /orgs/{org}/teams
    r = gh("POST", api(base, f"/orgs/{org}/teams"), token, json={"name": name, "privacy": "closed"})
    return r.json()
# 

def add_user_to_team(base: str, token: str, org: str, team_slug: str, username: str, role: str = "member") -> Dict:
    # PUT /orgs/{org}/teams/{team_slug}/memberships/{username}
    r = gh("PUT", api(base, f"/orgs/{org}/teams/{team_slug}/memberships/{username}"), token, json={"role": role})
    return r.json()
# 

def main():
    ap = argparse.ArgumentParser(description="Create/sync a GitHub Org team from a GitHub Classroom roster.")
    ap.add_argument("--api-url", default=os.environ.get("GITHUB_API_URL", DEFAULT_API), help="Base API URL (use your GHES URL if applicable)")
    ap.add_argument("--token", default=os.environ.get("GITHUB_TOKEN"), help="GitHub token (env GITHUB_TOKEN if not provided)")
    ap.add_argument("--org", required=True, help="Organization login (e.g., my-org)")
    ap.add_argument("--team-slug", required=True, help="Team slug to add members to (e.g., csis-119-fall-2025)")
    ap.add_argument("--create-team", metavar="TEAM_NAME", help="If team is missing, create it with this name")
    ap.add_argument("--team-role", default="member", choices=["member", "maintainer"], help="Team role to grant (default: member)")
    ap.add_argument("--classroom-id", type=int, help="GitHub Classroom ID")
    ap.add_argument("--classroom-name", help="GitHub Classroom name (resolve to ID)")
    ap.add_argument("--assignment-ids", help="Comma-separated assignment IDs to restrict roster (optional)")
    ap.add_argument("--dry-run", action="store_true", help="Show what would happen without making changes")
    args = ap.parse_args()

    if not args.token:
        print("Error: Provide a token with --token or set GITHUB_TOKEN.", file=sys.stderr)
        sys.exit(2)

    # Resolve classroom ID
    classroom_id = args.classroom_id
    if not classroom_id and args.classroom_name:
        c = get_classroom_by_name(args.api_url, args.token, args.classroom_name)
        if not c:
            print(f"❌ Classroom named '{args.classroom_name}' not found (check spelling or your access).", file=sys.stderr)
            sys.exit(1)
        classroom_id = int(c["id"])
    if not classroom_id:
        print("Error: You must provide --classroom-id or --classroom-name.", file=sys.stderr)
        sys.exit(2)

    # Collect usernames
    restrict_ids = None
    if args.assignment_ids:
        restrict_ids = [int(x.strip()) for x in args.assignment_ids.split(",") if x.strip()]
    print(f"🔎 Gathering GitHub usernames from classroom {classroom_id}...")
    usernames = collect_usernames_from_classroom(args.api_url, args.token, classroom_id, restrict_ids)
    if not usernames:
        print("⚠️ No student GitHub usernames found (have they accepted any assignments yet?).")
        sys.exit(0)
    print(f"✅ Found {len(usernames)} unique usernames.")

    # Ensure team exists
    team = get_team(args.api_url, args.token, args.org, args.team_slug)
    if not team:
        if args.create_team:
            if args.dry_run:
                print(f"🛈 DRY-RUN: would create team '{args.create_team}' in org {args.org}.")
                team_slug = args.team_slug
            else:
                t = create_team(args.api_url, args.token, args.org, args.create_team)
                team_slug = t["slug"]
                print(f"🆕 Created team '{t['name']}' with slug '{team_slug}'.")
        else:
            print(f"❌ Team '{args.team_slug}' not found in org {args.org}. Re-run with --create-team \"NAME\" to create it.", file=sys.stderr)
            sys.exit(1)
    else:
        team_slug = team["slug"]
        print(f"🏷️ Using existing team '{team.get('name', team_slug)}' (slug: {team_slug}).")

    # Add members
    added, pending, unchanged, failed = 0, 0, 0, 0
    for u in sorted(usernames, key=str.lower):
        if args.dry_run:
            print(f"DRY-RUN: would add @{u} to {args.org}/{team_slug} as {args.team_role}")
            continue
        try:
            res = add_user_to_team(args.api_url, args.token, args.org, team_slug, u, args.team_role)
            state = res.get("state")
            if state == "active":
                added += 1
                print(f"✅ @{u}: ACTIVE")
            elif state == "pending":
                pending += 1
                print(f"✅ @{u}: PENDING invite/membership")
            else:
                unchanged += 1
                print(f"ℹ️ @{u}: state={state}")
        except RuntimeError as e:
            failed += 1
            msg = str(e).lower()
            if "team synchronization" in msg or "external group" in msg:
                print(f"❌ @{u}: Team is IdP-synchronized; manage membership in your IdP.", file=sys.stderr)
                break
            else:
                print(f"❌ @{u}: {e}", file=sys.stderr)

    if not args.dry_run:
        print("\n—— Summary ——")
        print(f"ACTIVE: {added} | PENDING: {pending} | OTHER: {unchanged} | FAILED: {failed}")

if __name__ == "__main__":
    main()
