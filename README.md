# 🛡️ System Sentinel

<div align="center">

![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![Bash](https://img.shields.io/badge/bash-4.0+-yellow.svg)
![Platform](https://img.shields.io/badge/platform-Linux-lightgrey.svg)

*A comprehensive DevOps monitoring and remediation tool written in Bash*

[Features](#-features) • [Quick Start](#-quick-start) • [Documentation](#-documentation) • [Contributing](#-contributing) • [License](#-license)

</div>

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| 📊 **Disk Monitoring** | Alerts on low disk space, shows largest files |
| 🔄 **Service Health** | Monitors systemd services, auto-restarts failed ones |
| 🐳 **Docker Containers** | Tracks container status, health, and resource usage |
| ☸️ **Kubernetes Pods** | Monitors pods across all namespaces |
| 💾 **Log Analysis** | Searches for ERROR/CRITICAL/FATAL patterns |
| 📈 **Resource Monitoring** | Tracks CPU, memory, and load average |
| 📸 **System Snapshots** | Captures system state for comparison |
| 📄 **HTML Reports** | Beautiful visual reports |
| 📧 **Alerts** | Email and Slack notifications |
| 🧹 **Auto-Cleanup** | Removes old files from specified directories |
| 🔄 **CI/CD Ready** | JSON output, exit codes, GitHub/GitLab integrations |

---

## 🚀 Quick Start

### Installation
```bash
git clone https://github.com/yourusername/system-sentinel.git
cd system-sentinel
chmod +x system-sentinel.sh
```

### Run Health Check
```bash
./system-sentinel.sh check
```

### Interactive Mode
```bash
./system-sentinel.sh
```

### CI/CD Mode
```bash
./system-sentinel.sh ci-check | jq
```

### Docker Deployment
```bash
docker-compose up -d
```

---

## 📖 Documentation

| Document | Description |
|----------|-------------|
| [README.md](README.md) | Full documentation |
| [QUICKSTART.md](QUICKSTART.md) | 5-minute setup guide |
| [CI_CD_INTEGRATION.md](CI_CD_INTEGRATION.md) | CI/CD integration examples |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Contribution guidelines |
| [CHANGELOG.md](CHANGELOG.md) | Version history |

---

## 🎯 Usage Examples

### Monitor Docker Containers
```bash
./system-sentinel.sh docker
```
**Output:**
```
[2024-12-24 10:30:00] [INFO] Checking Docker containers...
[2024-12-24 10:30:00] [INFO] Docker images: 5, Volumes: 3
[2024-12-24 10:30:00] [INFO] Containers: total=10, running=8, stopped=2, unhealthy=0
```

### Check Kubernetes Pods
```bash
./system-sentinel.sh k8s
```
**Output:**
```
[2024-12-24 10:30:00] [INFO] Checking Kubernetes pods...
[2024-12-24 10:30:00] [INFO] Kubernetes nodes: 3/3 ready
[2024-12-24 10:30:00] [WARN] Pod nginx-ingress in namespace kube-system is Pending
```

### Take System Snapshot
```bash
./system-sentinel.sh snapshot before-deploy
```

### Generate HTML Report
```bash
./system-sentinel.sh report
# Open reports/report-20241224.html
```

### Continuous Monitoring
```bash
./system-sentinel.sh watch
# Runs checks every 5 minutes
```

---

## 📊 CI/CD Integration

### GitHub Actions
```yaml
name: Health Check
on: [push]
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - run: |
          chmod +x system-sentinel/system-sentinel.sh
          ./system-sentinel/system-sentinel.sh ci-check
```

### GitLab CI
```yaml
health-check:
  script:
    - chmod +x system-sentinel/system-sentinel.sh
    - ./system-sentinel/system-sentinel.sh ci-check
```

---

## 🔧 Configuration

Create `config/config.conf`:
```bash
DISK_THRESHOLD=80        # Alert when disk usage > 80%
CPU_THRESHOLD=80         # Alert when CPU usage > 80%
MEM_THRESHOLD=80         # Alert when memory > 80%
ALERT_EMAIL="you@example.com"
SLACK_WEBHOOK="https://hooks.slack.com/services/..."
```

---

## 🌟 Requirements

### Base
- ✅ Bash 4.0+
- ✅ systemctl (for service monitoring)
- ✅ Standard Linux utilities (df, free, ps, etc.)

### Optional
- 🐳 Docker (for container monitoring)
- ☸️ kubectl (for Kubernetes monitoring)
- 🔢 bc (for floating point calculations)

---

## 📋 Available Commands

```bash
./system-sentinel.sh check        # Full system check
./system-sentinel.sh ci-check     # CI/CD mode with JSON output
./system-sentinel.sh disk         # Check disk space
./system-sentinel.sh services     # Check service health
./system-sentinel.sh docker       # Check Docker containers
./system-sentinel.sh k8s          # Check Kubernetes pods
./system-sentinel.sh logs         # Analyze logs
./system-sentinel.sh resources    # Check system resources
./system-sentinel.sh snapshot     # Take system snapshot
./system-sentinel.sh report       # Generate HTML report
./system-sentinel.sh cleanup      # Cleanup old files
./system-sentinel.sh config       Show configuration
./system-sentinel.sh watch        # Continuous monitoring
./system-sentinel.sh help         # Show help
```

---

## 🤝 Contributing

<div align="center">

### We Need Your Help! 🙏

![Contributors welcome](https://img.shields.io/badge/contributions-welcome-brightgreen.svg?style=flat-square)

</div>

We welcome contributions from everyone! Whether you're fixing bugs, adding features, improving documentation, or just reporting issues, your help is greatly appreciated.

### How to Contribute

1. 🍴 **Fork** the repository
2. 🌿 **Create a branch** for your feature or bugfix
   ```bash
   git checkout -b feature/amazing-feature
   ```
3. 💻 **Make your changes** following our [Contributing Guidelines](CONTRIBUTING.md)
4. 🧪 **Test your changes** thoroughly
   ```bash
   ./system-sentinel.sh check
   ./system-sentinel.sh ci-check | jq
   ```
5. 📝 **Commit** with clear, descriptive messages
6. 📤 **Push** to your fork
7. 🔄 **Create a Pull Request** explaining your changes

### Areas Where We Need Help

- 🔬 **New Monitoring Checks**
  - Redis/MongoDB monitoring
  - Nginx/Apache metrics
  - Database connection checks
  - SSL certificate expiry monitoring

- 🎨 **UI/UX Improvements**
  - Web dashboard
  - Real-time monitoring interface
  - Better visualization

- 🔌 **Integrations**
  - Prometheus/Grafana
  - Elasticsearch/Logstash
  - PagerDuty/ServiceNow
  - Microsoft Teams

- 📚 **Documentation**
  - Tutorials and guides
  - Video demos
  - Translation to other languages

- 🧪 **Testing**
  - Unit tests
  - Integration tests
  - CI/CD improvements

### Coding Standards

- Use `log()` function for all output
- Return 0 for success, non-zero for failure
- Set `*_DATA` variable for JSON output
- Follow existing indentation (4 spaces)
- Keep functions focused and single-purpose

### Getting Started

Read our [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines and development setup instructions.

---

## 📜 License

<div align="center">

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

![MIT](https://img.shields.io/badge/License-MIT-yellow.svg)

</div>

---

## 🙏 Acknowledgments

- Built with ❤️ for DevOps engineers
- Inspired by community monitoring tools
- Made possible by contributors like you

---

## 📞 Support

- 📧 Email: support@system-sentinel.dev
- 💬 Discord: [Join our server](https://discord.gg/system-sentinel)
- 🐛 Issues: [Report a bug](https://github.com/yourusername/system-sentinel/issues)
- 💡 Ideas: [Suggest a feature](https://github.com/yourusername/system-sentinel/issues/new?template=feature_request.md)

---

## ⭐ Star History

<div align="center">

If this project helped you, please consider giving it a star ⭐

[![Star History Chart](https://api.star-history.com/svg?repos=yourusername/system-sentinel&type=Date)](https://star-history.com/#yourusername/system-sentinel&Date)

</div>

---

<div align="center">

**Made with ❤️ by the System Sentinel Community**

[⬆ Back to Top](#-system-sentinel)

</div>