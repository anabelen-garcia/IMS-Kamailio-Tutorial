#!/bin/bash

THISDIR="$(readlink -f "$(dirname -- ${BASH_SOURCE[0]})")" # Directory where this script is located; it is assumed all scripts are in the same directory

source "$THISDIR"/common_cscfs.sh

for ((i=0; i<len_pidfiles; i++)); do
        PIDFILE="${pidfiles[i]}"

        #if process running, terminate it and delete the PID file:
        if [ -f "$PIDFILE" ]; then
        kill $(cat "$PIDFILE") 2>/dev/null
        sleep 3
        rm -f "$PIDFILE"
        fi
done

pkill -e kamailio
