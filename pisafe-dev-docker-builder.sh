#!/bin/bash
## pisafe-dev-docker-builder.sh
## This tool will automate building a docker container based on the latest Raspberry Pi OS.

## Okay I think I found a stupid simple way of doing this and I'm an idiot for not trying this first. Worth considering running this in a Docker container or throwaway since so there's so many new packages to be installed. Like 500. Yikes.
## First pull down the tools. 
sudo apt install libguestfs-tools xz-utils
## Now get the latest Raspberry Pi OS. I chose arm64-lite version.
wget https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2022-09-26/2022-09-22-raspios-bullseye-arm64-lite.img.xz
## And we decompress it.
xz -dv 2022-09-22-raspios-bullseye-arm64-lite.img.xz 
## This is going to mount both partitions of the image file and output them to a tarball
guestfish -a 2022-09-22-raspios-bullseye-arm64-lite.img -m /dev/sda2:/ -m /dev/sda1:/boot tar-out / raspios-bullseye-64
## Now we import into docker
sudo docker import raspios-bullseye-64 raspios-bullseye-64
## And we can run it as the 'pi' account!
sudo docker run -it -u pi raspios-bullseye-64 /bin/bash


## An older method that I never quite got to work
## Sources:
##  - https://docs.docker.com/develop/develop-images/baseimages/
##  - https://github.com/RPi-Distro/pi-gen/blob/c3083ecd503629eac5184ec692f65bbbd28ac317/scripts/common
##  - https://stackoverflow.com/questions/56563559/how-to-convert-img-to-a-docker-image - extremely helpful
#sudo debootstrap --arch armhf --components "main,contrib,non-free" --keyring "stage0/files/raspberrypi.gpg" --exclude=info --include=ca-certificates bullseye bullseye http://raspbian.raspberrypi.org/raspbian/
#sudo tar -C bullseye -c . | sudo docker import - bullseye
#sudo docker run -it bullseye /bin/bash
## For a 64-bit version use the following. NOTE, you'll have to download the 64-bit branch listed above.
## sudo debootstrap --arch arm64 --include gnupg --components "main,contrib,non-free" --exclude=info --include=ca-certificates bullseye ./bullseye64 http://deb.debian.org/debian/
## sudo tar -C bullseye64 -c . | sudo docker import - bullseye64
## sudo docker run -it bullseye64 /bin/bash

###### above this line runs on the host; below this line runs on the guest. Also the keyring file is dead since we haven't pulled down the repo. Which we could TOTALLY do and copy to the guest and start in the right directory. But um yeah I'm lazy tonight.

## This gets you into a bash shell. Now you'll install prerequisites and grab the RPi-Distro files.
#apt install -y git quilt parted qemu-user-static debootstrap zerofree zip dosfstools libarchive-tools rsync xz-utils curl file bc qemu-utils kpartx pigz 
#pushd /root || exit
#git clone https://github.com/RPI-Distro/pi-gen.git
## For a 64-bit version, replace the above with the following:
## git clone --branch arm64 https://github.com/RPI-Distro/pi-gen.git

#Now change into the right directory
#pushd /root/pi-gen || exit

## Create the 'config' file
#config_file="
#IMG_NAME='Raspbian-Development'
#\nDEPLOY_DIR='raspi-dev'
#\nTARGET_HOSTNAME='raspi-dev'
#"
#echo -e $config_file > config

#whiptail --msgbox --title "CRITICAL MANUAL STEPS" "Now you'll have to modify a couple of the scripts so that when the 'build.sh' script is run, it writes everything into the container rather than to a file. When you're ready for this, hit OK and I'll give you more instructions." 25 80
#whiptail --msgbox --title "CRITICAL MANUAL STEPS" "After you hit OK this time, you'll be dropped into an editor. Might want to screenshot this becuase it's not all that simple. Scroll down to the **on_chroot()** section and comment out every line EXCEPT THE LAST ONE. For the last line, detete the '"--chroot=\${ROOTFS_DIR}/"' part and leave the rest." 25 80
#nano scripts/common
#whiptail --msgbox --title "CRITICAL MANUAL STEPS" "After you hit OK this time, you'll be dropped into an editor again. Might want to screenshot this becuase it's not all that simple. Under run_stage(): \
#\n - Set ROOTFS_DIR=\"/\" and comment out the other ROOTFS_DIR line \
#\n - Comment out the line rm -rf \"\${ROOTFS_DIR}\" and add \'touch /root/pi-gen/config\' instead" 25 80
#nano build.sh

## Get rid of these because they install a lot of packages that are for Desktop images, which we don't care about. Unless you do, in which case comment out these lines.
#rm stage2/01-sys-tweaks/00-packages-nr
#rm -rf stage3
#rm -rf stage4
#rm -rf stage5
#rm -rf export-image
#rm -rf export-noobs
#mkdir export-image
#mkdir export-noobs

## Instruct 'pi-gen' to skip stages 3-5 (mostly GUIs and such)
#touch ./export-image/SKIP ./export-noobs/SKIP
#touch ./stage0/SKIP_IMAGES ./stage1/SKIP_IMAGES ./stage2/SKIP_IMAGES

## Keep getting errors in some files so until I can figure out how to avoid those, gotta nuke 'em
#rm -rf stage2/01-sys-tweaks/00-patches
#rm -rf stage1/01-sys-tweaks/00-patches
#rm stage2/03-set-timezone/02-run.sh

## Now go!!
#./build.sh