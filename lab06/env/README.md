# Сборочное окружение

ALT Workstation 11.1, p11, x86_64. Проверки требуют Bash, Zsh, GNU grep, sed, coreutils, GCC, GNU make, GNU time и локаль ru_RU.utf8. Сборка пакета выполняется GEAR и hasher.

`bash check/check-lab06.sh` собирает программы, выполняет сравнения и пишет журналы в `logs/`. Задайте `LAB06_LOGS` для отдельного каталога. Для проверки установленного пакета задайте `LAB06_HASHER`, `LAB06_RPM` и `LAB06_DEBUG_RPM`. При отсутствии этих параметров только группа RPM получает SKIP.

Команда сборки из рабочего дерева GEAR: `gear-hsh --lazy-cleanup --no-sisyphus-check=gpg,packager,changelog <каталог-hasher>`. Отключение проверок сопровождающего и подписи применяется для учебной сборки с GitHub-адресом.
