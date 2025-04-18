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
https://github.com/vyos/vyos-1x/blob/current/src/op_mode/image_installer.py

Its path in the VyOS system is:
/usr/libexec/vyos/op_mode/image_installer.py

