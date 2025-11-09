#!/usr/bin/env bash
# system_monitor_selfcheck
# Run this as a regular user. Checks ONLY ~/system_monitor.sh
# Rubric (100 pts):
#  - Prompt (-p): 20
#  - While loop: 20
#  - clear present: 10
#  - date present: 10
#  - Sections: df -h / (10) + free -h (10) + ps…|head (10) => 30
#  - sleep 5 + completion: 10
# Pre-check (1 iteration) reported; not scored.

set -u  # no -e; don't crash on partial work

SCRIPT="$HOME/system_monitor.sh"
SHELL="/bin/bash"
TIMEOUT_CMD="$(command -v timeout || true)"
PRECHECK_ITER_INPUT="1"
PRECHECK_TIMEOUT_SECS=10

pf() { local ok="${1:-no}" lbl="${2:-}" extra="${3:-}"; [[ "$ok" == "yes" || "$ok" == "1" ]] && printf "  [OK]  %-32s %s\n" "$lbl" "$extra" || printf "  [..]  %-32s %s\n" "$lbl" "$extra"; }
yn_from_pts(){ local n="${1:-0}"; (( n>0 )) && echo yes || echo no; }

echo "Self-check for: $(whoami)"
echo "Home dir:       $HOME"
echo "Script:         $SCRIPT"
echo

if [[ ! -f "$SCRIPT" ]]; then
  echo "Result: script not found. Create $SCRIPT from the starter template and try again."
  exit 0
fi
[[ -x "$SCRIPT" ]] || chmod +x "$SCRIPT" 2>/dev/null || true

# Pre-check run once with input "1"
precheck_ok="no"; precheck_exit=0; precheck_reason=""; pre_out=""; pre_rc=0
if [[ -n "$TIMEOUT_CMD" ]]; then
  pre_out="$($TIMEOUT_CMD ${PRECHECK_TIMEOUT_SECS}s bash "$SCRIPT" <<<'1' 2>&1)"; pre_rc=$?
  if (( pre_rc==124 )); then precheck_ok="no"; precheck_exit=$pre_rc; precheck_reason="timeout ${PRECHECK_TIMEOUT_SECS}s"
  elif (( pre_rc==0 )); then precheck_ok="yes"; precheck_exit=$pre_rc; precheck_reason="success"
  else precheck_ok="no"; precheck_exit=$pre_rc; precheck_reason="exit $pre_rc"; fi
else
  pre_out="$(bash "$SCRIPT" <<<'1' 2>&1)"; pre_rc=$?
  if (( pre_rc==0 )); then precheck_ok="yes"; precheck_exit=$pre_rc; precheck_reason="success"
  else precheck_ok="no"; precheck_exit=$pre_rc; precheck_reason="exit $pre_rc"; fi
fi

# Static checks
content="$(sed -e 's/[[:space:]]\+$//' "$SCRIPT")"
raw_prompt=0; raw_while=0; raw_clear=0; raw_date=0; raw_sections=0; raw_sleep5=0

grep -qE 'read[[:space:]]+-p' <<<"$content" && raw_prompt=2
grep -qE '^while \[ "\$COUNT" -le "\$RUNS" \]$' <<<"$content" && raw_while=2
grep -qE '^[[:space:]]*clear([[:space:]]+.*)?$' <<<"$content" && raw_clear=1
grep -qE '^[[:space:]]*[^#[:space:]].*\bdate\b' <<<"$content" && raw_date=1

sect=0
grep -qE 'df[[:space:]]+-h[[:space:]]+/' <<<"$content" && ((sect+=1))
grep -qE '\bfree[[:space:]]+-h\b' <<<"$content" && ((sect+=1))
grep -qE 'ps[[:space:]]+-eo[[:space:]]+pid,comm,%cpu,%mem[[:space:]]+--sort=-%cpu' <<<"$content" \
  && grep -qE 'head[[:space:]]+-n[[:space:]]+6' <<<"$content" && ((sect+=1))
(( sect>3 )) && sect=3
raw_sections=$sect

has_sleep=0; has_done=0
grep -qE 'sleep[[:space:]]+5\b' <<<"$content" && has_sleep=1
grep -qi 'Monitoring complete after' <<<"$content" && has_done=1
(( has_sleep==1 && has_done==1 )) && raw_sleep5=1

# Dynamic content check (feedback only)
run_ok="no"
cmd_out="$pre_out"
grep -qE 'Filesystem|total +used +free|PID +COMMAND' <<<"$cmd_out" && run_ok="yes"

# Scale to 100
pts_prompt=$(( raw_prompt * 10 ))     # 0/20
pts_while=$(( raw_while * 10 ))       # 0/20
pts_clear=$(( raw_clear * 10 ))       # 0/10
pts_date=$(( raw_date * 10 ))         # 0/10
pts_sections=$(( raw_sections * 10 )) # 0..30
pts_sleep5=$(( raw_sleep5 * 10 ))     # 0/10
total=$(( pts_prompt + pts_while + pts_clear + pts_date + pts_sections + pts_sleep5 ))

echo "Checks:"
pf "$( [[ -f "$SCRIPT" ]] && echo yes || echo no )" "Script exists"
pf "$( [[ -x "$SCRIPT" ]] && echo yes || echo no )" "Executable bit"
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
pf "$precheck_ok" "Pre-check run (1 iteration)" "exit=$precheck_exit reason=$precheck_reason"
pf "$run_ok" "Output looked like a system report"
echo
printf "Estimated score: %d/100\n" "$total"
echo
echo "Tip: If pre-check failed, try: bash \"$SCRIPT\""
