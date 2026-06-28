# Week 2: Policy as Code for NIST controls

Week 1 built a hardened S3 setup in Terraform. Week 2 makes the rules that hardening satisfies executable, so a non-compliant change is caught before `terraform apply` rather than in a later audit.

This lab writes three Open Policy Agent (OPA) policies in Rego, each enforcing one NIST 800-53 control against the Terraform plan, and runs them two ways: as unit tests that define correct behavior, and with conftest as a gate against the real Week 1 plan.

## Controls enforced

| Policy | NIST 800-53 | ISO 27001:2022 Annex A | Rule |
|--------|-------------|------------------------|------|
| sc28_encryption_aws | SC-28 Protection of Information at Rest | A.8.24 Use of cryptography | Every S3 bucket must have a server-side encryption configuration. |
| ac3_no_public_aws | AC-3 Access Enforcement | A.8.3 Information access restriction | Every S3 bucket must have a public access block with all four flags set to true. |
| cm6_required_tags_aws | CM-6 Configuration Settings | A.8.9 Configuration management | Every taggable resource must carry the four required tags: Project, Environment, ManagedBy, ComplianceScope. |

## How it works

OPA evaluates the JSON form of a Terraform plan. Each policy raises a `deny` message that names the resource and the fix when a control is not met.

The main technique is reference matching. At plan time the bucket name is not known, because it includes a random suffix generated at apply time. A policy therefore cannot match a bucket to its encryption or public-access-block resource by name or value. It matches by reference instead: a child resource records the bucket it belongs to under `expressions.bucket.references` as a string like `aws_s3_bucket.primary.id`, and the policy reads the flag and tag values from `planned_values`.

CM-6 evaluates only resources that actually support tagging. The AWS provider exposes `tags_all`, the merged tag set including provider `default_tags`, only on resource types that can carry tags. Using the presence of `tags_all` as the taggable test keeps the policy from raising false positives on resources that cannot be tagged at all, such as a public access block or a random_id.

## Layout

```
week-2/
  policies/
    sc28_encryption_aws.rego          SC-28 policy
    sc28_encryption_aws_test.rego     spec, do not edit
    ac3_no_public_aws.rego            AC-3 policy
    ac3_no_public_aws_test.rego       spec, do not edit
    cm6_required_tags_aws.rego        CM-6 policy
    cm6_required_tags_aws_test.rego   spec, do not edit
  evidence/
    opa-test-output.txt               unit test run
    conftest-output.txt               policy run against the Week 1 plan
  plan.json                           Week 1 plan in JSON, the conftest input
```

## Run it

Unit tests:

```bash
opa test policies/ -v
```

Against the real Week 1 plan:

```bash
# in week-1, regenerate the plan and export it to JSON
terraform plan -out=tfplan
terraform show -json tfplan > ../week-2/plan.json

# in week-2, run all three policies
conftest test --policy policies --all-namespaces plan.json
```

## Results

- `opa test`: 6 of 6 tests pass. Each policy has one test for a compliant plan, expecting no denial, and one for a non-compliant plan, expecting a denial. Captured in `evidence/opa-test-output.txt`.
- `conftest` against the hardened Week 1 plan: 3 of 3 policies pass, captured in `evidence/conftest-output.txt`. Both the primary and log buckets carry encryption, a four-flag public access block, and the four required tags.

## Relationship to Week 1

Week 1 is the infrastructure. Week 2 is the control that proves the infrastructure stays compliant. Running the policies against the Week 1 plan also surfaced a real gap during development: the log bucket was missing the encryption and public access block that the primary bucket already had. That was fixed in Week 1 before this evidence was regenerated, which is the point of policy as code. The check finds the gap before the resource ships, not after.
