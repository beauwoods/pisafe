#!/bin/bash

####################
## pisafe.sh
## (c) Beau Woods 2023
## Script for building a new system, to be run after it's first imaged.
####################

####################
## 0. Laying the groundwork
####################
# Exit when any command fails, printing a message to STDOUT when doing so.
set -e # Set the script to exit on any failures, to avoid partial installs or clobbering exiting configs
script_exit_normal=false # Set a flag to clarify that the script exited abnormally, until resetting it to true just before the script ends.
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG # Keep track of the last executed command
trap 'if [[ $script_exit_normal != true ]]; then echo "XXXXXXXXXXFailure when running \"${last_command}\" with exit code $?."; fi' EXIT # On script exit, echo an error message

## Establish the preliminary variables
script_name="pisafe" # What are we calling this script?
script_file_name="$script_name-install.sh" # What do we expect the filename to be?
output_log="$HOME/$script_name.log" # Create a log file for status updates and errors

# Check if we can execute commands with sudo without a password
if ! sudo -ln &> /dev/null; then
    echo "This script requires sudo access to run. Please ensure you have sudo privileges."
    exit 1
fi

if ! command -v curl &> /dev/null; then
    echo "Error: curl is required but it's not installed. Please install curl and try again."
    exit 1
fi

##########
## Functions
##########

## find_window_manager() - Determine which window manager to use. 
find_window_manager() {
    window=$(which whiptail dialog 2> /dev/null | head -n 1) # Check whether whiptail or dialog is installed, assign the first one found to '$window'
    if [[ -n "$window" ]]; then
        echo "$window"
    else
        echo 'Error: Neither whiptail nor dialog found' >&2 If neither whiptail or dialog is installed, throw an error.
        exit 1
    fi
}

## configure_ssh() - Gather configuration details for harening the ssh server
configure_ssh() {
    $window --msgbox --title "SSH information gathering" "The SSH service allows for remote administration in a highly secureable manner. This script will collect information and make the configuration changes necessary to: \
        \n  1. Enable certificate-based authentication \
        \n  2. Disable password-based authentication \
        \n  3. Change the SSH port" 25 80 

    ## First, set 'ssh_key' to a non-null, invalid key value. Then while it's not valid and not null, iterate over this dialog until it's entered correctly. We first initialize the 'ssh_key' variable, then show the dialog until EITHER the variable is NULL (input is blank, indicating a desire to avoid doing anything) or we receive a valid SSH public key, as verified by ssh-keygen.
    ssh_key="variable initialization" # Set this to a STRING that is not a valid SSH key
    # Initialize a flag to track SSH key validity
    valid_ssh_key=1

    # Loop until a valid SSH key is entered or the user chooses to skip
    while [ $valid_ssh_key -ne 0 ]; do
        ssh_key=$($window --inputbox "Enter your SSH public key. SSH keys are strong access credentials. Learn more at: https://www.ssh.com/academy/ssh-keys\nLeave the field blank to skip." --title "SSH Public Key" 25 80 3>&1 1>&2 2>&3)
        
        # Check if the user chose to skip by entering an empty key
        if [ -z "$ssh_key" ]; then
            echo "No SSH key entered. Skipping SSH key setup."
            break # Exit the loop and skip SSH key setup
        fi

        # Test the entered SSH key for validity
        echo "$ssh_key" | ssh-keygen -lf - &>/dev/null
        valid_ssh_key=$?
        
        if [ $valid_ssh_key -eq 0 ]; then
            # The SSH key is valid; proceed with disabling password authentication
            $window --title "Disable SSH Password Authentication" --yesno "Would you like to disable password authentication for SSH? This is recommended for increased security if you set up SSH keys." 10 60
            
            passwordAuthentication="yes"
            if [ $? -eq 0 ]; then
                # User chose to disable password authentication
                passwordAuthentication="no"
            fi
        else
            # The SSH key is invalid; inform the user and loop again
            $window --msgbox "The SSH key you entered is invalid. Please try again." --title "Invalid SSH Key" 10 60
            # Optionally reset variables if needed
        fi
    done

# Create a dialog box to prompt for the SSH port. If the port is invalid (not between 1-65535) then show an error message and prompt again. If the port is valid, then set the variable 'ssh_port' to the value entered. If the port is NULL, then set the variable 'ssh_port' to the default value of 22.
    ssh_port="0" # Set this to an invalid SSH port so the loop below will trigger
    until [ "$ssh_port" -ge 1 ] && [ "$ssh_port" -le 65535 ] || [ -z "$ssh_port" ] 
    do
        ssh_port=$($window --inputbox "Enter the port you want to use for SSH. The default port is 22. \
        \n" --title "Gathering SSH port" 25 80 3>&1 1>&2 2>&3)
    done

} # End configure_ssh()

configure_tailscale() {
    # Tailscale exit node configuration
    $window --title "Tailscale Exit Node" --yesno "Do you want this host to be a Tailscale exit node?" 10 60

    if [ $? -eq 0 ]; then # Yes
        printf "\nThis host will be able to route network traffic from other Tailscale nodes. Complete this choice in the Tailscale Machines configuration page. https://login.tailscale.com/admin/machines\n"
        tailscale_exit_node="--advertise-exit-node"
        echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf
        echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.conf
        sudo sysctl -p /etc/sysctl.conf
    else # No
        printf "\nThis host will NOT route network traffic from other Tailscale nodes.\n"
        tailscale_exit_node=''
    fi

    # Tailscale SSH accessibility configuration
    $window --title "Tailscale SSH Access" --yesno "Do you want this host to be accessible through Tailscale SSH?" 10 60

    if [ $? -eq 0 ]; then # Yes
        printf "\nThis host will be accessible through Tailscale SSH. For more information, see the documentation. https://tailscale.com/kb/1193/tailscale-ssh/\n"
        tailscale_ssh="--ssh"
    else # No
        printf "\nThis host will NOT be accessible through Tailscale SSH.\n"
        tailscale_ssh=''
    fi

    # Ask whether to start Tailscale
    $window --title "Start Tailscale" --yesno "Do you want to start Tailscale now?" 8 50

    if [ $? -eq 0 ]; then
        # Commands to start Tailscale
        echo "Starting Tailscale..."
        tailscale up "$tailscale_exit_node" "$tailscale_ssh"
        $window --msgbox "Tailscale has been started." 8 50
    else
        $window --msgbox "Tailscale has not been started. You can start it manually later." 8 50
    fi
}

## Set up the logfile and dump some information into it to get us started
printf "==========Output from the \"%s\" script, run as %s on %s\n" "$script_name" "$last_command" "$(date)" > $output_log # Start the logfile, overwriting any file that existed before
printf "==========Figuring out which window manager we have access to - whiptail or dialog\n"
window=$(find_window_manager) # Set the window manager to 'whiptail' or 'dialog' or exit if neither exist
printf "==========Window manager is set to %s\n" "$window" >> $output_log

## INTRODUCTORY DIALOG
## Let people know what the script is, what it does, and what it needs from them
printf "==========Starting INTRODUCTORY DIALOG at %s\n" "$(date)" >> "$output_log"
$window --msgbox --title "Installing $script_name" "$script_name facilitates a more secureable deployment for a Raspberry Pi (or other Linux distros), including the following steps: \
    \n  1. Set passwords for any accounts that don't currently have them \
    \n  2. Harden SSH \
    \n  3. Install and configure Tailscale \
    \n  4. Configure software updates and unattended upgrades \
    \n \
    \n First we need to get some additional information." 25 80 # Generate a dialog box to provide an overview of what the script does
printf "==========Exited INTRODUCTORY DIALOG at %s\n" "$(date)" >> "$output_log"

## Get all the input we need so everything else can just install smoothly.
## First, find out what services are to be installed and configured.


####################
## 1. Prompt for password change (if null)
####################
## This will iterate through all of the accounts and prompt to change any for which the password is empty.
printf "==========Starting PASSWORD CHANGE at %s\n" "$(date)" >> "$output_log" # Start the logfile, overwriting any file that existed before
for account in $(getent shadow | grep '^[^:]*::' | cut -d: -f1) # For each account that has a blank password,
do
    $window --msgbox --title "Change blank password" "The account \"$account\" has a blank password. You will be prompted to change it on the next screen." 25 80; # Generate a dialog box to let the person running the script that they'll need to enter their password
    sudo passwd "$account"; # Change the password for the account
done
printf "==========Exited PASSWORD CHANGE at %s\n" "$(date)" >> "$output_log"


####################
## 2. SSH Tasks
####################
## Call the configure_ssh function to gather the necessary information for hardening the SSH server.
configure_ssh

## 2a. Import SSH key - Test if the '.ssh' folder exists in the account root and, if not, create it, backup the existing 'authorized_keys' file, then place the key into the 'authorized_keys' file, with a comment on source and date.
printf "\n.....\nWorking: 2a. Import SSH key\n"
if [ ! -d ~/.ssh ]; then # If the .ssh folder doesn't exist,
    mkdir ~/.ssh # Create it
fi
if [ -f ~/.ssh/authorized_keys ]; then # If the authorized_keys file exists,
    cp ~/.ssh/authorized_keys ~/.ssh/authorized_keys.$script_name.backup # Backup the existing authorized_keys file
fi
# Then proceed to add the key to the authorized_keys file
printf "\n\n# %s, added %s \n%s\n\n" "$(date)" "$ssh_key_name" "$ssh_key" >> ~/.ssh/authorized_keys
printf "Completed: 2a. Import SSH key\n.....\n"

##
## 2b. Harden sshd config - Increase security for sshd in a couple of different ways. 
## - Change from the standard port 22 to a non-standard one to cut down on network noise a little bit. This may provide _some_ additional security through obfuscation, particularly against low-capability adversaries. 
## - Disable password authentication and interactive logins. This restricts access to public key-based mechanisms which are _much_ stronger than password-based ones.
printf "\n.....\nWorking: 2b. Harden sshd config\n"
if test -d /etc/ssh/sshd_config.d # If the sshd_config.d folder exists,
then
     { printf \
        "\n# sshd server configuration file created with %s \
        \nPort %s \
        \nPermitRootLogin no \
        \nPubkeyAuthentication yes \
        \nAuthorizedKeysFile .ssh/authorized_keys \
        \nPasswordAuthentication %s \
        \nKbdInteractiveAuthentication no\n\n" \
        "$script_file_name" "$ssh_port" "$passwordAuthentication"; } \
    | sudo tee -a /etc/ssh/sshd_config.d/99-$script_name.conf > /dev/null # Add the config to the sshd_config.d folder
fi

printf "\n.....\nCompleted: 2b. Harden sshd config\n"
##
## 2c. Enable sshd - Load sshd automatically every time the server restarts
sudo systemctl enable ssh

####################
## 3. Install Tailscale
####################
## Tailscale is rad. This will install the software and add packages so it can be kept updated.
printf "\n.....\nWorking: 3. Install Tailscale\n"
curl -fsSL https://tailscale.com/install.sh | sh

configure_tailscale

#sudo tailscale up "$tailscale_exit_node" "$tailscale_ssh"
printf ".....\nCompleted: 3. Install Tailscale\n"

####################
## 4. Software updates
####################
## 4. Install unattended-upgrades - OK, so the 'unattended-upgrades' package is great, in theory. But it's kinda broken out of the box, which is dumb. So we're going to install it and then write some config files so it does what it should have done from the start.
printf "\n.....\nWorking: 4. Install unattended-upgrades\n"
sudo apt install unattended-upgrades
if test -d /etc/apt/apt.conf.d/50unattended-upgrades
then
     printf "\n# Line added by %s\nUnattended-Upgrade::Automatic-Reboot \"true\";\n\n" $script_file_name | sudo tee -a /etc/apt/apt.conf.d/50unattended-upgrades > /dev/null 
fi
sudo systemctl restart unattended-upgrades.service 
printf "\n.....\nCompleted: 4. Install unattended-upgrades\n"

# Final message before asking to start Tailscale
$window --msgbox "Alright, we're done here! Did we have fun today? That's good.\n\nI've cleaned up what I can here, but you may have to do some on your own.\n - Restart sshd (this will boot you from any current sshd sessions).\n - Reboot, if any of the updates said you'll need to.\n - Be sure to check the logfile at $output_log for more details.\n\nOkay, now to fire up Tailscale and send you on your way!" 20 70

## Send exit message to the console
script_exit_normal=true # Set the flag to indicate that the script exited normally