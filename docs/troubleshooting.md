# Troubleshooting

## Normal Fedora LUKS prompt appears before the YubiKey prompt

The CR generator is probably running too late. Verify that the exact root `systemd-cryptsetup@....service` has a `.wants/yubikey-cr.service` link in the initramfs and that `yubikey-cr.service` has `Before=` for that exact cryptsetup unit.

A dracut `initqueue/settled` hook was tested and proved unreliable for this purpose because cryptsetup could attempt activation before the hook generated the key.

## YubiKey prompt appears twice

The helper may be invoked again during initramfs processing. Keep the mapper guard in `yubikey-cr-key.sh`:

```sh
if [ -e "/dev/mapper/$CRYPTNAME" ]; then
    exit 0
fi
```

If the first invocation has already unlocked root, the second exits without prompting.

## PIN/challenge entered into the ordinary LUKS prompt fails

Expected. The short challenge is not a LUKS passphrase. It must first be processed by the YubiKey to generate the enrolled response.

## Inspect the current boot

After a successful boot:

```bash
sudo journalctl -b --no-pager | \
grep -Ei 'yubikey-cr|YubiKey challenge|systemd-cryptsetup|ask-password'
```

A healthy sequence should show the YubiKey service starting and finishing before the root cryptsetup service.

## Inspect the initramfs

```bash
sudo lsinitrd "/boot/initramfs-$(uname -r).img" | \
grep -E 'yubikey-cr|ykchalresp|systemd-ask-password'
```

Inspect a particular installed file with:

```bash
sudo lsinitrd -f /usr/libexec/yubikey-cr-key \
    "/boot/initramfs-$(uname -r).img"
```

## YubiKey is not detected

First prove Challenge-Response works in the running OS before debugging initramfs:

```bash
printf '%s' 'test-challenge' | ykchalresp -2 -i-
```

Do not publish the returned value.

The dracut module also includes the standard YubiKey udev rule when it is present on the host.

## Recovery path

If the CR path is unavailable, the separately retained LUKS recovery passphrase is the recovery credential. Do not remove that keyslot while developing or testing this integration.
