#!/bin/bash
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
LAB_DIR="$REPO_DIR/lab02"

PASSED=0
FAILED=0
SKIPPED=0

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

echo "=== Запуск проверки лабораторной работы № 2 ==="

# Задание 1
run_check "Задание 1: Структура каталогов lab02" \
    test -d "$LAB_DIR/sources" -a -d "$LAB_DIR/specs" -a -d "$LAB_DIR/env" -a -d "$LAB_DIR/logs" -a -d "$LAB_DIR/check"

run_check "Задание 1: Параметры терминала stty-before.txt" \
    grep -q "intr = ^C" "$LAB_DIR/logs/stty-before.txt"

run_check "Задание 1: Последовательности очистки экрана clear-seq.log" \
    test -s "$LAB_DIR/logs/clear-seq.log"

run_check "Задание 1: Различия описаний terminfo vt100 vs xterm-256color" \
    test -s "$LAB_DIR/logs/terminfo-diff.log"

run_check "Задание 1: Анализ двойной печати и подчеркивания man-overstrike.log" \
    grep -q "08" "$LAB_DIR/logs/man-overstrike.log"

# Задание 2
run_check "Задание 2: Исходный текст программы Show.c" \
    test -s "$LAB_DIR/sources/Show.c"

run_check "Задание 2: Контрольный файл для просмотра sample.txt" \
    test -s "$LAB_DIR/check/sample.txt"

run_check "Задание 2: Ошибка компоновки без библиотеки ncurses gcc-no-lib.log" \
    grep -qi "initscr" "$LAB_DIR/logs/gcc-no-lib.log"

run_check "Задание 2: Восстановление режима терминала stty-diff.log пуст" \
    test ! -s "$LAB_DIR/logs/stty-diff.log"

# Задание 3
run_check "Задание 3: Наличие Makefile с символами табуляции" \
    grep -Pq "^\t" "$LAB_DIR/sources/Makefile"

run_check "Задание 3: Диагностика пропущенного разделителя make-tab-error.log" \
    grep -qi "separator" "$LAB_DIR/logs/make-tab-error.log"

run_check "Задание 3: Диагностика отсутствующего реквизита make-prereq-error.log" \
    grep -qi "No rule to make target" "$LAB_DIR/logs/make-prereq-error.log"

run_check "Задание 3: Журнал отслеживания зависимостей make-deps.log" \
    grep -qi "Nothing to be done" "$LAB_DIR/logs/make-deps.log"

# Задание 4
run_check "Задание 4: Сопоставление ncurses6 и ncurses-devel" \
    grep -q "libncurses.so" "$LAB_DIR/logs/ncurses-pkg-compare.log"

run_check "Задание 4: Конфигурация сборочного окружения hasher-config" \
    grep -q "packager=" "$LAB_DIR/env/hasher-config"

run_check "Задание 4: Сведения о сопровождающем в logs/packager-after.log" \
    grep -q "Streltsov Dmitriy" "$LAB_DIR/logs/packager-after.log"

# Задание 5
run_check "Задание 5: Архив исходных текстов Show-1.0.tar.gz" \
    test -s "$LAB_DIR/sources/Show-1.0.tar.gz"

run_check "Задание 5: Содержимое архива имеет единственный верхний каталог Show-1.0/" \
    tar -tzf "$LAB_DIR/sources/Show-1.0.tar.gz" | grep -q "^Show-1.0/"

run_check "Задание 5: Spec-файл Show.spec содержит BuildRequires: libncurses-devel" \
    grep -qi "BuildRequires:.*libncurses-devel" "$LAB_DIR/specs/Show.spec"

run_check "Задание 5: Журнал сборки пакета Show-build.log" \
    grep -qi "Wrote:.*Show-1.0-alt1" "$LAB_DIR/logs/Show-build.log"

# Задание 6
run_check "Задание 6: Зависимость от разделяемой библиотеки в show-requires.log" \
    grep -q "libncurses.so.6" "$LAB_DIR/logs/show-requires.log"

run_check "Задание 6: Журнал сбоя установки без библиотеки install-fail-no-deps.log" \
    grep -q "libncurses.so.6" "$LAB_DIR/logs/install-fail-no-deps.log"

run_check "Задание 6: Успешная установка с основной библиотекой без devel" \
    grep -q "devel package is NOT installed: PASS" "$LAB_DIR/logs/install-success-runtime-only.log"

# Задание 7
run_check "Задание 7: Журнал автоматической пересборки hsh rebuild.log" \
    test -s "$LAB_DIR/logs/rebuild.log"

run_check "Задание 7: Структура репозитория repo-structure.log" \
    grep -q "RPMS.hasher" "$LAB_DIR/logs/repo-structure.log"

run_check "Задание 7: Отладочный подпакет и нулевое пересечение файлов" \
    grep -q "Files intersection count: 0" "$LAB_DIR/logs/debuginfo-compare.log"

# Задание 8
run_check "Задание 8: Отчет lab02/README.md" \
    test -s "$LAB_DIR/README.md"

echo "=========================================="
echo "Итог проверки: ПРОЙДЕНО: $PASSED, ОШИБОК: $FAILED, ПРОПУЩЕНО: $SKIPPED"
echo "=========================================="

if [ "$FAILED" -eq 0 ]; then
    exit 0
else
    exit 1
fi

