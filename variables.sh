#!/bin/bash

# Функция для очистки пути от лишних слэшей
normalize_path() {
    echo "$1" | sed -E 's#/{2,}#/#g'
}
# Цвета
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'  # No Color

# Вывод зеленого сообщения
print_success() {
    echo -e "${GREEN}$1${NC}"
}

# Вывод красного сообщения
print_error() {
    echo -e "${RED}$1${NC}"
}