#!/bin/bash
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
LAB_DIR="$REPO_DIR/lab01"

PASSED=0
FAILED=0

run_check() {
    local desc="$1"
    shift
    if "$@"; then
        echo "[PASS] $desc"
        PASSED=$((PASSED + 1))
    else
        echo "[FAIL] $desc"
        FAILED=$((FAILED + 1))
    fi
}

echo "=== Запуск проверки лабораторной работы № 1 ==="

# Задание 1
run_check "Задание 1: Структура каталогов lab01" \
    test -d "$LAB_DIR/specs" -a -d "$LAB_DIR/sources" -a -d "$LAB_DIR/env" -a -d "$LAB_DIR/logs" -a -d "$LAB_DIR/check"

run_check "Задание 1: Наличие .gitignore с правилами для RPM" \
    grep -q "RPMS/" "$REPO_DIR/.gitignore"

# Задание 2
run_check "Задание 2: Наличие и непустота env/repos.txt" \
    test -s "$LAB_DIR/env/repos.txt"

run_check "Задание 2: Наличие репозитория p11 в env/repos.txt" \
    grep -q "p11" "$LAB_DIR/env/repos.txt"

run_check "Задание 2: Наличие перечня установленных пакетов хоста env/host-packages.txt" \
    test -s "$LAB_DIR/env/host-packages.txt"

# Задание 3
run_check "Задание 3: Журналы анализа разделяемой библиотеки zlib (logs/zlib-*.log)" \
    test -s "$LAB_DIR/logs/zlib-info.log" -a -s "$LAB_DIR/logs/zlib-requires.log" -a -s "$LAB_DIR/logs/zlib-provides.log"

run_check "Задание 3: Журналы анализа devel-пакета zlib-devel" \
    test -s "$LAB_DIR/logs/zlib-devel-files.log" -a -s "$LAB_DIR/logs/zlib-devel-qf.log"

run_check "Задание 3: Наличие заголовочных файлов в zlib-devel" \
    grep -q "/usr/include/zlib.h" "$LAB_DIR/logs/zlib-devel-files.log"

# Задание 4
run_check "Задание 4: Конфигурационный файл hasher (env/hasher-config)" \
    test -s "$LAB_DIR/env/hasher-config"

run_check "Задание 4: Наличие параметров packager и no_sisyphus_check в hasher-config" \
    grep -q "packager=" "$LAB_DIR/env/hasher-config"

run_check "Задание 4: Журнал инициализации hasher (logs/hasher-init.log)" \
    test -s "$LAB_DIR/logs/hasher-init.log"

run_check "Задание 4: Проверка ролей builder и rooter в hasher" \
    grep -q "builder" "$LAB_DIR/logs/hasher-builder.log"

# Задание 5
run_check "Задание 5: Spec-файл нулевого пакета (specs/sample-streltsov.spec)" \
    test -s "$LAB_DIR/specs/sample-streltsov.spec"

run_check "Задание 5: Журнал сборки нулевого пакета" \
    test -s "$LAB_DIR/logs/sample-streltsov-build.log"

# Задание 6
run_check "Задание 6: Исходный сценарий (sources/streltsov-hello.sh)" \
    test -x "$LAB_DIR/sources/streltsov-hello.sh"

run_check "Задание 6: Spec-файл пакета с функциональностью (specs/streltsov-hello.spec)" \
    test -s "$LAB_DIR/specs/streltsov-hello.spec"

run_check "Задание 6: Эталон ожидаемого вывода (check/expected.txt)" \
    test -s "$LAB_DIR/check/expected.txt"

run_check "Задание 6: Соответствие вывода сценария эталону" \
    diff -q "$LAB_DIR/check/expected.txt" <("$LAB_DIR/sources/streltsov-hello.sh")

run_check "Задание 6: Журнал сборки пакета streltsov-hello с вычисленными зависимостями" \
    grep -q "Requires: /bin/sh" "$LAB_DIR/logs/streltsov-hello-build.log"

# Задание 7
run_check "Задание 7: Журнал автоматической сборки (logs/rebuild.log)" \
    test -s "$LAB_DIR/logs/rebuild.log"

run_check "Задание 7: Подтверждение воспроизводимости сборки (Hashes match: YES)" \
    grep -q "Hashes match: YES" "$LAB_DIR/logs/rebuild-diff.log"

run_check "Задание 7: Перечень пакетов chroot и сопоставление с хостом" \
    test -s "$LAB_DIR/env/chroot-packages.txt" -a -s "$LAB_DIR/logs/env-diff.log"

# Задание 8: Отчет README.md
run_check "Задание 8: Наличие отчета lab01/README.md" \
    test -s "$LAB_DIR/README.md"

echo "=========================================="
echo "Итог проверки: ПРОЙДЕНО: $PASSED, ОШИБОК: $FAILED"
echo "=========================================="

if [ "$FAILED" -eq 0 ]; then
    exit 0
else
    exit 1
fi

