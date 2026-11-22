%def_enable keypad
Name: lab08-autotools
Version: 1.0
Release: alt1
Summary: Terminal key scanner configured with Autotools
License: MIT
Group: Development/Other
Source0: %name-%version.tar.gz
BuildRequires: gcc
BuildRequires: make
BuildRequires: autoconf
BuildRequires: automake
BuildRequires: libncursesw-devel

%description
A terminal key scanner with a configurable frame margin and keypad decoding.

%prep
%setup

%build
%autoreconf
%configure %{subst_enable keypad}
%make_build

%install
%makeinstall_std

%check
make check

%files
%_bindir/lab08-keys

%changelog
* Sun Nov 22 2026 Dmitry Streltsov <dimasos88@github.com> 1.0-alt1
- Initial build.
