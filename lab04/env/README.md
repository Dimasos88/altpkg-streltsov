# Стенд ЛР № 4

ALT Workstation 11.1, p11, x86_64. Для основных проверок нужны Bash, coreutils, findutils, grep, gawk, util-linux, rpm, Git и Python 3. Для меню нужен dialog. Для дополнительных операций с потоками – moreutils. Для сборки RPM и реконструкции по тегам нужны rpm-build, hasher с зарегистрированным пользователем и GEAR.

Команда проверки из корня lab04:

```sh
bash check/check-lab04.sh
```

Переменная `LAB04_RPM_DIR` указывает каталог с `direct.rpm`, `gear-old.rpm` и `gear-new.rpm`. `LAB04_GEAR_URL` задаёт URL GEAR-репозитория для сетевой проверки тегов. Без этих параметров соответствующие группы отмечаются SKIP. Переменная `LAB04_LOGS` позволяет писать журналы в отдельный каталог.

Для прямой сборки поместите `sources/lab04-todo` в SOURCES под именем `lab04-todo-1.0.sh`, создайте SRPM через `rpmbuild -bs` и передайте его в `hsh`. Для GEAR-сборки клонируйте репозиторий пакета и выполните `gear-hsh --lazy-cleanup --no-sisyphus-check=gpg,packager,changelog <каталог-hasher>` из рабочего дерева нужного тега. Параметр отключает проверки подписи и учётных данных сопровождающего для учебной сборки с GitHub-адресом.
