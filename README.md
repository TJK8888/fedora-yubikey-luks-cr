# Fedora YubiKey LUKS Challenge-Response

A tested method for unlocking a Fedora LUKS2 root volume with an existing YubiKey **HMAC-SHA1 Challenge-Response** credential, while retaining the normal LUKS passphrase as recovery.

> [!IMPORTANT]
> This project is for YubiKey OTP Challenge-Response (typically slot 2). It is **not** a FIDO2 enrollment guide and does not require reprogramming an already-configured Challenge-Response slot.

## Authentication flow

```text
short challenge/PIN
        +
YubiKey HMAC-SHA1 secret
        |
        v
HMAC challenge-response
        |
        v
LUKS2 keyslot
        |
        v
encrypted root unlocked
```

The short challenge/PIN is not itself a LUKS password. The enrolled LUKS credential is the deterministic HMAC response produced by the YubiKey for that challenge.

## Status

The design has been boot-tested on Fedora 44 with LUKS2, dracut, systemd-cryptsetup and Plymouth. The Fedora-specific integration uses a small dracut module and an initramfs systemd service ordered directly before the generated root `systemd-cryptsetup` unit.

This repository intentionally contains **no machine-specific UUIDs, hostnames, usernames, PINs, HMAC responses, or LUKS credentials**.

## Before you begin

You should already have:

- Fedora installed with a LUKS2-encrypted root volume.
- A working long LUKS recovery passphrase.
- A YubiKey whose OTP slot is already configured for HMAC-SHA1 Challenge-Response.
- A verified backup/recovery path before modifying LUKS keyslots or initramfs.

Install the YubiKey personalization utilities:

```bash
sudo dnf install ykpers
```

Then read **[Installation](docs/installation.md)** before making changes.

## Repository layout

```text
.
├── README.md
├── docs/
│   ├── architecture.md
│   ├── installation.md
│   ├── security-model.md
│   └── troubleshooting.md
└── dracut/
    └── 55yubikey-cr/
        ├── module-setup.sh
        ├── yubikey-cr-key.sh
        └── yubikey-cr.service
```

The files under `dracut/55yubikey-cr/` are generalized templates. Installation requires substituting the target system's mapper name and escaped systemd cryptsetup unit as described in the installation guide.

## Why a custom Fedora integration?

The upstream `yubikey-luks` concept is straightforward: prompt for a challenge, send it to the YubiKey, and use the deterministic response as a LUKS credential. Fedora's early boot is built around dracut and systemd, so Debian/initramfs-tools `keyscript=` instructions do not map directly.

A first attempt using a dracut `initqueue/settled` hook raced with `systemd-cryptsetup`. The reliable solution was to make the YubiKey credential generator a direct dependency of the exact root cryptsetup service and order it before that service.

## Security note

Treat the generated HMAC response as an **unlock credential**. Do not print, log, publish, or commit it. LUKS UUIDs, mapper names and the integration scripts are identifiers/configuration rather than secrets, but this repository uses placeholders so examples remain portable.

See **[Security model](docs/security-model.md)** for details.

## Scope

The current documentation targets conventional Fedora installations using dracut/systemd early boot. Atomic Fedora derivatives may require different deployment handling even though the underlying LUKS/systemd design is similar.

## Acknowledgment

This project adapts the HMAC-SHA1 challenge-response approach popularized by the upstream `cornelinux/yubikey-luks` project to Fedora's dracut/systemd boot architecture.
