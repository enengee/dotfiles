#!/bin/bash

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

WINDOW_SIDES="$HOME/.local/bin/window-sides"
[ -x "$WINDOW_SIDES" ] || exit 1

snapshot() {
  aerospace eval "list-windows --focused --format 'F %{window-id}'; list-windows --workspace focused --format 'W %{window-id} %{window-layout} %{window-is-fullscreen} %{app-pid}'" 2>/dev/null
}

parse_snapshot() {
  focused=""
  tiling_ids=()
  fullscreen_ids=()
  hidden_pids=()
  native_fullscreen_ids=()
  local tag id layout is_fullscreen pid
  while read -r tag id layout is_fullscreen pid; do
    case "$tag" in
    F) focused=$id ;;
    W)
      case "$layout" in
      h_tiles | v_tiles | h_accordion | v_accordion)
        tiling_ids+=("$id")
        [ "$is_fullscreen" = true ] && fullscreen_ids+=("$id")
        ;;
      macos_native_window_of_hidden_app) hidden_pids+=("$pid") ;;
      macos_native_fullscreen) native_fullscreen_ids+=("$id") ;;
      esac
      ;;
    esac
  done <<<"$1"
}

shuffle() {
  local i j tmp
  for ((i = ${#pool[@]} - 1; i > 0; i--)); do
    j=$((RANDOM % (i + 1)))
    tmp=${pool[i]}
    pool[i]=${pool[j]}
    pool[j]=$tmp
  done
}

append_column() {
  local count=$#
  local members=("$@")
  if [ "$count" -ge 3 ]; then
    order+=("${members[0]}" "${members[count - 1]}" "${members[@]:1:count-2}")
  else
    order+=("$@")
  fi
}

build_column() {
  local start=$1 count=$2 j
  [ "$count" -ge 2 ] || return 0
  cmds+="join-with --window-id ${order[start]} right; "
  for ((j = start + 2; j < start + count; j++)); do
    cmds+="move --window-id ${order[j]} left; "
  done
  cmds+="layout --window-id ${order[start]} v_accordion; "
}

exec 3< <("$WINDOW_SIDES" | sort -k3,3n -k4,4n)
parse_snapshot "$(snapshot)"

if [ ${#hidden_pids[@]} -gt 0 ] || [ ${#native_fullscreen_ids[@]} -gt 0 ]; then
  if [ ${#hidden_pids[@]} -gt 0 ]; then
    osascript -l JavaScript -e 'ObjC.import("AppKit");
      function run(argv) {
        argv.forEach(function (pid) {
          var app = $.NSRunningApplication.runningApplicationWithProcessIdentifier(Number(pid));
          if (app) app.unhide;
        });
      }' "${hidden_pids[@]}" >/dev/null 2>&1
  fi
  if [ ${#native_fullscreen_ids[@]} -gt 0 ]; then
    cmds=""
    for id in "${native_fullscreen_ids[@]}"; do
      cmds+="macos-native-fullscreen off --window-id $id; "
    done
    aerospace eval "$cmds" >/dev/null 2>&1
  fi
  original_focused=$focused
  for _ in $(seq 100); do
    sleep 0.02
    parse_snapshot "$(snapshot)"
    [ ${#hidden_pids[@]} -eq 0 ] && [ ${#native_fullscreen_ids[@]} -eq 0 ] && break
  done
  focused=$original_focused
  exec 3< <("$WINDOW_SIDES" | sort -k3,3n -k4,4n)
fi

n=${#tiling_ids[@]}
[ "$n" -gt 0 ] || exit 0

cmds=""
for id in ${fullscreen_ids[@]+"${fullscreen_ids[@]}"}; do
  cmds+="fullscreen off --window-id $id; "
done
cmds+="flatten-workspace-tree; layout --root h_tiles; "

if [ "$n" -ge 2 ]; then
  left=()
  right=()
  pool=()
  unseen=" ${tiling_ids[*]} "
  while read -r id side _; do
    case "$unseen" in
    *" $id "*) unseen=${unseen/ $id / } ;;
    *) continue ;;
    esac
    case "$side" in
    L) left+=("$id") ;;
    R) right+=("$id") ;;
    *) pool+=("$id") ;;
    esac
  done <&3
  for id in $unseen; do pool+=("$id"); done

  shuffle
  for id in ${pool[@]+"${pool[@]}"}; do
    if [ ${#left[@]} -lt ${#right[@]} ] || { [ ${#left[@]} -eq ${#right[@]} ] && [ $((RANDOM % 2)) -eq 0 ]; }; then
      left+=("$id")
    else
      right+=("$id")
    fi
  done

  if [ ${#left[@]} -eq 0 ] || [ ${#right[@]} -eq 0 ]; then
    members=(${left[@]+"${left[@]}"} ${right[@]+"${right[@]}"})
    pool=()
    for ((i = 0; i < n; i++)); do pool+=("$i"); done
    shuffle
    moving=" ${pool[*]:0:n/2} "
    stay=()
    move=()
    for ((i = 0; i < n; i++)); do
      case "$moving" in
      *" $i "*) move+=("${members[i]}") ;;
      *) stay+=("${members[i]}") ;;
      esac
    done
    if [ ${#left[@]} -eq 0 ]; then
      left=("${move[@]}")
      right=("${stay[@]}")
    else
      left=("${stay[@]}")
      right=("${move[@]}")
    fi
  fi

  order=()
  append_column ${left[@]+"${left[@]}"}
  append_column ${right[@]+"${right[@]}"}

  for id in "${order[@]}"; do
    for ((k = 1; k < n; k++)); do
      cmds+="move --window-id $id --boundaries-action stop right; "
    done
  done

  build_column 0 ${#left[@]}
  build_column ${#left[@]} ${#right[@]}
fi

cmds+="balance-sizes"
[ -n "$focused" ] && cmds+="; focus --window-id $focused"

exec aerospace eval "$cmds" 2>/dev/null 3<&-
