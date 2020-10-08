#!/bin/bash

##
# Copyright (c) 2020 Fabrice Nicol <fabrnicol@gmail.com>
#
# This file is part of mkgentoo.
#
# mkgentoo is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 3 of the License, or (at your option) any later version.
#
# FFmpeg is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with FFmpeg; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301
##

## @mainpage Usage
## @brief In a nutshell
## @n
## @code ./mkgentoo [command=argument] ... [command=argument]  [file.iso] @endcode
## @n
## @details
## See <a href="https://github.com/fabnicol/gentoo-creator/wiki"><b>Wiki</b></a> for details.
## @n
## @author Fabrice Nicol 2020
## @copyright This software is licensed under the terms of the <a href="https://www.gnu.org/licenses/gpl-3.0.en.html"><b>GPL v3</b></a>

## @file mkgentoo.sh
## @author Fabrice Nicol <fabrnicol@gmail.com>
## @copyright GPL v.3
## @brief Process options, create Gentoo VirtualBox machine and optionally create clonezilla install medium
## @note This file is not included into the clonezilla ISO liveCD.
## @par USAGE
## @code
## mkgentoo  [[switch=argument]...]  filename.iso  [1]
## mkgentoo  [[switch=argument]...]                [2]
## mkgentoo  help[=md]                             [3]
## @endcode
## @par
## Usage [1] creates a bootable ISO output file with a current Gentoo distribution.   @n
## Usage [2] creates a VirtualBox VDI dynamic disk and a virtual machine with name Gentoo.   @n
## Usage [3] prints this help, in markdown form if argument 'md' is specified.  @n
## @par
## Run: @code mkgentoo help @endcode to print a list of possible switches and arguments.
## @warning you should have at least 55 GB of free disk space in the current directory or in vmpath
## if specified.
## Boolean values are either 'true' or 'false'. For example, to build a minimal distribution,
## specify <tt> minimal=true</tt> on command line.
## @par \b Examples:
## @li Only create the VM and virtual disk, in debug mode,
## without R or RStudio and set new passwords, for a French-language platform. Use 8 cores.
## @code mkgentoo language=fr minimal=true debug_mode=true ncpus=8 nonroot_user=ken passwd='util!Hx&32F' rootpasswd='Hk_32!_CD' cleanup=false @endcode
## @li Create ISO clonezilla image of Gentoo linux, burn it to DVD, create an installed OS
## on a USB stick whose model label starts with \e PNY and finally create a clonezilla installer
## on another USB stick mounted under <tt> /media/ken/AA45E </tt>
## @code mkgento burn usb_device="PNY" usb_installer="Sams" my_gentoo_image.iso @endcode
## @defgroup createInstaller Create Gentoo linux image and installer.

## @var CLI
## @brief Command line
## @ingroup createInstaller

declare -r CLI="$*"
DEBUG_MODE=true

## @var ARR
## @brief global string array of switches and default values
## @details Structure is as follows: @code
## ("commandline switch" "Description"  "Default value" ...) @endcode
## A double-entry arry will be simulated using indexes.
## @ingroup createInstaller
## @note `debug_mode` should be place up front in the array

declare -a -r ARR=("debug_mode"  "Do not clean up mkgentoo custom logs at root of gentoo system files before VM shutdown. Boolean."  "false"
     "build_virtualbox"   "Download code source and automatically build virtualbox and tools" "false"
     "burn"        "Burn to optical disc. Boolean."                                      "false"
     "cdrecord"    "cdrecord path. Automatically determined if left unspecified."        "$(which cdrecord)"
     "cflags"      "GCC CFLAGS options for ebuilds"                                      "-march=core-avx2 -O2"
     "cleanup"       "Clean up archives, temporary images and virtual machine after successful completion. Boolean."  "true"
     "clonezilla_install"  "Use the CloneZilla live CD instead of the official Gentoo minimal install CD. May be more robust for headless install, owing to a VB bug requiring artificial keyboard input (see doc)."  "false"
     "cpuexecutioncap" "Maximum percentage of CPU per core (0 to 100)"                    "100"
     "create_squashfs"  "(Re)create the squashfs filesystem. Boolean."                   "true"
     "force"         "Forcefully creates machine even if others with same same exist. Stops and restarts VBox daemons. Not advised if other VMs are running."                                            "false"
     "disable_md5_check" "Disable MD5 checkums verification after downloads. Boolean."   "true"
     "download"    "Download install ISO image from Gentoo mirror. Boolean."             "true"
     "download_clonezilla" "Refresh CloneZilla ISO download. An ISO file must have been downloaded to create the recovery image of the Gentoo platform once the virtual machine has ended its job. Boolean"                    "true"
     "download_clonezilla_path" "Download the following CloneZilla ISO"                       "https://sourceforge.net/projects/clonezilla/files/clonezilla_live_alternative/20200703-focal/clonezilla-live-20200703-focal-amd64.iso/download"
     "download_rstudio"  "Download and build RStudio. Boolean."                          "true"
     "download_arch" "Download and install stage3 archive to virtual disk. Booelan."     "true"
     "elist"       "\t File containing a list of Gentoo ebuilds to add to the VM on top of stage3. Note: if the default value is not used, adjust the names of the 'elist'.accept_keywords and 'elist'.use files" "ebuilds.list"
     "emirrors"    "Mirror sites for downloading ebuilds"                                "http://gentoo.mirrors.ovh.net/gentoo-distfiles/"
     "firmware"      "Type of bootloader: bios or efi. Use only 'bios', tweaking not supported but might be at later stages." "bios"
     "from_device"   "Do not Generate Gentoo but use the external device on which Gentoo was previously installed. Boolean." "false"
     "from_iso"      "Do not generate Gentoo but use the bootable ISO given on commandline. Boolean." "false"
     "from_vm"       "Do not generate Gentoo but use the VM ${VM}. Boolean."              "false"
     "githubpath"  "RStudio Github path to zip: path right before version.zip"           "https://github.com/rstudio/rstudio/archive/v"
     "help"          "\t This help"                                                       ""
     "hwvirtex"      "Activate HWVIRTEX: on/off"                                          "on"
     "ioapic"        "IOAPIC parameter: on or off"                                        "on"
     "kernel_config"  "Use a custom kernel config file"                                  ".config"
     "language"    "Set default login keyboard layout"                                   "us"
     "lineno_patch" "Line patched against vbox-img.cpp in virtualbox source code"        "797"
     "livecd"      "Path to the live CD that will start the VM"                          "gentoo.iso"
     "mem"         "\t VM RAM memory in MiB"                                             "8000"
     "minimal"     "Remove *libreoffice* and *data science tools* from default list of installed software. Boolean."  "false"
     "mirror"      "Mirror site for downloading of stage3 tarball"                       "http://gentoo.mirrors.ovh.net/gentoo-distfiles/"
     "ncpus"       "\t Number of VM CPUs. By default the third of available threads."    "$(($(nproc --all)/3))"
     "nonroot_user" "Non-root user"                                                      "fab"
     "pae"           "Activate PAE: on/off"                                               "on"
     "paravirtprovider" "Virtualization interface: kvm for GNU/Linux, may be tweaked (see VirtualBox documentation)"     "kvm"
     "passwd"      "User password"                                                       "dev20"
     "processor"   "Processor type"                                                      "amd64"
     "rootpasswd"  "Root password"                                                       "dev20"
     "rstudio"     "RStudio version to be downloaded and built from github source"       "1.3.1073"
     "rtcuseutc"   "Use UTC as time reference: on/off"                                   "on"
     "r_version"   "R version"                                                           "4.0.2"
     "scsi_address" "In case of several optical disc burners, specify the SCSI address as x,y,z"  ""
     "size"        "\t Dynamic disc size"                                                "55000"
     "stage3"      "Path to stage3 archive"                                              "stage3.tar.xz"
     "usbehci"     "Activate USB2 driver: on/off"                                        "off"
     "usbxhci"     "Activate USB3 driver: on/off. Note: if on, needs extension pack."    "off"
     "usb_device"  "Create Gentoo OS on external device. Argument is either a device label (e.g. sdb1, hdb1), or a mountpoint directory (if mounted), or a few consecutive letters of the model (e.g. 'Samsu', 'PNY' or 'Kingst'), if there is just one such."    ""
     "usb_installer" "Create Gentoo clone installer on external device. Argument is either a device label (e.g. sdb2, hdb2), or a mountpoint directory (if mounted), or a few consecutive letters of the model, if there is just one such. If unspecified, **usb_device** value will be used. OS Gentoo will be replaced by Clonezilla installer."  ""
     "vm"          "\t Virtual Machine name. Unless 'force=true' is used, a time stamp will be appended to avoid registry issues with prior VMs of the same name."                                             "Gentoo"
     "vbox_version"  "Virtualbox version"                                                "6.1.14"
     "vbox_version_full" "Virtualbox full version"                                       "6.1.14a"
     "vbpath"      "Path to VirtualBox directory"                                        "/usr/bin"
     "vmpath"      "Path to VM base directory"                                           "$PWD"
     "vmtype"      "gui or headless (without graphical interface, currently to be fixed)" "gui"
     "verbose"       "Increase verbosity"                                                 "false"
     "vtxvpid"       "Activate VTXVPID: on/off"                                           "on"  )

## @var ARRAY_LENGTH
## @brief Number of switches (true length of array divided by 3)
## @ingroup createInstaller

declare -i -r ARRAY_LENGTH=$((${#ARR[*]}/3))

## @var ISO
## @brief Name of downloaded clonezilla ISO file
## @ingroup createInstaller

export ISO="downloaded.iso"

## @fn test_cli_pre()
## @brief Check VirtualBox version and prepare commandline analysis
## @retval 0 otherwise exit -1 if VirtualBox is too old
## @ingroup createInstaller

test_cli_pre() {

    [ "$(whoami)" != "root" ] && { logger -s "[ERR] must be root to continue"; exit 1; }
    [ -d /home/partimage ] && rm -rf /home/partimag
    mkdir -p /home/partimag

    # Configuration tests

    local do_exit=false
    [ -z "$(VBoxManage --version)" ] \
        && { logger -s "[ERR] Did not find a proper VirtualBox install. Reinstall Virtualbox version >= 6.1"; do_exit=true; }
    [ -z "$(uuid)" ] \
        && { logger -s "[ERR] Did not find uuid. Intall the uuid package"; do_exit=true; }
    [ -z "$(mkisofs -version)" ] \
        && { logger -s "[ERR] Did not find mkisofs. Install the cdrtools package (see Wiki)"; do_exit=true; }
    [ -z "$(mksquashfs -version)" ] \
        && { logger -s "[ERR] Did not find squashfs. Install the squashfs package."; do_exit=true; }
    [ -z "$(xz --version)" ] \
        && { logger -s "[ERR] Did not find xz. Install xz and its libraries"; do_exit=true; }
    [ -z "$(ocs-sr -v)" ] \
        && { logger -s "[ERR] Did not find CloneZilla. Install CloneZilla and dependencies first."; do_exit=true; }
    [ -z "$(wget --version)" ] \
        && { logger -s "[ERR] Did not find wget. Please install it now."; do_exit=true; }
    [ -z "$(md5sum --version)" ] \
        && { logger -s "[ERR] Did not find md5sum. Install the coreutils package."; do_exit=true; }
    [ -z "$(tar --version)" ] \
        && { logger -s "[ERR] Did not find tar."; do_exit=true; }
    if [ -z "$(mountpoint --version)" ] || [ -z "$(findmnt --version)" ]
    then
        logger -s "[ERR] Did not find mountpoint/findmnt. Install util-linux."
        do_exit=true
    fi
    [ -z "$(sed --version)" ] && { logger -s "[ERR] Did not find sed."; do_exit=true; }
    [ -z "$(which xorriso)" ] && { logger -s "[ERR] Did not find xorriso (libburnia project)"; do_exit=true; }

    # Check VirtualBox version

    declare -r vbox_version=$(VBoxManage -v)
    declare -r version_major=$(echo ${vbox_version} | sed -E 's/([0-9]+)\..*/\1/')
    declare -r version_minor=$(echo ${vbox_version} | sed -E 's/[0-9]+\.([0-9]+)\..*/\1/')
    declare -r version_index=$(echo ${vbox_version} | sed -E 's/[0-9]+\.[0-9]+\.([0-9][0-9]).*/\1/')
    if [ ${version_major} -lt 6 ] || [ ${version_minor} -lt 1 ] || [ ${version_index} -lt 10 ]
    then
        logger -s "[ERR] VirtualBox must be at least version 6.1.10"
        logger -s "[ERR] Please update and reinstall"
        do_exit=true
    fi

    #--- do_exit:

    [ "$do_exit" = "true" ] && exit -1

    #---

    export  ISO_OUTPUT=$(sed -E 's/.*\b(\w+\.(iso|ISO))\b.*$/\1/' <<< "${CLI}")
    if [ -n "${ISO_OUTPUT}" ]
    then
        logger -s "[MSG] Build Gentoo distribution to bootable ISO output ${ISO_OUTPUT}"
        export CREATE_ISO=true
    else
        logger -s "[ERR] You did not indicate an ISO output file."
        logger -s "[MSG] A Virtual machine will be created with name Gentoo under $HOME"
        export CREATE_ISO=false
    fi
    return 0
}

## @fn test_cli()
## @brief Analyse commandline
## @param cli  Commandline
## @details Create globals of the form VAR=arg  when there is var=arg on commandline @n
## Otherwise assign default values VAR=defaults (3rd argument in array ARR)
## @ingroup createInstaller

test_cli() {
    declare -i i=$1
    local sw=${ARR[i*3]}
    local desc=${ARR[i*3+1]}
    local default=${ARR[i*3+2]}
    local vm_arg=$(sed -E "s/.*${sw}=([^ ]+).*$/\1/" <<< "${CLI}")
    declare -u VAR=${sw}

    # debug_mode should be placed on top of ARR

    if [ -n "${vm_arg}" ] && [ "${vm_arg}" != "${CLI}" ]
    then
        "${DEBUG_MODE}" && logger -s "[CLI] ${desc} = ${vm_arg}" | sed 's/\\t //'
        eval "${VAR}"="\"${vm_arg}\""
    else
        "${DEBUG_MODE}" && logger -s "[CLI] ${desc} = ${default}" | sed 's/\\t //'
        eval "${VAR}"="\"${default}\""
    fi
    export "${VAR}"
}


## @fn test_cli_post()
## @brief Check commanline coherence and incompatibilities
## @retval 0 or exit -1 on incompatibilities
## @ingroup createInstaller

test_cli_post() {

    # ruling out incompatible options

    "${DOWNLOAD}" && ! "${CREATE_SQUASHFS}" \
                  &&  logger -s "[ERR][CLI] You cannot set create_squashfs=false with download=true" \
                  &&  exit -1

    if { "${FROM_ISO}" && "${FROM_DEVICE}"; } \
           || { "${FROM_VM}" && "${FROM_DEVICE}"; } \
           || { "${FROM_ISO}" && "${FROM_VM}"; }
    then
            logger -s "[ERR][CLI] Only one of the three options from_iso, from_device or from_vm may be specified on commandline."
            exit -1
    fi
    if  "${FROM_ISO}" && "${CREATE_ISO}"; then
         logger -s "[ERR][CLI] You cannot specify an ISO output and input on commandline at the same time."
         exit -1
    fi
    if  "${FROM_ISO}" && "${USB_DEVICE}"; then
         logger -s "[ERR][CLI] Recovering OS directly to device from Clonezilla image is not supported."
         logger -s "[ERR][CLI] Burn ISO to install medium (DVD or USB strick) and install to device with it."
         exit -1
    fi

    # there are two modes of install: with CloneZilla live CD (Ubuntu-based) or official Gentoo install

    ${CLONEZILLA_INSTALL} && OSTYPE=Ubuntu_64 || OSTYPE=Gentoo_64

    # minimal CPU allocation

    [ "${NCPUS}" = "0" ] && NCPUS=1

    # VM name will be time-stamped to avoid registration issues, unless 'force=true' is used on commandline

    VM="${VM}".$(date -Is)

    # this far the only accept_keywords ebuils is dev-lang/R
    # Others can be manually added to file ${ELIST}.accept_keywords defaulting to ebuilds.list.accept_keywords

    sed -i '/dev-lang\/R.*$/d'  "${ELIST}.accept_keywords"
    echo ">=dev-lang/R-${R_VERSION}  ~${PROCESSOR}" >> "${ELIST}.accept_keywords"
}

## @fn help_md()
## @brief Print usage in markdown format
## @ingroup createInstaller

help_md() {
    echo "**USAGE:**  "
    echo "**mkgentoo**  [[switch=argument]...]  filename.iso  [1]  "
    echo "**mkgentoo**  [[switch=argument]...]                [2]  "
    echo "**mkgentoo**  help[=md]                             [3]  "
    echo "  "
    echo "Usage [1] creates a bootable ISO output file with a current Gentoo distribution.  "
    echo "Usage [2] creates a VirtualBox VDI dynamic disk and a virtual machine with name Gentoo.  "
    echo "Usage [3] prints this help, in markdown form if argument 'md' is specified.  "
    echo "Warning: you should have at least 55 GB of free disk space in the current directory or in vmpath if specified.  "
    echo "  "
    echo "**Switches:**  "
    echo "  "
    echo "Boolean values are either 'true' or 'false'. For example, to build a minimal distribution, specify:  "
    echo ">  minimal=true  "
    echo "  "
    echo "on command line.  "
    echo "  "
    echo " | switch | description | default value |  "
    echo " |:-----:|:--------:|:-----:|  "
    declare -i i
    for ((i=0; i<ARRAY_LENGTH; i++)); do
        declare -i sw=i*3       # no spaces!
        declare -i desc=i*3+1
        declare -i def=i*3+2
        echo -e "| ${ARR[sw]} \t| ${ARR[desc]} \t| [${ARR[def]}] |  "
    done
}

## @fn help_()
## @brief Print usage to stdout
## @ingroup createInstaller

help_() {
    help_md | sed 's/[\*\|\>]//g'
}

## @fn fetch_livecd()
## @brief Downloads Gentoo install CD
## @details Caches it as ${ISO}
## @retval Returns 0 on success or -1 on exit
## @ingroup createInstaller

fetch_livecd() {
    cd "${VMPATH}"
    local CACHED_ISO="install-${PROCESSOR}-minimal.iso"

    # Use clonezilla ISO for headless VM and Gentoo minimal install ISO for gui VM

    if  "${CLONEZILLA_INSTALL}"
    then
        DOWNLOAD_CLONEZILLA="${DOWNLOAD}"
        CACHED_ISO=clonezilla.iso
    else
        "${DOWNLOAD}" && get_gentoo_install_iso
    fi
    if "${DOWNLOAD_CLONEZILLA}"
    then
        get_clonezilla_iso
        "${CLONEZILLA_INSTALL}" && ISO="${CLONEZILLACD}"
    else
        [ -f "clonezilla.iso" ] && CLONEZILLACD="clonezilla.iso" \
        || { logger -s "[ERR] CloneZilla ISO has not been cached. Run with download=true" ; exit -1; }
    fi
    if ! "${DOWNLOAD}"
    then
        if  "${CREATE_SQUASHFS}"
        then
            [ -f ${CACHED_ISO} ] \
                && logger -s "[INF] Uncaching ${ISO} from ${CACHED_ISO}" \
                && cp -f ${CACHED_ISO} ${ISO}
        else
            logger -s "[ERR] No ISO file was found, please rerun with download=true" \
            && exit -1
        fi
        LIVECD=${ISO}
    fi
    return 0
}

## @fn fetch_stage3()
## @brief Downloads a fresh stage3 Gentoo archive
## @details Caches it as ${STAGE3}
## @ingroup createInstaller

fetch_stage3() {

    # Fetching stage3 tarball

    local CACHED_STAGE3="stage3-${PROCESSOR}.tar.xz"
    if "${DOWNLOAD_ARCH}"
    then
        logger -s "[INF] Cleaning up stage3 data..."
        [ -f latest-stage3*.txt* ] && rm -f latest-stage3*.txt*
        logger -s "[INF] Downloading stage3 data..."
        wget ${MIRROR}/releases/${PROCESSOR}/autobuilds/latest-stage3-${PROCESSOR}.txt 2>&1 | logger -s
        [ $? != 0 ] \
            && logger -s "[ERR] Could not download stage3 from mirrors: ${MIRROR}/releases/${PROCESSOR}/autobuilds/latest-stage3-${PROCESSOR}.txt" \
            && exit -1
    else
        [ ! -f latest-stage3-${PROCESSOR}.txt ] \
            && logger -s "[ERR] No stage 3 download information available!" \
            && logger -s "[ERR] Rerun with download_stage3=true" \
            && exit -1
    fi
    local current=$(cat latest-stage3-${PROCESSOR}.txt | grep "stage3-${PROCESSOR}.*.tar.xz" | cut -f 1 -d' ')
    if "${DOWNLOAD_ARCH}"
    then
        logger -s "[INF] Cleaning up stage3 archives(s)..."
        [ -f stage3-${PROCESSOR}-*tar.xz* ] && rm -f stage3-${PROCESSOR}-*tar.xz*
        [ -f ${STAGE3} ] && rm ${STAGE3}
        logger -s "[INF] Downloading ${current}..."
        wget "${MIRROR}/releases/${PROCESSOR}/autobuilds/${current}"  2>&1 | logger -s
        [ $? != 0 ] \
            && logger -s "[ERR] Could not download stage3 tarball from mirror: ${MIRROR}/releases/${PROCESSOR}/autobuilds/${current}" \
            && exit -1
        ! ${DISABLE_MD5_CHECK} && check_md5sum $(basename ${current})
        logger -s "[INF] Caching ${current} to ${CACHED_STAGE3}"
        cp -f $(echo -s ${current} | sed 's/.*stage3/stage3/')  ${CACHED_STAGE3}
    fi
    [ ! -f "${CACHED_STAGE3}" ] \
        && logger -s "[ERR] No stage3 tarball!" \
        && logger -s "[ERR] Rerun with download_stage3=true" \
        && exit -1
    logger -s "[INF] Uncaching stage3 from ${CACHED_STAGE3} to ${STAGE3}"
    cp -f ${CACHED_STAGE3} ${STAGE3}
}

## @fn make_boot_from_livecd()
## @brief Tweak the Gentoo minimal install CD so that the custom-
## made shell scripts and stage3 archive  are included into the squashfs filesystem.
## @details This function is returned from early if @code create_squashfs=false @endcode is given on commandline.
## @note Will be run in the ${VM} virtual machine
## @retval Returns 0 on success or -1 on failure.
## @ingroup createInstaller

make_boot_from_livecd() {
    if [ ! -f ${ISO} ]; then
        logger -s "[ERR] No active ISO file in current directory!"
        exit -1
    fi
    if ! "${CREATE_SQUASHFS}"
    then
        logger -s "[MSG] Reusing ${ISO} which was previously created... use this option with care if only you have run mkgentoo before."
        logger -s "[MSG] create_squashfs should be left at 'true' (default) if mkvm.sh or mkvm_chroot.sh have been altered"
        logger -s "[MSG] or the kernel config file, the global variables, the boot config files, the stage3 archive or the ebuild list."
        logger -s "[MSG] It can be set at 'false' if the install ISO file and stage3 archive are cached in the directory after prior downloads"
        logger -s "[MSG] with no other changes in the above set of files."
        return 0
    fi

    # mount ISO install file

    local verb=""
    "${VERBOSE}" && verb="-v"
    mountpoint -q mnt && umount -l mnt
    [ -d mnt ] && rm -rf mnt
    mkdir mnt
    mount -oloop ${ISO} mnt/  2>/dev/null
    ! mountpoint -q mnt && logger -s "[ERR] ISO not mounted!" && exit -1

    # get a copy with write access

    [ -d mnt2 ] && rm -rf mnt2/
    mkdir mnt2/
    "${VERBOSE}" && logger -s "[INF] Syncing mnt2 with ISO mountpoint..."
    rsync -a ${verb} mnt/ mnt2

    # parameter adjustment to account for Gentoo/CloneZilla differences

    local ROOT_LIVE="${VMPATH}/mnt2"
    local SQUASHFS_FILESYSTEM=image.squashfs
    export ISOLINUX_DIR=isolinux
    if "${CLONEZILLA_INSTALL}"
    then
        ISOLINUX_DIR=syslinux
        ROOT_LIVE="${VMPATH}/mnt2/live"
        SQUASHFS_FILESYSTEM=filesystem.squashfs
    fi

    # ISOLINUX config adjustments to automate the boot and reduce user input

    cd mnt2/${ISOLINUX_DIR}
    if "${CLONEZILLA_INSTALL}"
    then
        cp ${verb} -f ${VMPATH}/clonezilla/syslinux/isolinux.cfg .
    else
        sed -i 's/timeout.*/timeout 1/' isolinux.cfg
        sed -i 's/ontimeout.*/ontimeout gentoo/' isolinux.cfg
    fi

    # now unsquashfs the liveCD filesystem

    cd ${ROOT_LIVE}
    "${VERBOSE}" && logger -s "[INF] Unsquashing filesystem..." && unsquashfs ${SQUASHFS_FILESYSTEM}  \
                 ||  unsquashfs -q  ${SQUASHFS_FILESYSTEM} 2>&1 >/dev/null
    [ $? != 0 ] && logger -s "[ERR] unsquashfs failed !" && exit -1

    # we stick to the official mount point /mnt/gentoo

    "${CLONEZILLA_INSTALL}" &&  mkdir -p ../mnt/gentoo

    # copy the scripts, kernel config, ebuild list and stage3 archive to the /root directory
    # of the unsquashed filesystem
    # note: environment variables are passed along using a "physical" copy to /root/.bashrc

    cd "${VMPATH}"
    [ ! -f scripts/mkvm.sh ] && logger -s "[ERR] No mkvm.sh script!" && exit -1
    [ ! -f scripts/mkvm_chroot.sh ] && logger -s "[ERR] No mkvm_chroot.sh script!" && exit -1
    "${MINIMAL}" && cp ${verb} -f "${ELIST}.minimal" "${ELIST}"  \
                 || cp ${verb} -f "${ELIST}.complete" "${ELIST}"
    [ ! -f "${ELIST}" ] || [ ! -f "${ELIST}.use" ] || [ ! -f "${ELIST}.accept_keywords" ] \
        && logger -s "[ERR] No ebuild list!" \
        && exit -1
    [ ! -f "${STAGE3}" ] && logger -s "[ERR] No stage3 archive!" && exit -1
    [ ! -f "${KERNEL_CONFIG}" ] && logger -s "[ERR] No kernel configuration file!" && exit -1
    local sqrt="${ROOT_LIVE}/squashfs-root/root/"
    mv ${verb} -f "${STAGE3}" ${sqrt}                  | logger -s
    cp ${verb} -f scripts/mkvm.sh ${sqrt}              | logger -s
    chmod +x ${sqrt}mkvm.sh                            | logger -s
    cp ${verb} -f scripts/mkvm_chroot.sh ${sqrt}       | logger -s
    chmod +x ${sqrt}mkvm_chroot.sh                     | logger -s
    cp ${verb} -f "${ELIST}" "${ELIST}.use" "${ELIST}.accept_keywords" ${sqrt}  | logger -s
    cp ${verb} -f "${KERNEL_CONFIG}" ${sqrt}           | logger -s
    cd ${sqrt}

    # now prepare the .bashrc file by exporting the environment
    # this will be placed under /root in the VM

    rc=".bashrc"
    cp ${verb} -f /etc/bash.bashrc ${rc}                | logger -s
    declare -i i
    for ((i=0; i<ARRAY_LENGTH; i++)); do
        local  capname=${ARR[i*3]^^}
        local  expstring="export ${capname}=\"${!capname}\""
        if [ "${VERBOSE}" = "true" ]; then
            logger -s "${expstring}"
        fi
        echo "${expstring}" >> ${rc}
    done

    # the whole platform-making process will be launched by mkvm.sh under /root/
    # and fired on by .bashrc sourcing once the liveCD exits the boot process into root shell

    echo  "/bin/bash mkvm.sh"  >> ${rc}

    # restore the squashfs filesystem

    cd ../..
    rm ${verb} -f ${SQUASHFS_FILESYSTEM}                | logger -s
    local verb2="-quiet"
    mksquashfs squashfs-root/ ${SQUASHFS_FILESYSTEM} ${verb2}   | logger -s
    rm -rf squashfs-root/                               | logger -s

    # restore the ISO in bootable format

    cd "${VMPATH}"
    "${VERBOSE}" &&  verb2="-v"

    recreate_liveCD_ISO mnt2/                           | logger -s

    # cleanup by default

    umount -l mnt
    "${CLEANUP}" && rm -rf ${verb} mnt && rm -rf ${verb} mnt2
    return 0
}

## @fn test_vm_running()
## @brief Check if VM as first named argument exists and is running
## @param vm VM name or UUID
## @retval  Returns 0 on success and 1 is VM is not listed or not running
## @ingroup createInstaller

test_vm_running() {
    [ -n "$(VBoxManage list vms | grep \"$1\")" ]  && [ -n "$(VBoxManage list runningvms | grep \"$1\")" ]
}

## @fn deep_clean()
## @private
## @brief Force-clean root VirtualBox registry
## @ingroup createInstaller

deep_clean() {

    # no deep clean with 'force=false'

    ! "${FORCE}" && return 0

    logger -s "[INF] Cleaning up hard disks in config file because of inconsistencies in VM settings"
    local registry=/root/.config/VirtualBox/VirtualBox.xml
    if grep -q "${VM}.vdi" ${registry}
    then
        logger -s "[MSG] Disk ${VM}.vdi is already registered and needs to be wiped out of the registry"
        logger -s "[MSG] Otherwise issues may arise with UUIDS and data integrity"
        logger -s "[WAR] Stopping VirtualBox server. You need to stop/snapshot your running VMs."
        logger -s "[WAR] Enter Y when this is done or another key to exit."
        logger -s "[WAR] In which case ${VM}.vdi might not be properly attached to virtual machine ${VM}"
        read -p "Enter Y to continue or another key to skip deep clean: " reply
        [ reply != "Y" ] && [reply != "y" ] && return 0
    fi
    /etc/init.d/virtualbox stop
    sleep 5
    sed -i  '/^.*HardDisk.*$/d' registry
    sed -i -E  's/^(.*)<MediaRegistry>.*$/\1<MediaRegisty\/>/g' registry
    sed -i '/^.*<\/MediaRegistry>.*$/d' registry
    sed -i  '/^[[:space:]]*$/d' registry
    "${VERBOSE}" && cat  registry

     # it is necessary to sleep a bit otherwise doaemons will wake up with inconstitencies

    sleep 5
    /etc/init.d/virtualbox start
}


## @fn delete_vm()
## @param vm VM name
## @param ext virtual disk extension, without dot (defaults to "vdi").
## @brief Powers off, possibly with emergency stop, the VM names as first argument.
## @details @li Unregisters it
## @li Deletes its folder structure and hard drive (default is "vdi" as a second argument)
## @retval Returns 0 if Directory and hard drive could be erased, otherwise the OR value of both
## erasing commands
## @ingroup createInstaller

delete_vm() {
    if test_vm_running "$1"
    then
        logger -s "[INF] Powering off $1"
        VBoxManage controlvm "$1" poweroff 2>&1 | logger -s
    fi
    if test_vm_running "$1"
    then
        logger -s "[INF] Emergency stop for $1"
        VBoxManage startvm $1 --type emergencystop 2>&1 | logger -s
    fi
    logger -s "[INF] Closing medium $1.$2"
    if VBoxManage showmediuminfo "${VMPATH}/$1.$2" 2>/dev/null 1>/dev/null
    then
        VBoxManage storageattach "$1" --storagectl "SATA Controller" --port 0 --medium none 2>&1 | logger -s
        VBoxManage closemedium  disk "${VMPATH}/$1.$2" --delete 2>&1 | logger -s
    fi

    local res=$?
    if [ ${res} != 0 ]
    then

        # last resort. Happens when debugging with successive VMS
        # with same names or disk names and not enough wait time for daemons to clean up the mess
        # one needs to deep-clean twice. deep_clean will peek and clean the registry
        # altering it only if requested for security. This may cause other VMs to crash.

        deep_clean
    fi
    if [ -n "$(VBoxManage list vms | grep \"$1\")" ]
    then
        logger -s "[MSF] Current virtual machine: $(VBoxManage list vms | grep \"$1\"))"
        logger -s "[INF] Removing SATA controller"
        VBoxManage storagectl "$1" --name "SATA Controller" --remove 2>&1 | logger -s
        logger -s "[INF] Removing IDE controller"
        VBoxManage storagectl "$1" --name "IDE Controller" --remove  2>&1 | logger -s
        logger -s "[INF] Unregistering $1"
        VBoxManage unregistervm "$1" --delete 2>&1 | logger -s
    fi

    # the following is overall unnecessary except for issues with VBoxManage unregistervm

    [ -d "${VMPATH}/$1" ] \
        && logger -s "Force removing $1" \
        && rm -rf  "${VMPATH}/$1"

    # same for disk registration

    [ -n "$2" ] && [ -f "${VMPATH}/$1.$2" ] \
                && logger -s "Force removing $1.$2" \
                && rm -f   "${VMPATH}/$1.$2"

    # deep clean again!

    [ ${res} != 0 ] && deep_clean
    return ${res}
}

## @fn create_vm()
## @brief Create main VirtualBox machine using VBoxManage commandline
## @details Register machine, create VDI drive, create IDE drive attach disks to controlers @n
## Attach augmented clonezilla LiveCD to IDE controller. @n
## Wait for the VM to complete its task. Check that it is still running every minute. @n
## Finally compact it.
## @note VM may be visible (vmtype=gui) or without GUI (vmtype=headless, currently to be fixed)
## @todo Find a way to only compact on success and never on failure of VM.
## @ingroup createInstaller

create_vm() {
    export PATH=${PATH}:${VBPATH}
    cd ${VMPATH}
    delete_vm "${VM}" "vdi"
    local MEDIUM_UUID=`uuid`

    # create and register VM

    logger -s <<< $(VBoxManage createvm --name "${VM}" \
                                      --ostype ${OSTYPE}  \
                                      --register \
                                      --basefolder "${VMPATH}"  2>&1 \
                                      | xargs echo "[INF]")

    # add reasonably optimal options. Note: without --cpu-profile host,
    # building issues have arisen for qtsensors
    # owing to the need of haswell+ processors to build it.
    # By default the VB processor configuration is lower-grade
    # all other parameters are listed on commandline options with default values

    logger -s <<< $(VBoxManage modifyvm "${VM}" \
                             --cpus ${NCPUS} \
                             --cpu-profile host \
                             --memory ${MEM} \
                             --vram 128 \
                             --ioapic ${IOAPIC} \
                             --usbxhci ${USBXHCI} \
                             --usbehci ${USBEHCI} \
                             --hwvirtex ${HWVIRTEX} \
                             --pae ${PAE} \
                             --cpuexecutioncap ${CPUEXECUTIONCAP} \
                             --ostype ${OSTYPE} \
                             --vtxvpid ${VTXVPID} \
                             --paravirtprovider ${PARAVIRTPROVIDER} \
                             --rtcuseutc ${RTCUSEUTC} \
                             --firmware ${FIRMWARE} 2>&1 \
                             | xargs echo "[MSG]")

    # create virtual VDI disk

    logger -s <<< $(VBoxManage createmedium --filename "${VM}.vdi" \
                                          --size ${SIZE} \
                                          --variant Standard 2>&1 | xargs echo "[MSG]")

    # set disk UUID once and for all to avoid serious debugging issues whils several VMS are around,
    # some in zombie state, with same-name disks floating around with different UUIDs and registration issues

    logger -s <<< $(VBoxManage internalcommands sethduuid "${VM}.vdi" ${MEDIUM_UUID} 2>&1 \
                               | xargs echo "[MSG]")

    # add storage controllers

    logger -s <<< $(VBoxManage storagectl "${VM}" \
                             --name "IDE Controller"  \
                             --add ide 2>&1 \
                             | xargs echo "[MSG]")
    logger -s <<< $(VBoxManage storagectl "${VM}" \
                             --name "SATA Controller" \
                             --add sata \
                             --bootable on 2>&1 \
                             | xargs echo "[MSG]")

    # attach media to controllers and double check that the attached UUID is the right one
    # as there have been occasional issues of UUID switching on attachment. Only one port/device is necessary
    # use --tempeject on for live CD

    logger -s <<< $(VBoxManage storageattach "${VM}" \
                             --storagectl "IDE Controller"  \
                             --port 0 \
                             --device 0  \
                             --type dvddrive \
                             --medium ${LIVECD} \
                             --tempeject on  2>&1 | xargs echo "[MSG]")

    logger -s <<< $(VBoxManage storageattach "${VM}" \
                             --storagectl "SATA Controller" \
                             --medium "${VM}.vdi" \
                             --port 0 \
                             --device 0 \
                             --type hdd \
                             --setuuid ${MEDIUM_UUID}  2>&1 | xargs echo "[MSG]")

    # note: forcing UUID will potentially cause issues with registration if a prior run with the same disk
    # has set a prior UUID in the register (/root/.config/VirtualBox/VirtualBox.xml). So in the case a deep
    # clean is in order (see below).
    # Attaching empty drives may potentially be useful (e.g. when installing guest additions)

    logger -s <<< $(VBoxManage storageattach "${VM}" \
                             --storagectl "IDE Controller" \
                             --port 0 \
                             --device 1 \
                             --type dvddrive \
                             --medium emptydrive  2>&1 \
                             | xargs echo "[MSG]")

    # Starting VM

    logger -s <<< $(VBoxManage startvm "${VM}" --type ${VMTYPE} 2>&1 | xargs echo "[MSG]")

    # Sync with VM: this is a VBox bug workaround

    "${CLONEZILLA_INSTALL}" || [ ${VMTYPE} = "headless" ] && sleep 90 \
        && logger -s <<< $(VBoxManage controlvm "${VM}" keyboardputscancode 1c  2>&1 | xargs echo "[MSG]")

    # VM is created in a separate process
    # Wait for it to come to end
    # Test if still running every minute

    while test_vm_running ${VM}
    do
        logger -s "[MSG] ${VM} running. Disk size: " $(du -hal "${VM}.vdi")
        sleep 60
    done
    logger -s "[MSG] ${VM} has stopped"
    logger -s "[INF] Compacting VM..."
    logger -s <<< $(VBoxManage modifyhd "${VM}.vdi" --compact 2>&1 | xargs echo "[MSG]")
}

## @fn clonezilla_to_iso()
## @brief Create Gentoo linux clonezilla ISO installer out of a clonezilla
## directory structure and an clonezilla image.
## @param iso ISO output
## @param dir Directory to be transformed into ISO output
## @note ISO can be burned to DVD or used to create a bootable USB stick
## using dd on *nix platforms or Rufus (on Windows).
## @ingroup createInstaller

clonezilla_to_iso() {
    if ! [ -f "${VMPATH}/$2"/syslinux/isohdpfx.bin ]; then
         cp -vf ${VMPATH}/clonezilla/syslinux/isohdpfx.bin "${VMPATH}/$2"/syslinux
    fi
    xorriso -as mkisofs   -isohybrid-mbr "$2"/syslinux/isohdpfx.bin  \
            -c syslinux/boot.cat   -b syslinux/isolinux.bin   -no-emul-boot \
            -boot-load-size 4   -boot-info-table   -eltorito-alt-boot   -e boot/grub/efiboot.img \
            -no-emul-boot   -isohybrid-gpt-basdat   -o "$1"  "$2"
    if [ $? != 0 ]; then
        logger -s "[ERR] Could not create ISO image from ISO package creation directory"
        exit -1
    fi
}

## @fn process_clonezilla_iso()
## @brief Download clonezilla ISO or recover it from cache calling #fetch_clonezilla_iso. @n
## Upgrade it with virtualbox guest additions.
## @details Chroot into the clonezilla Ubuntu GNU/Linux distribution and runs apt to build
## kernel modules
## and install the VirtualBox guest additions ISO image. @n
## Upgrade clonezilla kernel consequently
## Recreates the quashfs system after exiting chroot.
## Copy the new \b isolinux.cfg parameter file: automates and silences clonezilla behaviour
## on disk recovery.
## Calls #clonezilla_to_iso
## @note Installing the guest additions is a prerequisite to folder sharing between the ISO VM
## and the host.
## Folder sharing is necessary to recover a compressed clonezilla image of the VDI virtual disk
## into the ISOFILES/home/partimag/image directory.
## @ingroup createInstaller

process_clonezilla_iso() {
    fetch_clonezilla_iso
    for i in proc sys dev run; do mount -B /$i squashfs-root/$i; done
    chroot squashfs-root
    mkdir -p  /boot
    apt update -yq
    apt upgrade -yq <<< $(echo N)
    local headers=$(apt-cache search ^linux-headers | tail -n1 | cut -f 1 -d' ')
    local kernel=$(apt-cache search ^linux-image | grep -v unsigned | tail -n1 | cut -f 1 -d' ')
    apt install -qy ${headers}
    apt install -qy ${kernel}
    apt install -qy build-essential gcc <<< "N"
    apt install -qy virtualbox-dkms
    apt install -qy virtualbox-guest-additions-iso
    mount -oloop /usr/share/virtualbox/VBoxGuestAdditions.iso /mnt
    cd /mnt
    /sbin/rcvboxadd quicksetup all
    /bin/bash VBoxLinuxAdditions.run
    cd /
    umount /mnt
    apt remove -y -q ${headers} build-essential gcc  virtualbox-guest-additions-iso
    apt autoremove -y -q
    exit
    cp -vf --dereference squashfs-root/boot/vmlinuz  vmlinuz
    cp -vf --dereference squashfs-root/boot/initrd.img  initrd.img
    rm -rf squashfs-root/boot
    rm -vf filesystem.squashfs
    for i in proc sys dev  run; do umount squashfs-root/$i; done
    mksquashfs squashfs-root filesystem.squashfs
    rm -rf squashfs-root/
    cd "${VMPATH}/mnt2"
    cp -vf ../clonezilla/savedisk/isolinux.cfg  syslinux
    cd "${VMPATH}"
    rm -vf ${CLONEZILLACD}
    clonezilla_to_iso ${CLONEZILLACD} "mnt2"
    rm -rf mnt2
}

## @fn build_virtualbox()
## @brief Build VirtualBox from source using an unsquashed clonezilla CD as a chrooted environment.
## @details Build scripts are copied from \b clonezilla/build
## @note This stage is only necessay if \b vbox-img is to be used to directly convert the
## VDI virtual disk into a block device, on account of a bug in Oracle source code (ticket #19901). @n
## This is only needed to reduce disk space requirements and avoid a temporary RAW file on disk of about 50 GB.
## Otherwise it is simpler to use the distribution stock version.
## @ingroup createInstaller

build_virtualbox() {
    cd ${VMPATH}
    cp -vf clonezilla/build/* ${CLONEZILLACD}/live
    cd ${CLONEZILLACD}/live
    ./build_virtualbox.sh
    cd ${VMPATH}
}

## @fn create_iso_vm()
## @brief Create the new VirtualBox machine aimed at converting the VDI virtualdisk containing the
## Gentoo Linux distribution into an XZ-compressed clonezilla image uneder \b ISOFILES/home/partimag/image
## @details
## @details Register machine, create VDI drive, create IDE drive attach disks to controlers @n
## Attach newly augmented clonezilla LiveCD to IDE controller. @n
## Wait for the VM to complete its task. Check that it is still running every minute. @n
## @note VM may be visible (vmtype=gui) or silent (vmtype=headless, currently to be fixed).
## Wait for the VM to complete task. @n
## A new VM is necessary as the first VM used to build the Gentoo filesystem does not contain clonezilla
## or the VirtualBox guest additions (requested for sharing folders with host).
## Calls #process_clonezilla_iso to satisfy these requirements.
## @warning the \b sharedfolder command may fail vith older version of VirtualBox or not be
## implemented. It is transient, so it disappears on shutdown and requests prior startup
## of VM to be activated.
## @ingroup createInstaller

create_iso_vm() {
    cd ${VMPATH}
    chown -R ${USER} .
    gpasswd -a ${USER} -g vboxusers
    chgrp vboxusers "ISOFILES/home/partimag/image"
    delete_vm ${ISOVM} "vdi"
    VBoxManage createvm --name "${ISOVM}" --ostype ubuntu_64  --register  --basefolder "${VMPATH}"
    VBoxManage modifyvm "${ISOVM}" --cpus ${NCPUS} --cpu-profile host --memory ${MEM} --vram 256 --ioapic on --usbxhci on --usbehci on
    VBoxManage storagectl "${ISOVM}" --name "SATA Controller" --add sata --bootable on

    # This to avoid issues with already-used vdis in debug tests

    VBoxManage internalcommands sethduuid "${ISOVM}.vdi"
    VBoxManage storageattach "${ISOVM}" --storagectl "SATA Controller"  --medium "${ISOVM}.vdi" --port 0 --device 0 --type hdd
    VBoxManage storagectl "${ISOVM}" --name "IDE Controller" --add ide
    VBoxManage storageattach "${ISOVM}" --storagectl "IDE Controller"  --port 0  --device 0   --type dvddrive --medium ${CLONEZILLACD}  --tempeject on
    VBoxManage storageattach "${ISOVM}" --storagectl "IDE Controller"  --port 0  --device 1   --type dvddrive --medium emptydrive
    VBoxManage startvm "${ISOVM}" --type ${VMTYPE}

    # must be running to work

    VBoxManage sharedfolder add "${ISOVM}" --name shared --hostpath "${VMPATH}/ISOFILES/home/partimag/image"  --automount --auto-mount-point "/home/partimag" --transient
    while [ test_vm_running ${ISOVM} ]; do
        logger -s "[MSG] ${ISOVM} running..."
        sleep 60
    done
}

## @fn clone_vm_to_device()
## @brief Directly clone Gentoo VM to USB stick (or any using block device)
## @warning Requests the \e patched version of \b vbox-img on account of
## Oracle source code bug (ticket #19901)
## @note Either build it beforehand or specify on commandline:
## @code build_virtualbox=true @endcode
## @ingroup createInstaller

clone_vm_to_device() {

    # Test whether USB_DEVICE is a mountpoint or a block device label

    USB_DEVICE=$(get_device ${USB_DEVICE})

    # Should not occur, only for paranoia

    [ -z "${USB_DEVICE}" ] && logger -s "[ERR] Could not set USB device ${USB_DEVICE}" && exit -1
    bin/vbox-img compact --filename "${VMPATH}/${VM}.vdi"
    bin/vbox-img convert --srcfilename "${VMPATH}/${VM}.vdi" \
                         --stdout \
                         --dstformat RAW | \
                         dd of=/dev/${USB_DEVICE} bs=4M status=progress
    [ $? = 0 ] && sync && return 0
    logger -s "[ERR] Could not convert dynamic virtual disk to raw USB device!"
    exit -1
}

## @fn clone_vm_to_raw()
## @brief Use @code VBoxManage clonemedium @endcode
## to clone VDI to RAW file before bare-metal copy to device.
## @ingroup createInstaller

clone_vm_to_raw() {
    VBoxManage clonemedium "${VMPATH}/${VM}.vdi" "${VMPATH}/tmpdisk.raw" --format RAW
}

## @fn dd_to_usb()
## @brief Bare-metal copy of temporary RAW disk to external device
## @note Used only if vbox-img (patched version) has not been built.
## @ingroup createInstaller

dd_to_usb() {
    "[INF] Bare metal copy of RAW disk to USB device..."

    # Test whether USB_DEVICE is a mountpoint or a block device label

    USB_DEVICE=$(get_device ${USB_DEVICE})

    # Should not occur, only for paranoia

    [ -z "${USB_DEVICE}" ] && logger -s "[ERR] Could not set USB device ${USB_DEVICE}" && exit -1
    dd if="${VMPATH}/tmpdisk.raw" of=/dev/${USB_DEVICE} bs=4M status=progress
    local res=$?
    if  ${res}
    then
        logger -s "[INF] Removing temporary RAW disk..."
        rm -f ${VMPATH}/tmpdisk.raw
    fi
    return ${res}
}

## @fn clonezilla_device_to_image()
## @brief Create CloneZilla xz-compressed image out of an external block device (like a USB stick)
## @details Image is created under ISOFILES/home/partimag/image under VMPATH
## @retval 0 on success otherwise exits -1 on failure
## @ingroup createInstaller

clonezilla_device_to_image() {
    find_ocs_sr=`which ocs-sr`
    if [ -z "$find_ocs_sr" ]
    then
        logger -s "[ERR] Could not find ocs_sr !"
        logger -s "[MSG] Install Clonezilla in a standard path or rerun after adding its parth to the PATH environment variable"
        logger -s "[MSG] Note: Debian-based distributions provide a handy `clonezilla` package."
        exit -1
    fi

    # At this stage USB_DEVICE can no longer be a mountpoint as it has been previously converted to device label

    findmnt /dev/${USB_DEVICE}  \
        && logger -s "[MSG] Device ${USB_DEVICE} is mounted to: $(get_mountpoint /dev/${USB_DEVICE})" \
        && logger -s "[WAR] The external USB device should not be mounted" \
        && logger -s "[INF] Trying to unmount..." &&  umount -l /dev/${USB_DEVICE}
    if  $?
    then
        logger -s "[MSG] Managed to unmount /dev/${USB_DEVICE}"
    else
        logger -s "[ERR] Could not manage to unmount external USB device"
        logger -s "[MSG] Unmount it manually and rerun."
        exit -1
    fi

    # double check

    [ `findmnt /dev/${USB_DEVICE}` ] && { logger -s "[ERR] Impossible to unmount device ${USB_DEVICE}"; exit -1; }
    if [ -d /home/partimag ]
    then
        logger -s "[WAR] /home/partimag needs to be wiped out..."
        logger -s "[INF] Trying with user rights..."
        rm -rf /home/partimag
        if [ $? != 0 ]
        then
            logger -s "[WAR] Directory /home/partimag needs elevated rights..."
            rm -rf /home/partimag
            [ $? != 0 ] && logger -s "[ERR] Could not fix /home/partimag issue." &&  exit -1
        fi
    fi
    if "${CLEANUP}"
    then
        logger -s "[INF] Erasing virtual disk and virtual machine to save disk space..."
        [ -f "${VMPATH}/${VM}.vdi" ] && rm -f "${VMPATH}/${VM}.vdi"
        [ -d "${VMPATH}/${VM}" ] && rm -rf "${VMPATH}/${VM}"
    fi
    rm -rf ISOFILES/home/partimag/image/*
    [ $? != 0 ] && { logger -s "[ERR] Could not remove old Clonezilla image"; exit -1; }
    ln -s  ${VMPATH}/ISOFILES/home/partimag/image  /home/partimag
    /usr/sbin/ocs-sr -q2 -c -j2 -nogui -batch -gm -gmf -noabo -z5 \
                     -i 40960000000 -fsck -senc -p poweroff savedisk gentoo.img ${USB_DEVICE}
    [ $? = 0 ] && [ -f /home/partimag/gentoo.img ] && logger -s "[MSG] Cloning succeeded!" \
        || { logger -s "[ERR] Cloning failed!"; exit -1; }
    return 0
}

## @fn vbox_img_works()
## @brief Test if \b vbox-img is functional
## @details \b vbox-img is a script; it refers to \b vbox-img.bin, which is a soft link to the VirtuaBox patched build.
## @retval 0 if vbox-img --version is non-empty
## @retval 1 otherwise
## @ingroup createInstaller

vbox_img_works() {
    cd ${VMPATH}

    # Using the custom-patched version of the vbox-img utility:

    [ -L bin/vbox-img.bin -a -f bin/vbox-img ] && vbox_version="$(bin/vbox-img --version)" \
	                                       && [ -n "${vbox_version}" ] && return 0
    return 1
}

## @fn create_usb_system()
## @brief Clone VDI virtual disk to external device (like a USB stick)
## @details Two options are available. If vbox-img (patched) is functional
## after building VirtualBox from source, then use it and clone VDI directly
## to external device. Otherwise create a temporary RAW file and bare-metal copy
## this file to external device.
## @retval In the first case, the exit code of #clone_vm_to_device
## @retval In the second case, the exit code of #dd_to_usb following #clone_vm_to_raw
## @ingroup createInstaller

create_usb_system() {
    { ! vbox_img_works || ${BUILD_VIRTUALBOX}; } && build_virtualbox
    if  vbox_img_works
    then
        logger -s "[INF] Cloning virtual disk to USB device ${USB_DEVICE} ..."
        clone_vm_to_device
        [ $? != 0 ] && logger -s "[ERR] Cloning VDI disk to USB deice failed !" && exit -1
    else
        logger -s "[INF] Cloning virtual disk to raw..."
        clone_vm_to_raw
        [ $? != 0 ] && logger -s "[ERR] Cloning VDI disk to RAW failed !" && exit -1
        logger -s "[INF] Copying to USB stick..."
        dd_to_usb
        if [ $? != 0 ]
        then
            logger -s "[INF] Copying raw file to USB device failed!"
            logger -s "[WAR] Check that your USB device has at least 50 GiB of reachable space"
            exit -1
        fi
    fi
}

## @fn cleanup()
## @brief Clean up all temporary files and directpries (except for VirtualBox build)
## @ingroup createInstaller

cleanup() {
    ! "${CLEANUP}" && return 0
    cd ${VMPATH}
    rm *.xz
    rm *.iso
    rm -rf ISOFILES
    [ -d mnt ]  && umount -l mnt && rmdir mnt
    [ -d mnt2 ] && rm -rf mnt2
    rm -rvf ${VM}
    rm -vf ${VM}.vdi
    return 0
}

## @fn generate_Gentoo()
## @brief Launch routines: fetch install IO, starge3 archive, create VM
## @ingroup createInstaller

generate_Gentoo() {
    logger -s "[INF] Fetching live CD..."
    fetch_livecd
    logger -s "[INF] Fetching stage3 tarball..."
    fetch_stage3
    logger -s "[INF] Tweaking live CD..."
    make_boot_from_livecd
    logger -s "[INF] Creating VM"
    if ! create_vm; then
        logger -s "[ERR] VM failed to be created!"
        exit -1
    fi

    # Now on to OS on external device

    if [ -n "${USB_DEVICE}" ]
    then
        logger -s "[INF] Creating OS on device ${USB_DEVICE}..."
        create_usb_system
    fi
}

## @fn main()
## @brief Main function launching routines
## @todo Daemonize the part below generate_Gentoo when #VMPTYPE is `headless`
## so that the script can be detached completely with `nohup mkgentoo ...  &`
## @ingroup createInstaller

main() {

# Help cases

grep -q 'help'    <<< "${CLI}" &&  help_ && exit 0
grep -q 'help_md' <<< "${CLI}" &&  help_md && exit 0

# Analyse commandline and source auxiliary files

test_cli_pre
for ((i=0; i<ARRAY_LENGTH; i++)) ; do test_cli $i; done
test_cli_post
cd ${VMPATH}
source scripts/fetch_clonezilla_iso.sh
source scripts/utils.sh

# if an Gentoo has already been built into an ISO image or on an external device
# skip generating it; otherwise go and build the Gentoo virtual machine

! "${FROM_VM}" && ! "${FROM_DEVICE}" && ! "${FROM_ISO}" && generate_Gentoo

# process the virtual disk into a clonezilla image

if [ -f "${VM}.vdi" ] && "${CREATE_ISO}"  && ! "${FROM_DEVICE}"
then
    # Now create a new VM from clonezilla ISO to retrieve
    # Gentoo filesystem from the VDI virtual disk.

    logger -s "[ERR] Adding VirtualBox Guest Additions to CloneZilla ISO VM..."
    "${VERBOSE}" && logger -s "[ERR] These are necessary to activate folder sharing."
    process_clonezilla_iso

    # And launch the corresponding VM

    logger -s "[ERR] Launching Clonezilla VM to convert virtual disk to clonezilla image..."
    create_iso_vm
fi

# Now convert the clonzilla xz image image into a bootable ISO

if ! "${FROM_ISO}"
then
    [ "${FROM_DEVICE}" = "true" ] && clonezilla_device_to_image
    logger -s "[ERR] Creating Clonezilla bootable ISO..."
    clonezilla_to_iso "${ISO_OUTPUT}" ISOFILES
    if $?
    then
        logger -s "[MSG] Done."
        [ -f "${ISO_OUTPUT}" ] && logger -s "[MSG] ISO install medium was created here: ${ISO_OUTPUT}"  \
                               || logger -s "[ERR] ISO install medium failed to be created."
    else
        logger -s "[ERR] ISO install medium failed to be created!"
        exit -1
    fi
fi
[ -n "${DEVICE_INSTALLER}" ] && create_install_usb_device
"${BURN}" &&  burn_iso
cleanup
exit 0
}

main
