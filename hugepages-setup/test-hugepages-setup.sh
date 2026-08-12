#!/usr/bin/env bash
# SPDX-FileCopyrightText: © 2026 Tenstorrent Inc.
# SPDX-License-Identifier: Apache-2.0
#
# Tests for hugepage allocation arithmetic (issue #15).
#
# The script used to write the number of pages Tenstorrent needs straight into
# nr_hugepages, which discards whatever the machine had already been configured
# with - a VM backed by 1G pages, for example. These cover adding on top of an
# existing allocation and converging on a re-run rather than stacking.
#
# Runs against a fixture sysfs tree and a stub lspci, so no Tenstorrent
# hardware and no root are needed.
#
# Usage: hugepages-setup/test-hugepages-setup.sh

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${HERE}/hugepages-setup.sh"
[ -x "${SCRIPT}" ] || [ -f "${SCRIPT}" ] || { echo "cannot find hugepages-setup.sh" >&2; exit 1; }

PASS=0
FAIL=0

check() {
	local desc="$1" expected="$2" actual="$3"
	if [[ "${expected}" == "${actual}" ]] ; then
		PASS=$((PASS + 1))
	else
		FAIL=$((FAIL + 1))
		echo "FAIL: ${desc} - expected ${expected}, got ${actual}"
	fi
}

# Build a fixture: one NUMA node preloaded with `existing` 1G pages, and an
# lspci that reports `cards` Wormholes on node 0.
make_fixture() {
	local existing="$1" cards="$2"
	FIXTURE="$(mktemp -d)"
	local hp="${FIXTURE}/sys/devices/system/node/node0/hugepages/hugepages-1048576kB"
	mkdir -p "${hp}"
	echo "${existing}" > "${hp}/nr_hugepages"
	echo "${existing}" > "${hp}/free_hugepages"

	mkdir -p "${FIXTURE}/bin"
	{
		echo '#!/usr/bin/env bash'
		# -vmm output: one stanza per device, blank-line separated, as the
		# script's awk expects. Only the WH id yields devices.
		echo 'if [[ "$*" == *"401e"* ]] ; then'
		echo "  for i in \$(seq 1 ${cards}) ; do"
		echo '    printf "Slot:\t00:01.0\nNUMANode:\t0\n\n"'
		echo '  done'
		echo 'fi'
		echo 'exit 0'
	} > "${FIXTURE}/bin/lspci"
	chmod +x "${FIXTURE}/bin/lspci"

	NR_FILE="${hp}/nr_hugepages"
	STATE="${FIXTURE}/run"
}

run_script() {
	PATH="${FIXTURE}/bin:${PATH}" \
	SYSFS_ROOT="${FIXTURE}/sys" \
	STATE_DIR="${STATE}" \
		bash "${SCRIPT}" >/dev/null 2>&1
	return $?
}

# ---- a machine with nothing configured ----------------------------------
make_fixture 0 1
run_script
check "fresh machine, one WH gets 4 pages" "4" "$(cat "${NR_FILE}")"
rm -rf "${FIXTURE}"

make_fixture 0 2
run_script
check "fresh machine, two WH get 8 pages" "8" "$(cat "${NR_FILE}")"
rm -rf "${FIXTURE}"

# ---- the bug in #15: an existing allocation must survive -----------------
make_fixture 32 1
run_script
check "existing 32 pages are kept, not replaced" "36" "$(cat "${NR_FILE}")"
rm -rf "${FIXTURE}"

make_fixture 32 2
run_script
check "existing 32 pages plus two cards" "40" "$(cat "${NR_FILE}")"
rm -rf "${FIXTURE}"

# ---- re-running must converge, not stack --------------------------------
make_fixture 32 1
run_script
first="$(cat "${NR_FILE}")"
run_script
check "second run does not add again" "${first}" "$(cat "${NR_FILE}")"
run_script
check "third run does not add again" "${first}" "$(cat "${NR_FILE}")"
rm -rf "${FIXTURE}"

make_fixture 0 1
run_script
run_script
check "re-run on a fresh machine stays at 4" "4" "$(cat "${NR_FILE}")"
rm -rf "${FIXTURE}"

# ---- a fresh boot clears the marker, and the count has reset too --------
make_fixture 32 1
run_script
rm -rf "${STATE}"          # /run is tmpfs; boot clears it
echo 32 > "${NR_FILE}"     # nr_hugepages resets to the cmdline value
run_script
check "after a reboot the machine lands on the same total" "36" "$(cat "${NR_FILE}")"
rm -rf "${FIXTURE}"

# ---- someone lowered the count behind our back --------------------------
make_fixture 32 1
run_script
echo 2 > "${NR_FILE}"      # now below what we recorded as ours
run_script
check "a lowered count does not produce a negative target" "4" "$(cat "${NR_FILE}")"
rm -rf "${FIXTURE}"

# ---- the script still fails loudly when the node is missing -------------
make_fixture 0 1
rm -rf "${FIXTURE}/sys/devices/system/node/node0"
run_script
check "missing numa node is still an error" "1" "$?"
rm -rf "${FIXTURE}"

echo
echo "${PASS} passed, ${FAIL} failed"
[[ "${FAIL}" -eq 0 ]]
