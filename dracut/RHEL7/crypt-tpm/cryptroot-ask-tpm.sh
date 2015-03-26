#!/bin/sh
#
# package reqs: od, getcapability, nv_readvalue, dd
#
# Author: Kent Yoder <shpedoikal@gmail.com>
#
PATH=/usr/sbin:/usr/bin:/sbin:/bin
. /lib/dracut-crypt-lib.sh

CRYPTSETUP=/sbin/cryptsetup
MOUNT=/bin/mount
UMOUNT=/bin/umount
TPM_NVREAD=/usr/bin/nv_readvalue
GETCAP=/usr/bin/getcapability
AWK=/bin/awk
DEVICE=${1}
NAME=${2}
PASS=${3}
TPM_LUKS_MAX_NV_INDEX=128
TPM_LUKS_CONF=/etc/tpm-luks.conf
TPM_NV_PER_AUTHREAD=0x00040000
TPM_NV_PER_OWNERREAD=0x00020000

VIABLE_INDEXES=""

#
# Find the device index based on the device name
#

NVINDEX=$(cat $TPM_LUKS_CONF | grep -v "^\s*#" | grep $DEVICE | cut -d: -f2)

if [ -z "$NVINDEX" ]; then
	exit 0
fi

NVINDEX=$(printf "0x%x" $NVINDEX)

NVMATCH=$($GETCAP -cap 0x11 -scap $NVINDEX | ${AWK} -F ": " '$1 ~ /Matches/ { print $2 }')
NVSIZE=$($GETCAP -cap 0x11 -scap $NVINDEX | ${AWK} -F= '$1 ~ /dataSize/ { print $2 }')
NVRESULT=$($GETCAP -cap 0x11 -scap $NVINDEX | ${AWK} '$1 ~ /Result/ { print $11 }')

#
# An index is viable if its composite hash matches current PCR state, or if
# it doesn't require PCR state at all
#

if [ -z "$NVSIZE" ]; then
	exit 0
fi

if [ -n "${MATCH1}" -a "${MATCH1}" != "Yes" ]; then
	warn "TPM NV index does not match PCT state."
	exit 255
fi

#
# An index needs a password if authentication bits matches AUTHREAD or OWNERREAD
#

if [ -n "$NVRESULT" -a -z "$PASS" ]; then
	AUTHREAD=$(( 0x${NVRESULT} & ${TPM_NV_PER_AUTHREAD} ))
	OWNERREAD=$(( 0x${NVRESULT} & ${TPM_NV_PER_OWNERREAD} ))
	
	if [ ${AUTHREAD} -ne 0 -o ${OWNERREAD} -ne 0 ]; then
		ask_for_password --tries 3 \
			--cmd "cryptroot-ask-tpm $DEVICE $NAME pass" \
			--prompt "TPM NVRAM Password ($DEVICE)"
	
		exit 0
	fi
fi

# 

TMPFS_MNT=/tmp/cryptroot-mnt
if [ ! -d ${TMPFS_MNT} ]; then
        mkdir ${TMPFS_MNT} || exit -1
fi

$MOUNT -t tmpfs -o size=16K tmpfs ${TMPFS_MNT}
if [ $? -ne 0 ]; then
        warn "Unable to mount tmpfs area to securely use TPM NVRAM data."
        exit 255
fi

# plymouth feeds in this password for us, if we need a password
NVPASS_OPTIONS=
if [ -n "$PASS" ]; then
	if [ ! -n "${NVPASS}" ]; then
		read NVPASS
	fi
	NVPASS_OPTIONS="-pwdd ${NVPASS}"
fi

KEYFILE=${TMPFS_MNT}/key

$TPM_NVREAD -ix ${NVINDEX} ${NVPASS_OPTIONS} -sz ${NVSIZE} -of ${KEYFILE} >/dev/null 2>&1
RC=$?
if [ ${RC} -eq 1 ]; then
	warn "TPM NV index ${NVINDEX}: Bad password."
elif [ ${RC} -eq 24 ]; then
	warn "TPM NV index ${NVINDEX}: PCR mismatch."
elif [ ${RC} -eq 2 ]; then
	warn "TPM NV index ${NVINDEX}: Invalid NVRAM Index."
elif [ ${RC} -ne 0 ]; then
	warn "TPM NV index ${NVINDEX}: Unknown error (${RC})"
fi

if [ ${RC} -eq 0 ]; then
        info "Trying data read from NV index $NVINDEX"
        $CRYPTSETUP luksOpen ${DEVICE} ${NAME} --key-file ${KEYFILE} --keyfile-size ${NVSIZE}
        RC=$?
        # Zeroize keyfile regardless of success/fail
        dd if=/dev/zero of=${KEYFILE} bs=1c count=${NVSIZE} >/dev/null 2>&1
        if [ ${RC} -eq 0 ]; then
	        info "Success."
	        ${UMOUNT} ${TMPFS_MNT}

	        exit 0
	fi
	
        warn "Cryptsetup failed..."
fi


# NVRAM cannot be accessed. Fall back to LUKS passphrase
warn "Unable to unlock NVRAM index $NVINDEX."

${UMOUNT} ${TMPFS_MNT}
exit 255
