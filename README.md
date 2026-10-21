# PHP-FPM — базовый образ

Базовый Docker-образ на базе **php:8.4-fpm-alpine / php:8.5-fpm-alpine** для проектов на Laravel. Содержит нужные расширения PHP и Composer.

## Содержимое образа

### Расширения PHP

| Расширение | Назначение             |
| ---------- | ---------------------- |
| bcmath     | Точная арифметика      |
| exif       | Метаданные изображений |
| gd         | Обработка изображений (freetype, jpeg, png, webp) |
| intl       | Интернационализация (с полными данными ICU) |
| pcntl      | Многопроцессность      |
| pdo_mysql  | MySQL/MariaDB          |
| pdo_pgsql  | PostgreSQL             |
| redis      | Redis ([phpredis](https://github.com/phpredis/phpredis), версия в `PHPREDIS_VERSION`) |
| zip        | Архивы ZIP             |
| opcache    | Кэш опкодов (подключён, но выключен, см. ниже) |

Все расширения собираются через `docker-php-ext-install`; phpredis для этого распаковывается в дерево исходников PHP. Остальное (mbstring, pdo_sqlite, sodium, curl, openssl и т.д.) уже есть в официальном образе `php`.

Xdebug в образе нет: если нужен для отладки, ставьте его в образе проекта.

### Прочее

- **Composer** — версия зафиксирована в стадии `FROM composer:…`, обновляет Dependabot (`/usr/local/bin/composer`).
- **git** — для зависимостей Composer из VCS.
- **shadow** — `usermod`/`groupmod`/`useradd` для пользователя приложения.
- **fcgi** — `cgi-fcgi` для `php-fpm-healthcheck`.
- **tzdata** — переменная `TZ` (например, `TZ=Europe/Moscow`) работает для системного времени и логов. На Laravel не влияет: у него таймзона из `config/app.php`.
- Build-зависимости (`-dev`-пакеты, компиляторы) удаляются после сборки расширений, остаются только рантайм-библиотеки.

### Настройки PHP

- Основа — `php.ini-production` из официального образа: `display_errors=Off`, `log_errors=On`, `post_max_size=8M`, `upload_max_filesize=2M`, `memory_limit=128M` и т.д.
- `00-gocpa.ini` поверх него: `expose_php=Off` и выключенный opcache.
- Ошибки PHP из воркеров FPM попадают в stderr контейнера (`catch_workers_output` из официального образа). Флагов `php_admin_*` образ не задаёт, так что любую настройку можно переопределить ini проекта, включая `log_errors=Off`.

### PHP-FPM

- Слушает порт `9000`, пул `www` работает от `www-data`.
- Параметры пула задаются переменными окружения (файл `zz-gocpa.conf`), пересобирать образ не нужно:

| Переменная                  | По умолчанию | Директива              |
| --------------------------- | ------------ | ---------------------- |
| `PHP_FPM_PM`                | `dynamic`    | `pm`                   |
| `PHP_FPM_MAX_CHILDREN`      | `20`         | `pm.max_children`      |
| `PHP_FPM_START_SERVERS`     | `4`          | `pm.start_servers`     |
| `PHP_FPM_MIN_SPARE_SERVERS` | `2`          | `pm.min_spare_servers` |
| `PHP_FPM_MAX_SPARE_SERVERS` | `6`          | `pm.max_spare_servers` |
| `PHP_FPM_MAX_REQUESTS`      | `500`        | `pm.max_requests`      |

  `zz-gocpa.conf` читается последним, поэтому эти директивы в своих conf-файлах пула проекту задавать бесполезно — только через переменные.
- `ping.path = /ping` и `pm.status_path = /status` — для healthcheck и мониторинга. Через nginx они не видны, пока nginx сам не передаёт эти пути в FPM.

### Healthcheck

`php-fpm-healthcheck` стучится в `/ping` пула через `cgi-fcgi`. В сам образ `HEALTHCHECK` не прописан: из того же образа запускаются очереди и планировщик, где FPM нет. Добавьте его в compose сервису с FPM:

```yaml
healthcheck:
  test: ["CMD", "php-fpm-healthcheck"]
  interval: 10s
  timeout: 3s
  retries: 3
```

Если пул слушает не `127.0.0.1:9000`, задайте адрес в `PHP_FPM_HEALTHCHECK_ADDR` (можно путь к unix-сокету).

## Настройка в проекте

Файлы из `/usr/local/etc/php/conf.d/` читаются по алфавиту, при совпадении директив побеждает последний файл. Ini проекта называйте так, чтобы он шёл после `00-gocpa.ini` (например, `laravel.ini` или `zz-app.ini`).

### OPcache

Модуль подключён на обеих версиях PHP, но выключен в `00-gocpa.ini`. В production включите его в ini проекта (нужны обе директивы: `opcache.enable` — общий выключатель, без него `opcache.enable_cli` не действует):

```ini
opcache.enable=1
opcache.enable_cli=1
```

Проверить, что opcache работает:

```bash
php -r 'var_dump(opcache_get_status() !== false);'
```

> Для php-fpm смотрите `opcache_get_status()` из веб-запроса: `opcache.enable_cli` влияет только на CLI.

## Использование

Образ публикуется в Docker Hub как **`gocpa/php`**, для amd64 и arm64.

| Тег                          | Описание                                                       |
| ---------------------------- | -------------------------------------------------------------- |
| `8.4-fpm`, `8.5-fpm`         | Плавающий тег: последняя сборка этой версии PHP                |
| `8.4-fpm-<n>`, `8.5-fpm-<n>` | Номер сборки (GitHub Actions `run_number`), напр. `8.4-fpm-42`. Не меняется |

```dockerfile
FROM gocpa/php:8.4-fpm-42   # фиксированная сборка
FROM gocpa/php:8.4-fpm      # всегда свежая
```

### Когда собирается

- **Релиз на GitHub** и **каждый понедельник в 03:00 UTC** — сборка, проверки и публикация обоих тегов. Еженедельная пересборка подтягивает патчи Alpine и PHP из официального образа без ручного релиза.
- **Вручную** — `Run workflow` во вкладке Actions, тоже с публикацией.
- **Pull request** — только сборка и проверки, без публикации.

Перед публикацией каждый образ проходит `tests/smoke.sh` и сканирование Trivy: сборка падает при уязвимостях HIGH/CRITICAL, для которых уже есть исправление. Образы публикуются с provenance и SBOM.

### Локальная сборка

По умолчанию собирается PHP 8.4, версия задаётся аргументом `PHP_VERSION`.

```bash
# Под текущую платформу, в локальный Docker:
docker build --build-arg PHP_VERSION=8.4 -t gocpa/php:8.4-fpm-dev .
docker build --build-arg PHP_VERSION=8.5 -t gocpa/php:8.5-fpm-dev .

# Под amd64 и arm64 сразу (нужен buildx; результат пушится в registry):
docker buildx build --build-arg PHP_VERSION=8.4 --platform linux/amd64,linux/arm64/v8 -t gocpa/php:8.4-fpm-dev --push .
docker buildx build --build-arg PHP_VERSION=8.5 --platform linux/amd64,linux/arm64/v8 -t gocpa/php:8.5-fpm-dev --push .
```

Проверка собранного образа (то же запускается в CI):

```bash
./tests/smoke.sh gocpa/php:8.4-fpm-dev
```

## Лицензия

[Unlicense](LICENSE) — код в общественном достоянии.
