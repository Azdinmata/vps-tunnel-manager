#!/bin/bash
# ==============================================================================
# AUTO-CLEANER CRON TASK FOR EXPIRED ACCOUNTS (SKIPS LIFETIME 0 DAYS)
# Location: scripts/auto-cleaner.sh
# ==============================================================================

TODAY=$(date +%s)
for user in $(awk -F: '$3 >= 1000 {print $1}' /etc/passwd); do
  EXP=$(chage -l "$user" | grep "Account expires" | cut -d: -f2)
  if [ "$EXP" != " never" ] && [ -n "$EXP" ]; then
    EXPS=$(date -d "$EXP" +%s 2>/dev/null)
    if [ -n "$EXPS" ] && [ "$EXPS" -le "$TODAY" ]; then
      userdel -f "$user"
    fi
  fi
done
