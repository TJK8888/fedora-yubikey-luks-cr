#!/bin/sh

# Replace this placeholder during installation.
CRYPTNAME='luks-REPLACE_WITH_LUKS_UUID'

KEYDIR=/run/cryptsetup-keys.d
KEYFILE="$KEYDIR/$CRYPTNAME.key"

# Avoid a duplicate prompt if this service is started after root is already open.
if [ -e "/dev/mapper/$CRYPTNAME" ]; then
    exit 0
fi

mkdir -p "$KEYDIR"
chmod 700 "$KEYDIR"

PIN="$(systemd-ask-password 'YubiKey challenge/PIN:')" || exit 1

if printf '%s' "$PIN" | ykchalresp -2 -i- >"$KEYFILE"; then
    unset PIN
    chmod 600 "$KEYFILE"
    exit 0
fi

unset PIN
rm -f "$KEYFILE"
exit 1
