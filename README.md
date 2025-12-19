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

The parameters chosen for the scenario are:
- One IMS domain (**domain.imsprovider.org**) with one PCSCF (named PCSCF1 to add others in the future more easily), one SCSCF (named SCSCF1 to add others in the future more easily) and one ICSCF.
- IP addresses and ports:
  - PCSCF1: 127.0.0.33, listens on 5060 port for SIP signaling.
  - SCSCF1: 127.0.0.11, listens on port 6060 for SIP signaling.
  - ICSCF: 127.0.0.55, listens on port 4060 for SIP signaling.
  - HSS: 127.0.0.77, listens on port 3868 for DIAMETER signaling.
    - The Tomcat server to access HSS's web interface, though, listens on all addresses (0.0.0.0), port 8080, so that it can be accessed from outside the host.
  - DNS server: 127.0.0.66, listens on port 53.
  - RTP engine: 127.0.0.88, listens on port 2223.
  - IMS user agents: 127.0.0.111 and 127.0.0.222

## License, credits to external sources and summary of original contributions

The original parts of this tutorial have been generated in the framework of an [educational innovation project](https://innovacioneducativa.upm.es/) funded by [Universidad Politécnica de Madrid](https://www.upm.es/), titled "Aprendizaje inter-asignatura de sistemas telemáticos modernos: redes móviles y voz sobre IP". An Attribution-NonCommercial-ShareAlike 4.0 International CC license ([CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/legalcode.en)) applies except for the external resources used in the case they have to preserve their respective licenses.

The following external resources have served as a guide to several parts of this tutorial:

- Sukchan Lee (Open5GS). "[VoLTE Setup with Kamailio IMS and Open5GS](https://open5gs.org/open5gs/docs/tutorial/02-VoLTE-setup/)" tutorial. Accessed December 18, 2025.

  This tutorial has been the main source for the core configuration of the P-, I- and S-CSCF IMS nodes, as well as for the FHoSS (HSS) and bind9 (DNS) services. For convenience, some information contained in this source is reproduced in this tutorial, sometimes verbatim. For enhance clarity, the reference [SuckanLee2025] is cited near those parts.

- Margarita Garrido Lorenzo. "[Implementación de una plataforma IMS con herramientas open source](https://hdl.handle.net/2117/96677)". Final degree project (Supervisor: José Luis Muñoz Tapia). Universitat Politècnica de Catalunya. 2016.

  This work has served as inspiration and information regarding the use of PJSUA as the IMS User Agent.

- Several free software products are used, amnog them: [Ubuntu](https://ubuntu.com/), [kamailio](https://www.kamailio.org/) (specifically this [branch](https://github.com/herlesupreeth/kamailio) by [Supreeth Herle](https://github.com/herlesupreeth)), [FHoSS](https://github.com/herlesupreeth/FHoSS), and [bind9](https://gitlab.isc.org/isc-projects/bind9).

The following are the main contributions of this tutorial with respect to the used external resources:

- All different functions run in the same hosting machine, but each one generates and consumes traffic using a different loopback IP address (127.0.0.X), avoiding 127.0.0.1 in most cases (except for mysql database) for easier traffic analyses.
- Explicit and detailed configuration of iptables artefacts are included that allow to capture traffic to analyse the main functioning of the IMS system for academic and testing purposes.
- This tutorial deviates from [SuckanLee2025] in several aspects, among them:
  - Different IMS domain (**domain.imsprovider.org**) and some nodes' names to be able to upgrade the scenario in the future more easily.
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

### Create and persist the loopback addresses needed for the different functions

Modify `/etc/rc.local` file in the fllowing manner:

```bash
root@kamailio-bionic:~# cat /etc/rc.local
#!/bin/bash
ip address add 127.0.0.11/8 dev lo
ip address add 127.0.0.33/8 dev lo
ip address add 127.0.0.55/8 dev lo
ip address add 127.0.0.66/8 dev lo
ip address add 127.0.0.77/8 dev lo
ip address add 127.0.0.88/8 dev lo
ip address add 127.0.0.111/8 dev lo
ip address add 127.0.0.222/8 dev lo
exit 0

root@kamailio-bionic:~# chmod +x /etc/rc.local
```



## Download, compile and install kamailio

> Note: _Source information for this section: [SuckanLee2025]._

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

## Download and adapt configuration files for PCSCF, SCSCF and ICSCF nodes

> Note: _Section adapted from [SuckanLee2025] to match this tutorial's CSCF names and other parameters, and to specify the detail of the changes made to the configuration files._

```bash
git clone https://github.com/herlesupreeth/Kamailio_IMS_Config
cd Kamailio_IMS_Config/
git checkout 5.3
cp -r kamailio_icscf /etc
cp -r kamailio_pcscf /etc
cp -r kamailio_scscf /etc
```

Before modifying the files, a backup is done for each directory, so that the following folders exist in `/etc/`:

```
kamailio_icscf
kamailio_icscf.BACKUP
kamailio_pcscf
kamailio_pcscf.BACKUP
kamailio_scscf
kamailio_scscf.BACKUP
```

In the following, the modifications made in the files are specified by using the output of the `diff` tool, so that only the changes are shown.

### Modification of SCSCF1 files

#### kamailio_scscf1.cfg

```
root@kamailio-bionic:/etc# diff kamailio_scscf.BACKUP/kamailio_scscf.cfg kamailio_scscf/kamailio_scscf1.cfg
35c35
< include_file "scscf.cfg"
---
> include_file "scscf1.cfg"
48c48
< listen=tcp:127.0.0.1:6060
---
> listen=tcp:127.0.0.11:6060
101c101
< system.service = "Serving-CSCF" desc "Function of this server"
---
> system.service = "Serving-CSCF1" desc "Function of this server1"
195c195
< modparam("jsonrpcs", "fifo_name", "/var/run/kamailio_scscf/kamailio_rpc.fifo")
---
> modparam("jsonrpcs", "fifo_name", "/var/run/kamailio_scscf1/kamailio_rpc.fifo")
197c197
< modparam("jsonrpcs", "dgram_socket", "/var/run/kamailio_scscf/kamailio_rpc.sock")
---
> modparam("jsonrpcs", "dgram_socket", "/var/run/kamailio_scscf1/kamailio_rpc.sock")
200c200
< modparam("ctl", "binrpc", "unix:/var/run/kamailio_scscf/kamailio_ctl")
---
> modparam("ctl", "binrpc", "unix:/var/run/kamailio_scscf1/kamailio_ctl")
242c242
< modparam("cdp","config_file","/etc/kamailio_scscf/scscf.xml")
---
> modparam("cdp","config_file","/etc/kamailio_scscf/scscf1.xml")
```

#### scscf1.xml

```
root@kamailio-bionic:/etc# diff kamailio_scscf.BACKUP/scscf.xml kamailio_scscf/scscf1.xml
3,4c3,4
<       FQDN="scscf.ims.mnc001.mcc001.3gppnetwork.org"
<       Realm="ims.mnc001.mcc001.3gppnetwork.org"
---
>       FQDN="scscf1.domain.imsprovider.org"
>       Realm="domain.imsprovider.org"
17c17
<       <Peer FQDN="hss.ims.mnc001.mcc001.3gppnetwork.org" Realm="ims.mnc001.mcc001.3gppnetwork.org" port="3868"/>
---
>       <Peer FQDN="hss.domain.imsprovider.org" Realm="domain.imsprovider.org" port="3868"/>
19c19
<       <Acceptor port="3870" bind="10.4.128.21"/>
---
>       <Acceptor port="3870" bind="127.0.0.11"/>
35c35
<       <DefaultRoute FQDN="hss.ims.mnc001.mcc001.3gppnetwork.org" metric="10"/>
---
>       <DefaultRoute FQDN="hss.domain.imsprovider.org" metric="10"/>
```

#### scscf1.cfg

```
root@kamailio-bionic:/etc# diff kamailio_scscf.BACKUP/scscf.cfg kamailio_scscf/scscf1.cfg
2c2,3
< listen=udp:10.4.128.21:6060
---
> listen=udp:127.0.0.11:6060
> #listen=udp:10.4.128.21:6060
5c6,7
< listen=tcp:10.4.128.21:6060
---
> listen=tcp:127.0.0.11:6060
> #listen=tcp:10.4.128.21:6060
10,14c12,16
< #!define NETWORKNAME "ims.mnc001.mcc001.3gppnetwork.org"
< #!define NETWORKNAME_ESC "ims\.mnc001\.mcc001\.3gppnetwork\.org"
< #!define HOSTNAME "scscf.ims.mnc001.mcc001.3gppnetwork.org"
< #!define HOSTNAME_ESC "scscf\.ims\.mnc001\.mcc001\.3gppnetwork\.org"
< #!define URI "sip:scscf.ims.mnc001.mcc001.3gppnetwork.org:6060"
---
> #!define NETWORKNAME "domain.imsprovider.org"
> #!define NETWORKNAME_ESC "domain\.imsprovider\.org"
> #!define HOSTNAME "scscf1.domain.imsprovider.org"
> #!define HOSTNAME_ESC "scscf1\.domain\.imsprovider\.org"
> #!define URI "sip:scscf1.domain.imsprovider.org:6060"
16,17c18,19
< #!subst "/NETWORKNAME/ims.mnc001.mcc001.3gppnetwork.org/"
< #!subst "/HSS_REALM/ims.mnc001.mcc001.3gppnetwork.org/"
---
> #!subst "/NETWORKNAME/domain.imsprovider.org/"
> #!subst "/HSS_REALM/domain.imsprovider.org/"
19c21,22
< alias=scscf.ims.mnc001.mcc001.3gppnetwork.org
---
> alias=scsf1.domain.imsprovider.org
> #alias=scscf.ims.mnc001.mcc001.3gppnetwork.org
22c25,26
< #!define ENUM_SUFFIX "ims.mnc001.mcc001.3gppnetwork.org."
---
> #!define ENUM_SUFFIX "domain.imsprovider.org."
> ##!define ENUM_SUFFIX "ims.mnc001.mcc001.3gppnetwork.org."
29c33,34
< #!define DB_URL "mysql://scscf:heslo@127.0.0.1/scscf"
---
> #!define DB_URL "mysql://scscf1:heslo@127.0.0.1/scscf1"
> ##!define DB_URL "mysql://scscf:heslo@127.0.0.1/scscf"
```

### Modification of PCSCF1 files

#### kamailio_pcscf1.cfg

```
root@kamailio-bionic:/etc# diff kamailio_pcscf.BACKUP/kamailio_pcscf.cfg kamailio_pcscf/kamailio_pcscf1.cfg 
12c12
< import_file "pcscf.cfg"
---
> import_file "pcscf1.cfg"
48c48
< listen=tcp:127.0.0.1:5060
---
> listen=tcp:127.0.0.33:5060
143c143
< system.service = "Proxy-CSCF" desc "Function of this server"
---
> system.service = "Proxy-CSCF1" desc "Function of this server1"
264c264
< modparam("jsonrpcs", "fifo_name", "/var/run/kamailio_pcscf/kamailio_rpc.fifo")
---
> modparam("jsonrpcs", "fifo_name", "/var/run/kamailio_pcscf1/kamailio_rpc.fifo")
266c266
< modparam("jsonrpcs", "dgram_socket", "/var/run/kamailio_pcscf/kamailio_rpc.sock")
---
> modparam("jsonrpcs", "dgram_socket", "/var/run/kamailio_pcscf1/kamailio_rpc.sock")
349c349
< modparam("rtpengine", "rtpengine_sock", "1 == udp:localhost:2223")
---
> modparam("rtpengine", "rtpengine_sock", "1 == udp:127.0.0.88:2223")
357c357
< modparam("ctl", "binrpc", "unix:/var/run/kamailio_pcscf/kamailio_ctl")
---
> modparam("ctl", "binrpc", "unix:/var/run/kamailio_pcscf1/kamailio_ctl")
421c421
< modparam("cdp","config_file","/etc/kamailio_pcscf/pcscf.xml")
---
> modparam("cdp","config_file","/etc/kamailio_pcscf/pcscf1.xml")

```

#### pcscf1.xml

```
root@kamailio-bionic:/etc# diff kamailio_pcscf.BACKUP/pcscf.xml kamailio_pcscf/pcscf1.xml
3,4c3,4
< 	FQDN="pcscf.ims.mnc001.mcc001.3gppnetwork.org"
< 	Realm="ims.mnc001.mcc001.3gppnetwork.org"
---
> 	FQDN="pcscf1.domain.imsprovider.org"
> 	Realm="domain.imsprovider.org"
17c17
< 	<Peer FQDN="pcrf.epc.mnc001.mcc001.3gppnetwork.org" Realm="epc.mnc001.mcc001.3gppnetwork.org" port="3868"/> 
---
> 	<Peer FQDN="pcrf.domain.imsprovider.org" Realm="epc.domain.imsprovider.org" port="3868"/> 
19c19
< 	<Acceptor port="3871" bind="10.4.128.21"/>
---
> 	<Acceptor port="3871" bind="127.0.0.33"/>
24c24
< 	<DefaultRoute FQDN="pcrf.epc.mnc001.mcc001.3gppnetwork.org" metric="10"/>
---
> 	<DefaultRoute FQDN="pcrf.domain.imsprovider.org" metric="10"/>

```

#### pcscf1.cfg

> Note: _Options WITH_RX, WITH_RX_REG and WITH_RX_CALL are commented out because no mobile core network is used in this scenario, and thus the Rx interface (between PCSCF and PGW) is not present._

```
root@kamailio-bionic:/etc# diff kamailio_pcscf.BACKUP/pcscf.cfg kamailio_pcscf/pcscf1.cfg 
4c4,5
< listen=udp:10.4.128.21:5060
---
> listen=udp:127.0.0.33:5060
> #listen=udp:10.4.128.21:5060
8c9,10
< listen=tcp:10.4.128.21:5060
---
> listen=tcp:127.0.0.33:5060
> #listen=tcp:10.4.128.21:5060
15c17
< #!define IPSEC_LISTEN_ADDR "10.4.128.21"
---
> #!define IPSEC_LISTEN_ADDR "127.0.0.33"
21c23
< #!define RX_AF_SIGNALING_IP "10.4.128.21"
---
> #!define RX_AF_SIGNALING_IP "127.0.0.33"
25c27,28
< alias=pcscf.ims.mnc001.mcc001.3gppnetwork.org
---
> alias=pcscf1.domain.imsprovider.org
> #alias=pcscf.ims.mnc001.mcc001.3gppnetwork.org
30c33
< #!define PCSCF_URL "sip:pcscf.ims.mnc001.mcc001.3gppnetwork.org:5060"
---
> #!define PCSCF_URL "sip:pcscf1.domain.imsprovider.org:5060"
34,36c37,39
< #!subst "/NETWORKNAME/ims.mnc001.mcc001.3gppnetwork.org/"
< #!subst "/HOSTNAME/pcscf.ims.mnc001.mcc001.3gppnetwork.org/"
< #!subst "/PCRF_REALM/epc.mnc001.mcc001.3gppnetwork.org/"
---
> #!subst "/NETWORKNAME/domain.imsprovider.org/"
> #!subst "/HOSTNAME/pcscf1.domain.imsprovider.org/"
> #!subst "/PCRF_REALM/epc.domain.imsprovider.org/"
47c50
< #!define DB_URL "mysql://pcscf:heslo@127.0.0.1/pcscf"
---
> #!define DB_URL "mysql://pcscf1:heslo@127.0.0.1/pcscf1"
50c53
< #!define SQLOPS_DBURL "pcscf=>mysql://pcscf:heslo@127.0.0.1/pcscf"
---
> #!define SQLOPS_DBURL "pcscf=>mysql://pcscf1:heslo@127.0.0.1/pcscf1"
108c111
< #!define FORCE_RTPRELAY
---
> ##!define FORCE_RTPRELAY
113,115c116,118
< #!define WITH_RX
< #!define WITH_RX_REG
< #!define WITH_RX_CALL
---
> ##!define WITH_RX
> ##!define WITH_RX_REG
> ##!define WITH_RX_CALL
```

### Modification of ICSCF files

> Note: _Complete information on the parameters in [Core Cookbook for Kamailio SIP Server v5.3.x (stable)](https://www.kamailio.org/wikidocs/cookbooks/5.3.x/core/)_.

#### kamailio_icscf.cfg

```
root@kamailio-bionic:/etc# diff kamailio_icscf.BACKUP/kamailio_icscf.cfg kamailio_icscf/kamailio_icscf.cfg 
31c31,32
< listen=tcp:127.0.0.1:4060
---
> listen=tcp:127.0.0.55:4060
> #listen=tcp:127.0.0.1:4060
```

#### icscf.xml

```
root@kamailio-bionic:/etc# diff kamailio_icscf.BACKUP/icscf.xml kamailio_icscf/icscf.xml 

3,4c3,4
< 	FQDN="icscf.ims.mnc001.mcc001.3gppnetwork.org"
< 	Realm="ims.mnc001.mcc001.3gppnetwork.org"
---
> 	FQDN="icscf.domain.imsprovider.org"
> 	Realm="domain.imsprovider.org"
18c18
< 	<Peer FQDN="hss.ims.mnc001.mcc001.3gppnetwork.org" Realm="ims.mnc001.mcc001.3gppnetwork.org" port="3868"/>
---
> 	<Peer FQDN="hss.domain.imsprovider.org" Realm="domain.imsprovider.org" port="3868"/>
20c20
< 	<Acceptor port="3869" bind="10.4.128.21"/>
---
> 	<Acceptor port="3869" bind="127.0.0.55"/>
33c33
< 	<DefaultRoute FQDN="hss.ims.mnc001.mcc001.3gppnetwork.org" metric="10"/>
---
> 	<DefaultRoute FQDN="hss.domain.imsprovider.org" metric="10"/>

```

#### icscf.cfg

```
root@kamailio-bionic:/etc# diff kamailio_icscf.BACKUP/icscf.cfg kamailio_icscf/icscf.cfg 
2c2
< listen=udp:10.4.128.21:4060
---
> listen=udp:127.0.0.55:4060
5c5
< listen=tcp:10.4.128.21:4060
---
> listen=tcp:127.0.0.55:4060
10c10
< alias=ims.mnc001.mcc001.3gppnetwork.org
---
> alias=domain.imsprovider.org
12,13c12,13
< #!define NETWORKNAME "ims.mnc001.mcc001.3gppnetwork.org"
< #!define HOSTNAME "icscf.ims.mnc001.mcc001.3gppnetwork.org"
---
> #!define NETWORKNAME "domain.imsprovider.org"
> #!define HOSTNAME "icscf.domain.imsprovider.org"
15,16c15,16
< #!subst "/NETWORKNAME/ims.mnc001.mcc001.3gppnetwork.org/"
< #!subst "/HSS_REALM/ims.mnc001.mcc001.3gppnetwork.org/"
---
> #!subst "/NETWORKNAME/domain.imsprovider.org/"
> #!subst "/HSS_REALM/domain.imsprovider.org/"
18c18
< #!define ENUM_SUFFIX "ims.mnc001.mcc001.3gppnetwork.org."
---
> #!define ENUM_SUFFIX "domain.imsprovider.org."
```

## Create PCSCF, SCSCF and ICSCF databases

> Note: _Section adapted from [SuckanLee2025] to match this tutorial's CSCF names and other parameters._


To create the databases for the CSCF nodes (in our case, PCSCF1, SCSCF1 and ICSCF), first run `mysql` and then:

```mysql
mysql> create database scscf1;
Query OK, 1 row affected (0.00 sec)

mysql> create database pcscf1;
Query OK, 1 row affected (0.00 sec)

mysql> create database icscf;
Query OK, 1 row affected (0.00 sec)
```

Create the tables of each database, pressing <Enter> each time root pass is asked:

> Note: _the files to use when creating these databases are specified in the corresponding `README.md` files inside `/etc/kamailio_scsf`, `/etc/kamailio_pcscf` and `/etc/kamailio_icscf`._

```bash
cd /usr/local/src/kamailio/utils/kamctl/mysql

mysql -u root -p pcscf1 < standard-create.sql
mysql -u root -p pcscf1 < presence-create.sql
mysql -u root -p pcscf1 < ims_usrloc_pcscf-create.sql
mysql -u root -p pcscf1 < ims_dialog-create.sql

mysql -u root -p scscf1 < standard-create.sql
mysql -u root -p scscf1 < presence-create.sql
mysql -u root -p scscf1 < ims_usrloc_scscf-create.sql
mysql -u root -p scscf1 < ims_dialog-create.sql
mysql -u root -p scscf1 < ims_charging-create.sql

cd /usr/local/src/kamailio/misc/examples/ims/icscf/
mysql -u root -p icscf < icscf.sql
```

Declare the users that will be able to modify the databases:

```mysql
mysql> grant delete,insert,select,update on scscf1.* to scscf1@localhost identified by 'heslo';
Query OK, 0 rows affected, 1 warning (0.00 sec)

mysql> grant delete,insert,select,update on pcscf1.* to pcscf1@localhost identified by 'heslo';
Query OK, 0 rows affected, 1 warning (0.00 sec)

mysql> grant delete,insert,select,update on icscf.* to icscf@localhost identified by 'heslo';
Query OK, 0 rows affected, 1 warning (0.00 sec)

mysql> grant delete,insert,select,update on icscf.* to provisioning@localhost identified by 'provi';
Query OK, 0 rows affected, 1 warning (0.00 sec)

mysql> grant all privileges on scscf1.* to 'scscf1'@'%' identified by 'heslo';
Query OK, 0 rows affected, 1 warning (0.00 sec)

mysql> grant all privileges on pcscf1.* to 'pcscf1'@'%' identified by 'heslo';
Query OK, 0 rows affected, 1 warning (0.00 sec)

mysql> grant all privileges on icscf.* to 'icscf'@'%' identified by 'heslo';
Query OK, 0 rows affected, 1 warning (0.00 sec)

mysql> grant all privileges on icscf.* to 'provisioning'@'%' identified by 'provi';
Query OK, 0 rows affected, 1 warning (0.00 sec)

mysql> flush privileges;
Query OK, 0 rows affected (0.01 sec)
```

In the ICSCF database, add the IMS domain as trusted, a reference to SCSCF1 and two of that SCSCF1's capabilities, with values `0` and `1`:

```mysql
mysql> use icscf;
mysql> insert into `nds_trusted_domains` values (1, 'domain.imsprovider.org');
mysql> insert into `s_cscf` values (1,'SCSCF Number 1','sip:scscf1.domain.imsprovider.org');
mysql> insert into `s_cscf_capabilities` values (1,1,0),(2,1,1);
mysql> select * from `s_cscf_capabilities`;
+----+-----------+------------+
| id | id_s_cscf | capability |
+----+-----------+------------+
|  1 |         1 |          0 |
|  2 |         1 |          1 |
+----+-----------+------------+
```

## Install and configure DNS server

> Note: _Section adapted from [SuckanLee2025] to match this tutorial's CSCF names and other parameters._

Start by installing `bind9` DNS server: `apt install bind9`.

Create the file with information on the `domain.imsprovider.org` DNS zone (`/etc/bind/domain.imsprovider.org`) with these contents:

```
$ORIGIN domain.imsprovider.org.
$TTL 1W
@                       1D IN SOA       localhost. root.localhost. (
                                        1               ; serial
                                        3H              ; refresh
                                        15M             ; retry
                                        1W              ; expiry
                                        1D )            ; minimum

                        1D IN NS        ns
ns                      1D IN A         127.0.0.66

pcscf1                  1D IN A         127.0.0.33
_sip._udp.pcscf1        1D SRV 0 0 5060 pcscf1
_sip._tcp.pcscf1        1D SRV 0 0 5060 pcscf1

icscf                   1D IN A         127.0.0.55
_sip._udp               1D SRV 0 0 4060 icscf
_sip._tcp               1D SRV 0 0 4060 icscf

scscf1                  1D IN A         127.0.0.11
_sip._udp.scscf1        1D SRV 0 0 6060 scscf1
_sip._tcp.scscf1        1D SRV 0 0 6060 scscf1

hss                     1D IN A         127.0.0.77
```

> Note: _Since we do not have an EPC in our scenario, no DNS zone is defined for it._

Edit the following bind9 configuration files:

- `/etc/bind/named.conf.local`. Contents:

```
// Do any local configuration here
//

// Consider adding the 1918 zones here, if they are not used in your
// organization
//include "/etc/bind/zones.rfc1918";

zone "domain.imsprovider.org" {
        type master;
        file "/etc/bind/domain.imsprovider.org";
};
```

- `/etc/bind/named.conf.options`. Contents:

```
options {
	directory "/var/cache/bind";

	// If there is a firewall between you and nameservers you want
	// to talk to, you may need to fix the firewall to allow multiple
	// ports to talk.  See http://www.kb.cert.org/vuls/id/800113

	// If your ISP provided one or more IP addresses for stable 
	// nameservers, you probably want to use them as forwarders.  
	// Uncomment the following block, and insert the addresses replacing 
	// the all-0's placeholder.

	// forwarders {
	// 	0.0.0.0;
	// };

        forwarders {
            // Include one line terminated in ; with the IP address of 
            // each specific DNS server you want to add.
        };


	//========================================================================
	// If BIND logs error messages about the root key being expired,
	// you will need to update your keys.  See https://www.isc.org/bind-keys
	//========================================================================
	//dnssec-validation auto;

        dnssec-validation no;
        allow-query { any; };

	auth-nxdomain no;    # conform to RFC1035
	listen-on { 127.0.0.66; };
        //listen-on-v6 { any; };
};

```

Make this host use the just installed DNS server as its nameserver by creating file `/etc/netplan/60-dns.yaml` with these contents:

```yaml
network:
    ethernets:
        ens3:
            nameservers:
                search: [domain.imsprovider.org]
                addresses:
                    - 127.0.0.66
    version: 2
```

Change `ens3` for the corresponding interface name of your host if necessary (to find out, you can use `ip link`).

> Note: _This file is created using `/etc/netplan/50-cloud-init.yaml` as a base. Adapt to your host situation if necessary._

Then, arrange for the file to be applied by typing `netplan apply` and create the following symbolic link: `ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf`.

Arrange for `/etc/resolv.conf` file to have these contents:
```
# This file is managed by man:systemd-resolved(8). Do not edit.
#
# This is a dynamic resolv.conf file for connecting local clients directly to
# all known uplink DNS servers. This file lists all configured search domains.
#
# Third party programs must not access this file directly, but only through the
# symlink at /etc/resolv.conf. To manage man:resolv.conf(5) in a different way,
# replace this symlink by a static file or a different symlink.
#
# See man:systemd-resolved.service(8) for details about the supported modes of
# operation for /etc/resolv.conf.

nameserver 127.0.0.66
nameserver <IP_address_of_another_nameserver_if_any>
search domain.imsprovider.org openstacklocal
```

And restart the following services:

```bash
systemctl restart systemd-resolved.service
systemctl restart bind9
```

Check the name resolution works as expected:
```bash
root@kamailio-bionic:~# ping pcscf1
PING pcscf1.domain.imsprovider.org (127.0.0.33) 56(84) bytes of data.
64 bytes from 127.0.0.33 (127.0.0.33): icmp_seq=1 ttl=64 time=0.146 ms
64 bytes from 127.0.0.33 (127.0.0.33): icmp_seq=2 ttl=64 time=0.066 ms
64 bytes from 127.0.0.33 (127.0.0.33): icmp_seq=3 ttl=64 time=0.068 ms

root@kamailio-bionic:~# ping google.com
PING google.com (216.58.209.78) 56(84) bytes of data.
64 bytes from waw02s06-in-f14.1e100.net (216.58.209.78): icmp_seq=1 ttl=112 time=4.39 ms
64 bytes from waw02s06-in-f14.1e100.net (216.58.209.78): icmp_seq=2 ttl=112 time=4.88 ms
64 bytes from waw02s06-in-f14.1e100.net (216.58.209.78): icmp_seq=3 ttl=112 time=4.10 ms
```

## Install and configure RTPEngine

> Note: _Section adapted from [SuckanLee2025] to match this tutorial's parameters._

```bash
export DEB_BUILD_PROFILES="pkg.ngcp-rtpengine.nobcg729"
apt install dpkg-dev
git clone https://github.com/sipwise/rtpengine
cd rtpengine/
git checkout mr7.4.1
```

Run `dpkg-checkbuilddeps` in that same directory and note what unmet build dependencies it reports.

> Example output:
>
>  dpkg-checkbuilddeps: error: Unmet build dependencies: debhelper (>= 10~) default-libmysqlclient-dev gperf iptables-dev (>= 1.4) libavcodec-dev (>= 6:10) libavfilter-dev (>= 6:10) libavformat-dev (>= 6:10) libavutil-dev (>= 6:10) libbencode-perl libcrypt-openssl-rsa-perl libcrypt-rijndael-perl libdigest-crc-perl libdigest-hmac-perl libevent-dev (>= 2.0) libhiredis-dev libio-multiplex-perl libio-socket-inet6-perl libiptc-dev libjson-glib-dev libnet-interface-perl libpcap0.8-dev libsocket6-perl libspandsp-dev libswresample-dev (>= 6:10) libsystemd-dev libxmlrpc-core-c3-dev (>= 1.16.07) markdown

With that output, install the unmet dependencies.

> Example based on previous output:
>
>  debhelper default-libmysqlclient-dev gperf iptables-dev libavcodec-dev libavfilter-dev libavformat-dev libavutil-dev libbencode-perl libcrypt-openssl-rsa-perl libcrypt-rijndael-perl libdigest-crc-perl libdigest-hmac-perl libevent-dev libhiredis-dev libio-multiplex-perl libio-socket-inet6-perl libiptc-dev libjson-glib-dev libnet-interface-perl libpcap0.8-dev libsocket6-perl libspandsp-dev libswresample-dev libsystemd-dev libxmlrpc-core-c3-dev markdown

After having done this, `dpkg-checkbuilddeps` should report an empty answer. Once this happens, build and install rtpengine packages:

```bash
root@kamailio-bionic:~/rtpengine# dpkg-buildpackage -uc -us
root@kamailio-bionic:~/rtpengine# cd ..
root@kamailio-bionic:~# dpkg -i *.deb
```

Create file `/etc/rtpengine/rtpengine.conf` taking `/etc/rtpengine/rtpengine.sample.conf` as a starting point and modify it in the manner specified by this diff command:

```bash
root@kamailio-bionic:~# cp /etc/rtpengine/rtpengine.sample.conf /etc/rtpengine/rtpengine.conf

root@kamailio-bionic:~# diff /etc/rtpengine/rtpengine.sample.conf /etc/rtpengine/rtpengine.conf 
16,17c16,17
< 
< listen-ng = 127.0.0.1:2223
---
> interface = 127.0.0.88
> listen-ng = 127.0.0.88:2223
72c72
< interface = 10.15.20.121
---
> interface = 127.0.0.88
```

Edit file `/etc/default/ngcp-rtpengine-daemon` so that it includes `RUN_RTPENGINE=yes` and file `/etc/default/ngcp-rtpengine-recording-daemon.dpkg-new` so that it includes `RUN_RTPENGINE_RECORDING=yes`.

Install rpcbind if needed in your host system:
```bash
root@kamailio-bionic:/etc/rtpengine# apt --fix-broken install
root@kamailio-bionic:/etc/rtpengine# apt install rpcbind
```

And restart the services:

```bash
root@kamailio-bionic:/etc/rtpengine# systemctl restart ngcp-rtpengine-daemon.service ngcp-rtpengine-recording-daemon.service ngcp-rtpengine-recording-nfs-mount.service
root@kamailio-bionic:/etc/rtpengine# systemctl enable ngcp-rtpengine-daemon.service ngcp-rtpengine-recording-daemon.service ngcp-rtpengine-recording-nfs-mount.service
```

Check that the daemon listens in the correct address and port:
```bash
root@kamailio-bionic:/etc/rtpengine# ss -tuln | grep 2223
udp   UNCONN  0        0                 127.0.0.88:2223          0.0.0.0:*     
```

## Launch the CSCF processes and prepare the system for the traffic capture

### Create the cgroups and classids on which the CSCFs are going to be later launched

Create the cgroup groups:

```bash
mkdir -p /sys/fs/cgroup/net_cls,net_prio/pidroutepcscf1
mkdir -p /sys/fs/cgroup/net_cls,net_prio/pidroutescscf1
mkdir -p /sys/fs/cgroup/net_cls,net_prio/pidrouteicscf
```

Establish the `net_cls classid` for each created cgroup:

```bash
echo 0x100001 | tee /sys/fs/cgroup/net_cls,net_prio/pidroutepcscf1/net_cls.classid
echo 0x100002 | tee /sys/fs/cgroup/net_cls,net_prio/pidroutescscf1/net_cls.classid
echo 0x100003 | tee /sys/fs/cgroup/net_cls,net_prio/pidrouteicscf/net_cls.classid
```

### Make sure all traffic coming from each of the processes launched in these groups has its source IP address as elected for the scenario

This is achieved by SNATting the traffic with iptables:

```bash
iptables -t nat -A POSTROUTING -m cgroup --cgroup 0x100001 -d 127.0.0.0/8 -j SNAT --to-source 127.0.0.33
iptables -t nat -A POSTROUTING -m cgroup --cgroup 0x100002 -d 127.0.0.0/8 -j SNAT --to-source 127.0.0.11
iptables -t nat -A POSTROUTING -m cgroup --cgroup 0x100003 -d 127.0.0.0/8 -j SNAT --to-source 127.0.0.55
```

> Note: _This prevents that, for example, DNS requests from the PCSCF1 are seen with source IP address = 127.0.0.1 when capturing traffic, something that would not hinder correct functioning, but would make it more difficult to interpret the messages flows with Wireshark._

### Launch the CSCF processes each inside its cgroup

Start by running `apt-get update` and `apt-get install -y cgroup-tools`, and then:

```bash
mkdir -p /var/run/kamailio_pcscf1
cgexec -g net_cls:pidroutepcscf1 kamailio -f /etc/kamailio_pcscf/kamailio_pcscf1.cfg -P /var/run/kamailio_pcscf1/kamailio_pcscf1.pid -DD -E -e &

mkdir /var/run/kamailio_scscf1
cgexec -g net_cls:pidroutescscf1 kamailio -f /etc/kamailio_scscf/kamailio_scscf1.cfg -P /var/run/kamailio_scscf1/kamailio_scscf1.pid -DD -E -e &

mkdir -p /var/run/kamailio_icscf
cgexec -g net_cls:pidrouteicscf kamailio -f /etc/kamailio_icscf/kamailio_icscf.cfg -P /var/run/kamailio_icscf/kamailio_icscf.pid -DD -E -e &
```

### Add iptables rules to be able to perform a capture of the packets with correct IP addresses and no duplicates

```bash
iptables -t mangle -A OUTPUT -m iprange --src-range 127.0.0.2-127.255.255.255 -m iprange --dst-range 127.0.0.2-127.255.255.255 -j MARK --set-mark 0x11

iptables -t mangle -A OUTPUT -m mark --mark 0x11 -j NFLOG --nflog-group 11

iptables -t mangle -A INPUT -m iprange --src-range 127.0.0.2-127.255.255.255 -m iprange --dst-range 127.0.0.2-127.255.255.255 -m mark ! --mark 0x11 -j NFLOG --nflog-group 11
```

The rationale behind these rules is the following:
- When a packet is generated in our system with loopback src and dst addresses, both different from 127.0.0.1, that packet will be processed by mangle:OUTPUT, where it will be marked 0x11, and will be copied to nflog-group 11. Afterwards, since the destination is this same host, it will go through mangle:INPUT but the 0x11 mark will prevent it from being copied again (i.e. duplicated) to nflog-group 11.
- When a packet is generated in our system whose source address is 127.0.0.1 and it has to be SNATted (see the SNAT rules in nat:POSTROUTING specified above), before going through SNAT it will go through mangle:OUTPUT, but it will neither be marked nor copied to nflog-group. After this packet is SNATted, and since the destination is this same host, it will go through mangle:INPUT, where it will be copied to nflog-group 11.
- If a packet is generated in our system that is an answer to a packet with the characteristics of the previous bullet, that packet will go through mangle:OUTPUT (before it is DNATted to "reverse" the request SNAT). There, it will be treated equivalently as the packet described in the first bullet, being thus copied only once to nflog-group 11.

### Capture in the virtual interface related to the chosen nflog-group

First, run `apt install wireshark-common` if needed in your system, and afterwards, just before the traffic is going to be generated (e.g. just before launching the user agents), run:

```bash
dumpcap -i nflog:11 -w captures/file.pcap
```

> Note: _With these steps, all traffic we are interested in is captured within the same host and in the same virtual interface (related to the nflog-group). This makes it much easier to have very didactical flow diagrams in which the order of the packets follows causality. It is suggested to open the .pcap file with Wireshark and visualize the flow graph (Statistics -> Flow graph)._

## Download and install HSS

> Note: _Section slightly adapted from [SuckanLee2025]._


### Prerequisites: download Java 7 and ant

In order to download an older version of Java (and Java 7 is an older version), it is necessary to previously have created an [Oracle account](https://profile.oracle.com/myprofile/account/create-account.jspx), which is free of charge.

Once that account is created, download `jdk-7u79-linux-x64.tar.gz` from [this link](https://www.oracle.com/technetwork/java/javase/downloads/java-archive-downloads-javase7-521261.html) and save it in `/usr/lib/jvm` (create that folder previously if necessary). Then, run:

```bash
cd /usr/lib/jvm
tar -zxf jdk-7u79-linux-x64.tar.gz -C /usr/lib/jvm/
update-alternatives --install /usr/bin/java java /usr/lib/jvm/jdk1.7.0_79/bin/java 100
update-alternatives --install /usr/bin/javac javac /usr/lib/jvm/jdk1.7.0_79/bin/javac 100
```

Check the correctness of the installation:

```bash
root@kamailio-bionic:/usr/lib/jvm# update-alternatives --display java
java - auto mode
  link best version is /usr/lib/jvm/jdk1.7.0_79/bin/java
  link currently points to /usr/lib/jvm/jdk1.7.0_79/bin/java
  link java is /usr/bin/java
/usr/lib/jvm/jdk1.7.0_79/bin/java - priority 100

root@kamailio-bionic:/usr/lib/jvm# update-alternatives --display javac
javac - auto mode
  link best version is /usr/lib/jvm/jdk1.7.0_79/bin/javac
  link currently points to /usr/lib/jvm/jdk1.7.0_79/bin/javac
  link javac is /usr/bin/javac
/usr/lib/jvm/jdk1.7.0_79/bin/javac - priority 100
 
root@kamailio-bionic:/usr/lib/jvm# update-alternatives --config java
There is only one alternative in link group java (providing /usr/bin/java): /usr/lib/jvm/jdk1.7.0_79/bin/java
Nothing to configure.

root@kamailio-bionic:/usr/lib/jvm# update-alternatives --config javac
There is only one alternative in link group javac (providing /usr/bin/javac): /usr/lib/jvm/jdk1.7.0_79/bin/javac
Nothing to configure.

root@kamailio-bionic:/usr/lib/jvm# java -version
java version "1.7.0_79"
Java(TM) SE Runtime Environment (build 1.7.0_79-b15)
Java HotSpot(TM) 64-Bit Server VM (build 24.79-b02, mixed mode)
```

Download file `apache-ant-1.9.14-bin.tar.gz` from [this link](http://archive.apache.org/dist/ant/binaries/apache-ant-1.9.14-bin.tar.gz) and store it in `/root`. After that, run:

```bash
root@kamailio-bionic:~# tar xvfvz apache-ant-1.9.14-bin.tar.gz
root@kamailio-bionic:~# mv apache-ant-1.9.14 /usr/local/
root@kamailio-bionic:~# sh -c 'echo ANT_HOME=/usr/local/ >> /etc/environment'
root@kamailio-bionic:~# ln -s /usr/local/apache-ant-1.9.14/bin/ant /usr/bin/ant

root@kamailio-bionic:~# ant -version
Apache Ant(TM) version 1.9.14 compiled on March 12 2019
```

### Download and install FHoSS

```bash
mkdir /opt/OpenIMSCore
cd /opt/OpenIMSCore/
git clone https://github.com/herlesupreeth/FHoSS
cd FHoSS/
export JAVA_HOME="/usr/lib/jvm/jdk1.7.0_79"
export CLASSPATH="/usr/lib/jvm/jdk1.7.0_79/jre/lib/"
ant compile deploy | tee ant_compile_deploy.txt
```

Create a file named `configurator.sh` inside `/opt/OpenIMSCore/FHoSS/deploy` with the following contents [SuckanLee2025]:

```bash
#!/bin/bash

# Initialization & global vars
# if you execute this script for the second time
# you should change these variables to the latest
# domain name and ip address
DDOMAIN="open-ims\.test"
DSDOMAIN="open-ims\\\.test"
DEFAULTIP="127\.0\.0\.1"
CONFFILES=`ls *.cfg *.xml *.sql *.properties 2>/dev/null`

# Interaction
printf "Domain Name:"
read domainname 
printf "IP Adress:"
read ip_address

# input domain is to be slashed for cfg regexes 
slasheddomain=`echo $domainname | sed 's/\./\\\\\\\\\./g'`

  if [ $# != 0 ] 
  then 
  printf "changing: "
      for j in $* 
      do
    sed -i -e "s/$DDOMAIN/$domainname/g" $j
    sed -i -e "s/$DSDOMAIN/$slasheddomain/g" $j
    sed -i -e "s/$DEFAULTIP/$ip_address/g" $j
    printf "$j " 
      done
  echo 
  else 
  printf "File to change [\"all\" for everything, \"exit\" to quit]:"
  # loop
      while read filename ;
      do
        if [ "$filename" = "exit" ] 
        then 
        printf "exitting...\n"
        break ;

      elif [ "$filename" = "all" ]
      then    
          printf "changing: "
         for i in $CONFFILES 
         do
        sed -i -e "s/$DDOMAIN/$domainname/g" $i
        sed -i -e "s/$DSDOMAIN/$slasheddomain/g" $i
        sed -i -e "s/$DEFAULTIP/$ip_address/g" $i
        
        printf "$i " 
         done 
         echo 
         break;

        elif [ -w $filename ] 
        then
            printf "changing $filename \n"
            sed -i -e "s/$DDOMAIN/$domainname/g" $filename
            sed -i -e "s/$DSDOMAIN/$slasheddomain/g" $filename
            sed -i -e "s/$DEFAULTIP/$ip_address/g" $filename

          else 
          printf "cannot access file $filename. skipping... \n" 
        fi
        printf "File to Change:"
      done 
  fi
``` 

After it is created, adapt its permissions (`chmod +x configurator.sh`). This file will serve to change the domain name and the IP address in the configuration files, by copying to different paths and running it.

```bash
root@kamailio-bionic:/opt/OpenIMSCore/FHoSS/deploy# ./configurator.sh 
Domain Name:domain.imsprovider.org
IP Adress:127.0.0.77
File to change ["all" for everything, "exit" to quit]:all
changing: DiameterPeerHSS.xml c3p0.properties hibernate.properties hss.properties log4j.properties

root@kamailio-bionic:/opt/OpenIMSCore/FHoSS/deploy# cp configurator.sh ../scripts/
root@kamailio-bionic:/opt/OpenIMSCore/FHoSS/deploy# cd ../scripts/

root@kamailio-bionic:/opt/OpenIMSCore/FHoSS/scripts# ./configurator.sh 
Domain Name:domain.imsprovider.org
IP Adress:127.0.0.77
File to change ["all" for everything, "exit" to quit]:all
changing: hss_db.sql hss_db_migrate_as_register.sql hss_db_migrate_dsai.sql userdata.sql

root@kamailio-bionic:/opt/OpenIMSCore/FHoSS/scripts# cp configurator.sh ../config/
root@kamailio-bionic:/opt/OpenIMSCore/FHoSS/scripts# cd ../config/
root@kamailio-bionic:/opt/OpenIMSCore/FHoSS/config# ./configurator.sh 
Domain Name:domain.imsprovider.org
IP Adress:127.0.0.77
File to change ["all" for everything, "exit" to quit]:all
changing: DiameterPeerHSS.xml c3p0.properties hibernate.properties hss.properties log4j.properties
```

After this, change the following:
- In file `/opt/OpenIMSCore/FHoSS/deploy/hibernate.properties`, revert the changed IP address and leave this line: `hibernate.connection.url=jdbc:mysql://127.0.0.1:3306/hss_db`.
- In file `/opt/OpenIMSCore/FHoSS/deploy/webapps/hss.web.console/WEB-INF/web.xml`, change `open-ims.org` by `domain.imsprovider.org`.
- In file `/opt/OpenIMSCore/FHoSS/src-web/WEB-INF/web.xml`, change `open-ims.org` by `domain.imsprovider.org`.

Make Tomcat listen in all interfaces instead of only in 127.0.0.77 (so that the web interface can be accessed from outside the host). To do so, change both `/opt/OpenIMSCore/FHoSS/deploy/hss.properties` and `/opt/OpenIMSCore/FHoSS/config/hss.properties` as follows (leave the rest unchanged):

```
# host & port : specify the IP address and the port where Tomcat is listening, e.g. host=127.0.0.77; port=8080;  

host=0.0.0.0
#host=127.0.0.77
port=8080
```

Change `scscf.domain.imsprovider.org` by `scscf1.domain.imsprovider.org` in these three files: `/opt/OpenIMSCore/FHoSS/deploy/DiameterPeerHSS.xml`, `/opt/OpenIMSCore/FHoSS/scripts/userdata.sql` and `/opt/OpenIMSCore/FHoSS/config/DiameterPeerHSS.xml`:

```bash
sed -i 's/scscf\.domain\.imsprovider\.org/scscf1.domain.imsprovider.org/g' /opt/OpenIMSCore/FHoSS/deploy/DiameterPeerHSS.xml
sed -i 's/scscf\.domain\.imsprovider\.org/scscf1.domain.imsprovider.org/g' /opt/OpenIMSCore/FHoSS/scripts/userdata.sql
sed -i 's/scscf\.domain\.imsprovider\.org/scscf1.domain.imsprovider.org/g' /opt/OpenIMSCore/FHoSS/config/DiameterPeerHSS.xml
```

Prepare the mysql database (when a pass is asked, press <Enter>):

```
root@kamailio-bionic:~# mysql
mysql> drop database hss_db;
mysql> create database hss_db;
mysql> quit

root@kamailio-bionic:~# cd /opt/OpenIMSCore/
root@kamailio-bionic:/opt/OpenIMSCore# mysql -u root -p hss_db < FHoSS/scripts/hss_db.sql 
Enter password: 
root@kamailio-bionic:/opt/OpenIMSCore# mysql -u root -p hss_db < FHoSS/scripts/userdata.sql 
Enter password:

root@kamailio-bionic:/opt/OpenIMSCore# mysql
mysql> grant delete,insert,select,update on hss_db.* to hss@localhost identified by 'hss';
mysql> grant delete,insert,select,update on hss_db.* to hss@'%' identified by 'hss';
```

At this point, run `cp /opt/OpenIMSCore/FHoSS/deploy/startup.sh /root/hss.sh` and add to `/root/hss.sh` the following three lines at the beginning:

```
cd /opt/OpenIMSCore/FHoSS/deploy 
JAVA_HOME="/usr/lib/jvm/jdk1.7.0_79"
CLASSPATH="/usr/lib/jvm/jdk1.7.0_79/jre/lib/"
```

To launch HSS, simply run:
```
/root/hss.sh
```

Check that it listens in the correct IP addresses and ports:

```bash
root@kamailio-bionic:~# ss -tuln | grep 8080 && ss -tuln | grep 77
tcp   LISTEN  0       100                         *:8080                *:*     
tcp   LISTEN  0       50        [::ffff:127.0.0.77]:3868                *:*     
```

## Add users using the FHoSS web interface

To connect to the FHoSS web interface, visit `http://<host_IP_address>:8080/hss.web.console/` and use the following credentials: user: `hssAdmin`, password: `hss`.

Follow next steps to add a user named "User a":
- Menu USER IDENTITIES: IMS Subscription -> Create:
  - Name: `User a`
  - Capabilities Set: `cap_set1`
  - Preferred S-CSCF: `scscf1`
- Click "Save" so that option "Create & Bind new IMPI" appears. Click on that option and enter the following values:
  - Identity: `a@domain.imsprovider.org`
  - Secret Key: `apass`
  - Authentication Schemes: Select "All" and choose "SIP Digest" as Default.
  - AMF: `8000`
  - OP: `00000000000000000000000000000000`
  - OPc: `00000000000000000000000000000000`
  - SQN: `000000021090`
- After clicking on "Save", click on "Create & Bind new IMPU" and enter these values:
  - Identity: `sip:a@domain.imsprovider.org`
  - Leave "Barring" unchecked.
  - Service Profile: `default_sp`
  - Charging-Info set: `default_charging_set`
  - Check "Can Register".
  - IMPU Type: `Public_User_Identity`
- After clicking "Save", select `domain.imsprovider.org` in "Add Visited-Networks" and click "Add".
- In "Associate IMPI(s) to IMPU" write `a@domain.imsprovider.org` as "IMPI Identity" and then click "Add".

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

## Launch a user agent for User a so that it registers to IMS

Add the following line to `/etc/hosts`:
```
127.0.0.33 domain.imsprovider.org
```

Arrange it so that the UA is launched in a specific cgroup and classid, prepare the corresponding SNAT rule (127.0.0.111) and make it listen on port 5566:

```bash
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
```

If, prior to launching the user agent, a capture is launched with `dumpcap -i nflog:11 -w captures/register.pcap`, the traffic flows associated to the registering of the user in IMS can be clearly observed by opening the `.pcap` file with Wireshark.

