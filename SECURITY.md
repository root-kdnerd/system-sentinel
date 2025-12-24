# 🛡️ Security Policy

## Supported Versions

| Version | Supported          |
|---------|--------------------|
| 2.0.x   | ✅ Yes              |
| < 2.0   | ❌ No               |

## 🐛 Reporting a Vulnerability

If you discover a security vulnerability in System Sentinel, we appreciate your help in disclosing it to us responsibly.

### How to Report

**Please do NOT open a public issue** for security vulnerabilities.

Instead, send an email to: **security@system-sentinel.dev**

Include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if known)

### What to Expect

- We will acknowledge receipt within 24 hours
- We will provide a detailed response within 48 hours
- We will work with you to understand and resolve the issue
- We will notify you when the fix is released

### Disclosure Timeline

- We will fix vulnerabilities within a reasonable timeframe
- We will announce the security fix publicly once it's released
- We will credit you for discovering the vulnerability (if you wish)

## 🔒 Security Best Practices

When using System Sentinel:

1. **Never commit secrets** - Use environment variables or config files in `.gitignore`
2. **Secure your configuration** - Set proper file permissions on `config/config.conf`
3. **Use SSH keys** - Avoid password-based authentication for remote checks
4. **Regular updates** - Keep the tool updated to the latest version
5. **Monitor logs** - Regularly review `system-sentinel.log` for suspicious activity

## 🛡️ Security Features

System Sentinel includes:

- ✅ No hard-coded secrets
- ✅ Config file in `.gitignore`
- ✅ Environment variable support
- ✅ Secure log handling (no sensitive data logged)
- ✅ Minimal external dependencies

## 🔗 Trusted Sources

Only download System Sentinel from:

- Official GitHub repository: https://github.com/yourusername/system-sentinel
- Official releases page: https://github.com/yourusername/system-sentinel/releases

## 📞 Contact

For security-related questions or concerns:
- Email: security@system-sentinel.dev
- PGP Key: [PGP public key would be linked here]

Thank you for helping keep System Sentinel safe! 🙏