# GRC Club Project

Hands-on labs and demos from GRC Engineering Club. Each week implements a control or set of controls in code, with evidence collected on the way to a passing state. Controls are tracked against NIST and mapped to ISO/IEC 27001:2022 Annex A for cross-framework reference.

## Weeks

| Week | Topic | NIST 800-53 | ISO 27001:2022 Annex A | Location |
|------|-------|-------------|--------------------------|----------|
| 1 | S3 bucket hardening (encryption, versioning, public access block, access logging) | SC-28, CM-6, AC-3, AU-3 | A.8.24 (Use of cryptography), A.8.13 (Information backup), A.8.3 (Information access restriction), A.8.15 (Logging) | [week-1](week-1/) |
| 2 | Policy as code: OPA/Rego policies that enforce the Week 1 controls against the Terraform plan, with unit tests and a conftest gate | SC-28, AC-3, CM-6 | A.8.24 (Use of cryptography), A.8.3 (Information access restriction), A.8.9 (Configuration management) | [week-2](week-2/) |

## Structure

Each week is self-contained: infrastructure as code, a verification script, and evidence collected from a real `terraform apply` or equivalent run. Generated state, plan files, and credentials are excluded from version control; see `.gitignore`.
