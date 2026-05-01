package terraform.s3.encryption

import rego.v1

# NIST 800-53 SC-28 (Protection of Information at Rest)
# CMMC SC.L2-3.13.16 — Protect the confidentiality of CUI at rest

valid_algorithms := {"AES256", "aws:kms"}

deny contains msg if {
    some resource in input.resource_changes
    resource.type == "aws_s3_bucket_server_side_encryption_configuration"

    some action in resource.change.actions
    action != "delete"

    some rule in resource.change.after.rule
    some sse in rule.apply_server_side_encryption_by_default

    not valid_algorithms[sse.sse_algorithm]

    msg := sprintf("S3 SSE config %s uses non-compliant algorithm %v (violates NIST 800-53 SC-28)", [resource.address, sse.sse_algorithm])
}
