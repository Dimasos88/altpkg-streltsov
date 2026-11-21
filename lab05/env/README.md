# Сборочное окружение

ALT Workstation 11.1, p11, x86_64. Использованы GCC, GNU make, binutils, GDB и gdbserver. Сценарий `bash check/check-lab05.sh` собирает программы, запускает проверки и пишет журналы в `logs/`. Для отдельного каталога задайте `LAB05_LOGS`.

`LAB05_DEBUG_ROOT` указывает на каталог с распакованным RPM отладочной информации glibc и заполненным кэшем debuginfod. Для проверки GDB в hasher задайте `LAB05_HASHER` и поместите отладочную сборку в `chroot/.in/progression-debug`. Проверка подразумевает, что /proc разрешён в системных настройках. `prepare-hasher.sh` принимает рабочий каталог, номер пары пользователей, режим rooter и дополнительные пакеты после `--`.

Для GDB требуются описание /proc с правом записи в fstab hasher-priv, разрешение точки в allowed_mountpoints, перезапуск hasher-privd после правки и параметр --mountpoints=/proc при запуске. Указание точки при сборке пакета – BuildRequires: /proc. [Практикум «Альт Платформа», глава 6](https://docs.altlinux.org/ru-RU/platform/11.0/html/alt-platform-practic/debugging.html).
