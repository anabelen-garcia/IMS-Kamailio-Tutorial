#!/bin/bash
set -x
/root/scripts/stop_hss.sh &
sleep 5
/root/scripts/stop_cscfs.sh &
/root/scripts/start_cscfs.sh &
/root/scripts/hss.sh &
