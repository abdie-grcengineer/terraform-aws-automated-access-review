package terraform.s3.public_access

import rego.v1

# NIST 800-53 AC-3 (Access Enforcement), SC-7 (Boundary Protection)
# CMMC AC.L2-3.1.3 — Control the flow of CUI in accordance with approved authorizations

required_flags := ["block_public_acls", "block_public_policy", "ignore_public_acls", "restrict_public_buckets"]

deny contains msg if {
    some resource in input.resource_changes
    resource.type == "aws_s3_bucket_public_access_block"

    some action in resource.change.actions
    action != "delete"

    some flag in required_flags
    not resource.change.after[flag]

    msg := sprintf("S3 public access block %s has %s = false (violates NIST 800-53 AC-3)", [resource.address, flag])
}
