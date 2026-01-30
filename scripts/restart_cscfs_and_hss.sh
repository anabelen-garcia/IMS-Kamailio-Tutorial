#!/bin/bash

THISDIR="$(readlink -f "$(dirname -- ${BASH_SOURCE[0]})")" # Directory where this script is located; it is assumed all scripts are in the same directory

"$THISDIR"/stop_hss.sh &
echo Sleeping for 5 seconds after stopping HSS...
sleep 5
"$THISDIR"/stop_cscfs.sh &
echo Sleeping for 10 seconds after stopping CSCFs...
sleep 10
echo Starting CSCFs and HSS...
"$THISDIR"/start_cscfs.sh &
"$THISDIR"/hss.sh &


# /root/scripts/stop_hss.sh &
# sleep 5
# /root/scripts/stop_cscfs.sh &
# /root/scripts/start_cscfs.sh &
# /root/scripts/hss.sh &
