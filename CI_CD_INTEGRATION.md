# CI/CD Integration Examples

## Quick Start

### 1. Basic Health Check in Pipeline

```bash
#!/bin/bash
./system-sentinel.sh ci-check
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
  echo "Health check failed!"
  exit 1
fi
```

### 2. Parse JSON Output

```bash
#!/bin/bash
OUTPUT=$(./system-sentinel.sh ci-check)
STATUS=$(echo $OUTPUT | jq -r '.status')
CPU=$(echo $OUTPUT | jq '.checks.resources.cpu')
echo "Status: $STATUS, CPU: $CPU%"
```

### 3. Save Report as Artifact

```bash
#!/bin/bash
./system-sentinel.sh ci-check > health-report.json
# Upload health-report.json as pipeline artifact
```

## GitHub Actions Examples

### Pre-Deployment Gate

```yaml
name: Deployment Pipeline

on:
  push:
    branches: [main]

jobs:
  health-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Check System Health
        run: |
          chmod +x system-sentinel/system-sentinel.sh
          ./system-sentinel/system-sentinel.sh ci-check
```

### Slack Alert on Failure

```yaml
      - name: Send Slack Alert
        if: failure()
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "🚨 System health check failed in ${{ github.repository }}"
            }
```

## GitLab CI Examples

### Basic Health Check Job

```yaml
health-check:
  script:
    - chmod +x system-sentinel/system-sentinel.sh
    - ./system-sentinel/system-sentinel.sh ci-check > report.json
    - STATUS=$(cat report.json | jq -r '.status')
    - test "$STATUS" = "healthy"
  artifacts:
    paths:
      - system-sentinel/report.json
    when: always
```

### Pre/Post Deployment Snapshots

```yaml
stages:
  - before-deploy
  - deploy
  - after-deploy

pre-snapshot:
  stage: before-deploy
  script:
    - chmod +x system-sentinel/system-sentinel.sh
    - ./system-sentinel/system-sentinel.sh snapshot before-$CI_PIPELINE_ID
  artifacts:
    paths:
      - system-sentinel/snapshots/
    expire_in: 1 week

deploy:
  stage: deploy
  script:
    - ./deploy.sh

post-snapshot:
  stage: after-deploy
  script:
    - chmod +x system-sentinel/system-sentinel.sh
    - ./system-sentinel/system-sentinel.sh snapshot after-$CI_PIPELINE_ID
  artifacts:
    paths:
      - system-sentinel/snapshots/
    expire_in: 1 week
```

## Jenkins Examples

### Jenkinsfile

```groovy
pipeline {
    agent any
    
    stages {
        stage('Health Check') {
            steps {
                sh '''
                    chmod +x system-sentinel/system-sentinel.sh
                    ./system-sentinel/system-sentinel.sh ci-check > health.json
                '''
                script {
                    def health = readJSON file: 'health.json'
                    if (health.status != 'healthy') {
                        error("System health check failed!")
                    }
                }
            }
        }
        
        stage('Deploy') {
            steps {
                sh './deploy.sh'
            }
        }
        
        stage('Post-Deploy Check') {
            steps {
                sh './system-sentinel/system-sentinel.sh ci-check'
            }
        }
    }
}
```

## Advanced Usage

### Conditional Deployment Based on Health

```bash
#!/bin/bash
HEALTH=$(./system-sentinel.sh ci-check)
STATUS=$(echo $HEALTH | jq -r '.status')

if [ "$STATUS" = "healthy" ]; then
  CPU=$(echo $HEALTH | jq '.checks.resources.cpu')
  if [ $(echo "$CPU < 80" | bc) -eq 1 ]; then
    echo "Safe to deploy. CPU usage: $CPU%"
    ./deploy.sh
  else
    echo "Cannot deploy. CPU too high: $CPU%"
    exit 1
  fi
else
  echo "System unhealthy, aborting deployment"
  exit 1
fi
```

### Monitor Specific Services

```bash
#!/bin/bash
# Check if specific services are healthy
HEALTH=$(./system-sentinel.sh ci-check)
SERVICES=$(echo $HEALTH | jq -c '.checks.services.data[]')

for service in $(echo "$SERVICES" | jq -r '.name'); do
  if echo "$service" | grep -q "nginx\|postgresql"; then
    echo "Checking $service..."
    STATE=$(echo "$service" | jq -r '.state')
    if [ "$STATE" != "active" ]; then
      echo "$service is not healthy: $STATE"
      exit 1
    fi
  fi
done
```

### Integration with Monitoring Tools

```bash
#!/bin/bash
# Send metrics to Prometheus Pushgateway
HEALTH=$(./system-sentinel.sh ci-check)
CPU=$(echo $HEALTH | jq '.checks.resources.cpu')
MEM=$(echo $HEALTH | jq '.checks.resources.memory')
DISK=$(echo $HEALTH | jq '.checks.disk.data[0].usage')

cat <<EOF | curl --data-binary @- http://pushgateway:9091/metrics/job/system-sentinel
# HELP sentinel_cpu_usage CPU usage percentage
# TYPE sentinel_cpu_usage gauge
sentinel_cpu_usage $CPU
# HELP sentinel_memory_usage Memory usage percentage
# TYPE sentinel_memory_usage gauge
sentinel_memory_usage $MEM
# HELP sentinel_disk_usage Disk usage percentage
# TYPE sentinel_disk_usage gauge
sentinel_disk_usage $DISK
EOF
```

### Alert on Degradation

```bash
#!/bin/bash
CURRENT=$(./system-sentinel.sh ci-check)
CURRENT_CPU=$(echo $CURRENT | jq '.checks.resources.cpu')
CURRENT_MEM=$(echo $CURRENT | jq '.checks.resources.memory')

# Load previous metrics
PREV_FILE="last-check.json"
if [ -f "$PREV_FILE" ]; then
  PREV=$(cat "$PREV_FILE")
  PREV_CPU=$(echo $PREV | jq '.checks.resources.cpu')
  
  # Check for significant increase
  CPU_DIFF=$(echo "$CURRENT_CPU - $PREV_CPU" | bc)
  if [ $(echo "$CPU_DIFF > 20" | bc) -eq 1 ]; then
    echo "⚠️ CPU usage increased by $CPU_DIFF%!"
    # Send alert notification
  fi
fi

# Save current for next time
echo "$CURRENT" > "$PREV_FILE"
```

## Exit Codes

- `0` - System is healthy
- `1` - System has issues found
- `2` - Command execution error

## CI Platform Specific Notes

### GitHub Actions
- Use `::notice::`, `::warning::`, `::error::` for step annotations
- Upload JSON reports as artifacts
- Create issues or PR comments for alerts

### GitLab CI
- Use GitLab-specific variables (`$CI_PIPELINE_ID`)
- Store artifacts for comparison
- Use `rules` for conditional execution

### Jenkins
- Use `readJSON` step for parsing
- Integrate with built-in warnings plugin
- Archive JSON reports

### Azure DevOps
- Use `logging commands` (`##vso[task.logissue]`)
- Publish test results
- Use pipeline artifacts for reports