# Base this image on arago-base-tisdk-image
include recipes-core/images/arago-base-tisdk-image.bb

LICENSE = "Apache-2.0"

DEPENDS = "parted-native mtools-native dosfstools-native e2fsprogs-native"

# Include modules in rootfs
IMAGE_INSTALL += " \
	socat \
	ti-u-boot-scr \
"

IMAGE_FEATURES += " \
	ssh-server-dropbear "

#
# fw update needs these to be created at boot and there is really
# no natural place for these.
#
create_mnt_dirs() {
   mkdir -p ${IMAGE_ROOTFS}/mnt/flags
   mkdir -p ${IMAGE_ROOTFS}/mnt/config
   mkdir -p ${IMAGE_ROOTFS}/mnt/cache
   mkdir -p ${IMAGE_ROOTFS}/mnt/root
}

ROOTFS_POSTPROCESS_COMMAND += "create_mnt_dirs;"

#Required for libglib read-only filesystem support
DEPENDS += " qemuwrapper-cross "

IMAGE_FEATURES += " read-only-rootfs "
