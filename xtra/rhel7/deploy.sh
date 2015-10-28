function cont {
   echo
   echo $1
   read -p "press ENTER to continue or CTRL+C to stop"
   echo
}

#YUM exclusions

cont "adding tpm-tools tpm-luks trustedGRUB2 to yum update exclusions"
exclude=$(
   (
      echo "tpm-tools tpm-luks TrustedGRUB2" | tr ' ' '\n' ; 
      cat /etc/yum.conf | grep '^exclude=' | sed -r 's/^exclude=(.*)/\1/' | tr ' ' '\n' | sort -u
   ) | sort -u | tr '\n' ' '
)
echo exclude=$exclude

[ -f /etc/yum.conf.ori ] || cp /etc/yum.conf /etc/yum.conf.ori
(cat /etc/yum.conf | grep -v '^exclude=' ; echo "exclude=$exclude") > /etc/yum.conf.new
cat /etc/yum.conf.new > /etc/yum.conf
rm /etc/yum.conf.new

#INSTALL AND CONFIGURE TrustedGRUB2

cont "replacing grub2 with TrustedGRUB2 package..."
yum remove -y grub2 grub2-tools
rpm -ivh ./TrustedGRUB2-*.el7.x86_64.rpm

cont "replacing boot loader..."
lsblk
read -a DEVICE -p "disk to install [/dev/sda]"
[ -z "$DEVICE" ] && DEVICE=/dev/sda

grub-install $DEVICE
cp -f 10_linux /etc/grub.d/
grub-mkconfig -o /boot/grub/grub.cfg

#INSTALL TPM-TOOLS and TPM-LUKS
cont "creating tss user..."
useradd -r tss

cont "installing tpm-tools and tpm-luks packages..."
yum install trousers
rpm -ivh ./tpm-tools-*.x86_64.rpm
rpm -ivh ./tpm-luks-*.el7.x86_64.rpm

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
x=1
for d in $(blkid -c /dev/null | grep crypto_LUKS | cut -d: -f1); do echo "$d:$((x++)):/usr/sbin/tpm-luks-gen-tgrub2-pcr-values" ; done >> /etc/tpm-luks.conf
sed '/^#/d' /etc/tpm-luks.conf

cont "building new initramfs..."
dracut --force

cont "initializing with slot #7 without using PCR values..."
tpm-luks-init -s 7 -n

echo
echo "you must now save the keys in a safe place, reboot, and run tpm-luks-update"
