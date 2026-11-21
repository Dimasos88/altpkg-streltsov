Name: lab07-trace
Version: 1.0
Release: alt1
Summary: File transfer and signal tracing exercises
License: MIT
Group: Development/Other
Source0: %name-%version.tar.gz
BuildRequires: gcc
BuildRequires: make
BuildRequires: strace

%description
Two programs used to test system call diagnostics and signal handling.

%prep
%setup

%build
%make_build CFLAGS="%optflags"

%install
install -Dpm755 lab07-move %buildroot%_bindir/lab07-move
install -Dpm755 lab07-signals %buildroot%_bindir/lab07-signals

%check
%make_build test

%files
%_bindir/lab07-move
%_bindir/lab07-signals

%changelog
* Sat Nov 21 2026 Dmitry Streltsov <dimasos88@github.com> 1.0-alt1
- Initial package with strace-based build checks.
