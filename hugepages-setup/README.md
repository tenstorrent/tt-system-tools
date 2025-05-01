# Hugepages Setup for Tenstorrent ASICs

This directory contains the necessary files to configure 1GB hugepages for Tenstorrent ASICs.

## Components

* `hugepages-setup.sh`: Script that configures the number of 1GB hugepages based on detected Tenstorrent hardware
* `tenstorrent-hugepages.service`: Systemd service that runs the hugepages setup script during system boot
* `dev-hugepages-1G.mount`: Systemd mount unit that mounts hugetlbfs at /dev/hugepages-1G

## Functionality

The hugepages setup script:

1. Detects Tenstorrent ASICs in the system (Grayskull, Wormhole, Blackhole)
2. Determines the NUMA node for each device
3. Allocates the appropriate number of 1GB hugepages:
   - 4 pages per Wormhole/Blackhole device (default)
   - 1 page per Grayskull device (default)
   - Override via `/opt/tenstorrent/bin/hugepages-override.txt` if needed
4. Configures the hugepages in the system

## Custom Configuration

If you need to override the default number of hugepages, create a text file at `/opt/tenstorrent/bin/hugepages-override.txt` with a single number representing the total number of hugepages to allocate. This will be evenly distributed across all detected Tenstorrent devices.

## Requirements

- Linux system with NUMA support
- Root privileges for the initial setup
- hugetlbfs kernel support
- pciutils package installed