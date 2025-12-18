#!/bin/bash
set -x

source ./common.sh

for ((i=0; i<len_pidfiles; i++)); do

        PIDFILE="${pidfiles[i]}"
        PIDDIR="$(dirname "$PIDFILE")"
        CONFIGFILE="${configfiles[i]}"
        CGROUPNAME="${cgroupnames[i]}"
        CGROUPDIR=/sys/fs/cgroup/net_cls,net_prio/"$CGROUPNAME"
        CLASSID="${classids[i]}"
        IPADDRESS="${ipaddresses[i]}"

        #create the cgroup directory if it does not exist yet and establish the classid for this cgroup:
        mkdir -p "$CGROUPDIR"
        echo "$CLASSID" | tee "$CGROUPDIR"/net_cls.classid

        #establish the SNAT rule so that all traffic coming from this process and with a loopback destination address has its origin changed to IPADDRESS:
        if ! iptables -w -t nat -C POSTROUTING -m cgroup --cgroup "$CLASSID" -d 127.0.0.0/8 -j SNAT --to-source "$IPADDRESS"; then
            iptables -w -t nat -A POSTROUTING -m cgroup --cgroup "$CLASSID" -d 127.0.0.0/8 -j SNAT --to-source "$IPADDRESS"
        fi

        #run the process, creating first the PID directory if it does not exist yet:
        mkdir -p "$PIDDIR"
        cgexec -g net_cls:"$CGROUPNAME" kamailio -f "$CONFIGFILE" -P "$PIDFILE" -DD -E -e &
        sleep 5

done

