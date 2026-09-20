# Architecture

## Goal

Unlock a Fedora LUKS2 root volume using a deterministic HMAC-SHA1 Challenge-Response produced by an existing YubiKey OTP slot.

```text
user challenge/PIN
      |
      v
systemd-ask-password
      |
      v
ykchalresp -> YubiKey HMAC-SHA1 slot
      |
      v
derived response
      |
      v
/run/cryptsetup-keys.d/<CRYPTNAME>.key
      |
      v
systemd-cryptsetup
      |
      v
LUKS2 root
```

A separate LUKS keyslot should retain the normal recovery passphrase.

## Why this differs from Debian yubikey-luks

The challenge-response concept is the same, but Fedora uses dracut and systemd in early boot. A Debian-style `keyscript=` integration is therefore not directly portable.

The working Fedora design installs a one-shot systemd service into the initramfs. The generated root `systemd-cryptsetup@....service` explicitly Wants that service, while the YubiKey service is ordered Before the cryptsetup unit.

This ordering matters. An initqueue hook can execute after cryptsetup has already looked for its key file.

## Boot sequence

1. initramfs systemd starts.
2. The root cryptsetup transaction pulls in `yubikey-cr.service`.
3. `yubikey-cr.service` runs before the root cryptsetup service.
4. `systemd-ask-password` creates the challenge/PIN request. Plymouth can present it graphically.
5. The helper sends the challenge to `ykchalresp`.
6. The response is written with restrictive permissions to the volatile `/run/cryptsetup-keys.d` path.
7. `systemd-cryptsetup` consumes that response as the LUKS credential.
8. The encrypted root is activated.

## Duplicate-start guard

During testing the initramfs attempted to start the helper again after the mapper was already active. A guard prevents a second prompt:

```sh
if [ -e "/dev/mapper/$CRYPTNAME" ]; then
    exit 0
fi
```

Because `/run` and the mapper state are boot-local, this does not persist authentication material across boots.
