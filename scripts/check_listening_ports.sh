#!/bin/bash

ports=("5060" "6060" "4060" "3868" "8080" "2223" "53" "5566" "5577") # adapt to your deployment's ports if necessary

lenports=${#ports[@]}

command="ss -tuln | grep -e Address:Port"
info_searched_ports="Looking for ports:"

for ((i=0; i<lenports; i++)); do
    #command+=" -e \"LISTEN[[:print:]]\+:${ports[i]}[[:blank:]]\""
    command+=" -e \":${ports[i]}[[:blank:]]\""
    info_searched_ports+=" ${ports[i]}"
done

echo
echo "$info_searched_ports"
echo
eval "$command"
echo
