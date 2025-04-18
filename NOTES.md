** Objective

Create a more streamlined VyOS install process 
minimize required user input
Generate a useful-out-of-the-box configuration:
  - Auto configure WAN:
    - Intended to be connected to a local LAN during initial setup. Security is not important at this stage
    - Auto detect interfaces
    - Manually or automatically specify WAN interface (kinda like pfsense does)
    - use DHCP to get IP 
    - configure the default route / default gateway
    - configure DNS based on recieved DHCP
  - Auto configure LAN:
    - set a LAN IP / subnet
    - configure DHCP server
    - configure DNS forward address
  - enable SSH on both interfaces @ a specified port

We will generate configuration from a template. Will require vars:
  - WAN interface name (eth0 etc)
  - LAN interface name (eth1 etc)
  - LAN interface IP
  - LAN interface subnet
  - LAN interface DHCP start
  - LAN interface DHCP end
  - SSH port


** How do do this?

The install script is part of the vyos-1x package:
  - https://github.com/vyos/vyos-1x/blob/current/src/op_mode/image_installer.py

Its path in the VyOS system is:
  - /usr/libexec/vyos/op_mode/image_installer.py

We should modify this into our own. Some observations:
  - The config_boot_list has 2 hardcoded options
  - VyOS includes python 3.11
  - Its python includes the jinja2 package

What we should do:
  - Create our own image_installer.py
  - At the config selection (line ~828) we will detect interfaces
  - Once detected we will ask the user to specify WAN / LAN interfaces
    - eventually we can maybe do an autodetect if we can use DHCP on the interfaces at this point
  - Then we ask the user to specify LAN defaults (IP/subnet/DHCP)
  - Generate the config once we have all the required inputs