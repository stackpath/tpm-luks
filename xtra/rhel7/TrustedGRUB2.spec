Name:		TrustedGRUB2
Version:	1.2.1
Release:	1%{?dist}
Summary:	Trusted boot loader based on grub2

Group:		System Environment/Base
License:	GPLv3+
#URL:
Source0:	TrustedGRUB2-%{version}.tar.gz
BuildRoot:	%(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)

BuildRequires:	gc gcc make bison gettext flex python autoconf automake autogen guile
#Requires:	cryptsetup dracut gawk coreutils grubby tpm-tools trousers
# for now we require an upstream tpm-tools and trousers, so don't add them
# here so we can avoid --nodeps
Requires:	dracut

%description
TrustedGRUB2 is a boot loader based on grub2 that offers TCG (TPM) support to guaranty
the integrity of the boot process (trusted boot). All boot components are measured and
written into PCR during the boot process.

%prep
%setup -q

%build
./autogen.sh
%configure --prefix=/usr --libdir=%{_libdir}
make %{?_smp_mflags} CFLAGS= CXXFLAGS= FFLAGS= FCFLAGS= LDFLAGS= CCASFLAGS=

%install
[ "${RPM_BUILD_ROOT}" != "/" ] && [ -d ${RPM_BUILD_ROOT} ] && rm -rf ${RPM_BUILD_ROOT};
make install DESTDIR=$RPM_BUILD_ROOT
touch $RPM_BUILD_DIR/$RPM_PACKAGE_NAME-$RPM_PACKAGE_VERSION/debugfiles.list

%clean
[ "${RPM_BUILD_ROOT}" != "/" ] && [ -d ${RPM_BUILD_ROOT} ] && rm -rf ${RPM_BUILD_ROOT};

%files
%defattr(-,root,root,-)
%doc README TODO
%{_bindir}/*
%{_sbindir}/*
%dir %{_datadir}/grub
%{_datadir}/grub/*
%dir %{_libdir}/grub
%dir %{_libdir}/grub/i386-pc
%{_libdir}/grub/i386-pc/*
%dir /etc/grub.d
%config /etc/grub.d/*
%dir /etc/bash_completion.d
/etc/bash_completion.d/grub

%exclude /usr/lib/debug
%exclude /usr/share/info/dir

%changelog
