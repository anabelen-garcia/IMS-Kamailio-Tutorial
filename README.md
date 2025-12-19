# Single-VM IMS setup with Kamailio and FHoSS for academic purposes

## Main considerations

This is a step-by-step tutorial to setup an IMS scenario with Kamailio CSCFs and FHoSS as HSS, which runs in a single host. 

The following considerations have guided this work:
- The main purpose of this scenario is **academic** (mainly for teaching). Thus, ease of flow graph visualization with Wireshark has been given priority over, e.g., more realistic deployment options.
- For this same reason, on several occasions the version of several of the tools and products used is not the latest, but one for which enough detailed information existed publicly about similar test scenarios. Most probably an equivalent scenario can be reached with newer versions.
- The fact that all elements run in the same (virtual) machine makes it easier to have a portable (and "clonable") solution and also to get a capture file with consistent and causally-ordered traces, useful for teaching purposes.
- In this tutorial, the rationale behind some of the main decisions is explained so that the scenario can more easily evolve to more complex deployments.

## Credits

The following external resources have served as a guide to several parts of this tutorial:

- Sukchan Lee (Open5GS). "[VoLTE Setup with Kamailio IMS and Open5GS](https://open5gs.org/open5gs/docs/tutorial/02-VoLTE-setup/)" tutorial. Accessed December 18, 2025.

  This tutorial has been the main source for the core configuration of the P-, I- and S-CSCF IMS nodes, as well as for the FHoSS (HSS) and bind9 (DNS) services. For convenience, some information contained in this source is reproduced in this tutorial, sometimes verbatim.

- Margarita Garrido Lorenzo. "[Implementación de una plataforma IMS con herramientas open source](https://hdl.handle.net/2117/96677)". Final degree project (Supervisor: José Luis Muñoz Tapia). Universitat Politècnica de Catalunya. 2016.

  This work has served as inspiration and information regarding the use of PJSUA to be used as the IMS User Agent.

- Several free software products are used, amnog them: [Ubuntu](https://ubuntu.com/), [kamailio](https://www.kamailio.org/), [FHoSS](https://github.com/herlesupreeth/FHoSS), and [bind9](https://gitlab.isc.org/isc-projects/bind9).

## Preparation of the (virtual) machine that hosts the scenario

A VM with Ubuntu bionic has served as the base host on which to deploy the scenario. Specifically, a [cloud image for Ubuntu bionic](https://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.img) [^1] has been downloaded and deployed in an Openstack cloud environment, using a flavor with 2 vCPUs, 4096 MB RAM and 10 GB disk space, together with this cloud-init yaml file that enables root access with pass "admin":

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
A non-VM environment with Ubuntu bionic should work equally well with the rest of the tutorial. Whether the host is a VM or a physical host, for convenience it is recommended that the following services are enabled in it, in order to install and manage the scenario from an outside client:

- SSH (to run commands).
- sftp (to copy files to / from the host, e.g. with [filezilla](https://filezilla-project.org/)).
