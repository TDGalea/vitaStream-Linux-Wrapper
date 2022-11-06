#!/bin/bash
device="/dev/video0" # Video device to use. You'll need to figure this out yourself & edit this line accordingly.
# If you're on a laptop or otherwise have a webcam, you very likely will need to do so.
title="VitaStream" # Title used in notifications.
# icon="/usr/share/icons/vita-white.ico" # Icon to use in notifications. Uncomment if you want to use one.
# notify="notify-send -a $title -i $icon" # notify-send formatting, with icon. Uncomment this line and comment the one below if you want to use.
notify="notify-send -a $title" # notify-send formatting, without icon. Uncomment this line and comment the one above if you want to use.
lockfile="/tmp/.VitaStream.lock" # File used to identify whether a watcher is already running.
mplayer='mplayer tv:// -tv driver=v4l2:device='$device':width=960:height=544 -title '$title # mplayer command string.

# Watcher needs to clear up the lockfile on exit.
function quit {
	[[ -f "$lockfile" ]] && rm "$lockfile"
	$notify "$title watcher stopped."
	exit 0
}

# Dependancy check.
depMissing=0
if ! hash mplayer 2>/dev/null; then printf "Missing dependancy: mplayer\n"; let depMissing+=1; fi
if ! hash notify-send 2>/dev/null; then printf "Missing dependancy: notify-send\n"; let depMissing+=1; fi
if ! hash lsusb 2>/dev/null; then printf "Missing dependancy: lsusb\n"; let depMissing+=1; fi
if [[ $depMissing -gt 0 ]]; then
	printf "Please install missing dependancies and launch again.\n"
	if hash notify-send 2>/dev/null; then $notify "Missing dependancies.
Run from command line to check."; fi
	exit 8
fi

# Exit if no mode passed.
[[ -z $1 ]] && printf "Need to know whether to stream now or become watcher.\n($0 [stream/watcher])\n" >&2 && exit 3

if [[ "$1" = "watcher" ]]; then # Watcher mode.
	trap 'quit' SIGHUP SIGINT SIGTERM # Watcher needs to clear up the lockfile on exit.
	[[ -f "$lockfile" ]] && printf "$title watcher already running! Kill the other one first.\nIf you're certain this isn't the case, remove file $lockfile.\n" >&2 && exit 1
	touch "$lockfile"
	detected=0
	$notify "$title watcher started."

	while true; do
		streamNow=n
		if [[ "$(lsusb|grep PSVita)" ]]; then # Vita detected.
			if [[ $detected -eq 0 ]]; then # Check it wasn't already detected previous loop.
				detected=1
				streamNow=`$notify -A y=Yes -A n=No "PS Vita detected.
Start stream now?"`
				[[ "$streamNow" = "y" ]] && $0 stream & # Begin the stream - launch self with "stream" parameter.
			fi
			sleep 0.5
		else # Not detected.
			if [[ $detected -eq 1 ]]; then # Notify if first occurance.
				detected=0
				$notify "PS Vita disconnected."
				kill `xprop -name "VitaStream" _NET_WM_PID | awk '{print $3}'` # Kill an existing stream.
			fi
			sleep 2
		fi
	done
elif [[ "$1" = "stream" ]]; then # Stream mode.
	if [[ "$(lsusb|grep PSVita)" ]]; then # Vita detected - begin the stream.
		$mplayer
		exit $?
	else # No Vita detected. Exit.
		$notify "PS Vita not detected.
Check connection and power, then try again."
		exit 2
	fi
else # Invalid mode specified.
	printf "'$1' is not a valid mode.\nOptions are 'stream' or 'watcher'\n" >&2
	exit 3
fi

# We shouldn't end up here.
printf "Reached end of file. How?\n" >&2
exit 9
