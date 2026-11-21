# Сборочное окружение

Стенд ALT Workstation 11.1 p11, x86_64. Основные зависимости: GCC, Bash, GNU make, binutils, coreutils, strace и RPM. Для сравнения уровней нужны ltrace и архивы пакета glibc-devel-static. Для сравнения подключения к процессу нужен GDB. Проверка списка трассировщиков требует доступа к tracefs.

Проверка: `bash check/check-lab07.sh`. Параметр `LAB07_STATIC_LDFLAGS` позволяет указать каталоги статических архивов. `LAB07_RPM` и `LAB07_GEAR_LOG` включают проверку пакета. `LAB07_LOGS` заменяет каталог журналов.

Для сборки используется GEAR из опубликованного репозитория и hasher с зарегистрированным пользователем. Учебная сборка использует `gear-hsh --lazy-cleanup --no-sisyphus-check=gpg,packager,changelog <каталог-hasher>`.
