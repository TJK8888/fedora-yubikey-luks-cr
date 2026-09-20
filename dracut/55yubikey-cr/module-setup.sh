#!/bin/sh

check() {
    require_binaries ykchalresp systemd-ask-password
    return $?
}

depends() {
    echo "systemd-cryptsetup"
    return 0
}

install() {
    inst_binary /usr/bin/ykchalresp
    inst_binary /usr/bin/systemd-ask-password

    if [ -f /usr/lib/udev/rules.d/69-yubikey.rules ]; then
        inst /usr/lib/udev/rules.d/69-yubikey.rules
    fi

    inst_simple "$moddir/yubikey-cr-key.sh" /usr/libexec/yubikey-cr-key
    inst_simple "$moddir/yubikey-cr.service" \
        /usr/lib/systemd/system/yubikey-cr.service

    # Installation must create the exact cryptsetup-unit .wants directory
    # and link yubikey-cr.service into it. See docs/installation.md.
}
