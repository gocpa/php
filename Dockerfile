# syntax=docker/dockerfile:1
# Базовый образ php-fpm для продуктов GoCPA

ARG PHP_VERSION=8.4

# отдельной стадией, чтобы версию обновлял Dependabot
FROM composer:2.10.3 AS composer

FROM php:${PHP_VERSION}-fpm-alpine

ARG PHP_VERSION
ARG PHPREDIS_VERSION=6.3.0

LABEL org.opencontainers.image.source="https://github.com/gocpa/php" \
      org.opencontainers.image.description="PHP ${PHP_VERSION} FPM Alpine base image for GoCPA Laravel projects" \
      org.opencontainers.image.version="${PHP_VERSION}"

COPY --from=composer /usr/bin/composer /usr/local/bin/composer

RUN apk add --no-cache --virtual .build-deps \
    $PHPIZE_DEPS linux-headers \
    freetype-dev icu-dev libjpeg-turbo-dev libpng-dev libwebp-dev libzip-dev postgresql-dev \
    && apk add --no-cache \
    freetype git icu-data-full icu-libs libjpeg-turbo libpng libpq libwebp libzip shadow tzdata \
    # php extensions; phpredis кладём в дерево исходников, чтобы собрать его вместе со всеми
    && docker-php-source extract \
    && mkdir /usr/src/php/ext/redis \
    && curl -fsSL "https://github.com/phpredis/phpredis/archive/refs/tags/${PHPREDIS_VERSION}.tar.gz" \
    | tar -xz --strip-components=1 -C /usr/src/php/ext/redis \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install -j"$(nproc)" bcmath exif gd intl pcntl pdo_mysql pdo_pgsql redis zip \
    # 8.4: opcache собран отдельным модулем и не подключён; 8.5: встроен в PHP
    && { php -m | grep -qi '^zend opcache$' || docker-php-ext-enable opcache; } \
    && docker-php-source delete \
    #
    && cp "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini" \
    # 00- — читается раньше ini проекта, иначе перебивает его настройки (например, opcache.enable=1)
    && printf '%s\n' 'expose_php=Off' 'opcache.enable=0' 'opcache.enable_cli=0' > "$PHP_INI_DIR/conf.d/00-gocpa.ini" \
    #
    # cleanup
    && apk del .build-deps \
    && rm -rf /tmp/* /var/tmp/* /usr/share/doc/* /usr/share/man/*

EXPOSE 9000

CMD ["php-fpm"]
