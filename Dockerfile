# syntax=docker/dockerfile:1
# Базовый образ php-fpm для продуктов GoCPA

ARG PHP_VERSION=8.4
FROM php:${PHP_VERSION}-fpm-alpine

LABEL org.opencontainers.image.source="https://github.com/gocpa/php" \
      org.opencontainers.image.description="PHP ${PHP_VERSION} FPM Alpine base image for GoCPA Laravel projects" \
      org.opencontainers.image.version="${PHP_VERSION}"

RUN --mount=type=cache,target=/var/cache/apk \
    --mount=type=bind,from=ghcr.io/php/pie:bin,source=/pie,target=/usr/bin/pie \
    apk add -U --no-cache --virtual temp \
    # dev deps
    autoconf file g++ freetype-dev icu-dev \
    jpeg-dev libjpeg-turbo-dev libpng-dev libzip-dev linux-headers make \
    oniguruma-dev postgresql-dev re2c zlib-dev \
    # prod deps
    && apk add --no-cache \
    freetype git icu icu-data-full libjpeg-turbo libpng libpq libzip shadow zlib \
    # php extensions
    && docker-php-source extract \
    && { php -m | grep gd || docker-php-ext-configure gd --with-freetype --with-jpeg --enable-gd; } \
    && docker-php-ext-install bcmath exif gd intl pcntl pdo_mysql pdo_pgsql zip \
    && (if ! php -m | grep -q opcache; then docker-php-ext-install opcache || true; fi) \
    && pie install phpredis/phpredis \
    && pie install xdebug/xdebug \
    && rm -f /usr/local/etc/php/conf.d/90-xdebug.ini \
    && rm -f /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \
    && rm -f /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini \
    && docker-php-source delete \
    #
    && echo "php_admin_flag[log_errors] = on" >> /usr/local/etc/php-fpm.d/www.conf \
    && echo "php_admin_value[error_log] = /proc/self/fd/2" >> /usr/local/etc/php-fpm.d/www.conf \
    && printf '%s\n' 'opcache.enable=0' 'opcache.enable_cli=0' > /usr/local/etc/php/conf.d/opcache.ini \
    # composer
    && curl -sSL https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
    && chmod +x /usr/local/bin/composer \
    #
    # cleanup
    && apk del temp \
    && rm -rf /var/cache/apk/* /tmp/* /var/tmp/* /usr/share/doc/* /usr/share/man/* /root/.composer/cache /root/.cache

EXPOSE 9000

CMD ["php-fpm", "-y", "/usr/local/etc/php-fpm.conf", "-R"]
