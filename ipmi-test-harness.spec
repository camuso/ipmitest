Name:           ipmi-test-harness
Version:        1.0
Release:        9%{?dist}
Summary:        Comprehensive IPMI test harness for BMC validation

License:        GPLv3+
URL:            https://github.com/yourusername/ipmi-test-harness
Source0:        %{name}.tar.gz

BuildArch:      noarch
BuildRequires:  bash

%description
The IPMI Test Harness is a comprehensive, modular testing framework for
validating BMC (Baseboard Management Controller) implementations. It provides
snapshot-safe, idempotent test routines for sensor monitoring, power control,
event logging, and authentication across diverse hardware platforms.

%prep
%setup -q -n %{name}

%build
# No build steps required for script-based package

%install
rm -rf %{buildroot}

# Install main executable script to /usr/local/bin (standard RHEL location for 3rd party executables)
install -d %{buildroot}/usr/local/bin
install -m 0755 ipmi-test-harness %{buildroot}/usr/local/bin/

# Install test module scripts to /usr/local/libexec/ipmi-test-harness
install -d %{buildroot}/usr/local/libexec/ipmi-test-harness
install -m 0755 ipmi-test-modules/*.sh %{buildroot}/usr/local/libexec/ipmi-test-harness/

# Install configuration example
install -d %{buildroot}/etc/ipmi-test-harness
install -m 0644 ipmi-test.conf.example %{buildroot}/etc/ipmi-test-harness/

# Install documentation
install -d %{buildroot}/usr/share/doc/%{name}
install -m 0644 README.md %{buildroot}/usr/share/doc/%{name}/
install -m 0644 IPMI-TEST-HARNESS-*.md %{buildroot}/usr/share/doc/%{name}/ 2>/dev/null || :

# Install example script if it exists
[[ -f ipmi-test-example.sh ]] && install -m 0755 ipmi-test-example.sh %{buildroot}/usr/local/libexec/ipmi-test-harness/ || :

%files
%defattr(-,root,root,-)
/usr/local/bin/ipmi-test-harness
/usr/local/libexec/ipmi-test-harness/
%config(noreplace) /etc/ipmi-test-harness/ipmi-test.conf.example
%doc /usr/share/doc/%{name}/

%postun
# Remove all installed files, directories, and other files during package removal
if [ $1 -eq 0 ]; then
	# Package removal (not upgrade) - remove all installed files and directories
	rm -f /usr/local/bin/ipmi-test-harness
	rm -rf /usr/local/libexec/ipmi-test-harness
	rm -rf /etc/ipmi-test-harness
	rm -rf /usr/share/doc/%{name}
fi

%changelog
* %(date "+%a %b %d %Y") Your Name <your.email@example.com> - 1.0-9
- Sensor tests now log [NA] clearly when a sensor is not present

* %(date "+%a %b %d %Y") Your Name <your.email@example.com> - 1.0-8
- Sensor threshold tests now report [NA] when sensors are not present

* %(date "+%a %b %d %Y") Your Name <your.email@example.com> - 1.0-7
- Improved sensor threshold reporting; now logs FAIL when sensors are missing

* %(date "+%a %b %d %Y") Your Name <your.email@example.com> - 1.0-6
- Fixed SEL post-clear verification to avoid bash arithmetic errors

* %(date "+%a %b %d %Y") Your Name <your.email@example.com> - 1.0-5
- Fixed auth module to handle local mode properly
- Skip network-only tests when running in local mode
- Fixed user_info to use proper user ID

* %(date "+%a %b %d %Y") Your Name <your.email@example.com> - 1.0-4
- Fixed SEL entry count syntax error with regex validation (watermarked version)

* %(date "+%a %b %d %Y") Your Name <your.email@example.com> - 1.0-3
- Fixed SEL entry count syntax error (properly this time)

* %(date "+%a %b %d %Y") Your Name <your.email@example.com> - 1.0-2
- Fixed SEL entry count syntax error
- Added safety flag (-D) to prevent accidental power operations
- Added local mode (-L) for testing local BMC
- Added spinner for command progress indication

* %(date "+%a %b %d %Y") Your Name <your.email@example.com> - 1.0-1
- Initial RPM package release

