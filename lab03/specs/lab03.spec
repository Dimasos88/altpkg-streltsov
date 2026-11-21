Name: lab03
Version: 1.0
Release: alt1
Summary: Numbered output of command-line arguments
License: MIT
Group: Development/Other
Source: %name-%version.tar.gz

BuildRequires: gcc
BuildRequires: make

%description
A multi-file C project packaged with two command-line programs and a shared
library. The two programs use identical output routines.

%prep
%setup

%build
%make_build CFLAGS="%optflags" lab03-static lab03-shared

%install
install -Dpm755 lab03-static %buildroot%_bindir/lab03-static
install -Dpm755 lab03-shared %buildroot%_bindir/lab03-shared
install -Dpm755 liblab03.so.1 %buildroot%_libdir/liblab03.so.1

%files
%_bindir/lab03-static
%_bindir/lab03-shared
%_libdir/liblab03.so.1
