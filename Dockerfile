FROM ubuntu:noble-20250404

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
  && curl -L https://github.com/xpirt/sdat2img/archive/b432c988a412c06ff24d196132e354712fc18929.tar.gz | tar -xzvf - \
  && mv sdat2img-b432c988a412c06ff24d196132e354712fc18929 sdat2img \
  && curl -L https://github.com/cfig/Android_boot_image_editor/archive/4af828484c378f4e8a82b2686ed446f4b7a9829d.tar.gz | tar -xzvf - \
  && mv Android_boot_image_editor-4af828484c378f4e8a82b2686ed446f4b7a9829d Android_boot_image_editor \
  && ./Android_boot_image_editor/gradlew --no-build-cache -p Android_boot_image_editor assemble \
  && ./Android_boot_image_editor/gradlew --stop \
  && curl -L https://github.com/PabloCastellano/extract-dtb/archive/ab824ac0993efc03a3a9201c5c03f54fda4bcfd0.tar.gz | tar -xzvf - \
  && mv extract-dtb-ab824ac0993efc03a3a9201c5c03f54fda4bcfd0 extract-dtb \
  && apt clean
