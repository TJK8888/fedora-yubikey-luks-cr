# Security model

## What is secret?

Treat these values as secrets:

- The long LUKS recovery passphrase.
- The YubiKey's HMAC-SHA1 secret.
- The user's chosen challenge/PIN.
- The HMAC response generated for that challenge.

In this design the HMAC response is enrolled as a LUKS credential. A captured valid response should therefore be treated as replayable unlock material for an attacker who has the encrypted volume/header.

## What is not a password?

These are configuration or identifiers and are not sufficient to reconstruct the credential:

- LUKS UUID.
- Mapper name.
- Partition device name.
- Keyslot number.
- YubiKey USB VID/PID.
- The fact that HMAC-SHA1 Challenge-Response is used.
- The dracut/systemd scripts.
- Normal LUKS header metadata such as salts and KDF parameters.

The LUKS header is nevertheless security-relevant because possession of it permits offline testing of candidate credentials. Protect backups appropriately.

## Challenge versus response

```text
challenge/PIN + secret inside YubiKey -> HMAC response -> LUKS credential
```

The challenge/PIN alone is not the LUKS credential. Knowing it without the YubiKey secret does not directly reveal the enrolled HMAC response.

Conversely, possession of the correct response can bypass the need to reproduce the HMAC calculation, so never publish the output of `ykchalresp` or the contents of the generated key file.

## Avoid accidental disclosure

Do not run diagnostic commands that print the generated response into logs, screenshots, shell transcripts or bug reports. In particular, never publish the contents of:

```text
/run/cryptsetup-keys.d/<CRYPTNAME>.key
```

Temporary enrollment files should be created with restrictive permissions and removed immediately after use.

## Recovery

Keep an independently tested long LUKS passphrase in a separate keyslot. Challenge-Response should add a normal authentication path, not remove the recovery path.
