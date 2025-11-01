#!/usr/bin/env bash
set -euo pipefail

# ================================
# Config
# ================================
TEACHER_GROUP="instructors"
STUDENT_CMD="awk -F: '/:x:10[0-9][0-9]/ && \$1 !~ /ec2-user|bastion/ {print \$1}' /etc/passwd"
HIST_PATH='/home/%s/.bash_history'

# ================================
# Priv helpers
# ================================
is_root() { [[ "$(id -u)" -eq 0 ]]; }
in_teacher_group() { id -nG 2>/dev/null | grep -qw "$TEACHER_GROUP"; }
is_teacher() { is_root || in_teacher_group; }

deny_unless_teacher() {
  if ! is_teacher; then
    echo "Error: this option requires root or membership in '$TEACHER_GROUP'." >&2
    exit 1
  fi
}

# ================================
# Grep helper (POSIX-friendly)
# ================================
found() { local p="$1" f="$2"; grep -Eqs "$p" "$f"; }

# Flag cluster for ls -al | -la (letters only, loose spacing)
ls_al_regex='(^|[[:space:]])ls[[:space:]]+-([[:alpha:]]*a[[:alpha:]]*l|[[:alpha:]]*l[[:alpha:]]*a)([[:space:]]|$)'

# ================================
# Slide matchers
# ================================
slide1(){ local hf="$1";
  found '(^|[[:space:]])cd[[:space:]]+/[[:space:]]*$' "$hf" &&
  found '(^|[[:space:]])pwd([[:space:]]|$)' "$hf" &&
  ( found '(^|[[:space:]])tree[[:space:]]+-d[[:space:]]+-L[[:space:]]+1[[:space:]]+/[[:space:]]*$' "$hf" \
    || found '(^|[[:space:]])tree([[:space:]]+[^|;]*)?[[:space:]]+/([[:space:]]|$)' "$hf" )
}
slide2(){ local hf="$1" student="$2";
  found "(^|[[:space:]])cd[[:space:]]+/home/${student}[[:space:]]*$" "$hf" &&
  found '(^|[[:space:]])pwd([[:space:]]|$)' "$hf" &&
  found "$ls_al_regex" "$hf"
}
slide3(){ local hf="$1" student="$2";
  found "(^|[[:space:]])cd[[:space:]]+/home/${student}[[:space:]]*$" "$hf" &&
  found '(^|[[:space:]])cd[[:space:]]+my_scripts([[:space:]]|$)' "$hf" &&
  found '(^|[[:space:]])pwd([[:space:]]|$)' "$hf" &&
  found "$ls_al_regex" "$hf"
}
slide4(){ local hf="$1";
  found '(^|[[:space:]])cd[[:space:]]+~([[:space:]]|$)' "$hf" &&
  found '(^|[[:space:]])pwd([[:space:]]|$)' "$hf" &&
  found '(^|[[:space:]])cd[[:space:]]+my_scripts([[:space:]]|$)' "$hf" &&
  found "$ls_al_regex" "$hf" &&
  found '(^|[[:space:]])cat[[:space:]]+hello\.sh([[:space:]]|$)' "$hf"
}
slide5(){ local hf="$1" student="$2"; local host; host="$(hostname 2>/dev/null || true)";
  found '(^|[[:space:]])env([[:space:]]|$)' "$hf" &&
  ( found '(^|[[:space:]])echo[[:space:]]+\$HOSTNAME([[:space:]]|$)' "$hf" \
    || { [[ -n "$host" ]] && found "(^|[[:space:]])echo[[:space:]]+${host}([[:space:]]|$)" "$hf"; } ) &&
  ( found '(^|[[:space:]])echo[[:space:]]+\$USER([[:space:]]|$)' "$hf" \
    || found "(^|[[:space:]])echo[[:space:]]+${student}([[:space:]]|$)" "$hf" )
}
slide6(){ local hf="$1";
  found '(^|[[:space:]])env([[:space:]]|$)' "$hf" &&
  found '(^|[[:space:]])env[[:space:]]*\|[[:space:]]*grep([[:space:]]+[-[:alpha:]]+)?[[:space:]]+NAME([[:space:]]|$)' "$hf"
}
slide7(){ local hf="$1" student="$2";
  found '(^|[[:space:]])cat[[:space:]]+/etc/passwd([[:space:]]|$)' "$hf" &&
  ( found 'cat[[:space:]]+/etc/passwd[[:space:]]*\|[[:space:]]*grep[[:space:]]+\$USER' "$hf" \
    || found "cat[[:space:]]+/etc/passwd[[:space:]]*\\|[[:space:]]*grep[[:space:]]+${student}([[:space:]]|$)" "$hf" ) &&
  found "awk[[:space:]]+-F:[[:space:]]*" "$hf" &&
  found "print[[:space:]]*\\\$1" "$hf" &&
  found "\\\$2" "$hf"
}
slide8(){ local hf="$1";
  found "cat[[:space:]]+/etc/passwd[[:space:]]*\\|[[:space:]]*awk[[:space:]]+-F:[[:space:]]*" "$hf" &&
  found "print[[:space:]]*\\\$1" "$hf" &&
  found "\\|[[:space:]]*sort([[:space:]]|$)" "$hf"
}
slide9(){ local hf="$1";
  found '(^|[[:space:]])ps[[:space:]]+-ef([[:space:]]|$)' "$hf" &&
  found '(^|[[:space:]])ps[[:space:]]+-ef[[:space:]]*\|[[:space:]]*grep[[:space:]]+sshd([[:space:]]|$)' "$hf"
}
slide10(){ local hf="$1"; found '(^|[[:space:]])htop([[:space:]]|$)' "$hf"; }

slide_fn(){ case "$1" in
  1) echo slide1;;2) echo slide2;;3) echo slide3;;4) echo slide4;;5) echo slide5;;
  6) echo slide6;;7) echo slide7;;8) echo slide8;;9) echo slide9;;10) echo slide10;;*) return 1;; esac; }

# ================================
# Args / Mode
# ================================
usage() {
  cat >&2 <<EOF
Usage:
  $(basename "$0")            # grade current user only (student-safe)
  $(basename "$0") --me       # same as default
  $(basename "$0") --all      # grade all students (requires $TEACHER_GROUP or root)
  $(basename "$0") --student USERNAME  # grade a single USERNAME (requires $TEACHER_GROUP or root)
EOF
}

MODE="me"
TARGET=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --me) MODE="me"; shift;;
    --all) MODE="all"; shift;;
    --student) MODE="one"; TARGET="${2:-}"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2;;
  esac
done

# Enforce safety: only instructors/root can grade others
case "$MODE" in
  me) :
    ;;
  all|one)
    deny_unless_teacher
    ;;
esac

# Resolve current login name robustly (prefers sudo caller, else real user)
CURRENT_USER="${SUDO_USER:-$USER}"

# Build the iterable list of students
build_student_list() {
  case "$MODE" in
    me) echo "$CURRENT_USER" ;;
    one) [[ -z "$TARGET" ]] && { echo "Error: --student requires a username" >&2; exit 2; }; echo "$TARGET" ;;
    all) eval "$STUDENT_CMD" ;;
  esac
}

# ================================
# Main
# ================================
declare -A totals
echo "Student,Slide,Score"

while IFS= read -r student; do
  [[ -z "${student// }" ]] && continue

  # If a non-teacher tries to grade someone else (e.g., by setting $USER), hard block:
  if [[ "$MODE" != "me" && "$student" != "$CURRENT_USER" && ! is_teacher ]]; then
    echo "Error: not authorized to grade user '$student'." >&2
    continue
  fi

  printf -v hist_file "$HIST_PATH" "$student"
  totals["$student"]=0

  # Students typically can't read others' histories; we also proactively restrict:
  if [[ "$MODE" == "me" && "$student" != "$CURRENT_USER" ]]; then
    echo "$student,Slide 1,0"
    for s in {2..10}; do echo "$student,Slide $s,0"; done
    continue
  fi

  if [[ ! -s "$hist_file" ]]; then
    for s in {1..10}; do echo "$student,Slide $s,0"; done
    continue
  fi

  for s in {1..10}; do
    fn="$(slide_fn "$s")"
    if "$fn" "$hist_file" "$student"; then
      echo "$student,Slide $s,10"
      totals["$student"]=$(( totals["$student"] + 10 ))
    else
      echo "$student,Slide $s,0"
    fi
  done
done < <(build_student_list)

echo
echo "Student,Total"
for student in "${!totals[@]}"; do
  echo "$student,${totals[$student]}"
done
