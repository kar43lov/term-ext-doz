# term-ext-doz

Аддон к [term-ext](https://github.com/kar43lov/term-ext) — zsh-функции для управления docker-контейнерами проекта **"Дознание"** (doznanie.web).

## Установка

Требует установленный [term-ext](https://github.com/kar43lov/term-ext).

```bash
curl -fsSL https://raw.githubusercontent.com/kar43lov/term-ext-doz/main/install-doz.sh | bash
```

Повторный запуск безопасен (идемпотентный).

## Команды

### Выбор ветки

```bash
dozbranch    # Интерактивный выбор: test / main / feature/dzn-{номер}
```

### Main

```bash
dozrun                  # Интерактивно (dev)
dozrun test 32068       # Напрямую: ветка + pipeline ID
dozrun-prod             # Интерактивно (prod)
dozrun-prod main 32068  # Напрямую
```

### Kafka consumer

```bash
dozrun-kafka                  # Интерактивно (dev)
dozrun-kafka test 32068       # Напрямую
dozrun-kafka-prod             # Интерактивно (prod)
dozrun-kafka-prod main 32068  # Напрямую
```

### ГОСТ-подпись

```bash
dozrun-gost                  # Интерактивно (dev) — спросит пароль и имя ключа
dozrun-gost test 32068       # Напрямую (всё равно спросит пароль)
dozrun-gost-prod             # Интерактивно (prod) — + лицензия
dozrun-gost-prod main 32068  # Напрямую
```

## Контейнеры

| Команда | Контейнер | Порт | Среда |
|---|---|---|---|
| `dozrun` | `doznanie_YYMMDD` | `1MMDD` | dev |
| `dozrun-prod` | `doznanie_YYMMDD` | `1MMDD` | prod |
| `dozrun-kafka` | `doznanie__consumer_YYMMDD` | `4MMDD` | dev |
| `dozrun-kafka-prod` | `doznanie__consumer_YYMMDD` | `6MMDD` | prod |
| `dozrun-gost` | `doznanie__gost-signer_YYMMDD` | `1MMDD` | dev |
| `dozrun-gost-prod` | `doznanie__gost-signer_YYMMDD` | `2MMDD` | prod |

`YYMMDD` и `MMDD` — текущая дата. Если контейнер с таким именем уже существует — скрипт предложит удалить.

## Управление контейнерами

Базовые docker-команды предоставляются [term-ext](https://github.com/kar43lov/term-ext):

```bash
dselect  # Выбор контейнера через fzf
dr       # Restart
ds       # Stop
dst      # Start
drm      # Remove
dlogs    # Логи (follow)
dps      # Список контейнеров
```

## Реестр образов

```
gitlab.dev.iac.mchs.ru:5050/cgu/doznanie.web/
```
