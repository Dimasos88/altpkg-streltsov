Name: streltsov-hello
Version: 1.0
Release: alt1
Summary: Greeting script for lab01
License: GPL-2.0-or-later
Group: Development/Other

Source0: %name.sh

%description
Greeting script for lab01 by Streltsov Dmitriy Sergeevich (KT-22-04).

%install
mkdir -p %buildroot%_bindir
install -p -m 755 %SOURCE0 %buildroot%_bindir/%name

%files
%_bindir/%name
