#!/usr/bin/env python3
"""
Pre-tool hook: blocks dangerous shell commands before Claude executes them.
Exit code 2 = block the command (Claude Code interprets this as "blocked by hook").
"""
import json
import sys

try:
    payload = json.load(sys.stdin)
except Exception:
    sys.exit(0)

command = payload.get("tool_input", {}).get("command", "")

BLOCKED_PATTERNS = [
    ("terraform apply", "Use CI/CD pipeline for apply operations"),
    ("terraform destroy", "Use CI/CD pipeline for destroy operations"),
    ("terraform state rm", "Manual state removal requires explicit authorization"),
    ("terraform state push", "Manual state push requires explicit authorization"),
    ("terraform state mv", "Manual state move requires explicit authorization"),
    ("terraform force-unlock", "Force unlock requires explicit authorization"),
    ("aws iam delete-role", "IAM role deletion requires explicit authorization"),
    ("aws iam put-role-policy", "IAM policy modification requires explicit authorization"),
    ("aws iam attach-role-policy", "IAM policy modification requires explicit authorization"),
    ("aws iam detach-role-policy", "IAM policy modification requires explicit authorization"),
    ("aws kms delete-key", "KMS key deletion is irreversible"),
    ("aws kms disable-key", "KMS key disable can break encrypted resources"),
    ("aws s3 rb", "S3 bucket removal requires explicit authorization"),
    ("git push --force", "Force push is not allowed"),
    ("git push -f ", "Force push is not allowed"),
    ("git reset --hard", "Hard reset discards uncommitted work"),
    ("git clean -f", "Force clean discards uncommitted files"),
    ("rm -rf /", "Recursive removal from root is not allowed"),
]

for pattern, reason in BLOCKED_PATTERNS:
    if pattern in command:
        print(
            json.dumps({
                "decision": "block",
                "reason": f"Blocked: '{pattern}' — {reason}. Use the CI/CD pipeline or perform this action manually."
            })
        )
        sys.exit(2)

sys.exit(0)
