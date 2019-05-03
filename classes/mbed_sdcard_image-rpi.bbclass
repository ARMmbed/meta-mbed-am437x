inherit image_types

#
# SD card image creation /w partitioning for AM437x.
#


# This image depends on the rootfs image
IMAGE_TYPEDEP_mbed-sdimg = "ext3"

# Boot partition volume id
BOOTDD_VOLUME_ID ?= "${MACHINE}"

# Boot partition size [in KiB] (will be rounded up to IMAGE_ROOTFS_ALIGNMENT)
BOOT_SPACE ?= "40960"

# Size of other non-rootfilesystem partitions
BOOTFLAGS_SIZE="20480"
CONFIG_SIZE="40960"
CACHE_SIZE="$(expr ${ROOTFS_SIZE} + ${ROOTFS_SIZE} / 2)"

# Set alignment to 4MB [in KiB]
IMAGE_ROOTFS_ALIGNMENT = "4096"

# Use an uncompressed ext3 by default as rootfs
SDIMG_ROOTFS_TYPE ?= "ext3"
SDIMG_ROOTFS = "${IMGDEPLOYDIR}/${IMAGE_LINK_NAME}.${SDIMG_ROOTFS_TYPE}"

# SD card image name
SDIMG = "${IMGDEPLOYDIR}/${IMAGE_NAME}.rootfs.ti-sdimg"


do_image_mbed_sdimg[depends] = " \
			ti-u-boot-scr:do_deploy \
			parted-native:do_populate_sysroot \
			mtools-native:do_populate_sysroot \
			dosfstools-native:do_populate_sysroot \
			e2fsprogs-native:do_populate_sysroot \
			virtual/kernel:do_deploy \
			u-boot:do_deploy \
			"

IMAGE_CMD () {

	# Align partitions
	BOOT_SPACE_ALIGNED=$(expr ${BOOT_SPACE} + ${IMAGE_ROOTFS_ALIGNMENT} - 1)
	BOOT_SPACE_ALIGNED=$(expr ${BOOT_SPACE_ALIGNED} - ${BOOT_SPACE_ALIGNED} % ${IMAGE_ROOTFS_ALIGNMENT})
	SDIMG_SIZE=$(expr ${IMAGE_ROOTFS_ALIGNMENT} + ${BOOT_SPACE_ALIGNED} + ${ROOTFS_SIZE} + ${ROOTFS_SIZE} + ${BOOTFLAGS_SIZE} + ${CONFIG_SIZE} + ${CACHE_SIZE})

	echo "Creating filesystem with Boot partition ${BOOT_SPACE_ALIGNED} KiB and RootFS $ROOTFS_SIZE KiB"


	# Initialize sdcard image file
	dd if=/dev/zero of=${SDIMG} bs=1024 count=0 seek=${SDIMG_SIZE}

	# Create partition table
	parted -s ${SDIMG} mklabel msdos

	# Create boot partition and mark it as bootable
	parted -s ${SDIMG} unit KiB mkpart primary fat32 ${IMAGE_ROOTFS_ALIGNMENT} $(expr ${BOOT_SPACE_ALIGNED} \+ ${IMAGE_ROOTFS_ALIGNMENT})
	parted -s ${SDIMG} set 1 boot on


	#Calculate aligned addresses for additional partitions
	BOOTFLAGSSTART=$(expr ${BOOT_SPACE_ALIGNED} \+ ${IMAGE_ROOTFS_ALIGNMENT} \+ 1)
	BOOTFLAGSSTART=$(expr ${BOOTFLAGSSTART} - ${BOOTFLAGSSTART} % ${IMAGE_ROOTFS_ALIGNMENT})
	BOOTFLAGSEND=$(expr ${BOOTFLAGSSTART} \+ ${BOOTFLAGS_SIZE})

	RFS1START=$(expr ${BOOTFLAGSEND} \+ ${IMAGE_ROOTFS_ALIGNMENT})
	RFS1START=$(expr ${RFS1START} - ${RFS1START} % ${IMAGE_ROOTFS_ALIGNMENT})
	RFS1END=$(expr ${RFS1START} \+ ${ROOTFS_SIZE})

	RFS2START=$(expr $RFS1END \+ ${IMAGE_ROOTFS_ALIGNMENT})
	RFS2START=$(expr ${RFS2START} - ${RFS2START} % ${IMAGE_ROOTFS_ALIGNMENT})
	RFS2END=$(expr ${RFS2START} \+ ${ROOTFS_SIZE})

	CONFIGSTART=$(expr $RFS2END \+ ${IMAGE_ROOTFS_ALIGNMENT})
	CONFIGSTART=$(expr ${CONFIGSTART} - ${CONFIGSTART} % ${IMAGE_ROOTFS_ALIGNMENT})
	CONFIGEND=$(expr ${CONFIGSTART} \+ ${CONFIG_SIZE})

	CACHESTART=$(expr $CONFIGEND \+ ${IMAGE_ROOTFS_ALIGNMENT})
	CACHESTART=$(expr ${CACHESTART} - ${CACHESTART} % ${IMAGE_ROOTFS_ALIGNMENT})
	CACHEEND="-1s"


	#Create additional partitions
	parted -s ${SDIMG} -- unit KiB mkpart primary ext2 ${BOOTFLAGSSTART} ${BOOTFLAGSEND}
	parted ${SDIMG} print

	parted -s ${SDIMG} -- unit KiB mkpart extended $(expr ${RFS1START} \- ${IMAGE_ROOTFS_ALIGNMENT}) -1s
	parted ${SDIMG} print

	parted -s ${SDIMG} -- unit KiB mkpart logical ext2 $(expr ${RFS1START}) ${RFS1END}
	parted ${SDIMG} print

	parted -s ${SDIMG} -- unit KiB mkpart logical ext2 ${RFS2START} ${RFS2END}
	parted ${SDIMG} print

	parted -s ${SDIMG} -- unit KiB mkpart logical ext2 ${CONFIGSTART} ${CONFIGEND}
	parted ${SDIMG} print

	parted -s ${SDIMG} -- unit KiB mkpart logical ext2 ${CACHESTART} ${CACHEEND}
	parted ${SDIMG} print



	# create local boot partition and copy MLO, u-boot.bin and boot script to it
	BOOT_BLOCKS=$(LC_ALL=C parted -s ${SDIMG} unit b print | awk '/ 1 / { print substr($4, 1, length($4 -1)) / 512 /2 }')
	rm -f ${WORKDIR}/boot.img
	mkfs.vfat -n "${BOOTDD_VOLUME_ID}" -S 512 -C ${WORKDIR}/boot.img $BOOT_BLOCKS
	mcopy -i ${WORKDIR}/boot.img -s ${DEPLOY_DIR_IMAGE}/MLO ::MLO
	mcopy -i ${WORKDIR}/boot.img -s ${DEPLOY_DIR_IMAGE}/u-boot.img ::u-boot.img
	mcopy -i ${WORKDIR}/boot.img -s ${DEPLOY_DIR_IMAGE}/boot.scr ::boot.scr


	# Burn Partitions
	dd if=${WORKDIR}/boot.img of=${SDIMG} conv=notrunc seek=1 bs=$(expr ${IMAGE_ROOTFS_ALIGNMENT} \* 1024)


	#Add label to rootfs partition
	tune2fs -L rootfs1 ${SDIMG_ROOTFS}
	dd if=${SDIMG_ROOTFS} of=${SDIMG} conv=notrunc seek=1 bs=$(expr 1024 \* ${RFS1START})
	tune2fs -L rootfs2 ${SDIMG_ROOTFS}
	dd if=${SDIMG_ROOTFS} of=${SDIMG} conv=notrunc seek=1 bs=$(expr 1024 \* ${RFS2START})

	#Reset the label back to empty
	tune2fs -L "" ${SDIMG_ROOTFS}

	#create empty BOOTFLAGS partition
	dd if=/dev/zero of=${IMGDEPLOYDIR}/bootflags.ext3 seek=${BOOTFLAGS_SIZE} count=0 bs=1k
	mkfs.ext3 -L bootflags -F $extra_imagecmd ${IMGDEPLOYDIR}/bootflags.ext3
	dd if=${IMGDEPLOYDIR}/bootflags.ext3 of=${SDIMG} conv=notrunc seek=1 bs=$(expr 1024 \* ${BOOTFLAGSSTART})

	#create empty CONFIG partition
	dd if=/dev/zero of=${IMGDEPLOYDIR}/config.ext3 seek=${CONFIG_SIZE} count=0 bs=1k
	mkfs.ext3 -L config -F $extra_imagecmd ${IMGDEPLOYDIR}/config.ext3
	dd if=${IMGDEPLOYDIR}/config.ext3 of=${SDIMG} conv=notrunc seek=1 bs=$(expr 1024 \* ${CONFIGSTART})

	#create empty CACHE partition
	dd if=/dev/zero of=${IMGDEPLOYDIR}/cache.ext3 seek=$(expr ${SDIMG_SIZE} \- ${CACHESTART}) count=0 bs=1k
	mkfs.ext3 -L "cache" -F $extra_imagecmd ${IMGDEPLOYDIR}/cache.ext3
	dd if=${IMGDEPLOYDIR}/cache.ext3 of=${SDIMG} conv=notrunc seek=1 bs=$(expr 1024 \* ${CACHESTART})

}

# remnant of rpi3 
ROOTFS_POSTPROCESS_COMMAND += " rpi_generate_sysctl_config ; "

rpi_generate_sysctl_config() {
	# systemd sysctl config
	/usr/bin/test -d ${IMAGE_ROOTFS}${sysconfdir}/sysctl.d && \
				echo "kernel.core_uses_pid = 1" >> ${IMAGE_ROOTFS}${sysconfdir}/sysctl.d/rpi-vm.conf && \
				echo "kernel.core_pattern = /var/log/core" >> ${IMAGE_ROOTFS}${sysconfdir}/sysctl.d/rpi-vm.conf

	# sysv sysctl config
	IMAGE_SYSCTL_CONF="${IMAGE_ROOTFS}${sysconfdir}/sysctl.conf"
	/usr/bin/test -e ${IMAGE_ROOTFS}${sysconfdir}/sysctl.conf && \
				sed -e "/kernel.core_uses_pid/d" -i ${IMAGE_SYSCTL_CONF}
		echo "" >> ${IMAGE_SYSCTL_CONF} && echo "kernel.core_uses_pid = 1" >> ${IMAGE_SYSCTL_CONF}

	/usr/bin/test -e ${IMAGE_ROOTFS}${sysconfdir}/sysctl.conf && \
				sed -e "/kernel.core_pattern/d" -i ${IMAGE_SYSCTL_CONF}
		echo "" >> ${IMAGE_SYSCTL_CONF} && echo "kernel.core_pattern = /var/log/core" >> ${IMAGE_SYSCTL_CONF}
}
