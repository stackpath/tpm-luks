This is still work in progress, and sannot be used as-is, as some files are still missing...

#Storing your LUKS key in TPM NVRAM for RHEL7, and seal them with PCR and TrustedGRUB2

This file describe a way to use TPM NVRAM for storing LUKS keys, with or without a password, and eventually use the TrustedGRUB2 boot loader to allow sealing the TP NVRAM with PCR.

TPM should be automatically enabled on RHEL7, as it is directly built into the kernel. You can simplify verify by looking for `/dev/tpm0`.

This will require to install four packages :

* [trousers]: allows to read and write the TPM
* [tpm-tools]: a utility that ease the use of the TPM
* [tpm-luks]: a dracut extension that reads the TPM NVRAM to get the key to use by LUKS
* [TrustedGRUB2]: a secure boot loader that fills PCR based on boot configuration

Unfortunatly, it seems that trousers and/or tpm-tools provided on the RHEL7 cdrom is not working, at least on my test platform, so you'll need to compile and install all four packages by yourself.

If you want to install on production servers, you will probably want to buld your own RPM packages.

The next sections explains how to do all this:

* A. Compiling and installing
* B. Building RPM packages
* C. Usage
* D. Secure boot
* E. Notes

##A. Compiling and installing

This section explains how to compile and install from source code.
	
###1. Install trousers in /usr/local

```bash
wget http://sourceforge.net/projects/trousers/files/trousers/0.3.13/trousers-0.3.13.tar.gz
tar zxf trousers-0.3.13.tar.gz
cd trousers-0.3.13
yum install automake autoconf pkgconfig libtool openssl-devel glibc-devel
export PKG_CONFIG_PATH=/usr/lib64/pkgconfig
sh ./bootstrap.sh
CFLAGS="-L/usr/lib64 -L/opt/gnome/lib64" LDFLAGS="-L/usr/lib64 -L/opt/gnome/lib64" ./configure --libdir="/usr/local/lib64"
make
make install
cd ..
```
	
###2. Install tpm-tools in /usr/local

```bash
wget ftp://rpmfind.net/linux/centos/7.0.1406/os/x86_64/Packages/opencryptoki-devel-3.0-11.el7.x86_64.rpm
yum localinstall opencryptoki-devel-3.0-11.el7.x86_64.rpm
wget http://sourceforge.net/projects/trousers/files/tpm-tools/1.3.8/tpm-tools-1.3.8.tar.gz
tar zxf tpm-tools-1.3.8.tar.gz
cd tpm-tools-1.3.8
yum install automake autoconf libtool gettext openssl openssl-devel opencryptoki
./configure
make
make install
cd ..
```
	
###3. Update ldconfig so libs from /usr/local are automatically loaded

```bash
cat <<\EOF > /etc/ld.so.conf.d/tpm-tools.conf
/usr/local/lib
/usr/local/lib64
EOF
ldconfig
```
	
###4. Install tpm-luks in /usr/local

```bash
git clone https://github.com/momiji/tpm-luks
cd tpm-luks
yum install automake autoconf libtool openssl openssl-devel
autoreconf -ivf
./configure
make
make install
```

###5. Install TrustedGRUB2 in /usr/local (only if you plan to seal NVRAM with PCR)
To get a full chain of trust up through your initramfs, you'll first need to

In case you want to seal your NVRAM with PCR values, 
blah blah... based on 2.0.0 release of grub2.
old version, but not so old as actual version is 2.0.2

However, one big difference is that all names are grub-* instead of grub2-*, which allows to install TrustedGRUB2 along side with grub2.

```bash
wget https://github.com/Sirrix-AG/TrustedGRUB2/archive/1.0.0.tar.gz -O TrustedGRUB2-1.0.0.tar.gz
wget http://mirror.centos.org/centos/7/os/x86_64/Packages/guile-2.0.9-5.el7.x86_64.rpm
wget http://mirror.centos.org/centos/7/os/x86_64/Packages/autogen-5.18-5.el7.x86_64.rpm
yum install gc gcc make bison gettext flex python autoconf automake
rpm -ivh guile-2.0.9-5.el7.x86_64.rpm
rpm -ivh autogen-5.18-5.el7.x86_64.rpm
tar zxf TrustedGRUB2-1.0.0.tar.gz
cd TrustedGRUB2-1.0.0
./autogen.sh
./configure
make
make install
ln -s /boot/grub /boot/grub2
grub-install /dev/sda
```
	
##B. Building RPM packages

This section explains how to build RPM packages from source code.

It is using rpmbuild and [mock], a fedora tool that helps in autamating RPM builds using chroot and rpmbuild.

Note that all rpms will be placed in ~makerpm/rpmbuild/RPMS.

###1. Install and configure rpmbuild and mock for RHEL

```bash
yum install rpmbuild mock
useradd -G mock makerpm
su - makerpm
mkdir -p ~/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
```
	
Create a new configuration file `/etc/mock/rhel.cfg` based on `/etc/mock/default.cfg` and change yum sources to use cdrom and epel repository.

You can then verify the good installation of mock:

```bash
mock -r rhel --init
mock -r rhel --shell "cat /etc/system-release"
```
and check that the result is `Red Hat Enterprise Linux Server release 7.0 (Maipo)`.

If you want to enter inside the chrooted folder the same way as mock:

```bash
mock -r rhel --shell
```
	
If you want to delete all mock files and cache:

```bash
mock -r rhel --scrub=all
```
	
###2. Build trousers RPM

Before building the rpm, you need to get the correct spec file. To do so you need run all A.1. up to and including the `./configure` line.
	
You can then use mock to build the rpm:

```bash
cd
cp trousers-0.3.13.tar.gz rpmbuild/SOURCES/
cp trousers-0.3.13/dist/fedora/trousers.spec rpmbuild/SPECS/
rpmbuild -bs rpmbuild/SPECS/trousers.spec
mock -r rhel --clean
mock -r rhel --resultdir=rpmbuild/RPMS/ rpmbuild/SRPMS/trousers-0.3.13-1.src.rpm --no-clean --no-cleanup-after
```
	
###3. Build tpm-tools RPM

Before building the rpm, you need to get the correct spec file. To do so you need run all A.2. up to and including the `./configure` line.
	
You can then use mock to build the rpm:

```bash
cd
cp tpm-tools-1.3.8.tar.gz rpmbuild/SOURCES/
cp tpm-tools-1.3.8/dist/tpm-tools.spec rpmbuild/SPECS/
sed -i 's/libtpm_unseal.so.0/libtpm_unseal.so.?/' rpmbuild/SPECS/tpm-tools.spec
sed -i 's/opencryptoki-devel/opencryptoki/g' rpmbuild/SPECS/tpm-tools.spec
rpmbuild -bs rpmbuild/SPECS/tpm-tools.spec
mock -r rhel --clean
mock -r rhel --yum-cmd localinstall rpmbuild/RPMS/trousers-0.3.13-1.x86_64.rpm
mock -r rhel --yum-cmd localinstall rpmbuild/RPMS/trousers-devel-0.3.13-1.x86_64.rpm
mock -r rhel --yum-cmd localinstall opencryptoki-devel-3.0-11.el7.x86_64.rpm
mock -r rhel --resultdir=rpmbuild/RPMS/ rpmbuild/SRPMS/tpm-tools-1.3.8-1.src.rpm --no-clean --no-cleanup-after
```

###4. Build tpm-luks RPM

Before building the rpm, you need to get the correct spec file. To do so you need run all A.4. up to and including the `./configure` line.
	
You can then use mock to build the rpm:

```bash
cd
git clone https://github.com/momiji/tpm-luks tpm-luks-0.8
tar zcf tpm-luks-0.8.tar.gz tpm-luks-0.8
cp tpm-luks-0.8.tar.gz rpmbuild/SOURCES/
cp tpm-luks/tpm-luks.spec rpmbuild/SPECS/
rpmbuild -bs rpmbuild/SPECS/tpm-luks.spec
mock -r rhel --clean
mock -r rhel --resultdir=rpmbuild/RPMS/ rpmbuild/SRPMS/tpm-luks-0.8-2.el7.src.rpm --no-clean --no-cleanup-after
```

###5. Build TrustedGRUB2 RPM

You can use mock to build the rpm:

```bash
cd
wget https://github.com/Sirrix-AG/TrustedGRUB2/archive/1.0.0.tar.gz -O TrustedGRUB2-1.0.0.tar.gz
wget http://mirror.centos.org/centos/7/os/x86_64/Packages/guile-2.0.9-5.el7.x86_64.rpm
wget http://mirror.centos.org/centos/7/os/x86_64/Packages/autogen-5.18-5.el7.x86_64.rpm
wget https://github.com/momiji/tpm-luks/xtra/TrustedGRUB2.spec
tar xf TrustedGRUB2-1.0.0.tar.gz
cp TrustedGRUB2.spec TrustedGRUB2-1.0.0/
tar zcf TrustedGRUB2-1.0.0.tar.gz TrustedGRUB2-1.0.0
cp TrustedGRUB2-1.0.0.tar.gz rpmbuild/SOURCES/
cp TrustedGRUB2.spec rpmbuild/SPECS/
rpmbuild -bs rpmbuild/SPECS/TrustedGRUB2.spec
mock -r rhel --clean
mock -r rhel --yum-cmd localinstall guile-2.0.9-5.el7.x86_64.rpm
mock -r rhel --yum-cmd localinstall autogen-5.18-5.el7.x86_64.rpm
mock -r rhel --shell "sed -i 's/--strict-build-id//g' /usr/lib/rpm/macros"
mock -r rhel --resultdir=rpmbuild/RPMS/ rpmbuild/SRPMS/TrustedGRUB2-1.0.0-1.el7.src.rpm --no-clean --no-cleanup-after
```
	
##C. Usage

Install from the build rpm
Backup original initramfs
Build a new one
Locate a NVRAM to use, ex number 1 All numbers are hexed, 10 is written 0xA
Update /etc/tpm-luks.conf with all disks for this NVRAM,
<device>:<nvram index>:
or if you want to use PCR (see section D. Secure boot below)
<device>:<nvram index>:///
for each disk : tpm-luks... avec -a pour password, sinon rien
to create, add -u to update... (keeping the same key)
Reboot and enjoy


	...
	
1. Update /etc/tpm-luks.conf and one line per disk you want to manage with tpm-luks
2. 

Backup LUKS headers before removing non-TPM keys, especially if using sealed NVRAM based on PCR values.
To restore headers, ...

	
##D. Secure boot

"Sealing" means binding the TPM NVRAM data to the state of your machine. Using sealing, you can require any arbitrary software to have run and recorded its state in the TPM before your LUKS secret would be released from the TPM chip. The usual use case would be to boot using a TPM-aware bootloader which records the kernel and initramfs you've booted. This would prevent your LUKS secret from being retrieved from the TPM chip if the machine was booted from any other media or configuration.

To get a full chain of trust up through your initramfs, you'll first need to install TrustedGRUB2, reboot, ...

install trusted grub 2
In the /etc/tpm-luks.conf file, the 3rd colomn lists the PCR to use to seal...
You might want to install TrustedGRUB2, a secured boot loader that automatically
fills some PCR based on kernel, initram, grub, ... files
	
Why yould I want to do this => with a password to prevent attacks as automatically locks itself
Prevent from disk stole..
without a password, based on PCR. if have access to the server (via ssh or else) ... nv_readvalue works without root access ?
	
Which PCR yould you want to use ?
	
##E. Notes

Haven't tested update of NVRAM when kernel or initramfs is rebuild, don't know if it works.
	
If you want to use password protected NVRAM (sealed or not), be aware that you'll be asked for the password for each LUKS disk.
This is by design, to prevent caching password or LUKS key (even in a temporary folder), and thus reducing security of the boot loader.
	
Also, if you activate logging during the boot process (using rd.debug option for example), all NVRAM passwords may be written in the log files in clear text.
In that case, it is recommended to use LUKS password instead of NVRAM passwords.

[trousers]: http://sourceforge.net/projects/trousers/
[tpm-tools]: http://sourceforge.net/projects/trousers/
[tpm-luks]: https://github.com/shpedoikal/tpm-luks/
[TrustedGRUB2]: https://github.com/Sirrix-AG/TrustedGRUB2/
[mock]: http://fedoraproject.org/wiki/Projects/Mock
