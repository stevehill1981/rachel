# Security Policy

## Supported Versions

Currently, only the latest version of Rachel is being actively maintained with security updates.

| Version | Supported          |
| ------- | ------------------ |
| main    | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability within Rachel, please send an email to the repository owner through GitHub. All security vulnerabilities will be promptly addressed.

Please include the following information:

- Type of issue (e.g., buffer overflow, SQL injection, cross-site scripting, etc.)
- Full paths of source file(s) related to the manifestation of the issue
- The location of the affected source code (tag/branch/commit or direct URL)
- Any special configuration required to reproduce the issue
- Step-by-step instructions to reproduce the issue
- Proof-of-concept or exploit code (if possible)
- Impact of the issue, including how an attacker might exploit the issue

## Security Updates

Security updates will be released as soon as possible after a vulnerability is confirmed. Users will be notified through:

1. GitHub Security Advisories
2. Release notes
3. Direct communication for critical vulnerabilities

## Best Practices

When deploying Rachel:

1. Always use HTTPS in production
2. Keep dependencies up to date (Dependabot helps with this)
3. Use strong session secrets
4. Enable CSRF protection (already enabled by default in Phoenix)
5. Regularly review security logs
6. Follow the principle of least privilege for database access

## Dependencies

This project uses automated dependency scanning through:

- Dependabot for dependency updates
- `mix deps.audit` for vulnerability scanning
- Sobelow for Elixir-specific security analysis

Run `mix sobelow` locally to check for security issues.