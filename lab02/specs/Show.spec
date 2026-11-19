Name: Show
Version: 1.0
Release: alt1
Summary: Text file pager using ncurses
License: GPL-2.0-or-later
Group: File tools

Source0: %name-%version.tar.gz

BuildRequires: libncurses-devel

%description
Simple text file page viewer using ncurses library by Streltsov Dmitriy (KT-22-04).

%prep
%setup

%build
%make_build

%install
mkdir -p %buildroot%_bindir
install -p -m 755 %name %buildroot%_bindir/%name

%files
%_bindir/%name
