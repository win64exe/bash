#!/bin/bash
set -e

sudo apt update
sudo apt install -y \
  build-essential meson ninja-build python3-mako git bison flex \
  libdrm-dev libexpat1-dev libx11-dev libxext-dev libxdamage-dev \
  libxfixes-dev libxcb1-dev libxcb-glx0-dev libxcb-dri3-dev \
  libxcb-present-dev libxshmfence-dev libxxf86vm-dev \
  libwayland-dev wayland-protocols libgbm-dev libegl1-mesa-dev \
  libgles2-mesa-dev libzstd-dev libxml2-dev libvulkan-dev \
  llvm-dev libclc-dev python3-pip python3-packaging

sudo pip3 install --upgrade meson jinja2

git clone https://gitlab.freedesktop.org/mesa/mesa.git
cd mesa
git checkout main

mkdir builddir
meson setup builddir \
  -Dprefix=/opt/mesa \
  -Dbuildtype=release \
  -Dplatforms=x11,wayland \
  -Degl=enabled \
  -Dgles1=true -Dgles2=true \
  -Dshared-glapi=true \
  -Dopengl=true \
  -Dgallium-drivers=panfrost \
  -Dvulkan-drivers=panfrost

ninja -C builddir
sudo ninja -C builddir install

cat <<EOF >> ~/.bashrc
export LD_LIBRARY_PATH=/opt/mesa/lib:\$LD_LIBRARY_PATH
export LIBGL_DRIVERS_PATH=/opt/mesa/lib/dri
export VK_ICD_FILENAMES=/opt/mesa/share/vulkan/icd.d/panfrost_icd.aarch64.json
export VK_LAYER_PATH=/opt/mesa/share/vulkan/explicit_layer.d
EOF

echo "Установка Mesa 25.1 завершена. Выполните 'source ~/.bashrc' и проверьте:"
echo "  vulkaninfo | grep panfrost"
