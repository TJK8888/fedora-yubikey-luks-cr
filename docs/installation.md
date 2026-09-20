# Installation

This guide intentionally uses placeholders. Read the commands before executing them and substitute values discovered on the target Fedora system.

## 1. Install prerequisites

```bash
sudo dnf install ykpers
command -v ykchalresp
command -v systemd-ask-password
```

This guide assumes the YubiKey OTP slot is **already** configured for HMAC-SHA1 Challenge-Response. Do not reprogram a working slot merely to follow this guide.

## 2. Identify the encrypted root

```bash
lsblk -f
sudo cryptsetup luksDump /dev/<ROOT_LUKS_PARTITION>
```

Record:

```text
ROOT_LUKS_PARTITION=/dev/...
LUKS_UUID=<uuid>
CRYPTNAME=luks-<uuid>
```

Confirm the normal recovery passphrase works before continuing.

## 3. Verify deterministic Challenge-Response

The example below assumes OTP slot 2. Change `-2` only if your existing CR configuration uses a different slot.

```bash
read -rsp "YubiKey challenge/PIN: " P1; echo
R1="$(printf '%s' "$P1" | ykchalresp -2 -i-)"

read -rsp "Repeat challenge/PIN: " P2; echo
R2="$(printf '%s' "$P2" | ykchalresp -2 -i-)"

if [ "$P1" = "$P2" ] && [ "$R1" = "$R2" ] && [ -n "$R1" ]; then
    echo "PASS: deterministic YubiKey CR response"
else
    echo "FAIL"
fi

unset P1 P2 R1 R2
```

The response is sensitive. The test intentionally does not print it.

## 4. Enroll the response in a free LUKS keyslot

Inspect current slots first:

```bash
sudo cryptsetup luksDump /dev/<ROOT_LUKS_PARTITION>
```

Choose a genuinely free slot and substitute `<NEW_SLOT>` below. Do not delete the recovery-passphrase slot.

```bash
umask 077
read -rsp "YubiKey challenge/PIN: " PIN; echo
printf '%s' "$PIN" | ykchalresp -2 -i- > /tmp/yubikey-cr-new.key
unset PIN

sudo cryptsetup luksAddKey \
    --key-slot <NEW_SLOT> \
    /dev/<ROOT_LUKS_PARTITION> \
    /tmp/yubikey-cr-new.key
```

Enter an existing valid LUKS passphrase when cryptsetup requests authorization.

Test the new credential:

```bash
sudo cryptsetup open --test-passphrase \
    --key-file /tmp/yubikey-cr-new.key \
    /dev/<ROOT_LUKS_PARTITION>

echo $?
rm -f /tmp/yubikey-cr-new.key
```

Expected result is `0`.

Regenerate the response from the remembered challenge and test again. This proves the credential can be recreated without storing it persistently.

## 5. Test the Fedora prompt path

```bash
umask 077
PIN="$(systemd-ask-password 'YubiKey challenge/PIN:')"
printf '%s' "$PIN" | ykchalresp -2 -i- > /tmp/yubikey-cr-test.key
unset PIN

sudo cryptsetup open --test-passphrase \
    --key-file /tmp/yubikey-cr-test.key \
    /dev/<ROOT_LUKS_PARTITION>

RC=$?
rm -f /tmp/yubikey-cr-test.key
echo "LUKS CR test result: $RC"
```

Continue only if the result is `0`.

## 6. Determine the exact systemd cryptsetup unit

Fedora generates a unit for the root mapper. After boot, inspect it with:

```bash
systemctl list-units 'systemd-cryptsetup@*.service'
```

The exact escaped unit name is required. Do not guess its escaping. You can also inspect the generated unit under `/run/systemd/generator/`.

For a mapper conceptually named:

```text
luks-<uuid>
```

systemd escapes hyphens in the instance portion as `\x2d`. Use the exact unit shown by systemd on your machine.

Set a shell variable to the exact unit name, for example:

```bash
CRYPTUNIT='systemd-cryptsetup@<EXACT_ESCAPED_INSTANCE>.service'
```

## 7. Configure crypttab

Back up the current file:

```bash
sudo cp -a /etc/crypttab /etc/crypttab.pre-yubikey-cr
```

The root entry needs to reference:

```text
/run/cryptsetup-keys.d/<CRYPTNAME>.key
```

Conceptually:

```text
<CRYPTNAME> UUID=<LUKS_UUID> /run/cryptsetup-keys.d/<CRYPTNAME>.key x-initrd.attach
```

Preserve any other options your existing Fedora installation requires rather than blindly replacing the line.

## 8. Install the dracut module templates

Clone this repository and copy the module:

```bash
sudo cp -a dracut/55yubikey-cr /usr/lib/dracut/modules.d/
```

Edit:

```text
/usr/lib/dracut/modules.d/55yubikey-cr/yubikey-cr-key.sh
```

Replace:

```text
luks-REPLACE_WITH_LUKS_UUID
```

with the actual `CRYPTNAME`.

Then edit:

```text
/usr/lib/dracut/modules.d/55yubikey-cr/yubikey-cr.service
```

and replace:

```text
SYSTEMD_CRYPTSETUP_UNIT_REPLACE_ME
```

with the exact `$CRYPTUNIT`.

## 9. Add the direct cryptsetup dependency

Edit `module-setup.sh` and, inside `install()`, add creation of the exact unit wants directory:

```sh
mkdir -p "$initdir/usr/lib/systemd/system/<EXACT_CRYPTSETUP_UNIT>.wants"

ln -s ../yubikey-cr.service \
    "$initdir/usr/lib/systemd/system/<EXACT_CRYPTSETUP_UNIT>.wants/yubikey-cr.service"
```

The directory name must exactly match the escaped root cryptsetup unit.

This explicit dependency is the important Fedora integration point.

## 10. Enable the module

```bash
sudo tee /etc/dracut.conf.d/yubikey-cr.conf >/dev/null <<'EOF'
add_dracutmodules+=" yubikey-cr "
EOF
```

Rebuild the current initramfs:

```bash
sudo dracut --force
```

## 11. Verify before reboot

```bash
sudo lsinitrd "/boot/initramfs-$(uname -r).img" | \
grep -E 'yubikey-cr|ykchalresp|systemd-ask-password'
```

Inspect the helper:

```bash
sudo lsinitrd -f /usr/libexec/yubikey-cr-key \
    "/boot/initramfs-$(uname -r).img"
```

Inspect crypttab:

```bash
sudo lsinitrd -f /etc/crypttab \
    "/boot/initramfs-$(uname -r).img"
```

Verify that the exact cryptsetup `.wants` directory and `yubikey-cr.service` symlink are present.

## 12. Reboot test

Reboot with the YubiKey inserted.

Expected behavior:

```text
YubiKey challenge/PIN
        |
        v
enter short challenge once
        |
        v
YubiKey CR generated
        |
        v
LUKS root unlocked
        |
        v
Fedora boots
```

The normal long LUKS recovery passphrase should not be required during a successful CR boot.

After login, verify ordering:

```bash
sudo journalctl -b --no-pager | \
grep -Ei 'yubikey-cr|YubiKey challenge|systemd-cryptsetup|ask-password'
```

The YubiKey service should complete before root `systemd-cryptsetup`.

## Important

Do not publish the output of `ykchalresp` or the contents of any generated key file. See [Security model](security-model.md).
