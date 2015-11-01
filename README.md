This is the new documentation on how to use LUKS with TPM enabled on RHEL7.

Old documentation can be found here: [README_OLD]

## Introduction

This project objective is to save the LUKS keys in the TPM NVRAM on RHEL7 systems, **and only RHEL7**.

To acomplish this, we will use:
* [trousers]: allows to read and write the TPM
* [tpm-tools]: a utility that ease the use of the TPM
* [tpm-luks]: a dracut extension that reads the TPM NVRAM to get the key to use by LUKS
* [TrustedGRUB2]: a secure boot loader that fills PCR based on boot configuration

Unfortunately, the default **tpm-tools** you can find in the RHEL repo does not work, **tpm-luks** is not compatible with RHEL7 and **TrustedGRUB2** is not available as an RPM.

Note that **trousers** is only necessary because we need the trousers-devel to build tpm-tools.

So, you will have to build your own RPMs, but this is very easy after all.

## A. Building

You will find in `xtra/rhel7` the necessary scripts to compile and build your own RPMs of **tpm-tools**, **tpm-luks** and **TrustedGRUB2**.

It is recommended to start with a fresh minimal install of rhel7. This is one possible procedure to do so:
* create a new virtual box virtual machine with 512MB of RAM and 8GB of disk
* install rhel from the rhel 7.1 iso cdrom you can download from redhat.com
* configure network so it can access the internet
* mount the cdrom to /mnt/cdrom: `mkdir /mnt/cdrom ; mount /dev/sr0 /mnt/cdrom`
* create a cdrom repo:
```
cat <<EOF > /etc/yum.repos.d/cdrom.repo
[cdrom]
name=cdrom
baseurl=file:///mnt/cdrom
enabled=1
gpgcheck=0
EOF
```

* verify it works: `yum update`
* install git : `yum install -y git`

You can now configure the system using the scripts in xtra/rhel7 folder:
```
git clone https://github.com/momiji/tpm-luks
cd tpm-luks/xtra/rhel7
./install.sh -d
sudo su - makerpm
git clone https://github.com/momiji/tpm-luks
cd tpm-luks/xtra/rhel7
./install.sh -d
```

When successfull, you can start building the RPMS:
```
./build_trousers.sh -d
./build_tpm-tools.sh -d
./build_tpm-luks.sh -d
./build_trustedgrub2.sh -d
```

## B. Installing

You need a RHEL7 system with TPM hardware, **installed without EFI**, because TrustedGRUB2 is not compatible with EFI.
System partitions must be encrypted at install with LUKS.

Remember you should only use basic ascii characters for TPM AUTH and OWNER passwords, like `A-Z`, `a-z`, `0-9`, plus some other chars that do not need to be escaped in bash shell. Do not use characters like `'` or `"`.

Before installing, you need to copy on the server the 3 packages we build in previous section: **tpm-tools**, **tpm-luks** and **TrustedGRUB2**.

From there, you can simply call the deploy.sh script, it will install and configure the system:
* configure yum to not automatically update these 3 packages
* install the packages
* configure the packages
```
curl https://github.com/momiji/tpm-luks/xtra/rhel7/deploy.sh -o deploy.sh
chmod +x deploy.sh
./deploy.sh
```

Reboot the server, it will still ask for LUKS paritions passwords, then:
```
tpm-luks-ctl init
tpm-luks-ctl seal
tpm-luks-ctl backup
```

Reboot again to verify everything works as expected.

## C. Notes

When initialized or unsealed, the TPM NVRAM is readable directly without having to enter a password. If you want an AUTH password, you can use the `-a` or `--auth-password` option. For the OWNER password, you can use `-o` or `--owner-password`.

If you want to use over PCRs than the defaults, you can modify them directly in the script `/usr/sbin/tpm-luks-gen-tgrub2-pcr-values`, or change the
scripts defined for each devices in `/etc/tpm-luks.conf`.

You can check if tpm-luks is configured correctly:
* `tpm-luks-ctl check`

If you want to unseal the TPM, before a reboot for example, remember to seal after the reboot:
* unseal: `tpm-luks-ctl unseal`
* reboot
* seal: `tpm-luks-ctl seal`

To add new LUKS partitions:
* modify `/etc/default/grub` file with new partitions info
* unseal: `tpm-luks-ctl unseal`
* add new partitions: `tpm-luks-ctl init`
* save backup: `tpm-luks-ctl backup`
* grub-mkconfig -o /boot/grub/grub.cfg
* dracut --force
* reboot
* seal: `tpm-luks-ctl seal`
* reboot to verify everything is ok

[README_OLD]: README_OLD.md
[trousers]: http://sourceforge.net/projects/trousers/
[tpm-tools]: http://sourceforge.net/projects/trousers/
[tpm-luks]: https://github.com/shpedoikal/tpm-luks/
[TrustedGRUB2]: https://github.com/Sirrix-AG/TrustedGRUB2/
[mock]: http://fedoraproject.org/wiki/Projects/Mock
