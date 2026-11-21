Name: lab04-todo
Version: 1.0
Release: alt1
Summary: Task list with command-line and dialog interfaces
License: MIT
Group: Office
Source0: %name-%version.sh

%description
Maintain a per-user task list from a terminal dialog or the command line.

%install
install -Dpm755 %SOURCE0 %buildroot%_bindir/%name

%files
%_bindir/%name

%changelog
* Sat Nov 21 2026 Dmitry Streltsov <dimasos88@github.com> 1.0-alt1
- Initial package.
