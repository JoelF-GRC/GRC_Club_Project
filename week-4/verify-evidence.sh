#!/usr/bin/env bash
# verify-evidence.sh <bundle.tar.gz> [sha256-sidecar] [sig-bundle]
# Proves an evidence bundle is intact and authentic.
#
# The sidecar and signature bundle default to the fixed names the CI
# workflow produces (evidence.tar.gz.sha256, evidence.sig.bundle) rather
# than being derived from the bundle argument's own filename. That is
# deliberate: the whole point of the tamper test is to check a candidate
# file against a known-good hash and signature obtained separately (from
# the CI artifact), not against a sidecar that could have been tampered
# alongside it.
set -euo pipefail

BUNDLE="${1:?usage: verify-evidence.sh <bundle.tar.gz> [sha256-sidecar] [sig-bundle]}"
SHA_SIDECAR="${2:-evidence.tar.gz.sha256}"
SIG_BUNDLE="${3:-evidence.sig.bundle}"

# Repo + workflow this evidence must have been signed by. Keeps the identity
# pin specific to this pipeline regardless of which branch or PR triggered it.
CERT_IDENTITY_REGEXP='^https://github\.com/JoelF-GRC/GRC_Club_Project/\.github/workflows/grc-gate\.yml@refs/.*$'
CERT_OIDC_ISSUER='https://token.actions.githubusercontent.com'

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# 1. INTEGRITY
#    Recompute the SHA-256 of the bundle and compare it to the hash recorded
#    in the sidecar. Compare hash values directly rather than running
#    `sha256sum -c` against the sidecar: -c also checks the filename recorded
#    in the sidecar against a file of that same name in the cwd, which breaks
#    the moment the bundle being checked has a different name or path (e.g.
#    the tampered copy in the deliverable's tamper test).
if [[ ! -f "$BUNDLE" ]]; then
  echo "INTEGRITY FAIL: bundle not found: $BUNDLE" >&2
  exit 1
fi
if [[ ! -f "$SHA_SIDECAR" ]]; then
  echo "INTEGRITY FAIL: sidecar not found: $SHA_SIDECAR" >&2
  exit 1
fi

expected_sha="$(awk '{print $1}' "$SHA_SIDECAR")"
actual_sha="$(sha256_of "$BUNDLE")"

if [[ "$actual_sha" != "$expected_sha" ]]; then
  echo "INTEGRITY FAIL: $BUNDLE does not match $SHA_SIDECAR" >&2
  echo "  expected: $expected_sha" >&2
  echo "  actual:   $actual_sha" >&2
  exit 1
fi
echo "INTEGRITY OK"

# 2. AUTHENTICITY
#    Verify the bundle against the Cosign signature bundle, pinning both the
#    OIDC issuer and the signing identity. Pinning the issuer alone is not
#    enough: it only proves "signed by some GitHub Actions workflow
#    somewhere," not "signed by this repo's grc-gate workflow specifically."
if [[ ! -f "$SIG_BUNDLE" ]]; then
  echo "AUTHENTICITY FAIL: signature bundle not found: $SIG_BUNDLE" >&2
  exit 1
fi

if ! cosign verify-blob \
  --bundle "$SIG_BUNDLE" \
  --certificate-oidc-issuer "$CERT_OIDC_ISSUER" \
  --certificate-identity-regexp "$CERT_IDENTITY_REGEXP" \
  "$BUNDLE" >/dev/null 2>&1; then
  echo "AUTHENTICITY FAIL: signature does not verify for $BUNDLE" >&2
  exit 1
fi
echo "AUTHENTICITY OK"

# 3. PRESERVATION (stretch)
#    Only runs if VAULT_BUCKET and VAULT_KEY are set, since the Object Lock
#    vault is optional stretch infrastructure this repo has not built yet.
#    Confirms the object's retention date is still in the future, meaning it
#    cannot currently be overwritten or deleted, even by an account owner.
if [[ -n "${VAULT_BUCKET:-}" && -n "${VAULT_KEY:-}" ]]; then
  retain_until="$(aws s3api get-object-retention \
    --bucket "$VAULT_BUCKET" \
    --key "$VAULT_KEY" \
    --query 'Retention.RetainUntilDate' \
    --output text)"

  if [[ -z "$retain_until" || "$retain_until" == "None" ]]; then
    echo "PRESERVATION FAIL: no retention set on s3://${VAULT_BUCKET}/${VAULT_KEY}" >&2
    exit 1
  fi

  retain_epoch="$(date -d "$retain_until" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "${retain_until%%.*}" +%s)"
  now_epoch="$(date +%s)"

  if (( retain_epoch <= now_epoch )); then
    echo "PRESERVATION FAIL: retention on s3://${VAULT_BUCKET}/${VAULT_KEY} already expired ($retain_until)" >&2
    exit 1
  fi
  echo "PRESERVATION OK (retained until $retain_until)"
else
  echo "PRESERVATION SKIPPED (VAULT_BUCKET/VAULT_KEY not set, stretch vault not configured)"
fi

echo "CHAIN INTACT"
