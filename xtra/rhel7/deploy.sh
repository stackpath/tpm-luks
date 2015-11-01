function cont {
   echo
   echo $1
   read -p "== press ENTER to continue or CTRL+C to stop =="
   echo
}

#YUM exclusions

cont "adding tpm-tools tpm-luks trustedGRUB2 to yum update exclusions"
exclude=$(
   (
      echo "tpm-tools tpm-luks TrustedGRUB2" | tr ' ' '\n'
      cat /etc/yum.conf | grep '^exclude=' | sed -r 's/^exclude=(.*)/\1/' | tr ' ' '\n' | grep -v '^\s*$'
   ) | sort -u | tr '\n' ' '
)
echo exclude=$exclude

/usr/bin/cp -f /etc/yum.conf /etc/yum.conf.bak
(cat /etc/yum.conf | grep -v '^exclude=' ; echo "exclude=$exclude") > /etc/yum.conf.new
/usr/bin/cp -f /etc/yum.conf.new /etc/yum.conf
/usr/bin/rm -f /etc/yum.conf.new

#INSTALL AND CONFIGURE TrustedGRUB2

cont "replacing grub2 with TrustedGRUB2 package..."
yum remove -y grub2 grub2-tools
rpm -ivh ./TrustedGRUB2-[0-9]*.x86_64.rpm

cont "replacing boot loader..."
lsblk
read -a DEVICE -p "disk to install [/dev/sda]"
[ -z "$DEVICE" ] && DEVICE=/dev/sda

grub-install $DEVICE
grub-mkconfig -o /boot/grub/grub.cfg

#INSTALL TPM-TOOLS and TPM-LUKS
cont "creating tss user..."
id tss || useradd -r tss

cont "installing tpm-tools and tpm-luks packages..."
yum install -y trousers
rpm -ivh ./tpm-tools-[0-9]*.x86_64.rpm
rpm -ivh ./tpm-luks-[0-9]*.x86_64.rpm

cont "testing tpm...."
tcsd
tpm_nvinfo
tpm_version
RC=$?

if [ $RC -ne 0 ]; then
   echo "ERROR: tpm error"
   exit 1
fi

cont "configuring tpm-luks..."
sed -i '/^[^#]/d' /etc/tpm-luks.conf
x=2 # start at 2 for obscure reasons (see tpm-luks-ctl)
for d in $(blkid -c /dev/null -t TYPE=crypto_LUKS | cut -d: -f1); do echo "$d:$((x++)):/usr/sbin/tpm-luks-gen-tgrub2-pcr-values" ; done >> /etc/tpm-luks.conf
sed '/^#/d' /etc/tpm-luks.conf

cont "building new initramfs..."
dracut --force

echo
echo "You must now:"
echo "- tpm-luks-ctl init      to generate new LUKS keys and save them in the TPM NVRAM"
echo "- tpm-luks-ctl backup    to dump the LUKS keys and backup them in a safe place"
echo "- reboot                 to verify it works and have all PCRs computed correctly"
echo "- tpm-luks-ctl seal      to seal the TPM NVRAM"
echo "- reboot                 to verify it restarts automatically"
echo "- tpm-luks-ctl check     to be sure"
echo
