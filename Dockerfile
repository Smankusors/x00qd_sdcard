FROM debian:trixie-20261005

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
    file \
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
  && curl --fail --location https://github.com/xpirt/sdat2img/archive/b432c988a412c06ff24d196132e354712fc18929.tar.gz | tar -xzvf - \
  && mv sdat2img-b432c988a412c06ff24d196132e354712fc18929 sdat2img \
  \
# For extracting Android boot.img (and bootstrap it for faster execution)
  && curl --fail --location https://github.com/cfig/Android_boot_image_editor/archive/c82f1d98c003b82c8783faa424c85becf5e61bab.tar.gz | tar -xzvf - \
  && mv Android_boot_image_editor-c82f1d98c003b82c8783faa424c85becf5e61bab Android_boot_image_editor \
  && ./Android_boot_image_editor/gradlew --no-build-cache -p Android_boot_image_editor assemble \
  && ./Android_boot_image_editor/gradlew --stop \
  \
# For extracting appended DTB on the kernel
  && curl --fail --location https://github.com/PabloCastellano/extract-dtb/archive/ab824ac0993efc03a3a9201c5c03f54fda4bcfd0.tar.gz | tar -xzvf - \
  && mv extract-dtb-ab824ac0993efc03a3a9201c5c03f54fda4bcfd0 extract-dtb \
  \
# For patching monolithic SELinux policies with sepolicy-inject.
  && curl --fail --location https://raw.githubusercontent.com/wiki/SELinuxProject/selinux/files/releases/20161014/libsepol-2.6.tar.gz --output /tmp/libsepol-2.6.tar.gz \
  && echo "d856d6506054f52abeaa3543ea2f2344595a3dc05d0d873ed7f724f7a16b1874  /tmp/libsepol-2.6.tar.gz" | sha256sum --check - \
  && tar -xzf /tmp/libsepol-2.6.tar.gz \
  && make -C libsepol-2.6 CFLAGS="-Wall -Wshadow -O2 -pipe -std=gnu11 -fcommon" \
  && curl --fail --location https://github.com/phhusson/sepolicy-inject/archive/76a26a4ac7a033d5ebed6f2a3c92c036b3c0002c.tar.gz | tar -xzvf - \
  && mv sepolicy-inject-76a26a4ac7a033d5ebed6f2a3c92c036b3c0002c sepolicy-inject \
  && make -C sepolicy-inject LIBDIR=../libsepol-2.6/src CFLAGS="-g -Wall -Wshadow -O2 -pipe -std=gnu11 -I/root/libsepol-2.6/include" \
  && install -m 0755 sepolicy-inject/sepolicy-inject /usr/local/bin/sepolicy-inject \
  && rm -f /tmp/libsepol-2.6.tar.gz \
  \
# Cleanup to save space
  && apt clean
