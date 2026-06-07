#!/usr/bin/env python3
"""
PreToolUse hook: blocks dangerous shell commands before Claude executes them.
Exit 2 = block. Error message goes to stderr so Claude can read it.
"""
import json
import re
import sys

try:
    payload = json.load(sys.stdin)
except Exception:
    sys.exit(0)

command = payload.get("tool_input", {}).get("command", "")

BLOCKED_PATTERNS = [
    (
        r"\bterraform\s+(?:-[^\s]+\s+)*apply\b",
        "Use the CI/CD pipeline (GitHub Actions) for apply operations",
    ),
    (
        r"\bterraform\s+(?:-[^\s]+\s+)*destroy\b",
        "Use the CI/CD pipeline (GitHub Actions) for destroy operations",
    ),
    (
        r"\bterraform\s+state\s+(rm|push|mv)\b",
        "Manual state changes require an explicit migration procedure — back up state first",
    ),
    (
        r"\bterraform\s+force-unlock\b",
        "Force unlock requires explicit authorization",
    ),
    (
        r"\bterraform\s+import\b",
        "terraform import requires explicit authorization",
    ),
    (
        r"\baws\s+iam\s+delete-role\b",
        "IAM role deletion requires explicit authorization",
    ),
    (
        r"\baws\s+iam\s+(put-role-policy|attach-role-policy|detach-role-policy)\b",
        "IAM policy modification requires explicit authorization",
    ),
    (
        r"\baws\s+kms\s+(delete-key|disable-key)\b",
        "KMS key deletion/disable can break encrypted resources and is irreversible",
    ),
    (
        r"\baws\s+s3\s+rb\b",
        "S3 bucket removal requires explicit authorization",
    ),
    (
        r"\baws\s+s3\s+rm\b",
        "S3 object removal requires explicit authorization",
    ),
    (
        r"\bgit\s+push\s+(--force|-f)\b",
        "Force push is not allowed",
    ),
    (
        r"\bgit\s+reset\s+--hard\b",
        "Hard reset discards uncommitted work",
    ),
    (
        r"\bgit\s+clean\s+-f\b",
        "Force clean discards uncommitted files",
    ),
    (
        r"\brm\s+-rf\s+/",
        "Recursive removal from root is not allowed",
    ),
]

for pattern, reason in BLOCKED_PATTERNS:
    if re.search(pattern, command):
        print(
            f"Blocked: '{pattern}' matched — {reason}.",
            file=sys.stderr,
        )
        sys.exit(2)

sys.exit(0)
