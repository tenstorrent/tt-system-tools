%global _name tenstorrent-tools

Name:           %{_name}
Version:        1.0.0
Release:        1%{?dist}
Summary:        Setup scripts for Tenstorrent hardware
License:        Apache-2.0

BuildArch:      noarch
Requires:       pciutils

Source0:        hugepages-setup.sh
Source1:        tenstorrent-hugepages.service
# This is actually 'dev-hugepages\x2d1G.mount`, but it's symlinked here
# to get around rpmbuild's inability to handle backslashes in filenames.
Source2:        tt-hugepages-mount

%description
This package contains setup scripts for Tenstorrent hardware.
It includes any setup scripts, including systemd loading helpers,
for the system to use to help get the cards up and running.
This includes: hugepages setup.

%prep
# Nothing to prep

%build
# Nothing to build

%install
mkdir -p %{buildroot}/opt/tenstorrent/bin
mkdir -p %{buildroot}%{_unitdir}
mkdir -p %{buildroot}%{_sbindir}

install -m 755 %{SOURCE0} %{buildroot}/opt/tenstorrent/bin/
install -m 644 %{SOURCE1} %{buildroot}%{_unitdir}/
install -m 644 %{SOURCE2} %{buildroot}%{_unitdir}/dev-hugepages\\x2d1G.mount

# Create post-install script
cat > %{buildroot}%{_sbindir}/tenstorrent-tools.post <<EOF
#!/bin/bash
systemctl daemon-reload
systemctl enable tenstorrent-hugepages.service
systemctl enable dev-hugepages\\x2d1G.mount
EOF
chmod 755 %{buildroot}%{_sbindir}/tenstorrent-tools.post

%post
%{_sbindir}/tenstorrent-tools.post

%files
/opt/tenstorrent/bin/hugepages-setup.sh
%{_unitdir}/tenstorrent-hugepages.service
%{_unitdir}/dev-hugepages\x2d1G.mount
%{_sbindir}/tenstorrent-tools.post

%changelog
* Tue Mar 18 2025 June Knauth <jknauth@tenstorrent.com> - 1.1.0-1
- Fix sourcing and work around special characters
* Fri Mar 14 2025 June Knauth <jknauth@tenstorrent.com> - 1.1.0-1
- Initial RPM package
