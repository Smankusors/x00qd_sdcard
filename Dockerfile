FROM ubuntu

WORKDIR /root

RUN apt update \
  && apt install -y \
    android-sdk-libsparse-utils \
    brotli \
    curl \
    device-tree-compiler \
    erofs-utils \
    gcc \
    git \
    g++ \
    f2fs-tools \
    lz4 \
    openjdk-17-jdk \
    parted \
    p7zip-full \
    python-is-python3 \
    python3 \
    pv \
    udev \
    unzip \
    xz-utils \
    zlib1g-dev \
  && curl -L https://github.com/xpirt/sdat2img/archive/refs/heads/master.tar.gz | tar -xzvf - \
  && curl -L https://github.com/cfig/Android_boot_image_editor/archive/refs/heads/master.tar.gz | tar -xzvf - \
  && curl -L https://github.com/PabloCastellano/extract-dtb/archive/refs/heads/master.tar.gz | tar -xzvf - \
  && ./Android_boot_image_editor-master/gradlew --no-build-cache -p Android_boot_image_editor-master assemble \
  && ./Android_boot_image_editor-master/gradlew --stop \
  && apt clean
