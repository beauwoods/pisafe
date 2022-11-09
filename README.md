## pisafe
A script to configure a newly installed Raspberry Pi (or other similar *nix distro) with a few common, helpful security tools and steps.

### why
Very small companies that deal with very big ones have to show that they have some security in place. This script sets up some baseline capabilities on a new system to do that more quickly and easily, in an automated/consistent way.

### what
The script does (or will do?) a number of things.
- 1. Prompt for password change (if null)
- 2. SSH
  - a. Import SSH key
  - b. Secure sshd config
  - c. Enable sshd
- 3. Install and configure Tailscale
- 4. Software updates
  - a. Apt Update && Upgrade
  - b. Install and configure unattended-upgrades

### to do
It's not there yet.
- Finish out all of the tasks
- Clean up the scripts
- Figure out what to do on errors. Some might stop the process, some might just dump a log and flag that an error happened.
- Send stdout to a logfile and give pretty updates on the console, pihole style
- Eventually it would be nice to parse the config files and ensure the values are what we want them to be. But that's not going to happen today.
- Front-end all of the question asking and store as variables
- Use whiptail (or similar) for interactive dialogs
- Allow CLI inputs for automated deployment
- Have a flag that will generate the CLI command for automated deployment (see above)
- Determine the right flavor and version, in case something breaks on other variants (like OpenWRT)
- Check to see if any pieces are already installed and do something about it (error out, or reconfigure, or whatever)
- Move software updates to the first thing we do?
- Add more tools
  - Protective DNS (pihole or AdGuard Home or NextDNS with a good back-end DNS server and DNSSEC or DOH)
  - Network vulnerability scanner (nmap or Nessus)
  - Local vulnerability scanner (cvescan)
  - Regular email updates/logs
  
Some reference scripts that can help
- https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh
- https://tailscale.com/install.sh
- https://github.com/RPi-Distro/raspi-config/blob/master/raspi-config
- https://raw.githubusercontent.com/pi-hole/pi-hole/master/automated%20install/basic-install.sh

### license
This script is licensed as GPL 3.0, though I'm open to other options.
