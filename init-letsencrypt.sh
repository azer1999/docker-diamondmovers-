#!/bin/bash

# Импорт глобальных данных
source "variables.sh"
# Путь к генерированному файлу с переменными
source "$absolute_path/dnssl_variables.sh"

projects_path="$(cd .. && pwd)/sites"

# Включаем переменные из файла в корне проекта
while true; do
    # Показываем существующие проекты
    echo "Существующие проекты в $projects_path:"
    ls -d "$projects_path"/*/ | sed "s#$projects_path/##"

    # Запрашиваем выбор проекта
    read -p "Выберите проект: " selected_project

    # Проверяем, что выбранный проект существует
    if [ -d "$projects_path/$selected_project" ]; then
        break
    else
        echo "Ошибка: Проект '$selected_project' не существует."
    fi
done
# Абсолютный путь к выбранному проекту
absolute_path="$projects_path/$selected_project"



# Используем переменные
echo "Site Name: $site_name"
echo "Server Name: $domains"

# Запрашиваем адрес электронной почты
echo "Введите ваш активный адрес электронной почты:"
read email

# Установим режим тестирования (по желанию)
read -p "Тестируете настройки? (1 для да, 0 для нет, по умолчанию 0): " staging
staging=${staging:-0}

# Остальной код скрипта
data_path="./certbot"
rsa_key_size=4096

# root required
if [ "$EUID" -ne 0 ]; then echo "Пожалуйста, запустите $0 с правами администратора." && exit; fi

clear

# Menu for existing folder
if [ -d "$data_path/conf/live/$site_name" ]; then
  print_success "### Существующие данные найдены для некоторых доменов..."
  echo
  PS3='Ваш выбор: '
  select opt in "Пропустить зарегистрированные домены" "Удалить зарегистрированные домены и продолжить" "Удалить зарегистрированные домены и выйти" "Выйти"; do
    echo; echo;
    case $REPLY in
        1) echo " Установленные сертификаты будут пропущены" echo; echo; break;;
        2) echo " Старые сертификаты удалены"; echo; echo; rm -rf "$data_path"; break;;
        3) echo " Старые сертификаты удалены"; echo; rm -rf "$data_path"; echo " Выход..."; echo; echo; sleep 2; clear; exit;;
        4) echo " Выход..."; echo; echo; sleep 0.5; clear; exit;;
        *) echo "недопустимый вариант $REPLY";;
    esac
  done
fi

mkdir -p "$data_path"

if [ ! -e "$data_path/conf/options-ssl-nginx.conf" ] && [ ! -e "$data_path/conf/ssl-dhparams.pem" ]; then
  print_success "### Загрузка рекомендуемых параметров TLS ..."
  mkdir -p "$data_path/conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf > "$data_path/conf/options-ssl-nginx.conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem > "$data_path/conf/ssl-dhparams.pem"
fi

# Dummy certificate
mkdir -p "$data_path/conf/live/$site_name"

if [ ! -e "$data_path/conf/live/$site_name/cert.pem" ]; then
  print_success "### Создание фиктивного сертификата для домена $site_name..."
  path="/etc/letsencrypt/live/$site_name"
  docker compose run --rm --entrypoint "openssl req -x509 -nodes -newkey rsa:1024 \
  -days 1 -keyout '$path/privkey.pem' -out '$path/fullchain.pem' -subj '/CN=localhost'" certbot
fi


print_success "### Запуск nginx ..."
# Перезапускать, если контейнер nginx уже запущен
docker compose up -d nginx && docker compose restart nginx

# Выбор соответствующего аргумента для адреса электронной почты
case "$email" in
  "") email_arg="--register-unsafely-without-email" ;;
  *) email_arg="--email $email" ;;
esac

# Включение режима тестирования, если необходимо
if [ "$staging" != "0" ]; then staging_arg="--staging"; fi

if [ -e "$data_path/conf/live/$site_name/cert.pem" ]; then
  print_success "Пропуск домена $site_name"; else

  print_success "### Удаление фиктивного сертификата для домена $site_name ..."
  rm -rf "$data_path/conf/live/$site_name"

  print_success "### Запрос сертификата Let's Encrypt для домена $site_name ..."

  # Объединение доменов в аргументы -d
  domain_args=""
  for domain in "${domains[@]}"; do
    domain_args="$domain_args -d $domain"
  done

  mkdir -p "$data_path/www"
  docker compose run --rm --entrypoint "certbot certonly --webroot -w /var/www/certbot --cert-name $site_name $domain_args \
  $staging_arg $email_arg --rsa-key-size $rsa_key_size --agree-tos --force-renewal --non-interactive" certbot
fi