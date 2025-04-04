#! /bin/bash
# This script is for development and testing; please don't use it unless you know what you're doing.

# Set up RPM build environment (if not already done)
mkdir -p ~/rpmbuild/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}

# Copy source files
cp dev-hugepages\\x2d1G.mount ~/rpmbuild/SOURCES/
cp hugepages-setup.sh ~/rpmbuild/SOURCES/
cp tenstorrent-hugepages.service ~/rpmbuild/SOURCES/

cp tenstorrent-tools.spec ~/rpmbuild/SPECS/

# This is a stupid hack to work around the fact that rpmbuild can't handle backslashes in filenames.
ln -sf ~/rpmbuild/SOURCES/"dev-hugepages\x2d1G.mount" ~/rpmbuild/SOURCES/tt-hugepages-mount

# Build the RPM
rpmbuild -bb --noclean ~/rpmbuild/SPECS/tenstorrent-tools.spec
