# Quick Start Guide

Get System Sentinel up and running in 5 minutes.

## Prerequisites

```bash
# Check if you have the required tools
which bash systemctl bc curl
```

Optional (for container monitoring):
```bash
which docker kubectl
```

## Quick Setup

### 1. Install (2 minutes)
```bash
# Download or clone the tool
cd /opt/
git clone <repository-url> system-sentinel
cd system-sentinel

# Make executable
chmod +x system-sentinel.sh

# Create directories
mkdir -p config snapshots reports logs
```

### 2. First Run (1 minute)
```bash
# Run a health check
./system-sentinel.sh check

# Or use interactive mode
./system-sentinel.sh
```

### 3. Configure (1 minute)
```bash
# Set up your alert thresholds
./system-sentinel.sh

# Select option 14 (Configure Alerts)
# Enter your email/Slack webhook
# Set thresholds (default: 80%)
```

### 4. Deploy to CI/CD (1 minute)

#### GitHub Actions
```yaml
# Add to .github/workflows/health-check.yml
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

#### GitLab CI
```yaml
# Add to .gitlab-ci.yml
health-check:
  script:
    - chmod +x system-sentinel/system-sentinel.sh
    - ./system-sentinel/system-sentinel.sh ci-check
```

## Common Use Cases

### Scenario 1: Monitor a Linux Server
```bash
# Start continuous monitoring
nohup ./system-sentinel.sh watch > /dev/null 2>&1 &

# Check logs
tail -f system-sentinel.log
```

### Scenario 2: Pre-Deployment Check
```bash
# Take snapshot before deployment
./system-sentinel.sh snapshot pre-deploy

# Run health check
./system-sentinel.sh ci-check

# If healthy, deploy your application
./deploy.sh

# Take snapshot after deployment
./system-sentinel.sh snapshot post-deploy

# Compare snapshots
./system-sentinel.sh
# Select option 9 (Compare Snapshots)
```

### Scenario 3: Monitor Docker Containers
```bash
# Check container health
./system-sentinel.sh docker

# If containers failed, restart them
./system-sentinel.sh
# Select option 13 (Restart Failed Containers)
```

### Scenario 4: Kubernetes Pod Monitoring
```bash
# Check all pods across namespaces
./system-sentinel.sh k8s

# Watch mode includes K8s checks
./system-sentinel.sh watch
```

### Scenario 5: Generate Daily Report
```bash
# Add to crontab for daily reports
# 0 6 * * * cd /opt/system-sentinel && ./system-sentinel.sh report
```

## Troubleshooting

### Docker not working?
```bash
# Check if Docker daemon is running
docker ps

# Make sure script has access to docker.sock
sudo chmod 666 /var/run/docker.sock
```

### Kubernetes not connecting?
```bash
# Check kubectl configuration
kubectl config view

# Test connection
kubectl cluster-info

# Check current context
kubectl config current-context
```

### Permission denied errors?
```bash
# Run with sudo if needed
sudo ./system-sentinel.sh check
```

### High CPU/Memory alerts?
```bash
# Lower thresholds
./system-sentinel.sh
# Select option 14 (Configure Alerts)
# Set CPU to 90%, Memory to 90%
```

## Next Steps

- Set up email/Slack alerts for notifications
- Integrate into CI/CD pipeline
- Add to monitoring dashboard
- Configure scheduled checks with cron
- Set up log rotation

## Getting Help

```bash
# View all options
./system-sentinel.sh help

# Check logs
tail -100 system-sentinel.log

# Generate HTML report
./system-sentinel.sh report
# Open reports/report-YYYYMMDD.html in browser
```