#!/bin/bash

mkdir -p /sys/fs/cgroup/net_cls,net_prio/pidrouteusera

echo 0x100010 | tee /sys/fs/cgroup/net_cls,net_prio/pidrouteusera/net_cls.classid

if ! iptables -w -t nat -C POSTROUTING -m cgroup --cgroup 0x100010 -d 127.0.0.0/8 -j SNAT --to-source 127.0.0.111; then
    iptables -w -t nat -A POSTROUTING -m cgroup --cgroup 0x100010 -d 127.0.0.0/8 -j SNAT --to-source 127.0.0.111
fi

cgexec -g net_cls:pidrouteusera \
    pjsua \
  --id sip:a@domain.imsprovider.org \
  --registrar sip:domain.imsprovider.org \
  --realm domain.imsprovider.org \
  --username a@domain.imsprovider.org \
  --password apass \
  --null-audio \
  --auto-answer 180 \
  --add-codec=PCMA/8000 \
  --use-ims \
  --local-port=5566
