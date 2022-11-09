#!/bin/bash

####################
## newbuild.sh
## (c) Beau Woods 2022
## Script for building a new system, to be run after it's first imaged.
####################

####################
## Laying the groundwork
####################
## Create a log file for status updates and errors, and point 'stdout' and 'stderr' there, while also sending 'stdout' to the console to provide status
output_log=~/pisafe.log
touch $output_log
#exec 1&>>$output_log 2>>$output_log
#exec &>>$output_log

## Update and install some new packages (if any)
#sudo apt update && apt upgrade -y 

## Establish a few of the variables we will need
date_h=$(date) # Date and time, in human-readable format
script_name="pisafe-install.sh"

## Start a progress log
printf "Output from %s script, run %s\n" "$script_name", "$date_h"

## Get some input.
printf "\n\nReconfiguring your SSH instance for greater security"
read -p "\nEnter your SSH key: " ssh_key
read -p "\nProvide a name for the SSH key to help identify it: " ssh_key_name
read -p "\nWhat port do you want SSH to run on [default is 22]: " ssh_port

####################
## 1. Prompt for password change (if null)
####################
## This will iterate through all of the accounts and prompt to change any for which the password is empty.
sudo awk -F: '$2 == "" { 
    printf $1, "has an empty password.";
    sudo passwd $1;
}' /etc/shadow

####################
## 2. SSH Tasks
####################
## 2a. Import SSH key - Test if the '.ssh' folder exists in the account root and, if not, create it, backup the existing 'authorized_keys' file, then place the key into the 'authorized_keys' file, with a comment on source and date.

printf "\n.....\nWorking: 2a. Import SSH key\n"
if test ! -d ~/.ssh
then 
    mkdir ~/.ssh
fi
cp ~/.ssh/authorized_keys ~/.ssh/authorized_keys.backup
printf "\n# $ssh_key_name, added %s \n$ssh_key\n\n" "$date_h" >> ~/.ssh/authorized_keys
printf "Completed: 2a. Import SSH key\n.....\n"

##
## 2b. Harden sshd config - Increase security for sshd in a couple of different ways. Change from the standard port 22 to a non-standard one to cut down on network noise a little bit. This may provide _some_ additional security through obfuscation, particularly against low-capability adversaries. Disable password authentication and interactive logins. This restricts access to public key-based mechanisms which are _much_ stronger than password-based ones.
printf "\n.....\nWorking: 2b. Harden sshd config\n"
if test -d /etc/ssh/sshd_config.d
then
     printf "\n# sshd server configuration file created with %s\n#\nPort $ssh_port\nPermitRootLogin no\nPubkeyAuthentication yes\nAuthorizedKeysFile     .ssh/authorized_keys\nPasswordAuthentication no\nKbdInteractiveAuthentication no\n\n" $script_name | sudo tee -a /etc/ssh/sshd_config.d/99-newbuild.conf > /dev/null # Corrected by https://www.shellcheck.net/wiki/SC2024
fi
printf "\n.....\nCompleted: 2b. Harden sshd config\n"
##
## 2c. Enable sshd - Load sshd automatically every time the server restarts
sudo systemctl enable sshd

####################
## 3. Install Tailscale
####################
## Tailscale is rad. This will install the software and add packages so it can be kept updated.
printf "\n.....\nWorking: 3. Install Tailscale\n"
curl -fsSL https://tailscale.com/install.sh | sh

#sudo tailscale up "$tailscale_exit_node" "$tailscale_ssh"
printf ".....\nCompleted: 3. Install Tailscale\n"

####################
## 4. Software updates
####################
## 4b. Install unattended-upgrades - OK, so the 'unattended-upgrades' package is great, in theory. But it's kinda broken out of the box, which is dumb. So we're going to install it and then write some config files so it does what it should have done from the start.
printf "\n.....\nWorking: 4b. Install unattended-upgrades\n"
sudo apt install unattended-upgrades
if test -d /etc/apt/apt.conf.d/50unattended-upgrades
then
     printf "\n# Line added by %s\nUnattended-Upgrade::Automatic-Reboot \"true\";\n\n" $script_name | sudo tee -a /etc/apt/apt.conf.d/50unattended-upgrades > /dev/null # Corrected by https://www.shellcheck.net/wiki/SC2024
fi
sudo systemctl reload unattended-upgrades.service 
printf "\n.....\nCompleted: 2b. Install unattended-upgrades\n"











## Send exit message to the console
printf "\nAlright, we're done here! Did we have fun today? That's good.\n"
printf "I've cleaned up what I can here, but you may have to do some on your own.\n" 
printf " - Restart sshd (this will boot you from any current sshd sessions).\n"
printf " - Reboot, if any of the updates said you'll need to.\n"
printf " - Be sure to check the logfile at %s for more details.\n" "$output_log"
printf "\n"
printf "Okay, now to fire up Tailscale and send you on your way!\n"

## Fire up Tailscale!
while true; do
    read -p "\n\nDo you want this host to be a Tailscale exit node [y/N]? " yn
    case $yn in
        [Yy]* ) printf "\nThis host will be able to route network traffic from other Tailscale nodes. Complete this choice in the Tailscale Machines configuration page. https://login.tailscale.com/admin/machines\n";
            tailscale_exit_node="--advertise-exit-node"; # Enable the command line option
            echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf; # Configure network traffic forwarding
            echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.conf; # Configure network traffic forwarding
            sudo sysctl -p /etc/sysctl.conf; # Load the updated 'sysctl.conf' file
            break;;
        * ) printf "\nThis host will NOT route network traffic from other Tailscale nodes.\n"; tailscale_exit_node='' break;; # Ensure the command line option is unset
    esac
done

while true; do
    read -p "\n\nDo you want this host to be accessible through Tailscale SSH [y/N]? " yn
    case $yn in
        [Yy]* ) printf "\nThis host will be accessible through Tailscale SSH. For more information, see the documentation. https://tailscale.com/kb/1193/tailscale-ssh/\n"; tailscale_ssh="--ssh"; break;; # Enable the command line option
        * ) printf "\nThis host will NOT be accessible through Tailscale SSH.\n"; tailscale_ssh='' break;; # Ensure the command line option is unset
    esac
done
