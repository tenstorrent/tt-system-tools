## Tenstorrent System Tools

## Official Repository

[https://github.com/tenstorrent/tt-system-tools](https://github.com/tenstorrent/tt-system-tools)

## Supported hardware:
* Grayskull
* Wormhole
* Blackhole (WIP)

## Supported OSes/package managers:
* Debian-based (.deb)
* Red-hat-based (.rpm)

This repository contains tools and utilities for managing the
Tenstorrent hardware in a system:

* **hugepages-setup**: Configuration of 1GB hugepages for Tenstorrent ASICs
* **tt-oops**: System diagnostic data collector for troubleshooting

See README.md in each tool subdirectory for more details.

## Installation

When installed via RPM or DEB packages, the tools are installed to:
* Scripts: `/opt/tenstorrent/bin/`
* Systemd services: `/lib/systemd/system/` or `/usr/lib/systemd/system/`
