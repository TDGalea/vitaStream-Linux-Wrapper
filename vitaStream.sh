#!/bin/bash
device="/dev/video0" # Video device to use. You'll need to figure this out yourself & edit this line accordingly.
# If you're on a laptop or otherwise have a webcam, you very likely will need to do so.
title="VitaStream" # Title used in notifications.
icon="/usr/share/icons/vita-white.ico" # Icon to use in notifications.
notify="notify-send -a $title -i $icon" # notify-send formatting.
lockfile="/tmp/.VitaStream.lock" # File used to identify whether a watcher is already running.
mplayer='mplayer tv:// -tv driver=v4l2:device='$device':width=960:height=544 -title '$title # mplayer command string.

# We need to clear up the lockfile on exit.
trap 'quit' SIGHUP SIGINT SIGTERM
function quit {
	rm "$lockfile"
	$notify "$title stopped."
	exit 0
}

# Exit if no mode passed.
[[ -z $1 ]] && printf "Need to know whether to stream now or become watcher.\n($0 [stream/watcher])" >&2 && exit 3

if [[ "$1" = "watcher" ]]; then # Watcher mode.
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