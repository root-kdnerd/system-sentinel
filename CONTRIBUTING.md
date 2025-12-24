# Contributing to System Sentinel

Thank you for your interest in contributing to System Sentinel!

## Development Setup

1. Clone the repository
2. Make the script executable: `chmod +x system-sentinel.sh`
3. Test your changes: `./system-sentinel.sh help`

## Adding New Features

### Adding a New Check

1. Create a new function following the naming pattern `check_<feature_name>`

```bash
check_custom_feature() {
    log "INFO" "Checking custom feature..."
    local issues=0
    
    # Your check logic here
    
    if [[ $issues -eq 1 ]]; then
        [[ "$CI_MODE" == "true" ]] && echo "::warning::Custom feature issue detected"
    fi
    
    return $issues
}
```

2. Add JSON data collection for CI mode

```bash
CUSTOM_DATA="{\"metric\":$value,\"status\":\"$status\"}"
```

3. Add to the menu in `show_menu()`

```bash
echo "16. Check Custom Feature"
```

4. Add case statement in main menu loop

```bash
16) check_custom_feature; read -p "Press Enter to continue..." ;;
```

5. Add to `run_ci_check()` function

```bash
check_custom_feature || exit_code=$?
checks_json+="\"custom\":{\"data\":${CUSTOM_DATA:-"{}"},\"status\":$([ $exit_code -eq 0 ] && echo '"ok"' || echo '"failed"')},"
```

6. Update help section and README

### Coding Standards

- Use `log()` function for all output (not `echo`)
- Return 0 for success, non-zero for failure
- Set `*_DATA` variable for JSON output
- Use CI_MODE checks for CI-specific output
- Follow existing indentation (4 spaces)
- Keep functions focused and single-purpose

## Testing

- Test with `./system-sentinel.sh check`
- Test with `./system-sentinel.sh ci-check`
- Verify JSON output is valid: `./system-sentinel.sh ci-check | jq`
- Test in watch mode: `./system-sentinel.sh watch`

## Feature Ideas

- [ ] Redis/MongoDB monitoring
- [ ] Nginx/Apache metrics
- [ ] Database connection checks
- [ ] SSL certificate expiry monitoring
- [ ] Backup verification
- [ ] Performance profiling
- [ ] Network latency checks
- [ ] Security audit (open ports, vulnerable packages)
- [ ] Integration with Prometheus/Grafana
- [ ] Web dashboard
- [ ] Remote monitoring via SSH
- [ ] Plugin system for custom checks

## Submitting Changes

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

MIT