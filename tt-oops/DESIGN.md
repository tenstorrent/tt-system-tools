# System Diagnostic Data Collector Design Document

## 1. Project Overview

**Purpose:**
A set of scripts designed to gather comprehensive system information from Linux-based computers for diagnosing issues, performing health checks, and troubleshooting.

**Key Objectives:**
1. Collect and organize system diagnostic data in a structured format
2. Provide both human-readable and machine-parseable output
3. Minimize performance impact during data collection
4. Ensure data security and privacy throughout the collection process

## 2. Functional Requirements

### 2.1 Core Functionality
- **REQ-1.1:** Must collect hardware, software, and configuration data
- **REQ-1.2:** Must support different collection levels (basic, detailed, debug)
- **REQ-1.3:** Must provide output in multiple formats (JSON, text, HTML, CSV)
- **REQ-1.4:** Must allow filtering of collected data by type and time period
- **REQ-1.5:** Must handle permission errors and missing dependencies gracefully

### 2.2 Performance Requirements
- **REQ-2.1:** Must not significantly impact system performance during collection
- **REQ-2.2:** Must complete basic collection within 2 minutes on standard hardware
- **REQ-2.3:** Must include timeout mechanisms for long-running operations
- **REQ-2.4:** Must support background operation for intensive collection tasks

### 2.3 Security Requirements
- **REQ-3.1:** Must exclude sensitive information (passwords, keys) from collection
- **REQ-3.2:** Must provide options to anonymize personal/user data
- **REQ-3.3:** Must document required privileges for each collection module
- **REQ-3.4:** Must support encryption for sensitive collected data
- **REQ-3.5:** Must validate and sanitize all command-line inputs

## 3. System Architecture

### 3.1 Main Collection Script (`collect_system_info.sh`)
- **Entry point** for diagnostic collection
- **Handles** command-line arguments and options
- **Orchestrates** the collection process
- **Manages** output formatting and storage

### 3.2 Data Collection Modules

#### 3.2.1 Hardware Information Module
- **REQ-4.1:** Must collect CPU information (model, cores, frequency, temperature)
- **REQ-4.2:** Must collect memory details (total, used, available, swap)
- **REQ-4.3:** Must collect disk information (partitions, usage, SMART data)
- **REQ-4.4:** Must collect network interface configurations
- **REQ-4.5:** Must enumerate PCI and USB devices
- **REQ-4.6:** Must collect GPU information when available

#### 3.2.2 Software Information Module
- **REQ-5.1:** Must collect OS details (distribution, version, kernel)
- **REQ-5.2:** Must list installed packages and versions
- **REQ-5.3:** Must report running services and their status
- **REQ-5.4:** Must gather user accounts and permissions
- **REQ-5.5:** Must collect relevant environment variables

#### 3.2.3 System Configuration Module
- **REQ-6.1:** Must collect network configuration (interfaces, routes, DNS)
- **REQ-6.2:** Must document system services and daemons configuration
- **REQ-6.3:** Must gather security settings (firewall, SELinux)
- **REQ-6.4:** Must report system limits and resource constraints
- **REQ-6.5:** Must document mount points and filesystem configurations

#### 3.2.4 Performance Metrics Module
- **REQ-7.1:** Must capture system load averages
- **REQ-7.2:** Must collect CPU usage statistics
- **REQ-7.3:** Must gather memory usage patterns
- **REQ-7.4:** Must record disk I/O statistics
- **REQ-7.5:** Must measure network traffic metrics
- **REQ-7.6:** Must collect continuous performance sampling for time-series analysis

#### 3.2.4.1 Continuous Performance Sampling Submodule
- **REQ-7.6.1:** Must capture time-series data using standard performance tools (vmstat, iostat, mpstat, etc.)
- **REQ-7.6.2:** Must collect samples at 1-second intervals for a configurable duration (default: 60 seconds)
- **REQ-7.6.3:** Must support simultaneous collection from multiple performance tools
- **REQ-7.6.4:** Must store raw output with timestamps for post-collection analysis
- **REQ-7.6.5:** Must provide summary statistics of collected time-series data
- **REQ-7.6.6:** Must run sampling in a non-blocking manner when possible

#### 3.2.5 System Logs Module
- **REQ-8.1:** Must collect system journal logs (via journalctl)
- **REQ-8.2:** Must gather traditional system logs from /var/log
- **REQ-8.3:** Must support application-specific logs collection
- **REQ-8.4:** Must provide log rotation information
- **REQ-8.5:** Must support filtering logs by time range and severity

### 3.3 Output Formatters
- **REQ-9.1:** Must provide JSON formatter for machine parsing
- **REQ-9.2:** Must include human-readable text formatter
- **REQ-9.3:** Must support HTML report generation
- **REQ-9.4:** Must enable CSV export for specific metrics

## 4. Data Collection Methods

### 4.1 System Commands
- Use standard Linux utilities (`lscpu`, `free`, `df`, `lsblk`, etc.)
- Leverage system management tools (`systemctl`, `journalctl`, etc.)
- Employ networking utilities (`ip`, `netstat`, etc.)

### 4.2 File System Inspection
- Read configuration files in `/etc`
- Parse log files in `/var/log`
- Extract system state from `/proc` and `/sys`
- Analyze journal files and kernel ring buffer

### 4.3 API Calls
- Use SMART API for disk health data
- Access hardware sensor readings via appropriate APIs
- Retrieve system metrics through procfs/sysfs interfaces

## 5. Output Structure

```json
{
  "metadata": {
    "collection_time": "timestamp",
    "system_id": "unique_identifier",
    "collection_level": "basic|detailed|debug"
  },
  "hardware": {
    "cpu": {},
    "memory": {},
    "storage": {},
    "network": {},
    "peripherals": {}
  },
  "software": {
    "os": {},
    "packages": [],
    "services": {},
    "logs": {}
  },
  "configuration": {
    "network": {},
    "security": {},
    "system": {}
  },
  "performance": {
    "metrics": {},
    "statistics": {}
  },
  "logs": {
    "system_journal": {},
    "traditional_logs": {},
    "application_logs": {},
    "log_rotation": {},
    "collection_metadata": {}
  }
}
```

## 6. Implementation Plan

### 6.1 Phase 1: Core Collection
- Implement basic hardware information collection
- Develop essential system configuration gathering
- Create simple performance metrics recording
- Establish output formatting framework

### 6.2 Phase 2: Extended Collection
- Add detailed hardware diagnostics
- Implement comprehensive software inventory
- Develop advanced performance metrics
- Enhance log collection capabilities

### 6.3 Phase 3: Analysis Tools
- Create data comparison utilities
- Implement trend analysis features
- Develop automated issue detection
- Build integration with monitoring systems

## 7. Usage Scenarios

### 7.1 Basic System Check
```bash
./collect_system_info.sh --level basic --logs last-hour
```

### 7.2 Detailed Diagnostics
```bash
./collect_system_info.sh --level detailed --output json --logs full
```

### 7.3 Debug Mode
```bash
./collect_system_info.sh --level debug --include-logs --log-severity error
```

### 7.4 Log Analysis Mode
```bash
./collect_system_info.sh --logs-only --time-range "24h" --log-pattern "error|warning"
```

## 8. Technical Dependencies

- **REQ-10.1:** Standard Linux utilities (core requirement)
- **REQ-10.2:** Python 3.x for data processing (optional)
- **REQ-10.3:** jq for JSON processing (required for JSON output)
- **REQ-10.4:** smartmontools for disk health analysis (optional)
- **REQ-10.5:** lm-sensors for hardware monitoring (optional)
- **REQ-10.6:** dmidecode for detailed hardware information (optional, requires root)
- **REQ-10.7:** systemd-journal-remote for journal access (optional)
- **REQ-10.8:** logrotate for log rotation info (optional)
- **REQ-10.9:** auditd for security logs (optional)
- **REQ-10.10:** rsyslog/syslog-ng for traditional logs (optional)

## 9. Error Handling Strategy

- **REQ-11.1:** Must implement graceful degradation when tools are missing
- **REQ-11.2:** Must provide clear error messages and logging
- **REQ-11.3:** Must include fallback collection methods
- **REQ-11.4:** Must validate collected data for integrity
- **REQ-11.5:** Must handle timeouts and resource constraints

## 10. Maintenance and Support

- **REQ-12.1:** Must support regular updates for new Linux distributions
- **REQ-12.2:** Must allow addition of new collection modules
- **REQ-12.3:** Must include performance optimization capabilities
- **REQ-12.4:** Must document security considerations and updates
- **REQ-12.5:** Must maintain comprehensive documentation