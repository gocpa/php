# PHP-FPM — базовый образ

Базовый Docker-образ на базе **php:8.4-fpm-alpine / php:8.5-fpm-alpine** для проектов на Laravel. Содержит нужные расширения PHP, Composer.

## Содержимое образа

### Расширения PHP

| Расширение | Назначение             |
| ---------- | ---------------------- |
| bcmath     | Точная арифметика      |
| exif       | Метаданные изображений |
| gd         | Обработка изображений  |
| intl       | Интернационализация    |
| opcache    | Кэш опкодов (выключен) |
| pcntl      | Многопроцессность      |
| pdo_mysql  | MySQL/MariaDB          |
| pdo_pgsql  | PostgreSQL             |
| zip        | Архивы ZIP             |
| redis      | Redis                  |
| xdebug     | Отладка (выключен)     |

**Xdebug:** по умолчанию выключен. В dev-образе необходимо включить вручную через добавление конфигурации в файл `/usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini`

**OPcache:** по умолчанию выключен. В production необходимо включить вручную через добавление конфигурации в файл `/usr/local/etc/php/conf.d/opcache.ini`
```ini
opcache.enable=1
opcache.enable_cli=1
```

**Composer** 2.8.6

## Использование

Образ публикуется в Docker Hub как **`gocpa/php`** с тегами по версии PHP:

| Тег                                   | Описание                                           |
| ------------------------------------- | -------------------------------------------------- |
| `8.4-fpm-<n>`, `8.5-fpm-<n>`          | Номер сборки (GitHub Actions `run_number`, напр. `8.4-fpm-42`) |

Локальная сборка (по умолчанию PHP 8.4):

```bash
# Сборка всех версий (текущая платформа):
docker build --build-arg PHP_VERSION=8.4 -t gocpa/php:8.4-fpm-dev .
docker build --build-arg PHP_VERSION=8.5 -t gocpa/php:8.5-fpm-dev .

# Сборка всех версий (все платформы):
docker buildx build --build-arg PHP_VERSION=8.4 --platform linux/amd64,linux/arm64/v8 -t gocpa/php:8.4-fpm-dev --push .
docker buildx build --build-arg PHP_VERSION=8.5 --platform linux/amd64,linux/arm64/v8 -t gocpa/php:8.5-fpm-dev --push .
```

## Уменьшение размера образа

- В образе все build-зависимости (`-dev`, компиляторы) удаляются после сборки расширений, остаются только рантайм-библиотеки.

## Лицензия

[Unlicense](LICENSE) — код в общественном достоянии.
