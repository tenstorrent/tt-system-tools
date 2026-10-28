#!/bin/bash 
# SPDX-FileCopyrightText: © 2024 Tenstorrent Inc.
# SPDX-License-Identifier: Apache-2.0
#
# This script sets up the hugepage config needed for Tenstorrent ASICs.
# For every Wormhole we allocate a full 4x1G pages, maximize the
# aperture between device and host.

set -eo pipefail

TT_VID=1e52
GS_PID=faca
WH_PID=401e
BH_PID=b140

# Two arguments: VIDPID to lspci, and multiplier per card found.
# Returns: <node> <pages>, one per line per card
get_node_pages() {
   VIDPID="$1"
   MULT="$2"
   # Need to do this since not all machines print NUMANode: for all devices, in that
   # case default to node 0.
   lspci -d "${VIDPID}" -vmm | awk "BEGIN {n=0} /NUMANode:/ {n=\$2} /^$/ {print n \" ${MULT}\"}"
}

error_out() {
  echo "$1" >&2
  exit 1
}

declare -A nodes
# For BH we want 4 1GB hugepages per device unless overridden.
# For WH we want 4 1GB hugepages per device unless overridden.
# For GS we want 1 1GB hugepage per device unless overridden.
file_path="/opt/tenstorrent/bin/hugepages-override.txt"
if [[ -f "$file_path" ]]; then
    HP_OVERRIDE=$(<"$file_path")
    TT_COUNT=$(lspci -d "${TT_VID}": | wc -l)
    echo "hugepages override requested via hugepages-override.txt: $HP_OVERRIDE"
    HP_COUNT=$((HP_OVERRIDE / TT_COUNT))

    while read -r index value ; do
        nodes[$index]=$((nodes[$index] + value))
    done < <(
        get_node_pages "${TT_VID}:${BH_PID}" "$HP_COUNT"
        get_node_pages "${TT_VID}:${WH_PID}" "$HP_COUNT"
        get_node_pages "${TT_VID}:${GS_PID}" "$HP_COUNT"
    )
else
    while read -r index value ; do
        nodes[$index]=$((nodes[$index] + value))
    done < <(
        get_node_pages "${TT_VID}:${BH_PID}" 4
        get_node_pages "${TT_VID}:${WH_PID}" 4
        get_node_pages "${TT_VID}:${GS_PID}" 1
    )
fi

# Now, let's iterate over the nodes and configure the number of
# hugepages.
NODES=${!nodes[*]}

# Kernels built without CONFIG_NUMA -- common on embedded arm64 and riscv64 SoCs -- expose no
# /sys/devices/system/node hierarchy at all. Such a system has a single memory node, so total
# up every card's request and drive the global hugepage control instead of a per-node one.
if [ -d /sys/devices/system/node ] ; then
    NUMA_SYSFS=true
else
    NUMA_SYSFS=false
    total=0
    for n in $NODES ; do
        total=$((total + nodes[$n]))
    done
    unset nodes
    declare -A nodes=([0]="${total}")
    NODES=0
fi

# First, make sure we have the hugepages configured and available.
for n in $NODES ; do
    if $NUMA_SYSFS ; then
        NODEDIR="/sys/devices/system/node/node${n}"
        [ -d "${NODEDIR}" ] || error_out "Can't locate numa node directory at $NODEDIR. Check setup."
        HUGEPAGE_DIR="${NODEDIR}/hugepages/hugepages-1048576kB"
        LABEL="Node ${n}"
    else
        HUGEPAGE_DIR="/sys/kernel/mm/hugepages/hugepages-1048576kB"
        LABEL="System"
    fi
    [ -d "${HUGEPAGE_DIR}" ] || error_out "Can't locate 1GB hugepage settings at ${HUGEPAGE_DIR}. Check setup."

    NR_HP="$(cat "${HUGEPAGE_DIR}/nr_hugepages")"
    echo "${LABEL} hugepages before: ${NR_HP}"
    echo "${LABEL} hugepages needed: ${nodes[$n]}"
    echo "${nodes[$n]}" > "${HUGEPAGE_DIR}/nr_hugepages" || error_out "Can't write to hugepages file at ${HUGEPAGE_DIR}/nr_hugepages"
    NR_HP="$(cat "${HUGEPAGE_DIR}/nr_hugepages")"
    echo "${LABEL} hugepages after: ${NR_HP}"
    if [ "${NR_HP}" != "${nodes[$n]}" ] ; then
        error_out "Failed to get requested ${nodes[$n]} hugepages, only got ${NR_HP}"
    fi
done

echo "Completed hugepage setup"
exit 0
