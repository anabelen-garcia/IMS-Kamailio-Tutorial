#!/bin/bash

THISDIR="$(readlink -f "$(dirname -- ${BASH_SOURCE[0]})")" # Directory where this script is located; it is assumed all scripts are in the same directory

"$THISDIR"/stop_hss.sh &
sleep 5
"$THISDIR"/stop_cscfs.sh &