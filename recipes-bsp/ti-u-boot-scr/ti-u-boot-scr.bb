SUMMARY = "U-boot boot script for mbed-am437x"
LICENSE = "Apache-2.0"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/Apache-2.0;md5=89aea4e17d99a7cacdbeed46a0096b10"

# fetcher does not work, installed in docker instead (+abs path /w mkimage)
DEPENDS = "u-boot-mkimage-native"

# no need for c compiler
INHIBIT_DEFAULT_DEPS = "1"

SRC_URI = "file://boot.cmd.in"


do_compile() {

    mkimage -A arm -T script -C none -n "Mbed-am437x boot script" -d "${WORKDIR}/boot.cmd.in" "${WORKDIR}/boot.scr"
}

inherit deploy

do_deploy() {

    install -d ${DEPLOYDIR}
    install -m 0644 "${WORKDIR}/boot.scr" "${DEPLOYDIR}/"
}

addtask do_deploy after do_compile before do_build

