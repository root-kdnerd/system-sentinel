# Changelog

All notable changes to System Sentinel will be documented in this file.

## [2.0.0] - 2024-12-24

### Added
- Docker container monitoring with health checks
- Kubernetes pod monitoring across namespaces
- Kubernetes node status checks
- Docker system disk usage monitoring
- Auto-restart failed containers feature
- Container status in snapshots
- K8s pod/node info in snapshots
- `docker` command for container-only checks
- `k8s` command for Kubernetes-only checks
- Docker deployment support (Dockerfile)
- Docker Compose configuration
- CONTRIBUTING.md for contributors
- CHANGELOG.md for version tracking

### Changed
- Version bump to 2.0.0
- Updated README with Docker/K8s documentation
- Enhanced menu system (now 16 options)
- CI/CD JSON output includes containers and K8s data
- Full check now includes Docker and Kubernetes

### Fixed
- Menu loop bug causing infinite loop
- Help command not showing menu properly
- CI mode not including all checks

## [1.0.0] - 2024-12-24

### Added
- Initial release
- Disk space monitoring with threshold alerts
- SystemD service health checks
- System resource monitoring (CPU, memory, load)
- Log analysis with pattern matching
- System snapshots
- HTML report generation
- Email and Slack alerting
- CI/CD mode with JSON output
- GitHub Actions workflows
- GitLab CI/CD templates
- Auto-cleanup for old files
- Auto-restart failed services
- Watch mode for continuous monitoring