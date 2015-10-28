DO NOT USE YET, WORK STILL IN PROGRESS TO UPDATE THE WAY tpm-luks-init and tpm-luks-update work.

This is the new documentation on how to use LUKS with TPM enabled on RHEL7.

Old documentation can be founs here: [README_OLD]

##Introduction

This project objective is to save the LUKS keys in the TPM NVRAM on RHEL7 systems, and only RHEL7.

To acomoplish this, we will use:
* [trousers]: allows to read and write the TPM
* [tpm-tools]: a utility that ease the use of the TPM
* [tpm-luks]: a dracut extension that reads the TPM NVRAM to get the key to use by LUKS
* [TrustedGRUB2]: a secure boot loader that fills PCR based on boot configuration

Unfortunately, the default tpm-tools you can find in the RHEL repo does not work, tpm-luks is not compatible with RHEL7 and TrustedGRUB2 is not avaiable as an RPM.
Note that trousers is only necessary because we need the trousers-devel to build tpm-tools.

You will have to build your own RPMs, but this is not very complex after all.

* A. Building
* B. Installing
* C. Troubleshooting

##A. Building

You will find in xtra/rhel7 the necessary scripts to compile and build your own RPMs of tpm-tools, tpm-luks and TrustedGRUB2.

It is recommended to start with a fresh minimal install of rhel7. This is one possible procedure to do so:
* create a new virtual box virtual machine with 512MB of RAM and 8GB of disk
* install rhel from the rhel 7.1 iso cdrom you can download from redhat.com
* configure network so it can access the internet
* mount the cdrom to /mnt/cdrom: `mkdir /mnt/cdrom ; mount /dev/sr0 /mnt/cdrom`
* create a cdrom repo:

```
cat > /etc/yum.repos.d/cdrom.repo
[cdrom]
name=cdrom
baseurl=file:///mnt/cdrom
enabled=1
gpgcheck=0
```

* verify it works: `yum update`
* install git : yum install git

You can now configure the system using the scripts in xtra/rhel7 folder:

```
git clone https://github.com/momiji/tpm-luks.git
cd tpm-luks/xtra/rhel7
./install.sh -d
sudo su - makerpm
git clone https://github.com/momiji/tpm-luks.git
cd tpm-luks/xtra/rhel7
./install.sh -d
```

When successfull, you can now start building the RPMS:

```
./build_trousers.sh -d
./build_tpm-tools.sh -d
./build_tpm-luks.sh -d
./build_trustedrub2.sh -d
```

##B. Installing

You need a RHEL7 system with TPM hardware, installed without EFI, because TrustedGRUB2 is not compatible with EFI.
System partitions must be encrypted at install with LUKS.

Before installing, you need to copy the 3 required packages on the server. From there, you can simply call the deploy.sh script.

```
curl https://github.com/momiji/tpm-luks/xtra/rhel7/deploy.sh -o deploy.sh
chmod +x deploy.sh
./deploy.sh
```

It will install and configure the following RPMs we just built:
* tpm-tools
* tpm-luks
* TrustedGRUB2

You must save the keys in a safe place.

Now you can safely reboot the server, and then seal the TPM keys:

```
tpm-luks-update
```

Reboot again to verify everything works perfectly.

##C. Troubleshooting

If you need to unseal the TPM:
```
tpm-luks-update -n
```

It is important to seal back the TPM once the work is finished.

To manually add new LUKS partitions to a running system, you need to:
* add them in /etc/default/grub
* update /etc/tpm-luks.conf
* call tpm-luks-init -s 7 -n to generate keys for the new partitions
* call tpm-luks-update -n to unseal the TPM
* dracut --force to update the boot loader
* reboot
* call tpm-luks-update to seal the TPM
* reboot to verify everything works

[README_OLD]: README_OLD.md
[trousers]: http://sourceforge.net/projects/trousers/
[tpm-tools]: http://sourceforge.net/projects/trousers/
[tpm-luks]: https://github.com/shpedoikal/tpm-luks/
[TrustedGRUB2]: https://github.com/Sirrix-AG/TrustedGRUB2/
[mock]: http://fedoraproject.org/wiki/Projects/Mock
