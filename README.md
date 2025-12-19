# Single-VM IMS setup with Kamailio and FHoSS for academic purposes

Ana Belén García Hernando. Universidad Politécnica de Madrid. 2025.

If you find any errors or have any comments, please report them to <anabelen.garcia _*at*_ upm.es>

## Main considerations

This is a step-by-step tutorial to setup an IMS scenario with Kamailio CSCFs and FHoSS as HSS, which runs in a single host. 

The following considerations have guided this work:
- The main purpose of this scenario is **academic** (mainly for teaching). Thus, ease of flow graph visualization with Wireshark has been given priority over, e.g., more realistic deployment options.
- For this same reason, on several occasions the version of several of the tools and products used is not the latest, but one for which enough detailed information existed publicly about similar test scenarios. Most probably an equivalent scenario can be reached with newer versions.
- The fact that all elements run in the same (virtual) machine makes it easier to have a portable (and "clonable") solution and also to get a capture file with consistent and causally-ordered traces, useful for teaching purposes.
- In this tutorial, the rationale behind some of the main decisions is explained so that the scenario can more easily evolve to more complex deployments.

## License, credits to external sources and summary of original contributions

The original parts of this tutorial have been generated in the framework of an [educational innovation project](https://innovacioneducativa.upm.es/) funded by [Universidad Politécnica de Madrid](https://www.upm.es/), titled "Aprendizaje inter-asignatura de sistemas telemáticos modernos: redes móviles y voz sobre IP". An Attribution-NonCommercial-ShareAlike 4.0 International CC license ([CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/legalcode.en)) applies except for the external resources used in the case they have to preserve their respective licenses.

The following external resources have served as a guide to several parts of this tutorial:

- Sukchan Lee (Open5GS). "[VoLTE Setup with Kamailio IMS and Open5GS](https://open5gs.org/open5gs/docs/tutorial/02-VoLTE-setup/)" tutorial. Accessed December 18, 2025.

  This tutorial has been the main source for the core configuration of the P-, I- and S-CSCF IMS nodes, as well as for the FHoSS (HSS) and bind9 (DNS) services. For convenience, some information contained in this source is reproduced in this tutorial, sometimes verbatim. For enhance clarity, the reference [SuckanLee2025] is cited near those parts.

- Margarita Garrido Lorenzo. "[Implementación de una plataforma IMS con herramientas open source](https://hdl.handle.net/2117/96677)". Final degree project (Supervisor: José Luis Muñoz Tapia). Universitat Politècnica de Catalunya. 2016.

  This work has served as inspiration and information regarding the use of PJSUA as the IMS User Agent.

- Several free software products are used, amnog them: [Ubuntu](https://ubuntu.com/), [kamailio](https://www.kamailio.org/) (specifically this [branch](https://github.com/herlesupreeth/kamailio) by [Supreeth Herle](https://github.com/herlesupreeth)), [FHoSS](https://github.com/herlesupreeth/FHoSS), and [bind9](https://gitlab.isc.org/isc-projects/bind9).

The following are the main contributions of this tutorial with respect to the used external resources:

- All different functions run in the same hosting machine, but each one generates and consumes traffic using a different loopback IP address (127.0.0.X), avoiding 127.0.0.1 for easier analyses.
- Explicit and detailed configuration of iptables artefacts are included that allow to capture traffic to analyse the main functioning of the IMS system for academic and testing purposes.
- This tutorial deviates from [SuckanLee2025] in several aspects, among them:
  - Different IMS domain (**domain.imsprovider.org**).
  - No EPC (Evolved Packet Core) included, since this is a pure IMS scenario, no VoLTE involved. As a consequence, no Rx interface in place.
  - User Agents are based on PJSUA. No real smartphones.
  - Some other small changes that are documented where applicable.

We have made our best to appropriately cite and respect the authorship and licenses of external sources used. If you feel something has not been properly cited or used, please contact the author.

## Preparation of the (virtual) machine that hosts the scenario

A VM with Ubuntu bionic has served as the base host on which to deploy the scenario. Specifically, a [cloud image for Ubuntu bionic](https://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.img) [^1] has been downloaded and deployed in an Openstack cloud environment, using for it a flavor with 2 vCPUs, 4096 MB RAM and 10 GB disk space, together with this cloud-init yaml file ([SuckanLee2025]) that enables root access with pass "admin":

[^1]: QCow2 UEFI/GPT Bootable disk image.


```yaml
#cloud-config
disable_root: 0
ssh_pwauth: True
users:
  - name: root
chpasswd:
  list: |
    root:admin
  expire: False
runcmd:
  - sed -i -e '/^#PermitRootLogin/s/^.*$/PermitRootLogin yes/' /etc/ssh/sshd_config
  - systemctl restart sshd
```

A non-VM environment or non-Openstack VM with Ubuntu bionic should work equally well with the rest of the tutorial. Whether the host is a VM or a physical host, for convenience it is recommended that the following services are enabled in it, in order to install and manage the scenario from an outside client:

- SSH (to run commands).
- sftp (to copy files to / from the host, e.g. with [filezilla](https://filezilla-project.org/)).

Unless otherwise stated, all commands are run on the host by user root (no sudo), with home directory `/root` .

### Initial configuration and packages to install

Set hostname and timezone:

```bash
root@hostname:~# hostnamectl set-hostname kamailio-bionic
root@kamailio-bionic:~# timedatectl set-timezone Europe/Madrid # use your own timezone
```

Adapt repositories, update, upgrade and install initial packages:

```bash
root@kamailio-bionic:~# # Modify the repositories file as needed in your case, e.g.:

root@kamailio-bionic:~# cat /etc/apt/sources.list
deb https://nova.clouds.archive.ubuntu.com/ubuntu/ bionic main restricted
deb https://nova.clouds.archive.ubuntu.com/ubuntu/ bionic-updates main restricted
deb https://nova.clouds.archive.ubuntu.com/ubuntu/ bionic universe
deb https://nova.clouds.archive.ubuntu.com/ubuntu/ bionic-updates universe
deb https://nova.clouds.archive.ubuntu.com/ubuntu/ bionic multiverse
deb https://nova.clouds.archive.ubuntu.com/ubuntu/ bionic-updates multiverse
deb https://nova.clouds.archive.ubuntu.com/ubuntu/ bionic-backports main restricted universe multiverse
deb https://security.ubuntu.com/ubuntu bionic-security main restricted
deb https://security.ubuntu.com/ubuntu bionic-security universe
deb https://security.ubuntu.com/ubuntu bionic-security multiverse

root@kamailio-bionic:~# # Install packages [SuckanLee2025]:

root@kamailio-bionic:~# apt update && apt upgrade -y && apt install -y mysql-server tcpdump screen ntp ntpdate git-core dkms gcc flex bison libmysqlclient-dev make libssl-dev libcurl4-openssl-dev libxml2-dev libpcre3-dev bash-completion g++ autoconf rtpproxy libmnl-dev libsctp-dev ipsec-tools libradcli-dev libradcli4
```

Include these directories in `PATH` variable, so that further steps work:


```bash
root@kamailio-bionic:~# echo $PATH
/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin
```

## Download, compile and install kamailio

Source information for this section: [SuckanLee2025].

Checkout the kamailio branch that will serve as the basis for all the IMS CSCFs and generate build config files (Call State Control Functions):

```bash
mkdir -p /usr/local/src/
cd /usr/local/src/
git clone https://github.com/herlesupreeth/kamailio
cd kamailio/
git checkout 5.3
make cfg
```

Modify `/usr/local/src/kamailio/src/modules.lst` so that it contains the modules to be compiled:

```
# this file is autogenerated by make modules-cfg

# the list of sub-directories with modules
modules_dirs:=modules

# the list of module groups to compile
cfg_group_include=

# the list of extra modules to compile
include_modules= cdp cdp_avp db_mysql dialplan ims_auth ims_charging ims_dialog ims_diameter_server ims_icscf ims_ipsec_pcscf ims_isc ims_ocs ims_qos ims_registrar_pcscf ims_registrar_scscf ims_usrloc_pcscf ims_usrloc_scscf outbound presence presence_conference presence_dialoginfo presence_mwi presence_profile presence_reginfo presence_xml pua pua_bla pua_dialoginfo pua_reginfo pua_rpc pua_usrloc pua_xmpp sctp tls utils xcap_client xcap_server xmlops xmlrpc

# the list of static modules
static_modules=

# the list of modules to skip from compile list
skip_modules=

# the list of modules to exclude from compile list
exclude_modules= acc_json acc_radius app_java app_lua app_lua_sr app_mono app_perl app_python app_python3 app_ruby auth_ephemeral auth_identity auth_radius cnxcc cplc crypto db2_ldap db_berkeley db_cassandra db_mongodb db_oracle db_perlvdb db_postgres db_redis db_sqlite db_unixodbc dnssec erlang evapi geoip geoip2 gzcompress h350 http_async_client http_client jansson janssonrpcc json jsonrpcc kafka kazoo lcr ldap log_systemd lost memcached misc_radius ndb_cassandra ndb_mongodb ndb_redis nsq osp peering phonenum pua_json rabbitmq regex rls rtp_media_server snmpstats systemdops topos_redis uuid websocket xhttp_pi xmpp $(skip_modules)

modules_all= $(filter-out modules/CVS,$(wildcard modules/*))
modules_noinc= $(filter-out $(addprefix modules/, $(exclude_modules) $(static_modules)), $(modules_all)) 
modules= $(filter-out $(modules_noinc), $(addprefix modules/, $(include_modules) )) $(modules_noinc) 
modules_configured:=1
```

Compile and install kamailio:
```bash
export RADCLI=1
make Q=0 all | tee make_all.txt
make install | tee make_install.txt
ldconfig
```

Modify `/usr/local/etc/kamailio/kamctlrc` so that the following domain and dbengine are specified:
```
## your SIP domain
SIP_DOMAIN=domain.imsprovider.org
# (...)
# If you want to setup a database with kamdbctl, you must at least specify
# this parameter.
DBENGINE=MYSQL
```



## Create PCSCF, SCSCF and ICSCF databases


> Note: the files to use when creating these databases are specified in the corresponding `README.md` files inside `etc/kamailio_scsf`, `/etc/kamailio_pcscf` and `/etc/kamailio_icscf`._








## Build and install PJSUA user agent

```bash
apt-get update
apt install python3-dev gcc make binutils build-essential
wget https://github.com/pjsip/pjproject/archive/refs/tags/2.14.tar.gz
tar xvf 2.14.tar.gz
cd pjproject-2.14/
export CFLAGS="$CFLAGS -fPIC"
./configure && make dep && make
cp pjsip-apps/bin/pjsua* /usr/local/bin/pjsua
```


> Note: _Complete information on the parameters in [Core Cookbook for Kamailio SIP Server v5.3.x (stable)](https://www.kamailio.org/wikidocs/cookbooks/5.3.x/core/)_.





```bash

```


```

```
