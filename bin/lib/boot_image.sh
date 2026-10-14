repack_boot_image() {
  echo "Repacking boot.img..."
  cp work/boot.img Android_boot_image_editor/boot.img
  ./Android_boot_image_editor/gradlew -p Android_boot_image_editor pack
}
