#!/bin/bash
# System Sentinel - Comprehensive DevOps Monitoring & Remediation Tool
# Features: Disk, services, Docker, Kubernetes, logs, system snapshots, alerts

VERSION="2.0.0"
BASE_DIR="$(dirname "$(readlink -f "$0")")"
LOG_FILE="$BASE_DIR/system-sentinel.log"
CONFIG_DIR="$BASE_DIR/config"
ALERT_EMAIL=""
SLACK_WEBHOOK=""
DISK_THRESHOLD=80
CPU_THRESHOLD=80
MEM_THRESHOLD=80

mkdir -p "$CONFIG_DIR"
load_config() {
    [[ -f "$CONFIG_DIR/config.conf" ]] && source "$CONFIG_DIR/config.conf"
}
save_config() {
    cat > "$CONFIG_DIR/config.conf" << EOF
DISK_THRESHOLD=$DISK_THRESHOLD
CPU_THRESHOLD=$CPU_THRESHOLD
MEM_THRESHOLD=$MEM_THRESHOLD
ALERT_EMAIL="$ALERT_EMAIL"
SLACK_WEBHOOK="$SLACK_WEBHOOK"
EOF
}
log() {
    local level="$1"
    shift
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*"
    echo "$message" | tee -a "$LOG_FILE"
    [[ "$CI_MODE" == "true" ]] && echo "::notice::$message"
}
json_output() {
    local status="$1"
    shift
    local data="$*"
    cat << JSON
{
  "timestamp": "$(date -Iseconds)",
  "hostname": "$(hostname)",
  "status": "$status",
  "checks": $data
}
JSON
}
send_alert() {
    local subject="$1"
    local message="$2"
    log "ALERT" "$subject: $message"
    [[ -n "$ALERT_EMAIL" ]] && echo "$message" | mail -s "[System Sentinel] $subject" "$ALERT_EMAIL"
    [[ -n "$SLACK_WEBHOOK" ]] && curl -s -X POST -H 'Content-type: application/json' --data "{\"text\":\"[System Sentinel] $subject\n$message\"}" "$SLACK_WEBHOOK" >/dev/null
}
check_disk_space() {
    log "INFO" "Checking disk space..."
    local issues=0
    local disk_json=""
    while read -r fs size used avail percent mount; do
        local usage=${percent%\%}
        if (( usage >= DISK_THRESHOLD )); then
            log "WARN" "Low disk space: $mount at $usage%"
            send_alert "Disk Space Warning" "Mount point $mount is at $usage% capacity"
            issues=1
            if [[ -d "$mount" ]]; then
                log "INFO" "Top 10 largest files in $mount:"
                find "$mount" -type f -exec du -h {} + 2>/dev/null | sort -rh | head -10 | tee -a "$LOG_FILE"
            fi
        fi
        disk_json+="{\"mount\":\"$mount\",\"usage\":$usage,\"size\":\"$size\",\"available\":\"$avail\"},"
    done < <(df -h | grep -vE '^Filesystem|tmpfs|cdrom|overlay')
    [[ -n "$disk_json" ]] && DISK_DATA="[${disk_json%,}]"
    [[ "$CI_MODE" == "true" && "$issues" -eq 1 ]] && echo "::warning::Disk space issue detected"
    return $issues
}
cleanup_old_files() {
    local dir="${1:-/tmp}"
    local days="${2:-7}"
    log "INFO" "Cleaning files older than $days days in $dir"
    local count=$(find "$dir" -type f -mtime +"$days" 2>/dev/null | wc -l)
    if (( count > 0 )); then
        find "$dir" -type f -mtime +"$days" -delete 2>/dev/null
        log "INFO" "Deleted $count files"
    fi
}
check_service_health() {
    log "INFO" "Checking service health..."
    local failed_services=()
    local services_json=""
    if command -v systemctl &>/dev/null; then
        while read -r service state; do
            services_json+="{\"name\":\"$service\",\"state\":\"$state\"},"
            if [[ "$state" != "active" && "$state" != "running" ]]; then
                failed_services+=("$service")
                log "WARN" "Service $service is $state"
            fi
        done < <(systemctl list-units --type=service --state=failed,dead --no-legend | awk '{print $1, $4}' | head -20)
    fi
    [[ -n "$services_json" ]] && SERVICES_DATA="[${services_json%,}]"
    if [[ ${#failed_services[@]} -gt 0 ]]; then
        send_alert "Service Issues" "Failed/dead services: ${failed_services[*]}"
        [[ "$CI_MODE" == "true" ]] && echo "::warning::Service issues detected: ${failed_services[*]}"
    fi
    return ${#failed_services[@]}
}
restart_failed_services() {
    log "INFO" "Attempting to restart failed services..."
    if command -v systemctl &>/dev/null; then
        systemctl list-units --type=service --state=failed --no-legend | awk '{print $1}' | while read -r svc; do
            log "INFO" "Restarting $svc"
            systemctl restart "$svc" && log "INFO" "Successfully restarted $svc" || log "ERROR" "Failed to restart $svc"
        done
    fi
}
analyze_logs() {
    local log_path="${1:-/var/log}"
    local pattern="${2:-ERROR|CRITICAL|FATAL}"
    local hours="${3:-1}"
    local since="$(date -d "$hours hours ago" '+%Y-%m-%d %H:%M:%S')"
    log "INFO" "Analyzing logs for errors in last $hours hours..."
    local errors_found=0
    while IFS= read -r -d '' log_file; do
        local count=$(awk -v since="$since" '$0 " " since >= since && /('"$pattern"')/' "$log_file" 2>/dev/null | wc -l)
        if (( count > 0 )); then
            log "WARN" "Found $count errors in $log_file"
            errors_found=1
            tail -20 "$log_file" | grep -E "$pattern" | tee -a "$LOG_FILE"
        fi
    done < <(find "$log_path" -type f \( -name "*.log" -o -name "syslog*" -o -name "messages*" \) -mmin -"$((hours*60))" -print0 2>/dev/null)
    return $errors_found
}
check_system_resources() {
    log "INFO" "Checking system resources..."
    local issues=0
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    local mem_usage=$(free | grep Mem | awk '{printf("%.0f"), $3/$2 * 100.0}')
    local load_avg=$(uptime | awk -F'load average:' '{print $2}')
    local uptime_p=$(uptime -p)
    local process_count=$(ps aux | wc -l)
    RESOURCES_DATA="{\"cpu\":$cpu_usage,\"memory\":$mem_usage,\"load_average\":\"$load_avg\",\"uptime\":\"$uptime_p\",\"processes\":$process_count}"
    if (( $(echo "$cpu_usage > $CPU_THRESHOLD" | bc -l) )); then
        log "WARN" "High CPU usage: ${cpu_usage}%"
        send_alert "High CPU" "CPU usage at ${cpu_usage}%"
        log "INFO" "Top 5 CPU processes:"
        ps aux --sort=-%cpu | head -6 | tee -a "$LOG_FILE"
        issues=1
        [[ "$CI_MODE" == "true" ]] && echo "::warning::High CPU usage: ${cpu_usage}%"
    fi
    if (( mem_usage > MEM_THRESHOLD )); then
        log "WARN" "High memory usage: ${mem_usage}%"
        send_alert "High Memory" "Memory usage at ${mem_usage}%"
        log "INFO" "Top 5 memory processes:"
        ps aux --sort=-%mem | head -6 | tee -a "$LOG_FILE"
        issues=1
        [[ "$CI_MODE" == "true" ]] && echo "::warning::High memory usage: ${mem_usage}%"
    fi
    log "INFO" "Load average: $load_avg"
    return $issues
}
check_docker_containers() {
    log "INFO" "Checking Docker containers..."
    local issues=0
    local docker_json=""
    
    if ! command -v docker &>/dev/null; then
        log "INFO" "Docker not installed, skipping container checks"
        return 0
    fi
    
    if ! docker info &>/dev/null; then
        log "ERROR" "Cannot connect to Docker daemon"
        DOCKER_DATA="{\"error\":\"Cannot connect to Docker daemon\"}"
        return 1
    fi
    
    local total_containers=$(docker ps -a --format "{{.ID}}" | wc -l)
    local running_containers=$(docker ps --format "{{.ID}}" | wc -l)
    local stopped_containers=$(docker ps -a --filter "status=exited" --format "{{.ID}}" | wc -l)
    local unhealthy_containers=$(docker ps --filter "health=unhealthy" --format "{{.ID}}" | wc -l)
    
    docker_json="{\"total\":$total_containers,\"running\":$running_containers,\"stopped\":$stopped_containers,\"unhealthy\":$unhealthy_containers,\"containers\":["
    
    while IFS= read -r container; do
        local id=$(echo "$container" | awk '{print $1}')
        local name=$(echo "$container" | awk '{print $2}')
        local status=$(echo "$container" | awk '{print $3}')
        local health=$(echo "$container" | awk '{print $4}')
        
        docker_json+="{\"id\":\"$id\",\"name\":\"$name\",\"status\":\"$status\",\"health\":\"$health\"},"
        
        if [[ "$status" != "Up" ]]; then
            log "WARN" "Container $name is not running (status: $status)"
            issues=1
        fi
        
        if [[ "$health" == "unhealthy" ]]; then
            log "WARN" "Container $name is unhealthy"
            send_alert "Container Unhealthy" "Container $name is unhealthy"
            issues=1
        fi
    done < <(docker ps -a --format "{{.ID}} {{.Names}} {{.Status}}" | head -20)
    
    docker_json+="]}"
    DOCKER_DATA="${docker_json%]},[]}"
    DOCKER_DATA="[${docker_json%}]}"
    
    if [[ $unhealthy_containers -gt 0 ]]; then
        log "WARN" "Found $unhealthy_containers unhealthy container(s)"
        [[ "$CI_MODE" == "true" ]] && echo "::warning::Found unhealthy Docker containers"
    fi
    
    if [[ $stopped_containers -gt 0 ]]; then
        log "INFO" "Found $stopped_containers stopped container(s)"
    fi
    
    return $issues
}
check_docker_system() {
    log "INFO" "Checking Docker system..."
    local issues=0
    
    if ! command -v docker &>/dev/null; then
        return 0
    fi
    
    local docker_disk_usage=$(docker system df --format "{{.Size}}" | head -1)
    local images_count=$(docker images --format "{{.ID}}" | wc -l)
    local volumes_count=$(docker volume ls --format "{{.Name}}" | wc -l)
    
    log "INFO" "Docker images: $images_count, Volumes: $volumes_count"
    
    if [[ -n "$docker_disk_usage" ]]; then
        log "INFO" "Docker disk usage: $docker_disk_usage"
    fi
    
    return $issues
}
restart_failed_containers() {
    log "INFO" "Attempting to restart failed containers..."
    
    if ! command -v docker &>/dev/null; then
        log "WARN" "Docker not installed"
        return 1
    fi
    
    local restarted=0
    while IFS= read -r container; do
        local name=$(docker ps -a --filter "id=$container" --format "{{.Names}}")
        local status=$(docker ps -a --filter "id=$container" --format "{{.Status}}")
        
        if [[ ! "$status" =~ Up ]]; then
            log "INFO" "Restarting container: $name"
            if docker start "$container" &>/dev/null; then
                log "INFO" "Successfully restarted $name"
                ((restarted++))
            else
                log "ERROR" "Failed to restart $name"
            fi
        fi
    done < <(docker ps -a --filter "status=exited" --format "{{.ID}}")
    
    log "INFO" "Restarted $restarted container(s)"
    return $([ $restarted -eq 0 ])
}
check_kubernetes_pods() {
    log "INFO" "Checking Kubernetes pods..."
    local issues=0
    local k8s_json=""
    
    if ! command -v kubectl &>/dev/null; then
        log "INFO" "kubectl not installed, skipping Kubernetes checks"
        return 0
    fi
    
    if ! kubectl cluster-info &>/dev/null; then
        log "WARN" "Cannot connect to Kubernetes cluster"
        K8S_DATA="{\"error\":\"Cannot connect to Kubernetes cluster\"}"
        return 1
    fi
    
    local namespaces=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
    k8s_json="{\"namespaces\":["
    
    for ns in $namespaces; do
        k8s_json+="{\"name\":\"$ns\",\"pods\":["
        
        while IFS= read -r pod_line; do
            local pod_name=$(echo "$pod_line" | awk '{print $1}')
            local ready=$(echo "$pod_line" | awk '{print $2}')
            local status=$(echo "$pod_line" | awk '{print $3}')
            local restarts=$(echo "$pod_line" | awk '{print $4}')
            
            k8s_json+="{\"name\":\"$pod_name\",\"ready\":\"$ready\",\"status\":\"$status\",\"restarts\":$restarts},"
            
            if [[ "$status" != "Running" && "$status" != "Completed" && "$status" != "Succeeded" ]]; then
                log "WARN" "Pod $pod_name in namespace $ns is $status"
                issues=1
            fi
            
            if [[ "$ready" != "1/1" && "$ready" != "2/2" && "$ready" != "3/3" ]]; then
                log "WARN" "Pod $pod_name not ready ($ready)"
            fi
        done < <(kubectl get pods -n "$ns" --no-headers 2>/dev/null | head -20)
        
        k8s_json+="]},"
    done
    
    k8s_json+="]}"
    K8S_DATA="${k8s_json%]},[]}"
    K8S_DATA="[${k8s_json%}]"
    
    local total_nodes=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
    local ready_nodes=$(kubectl get nodes --no-headers 2>/dev/null | grep -c "Ready")
    
    log "INFO" "Kubernetes nodes: $ready_nodes/$total_nodes ready"
    
    if [[ $ready_nodes -lt $total_nodes ]]; then
        log "WARN" "Some Kubernetes nodes are not ready"
        send_alert "Kubernetes Nodes" "Only $ready_nodes/$total_nodes nodes are ready"
        issues=1
    fi
    
    return $issues
}
check_kubernetes_resources() {
    log "INFO" "Checking Kubernetes resource usage..."
    local issues=0
    
    if ! command -v kubectl &>/dev/null; then
        return 0
    fi
    
    if command -v kubectl top &>/dev/null; then
        log "INFO" "Node resource usage:"
        kubectl top nodes 2>/dev/null | tee -a "$LOG_FILE" | head -10
        
        log "INFO" "Pod resource usage:"
        kubectl top pods --all-namespaces 2>/dev/null | tee -a "$LOG_FILE" | head -15
    else
        log "WARN" "kubectl metrics-server not installed, skipping resource usage"
    fi
    
    return $issues
}
take_snapshot() {
    local snapshot_name="${1:-snapshot-$(date +%Y%m%d-%H%M%S)}"
    local snapshot_dir="$CONFIG_DIR/snapshots"
    mkdir -p "$snapshot_dir"
    log "INFO" "Taking system snapshot: $snapshot_name"
    cat > "$snapshot_dir/$snapshot_name.txt" << EOF
=== SYSTEM SNAPSHOT: $snapshot_name ===
Date: $(date)
Hostname: $(hostname)
=== DISK USAGE ===
$(df -h)
=== MEMORY INFO ===
$(free -h)
=== CPU INFO ===
$(lscpu | grep -E "^Model name|^CPU\(s\)|^Thread|^Core")
=== TOP PROCESSES ===
$(ps aux --sort=-%cpu | head -10)
=== SERVICE STATUS ===
$(systemctl list-units --type=service --state=running,failed --no-legend 2>/dev/null | head -20)
=== NETWORK CONNECTIONS ===
$(ss -tuln 2>/dev/null || netstat -tuln 2>/dev/null)
 === UPTIME/LOAD ===
 $(uptime)
 === RECENT LOG ERRORS (last hour) ===
 $(journalctl -p err -since "1 hour ago" --no-pager 2>/dev/null || tail -100 /var/log/syslog 2>/dev/null | grep -iE "error|fail" | tail -10)
 === DOCKER CONTAINERS ===
 $(docker ps -a 2>/dev/null || echo "Docker not available")
 === DOCKER SYSTEM INFO ===
 $(docker system df 2>/dev/null || echo "Docker not available")
 === KUBERNETES PODS ===
 $(kubectl get pods --all-namespaces 2>/dev/null || echo "Kubernetes not available")
 === KUBERNETES NODES ===
 $(kubectl get nodes 2>/dev/null || echo "Kubernetes not available")
EOF
    gzip "$snapshot_dir/$snapshot_name.txt"
    log "INFO" "Snapshot saved to $snapshot_dir/$snapshot_name.txt.gz"
    echo "$snapshot_dir/$snapshot_name.txt.gz"
}
compare_snapshots() {
    local snap1="$1"
    local snap2="$2"
    [[ ! -f "$snap1" ]] && { log "ERROR" "Snapshot not found: $snap1"; return 1; }
    [[ ! -f "$snap2" ]] && { log "ERROR" "Snapshot not found: $snap2"; return 1; }
    log "INFO" "Comparing snapshots: $snap1 vs $snap2"
    zcat "$snap1" > /tmp/snap1.txt
    zcat "$snap2" > /tmp/snap2.txt
    diff -u /tmp/snap1.txt /tmp/snap2.txt || true
    rm -f /tmp/snap1.txt /tmp/snap2.txt
}
generate_report() {
    local report_file="${1:-$BASE_DIR/reports/report-$(date +%Y%m%d).html}"
    log "INFO" "Generating report: $report_file"
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>System Sentinel Report - $(date)</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1000px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; }
        h1 { color: #333; border-bottom: 3px solid #4CAF50; padding-bottom: 10px; }
        h2 { color: #555; margin-top: 30px; }
        .metric { display: inline-block; margin: 10px; padding: 15px; background: #f9f9f9; border-radius: 5px; min-width: 150px; }
        .metric-label { color: #666; font-size: 12px; }
        .metric-value { font-size: 24px; font-weight: bold; color: #333; }
        .status-ok { color: #4CAF50; }
        .status-warn { color: #ff9800; }
        .status-crit { color: #f44336; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background: #4CAF50; color: white; }
        tr:hover { background: #f5f5f5; }
        .section { background: #f9f9f9; padding: 15px; border-radius: 5px; margin: 20px 0; }
        pre { background: #333; color: #fff; padding: 10px; border-radius: 5px; overflow-x: auto; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🛡️ System Sentinel Report</h1>
        <p>Generated: $(date)</p>
        <p>Hostname: $(hostname)</p>
        
        <h2>System Overview</h2>
        <div class="section">
            <div class="metric">
                <div class="metric-label">Uptime</div>
                <div class="metric-value">$(uptime -p)</div>
            </div>
            <div class="metric">
                <div class="metric-label">Load Average</div>
                <div class="metric-value">$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}')</div>
            </div>
            <div class="metric">
                <div class="metric-label">Running Processes</div>
                <div class="metric-value">$(ps aux | wc -l)</div>
            </div>
        </div>
        
        <h2>Disk Usage</h2>
        <table>
            <tr><th>Filesystem</th><th>Size</th><th>Used</th><th>Available</th><th>Use%</th><th>Mount</th></tr>
            $(df -h | grep -vE '^Filesystem|tmpfs|cdrom|overlay' | awk '{print "<tr><td>"$1"</td><td>"$2"</td><td>"$3"</td><td>"$4"</td><td>"$5"</td><td>"$6"</td></tr>"}')
        </table>
        
        <h2>Memory Information</h2>
        <table>
            <tr><th>Type</th><th>Total</th><th>Used</th><th>Free</th><th>Available</th></tr>
            $(free -h | grep -E "Mem:|Swap:" | awk '{print "<tr><td>"$1"</td><td>"$2"</td><td>"$3"</td><td>"$4"</td><td>"$7"</td></tr>"}')
        </table>
        
        <h2>Top Processes (CPU)</h2>
        <table>
            <tr><th>PID</th><th>User</th><th>CPU%</th><th>MEM%</th><th>Command</th></tr>
            $(ps aux --sort=-%cpu | head -11 | awk 'NR>1 {print "<tr><td>"$2"</td><td>"$1"</td><td>"$3"</td><td>"$4"</td><td>"$11"</td></tr>"}')
        </table>
        
        <h2>Recent Log Errors (Last Hour)</h2>
        <pre>$(journalctl -p err -since "1 hour ago" --no-pager 2>/dev/null | tail -20 || echo "No journalctl available")</pre>
        
        <h2>Service Status</h2>
        <table>
            <tr><th>Service</th><th>State</th></tr>
            $(systemctl list-units --type=service --state=running,failed --no-legend 2>/dev/null | head -20 | awk '{print "<tr><td>"$1"</td><td>"$4"</td></tr>"}')
        </table>
    </div>
</body>
</html>
EOF
    log "INFO" "Report generated: $report_file"
}
show_menu() {
    clear
    echo "╔════════════════════════════════════════╗"
    echo "║     🛡️ System Sentinel v$VERSION     ║"
    echo "╚════════════════════════════════════════╝"
    echo ""
    echo "1.  Run Full System Check"
    echo "2.  Check Disk Space"
    echo "3.  Check Service Health"
    echo "4.  Analyze Logs for Errors"
    echo "5.  Check System Resources"
    echo "6.  Check Docker Containers"
    echo "7.  Check Kubernetes Pods"
    echo "8.  Take System Snapshot"
    echo "9.  Compare Snapshots"
    echo "10. Generate HTML Report"
    echo "11. Cleanup Old Files"
    echo "12. Restart Failed Services"
    echo "13. Restart Failed Containers"
    echo "14. Configure Alerts"
    echo "15. View Recent Logs"
    echo "0.  Exit"
    echo ""
}
run_ci_check() {
    CI_MODE="true"
    local exit_code=0
    local checks_json="{"
    
    check_disk_space || exit_code=$?
    checks_json+="\"disk\":{\"data\":${DISK_DATA:-"[]"},\"status\":$([ $exit_code -eq 0 ] && echo '"ok"' || echo '"failed"')},"
    
    check_service_health || exit_code=$?
    checks_json+="\"services\":{\"data\":${SERVICES_DATA:-"[]"},\"status\":$([ $exit_code -eq 0 ] && echo '"ok"' || echo '"failed"')},"
    
    check_system_resources || exit_code=$?
    checks_json+="\"resources\":${RESOURCES_DATA:-"{}"},"
    
    check_docker_containers || exit_code=$?
    checks_json+="\"docker\":{\"data\":${DOCKER_DATA:-"[]"},\"status\":$([ $exit_code -eq 0 ] && echo '"ok"' || echo '"failed"')},"
    
    check_kubernetes_pods || exit_code=$?
    checks_json+="\"kubernetes\":{\"data\":${K8S_DATA:-"[]"},\"status\":$([ $exit_code -eq 0 ] && echo '"ok"' || echo '"failed"')},"
    
    analyze_logs /var/log "ERROR|CRITICAL|FATAL" 1 || exit_code=$?
    checks_json+="\"logs\":{\"status\":$([ $exit_code -eq 0 ] && echo '"ok"' || echo '"failed"')}"
    
    checks_json+="}"
    
    json_output $([ $exit_code -eq 0 ] && echo "healthy" || echo "unhealthy") "$checks_json"
    
    if [[ $exit_code -ne 0 ]]; then
        echo "::error::System health check failed"
    else
        echo "::notice::System health check passed"
    fi
    
    return $exit_code
}

main() {
    load_config
    case "$1" in
        --help|-h|help)
            echo "System Sentinel - DevOps Monitoring & Remediation Tool"
            echo "Usage: $0 [option]"
            echo ""
            echo "Options:"
            echo "  check        Run full system check"
            echo "  ci-check     CI/CD mode: JSON output + exit codes"
            echo "  disk         Check disk space"
            echo "  services     Check service health"
            echo "  logs         Analyze logs"
            echo "  resources    Check system resources"
            echo "  docker       Check Docker containers"
            echo "  k8s          Check Kubernetes pods"
            echo "  snapshot     Take system snapshot"
            echo "  report       Generate HTML report"
            echo "  cleanup      Cleanup old files"
            echo "  config       Show configuration"
            echo "  watch        Run in watch mode (continuous)"
            echo "  help         Show this help"
            echo ""
            echo "CI/CD Examples:"
            echo "  ./system-sentinel.sh ci-check    # Returns exit code 0 if healthy, 1 if issues found"
            echo "  ./system-sentinel.sh ci-check | jq # Parse JSON output"
            exit 0
            ;;
        ci-check)
            run_ci_check
            exit $?
            ;;
        check)
            check_disk_space && check_service_health && check_system_resources && check_docker_containers && check_kubernetes_pods && analyze_logs
            exit $?
            ;;
        disk)
            check_disk_space
            exit $?
            ;;
        services)
            check_service_health
            exit $?
            ;;
        logs)
            analyze_logs
            exit $?
            ;;
        resources)
            check_system_resources
            exit $?
            ;;
        docker)
            check_docker_containers
            check_docker_system
            exit $?
            ;;
        k8s|kubernetes)
            check_kubernetes_pods
            check_kubernetes_resources
            exit $?
            ;;
        snapshot)
            take_snapshot
            exit $?
            ;;
        report)
            generate_report
            exit $?
            ;;
        config)
            cat "$CONFIG_DIR/config.conf" 2>/dev/null || echo "No config found"
            exit 0
            ;;
        cleanup)
            read -p "Enter directory to clean [default: /tmp]: " dir
            read -p "Enter days threshold [default: 7]: " days
            cleanup_old_files "${dir:-/tmp}" "${days:-7}"
            exit $?
            ;;
        watch)
            log "INFO" "Starting watch mode..."
            while true; do
                check_disk_space
                check_service_health
                check_system_resources
                check_docker_containers
                check_kubernetes_pods
                analyze_logs
                sleep 300
            done
            ;;
    esac

    while true; do
        show_menu
        read -p "Select an option: " choice
        case $choice in
            1) check_disk_space && check_service_health && check_system_resources && check_docker_containers && check_kubernetes_pods && analyze_logs; read -p "Press Enter to continue..." ;;
            2) check_disk_space; read -p "Press Enter to continue..." ;;
            3) check_service_health; read -p "Press Enter to continue..." ;;
            4) read -p "Log path [/var/log]: " log_path; read -p "Pattern [ERROR|CRITICAL|FATAL]: " pattern; read -p "Hours back [1]: " hours; analyze_logs "${log_path:-/var/log}" "${pattern:-ERROR|CRITICAL|FATAL}" "${hours:-1}"; read -p "Press Enter to continue..." ;;
            5) check_system_resources; read -p "Press Enter to continue..." ;;
            6) check_docker_containers && check_docker_system; read -p "Press Enter to continue..." ;;
            7) check_kubernetes_pods && check_kubernetes_resources; read -p "Press Enter to continue..." ;;
            8) take_snapshot; read -p "Press Enter to continue..." ;;
            9) ls -la "$CONFIG_DIR/snapshots/" 2>/dev/null; read -p "Enter first snapshot: " snap1; read -p "Enter second snapshot: " snap2; compare_snapshots "$snap1" "$snap2"; read -p "Press Enter to continue..." ;;
            10) generate_report; read -p "Press Enter to continue..." ;;
            11) read -p "Directory [/tmp]: " dir; read -p "Days [7]: " days; cleanup_old_files "${dir:-/tmp}" "${days:-7}"; read -p "Press Enter to continue..." ;;
            12) restart_failed_services; read -p "Press Enter to continue..." ;;
            13) restart_failed_containers; read -p "Press Enter to continue..." ;;
            14) read -p "Alert email [current: $ALERT_EMAIL]: " email; read -p "Slack webhook [current: $SLACK_WEBHOOK]: " webhook; read -p "Disk threshold % [current: $DISK_THRESHOLD]: " disk; read -p "CPU threshold % [current: $CPU_THRESHOLD]: " cpu; read -p "Memory threshold % [current: $MEM_THRESHOLD]: " mem; ALERT_EMAIL="${email:-$ALERT_EMAIL}"; SLACK_WEBHOOK="${webhook:-$SLACK_WEBHOOK}"; DISK_THRESHOLD="${disk:-$DISK_THRESHOLD}"; CPU_THRESHOLD="${cpu:-$CPU_THRESHOLD}"; MEM_THRESHOLD="${mem:-$MEM_THRESHOLD}"; save_config; read -p "Press Enter to continue..." ;;
            15) tail -50 "$LOG_FILE"; read -p "Press Enter to continue..." ;;
            0) log "INFO" "Exiting System Sentinel"; exit 0 ;;
            *) echo "Invalid option"; sleep 2 ;;
        esac
    done
}
main "$@"