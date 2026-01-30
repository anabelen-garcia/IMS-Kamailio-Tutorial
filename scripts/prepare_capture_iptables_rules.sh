#!/bin/bash

ruleinit=(iptables -w -t mangle)
rule1=(OUTPUT -m iprange --src-range 127.0.0.2-127.255.255.255 -m iprange --dst-range 127.0.0.2-127.255.255.255 -j MARK --set-mark 0x11)
rule2=(OUTPUT -m mark --mark 0x11 -j NFLOG --nflog-group 11)
rule3=(INPUT -m iprange --src-range 127.0.0.2-127.255.255.255 -m iprange --dst-range 127.0.0.2-127.255.255.255 -m mark ! --mark 0x11 -j NFLOG --nflog-group 11)

if ! "${ruleinit[@]}" -C "${rule1[@]}"; then
    "${ruleinit[@]}" -A "${rule1[@]}"
fi

if ! "${ruleinit[@]}" -C "${rule2[@]}"; then
    "${ruleinit[@]}" -A "${rule2[@]}"
fi

if ! "${ruleinit[@]}" -C "${rule3[@]}"; then
    "${ruleinit[@]}" -A "${rule3[@]}"
fi

echo "To start a capture, run \"dumpcap -i nflog:11 -w filename.pcap\""

