# Week 4 starter: Evidence You Can Trust

Chain of custody means anyone can prove your evidence is authentic and untouched, without trusting you. You build two things: a signing step that runs in your pipeline, and a verify script that checks the result.

## The signing step (you add it to week 3's workflow)

After your gate produces `evidence/`, add a step that:

1. Bundles `evidence/` into a single `.tar.gz`.
2. Writes the bundle's SHA-256 to a `.sha256` sidecar file.
3. Signs the bundle with Cosign, keyless: `cosign sign-blob --yes --bundle evidence.sig.bundle <bundle>`.

Keyless signing means no private key. In GitHub Actions, Cosign uses the workflow's OIDC token, so the signature is tied to your pipeline run. The job needs `permissions: id-token: write` or the signing fails. The `--bundle` file packs the signature, the certificate, and the transparency-log entry into one file your verifier reads.

You can also sign locally to learn the flow: `cosign sign-blob` will open a browser for a one-time identity check. Still free, still keyless.

## The verify script (fill in verify-evidence.sh)

Three checks, each exits non-zero on failure:

1. **Integrity.** Recompute the SHA-256, compare to the sidecar.
2. **Authenticity.** `cosign verify-blob` against the `.sig.bundle`, pinning the OIDC issuer.
3. **Preservation** (stretch). If you used a vault, confirm the Object Lock retention is still in the future.

Print `CHAIN INTACT` only if all checks pass.

## The tamper test (this is the deliverable)

```bash
cp evidence.tar.gz /tmp/tampered.tar.gz
echo "junk" >> /tmp/tampered.tar.gz
./verify-evidence.sh /tmp/tampered.tar.gz   # must FAIL on integrity
./verify-evidence.sh evidence.tar.gz        # must say CHAIN INTACT
```

One changed byte breaks the chain. That failure is the whole point: custody is mathematical, not a promise.

## Cost

Free. Sigstore signing and verification cost nothing and need no cloud account. The only paid piece is the optional vault, which is pennies and gets torn down.

## Stretch: the immutable vault

For true preservation, upload the signed bundle to an S3 bucket with Object Lock and versioning on, so nobody can overwrite or delete it. Apply it, push one bundle, verify retention, then tear it down the same day. The brief covers the setup and teardown.

## What got built

The signing step landed in `grc-gate.yml` right after the existing evidence upload from week 3. It installs Cosign the same way week 3 installed Conftest: download a pinned version, check it against the published checksum file, then trust the binary. That install needed `id-token: write` added to the workflow's permissions, without it there's no OIDC token for Cosign to trade for a signing certificate. After the policy gate runs, a new step tars up `evidence/`, hashes it, and signs it with `cosign sign-blob --yes --bundle evidence.sig.bundle`. The signed bundle, the sha256 sidecar, and the signature bundle get uploaded as their own artifact, separate from the raw evidence folder, so there's something concrete to hand a verifier.

Filling in `verify-evidence.sh` turned up two things worth writing down.

The first was a repeat of a week 3 lesson. `sha256sum -c` checks the filename recorded in the sidecar against a file of that name sitting in the current directory. That works fine when you're checking the original bundle, but it breaks the moment you check a renamed or relocated copy, which is exactly what the tamper test does. So the integrity check pulls the hash out of the sidecar and compares it directly to a freshly computed hash of whatever file was actually passed in, no filename matching involved.

The second was something the README didn't call out but Cosign enforces anyway. Pinning the OIDC issuer alone isn't enough to prove a signature came from this pipeline specifically, it only proves it came from some GitHub Actions workflow somewhere. `cosign verify-blob` actually requires a `--certificate-identity` or `--certificate-identity-regexp` alongside the issuer, so the script pins both, anchored to this repo's `grc-gate.yml` workflow.

The whole thing got tested for real, not just checked for green in the Actions tab. After the workflow ran in [PR #6](https://github.com/JoelF-GRC/GRC_Club_Project/pull/6), the signed artifact was downloaded straight from that run and checked locally: `verify-evidence.sh` against the real bundle printed `INTEGRITY OK`, `AUTHENTICITY OK`, `PRESERVATION SKIPPED` (no vault configured yet), and `CHAIN INTACT`. Then the README's tamper test ran against that same bundle: a copy with one appended line, checked against the original sidecar and signature, failed integrity immediately and printed the expected mismatch. Same signature, different bytes, caught.

The preservation check is written but sits idle. It only runs when `VAULT_BUCKET` and `VAULT_KEY` are set as environment variables, and prints `PRESERVATION SKIPPED` otherwise. The Object Lock vault itself is still the stretch goal above, not yet built.
