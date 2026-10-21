#!/bin/sh
# Smoke-тест образа: ./tests/smoke.sh <image>
set -eu

IMAGE="$1"
run() { docker run --rm "$IMAGE" "$@"; }

echo "--- extensions"
modules=$(run php -m)
for ext in bcmath exif gd intl pcntl pdo_mysql pdo_pgsql redis zip 'Zend OPcache'; do
    printf '%s\n' "$modules" | grep -qix "$ext" || { echo "missing: $ext"; exit 1; }
done
if printf '%s\n' "$modules" | grep -qix xdebug; then echo "xdebug must not be loaded"; exit 1; fi

echo "--- gd formats"
run php -r 'foreach (["FreeType Support", "JPEG Support", "PNG Support", "WebP Support"] as $k) { if (empty(gd_info()[$k])) { fwrite(STDERR, "gd: no $k\n"); exit(1); } }'

echo "--- opcache: off by default, project ini can turn it on"
run php -r 'exit(ini_get("opcache.enable_cli") ? 1 : 0);'
docker run --rm "$IMAGE" sh -c 'printf "opcache.enable=1\\nopcache.enable_cli=1\\n" > "$PHP_INI_DIR/conf.d/zz-test.ini" && php -r "exit(opcache_get_status() === false ? 1 : 0);"'

echo "--- php.ini"
run php -r 'exit(ini_get("expose_php") || ini_get("display_errors") ? 1 : 0);'

echo "--- tzdata"
test "$(docker run --rm -e TZ=Europe/Moscow "$IMAGE" date +%Z)" = MSK

echo "--- php-fpm config"
run php-fpm -t

echo "--- composer"
run composer --version

echo "OK"
