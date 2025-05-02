%global _name tenstorrent-tools

Name:           %{_name}
Version:        1.3.1
Release:        1%{?dist}
Summary:        Setup and support scripts for Tenstorrent hardware
License:        Apache-2.0

BuildArch:      noarch
Requires:       pciutils

Source0:        hugepages-setup/hugepages-setup.sh
Source1:        hugepages-setup/tenstorrent-hugepages.service
# This is actually 'dev-hugepages\x2d1G.mount`, but it's symlinked here
# to get around rpmbuild's inability to handle backslashes in filenames.
Source2:        hugepages-setup/tt-hugepages-mount
Source3:        tt-oops/tt-oops.sh

%description
This package contains setup and support scripts for Tenstorrent hardware.
It includes any setup scripts, including systemd loading helpers, for
the system to use to help get the cards up and running.
It also includes helper scripts for support and diagnosing issues with
the hardware or software.

%prep
# Nothing to prep

%build
# Nothing to build

%install
mkdir -p %{buildroot}/opt/tenstorrent/bin
mkdir -p %{buildroot}%{_unitdir}
mkdir -p %{buildroot}%{_sbindir}

# Install hugepages setup files
install -m 755 %{SOURCE0} %{buildroot}/opt/tenstorrent/bin/
install -m 644 %{SOURCE1} %{buildroot}%{_unitdir}/
install -m 644 %{SOURCE2} %{buildroot}%{_unitdir}/dev-hugepages\\x2d1G.mount

# Install tt-oops script
install -m 755 %{SOURCE3} %{buildroot}/opt/tenstorrent/bin/tt-oops

# Create post-install script
cat > %{buildroot}%{_sbindir}/tenstorrent-tools.post <<'EOF'
#!/bin/bash
systemctl daemon-reload
systemctl enable --now tenstorrent-hugepages.service
systemctl enable --now "dev-hugepages\\x2d1G.mount"
EOF
chmod 755 %{buildroot}%{_sbindir}/tenstorrent-tools.post

%post
%{_sbindir}/tenstorrent-tools.post

%files
/opt/tenstorrent/bin/hugepages-setup.sh
/opt/tenstorrent/bin/tt-oops
%{_unitdir}/tenstorrent-hugepages.service
%{_unitdir}/dev-hugepages\x2d1G.mount
%{_sbindir}/tenstorrent-tools.post

%changelog
* Thu May 1 2025 Olof Johansson <olofj@tenstorrent.com> - 1.3.1
- tt-oops: Don't collect tt-smi samples for performance yet
- tt-oops: Collect ethtool output for network interfaces

* Tue Apr 30 2025 Olof Johansson <olofj@tenstorrent.com> - 1.3.0-1
- Refactor repository structure
- Add tt-oops system diagnostic tool

* Fri Apr 4  2025 June Knauth <jknauth@tenstorrent.com> - 1.2.0-1
- Bump to version 1.2
* Tue Mar 18 2025 June Knauth <jknauth@tenstorrent.com> - 1.1.0-1
- Fix sourcing and work around special characters
* Fri Mar 14 2025 June Knauth <jknauth@tenstorrent.com> - 1.1.0-1
- Initial RPM package
