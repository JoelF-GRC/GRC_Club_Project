# METADATA
# title: CM-6 - Configuration Settings (AWS required tags)
# description: Taggable resources must carry the four required compliance tags.
# custom:
#   control_id: CM-6
#   framework: nist-800-53
#   severity: medium
#   remediation: Add the missing tags or rely on provider default_tags.
package compliance.cm6_aws

import rego.v1

required := {"Project", "Environment", "ManagedBy", "ComplianceScope"}

# Deny any taggable resource that is missing one or more required tags.
#
# Only resources that support tagging are evaluated. The AWS provider exposes
# tags_all (the merged set, including provider default_tags) only on resource
# types that can carry tags, so binding tags_all both reads the tag set and
# acts as the "is taggable" guard. Without this, the rule fires on resources
# that cannot be tagged at all (for example aws_s3_bucket_public_access_block,
# aws_s3_bucket_versioning, or random_id), producing false positives.
deny contains msg if {
    some resource in input.planned_values.root_module.resources
    tags_all := resource.values.tags_all

    some tag in required
    not tags_all[tag]

    msg := sprintf(
        "CM-6: %s is missing required tag '%s'. Add it via provider default_tags or directly on the resource.",
        [resource.address, tag]
    )
}