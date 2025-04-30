#!/usr/bin/env bash
# SPDX-FileCopyrightText: © 2025 Tenstorrent Inc.
# SPDX-License-Identifier: Apache-2.0
#
# System Diagnostic Data Collector (tt-oops.sh)
# A tool to gather comprehensive system information for diagnostics

set -eo pipefail

VERSION="0.1.0"
SCRIPT_NAME="$(basename "$0")"
OUTPUT_DIR="$(pwd)/tt-oops-output-$(date +%Y%m%d-%H%M%S)"
COLLECTION_LEVEL="basic"
LOG_LEVEL="info"
OUTPUT_FORMAT="text"
INCLUDE_LOGS="last-hour"
COMPRESS_OUTPUT=true
SAMPLE_DURATION=60
ARCHIVE_FILE=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_debug() {
	if [[ "$LOG_LEVEL" == "debug" ]]; then
		echo -e "${BLUE}[DEBUG] $*${NC}" >&2
	else
		echo -e "${BLUE}[DEBUG] $*${NC}" >/dev/null
	fi
}

log_info() {
	if [[ "$LOG_LEVEL" == "debug" || "$LOG_LEVEL" == "info" ]]; then
		echo -e "${GREEN}[INFO] $*${NC}" >&2
	fi
}

log_warn() {
	if [[ "$LOG_LEVEL" == "debug" || "$LOG_LEVEL" == "info" || "$LOG_LEVEL" == "warn" ]]; then
		echo -e "${YELLOW}[WARN] $*${NC}" >&2
	fi
}

log_error() {
	echo -e "${RED}[ERROR] $*${NC}" >&2
}

# Check if command exists
command_exists() {
	command -v "$1" >/dev/null 2>&1
}

# Run a command with error handling
run_command() {
	local cmd="$1"
	local output_file="$2"
	local description="$3"

	# Always show what command is being run, regardless of log level
	log_debug "Running command: $cmd > $output_file"

	# Ensure the directory exists
	mkdir -p "$(dirname "$output_file")"

	if bash -c "$cmd" >"$output_file" 2>&1; then
		# Always show success message, don't use log_debug
		log_debug "Successfully collected $description"
		return 0
	else
		# Always show failure message, don't use log_warn
		log_debug "Failed to collect $description"
		log_debug "Command failed: $cmd" >"$output_file"
		return 1
	fi
}

# Check for required privileges
check_privileges() {
	log_debug "Checking privileges for collection level: $COLLECTION_LEVEL"

	if [[ "$COLLECTION_LEVEL" == "detailed" || "$COLLECTION_LEVEL" == "debug" ]]; then
		if [[ $EUID -ne 0 ]]; then
			log_warn "Some detailed information may not be available without root privileges"
			return 1
		fi
	fi

	return 0
}

# Check dependencies
check_dependencies() {
	log_debug "Checking dependencies"

	local missing_deps=()

	# Core dependencies
	for cmd in lscpu free df lsblk uname ip grep pstree; do
		if ! command_exists "$cmd"; then
			missing_deps+=("$cmd")
		fi
	done

	# Optional dependencies based on collection level
	if [[ "$COLLECTION_LEVEL" == "detailed" || "$COLLECTION_LEVEL" == "debug" ]]; then
		for cmd in smartctl sensors jq dmidecode; do
			if ! command_exists "$cmd"; then
				log_warn "Optional dependency '$cmd' not found, some features will be disabled"
			fi
		done

		# Performance monitoring tools
		for cmd in vmstat iostat mpstat sar pidstat; do
			if ! command_exists "$cmd"; then
				log_warn "Optional performance monitoring tool '$cmd' not found, continuous performance sampling will be limited"
			fi
		done
	fi

	# Check for Tenstorrent tools
	if ! command_exists tt-smi; then
		log_warn "Tenstorrent tool 'tt-smi' not found, Tenstorrent hardware data collection will be limited"
	fi

	if [[ ${#missing_deps[@]} -gt 0 ]]; then
		log_error "Missing required dependencies: ${missing_deps[*]}"
		return 1
	fi

	return 0
}

# Create output directory
create_output_dir() {
	log_debug "Creating output directory: $OUTPUT_DIR"

	if mkdir -p "$OUTPUT_DIR"; then
		log_info "Created output directory: $OUTPUT_DIR"
		return 0
	else
		log_error "Failed to create output directory: $OUTPUT_DIR"
		return 1
	fi
}

# Collect hardware information
collect_hardware_info() {
	log_info "Collecting hardware information"

	mkdir -p "$OUTPUT_DIR/hardware"

	# CPU info
	log_debug "Collecting CPU information"
	run_command "lscpu" "$OUTPUT_DIR/hardware/cpu_info.txt" "CPU information"

	# Memory info
	log_debug "Collecting memory information"
	run_command "free -h" "$OUTPUT_DIR/hardware/memory_info.txt" "memory information"
	run_command "cat /proc/meminfo" "$OUTPUT_DIR/hardware/meminfo.txt" "detailed memory information"

	# Disk info
	log_debug "Collecting disk information"
	run_command "df -h" "$OUTPUT_DIR/hardware/disk_usage.txt" "disk usage"
	run_command "lsblk -a" "$OUTPUT_DIR/hardware/block_devices.txt" "block devices"

	# Network info
	log_debug "Collecting network information"
	run_command "ip addr" "$OUTPUT_DIR/hardware/network_interfaces.txt" "network interfaces"
	run_command "ip route" "$OUTPUT_DIR/hardware/network_routes.txt" "network routes"
	run_command "netstat -tuln" "$OUTPUT_DIR/hardware/netstat.txt" "network statistics" || true

	# System hardware info
	if command_exists dmidecode && [[ $EUID -eq 0 ]]; then
		log_debug "Collecting DMI information"
		run_command "dmidecode" "$OUTPUT_DIR/hardware/dmidecode.txt" "DMI information"

		# Additionally collect specific DMI sections for easier analysis
		run_command "dmidecode -t system" "$OUTPUT_DIR/hardware/dmidecode_system.txt" "DMI system information"
		run_command "dmidecode -t bios" "$OUTPUT_DIR/hardware/dmidecode_bios.txt" "DMI BIOS information"
		run_command "dmidecode -t processor" "$OUTPUT_DIR/hardware/dmidecode_processor.txt" "DMI processor information"
		run_command "dmidecode -t memory" "$OUTPUT_DIR/hardware/dmidecode_memory.txt" "DMI memory information"
	else
		log_warn "dmidecode not available or not running as root, skipping DMI information"
	fi

	if command_exists lshw; then
		log_debug "Collecting hardware information with lshw"
		run_command "lshw" "$OUTPUT_DIR/hardware/lshw.txt" "hardware details"
	fi

	# PCI devices
	if command_exists lspci; then
		log_debug "Collecting PCI devices"
		run_command "lspci -v" "$OUTPUT_DIR/hardware/pci_devices.txt" "PCI devices"
	fi

	# USB devices
	if command_exists lsusb; then
		log_debug "Collecting USB devices"
		run_command "lsusb -v" "$OUTPUT_DIR/hardware/usb_devices.txt" "USB devices"
	fi

	# SMART data for disks (if available and privileges allow)
	if command_exists smartctl && [[ $EUID -eq 0 ]]; then
		log_debug "Collecting SMART data for disks"
		mkdir -p "$OUTPUT_DIR/hardware/smart"

		# Get list of disks
		if lsblk -d -o NAME -n 2>/dev/null; then
			mapfile -t disks < <(lsblk -d -o NAME -n 2>/dev/null | grep -v "loop" || echo "")

			for disk in "${disks[@]}"; do
				if [[ -n "$disk" ]]; then
					run_command "smartctl -a /dev/$disk" "$OUTPUT_DIR/hardware/smart/${disk}_smart.txt" "SMART data for $disk" || true
				fi
			done
		else
			log_warn "lsblk command failed, skipping SMART data collection"
		fi
	fi

	# Hardware sensors
	if command_exists sensors; then
		log_debug "Collecting sensor information"
		run_command "sensors" "$OUTPUT_DIR/hardware/sensors.txt" "hardware sensors"
	fi

	log_info "Hardware information collection complete"
}

# Collect software information
collect_software_info() {
	log_info "Collecting software information"

	mkdir -p "$OUTPUT_DIR/software"

	# OS info
	log_debug "Collecting OS information"
	run_command "uname -a" "$OUTPUT_DIR/software/uname.txt" "kernel information"

	if [[ -f /etc/os-release ]]; then
		run_command "cat /etc/os-release" "$OUTPUT_DIR/software/os_release.txt" "OS release information"
	fi

	# Kernel info
	log_debug "Collecting kernel information"
	run_command "uname -r" "$OUTPUT_DIR/software/kernel_version.txt" "kernel version"
	run_command "cat /proc/version" "$OUTPUT_DIR/software/proc_version.txt" "kernel version details"
	run_command "cat /proc/cmdline" "$OUTPUT_DIR/software/kernel_cmdline.txt" "kernel command line"

	# Package info (detect package manager and use appropriate command)
	log_debug "Collecting package information"

	if command_exists dpkg; then
		run_command "dpkg -l" "$OUTPUT_DIR/software/packages_dpkg.txt" "Debian packages"
	elif command_exists rpm; then
		run_command "rpm -qa" "$OUTPUT_DIR/software/packages_rpm.txt" "RPM packages"
	elif command_exists pacman; then
		run_command "pacman -Q" "$OUTPUT_DIR/software/packages_pacman.txt" "Arch packages"
	fi

	# Service info
	log_debug "Collecting service information"

	if command_exists systemctl; then
		run_command "systemctl list-units --type=service" "$OUTPUT_DIR/software/systemd_services.txt" "systemd services"
		run_command "systemctl list-units --failed" "$OUTPUT_DIR/software/systemd_failed.txt" "failed systemd services"
	elif command_exists service; then
		run_command "service --status-all" "$OUTPUT_DIR/software/sysv_services.txt" "SysV services"
	fi

	# Process info
	log_debug "Collecting process information"
	run_command "ps aux" "$OUTPUT_DIR/software/processes.txt" "running processes"

	# Environment variables (filtered for safety)
	log_debug "Collecting environment variables (filtered)"
	run_command "env | grep -v -i 'key\|token\|password\|secret'" "$OUTPUT_DIR/software/environment.txt" "environment variables"

	# User info
	log_debug "Collecting user information"
	run_command "w" "$OUTPUT_DIR/software/logged_in_users.txt" "logged-in users"
	run_command "last | head -20" "$OUTPUT_DIR/software/recent_logins.txt" "recent logins"

	log_info "Software information collection complete"
}

# Collect system configuration
collect_system_config() {
	log_info "Collecting system configuration"

	mkdir -p "$OUTPUT_DIR/config"

	# Network configuration
	log_debug "Collecting network configuration"
	if command_exists ip; then
		run_command "ip route" "$OUTPUT_DIR/config/ip_routes.txt" "IP routes"
		run_command "ip rule" "$OUTPUT_DIR/config/ip_rules.txt" "IP rules"
	fi

	if command_exists ss; then
		run_command "ss -tuap" "$OUTPUT_DIR/config/socket_stats.txt" "socket statistics"
	fi

	if [[ -f /etc/resolv.conf ]]; then
		run_command "cat /etc/resolv.conf" "$OUTPUT_DIR/config/resolv.conf" "DNS resolver config"
	fi

	if [[ -f /etc/hosts ]]; then
		run_command "cat /etc/hosts" "$OUTPUT_DIR/config/hosts" "hosts file"
	fi

	# System limits
	log_debug "Collecting system limits"
	run_command "ulimit -a" "$OUTPUT_DIR/config/ulimit.txt" "user limits"

	if [[ -f /etc/security/limits.conf ]]; then
		run_command "cat /etc/security/limits.conf" "$OUTPUT_DIR/config/limits.conf" "system limits configuration"
	fi

	# Mounted filesystems
	log_debug "Collecting mount information"
	run_command "mount" "$OUTPUT_DIR/config/mounts.txt" "mounted filesystems"
	run_command "cat /etc/fstab" "$OUTPUT_DIR/config/fstab.txt" "filesystem table"

	# Firewall info
	log_debug "Collecting firewall information"
	if command_exists iptables && [[ $EUID -eq 0 ]]; then
		run_command "iptables -L" "$OUTPUT_DIR/config/iptables.txt" "iptables rules"
	fi

	if command_exists firewall-cmd; then
		run_command "firewall-cmd --list-all" "$OUTPUT_DIR/config/firewalld.txt" "firewalld configuration"
	fi

	# SELinux info
	if command_exists getenforce; then
		run_command "getenforce" "$OUTPUT_DIR/config/selinux_mode.txt" "SELinux mode"
		run_command "sestatus" "$OUTPUT_DIR/config/selinux_status.txt" "SELinux status"
	fi

	# crontab information
	log_debug "Collecting crontab information"
	if [[ -d /etc/cron.d ]]; then
		mkdir -p "$OUTPUT_DIR/config/cron"
		run_command "ls -la /etc/cron*" "$OUTPUT_DIR/config/cron/cron_dirs.txt" "cron directories"

		for cron_file in /etc/cron*/*; do
			if [[ -f "$cron_file" ]]; then
				run_command "cat $cron_file" "$OUTPUT_DIR/config/cron/$(basename "$cron_file").txt" "cron job $(basename "$cron_file")"
			fi
		done
	fi

	log_info "System configuration collection complete"
}

# Collect Tenstorrent hardware information
collect_tenstorrent_info() {
	log_info "Collecting Tenstorrent hardware information"

	mkdir -p "$OUTPUT_DIR/tenstorrent"

	# Check for Tenstorrent tools
	if command_exists tt-smi; then
		# Collect detailed tt-smi snapshot
		log_debug "Collecting tt-smi snapshot"
		run_command "tt-smi --snapshot" "$OUTPUT_DIR/tenstorrent/tt-smi_snapshot.txt" "Tenstorrent device snapshot"

		# Check for device count
		if device_count=$(tt-smi -f csv 2>/dev/null | tail -n +2 | wc -l) && [ "$device_count" -gt 0 ]; then
			log_debug "Found $device_count Tenstorrent devices"
		fi
	else
		log_warn "tt-smi not found, skipping Tenstorrent hardware information collection"
	fi

	# Check for other Tenstorrent tools
	if command_exists tt-info; then
		log_debug "Collecting tt-info information"
		run_command "tt-info" "$OUTPUT_DIR/tenstorrent/tt-info.txt" "Tenstorrent device detailed information"
	fi

	# Collect Tenstorrent driver information
	log_debug "Collecting Tenstorrent driver information"
	run_command "lsmod | grep tenstorrent" "$OUTPUT_DIR/tenstorrent/driver_modules.txt" "Tenstorrent driver modules" || true
	run_command "dmesg | grep -i tenstorrent" "$OUTPUT_DIR/tenstorrent/dmesg_tenstorrent.txt" "Tenstorrent kernel messages" || true

	# Collect PCIe information for Tenstorrent devices
	if command_exists lspci; then
		log_debug "Collecting PCIe information for Tenstorrent devices"
		run_command "lspci | grep -i tenstorrent" "$OUTPUT_DIR/tenstorrent/pci_devices.txt" "Tenstorrent PCI devices" || true
		run_command "lspci -vv | grep -A 50 -i tenstorrent" "$OUTPUT_DIR/tenstorrent/pci_devices_detailed.txt" "Tenstorrent PCI devices detailed" || true
	fi

	# Collect information about Tenstorrent software packages
	log_debug "Collecting Tenstorrent software package information"
	run_command "pip list | grep -i tenstorrent" "$OUTPUT_DIR/tenstorrent/python_packages.txt" "Tenstorrent Python packages" || true

	# Look for Tenstorrent log files
	log_debug "Checking for Tenstorrent log files"
	if [ -d "/var/log/tenstorrent" ]; then
		mkdir -p "$OUTPUT_DIR/tenstorrent/logs"
		find "/var/log/tenstorrent" -type f -name "*.log" -exec cp {} "$OUTPUT_DIR/tenstorrent/logs/" \; 2>/dev/null || true
	fi

	# Check for Tenstorrent configuration files
	log_debug "Checking for Tenstorrent configuration files"
	if [ -d "/etc/tenstorrent" ]; then
		mkdir -p "$OUTPUT_DIR/tenstorrent/config"
		find "/etc/tenstorrent" -type f -exec cp {} "$OUTPUT_DIR/tenstorrent/config/" \; 2>/dev/null || true
	fi

	log_info "Tenstorrent hardware information collection complete"
}

# Run a performance sampling command as a background process
run_sampling_command() {
	local cmd="$1"
	local output_file="$2"
	local description="$3"
	local duration="$4" # in seconds
	local pid_file="$5"

	log_debug "Starting sampling command: $cmd > $output_file for $duration seconds"

	# Store the PID for later termination
	(
		echo "Starting $description at $(date +"%Y-%m-%d %H:%M:%S")" >"$output_file"
		echo "Command: $cmd" >>"$output_file"
		echo "Duration: $duration seconds" >>"$output_file"
		echo "---------------------------------------------------" >>"$output_file"

		# Start the command with a timeout
		timeout "${duration}s" bash -c "$cmd" >>"$output_file" 2>&1

		echo "---------------------------------------------------" >>"$output_file"
		echo "Completed $description at $(date +"%Y-%m-%d %H:%M:%S")" >>"$output_file"
	) &

	# Store the PID
	echo $! >"$pid_file"
	log_debug "Sampling process $(cat "$pid_file") started for $description"
}

# Collect continuous performance samples
collect_performance_samples() {
	local duration=${SAMPLE_DURATION:-60} # Default to 60 seconds if not set

	log_info "Collecting continuous performance samples for $duration seconds"

	mkdir -p "$OUTPUT_DIR/performance/samples"
	mkdir -p "$OUTPUT_DIR/performance/samples/pids"

	# Start various sampling commands in the background

	# Virtual memory statistics
	if command_exists vmstat; then
		log_debug "Starting vmstat sampling"
		run_sampling_command "vmstat 1" \
			"$OUTPUT_DIR/performance/samples/vmstat.txt" \
			"vmstat sampling" \
			"$duration" \
			"$OUTPUT_DIR/performance/samples/pids/vmstat.pid"
	fi

	# CPU statistics by processor
	if command_exists mpstat; then
		log_debug "Starting mpstat sampling"
		run_sampling_command "mpstat -P ALL 1" \
			"$OUTPUT_DIR/performance/samples/mpstat.txt" \
			"mpstat sampling" \
			"$duration" \
			"$OUTPUT_DIR/performance/samples/pids/mpstat.pid"
	fi

	# I/O statistics
	if command_exists iostat; then
		log_debug "Starting iostat sampling"
		run_sampling_command "iostat -d -x 1" \
			"$OUTPUT_DIR/performance/samples/iostat.txt" \
			"iostat sampling" \
			"$duration" \
			"$OUTPUT_DIR/performance/samples/pids/iostat.pid"
	fi

	# Network statistics
	if command_exists sar && [[ -x /usr/bin/sar || -x /usr/sbin/sar ]]; then
		log_debug "Starting sar network sampling"
		run_sampling_command "sar -n DEV 1" \
			"$OUTPUT_DIR/performance/samples/sar_network.txt" \
			"sar network sampling" \
			"$duration" \
			"$OUTPUT_DIR/performance/samples/pids/sar_network.pid"
	fi

	# Process statistics
	if command_exists pidstat; then
		log_debug "Starting pidstat sampling"
		run_sampling_command "pidstat 1" \
			"$OUTPUT_DIR/performance/samples/pidstat.txt" \
			"pidstat sampling" \
			"$duration" \
			"$OUTPUT_DIR/performance/samples/pids/pidstat.pid"
	fi

	# Memory detailed
	if command_exists sar && [[ -x /usr/bin/sar || -x /usr/sbin/sar ]]; then
		log_debug "Starting sar memory sampling"
		run_sampling_command "sar -r 1" \
			"$OUTPUT_DIR/performance/samples/sar_memory.txt" \
			"sar memory sampling" \
			"$duration" \
			"$OUTPUT_DIR/performance/samples/pids/sar_memory.pid"
	fi

	# GPU/Tenstorrent device sampling if available
	if command_exists tt-smi; then
		log_debug "Starting tt-smi sampling"
		run_sampling_command "while true; do echo \"--- \$(date -Iseconds) ---\"; tt-smi; sleep 1; done" \
			"$OUTPUT_DIR/performance/samples/tt-smi.txt" \
			"tt-smi sampling" \
			"$duration" \
			"$OUTPUT_DIR/performance/samples/pids/tt-smi.pid"
	fi

	log_info "Performance sampling started, will continue for $duration seconds"
	log_info "Collection will continue in the background while other data is being gathered"
}

# Wait for all sampling processes to complete
wait_for_samples() {
	log_info "Waiting for performance sampling to complete"

	# Check if we have any PID files
	if [[ -d "$OUTPUT_DIR/performance/samples/pids" ]]; then
		local pid_files=("$OUTPUT_DIR/performance/samples/pids"/*.pid)
		if [[ ${#pid_files[@]} -gt 0 && -f "${pid_files[0]}" ]]; then
			for pid_file in "$OUTPUT_DIR/performance/samples/pids"/*.pid; do
				if [[ -f "$pid_file" ]]; then
					local pid=$(cat "$pid_file")
					local name=$(basename "$pid_file" .pid)

					if kill -0 "$pid" 2>/dev/null; then
						log_debug "Waiting for $name sampling (PID $pid) to complete..."
						wait "$pid" 2>/dev/null || log_warn "$name sampling (PID $pid) exited with non-zero status"
					else
						log_debug "$name sampling (PID $pid) already completed"
					fi

					# Remove PID file
					rm -f "$pid_file"
				fi
			done
		else
			log_debug "No performance sampling processes to wait for"
		fi
	fi

	log_info "All performance sampling completed"
}

# Collect performance metrics
collect_performance_metrics() {
	log_info "Collecting performance metrics"

	mkdir -p "$OUTPUT_DIR/performance"

	# System load
	log_debug "Collecting system load"
	run_command "uptime" "$OUTPUT_DIR/performance/uptime.txt" "system uptime"
	run_command "cat /proc/loadavg" "$OUTPUT_DIR/performance/loadavg.txt" "load average"

	# Memory statistics
	log_debug "Collecting memory statistics"
	run_command "cat /proc/meminfo" "$OUTPUT_DIR/performance/meminfo_full.txt" "memory information"

	# CPU information and statistics
	log_debug "Collecting CPU statistics"
	run_command "cat /proc/stat" "$OUTPUT_DIR/performance/cpu_stat.txt" "CPU statistics"
	run_command "cat /proc/cpuinfo" "$OUTPUT_DIR/performance/cpuinfo_full.txt" "CPU information"

	# CPU usage (snapshot)
	log_debug "Collecting CPU usage snapshot"
	if command_exists mpstat; then
		run_command "mpstat -P ALL" "$OUTPUT_DIR/performance/mpstat.txt" "CPU usage by processor"
	elif command_exists top; then
		run_command "top -bn1" "$OUTPUT_DIR/performance/top.txt" "top processes"
	fi

	# Memory usage details
	log_debug "Collecting detailed memory usage"
	if command_exists vmstat; then
		run_command "vmstat 1 5" "$OUTPUT_DIR/performance/vmstat.txt" "virtual memory statistics"
	fi

	if command_exists free; then
		run_command "free -m" "$OUTPUT_DIR/performance/free.txt" "memory usage summary"
	fi

	# Disk I/O
	log_debug "Collecting disk I/O statistics"
	run_command "cat /proc/diskstats" "$OUTPUT_DIR/performance/diskstats.txt" "disk statistics"

	if command_exists iostat; then
		run_command "iostat -x" "$OUTPUT_DIR/performance/iostat.txt" "I/O statistics"
	fi

	# Process statistics
	log_debug "Collecting process statistics"
	run_command "ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%mem | head -20" "$OUTPUT_DIR/performance/top_memory_processes.txt" "top memory processes"
	run_command "ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%cpu | head -20" "$OUTPUT_DIR/performance/top_cpu_processes.txt" "top CPU processes"

	# Network statistics
	log_debug "Collecting network statistics"
	if command_exists netstat; then
		run_command "netstat -s" "$OUTPUT_DIR/performance/netstat_stats.txt" "network statistics"
	fi

	if command_exists ip; then
		run_command "ip -s link" "$OUTPUT_DIR/performance/ip_link_stats.txt" "interface statistics"
	fi

	# Start continuous performance sampling
	if [[ "$COLLECTION_LEVEL" == "detailed" || "$COLLECTION_LEVEL" == "debug" ]]; then
		collect_performance_samples
	fi

	log_info "Performance metrics collection complete"
}

# Collect logs based on the specified level
collect_logs() {
	log_info "Collecting logs (level: $INCLUDE_LOGS)"

	mkdir -p "$OUTPUT_DIR/logs"

	# System journal logs (if available)
	if command_exists journalctl; then
		log_debug "Collecting system journal logs"

		case "$INCLUDE_LOGS" in
		"last-hour")
			run_command "journalctl --since '1 hour ago'" "$OUTPUT_DIR/logs/journal_last_hour.txt" "journal logs from last hour"
			run_command "journalctl -p err --since '1 hour ago'" "$OUTPUT_DIR/logs/journal_errors_last_hour.txt" "journal errors from last hour"
			;;
		"last-day")
			run_command "journalctl --since '1 day ago'" "$OUTPUT_DIR/logs/journal_last_day.txt" "journal logs from last day"
			run_command "journalctl -p err --since '1 day ago'" "$OUTPUT_DIR/logs/journal_errors_last_day.txt" "journal errors from last day"
			;;
		"boot")
			run_command "journalctl -b" "$OUTPUT_DIR/logs/journal_current_boot.txt" "journal logs from current boot"
			run_command "journalctl -b -p err" "$OUTPUT_DIR/logs/journal_errors_current_boot.txt" "journal errors from current boot"
			;;
		"full")
			# For full logs, collect errors and warnings to avoid excessive size
			run_command "journalctl -p err --no-pager | tail -1000" "$OUTPUT_DIR/logs/journal_errors.txt" "journal errors"
			run_command "journalctl -p warning --no-pager | tail -1000" "$OUTPUT_DIR/logs/journal_warnings.txt" "journal warnings"
			run_command "journalctl --disk-usage" "$OUTPUT_DIR/logs/journal_disk_usage.txt" "journal disk usage"
			;;
		esac

		# Always collect boot messages
		run_command "journalctl -b 0 -p info | head -1000" "$OUTPUT_DIR/logs/journal_boot_messages.txt" "boot messages"

		# Collect specific system services logs
		for service in systemd kernel dbus; do
			run_command "journalctl -u $service --since '1 day ago' -p err,warning" "$OUTPUT_DIR/logs/journal_${service}.txt" "journal logs for $service"
		done

		# Collect kernel-specific messages
		run_command "journalctl -k --since '1 day ago'" "$OUTPUT_DIR/logs/journal_kernel.txt" "kernel messages from journal"

		# Collect startup logs
		run_command "journalctl -b -p info | head -2000" "$OUTPUT_DIR/logs/journal_startup.txt" "startup messages"
	fi

	# Kernel logs
	log_debug "Collecting kernel logs"
	run_command "dmesg" "$OUTPUT_DIR/logs/dmesg.txt" "kernel ring buffer"
	run_command "dmesg --level=err,warn" "$OUTPUT_DIR/logs/dmesg_errors.txt" "kernel error and warning messages"
	run_command "dmesg --level=emerg,alert,crit" "$OUTPUT_DIR/logs/dmesg_critical.txt" "kernel critical messages"
	run_command "dmesg -T" "$OUTPUT_DIR/logs/dmesg_human_readable.txt" "kernel ring buffer with human-readable timestamps"

	# Traditional system logs (if accessible)
	log_debug "Collecting traditional system logs"

	# Create an array of important log files
	log_files=(
		"/var/log/syslog"
		"/var/log/messages"
		"/var/log/kern.log"
		"/var/log/auth.log"
		"/var/log/dmesg"
		"/var/log/boot.log"
		"/var/log/cron"
		"/var/log/maillog"
	)

	# Copy accessible log files
	for log_file in "${log_files[@]}"; do
		if [[ -f "$log_file" && -r "$log_file" ]]; then
			log_debug "Copying log file: $log_file"

			# Handle compressed logs
			if [[ "$log_file" == *.gz ]]; then
				run_command "cp $log_file" "$OUTPUT_DIR/logs/$(basename "$log_file")" "compressed log file $(basename "$log_file")"
			else
				# For regular logs, we'll get the last N lines to avoid excessive size
				case "$INCLUDE_LOGS" in
				"last-hour" | "boot")
					run_command "tail -n 1000 $log_file" "$OUTPUT_DIR/logs/$(basename "$log_file")" "last 1000 lines of $(basename "$log_file")"
					;;
				"last-day")
					run_command "tail -n 5000 $log_file" "$OUTPUT_DIR/logs/$(basename "$log_file")" "last 5000 lines of $(basename "$log_file")"
					;;
				"full")
					run_command "cp $log_file" "$OUTPUT_DIR/logs/$(basename "$log_file")" "complete log file $(basename "$log_file")"
					;;
				esac
			fi
		fi
	done

	# Check for additional application logs
	log_debug "Checking for application logs"
	app_log_dirs=(
		"/var/log/apache2"
		"/var/log/httpd"
		"/var/log/nginx"
		"/var/log/mysql"
		"/var/log/postgresql"
		"/var/log/containers"
	)

	for app_dir in "${app_log_dirs[@]}"; do
		if [[ -d "$app_dir" && -r "$app_dir" ]]; then
			mkdir -p "$OUTPUT_DIR/logs/applications/$(basename "$app_dir")"
			log_debug "Found application logs in $app_dir"

			# Get a list of error logs only to avoid huge files
			find "$app_dir" -name "*error*log" -type f -readable 2>/dev/null |
				while read -r app_log; do
					if [[ -f "$app_log" ]]; then
						run_command "tail -n 500 $app_log" "$OUTPUT_DIR/logs/applications/$(basename "$app_dir")/$(basename "$app_log")" "application log $(basename "$app_log")"
					fi
				done
		fi
	done

	log_info "Log collection complete"
}

# Generate summary statistics for performance samples
generate_performance_summary() {
	log_info "Generating performance sample summaries"

	mkdir -p "$OUTPUT_DIR/performance/summary"

	# Check if we have performance samples directory
	if [[ ! -d "$OUTPUT_DIR/performance/samples" ]]; then
		log_debug "No performance samples found, skipping summary generation"
		return 0
	fi

	# Create a summary file
	cat >"$OUTPUT_DIR/performance/summary/performance_summary.txt" <<EOF
======================================================
           Performance Sampling Summary
======================================================

Sample Duration: $SAMPLE_DURATION seconds
Collection Time: $(date)

EOF

	# Check and summarize vmstat data
	if [[ -f "$OUTPUT_DIR/performance/samples/vmstat.txt" ]]; then
		log_debug "Summarizing vmstat data"
		echo "## VMSTAT Summary" >>"$OUTPUT_DIR/performance/summary/performance_summary.txt"

		# Extract useful columns from vmstat and calculate averages
		if command_exists awk; then
			echo "Average CPU usage:" >>"$OUTPUT_DIR/performance/summary/performance_summary.txt"
			awk '
        BEGIN {us=0; sy=0; id=0; wa=0; st=0; count=0}
        /^ *[0-9]/ {us+=$13; sy+=$14; id+=$15; wa+=$16; count++}
        END {
          if (count > 0) {
            printf "  User: %.1f%%\n", us/count;
            printf "  System: %.1f%%\n", sy/count;
            printf "  Idle: %.1f%%\n", id/count;
            printf "  Wait: %.1f%%\n", wa/count;
          } else {
            print "  No data available";
          }
        }
      ' "$OUTPUT_DIR/performance/samples/vmstat.txt" >>"$OUTPUT_DIR/performance/summary/performance_summary.txt"

			echo -e "\nMemory usage (in KB):" >>"$OUTPUT_DIR/performance/summary/performance_summary.txt"
			awk '
        BEGIN {swpd=0; free=0; buff=0; cache=0; count=0}
        /^ *[0-9]/ {swpd+=$3; free+=$4; buff+=$5; cache+=$6; count++}
        END {
          if (count > 0) {
            printf "  Swap used: %d\n", swpd/count;
            printf "  Free: %d\n", free/count;
            printf "  Buffer: %d\n", buff/count;
            printf "  Cache: %d\n", cache/count;
          } else {
            print "  No data available";
          }
        }
      ' "$OUTPUT_DIR/performance/samples/vmstat.txt" >>"$OUTPUT_DIR/performance/summary/performance_summary.txt"
		else
			echo "  awk not available, cannot generate vmstat summary" >>"$OUTPUT_DIR/performance/summary/performance_summary.txt"
		fi

		echo -e "\n" >>"$OUTPUT_DIR/performance/summary/performance_summary.txt"
	fi

	# Check and summarize iostat data
	if [[ -f "$OUTPUT_DIR/performance/samples/iostat.txt" ]]; then
		log_debug "Summarizing iostat data"
		echo "## IOSTAT Summary" >>"$OUTPUT_DIR/performance/summary/performance_summary.txt"

		# Extract device names and their average metrics
		if command_exists grep && command_exists awk; then
			# Get a list of unique device names
			grep -o "^[[:space:]]*[[:alnum:]]\+" "$OUTPUT_DIR/performance/samples/iostat.txt" |
				grep -v "^Linux\|^Device\|^avg-cpu\|^Time:" |
				sort -u >"$OUTPUT_DIR/performance/summary/devices.tmp"

			while read -r device; do
				echo "Device: $device" >>"$OUTPUT_DIR/performance/summary/performance_summary.txt"
				awk -v dev="$device" '
          $1 == dev {
            r_s += $3; w_s += $4; rkB_s += $5; wkB_s += $6; 
            await += $10; util += $NF; count++
          }
          END {
            if (count > 0) {
              printf "  Read ops/s: %.2f\n", r_s/count;
              printf "  Write ops/s: %.2f\n", w_s/count;
              printf "  Read KB/s: %.2f\n", rkB_s/count;
              printf "  Write KB/s: %.2f\n", wkB_s/count;
              printf "  Avg wait time (ms): %.2f\n", await/count;
              printf "  Utilization: %.1f%%\n", util/count;
            } else {
              print "  No data available";
            }
          }
        ' "$OUTPUT_DIR/performance/samples/iostat.txt" >>"$OUTPUT_DIR/performance/summary/performance_summary.txt"
				echo >>"$OUTPUT_DIR/performance/summary/performance_summary.txt"
			done <"$OUTPUT_DIR/performance/summary/devices.tmp"

			rm -f "$OUTPUT_DIR/performance/summary/devices.tmp"
		else
			echo "  grep or awk not available, cannot generate iostat summary" >>"$OUTPUT_DIR/performance/summary/performance_summary.txt"
		fi

		echo -e "\n" >>"$OUTPUT_DIR/performance/summary/performance_summary.txt"
	fi

	# Check and summarize tt-smi data if available
	if [[ -f "$OUTPUT_DIR/performance/samples/tt-smi.txt" ]]; then
		log_debug "Summarizing tt-smi data"
		echo "## Tenstorrent Device Summary" >>"$OUTPUT_DIR/performance/summary/performance_summary.txt"

		# Extract basic device information
		if command_exists grep; then
			# Count number of samples
			samples=$(grep -c "--- 20" "$OUTPUT_DIR/performance/samples/tt-smi.txt" || echo 0)
			echo "Collected $samples samples of Tenstorrent device states" >>"$OUTPUT_DIR/performance/summary/performance_summary.txt"

			# Extract power states
			if command_exists grep && command_exists awk; then
				# Process tt-smi output for device stats
				cat "$OUTPUT_DIR/performance/samples/tt-smi.txt" | grep -A 100 "--- 20" | grep -E "Device ID|Power|Clock|Temp" |
					awk '
          /Device ID/ {device=$NF; next}
          /Power/ {
            split($0, parts, "|");
            for (i in parts) {
              if (parts[i] ~ /Power/) {
                gsub(/[^0-9.]/, "", parts[i]);
                power[device] += parts[i];
                power_count[device]++;
              }
            }
          }
          /Temp/ {
            split($0, parts, "|");
            for (i in parts) {
              if (parts[i] ~ /Temp/) {
                gsub(/[^0-9.]/, "", parts[i]);
                temp[device] += parts[i];
                temp_count[device]++;
              }
            }
          }
          END {
            for (dev in power) {
              printf "Device %s:\n", dev;
              if (power_count[dev] > 0) {
                printf "  Average Power: %.2f W\n", power[dev]/power_count[dev];
              }
              if (temp_count[dev] > 0) {
                printf "  Average Temperature: %.2f C\n", temp[dev]/temp_count[dev];
              }
            }
          }
        ' >"$OUTPUT_DIR/performance/summary/tt-smi_summary.tmp"

				# Add the tt-smi summary to the main summary file
				if [[ -s "$OUTPUT_DIR/performance/summary/tt-smi_summary.tmp" ]]; then
					cat "$OUTPUT_DIR/performance/summary/tt-smi_summary.tmp" >>"$OUTPUT_DIR/performance/summary/performance_summary.txt"
				else
					echo "  No parseable Tenstorrent device data found" >>"$OUTPUT_DIR/performance/summary/performance_summary.txt"
				fi

				rm -f "$OUTPUT_DIR/performance/summary/tt-smi_summary.tmp"
			else
				echo "  Required tools not available, cannot generate tt-smi summary" >>"$OUTPUT_DIR/performance/summary/performance_summary.txt"
			fi
		fi

		echo -e "\n" >>"$OUTPUT_DIR/performance/summary/performance_summary.txt"
	fi

	log_info "Performance summary generated at $OUTPUT_DIR/performance/summary/performance_summary.txt"
}

# Format the collected data
format_output() {
	log_info "Formatting output as $OUTPUT_FORMAT"

	# Generate performance sampling summary if available
	if [[ "$COLLECTION_LEVEL" == "detailed" || "$COLLECTION_LEVEL" == "debug" ]]; then
		generate_performance_summary
	fi

	# The output is already collected in individual files for all formats
	echo "Data collection complete. Results available in $OUTPUT_DIR"

	# Additional processing for specific formats
	case "$OUTPUT_FORMAT" in
	"text")
		# Text output is already the default (individual text files)
		;;
	"json")
		# Add JSON metadata and supplementary files
		if command_exists jq; then
			log_debug "Adding JSON metadata"

			# Create a metadata file
			cat >"$OUTPUT_DIR/metadata.json" <<EOF
{
  "collection_time": "$(date -Iseconds)",
  "hostname": "$(hostname)",
  "collection_level": "$COLLECTION_LEVEL",
  "system_id": "$(hostname)-$(date +%Y%m%d)"
}
EOF

			# Note about future implementation
			log_info "Basic JSON metadata created at $OUTPUT_DIR/metadata.json"
			log_info "Note: Full JSON conversion of all data files will be implemented in a future version."
		else
			log_warn "jq not found, metadata.json not created"
		fi
		;;
	*)
		log_error "Unsupported output format: $OUTPUT_FORMAT"
		;;
	esac
}

# Create a summary report
create_summary() {
	log_info "Creating summary report"

	# Get OS information
	os_name=$(grep PRETTY_NAME "$OUTPUT_DIR/software/os_release.txt" 2>/dev/null | sed 's/PRETTY_NAME=//' | tr -d '"' || echo "Unknown OS")
	kernel_version=$(cat "$OUTPUT_DIR/software/kernel_version.txt" 2>/dev/null || echo "Unknown kernel")

	# Get hardware information
	cpu_info=$(grep "Model name" "$OUTPUT_DIR/hardware/cpu_info.txt" 2>/dev/null | sed 's/Model name:[[:space:]]*//' | head -1 || echo "Unknown CPU")
	cpu_cores=$(grep "^CPU(s):" "$OUTPUT_DIR/hardware/cpu_info.txt" 2>/dev/null | awk '{print $2}' || echo "Unknown")
	memory_total=$(grep "MemTotal" "$OUTPUT_DIR/hardware/meminfo.txt" 2>/dev/null | awk '{print $2 " " $3}' || echo "Unknown memory")

	# Get Tenstorrent device information if available
	tt_devices="None detected"
	if [[ -f "$OUTPUT_DIR/tenstorrent/tt-smi.txt" ]]; then
		tt_device_count=$(grep -c "Device ID" "$OUTPUT_DIR/tenstorrent/tt-smi.txt" 2>/dev/null || echo "0")
		if [[ "$tt_device_count" -gt 0 ]]; then
			tt_devices="$tt_device_count devices detected"
		fi
	fi

	# Create summary report
	cat >"$OUTPUT_DIR/summary.txt" <<EOF
=======================================================
      System Diagnostic Data Collection Summary
=======================================================

Collection Date: $(date)
Hostname: $(hostname)
Collection Level: $COLLECTION_LEVEL
Output Format: $OUTPUT_FORMAT

System Summary:
--------------
OS: $os_name
Kernel: $kernel_version
CPU: $cpu_info ($cpu_cores cores)
Memory: $memory_total
Uptime: $(cat "$OUTPUT_DIR/performance/uptime.txt" 2>/dev/null || echo "Unknown")
Tenstorrent: $tt_devices

Collection Includes:
------------------
- Detailed system information (kernel, users, processes, init system)
- Hardware information (CPU, memory, disks, network)
- Software details (OS, kernel, packages, services)
- System configuration (network, security, mounts)
- Performance metrics (CPU, memory, disk, network)
- Performance sampling data (${SAMPLE_DURATION}s continuous monitoring)
- Tenstorrent hardware information (tt-smi, device stats)
- System logs (level: $INCLUDE_LOGS)
- Kernel logs and journal entries

Files Collected: $(find "$OUTPUT_DIR" -type f | wc -l)
Total Collection Size: $(du -sh "$OUTPUT_DIR" | awk '{print $1}')

For detailed information, explore the subdirectories in this output folder.
EOF

	# Add reference to performance summary if available
	if [[ -f "$OUTPUT_DIR/performance/summary/performance_summary.txt" ]]; then
		echo -e "\nPerformance Sampling Summary: $OUTPUT_DIR/performance/summary/performance_summary.txt" >>"$OUTPUT_DIR/summary.txt"
	fi

	# Add inventory of key files
	echo -e "\nKey Files:" >>"$OUTPUT_DIR/summary.txt"
	find "$OUTPUT_DIR" -type f | sort | grep -v "smart" | head -20 >>"$OUTPUT_DIR/summary.txt"
	echo "..." >>"$OUTPUT_DIR/summary.txt"

	log_info "Summary report created at $OUTPUT_DIR/summary.txt"
}

# Collect detailed system information
collect_detailed_system_info() {
	log_info "Collecting detailed system information"

	mkdir -p "$OUTPUT_DIR/system"

	# Kernel and boot information
	log_debug "Collecting kernel and boot information"
	run_command "uname -a" "$OUTPUT_DIR/system/uname_full.txt" "full system information"
	run_command "cat /proc/version" "$OUTPUT_DIR/system/kernel_version.txt" "kernel version details"
	run_command "cat /proc/cmdline" "$OUTPUT_DIR/system/kernel_cmdline.txt" "kernel command line parameters"

	# System uptime and load
	log_debug "Collecting system uptime and load"
	run_command "uptime" "$OUTPUT_DIR/system/uptime.txt" "system uptime"
	run_command "cat /proc/loadavg" "$OUTPUT_DIR/system/loadavg.txt" "system load average"

	# User information
	log_debug "Collecting user information"
	run_command "who" "$OUTPUT_DIR/system/who.txt" "logged in users"
	run_command "w" "$OUTPUT_DIR/system/w.txt" "logged in users and activity"
	run_command "last | head -50" "$OUTPUT_DIR/system/last.txt" "recent logins"

	# System time and timezone
	log_debug "Collecting time and timezone information"
	run_command "date" "$OUTPUT_DIR/system/date.txt" "current system date"
	run_command "timedatectl" "$OUTPUT_DIR/system/timedatectl.txt" "time and timezone details"

	# Init system information
	log_debug "Collecting init system information"
	if command_exists systemctl; then
		run_command "systemctl --version" "$OUTPUT_DIR/system/systemd_version.txt" "systemd version"
		run_command "systemctl status" "$OUTPUT_DIR/system/systemd_status.txt" "systemd status"
		run_command "systemctl list-units --failed" "$OUTPUT_DIR/system/systemd_failed.txt" "failed systemd units"
		run_command "systemctl list-units --state=running" "$OUTPUT_DIR/system/systemd_running.txt" "running systemd units"
	fi

	# Running processes
	log_debug "Collecting process information"
	run_command "ps aux" "$OUTPUT_DIR/system/processes.txt" "all processes"
	run_command "pstree" "$OUTPUT_DIR/system/pstree.txt" "process tree"

	# System limits and capabilities
	log_debug "Collecting system limits"
	run_command "ulimit -a" "$OUTPUT_DIR/system/ulimit.txt" "user limits"
	run_command "sysctl -a" "$OUTPUT_DIR/system/sysctl.txt" "kernel parameters"

	# Installed software
	log_debug "Collecting installed software information"
	if command_exists dpkg; then
		run_command "dpkg -l" "$OUTPUT_DIR/system/installed_packages.txt" "installed packages"
	elif command_exists rpm; then
		run_command "rpm -qa" "$OUTPUT_DIR/system/installed_packages.txt" "installed packages"
	elif command_exists pacman; then
		run_command "pacman -Q" "$OUTPUT_DIR/system/installed_packages.txt" "installed packages"
	fi

	# System localization
	log_debug "Collecting localization information"
	run_command "locale" "$OUTPUT_DIR/system/locale.txt" "system localization"

	# Check for containerization
	log_debug "Checking for containerization"
	run_command "systemd-detect-virt" "$OUTPUT_DIR/system/virtualization.txt" "virtualization environment" || true
	run_command "cat /proc/1/cgroup" "$OUTPUT_DIR/system/cgroups.txt" "control groups"

	log_info "Detailed system information collection complete"
}

# Compress the output directory
compress_output() {
	log_info "Compressing output directory"

	ARCHIVE_FILE="tt-oops-$(hostname)-$(date +%Y%m%d-%H%M%S).tar.gz"

	if command_exists tar; then
		if tar -czf "$ARCHIVE_FILE" -C "$(dirname "$OUTPUT_DIR")" "$(basename "$OUTPUT_DIR")"; then
			log_info "Output compressed to $ARCHIVE_FILE"
			echo "Final output archive: $ARCHIVE_FILE"
			return 0
		else
			log_error "Failed to compress output"
			ARCHIVE_FILE=""
			return 1
		fi
	else
		log_error "tar command not found, cannot compress output"
		ARCHIVE_FILE=""
		return 1
	fi
}

# Display usage information
show_usage() {
	echo "Usage: $SCRIPT_NAME [OPTIONS]"
	echo "Collect system diagnostic information for troubleshooting."
	echo
	echo "Options:"
	echo "  -h, --help            Show this help message and exit"
	echo "  -v, --version         Show version information and exit"
	echo "  -l, --level LEVEL     Collection level (basic, detailed, debug)"
	echo "  -o, --output FORMAT   Output format (text, json)"
	echo "  -d, --dir DIRECTORY   Output directory"
	echo "  --logs LEVEL          Log collection level (none, last-hour, last-day, boot, full)"
	echo "  --log-level LEVEL     Script logging verbosity (error, warn, info, debug)"
	echo "  --no-compress         Don't compress the output"
	echo "  --sample-duration SEC Duration in seconds for continuous performance sampling (default: 60)"
	echo
	echo "Note: Some detailed hardware information requires root privileges and additional"
	echo "      tools like dmidecode, smartctl, lshw, etc. to be installed."
	echo
	echo "Examples:"
	echo "  $SCRIPT_NAME --level basic"
	echo "  $SCRIPT_NAME --level detailed --logs last-day --output json"
	echo "  $SCRIPT_NAME --level debug --logs full --log-level debug"
	echo "  $SCRIPT_NAME --level detailed --sample-duration 120 --logs last-hour"
	echo "  $SCRIPT_NAME -v    # Show version information"
}

# Parse command line arguments
parse_args() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
		-h | --help)
			show_usage
			exit 0
			;;
		-v | --version)
			echo "$SCRIPT_NAME version $VERSION"
			exit 0
			;;
		-l | --level)
			shift
			COLLECTION_LEVEL="$1"
			if [[ "$COLLECTION_LEVEL" != "basic" &&
				"$COLLECTION_LEVEL" != "detailed" &&
				"$COLLECTION_LEVEL" != "debug" ]]; then
				log_error "Invalid collection level: $COLLECTION_LEVEL"
				echo "Valid levels: basic, detailed, debug"
				exit 1
			fi
			;;
		-o | --output)
			shift
			OUTPUT_FORMAT="$1"
			if [[ "$OUTPUT_FORMAT" != "text" &&
				"$OUTPUT_FORMAT" != "json" ]]; then
				log_error "Invalid output format: $OUTPUT_FORMAT"
				echo "Valid formats: text, json"
				exit 1
			fi
			;;
		-d | --dir)
			shift
			OUTPUT_DIR="$1"
			;;
		--logs)
			shift
			INCLUDE_LOGS="$1"
			if [[ "$INCLUDE_LOGS" != "none" &&
				"$INCLUDE_LOGS" != "last-hour" &&
				"$INCLUDE_LOGS" != "last-day" &&
				"$INCLUDE_LOGS" != "boot" &&
				"$INCLUDE_LOGS" != "full" ]]; then
				log_error "Invalid log collection level: $INCLUDE_LOGS"
				echo "Valid levels: none, last-hour, last-day, boot, full"
				exit 1
			fi
			;;
		--log-level)
			shift
			LOG_LEVEL="$1"
			if [[ "$LOG_LEVEL" != "error" &&
				"$LOG_LEVEL" != "warn" &&
				"$LOG_LEVEL" != "info" &&
				"$LOG_LEVEL" != "debug" ]]; then
				log_error "Invalid log level: $LOG_LEVEL"
				echo "Valid levels: error, warn, info, debug"
				exit 1
			fi
			;;
		--no-compress)
			COMPRESS_OUTPUT=false
			;;
		--sample-duration)
			shift
			if [[ "$1" =~ ^[0-9]+$ ]]; then
				SAMPLE_DURATION="$1"
			else
				log_error "Invalid sample duration: $1. Must be a positive integer."
				exit 1
			fi
			;;
		*)
			log_error "Unknown option: $1"
			show_usage
			exit 1
			;;
		esac
		shift
	done

	# Validate output directory
	if [[ -z "$OUTPUT_DIR" ]]; then
		OUTPUT_DIR="$(pwd)/tt-oops-output-$(date +%Y%m%d-%H%M%S)"
	fi

	return 0
}

# Main function
main() {
	echo "TT-OOPS: System Diagnostic Data Collector v$VERSION"
	echo "=============================================="

	# Display help by default if no arguments provided
	if [[ $# -eq 0 ]]; then
		show_usage
		exit 0
	fi

	# Parse command line arguments
	parse_args "$@"

	# Check for required privileges
	check_privileges || log_warn "Running with limited privileges, some data may not be collected"

	# Check for required dependencies
	check_dependencies || exit 1

	# Create output directory
	log_info "Creating output directory: $OUTPUT_DIR"
	create_output_dir || exit 1
	log_info "Output directory created: $OUTPUT_DIR"

	# Collect detailed system information
	collect_detailed_system_info

	# Collect data based on the specified collection level
	collect_hardware_info
	collect_software_info
	collect_system_config
	collect_performance_metrics
	collect_tenstorrent_info

	# Collect logs if requested
	if [[ "$INCLUDE_LOGS" != "none" ]]; then
		collect_logs
	fi

	# Wait for any running performance sampling to complete
	wait_for_samples

	# Format the collected data
	format_output

	# Create a summary report
	create_summary

	# Compress the output directory
	if [[ "$COMPRESS_OUTPUT" == true ]]; then
		compress_output
	fi

	echo
	echo "Collection complete. Results available in $OUTPUT_DIR"
	if [[ "$COMPRESS_OUTPUT" == true && -n "$ARCHIVE_FILE" && -f "$ARCHIVE_FILE" ]]; then
		echo "Compressed archive available: $ARCHIVE_FILE"
	fi
	echo "=============================================="

	return 0
}

# Execute main function with all arguments
main "$@"
