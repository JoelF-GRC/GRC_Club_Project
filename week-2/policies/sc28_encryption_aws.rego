# METADATA
# title: SC-28 - Encryption at Rest (AWS S3)
# description: Every aws_s3_bucket must have a matching server-side encryption configuration.
# custom:
#   control_id: SC-28
#   framework: nist-800-53
#   severity: high
#   remediation: Add aws_s3_bucket_server_side_encryption_configuration referencing the bucket.
package compliance.sc28_aws

import rego.v1

# Deny any aws_s3_bucket that has no matching server-side encryption
# configuration. At plan time the bucket name is not yet known (the random
# suffix is unresolved), so the bucket cannot be matched by value. Instead the
# encryption resource is matched by reference: its expressions.bucket.references
# entry points back at "aws_s3_bucket.<name>".
deny contains msg if {
    some bucket in input.configuration.root_module.resources
    bucket.type == "aws_s3_bucket"

    not encryption_exists_for(bucket)

    msg := sprintf(
        "SC-28: aws_s3_bucket.%s has no encryption configuration. Add aws_s3_bucket_server_side_encryption_configuration referencing this bucket.",
        [bucket.name]
    )
}

encryption_exists_for(bucket) if {
    some enc in input.configuration.root_module.resources
    enc.type == "aws_s3_bucket_server_side_encryption_configuration"
    some ref in enc.expressions.bucket.references
    startswith(ref, sprintf("aws_s3_bucket.%s", [bucket.name]))
}