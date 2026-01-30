#!/bin/bash

pidfiles=("/var/run/kamailio_pcscf1/kamailio_pcscf1.pid" "/var/run/kamailio_scscf1/kamailio_scscf1.pid" "/var/run/kamailio_icscf/kamailio_icscf.pid")
configfiles=("/etc/kamailio_pcscf/kamailio_pcscf1.cfg" "/etc/kamailio_scscf/kamailio_scscf1.cfg" "/etc/kamailio_icscf/kamailio_icscf.cfg")
cgroupnames=("pidroutepcscf1" "pidroutescscf1" "pidrouteicscf")
classids=("0x100001" "0x100002" "0x100003")
ipaddresses=("127.0.0.33" "127.0.0.11" "127.0.0.55")

len_pidfiles=${#pidfiles[@]}
len_configfiles=${#configfiles[@]}
len_cgroupnames=${#cgroupnames[@]}
len_classids=${#classids[@]}
len_ipaddresses=${#ipaddresses[@]}

if (( len_pidfiles != len_configfiles || len_pidfiles != len_cgroupnames || len_pidfiles != len_classids || len_pidfiles != len_ipaddresses )); then
  echo "Error: arrays must have equal lengths, edit this file to correct it." >&2
  exit 1
fi
