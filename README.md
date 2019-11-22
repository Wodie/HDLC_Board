# Quantar_v.24_to_RS232

Importatnt: Project is under development.

Quantar v.24 Sync to/from Async card.

This is the sourcecode for the Microchip PIC 16F887 inside the v.24 board created by Juan Carlos Perez KM4NNO.
This board converts Sync to Async HDLC and Async to Sync HDLC.
Quantar/DIU3000 needs to be the master clock (set them to internal clock).

Buffer from Sync to Async is unlimited.
Buffer from Async to Sync is limited to 120 bytes, but need testing.


To use the QuantarNetwork program copy QuantarNetwork.pl, congfig.ini, and Speech.ini to a folder, update the config.ini file with your callsign and IP address, etc and install the required Perl libraries using the follownig commands:

sudo cpan

install Switch

install IO::Socket

install IO::Socket::Multicast

install Config::IniFiles

install Digest::CRC

install Device::SerialPort

exit
 
To make an exe file:
sudo chmod +x QuantarNetwork.pl

sudo cpan -i PAR::Packer

pp -o QuantarNetwork.exe QuantarNetwork.pl


This software and hardware is licenced under the GPL v3. If you are using it, please let me know, I will be glad to know it.

