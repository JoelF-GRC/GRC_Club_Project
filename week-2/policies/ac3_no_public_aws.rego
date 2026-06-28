# METADATA
# title: AC-3 - Access Enforcement (AWS S3 public access block)
# description: Every aws_s3_bucket must have a public access block with all four flags true.
# custom:
#   control_id: AC-3
#   framework: nist-800-53
#   severity: critical
#   remediation: Add aws_s3_bucket_public_access_block referencing the bucket, all four flags true.
package compliance.ac3_aws

import rego.v1

# Deny any aws_s3_bucket that lacks a public access block with all four flags
# set to true. The bucket is matched by reference (the public access block's
# expressions.bucket.references points back at "aws_s3_bucket.<name>"), then the
# four flag values are read from planned_values to confirm each is true.
deny contains msg if {
    some bucket in input.configuration.root_module.resources
    bucket.type == "aws_s3_bucket"

    not pab_exists_for(bucket)

    msg := sprintf(
        "AC-3: aws_s3_bucket.%s has no public access block with all four flags true. Add aws_s3_bucket_public_access_block referencing this bucket with all four flags set to true.",
        [bucket.name]
    )
}

pab_exists_for(bucket) if {
    # Find the public access block in configuration that references this bucket
    some pab_config in input.configuration.root_module.resources
    pab_config.type == "aws_s3_bucket_public_access_block"
    some ref in pab_config.expressions.bucket.references
    startswith(ref, sprintf("aws_s3_bucket.%s", [bucket.name]))

    # Find the same resource in planned_values and confirm all four flags are true
    some pab_values in input.planned_values.root_module.resources
    pab_values.address == sprintf("aws_s3_bucket_public_access_block.%s", [pab_config.name])
    pab_values.values.block_public_acls == true
    pab_values.values.block_public_policy == true
    pab_values.values.ignore_public_acls == true
    pab_values.values.restrict_public_buckets == true
}