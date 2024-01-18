# Copyright OpenSearch Contributors
# SPDX-License-Identifier: Apache-2.0
#
# The OpenSearch Contributors require contributions made to
# this file be licensed under the Apache-2.0 license or a
# compatible open source license.

# No build, no debuginfo
%define debug_package %{nil}

# Disable brp-java-repack-jars, so jars will not be decompressed and repackaged
%define __jar_repack 0

# Generate digests, 8 means algorithm of sha256
# This is different from rpm sig algorithm
# Requires rpm version 4.12 + to generate but b/c run on older versions
%define _source_filedigest_algorithm 8
%define _binary_filedigest_algorithm 8

# Fixed in Fedora: 
# https://www.endpointdev.com/blog/2011/10/rpm-building-fedoras-sharedstatedir/
%define _sharedstatedir /var/lib

# User Define Variables
%define product_dir %{_datadir}/%{name}
%define config_dir %{_sysconfdir}/%{name}
%define data_dir %{_sharedstatedir}/%{name}
%define log_dir %{_localstatedir}/log/%{name}
%define pid_dir %{_localstatedir}/run/%{name}
%{!?_version: %define _version 0.0.0 }
%{!?_architecture: %define _architecture x86_64 }

Name: wazuh-indexer
Version: %{_version}
Release: 1
License: Apache-2.0
Summary: An open source distributed and RESTful search engine
URL: https://www.wazuh.com/
Vendor:      Wazuh, Inc <info@wazuh.com>
Packager:    Wazuh, Inc <info@wazuh.com>
Group: Application/Internet
ExclusiveArch: %{_architecture}
AutoReqProv: no

%description
Wazuh indexer is a near real-time full-text search and analytics engine that 
gathers security-related data into one platform. This Wazuh central component 
indexes and stores alerts generated by the Wazuh server. Wazuh indexer can be 
configured as a single-node or multi-node cluster, providing scalability and 
high availability.
For more information, see: https://www.wazuh.com/

%prep
# No-op. We are using dir so no need to setup.

%build
# No-op. This is all pre-built Java. Nothing to do here.

%install
set -e
cd %{_topdir} && pwd
# Create necessary directories
mkdir -p %{buildroot}%{pid_dir}
mkdir -p %{buildroot}%{product_dir}/plugins
# Install directories/files
cp -a etc usr var %{buildroot}
chmod 0755 %{buildroot}%{product_dir}/bin/*
if [ -d %{buildroot}%{product_dir}/plugins/opensearch-security ]; then
    chmod 0755 %{buildroot}%{product_dir}/plugins/opensearch-security/tools/*
fi
# Pre-populate the folders to ensure rpm build success even without all plugins
mkdir -p %{buildroot}%{config_dir}/opensearch-observability
mkdir -p %{buildroot}%{config_dir}/opensearch-reports-scheduler
mkdir -p %{buildroot}%{product_dir}/performance-analyzer-rca

# Pre-populate PA configs if not present
if [ ! -f %{buildroot}%{data_dir}/rca_enabled.conf ]; then
    echo 'true' > %{buildroot}%{data_dir}/rca_enabled.conf
fi
if [ ! -f %{buildroot}%{data_dir}/performance_analyzer_enabled.conf ]; then
    echo 'true' > %{buildroot}%{data_dir}/performance_analyzer_enabled.conf
fi
# Change Permissions
chmod -Rf a+rX,u+w,g-w,o-w %{buildroot}/*
exit 0

%pre
set -e
# Stop existing service
if command -v systemctl >/dev/null && systemctl is-active %{name}.service >/dev/null; then
    echo "Stop existing %{name}.service"
    systemctl --no-reload stop %{name}.service
fi
if command -v systemctl >/dev/null && systemctl is-active %{name}-performance-analyzer.service >/dev/null; then
    echo "Stop existing %{name}-performance-analyzer.service"
    systemctl --no-reload stop %{name}-performance-analyzer.service
fi
# Create user and group if they do not already exist.
getent group %{name} > /dev/null 2>&1 || groupadd -r %{name}
getent passwd %{name} > /dev/null 2>&1 || \
    useradd -r -g %{name} -M -s /sbin/nologin \
        -c "%{name} user/group" %{name}
exit 0

%post
set -e
# Apply Security Settings
if [ -d %{product_dir}/plugins/opensearch-security ]; then
    sh %{product_dir}/plugins/opensearch-security/tools/install_demo_configuration.sh -y -i -s > %{log_dir}/install_demo_configuration.log 2>&1
fi
chown -R %{name}.%{name} %{config_dir}
chown -R %{name}.%{name} %{log_dir}
# Apply PerformanceAnalyzer Settings
chmod a+rw /tmp
if ! grep -q '## OpenSearch Performance Analyzer' %{config_dir}/jvm.options; then
   # Add Performance Analyzer settings in %{config_dir}/jvm.options
   CLK_TCK=`/usr/bin/getconf CLK_TCK`
   echo >> %{config_dir}/jvm.options
   echo '## OpenSearch Performance Analyzer' >> %{config_dir}/jvm.options
   echo "-Dclk.tck=$CLK_TCK" >> %{config_dir}/jvm.options
   echo "-Djdk.attach.allowAttachSelf=true" >> %{config_dir}/jvm.options
   echo "-Djava.security.policy=file://%{config_dir}/opensearch-performance-analyzer/opensearch_security.policy" >> %{config_dir}/jvm.options
   echo "--add-opens=jdk.attach/sun.tools.attach=ALL-UNNAMED" >> %{config_dir}/jvm.options
fi
# Reload systemctl daemon
if command -v systemctl > /dev/null; then
    systemctl daemon-reload
fi
# Reload other configs
if command -v systemctl > /dev/null; then
    systemctl restart systemd-sysctl.service || true
fi

if command -v systemd-tmpfiles > /dev/null; then
    systemd-tmpfiles --create %{name}.conf
fi

# Messages
echo "### NOT starting on installation, please execute the following statements to configure wazuh-indexer service to start automatically using systemd"
echo " sudo systemctl daemon-reload"
echo " sudo systemctl enable wazuh-indexer.service"
echo "### You can start wazuh-indexer service by executing"
echo " sudo systemctl start wazuh-indexer.service"
exit 0

%preun
set -e
if command -v systemctl >/dev/null && systemctl is-active %{name}.service >/dev/null; then
    echo "Stop existing %{name}.service"
    systemctl --no-reload stop %{name}.service
fi
if command -v systemctl >/dev/null && systemctl is-active %{name}-performance-analyzer.service >/dev/null; then
    echo "Stop existing %{name}-performance-analyzer.service"
    systemctl --no-reload stop %{name}-performance-analyzer.service
fi
exit 0

%files
# Permissions
%defattr(-, %{name}, %{name})

# Root dirs/docs/licenses
%dir %{product_dir}
%doc %{product_dir}/NOTICE.txt
%doc %{product_dir}/README.md
%license %{product_dir}/LICENSE.txt

# Config dirs/files
%dir %{config_dir}
%{config_dir}/jvm.options.d
%{config_dir}/opensearch-*
%config(noreplace) %{config_dir}/opensearch.yml
%config(noreplace) %{config_dir}/jvm.options
%config(noreplace) %{config_dir}/log4j2.properties
%config(noreplace) %{data_dir}/rca_enabled.conf
%config(noreplace) %{data_dir}/performance_analyzer_enabled.conf

# Service files
%attr(0644, root, root) %{_prefix}/lib/systemd/system/%{name}.service
%attr(0644, root, root) %{_prefix}/lib/systemd/system/%{name}-performance-analyzer.service
%attr(0644, root, root) %{_sysconfdir}/init.d/%{name}
%attr(0644, root, root) %config(noreplace) %{_sysconfdir}/sysconfig/%{name}
%attr(0644, root, root) %config(noreplace) %{_prefix}/lib/sysctl.d/%{name}.conf
%attr(0644, root, root) %config(noreplace) %{_prefix}/lib/tmpfiles.d/%{name}.conf

# Main dirs
%{product_dir}/bin
%{product_dir}/jdk
%{product_dir}/lib
%{product_dir}/modules
%{product_dir}/performance-analyzer-rca
%{product_dir}/plugins
%{log_dir}
%{pid_dir}
%dir %{data_dir}

# Wazuh additional files
%attr(440, %{name}, %{name}) %{product_dir}/VERSION
%attr(750, %{name}, %{name}) %{product_dir}/bin/indexer-security-init.sh
%attr(750, %{name}, %{name}) %{product_dir}/bin/indexer-ism-init.sh
%attr(750, %{name}, %{name}) %{product_dir}/bin/indexer-init.sh

%changelog
* Thu Mar 28 2024 support <info@wazuh.com> - 4.9.0
- More info: https://documentation.wazuh.com/current/release-notes/release-4-9-0.html
* Tue Jan 30 2024 support <info@wazuh.com> - 4.8.1
- More info: https://documentation.wazuh.com/current/release-notes/release-4-8-1.html
* Fri Dec 15 2023 support <info@wazuh.com> - 4.8.0
- More info: https://documentation.wazuh.com/current/release-notes/release-4-8-0.html
* Tue Dec 05 2023 support <info@wazuh.com> - 4.7.1
- More info: https://documentation.wazuh.com/current/release-notes/release-4-7-1.html
* Tue Nov 21 2023 support <info@wazuh.com> - 4.7.0
- More info: https://documentation.wazuh.com/current/release-notes/release-4-7-0.html
* Tue Oct 31 2023 support <info@wazuh.com> - 4.6.0
- More info: https://documentation.wazuh.com/current/release-notes/release-4-6-0.html
* Tue Oct 24 2023 support <info@wazuh.com> - 4.5.4
- More info: https://documentation.wazuh.com/current/release-notes/release-4-5-4.html
* Tue Oct 10 2023 support <info@wazuh.com> - 4.5.3
- More info: https://documentation.wazuh.com/current/release-notes/release-4-5-3.html
* Thu Aug 31 2023 support <info@wazuh.com> - 4.5.2
- More info: https://documentation.wazuh.com/current/release-notes/release-4-5-2.html
* Thu Aug 24 2023 support <info@wazuh.com> - 4.5.1
- More info: https://documentation.wazuh.com/current/release-notes/release-4-5.1.html
* Thu Aug 10 2023 support <info@wazuh.com> - 4.5.0
- More info: https://documentation.wazuh.com/current/release-notes/release-4-5-0.html
* Mon Jul 10 2023 support <info@wazuh.com> - 4.4.5
- More info: https://documentation.wazuh.com/current/release-notes/release-4-4-5.html
* Tue Jun 13 2023 support <info@wazuh.com> - 4.4.4
- More info: https://documentation.wazuh.com/current/release-notes/release-4-4-4.html
* Thu May 25 2023 support <info@wazuh.com> - 4.4.3
- More info: https://documentation.wazuh.com/current/release-notes/release-4-4-3.html
* Mon May 08 2023 support <info@wazuh.com> - 4.4.2
- More info: https://documentation.wazuh.com/current/release-notes/release-4-4-2.html
* Mon Apr 17 2023 support <info@wazuh.com> - 4.4.1
- More info: https://documentation.wazuh.com/current/release-notes/release-4-4-1.html
* Wed Jan 18 2023 support <info@wazuh.com> - 4.4.0
- More info: https://documentation.wazuh.com/current/release-notes/release-4-4-0.html
* Thu Nov 10 2022 support <info@wazuh.com> - 4.3.10
- More info: https://documentation.wazuh.com/current/release-notes/release-4-3-10.html
* Mon Oct 03 2022 support <info@wazuh.com> - 4.3.9
- More info: https://documentation.wazuh.com/current/release-notes/release-4-3-9.html
* Mon Sep 19 2022 support <info@wazuh.com> - 4.3.8
- More info: https://documentation.wazuh.com/current/release-notes/release-4-3-8.html
* Mon Aug 08 2022 support <info@wazuh.com> - 4.3.7
- More info: https://documentation.wazuh.com/current/release-notes/release-4-3-7.html
* Thu Jul 07 2022 support <info@wazuh.com> - 4.3.6
- More info: https://documentation.wazuh.com/current/release-notes/release-4-3-6.html
* Wed Jun 29 2022 support <info@wazuh.com> - 4.3.5
- More info: https://documentation.wazuh.com/current/release-notes/release-4-3-5.html
* Tue Jun 07 2022 support <info@wazuh.com> - 4.3.4
- More info: https://documentation.wazuh.com/current/release-notes/release-4-3-4.html
* Tue May 31 2022 support <info@wazuh.com> - 4.3.3
- More info: https://documentation.wazuh.com/current/release-notes/release-4-3-3.html
* Mon May 30 2022 support <info@wazuh.com> - 4.3.2
- More info: https://documentation.wazuh.com/current/release-notes/release-4-3-2.html
* Wed May 18 2022 support <info@wazuh.com> - 4.3.1
- More info: https://documentation.wazuh.com/current/release-notes/release-4-3-1.html
* Thu May 05 2022 support <info@wazuh.com> - 4.3.0
- More info: https://documentation.wazuh.com/current/release-notes/release-4-3-0.html
- Initial package
