package terraform.iam.wildcard

import rego.v1

# NIST 800-53 AC-6 (Least Privilege)
# CMMC AC.L2-3.1.5 — Employ the principle of least privilege

is_wildcard(value) if {
    value == "*"
}

is_wildcard(value) if {
    is_array(value)
    some v in value
    v == "*"
}

deny contains msg if {
    some resource in input.resource_changes
    resource.type == "aws_iam_role_policy"

    some action in resource.change.actions
    action != "delete"

    policy := json.unmarshal(resource.change.after.policy)
    some statement in policy.Statement

    statement.Effect == "Allow"
    is_wildcard(statement.Action)
    is_wildcard(statement.Resource)

    msg := sprintf("IAM policy %s has Allow Action=\"*\" on Resource=\"*\" — violates NIST 800-53 AC-6 least privilege", [resource.address])
}
