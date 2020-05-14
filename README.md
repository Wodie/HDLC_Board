# Quantar_P25Link

Importatnt: this is a work in progress project, so features might not work on every update.

# Quantar v.24 Sync to/from Async card.

This is the sourcecode for the Microchip PICs 15F887 or 16F884 for the v.24 board created by Juan Carlos Perez KM4NNO.
This board converts Sync to Async HDLC and Async to Sync HDLC.
Quantar/DIU3000 needs to be the master clock (set them to internal clock).

Buffer from Sync to Async is unlimited.
Buffer from Async to Sync is limited to 120/112 bytes, but need testing.


To use the p25nx_v2.x.x program copy p25nx_v2.x.x.pl, congfig.ini, , hosts.txt, and Speech.ini to a folder.

Update the config.ini file with your callsign and IP address, etc. Mode = 0 means Serial, Mode = 1 means Cisco STUN (work in progress, not working).

Modify the hosts.txt file with the Talk Groups you want lo add to the Scan list by setting the last field to a highest take precedence >= 1. 0 = No Scan.

Install the required Perl libraries using the follownig commands:

sudo cpan

install Switch

install IO::Socket

install IO::Socket::Multicast

install Config::IniFiles

install Digest::CRC

install Device::SerialPort

install Term::ReadKey

exit
 
To make an exe file:
sudo chmod +x p25nx_v2.0.13.pl

sudo cpan -i PAR::Packer

pp -o p25nx.exe p25nx_v2.0.13.pl


This software and hardware is licenced under the GPL v3. If you are using it, please let me know, I will be glad to know it.

