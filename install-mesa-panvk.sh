#!/bin/bash

set -e

echo "[+] Установка зависимостей..."
sudo apt update
sudo apt install -y \
  build-essential meson ninja-build python3-mako git bison flex \
  libdrm-dev libexpat1-dev libx11-dev libxext-dev libxdamage-dev \
  libxfixes-dev libxcb-glx0-dev libxcb-dri2-0-dev libxcb-dri3-dev \
  libxcb-present-dev libxshmfence-dev libxxf86vm-dev \
  libwayland-dev wayland-protocols libgbm-dev libegl1-mesa-dev \
  libgles2-mesa-dev libzstd-dev libxml2-dev libvulkan-dev \
  python3-pip python3-packaging

echo "[+] Установка Meson >= 1.2 из pip (вместо устаревшей версии в Debian 12)..."
sudo pip3 install --upgrade meson jinja2

echo "[+] Клонирование Mesa (ветка main)..."
git clone https://gitlab.freedesktop.org/mesa/mesa.git
cd mesa
# Ветка main содержит 25.1 (будущая релизная версия)
git checkout main

echo "[+] Настройка сборки Mesa 25.1 с поддержкой PanVK..."
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
  -Dgles2=true \
  -Dopengl=true \
  -Dvulkan=true

echo "[+] Сборка Mesa 25.1 (может занять длительное время)..."
ninja -C builddir

echo "[+] Установка в /opt/mesa..."
sudo ninja -C builddir install

echo "[+] Настройка переменных окружения в ~/.bashrc..."
echo 'export LD_LIBRARY_PATH=/opt/mesa/lib:$LD_LIBRARY_PATH' >> ~/.bashrc
echo 'export LIBGL_DRIVERS_PATH=/opt/mesa/lib/dri' >> ~/.bashrc
echo 'export VK_ICD_FILENAMES=/opt/mesa/share/vulkan/icd.d/panfrost_icd.aarch64.json' >> ~/.bashrc
echo 'export VK_LAYER_PATH=/opt/mesa/share/vulkan/explicit_layer.d' >> ~/.bashrc

echo "[✓] Установка Mesa 25.1 завершена. Перезагрузите систему или выполните:"
echo "    source ~/.bashrc"
echo "Затем проверьте работу Vulkan:"
echo "    vulkaninfo | grep panfrost"
