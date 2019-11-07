# Quantar_v.24_to_RS232

Importatnt: Project is not finished yet, I am working on a bug that corrupts some frames from Async to Sync with high data rates (Voice).

Quantar v.24 Sync to/from Async card.

This is the sourcecode for the Microchip PIC 16F887 inside the v.24 board created by Juan Carlos Perez KM4NNO.
This board converts Sync to Async HDLC and Async to Sync HDLC.
Quantar needs to be the master clock.

Buffer from Sync to Async is unlimited.
Buffer from Async to Sync is limited to 32 bytes for now (it will be increased to ~90).


To use the QuantarNetwork program copy QuantarNetwork.pl and congfig.ini Speech.ini to a folder, update the config.ini file with your callsign and IP address, and install the required Perl libraries using the follownig commands:

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


This software and hardware is licenced under the GPL v3. If you are using it, please let me know.

