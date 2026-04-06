#!/usr/bin/env bash
#
# term-ext-doz: аддон к term-ext — функции для управления
# docker-контейнерами проекта "Дознание" (doznanie.web).
#
# Требует: term-ext (https://github.com/kar43lov/term-ext)
#
# Использование:
#   curl -fsSL https://raw.githubusercontent.com/kar43lov/term-ext-doz/main/install-doz.sh | bash
#
set -euo pipefail

# ── Цвета ─────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }

# ── Проверка: term-ext установлен? ───────────────────────────
TERMEXT_FILE="$HOME/.zshrc.term-ext"
if [ ! -f "$TERMEXT_FILE" ]; then
    error "term-ext не установлен (~/.zshrc.term-ext не найден)."
    echo "  Сначала установи: curl -fsSL https://raw.githubusercontent.com/kar43lov/term-ext/main/install-terminal-user.sh | bash"
    exit 1
fi
info "term-ext обнаружен."

# ── Проверка: fzf доступен? ──────────────────────────────────
if ! command -v fzf >/dev/null 2>&1; then
    error "fzf не установлен. Он нужен для интерактивного выбора."
    exit 1
fi

# ── Записываем doz-функции ───────────────────────────────────
DOZ_FILE="$HOME/.zshrc.term-ext-doz"
info "Записываю функции в $DOZ_FILE..."

cat > "$DOZ_FILE" << 'DOZ_EOF'
# ══════════════════════════════════════════════════════════════
# term-ext-doz: функции для проекта "Дознание"
# Не редактируй вручную — обновляется скриптом install-doz.sh
# ══════════════════════════════════════════════════════════════

# ── Реестр образов ───────────────────────────────────────────
_DOZ_REGISTRY="gitlab.dev.iac.mchs.ru:5050/cgu/doznanie.web"

# Docker через sudo (registry авторизован под root)
_DOZ_DOCKER="sudo docker"

# ── Выбор ветки ──────────────────────────────────────────────
dozbranch() {
    local branch
    branch=$(printf 'test\nmain\nfeature/dzn-...' | fzf --prompt="Ветка> " --height=6 --no-info)
    [ -z "$branch" ] && return 1

    if [ "$branch" = "feature/dzn-..." ]; then
        local num
        printf "Номер задачи (например 220 → feature/dzn-220): " >/dev/tty
        read -r num </dev/tty
        [ -z "$num" ] && { echo "Номер не указан." >/dev/tty; return 1; }
        branch="feature/dzn-$num"
    fi

    echo "$branch"
}

# ── Вспомогательные функции ──────────────────────────────────

# Проверка существующего контейнера
_doz_check_container() {
    local name="$1"
    if eval "$_DOZ_DOCKER ps -a --format '{{.Names}}'" | grep -qx "$name"; then
        printf "\033[1;33m[!]\033[0m Контейнер '%s' уже существует. Удалить? [y/N] " "$name" >/dev/tty
        read -r answer </dev/tty
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            eval "$_DOZ_DOCKER rm -f $name"
        else
            echo "Отменено." >/dev/tty
            return 1
        fi
    fi
}

# Запрос branch и pipeline (интерактивно или из аргументов)
_doz_get_params() {
    local branch pipeline
    if [ $# -ge 2 ]; then
        branch="$1"
        pipeline="$2"
    else
        branch=$(dozbranch) || return 1
        echo -e "\033[0;32m[✓]\033[0m Ветка: $branch" >/dev/tty
        printf "Pipeline ID (номер сборки в GitLab): " >/dev/tty
        read -r pipeline </dev/tty
        [ -z "$pipeline" ] && { echo "Pipeline не указан." >/dev/tty; return 1; }
    fi
    echo "$branch" "$pipeline"
}

# ── Основные команды ─────────────────────────────────────────

# dozrun — Main (dev)
dozrun() {
    local params branch pipeline
    params=$(_doz_get_params "$@") || return 1
    read -r branch pipeline <<< "$params"

    local date_suffix=$(date +%y%m%d)
    local mmdd=$(date +%m%d)
    local container="doznanie_${date_suffix}"
    local port="1${mmdd}"
    local image="${_DOZ_REGISTRY}/srv-main----${branch}:${pipeline}"

    _doz_check_container "$container" || return 1

    echo -e "\033[0;32m[✓]\033[0m Запуск: $container (порт $port)"
    echo "  Image: $image"

    eval "$_DOZ_DOCKER run -itd \
        --name $container \
        --restart unless-stopped \
        -e TZ=Europe/Moscow \
        -p ${port}:8080 \
        -v /etc/hosts:/etc/hosts \
        -v /srv/services/inq.dev.iac.mchs.ru/appsettings.json:/app/main/appsettings.json \
        -v /data/nfs/VS:/data/nfs/VS \
        $image"
}

# dozrun-prod — Main (prod)
dozrun-prod() {
    local params branch pipeline
    params=$(_doz_get_params "$@") || return 1
    read -r branch pipeline <<< "$params"

    local date_suffix=$(date +%y%m%d)
    local mmdd=$(date +%m%d)
    local container="doznanie_${date_suffix}"
    local port="1${mmdd}"
    local image="${_DOZ_REGISTRY}/srv-main----${branch}:${pipeline}"

    _doz_check_container "$container" || return 1

    echo -e "\033[0;32m[✓]\033[0m Запуск (prod): $container (порт $port)"
    echo "  Image: $image"

    eval "$_DOZ_DOCKER run -itd \
        --name $container \
        --restart unless-stopped \
        -e TZ=Europe/Moscow \
        -p ${port}:8080 \
        -v /etc/hosts:/etc/hosts \
        -v /home/stepanovim/inq.cgu.mchs.ru/configs/appsettings.json:/app/main/appsettings.json \
        -v /data/nfs/VS:/data/nfs/VS \
        -v /home/stepanovim/inq.cgu.mchs.ru/configs/nlog.config:/app/main/nlog.config \
        -v /home/stepanovim/inq.cgu.mchs.ru/logs:/app/main/logs \
        $image"
}

# dozrun-kafka — Kafka consumer (dev)
dozrun-kafka() {
    local params branch pipeline
    params=$(_doz_get_params "$@") || return 1
    read -r branch pipeline <<< "$params"

    local date_suffix=$(date +%y%m%d)
    local mmdd=$(date +%m%d)
    local container="doznanie__consumer_${date_suffix}"
    local port="4${mmdd}"
    local image="${_DOZ_REGISTRY}/srv-kafka----${branch}:${pipeline}"

    _doz_check_container "$container" || return 1

    echo -e "\033[0;32m[✓]\033[0m Запуск Kafka (dev): $container (порт $port)"
    echo "  Image: $image"

    eval "$_DOZ_DOCKER run -itd \
        --name $container \
        --restart unless-stopped \
        -e TZ=Europe/Moscow \
        -e ASPNETCORE_URLS='http://0.0.0.0:8080' \
        -p ${port}:8080 \
        -v /etc/hosts:/etc/hosts \
        -v /srv/services/inq.dev.iac.mchs.ru/kafka.appsettings.json:/app/kafka/appsettings.json \
        $image"
}

# dozrun-kafka-prod — Kafka consumer (prod)
dozrun-kafka-prod() {
    local params branch pipeline
    params=$(_doz_get_params "$@") || return 1
    read -r branch pipeline <<< "$params"

    local date_suffix=$(date +%y%m%d)
    local mmdd=$(date +%m%d)
    local container="doznanie__consumer_${date_suffix}"
    local port="6${mmdd}"
    local image="${_DOZ_REGISTRY}/srv-kafka----${branch}:${pipeline}"

    _doz_check_container "$container" || return 1

    echo -e "\033[0;32m[✓]\033[0m Запуск Kafka (prod): $container (порт $port)"
    echo "  Image: $image"

    eval "$_DOZ_DOCKER run -itd \
        --name $container \
        --restart unless-stopped \
        -e TZ=Europe/Moscow \
        -e ASPNETCORE_URLS='http://0.0.0.0:8080' \
        -p ${port}:8080 \
        -v /etc/hosts:/etc/hosts \
        -v /home/stepanovim/inq.cgu.mchs.ru/configs/kafka.appsettings.json:/app/kafka/appsettings.json \
        -v /home/stepanovim/inq.cgu.mchs.ru/configs/kafka.nlog.config:/app/kafka/nlog.config \
        -v /home/stepanovim/inq.cgu.mchs.ru/logs/kafka:/app/kafka/logs \
        $image"
}

# dozrun-gost — ГОСТ-подпись (dev)
dozrun-gost() {
    local params branch pipeline
    params=$(_doz_get_params "$@") || return 1
    read -r branch pipeline <<< "$params"

    local date_suffix=$(date +%y%m%d)
    local mmdd=$(date +%m%d)
    local container="doznanie__gost-signer_${date_suffix}"
    local port="1${mmdd}"
    local image="${_DOZ_REGISTRY}/srv-gost-signer----${branch}:${pipeline}"

    _doz_check_container "$container" || return 1

    local cont_password key_name
    printf "CONTAINER_PASSWORD [1234567890]> " >/dev/tty
    read -r cont_password </dev/tty
    cont_password=${cont_password:-1234567890}

    printf "KEY_CONTAINER_NAME [81ab0001.000]> " >/dev/tty
    read -r key_name </dev/tty
    key_name=${key_name:-81ab0001.000}

    echo -e "\033[0;32m[✓]\033[0m Запуск ГОСТ (dev): $container (порт $port)"
    echo "  Image: $image"

    eval "$_DOZ_DOCKER run -itd \
        --name $container \
        --restart unless-stopped \
        -e TZ=Europe/Moscow \
        -e ASPNETCORE_URLS='http://0.0.0.0:8080' \
        -e CONTAINER_PASSWORD='$cont_password' \
        -e KEY_CONTAINER_NAME='$key_name' \
        -p ${port}:8080 \
        -v /srv/services/inq.dev.iac.mchs.ru/gost-signer-keys:/keys:ro \
        -v /etc/hosts:/etc/hosts:ro \
        -v /srv/services/inq.dev.iac.mchs.ru/gost-signer.appsettings.json:/app/gost-signer/appsettings.json:ro \
        $image"
}

# dozrun-gost-prod — ГОСТ-подпись (prod)
dozrun-gost-prod() {
    local params branch pipeline
    params=$(_doz_get_params "$@") || return 1
    read -r branch pipeline <<< "$params"

    local date_suffix=$(date +%y%m%d)
    local mmdd=$(date +%m%d)
    local container="doznanie__gost-signer_${date_suffix}"
    local port="2${mmdd}"
    local image="${_DOZ_REGISTRY}/srv-gost-signer----${branch}:${pipeline}"

    _doz_check_container "$container" || return 1

    local cont_password key_name crypto_license
    printf "CONTAINER_PASSWORD [1234567890]> " >/dev/tty
    read -r cont_password </dev/tty
    cont_password=${cont_password:-1234567890}

    printf "KEY_CONTAINER_NAME [81ab0001.000]> " >/dev/tty
    read -r key_name </dev/tty
    key_name=${key_name:-81ab0001.000}

    printf "CRYPTO_LICENSE [40000-A0000-B0000-C0000-D0000]> " >/dev/tty
    read -r crypto_license </dev/tty
    crypto_license=${crypto_license:-40000-A0000-B0000-C0000-D0000}

    echo -e "\033[0;32m[✓]\033[0m Запуск ГОСТ (prod): $container (порт $port)"
    echo "  Image: $image"

    eval "$_DOZ_DOCKER run -itd \
        --name $container \
        --restart unless-stopped \
        -e TZ=Europe/Moscow \
        -e ASPNETCORE_URLS='http://0.0.0.0:8080' \
        -e CONTAINER_PASSWORD='$cont_password' \
        -e KEY_CONTAINER_NAME='$key_name' \
        -e CRYPTO_LICENSE='$crypto_license' \
        -p ${port}:8080 \
        -v /home/stepanovim/inq.cgu.mchs.ru/gost-signer-keys:/keys:ro \
        -v /etc/hosts:/etc/hosts:ro \
        -v /home/stepanovim/inq.cgu.mchs.ru/configs/gost-signer.appsettings.json:/app/gost-signer/appsettings.json:ro \
        $image"
}
DOZ_EOF

info "Функции записаны в $DOZ_FILE."

# ── Добавить source в ~/.zshrc.term-ext ──────────────────────
DOZ_SOURCE='[ -f ~/.zshrc.term-ext-doz ] && source ~/.zshrc.term-ext-doz'
MARKER="# ── История: поиск стрелками"

if grep -qF '.zshrc.term-ext-doz' "$TERMEXT_FILE"; then
    info "~/.zshrc.term-ext уже подключает term-ext-doz."
else
    # Вставляем ПЕРЕД блоком bindkey (поиск стрелками)
    if grep -qF "$MARKER" "$TERMEXT_FILE"; then
        sed -i.bak "/$MARKER/i\\
\\
# ── Дознание (term-ext-doz) ──────────────────────────────────\\
$DOZ_SOURCE" "$TERMEXT_FILE"
        rm -f "${TERMEXT_FILE}.bak"
        info "Подключение term-ext-doz добавлено в ~/.zshrc.term-ext (перед bindkey)."
    else
        # Маркер не найден — добавляем в конец
        echo "" >> "$TERMEXT_FILE"
        echo "# ── Дознание (term-ext-doz) ──────────────────────────────────" >> "$TERMEXT_FILE"
        echo "$DOZ_SOURCE" >> "$TERMEXT_FILE"
        warn "Маркер '${MARKER}' не найден. Подключение добавлено в конец ~/.zshrc.term-ext."
    fi
fi

echo ""
info "Готово! Установлены команды:"
echo "  dozbranch         — выбор ветки (fzf)"
echo "  dozrun            — Main (dev)"
echo "  dozrun-prod       — Main (prod)"
echo "  dozrun-kafka      — Kafka consumer (dev)"
echo "  dozrun-kafka-prod — Kafka consumer (prod)"
echo "  dozrun-gost       — ГОСТ-подпись (dev)"
echo "  dozrun-gost-prod  — ГОСТ-подпись (prod)"
echo ""
info "Перезапусти шелл:"
echo "  exec zsh"
