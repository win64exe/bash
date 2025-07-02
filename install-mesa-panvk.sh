#!/bin/bash

set -e

# === 1. Установка зависимостей ===
echo "[+] Установка зависимостей..."
sudo apt update
sudo apt install -y \
  build-essential meson ninja-build python3-mako git bison flex \
  libdrm-dev libexpat1-dev libx11-dev libxext-dev libxdamage-dev \
  libxfixes-dev libxcb-glx0-dev libxcb-dri2-0-dev libxcb-dri3-dev \
  libxcb-present-dev libxshmfence-dev libxxf86vm-dev \
  libwayland-dev wayland-protocols libgbm-dev libegl1-mesa-dev \
  libgles2-mesa-dev libzstd-dev libxml2-dev libvulkan-dev \
  python3-pip

# === 2. Установка дополнительных Python-пакетов для Meson ===
echo "[+] Установка python3-meson и jinja2..."
sudo pip3 install meson jinja2

# === 3. Скачиваем Mesa ===
echo "[+] Клонирование Mesa (будет использована последняя стабильная версия)..."
git clone https://gitlab.freedesktop.org/mesa/mesa.git
cd mesa
git checkout mesa-24.1.1  # Можно обновить при необходимости

# === 4. Настройка сборки ===
echo "[+] Настройка Meson-сборки..."

mkdir -p builddir
meson setup builddir \
  -Dprefix=/opt/mesa \
  -Dbuildtype=release \
  -Dplatforms=x11,wayland \
  -Dgallium-drivers=panfrost \
  -Dvulkan-drivers=panfrost \
  -Dglx=dri \
  -Dshared-glapi=true \
  -Dgles1=true \
  -Dgles2=true

# === 5. Сборка и установка ===
echo "[+] Сборка Mesa (может занять 30+ минут)..."
ninja -C builddir
echo "[+] Установка Mesa в /opt/mesa..."
sudo ninja -C builddir install

# === 6. Настройка переменных среды ===
echo "[+] Добавление переменных среды в ~/.bashrc..."
echo 'export LD_LIBRARY_PATH=/opt/mesa/lib:$LD_LIBRARY_PATH' >> ~/.bashrc
echo 'export LIBGL_DRIVERS_PATH=/opt/mesa/lib/dri' >> ~/.bashrc
echo 'export VK_ICD_FILENAMES=/opt/mesa/share/vulkan/icd.d/panfrost_icd.aarch64.json' >> ~/.bashrc
echo 'export VK_LAYER_PATH=/opt/mesa/share/vulkan/explicit_layer.d' >> ~/.bashrc

# === 7. Готово ===
echo "[✓] Установка завершена. Перезагрузите систему или выполните:"
echo "    source ~/.bashrc"
echo "Затем проверьте Vulkan командой: vulkaninfo | less"
