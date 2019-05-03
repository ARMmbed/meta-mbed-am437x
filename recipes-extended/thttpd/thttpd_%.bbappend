
do_install_append () {

    #
    # this is hackish: thttpd competes /w edge for the same ip port with
    # arbitrary start order introduced by systemd. thttpd creeps in via
    # a package group from arago-base-tisdk-image and there does not seem
    # to be a way to remove thttpd without removing the entire group, which
    # in turn leads to other probs.
    #
    # so to get rid off thttpd, prevent it from starting by removing the 
    # start script.
    #

    rm ${D}${sysconfdir}/init.d/thttpd
}


