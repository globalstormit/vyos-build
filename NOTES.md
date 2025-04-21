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

We should modify this into our own. 
Some observations:
  - The config_boot_list has 2 hardcoded options
  - VyOS includes python 3.11
  - Its python includes the jinja2 package
  - the 'vyos' python package is @ /usr/lib/python3/dist-packages/vyos/

What we should do:
  - Create our own image_installer.py
  - At the config selection (line ~828) we will detect interfaces
    - python code to do that:
      from vyos.ifconfig import Section
      a = Section.interfaces(section='ethernet')
      print(a)
    - just use Section.interfaces() to list all interfaces (may be useful if configuring an LTE router)
    - it returns a list like:
      ['eth0', 'lo']
  - Once detected we will ask the user to specify WAN / LAN interfaces
    - eventually we can maybe do an autodetect if we can use DHCP on the interfaces at this point
  - Then we ask the user to specify LAN defaults (IP/subnet/DHCP)
  - Generate the config once we have all the required inputs

To set up our own python packages path:
  - use the path /opt/gsit/py
  - add the path to /etc/environment



DHCP interface scanner script:
-------------------------------------------------------------------------------------------

#!/usr/bin/env python3
#
# DHCP Scanner for VyOS
# Scans Ethernet interfaces for DHCP connectivity
#

import os
import sys
import time
import json
from typing import Dict, List, Optional
import threading

# Add VyOS modules to the path
sys.path.append('/usr/lib/python3/dist-packages')

from vyos.ifconfig import Section
from vyos.ifconfig import Interface
from vyos.utils.process import cmd
from vyos.utils.network import get_interface_address

def check_dhcp_status(ifname: str, timeout: int = 30) -> Dict:
    """
    Check if DHCP is successful on an interface
    Returns a dictionary with status information
    """
    result = {
        'ifname': ifname,
        'dhcp_enabled': False,
        'has_ip': False,
        'ip_address': None,
        'subnet': None,
        'original_state': None,
        'error': None
    }
    
    try:
        # Create interface object
        interface = Interface(ifname, create=False)
        
        # Save original state to restore later
        result['original_state'] = interface.get_admin_state()
        
        # Ensure interface is up
        if result['original_state'] != 'up':
            interface.set_admin_state('up')
            time.sleep(1)  # Give the interface time to come up
        
        # Start DHCP client
        print(f"Enabling DHCP on {ifname}...")
        interface.set_dhcp(True)
        result['dhcp_enabled'] = True
        
        # Wait for DHCP to get an address
        print(f"Waiting up to {timeout} seconds for DHCP on {ifname}...")
        start_time = time.time()
        while (time.time() - start_time) < timeout:
            # Check if interface has an IP address
            addr_info = get_interface_address(ifname)
            if addr_info and 'addr_info' in addr_info:
                for addr in addr_info['addr_info']:
                    if addr['family'] == 'inet' and 'dynamic' in addr:
                        result['has_ip'] = True
                        result['ip_address'] = addr['local']
                        result['subnet'] = addr['prefixlen']
                        return result
            
            # Wait a bit before checking again
            time.sleep(2)
        
        return result
            
    except Exception as e:
        result['error'] = str(e)
        return result
    finally:
        # Clean up - disable DHCP and restore original state
        try:
            # Disable DHCP
            if result['dhcp_enabled']:
                interface = Interface(ifname, create=False)
                interface.set_dhcp(False)
            
            # Restore original admin state
            if result['original_state'] and result['original_state'] != interface.get_admin_state():
                interface.set_admin_state(result['original_state'])
        except:
            # If cleanup fails, we still want to continue with other interfaces
            pass

def scan_interfaces(timeout_per_interface: int = 30) -> List[Dict]:
    """
    Scan all Ethernet interfaces for DHCP
    Returns a list of dictionaries with status information
    """
    # Get list of Ethernet interfaces
    ethernet_interfaces = Section.interfaces('ethernet')
    results = []
    
    print(f"Found {len(ethernet_interfaces)} Ethernet interfaces")
    
    # Process each interface in parallel using threads
    threads = []
    for ifname in ethernet_interfaces:
        thread = threading.Thread(target=lambda i, r: r.append(check_dhcp_status(i, timeout_per_interface)), 
                                 args=(ifname, results))
        threads.append(thread)
        thread.start()
    
    # Wait for all threads to complete
    for thread in threads:
        thread.join()
    
    return results

def display_results(results: List[Dict]) -> None:
    """
    Display scan results in a formatted way
    """
    print("\n=== DHCP Scanner Results ===")
    print("-" * 80)
    print(f"{'Interface':<10} {'IP Address':<16} {'Subnet':<8} {'Status':<30}")
    print("-" * 80)
    
    success_count = 0
    
    for result in sorted(results, key=lambda x: x['ifname']):
        status = "✅ DHCP Address Obtained" if result['has_ip'] else "❌ No DHCP Address"
        if result['error']:
            status = f"⚠️ Error: {result['error']}"
        
        ip_addr = result['ip_address'] if result['ip_address'] else 'N/A'
        subnet = f"/{result['subnet']}" if result['subnet'] else 'N/A'
        
        print(f"{result['ifname']:<10} {ip_addr:<16} {subnet:<8} {status:<30}")
        
        if result['has_ip']:
            success_count += 1
    
    print("-" * 80)
    print(f"Summary: Found DHCP on {success_count} of {len(results)} interfaces")
    print("=" * 80)

def main():
    """
    Main function
    """
    print("VyOS DHCP Scanner")
    print("This tool will scan your Ethernet interfaces for DHCP servers.")
    print("It will temporarily enable DHCP on each interface to detect configuration.")
    print()
    
    # Default timeout per interface
    timeout = 15
    
    # Check args for different timeout
    if len(sys.argv) > 1:
        try:
            timeout = int(sys.argv[1])
        except ValueError:
            print(f"Invalid timeout value: {sys.argv[1]}, using default {timeout} seconds")
    
    print(f"Using {timeout} second timeout per interface")
    
    # Scan interfaces
    results = scan_interfaces(timeout)
    
    # Display results
    display_results(results)
    
    # Suggest next steps
    working_interfaces = [r['ifname'] for r in results if r['has_ip']]
    
    if working_interfaces:
        print("\nNext steps:")
        print("To permanently configure an interface with DHCP, use the VyOS CLI:")
        for ifname in working_interfaces:
            print(f"  configure")
            print(f"  set interfaces ethernet {ifname} address 'dhcp'")
            print(f"  commit")
            print(f"  save")
            break  # Just show example for the first working interface
    
if __name__ == "__main__":
    # Ensure the script is run with root privileges
    if os.geteuid() != 0:
        print("This script must be run with root privileges.")
        print("Please use 'sudo' or run as root.")
        sys.exit(1)
    
    main()


----------------------------------------------------------------------------------------