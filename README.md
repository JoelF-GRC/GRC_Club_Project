# GRC Club Project

Hands-on labs and demos from [GRC Engineering Club](https://grcengclub.com/), a community of GRC professionals who want to build the technical skills to implement and enforce controls in code, moving past written policies. Each week, the GRC Club releases assignments that challenge you to implement a control or set of controls in code, with evidence collected on the way to a passing state. Controls are tracked against NIST, and I have further mapped to ISO/IEC 27001:2022 Annex A for cross-framework reference.

This is an ongoing series, worked week by week. New weeks are added here as each lab is released, so the set grows over time rather than a single commit or pull request (PR).

## Weeks

| Week | Topic | NIST 800-53 | ISO 27001:2022 Annex A | Location |
|------|-------|-------------|--------------------------|----------|
| 1 | S3 bucket hardening (encryption, versioning, public access block, access logging) | SC-28, CM-6, AC-3, AU-3 | A.8.24 (Use of cryptography), A.8.13 (Information backup), A.8.3 (Information access restriction), A.8.15 (Logging) | [week-1](week-1/) |
| 2 | Policy as code: OPA/Rego policies that enforce the Week 1 controls against the Terraform plan, with unit tests and a conftest gate | SC-28, AC-3, CM-6 | A.8.24 (Use of cryptography), A.8.3 (Information access restriction), A.8.9 (Configuration management) | [week-2](week-2/) |
| 3 | CI gate: a GitHub Actions workflow that runs the Week 2 conftest policies on every pull request, uploads evidence on every run, and is enforced by branch protection so a control violation blocks the merge | SC-28, AC-3, CM-6 | A.8.24 (Use of cryptography), A.8.3 (Information access restriction), A.8.9 (Configuration management) | [week-3](week-3/) |
| 4 | Chain of custody: the Week 3 gate's evidence is bundled, hashed, and signed keyless with Cosign using the pipeline's own OIDC identity, then checked by a verify script that confirms integrity, authenticity, and retention. Stretch goal done: an S3 Object Lock vault was built, proven to actually block deletion, and torn down the same day | AU-9, SI-7 | A.5.28 (Collection of evidence), A.8.24 (Use of cryptography) | [week-4](week-4/) |

Week 5 onward will be added as the club publishes each lab.

## Structure

Each week is self-contained: infrastructure as code, a verification script, and evidence collected from a real `terraform apply` or equivalent run. Generated state, plan files, and credentials are excluded from version control; see `.gitignore`.
