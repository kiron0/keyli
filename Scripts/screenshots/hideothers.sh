#!/bin/zsh
mode=$1; list=$2
while IFS= read -r app; do
  [ -z "$app" ] && continue
  [ "$app" = "Keyli" ] && continue
  if [ "$mode" = "hide" ]; then v=false; else v=true; fi
  osascript -e "tell application \"System Events\" to set visible of process \"$app\" to $v" >/dev/null 2>&1
done < "$list"
