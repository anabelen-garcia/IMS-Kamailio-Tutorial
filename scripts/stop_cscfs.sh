#!/bin/bash
set -x

source ./common.sh

for ((i=0; i<len_pidfiles; i++)); do
        PIDFILE="${pidfiles[i]}"

        #if process running, terminate it and delete the PID file:
        if [ -f "$PIDFILE" ]; then
        kill $(cat "$PIDFILE") 2>/dev/null
        sleep 3
        rm -f "$PIDFILE"
        fi
done
