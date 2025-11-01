#!/usr/bin/env bash
set -euo pipefail

# --- Config -------------------------------------------------------------------
STUDENT_CMD="awk -F: '/:x:10[0-9][0-9]/ && \$1 !~ /ec2-user|bastion/ {print \$1}' /etc/passwd"
HIST_PATH='/home/%s/.bash_history'

# --- Helpers ------------------------------------------------------------------
found() {
  # POSIX-friendly grep: -E (ERE), -q (quiet), -s (no error on missing file)
  local pattern="$1" file="$2"
  grep -Eqs "$pattern" "$file"
}

# Match ls -al OR -la with loose spacing (letters only in flag cluster)
ls_al_regex='(^|[[:space:]])ls[[:space:]]+-([[:alpha:]]*a[[:alpha:]]*l|[[:alpha:]]*l[[:alpha:]]*a)([[:space:]]|$)'

# --- Slide matchers -----------------------------------------------------------
slide1() { # cd / ; pwd ; tree -d -L 1 /   (be lenient about tree flags)
  local hf="$1"
  found '(^|[[:space:]])cd[[:space:]]+/[[:space:]]*$' "$hf" &&
  found '(^|[[:space:]])pwd([[:space:]]|$)' "$hf" &&
  # Accept "tree -d -L 1 /" OR any "tree ... /"
  ( found '(^|[[:space:]])tree[[:space:]]+-d[[:space:]]+-L[[:space:]]+1[[:space:]]+/[[:space:]]*$' "$hf" \
    || found '(^|[[:space:]])tree([[:space:]]+[^|;]*)?[[:space:]]+/([[:space:]]|$)' "$hf" )
}

slide2() { # cd /home/$USER ; pwd ; ls -al
  local hf="$1" student="$2"
  found "(^|[[:space:]])cd[[:space:]]+/home/${student}[[:space:]]*$" "$hf" &&
  found '(^|[[:space:]])pwd([[:space:]]|$)' "$hf" &&
  found "$ls_al_regex" "$hf"
}

slide3() { # cd /home/$USER ; cd my_scripts ; pwd ; ls -al
  local hf="$1" student="$2"
  found "(^|[[:space:]])cd[[:space:]]+/home/${student}[[:space:]]*$" "$hf" &&
  found '(^|[[:space:]])cd[[:space:]]+my_scripts([[:space:]]|$)' "$hf" &&
  found '(^|[[:space:]])pwd([[:space:]]|$)' "$hf" &&
  found "$ls_al_regex" "$hf"
}

slide4() { # cd ~ ; pwd ; cd my_scripts ; ls -al ; cat hello.sh
  local hf="$1"
  found '(^|[[:space:]])cd[[:space:]]+~([[:space:]]|$)' "$hf" &&
  found '(^|[[:space:]])pwd([[:space:]]|$)' "$hf" &&
  found '(^|[[:space:]])cd[[:space:]]+my_scripts([[:space:]]|$)' "$hf" &&
  found "$ls_al_regex" "$hf" &&
  found '(^|[[:space:]])cat[[:space:]]+hello\.sh([[:space:]]|$)' "$hf"
}

slide5() { # env ; echo $HOSTNAME ; echo $USER  (history may contain expanded values)
  local hf="$1" student="$2"
  local host; host="$(hostname 2>/dev/null || true)"
  found '(^|[[:space:]])env([[:space:]]|$)' "$hf" &&
  ( found '(^|[[:space:]])echo[[:space:]]+\$HOSTNAME([[:space:]]|$)' "$hf" \
    || { [[ -n "$host" ]] && found "(^|[[:space:]])echo[[:space:]]+${host}([[:space:]]|$)" "$hf"; } ) &&
  ( found '(^|[[:space:]])echo[[:space:]]+\$USER([[:space:]]|$)' "$hf" \
    || found "(^|[[:space:]])echo[[:space:]]+${student}([[:space:]]|$)" "$hf" )
}

slide6() { # env ; env | grep NAME
  local hf="$1"
  found '(^|[[:space:]])env([[:space:]]|$)' "$hf" &&
  found '(^|[[:space:]])env[[:space:]]*\|[[:space:]]*grep([[:space:]]+[-[:alpha:]]+)?[[:space:]]+NAME([[:space:]]|$)' "$hf"
}

slide7() { # cat /etc/passwd | grep $USER | awk -F':' '{print $1, $2}'
  local hf="$1" student="$2"
  found '(^|[[:space:]])cat[[:space:]]+/etc/passwd([[:space:]]|$)' "$hf" &&
  ( found 'cat[[:space:]]+/etc/passwd[[:space:]]*\|[[:space:]]*grep[[:space:]]+\$USER' "$hf" \
    || found "cat[[:space:]]+/etc/passwd[[:space:]]*\\|[[:space:]]*grep[[:space:]]+${student}([[:space:]]|$)" "$hf" ) &&
  # Check awk pieces separately to avoid brittle quoting/braces issues
  found "awk[[:space:]]+-F:[[:space:]]*" "$hf" &&
  found "print[[:space:]]*\\\$1" "$hf" &&
  found "\\\$2" "$hf"
}

slide8() { # cat /etc/passwd | awk -F':' '{print $1}'  and then ... | sort
  local hf="$1"
  found "cat[[:space:]]+/etc/passwd[[:space:]]*\\|[[:space:]]*awk[[:space:]]+-F:[[:space:]]*" "$hf" &&
  found "print[[:space:]]*\\\$1" "$hf" &&
  found "\\|[[:space:]]*sort([[:space:]]|$)" "$hf"
}

slide9() { # ps -ef ; ps -ef | grep sshd
  local hf="$1"
  found '(^|[[:space:]])ps[[:space:]]+-ef([[:space:]]|$)' "$hf" &&
  found '(^|[[:space:]])ps[[:space:]]+-ef[[:space:]]*\|[[:space:]]*grep[[:space:]]+sshd([[:space:]]|$)' "$hf"
}

slide10() { # htop
  local hf="$1"
  found '(^|[[:space:]])htop([[:space:]]|$)' "$hf"
}

slide_fn() {
  case "$1" in
    1) echo slide1 ;;
    2) echo slide2 ;;
    3) echo slide3 ;;
    4) echo slide4 ;;
    5) echo slide5 ;;
    6) echo slide6 ;;
    7) echo slide7 ;;
    8) echo slide8 ;;
    9) echo slide9 ;;
    10) echo slide10 ;;
    *) return 1 ;;
  esac
}

# --- Main ---------------------------------------------------------------------
declare -A totals

printf "Student,Slide,Score\n"

# shellcheck disable=SC2046
while IFS= read -r student; do
  [[ -z "${student// }" ]] && continue
  printf -v hist_file "$HIST_PATH" "$student"
  totals["$student"]=0

  if [[ ! -s "$hist_file" ]]; then
    for s in {1..10}; do
      printf "%s,Slide %d,0\n" "$student" "$s"
    done
    continue
  fi

  for s in {1..10}; do
    fn="$(slide_fn "$s")"
    if "$fn" "$hist_file" "$student"; then
      printf "%s,Slide %d,10\n" "$student" "$s"
      totals["$student"]=$(( totals["$student"] + 10 ))
    else
      printf "%s,Slide %d,0\n" "$student" "$s"
    fi
  done
done < <(eval "$STUDENT_CMD")

printf "\nStudent,Total\n"
for student in "${!totals[@]}"; do
  printf "%s,%d\n" "$student" "${totals[$student]}"
done
