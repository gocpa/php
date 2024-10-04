# syntax=docker/dockerfile:1
# Базовый образ php8.3-fpm для партнерских программ GoCPA

FROM php:8.3.12-fpm-alpine3.19

RUN \
    # deps
    apk add -U --no-cache --virtual temp \
    # dev deps
    autoconf file g++ icu-data-full icu-dev libzip-dev \
    make oniguruma-dev postgresql-dev re2c zlib-dev \
    # prod deps
    && apk add --no-cache \
    freetype-dev git icu jpeg-dev libjpeg-turbo-dev \
    libpng-dev libpq libzip linux-headers shadow zlib \
    # php extensions
    && docker-php-source extract \
    && pecl channel-update pecl.php.net \
    && { php -m | grep gd || docker-php-ext-configure gd --with-freetype --with-jpeg --enable-gd; } \
    && docker-php-ext-install bcmath gd intl pcntl opcache pdo_mysql pdo_pgsql zip \
    && { pecl clear-cache || true; } \
    && pecl install redis \
    && docker-php-source delete \
    #
    # composer
    && curl -sSL https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
    #
    # cleanup
    && apk del temp \
    && rm -rf /var/cache/apk/* /tmp/* /var/tmp/* /usr/share/doc/* /usr/share/man/*

EXPOSE 9000

RUN echo "php_admin_flag[log_errors] = on" >> /usr/local/etc/php-fpm.d/www.conf

CMD ["php-fpm", "-y", "/usr/local/etc/php-fpm.conf", "-R"]
