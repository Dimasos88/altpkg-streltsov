Name: lab06-regex
Version: 1.0
Release: alt1
Summary: POSIX regular expression matching and substitution
License: MIT
Group: Development/Other
Source0: %name-%version.tar.gz
BuildRequires: gcc
BuildRequires: make

%description
Command-line tools for POSIX extended regular expressions.

%prep
%setup

%build
%make_build CFLAGS="%optflags"

%install
install -Dpm755 lab06-match %buildroot%_bindir/lab06-match
install -Dpm755 lab06-replace %buildroot%_bindir/lab06-replace

%files
%_bindir/lab06-match
%_bindir/lab06-replace

%changelog
* Sat Nov 21 2026 Dmitry Streltsov <dimasos88@github.com> 1.0-alt1
- Initial package.
