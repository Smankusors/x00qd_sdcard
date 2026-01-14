FROM debian:trixie-20251229

WORKDIR /root
ENV PATH=/root/bin:$PATH

RUN apt update \
  && apt install -y \
    brotli \
    curl \
    device-tree-compiler \
    git \
    e2fsprogs \
    f2fs-tools \
    jq \
    mkbootimg \
    parted \
    python3 \
    pv \
    udev \
    unzip \
    \
#   Android_boot_image_editor dependencies
    android-sdk-libsparse-utils \
    erofs-utils \
    g++ \
    gcc \
    lz4 \
    openjdk-21-jdk \
    p7zip-full \
    python-is-python3 \
    xz-utils \
    zlib1g-dev \
    \
#   u-boot cross compile dependencies
    bison \
    flex \
    gcc-aarch64-linux-gnu \
    libgnutls28-dev \
    libssl-dev \
    make \
    xxd \
    \
    \
# For converting Android sparse image to non sparse format
  && curl -L https://github.com/xpirt/sdat2img/archive/b432c988a412c06ff24d196132e354712fc18929.tar.gz | tar -xzvf - \
  && mv sdat2img-b432c988a412c06ff24d196132e354712fc18929 sdat2img \
  \
# For extracting Android boot.img (and bootstrap it for faster execution)
  && curl -L https://github.com/cfig/Android_boot_image_editor/archive/c82f1d98c003b82c8783faa424c85becf5e61bab.tar.gz | tar -xzvf - \
  && mv Android_boot_image_editor-c82f1d98c003b82c8783faa424c85becf5e61bab Android_boot_image_editor \
  && ./Android_boot_image_editor/gradlew --no-build-cache -p Android_boot_image_editor assemble \
  && ./Android_boot_image_editor/gradlew --stop \
  \
# For extracting appended DTB on the kernel
  && curl -L https://github.com/PabloCastellano/extract-dtb/archive/ab824ac0993efc03a3a9201c5c03f54fda4bcfd0.tar.gz | tar -xzvf - \
  && mv extract-dtb-ab824ac0993efc03a3a9201c5c03f54fda4bcfd0 extract-dtb \
  \
# Cleanup to save space
  && apt clean
