#!/usr/bin/env bash
# grade_system_monitor.sh
# Run as root. CSV is the official record; stdout prints a human-friendly report.
# Rubric (100 pts):
#  - Prompt (-p): 20
#  - While loop: 20
#  - clear present: 10
#  - date present: 10
#  - Sections: df -h / (10) + free -h (10) + ps…|head (10)  => 30
#  - sleep 5 + completion: 10
# Pre-check (run as student; not scored) reported separately.

set -euo pipefail

CSV_OUT="/root/system_monitor_grades-$(date +%F).csv"
SCRIPT_NAME="system_monitor.sh"
TIMEOUT_CMD="$(command -v timeout || true)"
SHELL="/bin/bash"

# Pre-check config
PRECHECK_ITER_INPUT="1"
PRECHECK_TIMEOUT_SECS=10

HEADER="student,exists,exec_perms,precheck_ok,precheck_exit,precheck_reason,run_ok,prompt,while,clear,date,sections,sleep5_done,total_points_100,notes"

# Roster (your exact filter)
mapfile -t STUDENTS < <(awk -F: '/:x:10[0-9][0-9]/ && $1 !~ /ec2-user|bastion/ {print $1}' /etc/passwd || true)

echo "Discovered students (${#STUDENTS[@]}):"
printf ' - %s\n' "${STUDENTS[@]:-<none>}"
echo

echo "$HEADER" > "$CSV_OUT"

pf() { # pretty flag
  local ok="$1" lbl="$2" pts="${3:-}"
  if [[ "$ok" == "yes" || "$ok" == "1" ]]; then
    printf "  [OK]  %-32s %s\n" "$lbl" "$pts"
  else
    printf "  [!!]  %-32s %s\n" "$lbl" "$pts"
  fi
}

yn_from_pts() { local n="${1:-0}"; (( n > 0 )) && echo "yes" || echo "no"; }

grade_one_student() {
  local user="$1"
  local home script file_exists exec_ok run_ok notes
  local precheck_ok="no" precheck_exit=0 precheck_reason=""
  home="$(getent passwd "$user" | awk -F: '{print $6}')"
  script="$home/$SCRIPT_NAME"

  file_exists="no"
  exec_ok="no"
  run_ok="no"
  notes=""

  printf -- "————— %s —————\n" "$user"

  if [[ -z "${home:-}" || ! -d "$home" ]]; then
    printf "Home dir: %s\n\n" "NOT FOUND"
    echo "$user,no,no,no,0,Home dir not found,no,0,0,0,0,0,0,Home dir not found" >> "$CSV_OUT"
    return
  fi

  if [[ ! -f "$script" ]]; then
    printf "Script:   %s\n\n" "Missing $SCRIPT_NAME"
    echo "$user,no,no,no,0,Missing $SCRIPT_NAME,no,0,0,0,0,0,0,Missing $SCRIPT_NAME" >> "$CSV_OUT"
    return
  fi
  file_exists="yes"

  if [[ -x "$script" ]]; then
    exec_ok="yes"
  else
    chmod +x "$script" 2>/dev/null || true
    [[ -x "$script" ]] && exec_ok="yes"
  fi

  printf "Home dir: %s\n" "$home"
  printf "Script:   %s (%s)\n" "$script" "$( [[ "$exec_ok" == "yes" ]] && echo exec || echo not-exec )"

  # -------- PRE-CHECK (as student, not scored) --------
  local pre_out="" pre_rc=0
  if [[ -n "$TIMEOUT_CMD" ]]; then
    set +e
    pre_out="$(sudo -u "$user" $SHELL -lc "cd '$home' && $TIMEOUT_CMD ${PRECHECK_TIMEOUT_SECS}s bash './$SCRIPT_NAME' <<<'${PRECHECK_ITER_INPUT}'" 2>&1)"
    pre_rc=$?
    set -e
    if (( pre_rc == 124 )); then
      precheck_ok="no"; precheck_exit=$pre_rc; precheck_reason="timeout ${PRECHECK_TIMEOUT_SECS}s"
    elif (( pre_rc == 0 )); then
      precheck_ok="yes"; precheck_exit=$pre_rc; precheck_reason="success"
    else
      precheck_ok="no"; precheck_exit=$pre_rc; precheck_reason="exit $pre_rc"
    fi
  else
    set +e
    pre_out="$(sudo -u "$user" $SHELL -lc "cd '$home' && bash './$SCRIPT_NAME' <<<'${PRECHECK_ITER_INPUT}'" 2>&1)"
    pre_rc=$?
    set -e
    if (( pre_rc == 0 )); then
      precheck_ok="yes"; precheck_exit=$pre_rc; precheck_reason="success"
    else
      precheck_ok="no"; precheck_exit=$pre_rc; precheck_reason="exit $pre_rc"
    fi
  fi
  printf "Pre-check: %s (exit=%s, reason=%s)\n" "$( [[ $precheck_ok == yes ]] && echo PASS || echo FAIL )" "$precheck_exit" "$precheck_reason"

  # -------- Static checks --------
  local content
  content="$(sed -e 's/[[:space:]]\+$//' "$script")"

  local raw_prompt=0 raw_while=0 raw_clear=0 raw_date=0 raw_sections=0 raw_sleep5=0

  grep -qE 'read[[:space:]]+-p' <<<"$content" && raw_prompt=2
  if grep -qE '^while \[ "\$COUNT" -le "\$RUNS" \]$' <<<"$content"; then
    raw_while=2
  fi

  grep -qE '^[[:space:]]*clear([[:space:]]+.*)?$' <<<"$content" && raw_clear=1
  grep -qE '^[[:space:]]*[^#[:space:]].*\bdate\b' <<<"$content" && raw_date=1

  local sect=0
  if grep -qE 'df[[:space:]]+-h[[:space:]]+/' <<<"$content"; then ((sect+=1)); fi
  if grep -qE '\bfree[[:space:]]+-h\b' <<<"$content"; then ((sect+=1)); fi
  if grep -qE 'ps[[:space:]]+-eo[[:space:]]+pid,comm,%cpu,%mem[[:space:]]+--sort=-%cpu' <<<"$content" \
     && grep -qE 'head[[:space:]]+-n[[:space:]]+6' <<<"$content"; then ((sect+=1)); fi
  (( sect > 3 )) && sect=3
  raw_sections=$sect

  local has_sleep=0 has_done=0
  grep -qE 'sleep[[:space:]]+5\b' <<<"$content" && has_sleep=1
  grep -qi 'Monitoring complete after' <<<"$content" && has_done=1
  if (( has_sleep==1 && has_done==1 )); then
    raw_sleep5=1
  fi

  # -------- Dynamic content check (reported) --------
  local cmd_out=""
  if [[ "$precheck_ok" == "yes" ]]; then
    cmd_out="$pre_out"
  else
    if [[ -n "$TIMEOUT_CMD" ]]; then
      set +e
      cmd_out="$(sudo -u "$user" $SHELL -lc "cd '$home' && $TIMEOUT_CMD ${PRECHECK_TIMEOUT_SECS}s bash './$SCRIPT_NAME' <<<'${PRECHECK_ITER_INPUT}'" 2>&1)"
      set -e
    else
      set +e
      cmd_out="$(sudo -u "$user" $SHELL -lc "cd '$home' && bash './$SCRIPT_NAME' <<<'${PRECHECK_ITER_INPUT}'" 2>&1)"
      set -e
    fi
  fi
  if grep -qE 'Filesystem|total +used +free|PID +COMMAND' <<<"$cmd_out"; then
    run_ok="yes"
  else
    run_ok="no"
    notes+="No recognizable output; "
  fi

  # -------- Scale to 100 --------
  local pts_prompt=$(( raw_prompt * 10 ))     # 0/20
  local pts_while=$(( raw_while * 10 ))       # 0/20
  local pts_clear=$(( raw_clear * 10 ))       # 0/10
  local pts_date=$(( raw_date * 10 ))         # 0/10
  local pts_sections=$(( raw_sections * 10 )) # 0..30
  local pts_sleep5=$(( raw_sleep5 * 10 ))     # 0/10
  local total=$(( pts_prompt + pts_while + pts_clear + pts_date + pts_sections + pts_sleep5 ))

  echo "Checks:"
  pf "$file_exists" "Script exists"
  pf "$exec_ok"     "Executable bit"
  pf "$(yn_from_pts "$pts_prompt")" "Prompt (-p) (20)" "pts=$pts_prompt"
  pf "$(yn_from_pts "$pts_while")"  "While loop (20)"  "pts=$pts_while"
  pf "$(yn_from_pts "$pts_clear")"  "clear present (10)" "pts=$pts_clear"
  pf "$(yn_from_pts "$pts_date")"   "date present (10)"  "pts=$pts_date"
  echo "  Sections (max 30 pts):"
  pf "$( [[ $raw_sections -ge 1 ]] && echo yes || echo no )" "df -h / (10)" ""
  pf "$( [[ $raw_sections -ge 2 ]] && echo yes || echo no )" "free -h (10)" ""
  pf "$( [[ $raw_sections -ge 3 ]] && echo yes || echo no )" "ps…|head (10)" ""
  printf "  --> Sections points: %d/30\n" "$pts_sections"
  pf "$(yn_from_pts "$pts_sleep5")" "sleep 5 + completion (10)" "pts=$pts_sleep5"

  echo
  pf "$precheck_ok" "Pre-check (exec as student)" "exit=$precheck_exit reason=$precheck_reason"
  pf "$run_ok" "Dynamic run produced expected output"
  echo
  printf "Total points: %d/100\n" "$total"
  [[ -n "$notes" ]] && printf "Notes: %s\n" "$notes"
  echo

  # -------- CSV --------
  local line="$user,$file_exists,$exec_ok,$precheck_ok,$precheck_exit,$precheck_reason,$run_ok,$pts_prompt,$pts_while,$pts_clear,$pts_date,$pts_sections,$pts_sleep5,$total,${notes}"
  echo "$line" >> "$CSV_OUT"
}

if [[ ${#STUDENTS[@]} -eq 0 ]]; then
  echo "no_students_found,no,no,no,0,No students matched regex,no,0,0,0,0,0,0,No students matched regex" >> "$CSV_OUT"
  echo "No students matched; wrote: $CSV_OUT"
  exit 0
fi

for stu in "${STUDENTS[@]}"; do
  grade_one_student "$stu"
done

echo "Wrote grades to: $CSV_OUT"
