# Security policy

Report vulnerabilities privately through GitHub Security Advisories. Command injection through working-directory handling, unsafe executable discovery, credential exposure, unexpected downloads, destructive filesystem behavior, and unreviewed privilege escalation are in scope.

The launcher intentionally does not request elevation, install software, read API keys, or connect to external services. Each AI CLI retains responsibility for its own authentication, network activity, permissions, and data policy.
