#!/bin/bash

source "variables.sh"

projects_path="$(cd .. && pwd)/sites"

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
variables_file="$absolute_path/dnssl_variables.sh"

# Получаем DOCKER_IP_ADDRESS из сети Docker bridge
DOCKER_IP_ADDRESS=$(docker network inspect bridge | grep Gateway | awk '{print $2}' | tr -d ',"')

# Запрашиваем название сайта
read -p "Введите название сайта: " site_name

# Запрашиваем список IP-адресов или доменных имен для server_name
echo "Введите домен вашего сайта (если несколько, разделите пробелами):"
read -a domains

# Проход по всем элементам массива
server_names=""
for domain in "${domains[@]}"; do
    server_names+=" $domain"
done

# Запрашиваем номер порта Docker контейнера (должен быть только числом)
port=""
read -p "Введите номер порта Docker контейнера (число): " port_input
if [[ "$port_input" =~ ^[0-9]+$ ]]; then
    port="$port_input"
else
    echo "Ошибка: Введите корректное число для номера порта."
fi
 # Обновляем раздел volumes для каждого сайта
sed -i "/nginx:/,/volumes:/ s|\(.*volumes:.*\)|\1\n      - $(normalize_path "$absolute_path/static"):/var/www/web/$site_name/static\n      - $(normalize_path "$absolute_path/media"):/var/www/web/$site_name/media|" docker-compose.yml

# Создаем файл переменных
cat > "$variables_file" <<EOL
#!/bin/bash

# Переменные проекта
site_name="$site_name"
port="$port"
domains=()
EOL
    # Используем цикл для записи каждого домена в файл
    for domain in "${domains[@]}"; do
        echo "domains+=(\"$domain\")" >> "$variables_file"
    done

    # Создаем конфигурационный файл
    cat > "sites-enabled/${site_name}_nginx.conf" <<EOL
server {
    listen 80;
#    listen 443 ssl;
    server_name$server_names;
    # Этот сервер блок выполняется при этих доменных именах

    # ssl_certificate и ssl_certificate_key - необходимые сертификаты
#    ssl_certificate /etc/letsencrypt/live/$site_name/fullchain.pem; # Закомментить
#    ssl_certificate_key /etc/letsencrypt/live/$site_name/privkey.pem; # Закомментить
#    include /etc/letsencrypt/options-ssl-nginx.conf; # Закомментить
#    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # Закомментить

    location /.well-known/acme-challenge/ { root /var/www/certbot; }

    location /static/ {
        alias $(normalize_path "/var/www/web/$site_name/static")/;
    }

    location /media/ {
        alias $(normalize_path "/var/www/web/$site_name/media")/;
    }

    location / {
        proxy_pass http://$DOCKER_IP_ADDRESS:$port;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Host \$host;
        proxy_redirect off;
    }
}
EOL
  # Копируем созданный конфигурационный файл в папку sites-enabled
print_success "Конфигурационный файл для сайта $site_name создан в текущей папке."
print_success "Новые записи успешно добавлены в раздел volumes сервиса nginx в docker-compose.yml"
## Перезапускаем контейнер nginx
docker-compose restart