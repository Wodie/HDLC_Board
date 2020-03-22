#!/usr/bin/perl
#
#
# Strict and warnings recommended.
use strict;
use warnings;
use IO::Select;
use Switch;
use Config::IniFiles;
use Digest::CRC; # For HDLC.
use Device::SerialPort;
use IO::Socket;
use IO::Socket::INET;
use IO::Socket::Multicast;
use Class::Struct;
use Time::HiRes qw(nanosleep);
#use RPi::Pin;
#use RPi::Const qw(:all);


# About Message.
print "QuantarNet v3.0.0\n";
print "Released: December 01, 2019. Created October 17, 2019.\n";
print "Created by:\n";
print "Juan Carlos Pérez De Castro (Wodie) KM4NNO / XE1F\n";
print "Bryan Fields W9CR.\n";
print "www.wodielite.com\n";
print "wodielite at mac.com\n\n";

# Load Settings ini file.
print "Loading Settings...\n";
my $cfg = Config::IniFiles->new( -file => "config.ini");
# Settings:
my $Mode = $cfg->val('Settings', 'Mode'); #0 = v.24, no other modes coded at the momment.
my $LocalHost = $cfg->val('Settings', 'Local_Host');
my $P25NX_STUN_ID = sprintf("%x", hex($cfg->val('Settings', 'STUN_ID')));
my $P25NX_Enabled = $cfg->val('Settings', 'P25NX_Enabled');
my $RTRT_Enabled = $cfg->val('Settings', 'RTRT_Enabled');
my $Cisco_DMVPN_Enabled = $cfg->val('Settings', 'Cisco_DMVPN_Enabled'); # Need Cisco DMVPN.
my $P25Link_Enabled = $cfg->val('Settings', 'P25Link_Enabled');
my $MMDVM_Enabled = $cfg->val('Settings', 'MMDVM_Enabled');
print "  Mode = $Mode\n";
print "  Local Host = $LocalHost\n";
print "  Stun ID = 0x$P25NX_STUN_ID\n";
print "  P25NX Enabled = $P25NX_Enabled\n";
print "  RT/RT ENabled = $RTRT_Enabled\n";
print "  Cisco DMVPN Enabled = $Cisco_DMVPN_Enabled\n";
print "  P25Link Enabled = $P25Link_Enabled\n";
print "  MMDVM Enabled = $MMDVM_Enabled\n";
# Preferences
my $Language = $cfg->val('Preferences', 'Language');
my $Verbose = $cfg->val('Preferences', 'Verbose');
my $HDLC_Verbose = $cfg->val('Preferences', 'HDLC_Verbose');
my $MMDVM_Verbose = $cfg->val('Preferences', 'MMDVM_Verbose');
my $P25NX_Verbose =$cfg->val('Preferences', 'P25NX_Verbose');
my $DefaultTalkGroup = $cfg->val('Preferences', 'DefaultTalkGroup');
my $DefaultTalkGroupTimeout = $cfg->val('Preferences', 'DefaultTalkGroupTimeout');
my $UseVoicePrompts = $cfg->val('Preferences', 'UseVoicePrompts');
my $UseLocalCourtesyTone = $cfg->val('Preferences', 'UseLocalCourtesyTone');
my $UseRemoteCourtesyTone = $cfg->val('Preferences', 'UseRemoteCourtesyTone');
print "  Language = $Language\n";
print "  Verbose = $Verbose\n";
print "  HDLC Verbose = $HDLC_Verbose\n";
print "  MMDVM Verbose = $MMDVM_Verbose\n";
print "  P25NX Verbose = $P25NX_Verbose\n";
print "  Default Talk Group = $DefaultTalkGroup\n";
print "  Default Talk Group Timeout = $DefaultTalkGroupTimeout\n";
print "  Use Voice Prompts = $UseVoicePrompts\n";
print "  Use Local Courtesy Tone = $UseLocalCourtesyTone\n";
print "  Use Remote COurtesy Tone = $UseRemoteCourtesyTone\n";

# User:
my $Callsign = $cfg->val('User', 'Callsign');
my $RadioID = sprintf("%d", $cfg->val('User', 'RadioID'));
print "  Callsign = $Callsign\n";
print "  Repeater RadioID = $RadioID\n";
# Reflectors
print "  Listing available Reflectors:\n";
my @Reflectors = $cfg->val('Reflectors', 'Ref');
for (my $x = 0; $x < scalar(@Reflectors); $x++) {
#	print "    Ref " . $x . " " . $Reflectors[$x] ."\n";
}

print "  Reflectors Database/MMDVM talk groups.\n"; my @Links = (
	#[P25NX TG, MMDVM TG, 'Ref. Address', Port],
	[420, 420, 'p25.evsuperfreqs.com', 41000],
	[530, 530, 'zldigitalreflectors.hopto.org', 41000],
	[707, 707, '707p25.kd0ioe.com', 41000],
	[2140, 2140, '94.177.235.81', 41000],
	[2503, 2503, 'p25.r1ik.ru', 41000],
	[3023, 3023, 'ontxlink.hopto.org', 41000],
	[4095, 4095, '44.98.254.131', 41010], # Ref Tpa 10
	[5057, 5057, '45.248.50.37', 41000],
	[6395, 6395, 'p25ref.nf9k.net', 41000],
	# P25NX and MMDVM reflectors:
	[10100, 10100, 'm1geo.com', 41000],
	[10101, 10101, '44.98.254.131', 41001], # Tpa 0
	[10102, 10102, '44.98.254.131', 41002], # Tpa 1
	[10103, 10103, '44.98.254.131', 41003], # Tpa 2
	[10200, 10200, 'dvswitch.org', 41000],
	[10201, 10201, 'dvswitch.org', 41010],
	[10202, 10202, '44.98.254.131', 41004], # Tpa 3
	[10203, 10203, '44.98.254.131', 41005], # Tpa 4
	[10300, 10300, '176.9.1.168', 41000],
	[10301, 10301, 'ea5gvk.duckdns.org', 41000],
	[10302, 10302, '44.98.254.131', 41006], # Tpa 5
	[10303, 10303, '44.98.254.131', 41007], # Tpa 6
	[10310, 10310, '44.148.230.100', 41000], # France
	[10320, 10320, '78.47..206..12', 41000], # Germany
#	[10328, 10328, '5.9.59.26', 41000],
#	[10342, 10342, 'P25R.northwestdigital.club', 41000],
#	[10350, 10350, 'warc.ddns.net', 41000],
#	[10400, 10400, 'pacificp25.repeaters.info', 41000],
#	[10401, 10401, 'pacifictac1.repeaters.info', 41010],
#	[10402, 10402, '47.104.177.248', 41000],
#	[10403, 10403, '120.234.41.144', 41000],
#	[10404, 10404, 'p25tw338.ddns.net', 41000],
	# MMDVM Reflectors:
	[10700, 10700, 'p25nsw.gustotech.net', 41000],
	[23225, 23255, '94.199.173.123', 41000],
	[25641, 25641, '194.182.85.217', 41000],
	[28299, 28299, '65.101.7.51', 41000],
	[30639, 30693, 'wiresxdigi.dyndns.org', 41000],
	[31010, 31010, 'p25.alabamalink.info', 41000],
	[31062, 31062, 'p25.mw-dmr.net', 41000],
	[31088, 31088, '54.191.50.212', 41000],
	[31092, 31092, 'p25.alecwasserman.com', 41000],
	[31171, 31171, '74.208.235.115', 41000],
	[31188, 31188, 'w9windigital.org', 41000],
	[31665, 31665, '18.223.66.56', 41000],
	[31672, 31672, 'p25-31672.pistar.uk', 41000],
	[31341, 31341, 'p25.kc2idb.net', 41000],
	[31777, 31777, '45.77.204.214', 41000],
	[31888, 31888, 'p25.kg4jpl.com', 41000],
	[40721, 40721, '38.110.97.161', 41000],
	[50525, 50525, '505.p25dvm.com', 41000],
	[53099, 53099, '203.86.206.49', 41000]
	);
my $NumberOfReflectors = scalar @Links; # Length of the array.
for (my $x = 0; $x < $NumberOfReflectors; $x++) {
#	print "    Link " . $x . " P25NX TG " . $Links[$x][0] .
#		" MMDVM TG " . $Links[$x][1] .
#		" IP " . $Links[$x][2] . 
#		" Port " . $Links[$x][3] .  "\n";
}
print "  Total number of Reflectors found = " . $NumberOfReflectors . "\n\n";

# Voice Announce.
print "Loading voice announcements...\n";
my $SpeechFile = Config::IniFiles->new( -file => "Speech.ini");
my @Speech_SystemStart = $SpeechFile->val('speech_SystemStart', 'byte');
my @Speech_DefaultRevert = $SpeechFile->val('speech_DefaultRevert', 'byte');
my @HDLC_TestPattern = $SpeechFile->val('HDLC_TestPattern', 'byte');
my @Speech_WW = $SpeechFile->val('speech_WW', 'byte');
my @Speech_WWTac1 = $SpeechFile->val('speech_WWTac1', 'byte');
my @Speech_WWTac2 = $SpeechFile->val('speech_WWTac2', 'byte');
my @Speech_WWTac3 = $SpeechFile->val('speech_WWTac3', 'byte');
my @Speech_NA = $SpeechFile->val('speech_NA', 'byte');
my @Speech_NATac1 = $SpeechFile->val('speech_NATac1', 'byte');
my @Speech_NATac2 = $SpeechFile->val('speech_NATac2', 'byte');
my @Speech_NATac3 = $SpeechFile->val('speech_NATac3', 'byte');
my @Speech_Europe = $SpeechFile->val('speech_Europe', 'byte');
my @Speech_EuTac1 = $SpeechFile->val('speech_EuTac1', 'byte');
my @Speech_EuTac2 = $SpeechFile->val('speech_EuTac2', 'byte');
my @Speech_EuTac3 = $SpeechFile->val('speech_EuTac3', 'byte');
my @Speech_France = $SpeechFile->val('speech_France', 'byte');
my @Speech_Germany = $SpeechFile->val('speech_Germany', 'byte');
my @Speech_Pacific = $SpeechFile->val('speech_Pacific', 'byte');
my @Speech_PacTac1 = $SpeechFile->val('speech_PacTac1', 'byte');
my @Speech_PacTac2 = $SpeechFile->val('speech_PacTac2', 'byte');
my @Speech_PacTac3 = $SpeechFile->val('speech_PacTac3', 'byte');
my $Pending_VA = 0;
my $VA_Message = 0;
print "\n";


# Quantar HDLC Init.
print "Init Quantar HDLC.\n";
struct Quant => {
	FrameType => '$',
	LocalRx => '$',
	LocalRx_Time => '$',
	IsDigitalVoice => '$',
	IsPage => '$',
	dBm => '$',
	RSSI => '$',
	RSSI_Is_Valid => '$',
	InvertedSignal => '$',
	CandidateAdjustedMM => '$',
	BER => '$',
	SourceDev => '$',
	Encrypted => '$',
	Explicit => '$',
	IndividualCall => '$',
	ManufacturerID => '$',
	Emergency => '$',
	Protected => '$',
	FullDuplex => '$',
	PacketMode => '$',
	Priority => '$',
	AstroTalkGroup => '$',
	DestinationRadioID => '$',
	SourceRadioID => '$',
	LSD => '@',
	LSD0 => '$',
	LSD1 => '$',
	LSD2 => '$',
	LSD3 => '$',
	EncryptionI => '$',
	EncryptionII => '$',
	EncryptionIII => '$',
	EncryptionIV => '@',
	Algorythm => '$',
	KeyID => '$',
	Speech => '$',
	Raw0x62 => '$',
	Raw0x63 => '$',
	Raw0x64 => '$',
	Raw0x65 => '$',
	Raw0x66 => '$',
	Raw0x67 => '$',
	Raw0x68 => '$',
	Raw0x69 => '$',
	Raw0x6A => '$',
	Raw0x6B => '$',
	Raw0x6C => '$',
	Raw0x6D => '$',
	Raw0x6E => '$',
	Raw0x6F => '$',
	Raw0x70 => '$',
	Raw0x71 => '$',
	Raw0x72 => '$',
	Raw0x73 => '$',
	SuperFrame => '$',
};
my $Quant = Quant->new();
$Quant->LocalRx(0);
$Quant->AstroTalkGroup(0x00);
#
# ICW (Infrastructure Control Word).
# Byte 1 address.
# Bte 2 frame type.
my $C_RR = 0x41;
my $C_UI = 0x03;
my $C_SABM = 0x3F;
my $C_XID = 0xBF;
# Byte 3.
# Byte 4.
# Byte 5 RT mode flag.
my $C_RTRT_Enabled = 0x02;
my $C_RTRT_Disabled = 0x04;
my $C_RTRT_DCRMode = 0x05;
# Byte 6 Op Code Start/Stop flag.
my $C_ChangeChannel = 0x06;
my $C_StartTx = 0x0C;
my $C_EndTx = 0x25;
# Byte 7 OpArg, type flag.
my $C_AVoice = 0x00;
my $C_TMS_Data_Payload = 0x06;
my $C_DVoice = 0x0B;
my $C_TMS_Data = 0x0C;
my $C_From_Comparator_Start = 0x0D;
my $C_From_Comparator_Stop = 0x0E;
my $C_Page = 0x0F;
# Byte 8 ICW flag.
my $C_DIU3000 = 0x00;
my $C_Quantar = 0xC2;
my $C_QuantarAlt = 0x1B;
# Byte 9 LDU1 RSSI.
# Byte 10 1A flag.
my $C_RSSI_Is_Valid = 0x1A;
# Byte 11 LDU1 RSSI.
#
# Byte 13 Page.
my $C_Normal_Page = 0x9F;
my $C_Emergency_Page = 0xA7;
#
my $C_AllCallTG = 0xFFFF;
#
#
my $IsTGData = 0;
my $C_Implicit_MFID = 0;
my $C_Explicit_MFID = 1;
my $Is_TG_Data = 0;
my $SuperframeCounter = 0;
#
#
my $RR_NextTimer = 0;
my $RR_Timeout = 0;
my $RR_TimerInterval = 5; # Seconds.
my $HDLC_Handshake = 0;
my $SABM_Counter = 0;
my $Message = "";
my $HDLC_Buffer = "";
my $RR_Timer = 0;
#
my $Tx_Started = 0;
my $SuperFrameCounter = 0;
my $HDLC_TxTraffic = 0;
my $LocalRx_Time;
# Init Serial Port for HDLC.
my $TickCount;
my $FutureTickCount;
my $SerialPort;
my $SerialPort_Configuration = "SerialConfig.cnf";
if ($Mode == 0) {
	$SerialPort = Device::SerialPort->new('/dev/ttyUSB0') || die "Cannot Init Serial Port : $!\n"; # For Linux.
	#my $SerialPort = Device::SerialPort->new('/dev/tty.usbserial') || die "Cannot Init Serial Port : $!\n"; # For Mac.
	$SerialPort->baudrate(19200);
	$SerialPort->databits(8);
	$SerialPort->parity('none');
	$SerialPort->stopbits(1);
	$SerialPort->handshake('none');
	$SerialPort->buffers(4096, 4096);
	$SerialPort->datatype('raw');
	$SerialPort->debug(1);
	$SerialPort->write_settings || undef $SerialPort;
	#$SerialPort->save($SerialPort_Configuration);
	$TickCount = sprintf("%d", $SerialPort->get_tick_count());
	$FutureTickCount = $TickCount + 5000;
	print "  TickCount = $TickCount\n\n";
}
# To use Raspberry Pi UART you need to disable Bluetooth by editing: /boot/config.txt
# Add line: dtoverlay=pi3-disable-bt-overlay


# Init MMDVM.
print "Init MMDVM.\n";
my $MMDVM_LocalHost = $LocalHost; # Bind Address.
#my $MMDVM_LocalHost = '192.168.0.103';# Bind Address.
my $MMDVM_LocalPort = 41020; # Local Port.
my $MMDVM_RemoteHost; # Buffer for Rx data IP.
my $MMDVM_Poll_Timer_Interval = 5; # sec.
my $MMDVM_Sock;
my $MMDVM_Sel;
my $MMDVM_Listen_Enable;
my $MMDVM_Poll_NextTimer = time + $MMDVM_Poll_Timer_Interval;
my $MMDVM_Connected = 0;
struct AddrPort => {
	Address => '$',
	Port => '$',
};
my $MMDVM_Addr = AddrPort->new();
$MMDVM_Addr->Address(0.0.0.0);
$MMDVM_Addr->Port(41000);
my $MaxLen =1024; # Max Socket Buffer length.


# Init P25NX.
print "Init_P25NX.\n";
#my $P25NX_STUN_ID = 0x63;
my $P25NX_InfoPayload = 0xFD; # Can be 0xFD or 0x07
my $P25NX_RemoteHost; # Buffer for remote data IP.
my $P25NX_LocalPort = 30000;
my $P25NX_RemotePort = 30000;
my $P25NX_Index;
my $P25NX_Sock;
my $P25NX_Sel;
my $P25NX_Connected = 0;

# Init P25Link.
my $P25Link_Connected = 0;
# Connect to Default Talk Group.
my $ActiveLinkIndex = 0;
my $LinkedTalkGroup = 0;
my $DefaultTalkGroupTimer;
if ($DefaultTalkGroup > 10) {
	ChangeLinkedTG($DefaultTalkGroup);
}
# Prepare Startu VA Message.
$VA_Message = 0; # Welcome to the P25NX.
$Pending_VA = 1;


# Raspberry Pi GPIO
#my $ResetPicPin = RPi::Pin->new(4, "Reset PIC");
#my $Pin5 = RPi::Pin->new(5, "PTT");
#my $Pin5 = RPi::Pin->new(6, "COS");
# This use the BCM pin numbering scheme. 
# Valid GPIOs are: 2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27.
# GPIO 2, 3 Aleternate for I2C.
# GPIO 14, 15 alternate for USART.
#$ResetPicPin->mode(OUTPUT);
#$Pin5->write(HIGH);
#$pin->set_interrupt(EDGE_RISING, 'main::Pin5_Interrupt_Handler');


# Misc
my $Res = 0;
my $Count = 0;
my $Value = 0;


###################################################################
# MAIN ############################################################
###################################################################
MainLoop();

$SerialPort->close || die "Failed to close SerialPort.\n";
$MMDVM_Sock->close();
P25NX_Disconnect($LinkedTalkGroup);
$P25NX_Sock->close();
print "You should never reach this point.\n";
print "Good bye cruel World.\n";
return 0;

##################################################################
# Subs ###########################################################
##################################################################

##################################################################
# HDLC ###########################################################
##################################################################
sub Read_Serial{ # Read the serial port, look for 0x7E characters and extract data between them.
	my $NumChars;
	my $SerialBuffer;
	($NumChars, $SerialBuffer) = $SerialPort->read(255);
	if ($NumChars >= 1 ){ #Perl data Arrival test.
		#Bytes_2_HexString($SerialBuffer);
		for (my $x = 0; $x <= $NumChars; $x++) {
			if (ord(substr($SerialBuffer, $x, 1)) == 0x7E) {
				if (length($HDLC_Buffer) > 0) {
					HDLC_Rx($HDLC_Buffer); # Process a full data stream.
					#print "Serial Str Data Rx len() = " . length($HDLC_Buffer) . "\n";
				}
				#print "Read_Serial len = ", length($HDLC_Buffer), "\n";
				$HDLC_Buffer = ""; # Clear Rx buffer.
			} else {
				$HDLC_Buffer = $HDLC_Buffer . substr($SerialBuffer, $x, 1); # Add Bytes until the end of data stream (0x7E).
			}
		}
	}
}

sub HDLC_Rx{
	my ($Buffer) = @_;
	my $RTRTOn;
	my $OpCode;
	my $OpArg;
	my $SiteID;
	my $IsChannelChange;
	my $Channel;
	my $IsStart;
	my $IsEnd;

	if ($Mode == 0) {
		# CRC CCITT test patterns:
		#my $DataC;
		#$DataC = "7EFD01BED27E"; # RR
		#$DataC = "7EFD3F430A7E"; # SABM
		#$Buffer = chr(0x7E) . chr(0xFD) . chr(0x3F) . chr(0x43) . chr(0x0A) . chr(0x7E);
		#$Buffer = chr(0x7E) . chr(0xFD) . chr(0x03) . chr(0x00) . chr(0x00) . 
			#chr(0x7D) . chr(0x5E) . 
			#chr(0x11) . chr(0x11) .
			#chr(0x7D) . chr(0x5D) . chr(0x22) . chr(0x22) . 
			#chr(0x7D) . chr(0x45) . chr(0x33) . chr(0x33) .
			#chr(0x7E);	

		#$Buffer = chr(0x7E) . $Buffer . chr(0x7E);

		#print "A ", sprintf("0x%x", ord(substr($Buffer, 0, 1))), "\n";
		#print "B ", sprintf("0x%x", ord(substr($Buffer, 1, 1))), "\n";
		#print "C ", sprintf("0x%x", ord(substr($Buffer, 2, 1))), "\n";
		#print "D ", sprintf("0x%x", ord(substr($Buffer, 3, 1))), "\n";
		#print "E ", sprintf("0x%x", ord(substr($Buffer, 4, 1))), "\n";
		#print "F ", sprintf("0x%x", ord(substr($Buffer, 5, 1))), "\n";
	
		#print "Buffer = $Buffer\n";
		#print "Len(Buffer) = ", length($Buffer), "\n";
		#my $res = HexStr_2_Str($Buffer);

		if (substr($Buffer, 0, 7) eq "!RESET!") {
			my $BoardID = ord(substr($Buffer, 7, 1));
			print "*** Warning ***   HDLC_Rx Board $BoardID made a Reset!\n";
			return;
		}

		# Byte Stuff
		$Buffer =~ s/\}\^/\~/g; # 0x7D 0x5E to 0x7E
		$Buffer =~ s/\}\]/\}/g; # 0x7D 0x5D to 0x7D
		#print "Byte Stuff, Len(Buffer) = ", length($Buffer), "\n";
		
		# Show Raw data.
		#Bytes_2_HexString($Buffer);
	
		# CRC CCITT.
		if (length($Buffer) < 2) {
			print "*** Warning ***   HDLC_Rx Warning Buffer < 2 Bytes.\n";
			return;
		}
		$Message = substr($Buffer, 0, length($Buffer) - 2);
		#print "Len(Message) = ", length($Message), "\n";
		my $CRC_Rx = 256 * ord(substr($Buffer, length($Buffer) - 2, 1 )) + ord(substr($Buffer, length($Buffer) - 1, 1));
		#print "CRC_Rx  = $CRC_Rx\n";
		if (length($Message) == 0) {
			print "*** Warning ***   HDLC_Rx Message is Null.\n";
			return;
		}
		my $CRC_Gen = CRC_CCITT_Gen($Message);
		#print "CRC_Gen = $CRC_Gen\n";
		#print "CRCH ", sprintf("0x%x", ord(substr($CRC_Gen, 0, 1))), "\n";
		#print "CRCL ", sprintf("0x%x", ord(substr($CRC_Gen, 1, 1))), "\n";
		#print "Calc CRC16 in hex: ", unpack('H*', pack('S', $Message)), "\n";
		if ($CRC_Rx != $CRC_Gen) {
			print "*** Warning ***   HDLC_Rx CRC does not match " . $CRC_Rx . " <> " . $CRC_Gen . ".\n";
			return;
		}
	} else {
		$Message = $Buffer,
	}

	if ($HDLC_Verbose == 3) {
		print "HDLC_Rx Message.\n";
		Bytes_2_HexString($Message);
	}
	# 01 Address
	my $Address = ord(substr($Message, 0, 1));
	#print "Address = ", sprintf("0x%x", $Address), "\n";
	#Bytes_2_HexString($Message);
	
	$Quant->FrameType(ord(substr($Message, 1, 1)));
	#print "Frame Types = ", sprintf("0x%x", $FrameType), "\n";
	switch ($Quant->FrameType) {
		case 0x01 { # RR Receive Ready.
			if ($Address == 253) {
				$RR_Timer = 0;
				$HDLC_Handshake = 1;
			} else {
				print "*** Warning ***   HDLC_Rx RR Address 253 != $Address\n";
			}
			return;
		}
		case 0x03 { # User Information.
			#print "Case 0x03 UI.", substr($Message, 2, 1), "\n";
			#Bytes_2_HexString($Message);
			$Quant->LocalRx(1);
			$Quant->LocalRx_Time($SerialPort->get_tick_count());
			switch (ord(substr($Message, 2, 1))) {
				case 0x00 { #Network ID, NID Start/Stop.
					if ($HDLC_Verbose) {
						print "UI 0x00 NID Start/Stop";
					}
					if (ord(substr($Message, 4, 1)) == $C_RTRT_Enabled) {
						$RTRTOn = 1;
						if ($HDLC_Verbose) {
							print ", RT/RT Enabled";
						}
					}
					if (ord(substr($Message, 4, 1)) == $C_RTRT_Disabled) {
						$RTRTOn = 0;
						if ($HDLC_Verbose) {
							print ", RT/RT Disabled";
						}
					}
					$OpCode = ord(substr($Message, 5, 1));
					$OpArg = ord(substr($Message, 6, 1));
					switch ($OpCode) {
						case 0x06 { # ChannelChange
							$IsChannelChange = 1;
							$Channel = $OpArg;
						}
						case 0x0C { # StartTx
							$IsStart = 1;
							if ($Verbose) {
								print ", HDLC ICW Start";
							}
							Tx_to_Network($Message);
						}
						case 0x0D {
								print ", DIU Monitor";
						}
						case 0x25 { # StopTx
							$IsEnd = 1;
							if ($Verbose) {
								print ", HDLC ICW Terminate";
							}
							Tx_to_Network($Message);
							$Quant->LocalRx(0);
						}
					}
					switch ($OpArg) {
						case 0x00 { # AVoice
							 if ($HDLC_Verbose) {print ", Analog Voice";}
						}
						case 0x0B { # DVoice
							 if ($HDLC_Verbose) {print ", Digital Voice";}
						}
						case 0x0F { # Page
							 if ($HDLC_Verbose) {print ", Page";}
						}
					}
					if ($Verbose) {
						print ", Linked Talk Group " . $LinkedTalkGroup . ".\n";
						print "MMDVM_Connected " . $MMDVM_Connected . 
						"\nP25NX_Connected " . $P25NX_Connected . "\n";
					}
				}
				case 0x01 {
					print "UI 0x01 Undefined.\n";
				}
				case 0x59 {
					print "UI 0x59 Undefined.\n";
					return;
				}
				case 0x60 {
					if ($HDLC_Verbose) {print "UI 0x60 Voice Header part 1.\n";}
					Bytes_2_HexString($Buffer);
					switch (ord(substr($Message, 4, 1))) {
						case 0x02 { # RTRT_Enabled
							$RTRTOn = 1;
							if ($HDLC_Verbose) {print "RT/RT Enabled";}
						}
						case 0x04 { # RTRT_Disabled
							$RTRTOn = 1;
							if ($HDLC_Verbose) {print "RT/RT Disabled";}
						}
					}
					switch (ord(substr($Message, 6, 1))) {
						case 0x00 { # AVoice
							if ($HDLC_Verbose) {print ", Analog Voice";}
						}
						case 0x0B { # DVoice
							if ($HDLC_Verbose) {print ", Digital Voice";}
						}
						case 0x0F { # Page
							if ($HDLC_Verbose) {print ", Page";}
						}
					}
					$SiteID = ord(substr($Message,7 ,1));
					switch ($SiteID) {
						case 0x00 { # DIU3000
							if ($HDLC_Verbose) {print ", Source: DIU 3000";}
						}
						case 0xC2 { # Quantar
							if ($HDLC_Verbose) {print ", Source: Quantar";}
						}
					}
					if (ord(substr($Message, 9, 1)) == 1) {
						$Quant->RSSI_Is_Valid(1);
						$Quant->RSSI(ord(substr($Message, 8, 1)));
						$Quant->InvertedSignal(ord(substr($Message, 10, 1)));
						if ($HDLC_Verbose) {
							print ", RSSI = " . $Quant->RSSI . "\n";
							print ", Inverted signal = " . $Quant->InvertedSignal . "\n";
						}
					} else {
						$Quant->RSSI_Is_Valid(0);
						if ($HDLC_Verbose) {print ".\n";}
					}
				}
				case 0x61 {
					if ($HDLC_Verbose) {
						print "UI 0x61 Voice Header part 2.\n";
					}
					if ($HDLC_Verbose == 2) {
						Bytes_2_HexString($Message);
					}
					#my $TGID = 256 * ord(substr($Message, 4, 1)) + ord(substr($Message, 3, 1));;
					#print "Not true TalkGroup ID = " . $TGID . "\n";

				}
				case 0x62 { # dBm, RSSI, BER.
					if ($HDLC_Verbose) {print "UI 0x62 IMBE Voice part 1.\n";}
					switch (ord(substr($Message, 4, 1))) {
						case 0x02 { # RT/RT Enable
							$RTRTOn = 1;
							if ($HDLC_Verbose) {print "RT/RT Enabled";}
						}
						case 0x04 { # RT/RT Disable
							$RTRTOn = 0;
							if ($HDLC_Verbose) {print "RT/RT Disabled";}
						}
					}
					switch (ord(substr($Message, 6, 1))) {
						case 0x0B { # DVoice
							$Quant->IsDigitalVoice(1);
							$Quant->IsPage(0);
							if ($HDLC_Verbose) {print ", Digital Voice";}
						}
						case 0x0F { # Page
							$Quant->IsDigitalVoice(0);
							$Quant->IsPage(1);
							if ($HDLC_Verbose) {print ", Page";}
						}
					}
					$SiteID = ord(substr($Message, 7, 1));
					switch ($SiteID) {
						case 0x00 { # DIU3000
							if ($HDLC_Verbose) {print ", SiteID: DIU 3000";}
						}
						case 0xC2 { # Quantar
							if ($HDLC_Verbose) {print ", SiteID: Quantar";}
						}
					}
					if (ord(substr($Message, 9, 1))) {
						$Quant->RSSI_Is_Valid(1);
						$Quant->RSSI(ord(substr($Message, 8, 1)));
						$Quant->InvertedSignal(ord(substr($Message, 10, 1)));
						$Quant->CandidateAdjustedMM(ord(substr($Message, 11, 1)));
						if ($HDLC_Verbose) {
							print ", RSSI = " . $Quant->RSSI . "\n";
							print ", Inverted signal = " . $Quant->InvertedSignal . "\n";
						}
					} else {
						$Quant->RSSI_Is_Valid(0);
					}
					$Quant->Speech(ord(substr($Message, 12, 11)));
					$Quant->Raw0x62($Message);
					$Quant->SuperFrame($Message);
					$Quant->SourceDev(ord(substr($Message, 23, 1)));
					Tx_to_Network($Message);

				}
				case 0x63 {
					if ($HDLC_Verbose) {print "UI 0x63 IMBE Voice part 2.\n";}
					$Quant->Speech(ord(substr($Message, 3, 11)));
					$Quant->Raw0x63($Message);
					$Quant->SuperFrame($Quant->SuperFrame . $Message);
					$Quant->SourceDev(ord(substr($Message, 14, 1)));
					Tx_to_Network($Message);
				}
				case 0x64 { # Group/Direct Call, Clear/Private.
					if ($HDLC_Verbose) {print "UI 0x64 IMBE Voice part 3 + link control.\n";}
					if (ord(substr($Message, 3, 1)) & 0x80) {
						$Quant->Encrypted(1);
					}
					if (ord(substr($Message, 3, 1))& 0x40) {
						$Quant->Explicit(1);
					}
					$IsTGData = 0;
					switch (ord(substr($Message, 3, 1)) & 0x0F) {
						case 0x00 { # Group voice channel user.
							$IsTGData = 1;
							$Quant->IndividualCall(0);
						}
						case 0x02 { # Group voice channel update.
							$Quant->IndividualCall(0);
						}
						case 0x03 { # Unit to unit voice channel user.
							$Quant->IndividualCall(1);
						}
						case 0x04 { # Group voice channel update - explicit.
							$Quant->IndividualCall(1);
						}
						case 0x05 { # Unit to unit answer request.
							$Quant->IndividualCall(1);
						}
						case 0x06 { # Telephone interconnect voice channel user.
							print "Misterious packet.";
						}
						case 0x07 { # Telephone interconnect answer request.
							print "Telephone interconnect answer request.\n";
						}
						case 0x0F { # Call termination/cancellation.
							print "Call termination/cancellation.\n";
						}

					}
					$Quant->ManufacturerID(ord(substr($Message, 4, 1)));
					if (ord(substr($Message, 5, 1)) and 0x80) {
						$Quant->Emergency(1);
					} else {
						$Quant->Emergency(0);
					}
					if (ord(substr($Message, 5, 1)) and 0x40) {
						$Quant->Protected(1);
					} else {
						$Quant->Protected(0);
					}
					if (ord(substr($Message, 5, 1)) and 0x20) {
						$Quant->FullDuplex(1);
					} else {
						$Quant->FullDuplex(0);
					}
					if (ord(substr($Message, 5, 1)) and 0x10) {
						$Quant->PacketMode(1);
					} else {
						$Quant->PacketMode(0);
					}
					$Quant->Priority(ord(substr($Message, 5, 1)));
					$Quant->Speech(ord(substr($Message, 7, 11)));
					$Quant->SuperFrame($Quant->SuperFrame . $Message);
					$Quant->Raw0x64($Message);
 					Tx_to_Network($Message);
				}
				case 0x65 #Talk Group.
				{
					if ($HDLC_Verbose) {print "UI 0x65 IMBE Voice part 4 + link control.\n";}
					#Bytes_2_HexString($Message);
					if ($IsTGData) {
						$Quant->AstroTalkGroup(256 * ord(substr($Message, 4, 1)) +
								ord(substr($Message, 5, 1)));
						$Quant->DestinationRadioID(65536 * ord(substr($Message, 3, 1)) +
								256 * ord(substr($Message, 4, 1)) + 
								ord(substr($Message, 5, 1)));
						if ($Quant->IndividualCall) {
							if ($HDLC_Verbose) {print "Destination ID = " . $Quant->{DestinationID} . "\n";}
						} else {
							if ($HDLC_Verbose) {print "AstroTalkGroup = " . $Quant->AstroTalkGroup . "\n";}
							ChangeLinkedTG($Quant->AstroTalkGroup);
						}
					}
					$Quant->Speech(ord(substr($Message, 7, 11)));
					$Quant->Raw0x65($Message);
					$Quant->SuperFrame($Quant->SuperFrame . $Message);
					Tx_to_Network($Message);
				}
				case 0x66 { # Source ID.
					if ($HDLC_Verbose) {print "UI 0x66 IMBE Voice part 5. + link control.\n";}
					# Get Called ID.
					if ($IsTGData) {
						$Quant->SourceRadioID(ord(substr($Buffer, 3, 1)) * 256 * 256 +
							ord(substr ($Buffer, 4, 1)) *256 +
							ord(substr($Buffer, 5, 1)));
						if ($HDLC_Verbose) {print "HDLC SourceRadioID = " . $Quant->SourceRadioID . "\n";}
					} else {
						if ($Verbose) {print "Misterious packet 0x66\n";}
					}
					$Quant->Speech(ord(substr($Message, 7, 11)));
					$Quant->Raw0x66($Message);
					$Quant->SuperFrame($Quant->SuperFrame . $Message);
					Tx_to_Network($Message);
				}
				case 0x67 { # TBD
					if ($HDLC_Verbose) {print "UI 0x67 IMBE Voice part 6 + link control.\n";}
					$Quant->Speech(ord(substr($Message, 7, 11)));
					$Quant->Raw0x67($Message);
					$Quant->SuperFrame($Quant->SuperFrame . $Message);
					Tx_to_Network($Message);
				}
				case 0x68 {
					if ($HDLC_Verbose) {print "UI 0x68 IMBE Voice part 7 + link control.\n";}
					$Quant->Speech(ord(substr($Message, 7, 11)));
					$Quant->Raw0x68($Message);
					$Quant->SuperFrame($Quant->SuperFrame . $Message);
					Tx_to_Network($Message);
				}
				case 0x69 {
					if ($HDLC_Verbose) {print "UI 0x69 IMBE Voice part 8 + link control.\n";}
					$Quant->Speech(ord(substr($Message, 7, 11)));
					$Quant->Raw0x69($Message);
					$Quant->SuperFrame($Quant->SuperFrame . $Message);
					Tx_to_Network($Message);
				}
				case 0x6A { # Low speed data Byte 1.
					if ($HDLC_Verbose) {print "UI 0x6A IMBE Voice part 9 + low speed data 1.\n";}
					$Quant->LSD0(ord(substr($Message, 4, 1)));
					$Quant->LSD1(ord(substr($Message, 5, 1)));
					$Quant->Speech(ord(substr($Message, 6, 11)));
					$Quant->Raw0x6A($Message);
					$Quant->SuperFrame($Quant->SuperFrame . $Message);
					Tx_to_Network($Message);
				}
				case 0x6B { # dBm, RSSI, BER.
					if ($HDLC_Verbose) {print "UI 0x6B IMBE Voice part 10.\n";}
					switch (ord(substr($Message, 4, 1))) {
						case 0x02 { # RT/RT Enable
							$RTRTOn = 1;
							if ($HDLC_Verbose) {print "RT/RT Enabled";}
						}
						case 0x04 { # RT/RT Disable
							$RTRTOn = 0;
							if ($HDLC_Verbose) {print "RT/RT Disabled";}
						}
					}
					switch (ord(substr($Message, 6, 1))) {
						case 0x0B { # DVoice
							$Quant->IsDigitalVoice(1);
							$Quant->IsPage(0);
							if ($HDLC_Verbose) {print ", Digital Voice";}
						}
						case 0x0F { # Page
							$Quant->IsDigitalVoice(0);
							$Quant->IsPage(1);
							if ($HDLC_Verbose) {print ", Page";}
						}
					}
					$SiteID = ord(substr($Message, 7, 1));
					switch ($SiteID) {
						case 0x00 { # DIU3000
							if ($HDLC_Verbose) {print ", SiteID: DIU 3000";}
						}
						case 0xC2 { # Quantar
							if ($HDLC_Verbose) {print ", SiteID: Quantar";}
						}
					}
					$Quant->RSSI(ord(substr($Message, 8, 1)));
					if (ord(substr($Message, 9, 1))) {
						$Quant->RSSI_Is_Valid(1);
						if ($HDLC_Verbose) {
							print ", RSSI = " . $Quant->RSSI . "\n";
							print ", Inverted signal = " . $Quant->InvertedSignal . "\n";
						}
					} else {
						$Quant->RSSI_Is_Valid(0);
					}
					$Quant->InvertedSignal(ord(substr($Message, 10, 1)));
					$Quant->CandidateAdjustedMM(ord(substr($Message, 11, 1)));
					$Quant->Speech(ord(substr($Message, 12, 11)));
					$Quant->Raw0x6B($Message);
					$Quant->SourceDev(ord(substr($Message, 23, 1)));
					$Quant->SuperFrame($Message);
					Tx_to_Network($Message);
				}
				case 0x6C {
					if ($HDLC_Verbose) {print "UI 0x6C IMBE Voice part 11.\n";}
					$Quant->Speech(ord(substr($Message, 3, 11)));
					$Quant->Raw0x6C($Message);
					$Quant->SuperFrame($Quant->SuperFrame . $Message);
					Tx_to_Network($Message);
				}
				case 0x6D {
					if ($HDLC_Verbose) {print "UI 0x6D IMBE Voice part 12 + encryption sync.\n";}
					$Quant->EncryptionI(ord(substr($Message, 3, 4)));
					$Quant->Speech(ord(substr($Message, 7, 11)));
					$Quant->Raw0x6D($Message);
					$Quant->SuperFrame($Quant->SuperFrame . $Message);
					Tx_to_Network($Message);
				}
				case 0x6E {
					if ($HDLC_Verbose) {print "UI 0x6E IMBE Voice part 13 + encryption sync.\n";}
					$Quant->EncryptionII(ord(substr($Message, 3,4)));
					$Quant->Speech(ord(substr($Message, 7, 11)));
					$Quant->Raw0x6E($Message);
					$Quant->SuperFrame($Quant->SuperFrame . $Message);
					Tx_to_Network($Message);
				}
				case 0x6F {
					if ($HDLC_Verbose) {print "UI 0x6F IMBE Voice part 14 + encryption sync.\n";}
					$Quant->EncryptionIII(ord(substr($Message, 3,4)));
					$Quant->Speech(ord(substr($Message, 7, 11)));
					$Quant->Raw0x6F($Message);
					$Quant->SuperFrame($Quant->SuperFrame . $Message);
					Tx_to_Network($Message);
				}
				case 0x70 { # Algorithm.
					if ($HDLC_Verbose) {print "UI 0x70 IMBE Voice part 15 + encryption sync.\n";}
					$Quant->Algorythm(ord(substr($Message, 3,1)));
					$Quant->KeyID(ord(substr($Message, 4,2)));
					$Quant->Speech(ord(substr($Message, 7, 11)));
					$Quant->Raw0x70($Message);
					$Quant->SuperFrame($Quant->SuperFrame . $Message);
					Tx_to_Network($Message);
				}
				case 0x71 {
					if ($HDLC_Verbose) {print "UI 0x71 IMBE Voice part 16 + encryption sync.\n";}
					$Quant->Speech(ord(substr($Message, 7, 11)));
					$Quant->Raw0x71($Message);
					$Quant->SuperFrame($Quant->SuperFrame . $Message);
					Tx_to_Network($Message);
				}
				case 0x72 {
					if ($HDLC_Verbose) {print "UI 0x72 IMBE Voice part 17 + encryption sync.\n";}
					$Quant->Speech(ord(substr($Message, 7, 11)));
					$Quant->Raw0x72($Message);
					$Quant->SuperFrame($Quant->SuperFrame . $Message);
					Tx_to_Network($Message);
				}
				case 0x73 { # Low speed data Byte 2.
					if ($HDLC_Verbose) {print "UI 0x73 IMBE Voice part 18 + low speed data 2.\n";}
					$Quant->LSD2(ord(substr($Message, 4, 1)));
					$Quant->LSD3(ord(substr($Message, 5, 1)));
					$Quant->Speech(ord(substr($Message, 6, 11)));
					$Quant->Raw0x73($Message);
					$Quant->SuperFrame($Quant->SuperFrame . $Message);
					Tx_to_Network($Message);
				}
				case 0x80 {
					print "UI 0x80.\n";
					Bytes_2_HexString($Message);
				}
				case 0x85 {
					print "UI 0x85.\n";
					Bytes_2_HexString($Message);
				}
				case 0x87 {
					print "UI 0x87.\n";
					Bytes_2_HexString($Message);
				}
				case 0x88 {
					print "UI 0x88.\n";
					Bytes_2_HexString($Message);
				}
				case 0x8D {
					print "UI 0x8D.\n";
					Bytes_2_HexString($Message);
				}
				case 0x8F {
					print "UI 0x8F.\n";
					Bytes_2_HexString($Message);
				}
				case 0xA1 { # Page affliate request.
					print "UI 0xA1.\n";
					Bytes_2_HexString($Message);
				} else {
					print "UI else 0x" . ord(substr($Message, 2, 1)) . "\n";
					Bytes_2_HexString($Message);
				}
			}
		}
		case 0x3F { # SABM Rx
			if ($HDLC_Verbose) {print "HDLC_Rx SABM.\n";}
			if ($HDLC_Verbose == 2) {Bytes_2_HexString($Message);}
			$HDLC_Handshake = 0;
			$RR_Timer = 0;
			HDLC_UA_Tx(253);
			$SABM_Counter = $SABM_Counter + 1;
			if ($SABM_Counter > 3) {
				HDLC_Reset();
				$SABM_Counter = 0;
			}
		}
		case 0x73 { #
			if ($HDLC_Verbose) {print "Case 0x73 Unumbered Ack.\n";}
			if ($HDLC_Verbose == 2) {Bytes_2_HexString($Message);}
		}
		case 0xBF { # XID Quantar to DIU identification packet.
			if ($HDLC_Verbose) {print "HDLC_Rx XID.\n";}
			if ($HDLC_Verbose == 2) {Bytes_2_HexString($Message);}
			$SABM_Counter = 0;
			my $MessageType = ord(substr($Message, 2, 1));
			my $StationSiteNumber = (int(ord(substr($Message, 3, 1))) - 1) / 2;
			my $StationType = ord(substr($Message, 4, 1));
			if ($StationType == $C_Quantar) {
				if ($HDLC_Verbose) {print "HDLC_Rx Quantar Station type.\n";}
			}
			if ($StationType == $C_DIU3000) {
				if ($HDLC_Verbose) {print "HDLC_Rx DIU 3000 Station type.\n";}
			}
			HDLC_XID_Tx(0x0B);
			$HDLC_Handshake = 1;
			$RR_Timer = 1;
			HDLC_RR_Tx();
		}
	}
}

sub HDLC_Tx{
	my ($Data) = @_;
	my $CRC;
	my $MSB;
	my $LSB;
	if ($Mode == 0) { #Serial mode.
		if ($HDLC_Verbose) {print "HDLC_Tx.\n";}
		if ($HDLC_Verbose > 1) {Bytes_2_HexString($Data);}
		$CRC = CRC_CCITT_Gen($Data);
		$MSB = int($CRC / 256);
		$LSB = $CRC - $MSB * 256;
		$Data = $Data . chr($MSB) . chr($LSB);
		# Byte Stuff
		$Data =~ s/\}/\}\]/g; # 0x7D to 0x7D 0x5D
		$Data =~ s/\~/\}\^/g; # 0x7E to 0x7D 0x5E
		if ($HDLC_Verbose >= 2) {print "Len(Data) = ", length($Data), "\n";}
		$SerialPort->write($Data . chr(0x7E));
		my $SerialWait = (8.0 / 9600.0) * length($Data); # Frame length delay.
		nanosleep($SerialWait * 1000000000);
		if ($HDLC_Verbose) {print "Serial nanosleep = $SerialWait\n";}
	}
	if ($Mode == 1) { # STUN mode.
		CiscoSTUN_Tx($Data);
	}
}

sub HDLC_Reset{
	if ($Mode == 0) {
		#$serialport->write(chr(0x7D) . chr(0xFF));
		$SerialPort->pulse_rts_on(50);
		$HDLC_TxTraffic = 0; 
		print "HDLC_Reset Sent.\n";
	}
}

sub HDLC_UA_Tx{
	my ($Address) = @_;
	if ($HDLC_Verbose) {print "HDLC_UA_Tx.\n";}
	my $Data = chr($Address) . chr(0x73);
	HDLC_Tx ($Data);
}

sub HDLC_XID_Tx{
	my ($Address) = @_;
	if ($HDLC_Verbose) {print "HDLC_XID_Tx.\n";}
	my $ID = 13;
	my $Data = chr($Address) . chr(0xBF) . chr(0x01) . chr($ID * 2 + 1) . chr(0x00) . chr(0x00) . chr(0x00) . chr(0x00) . chr(0x00) . chr(0xFF);
	HDLC_Tx ($Data);
}

sub HDLC_RR_Tx{
	my $Data;
	if ($HDLC_Verbose) {print "HDLC_RR_Tx.\n";}
	$Data = chr(253) . chr(0x01);
	HDLC_Tx ($Data);
}

sub Bytes_2_HexString{
	my ($Buffer) = @_;
	# Display Rx Hex String.
	#print "HDLC_Rx Buffer:              ";
	for (my $x = 0; $x < length($Buffer); $x++) {
		print sprintf(" %x", ord(substr($Buffer, $x, 1)));
	}
	print "\n";
}

sub HexString_2_Bytes{
	my ($Buffer) = @_;
	my $Data;
	for (my $x = 0; $x < length($Buffer); $x = $x + 6) {
		#print "Dat = " . substr($Buffer, $x, 4) . "\n";
		#print "Dat2 = " . sprintf("%d", hex(substr($Buffer, $x, 4))) . "\n";
		$Data = $Data . chr(sprintf("%d", hex(substr($Buffer, $x, 4))));
	}
	#print "Data Length =" . length($Data) . "\n";
	#Bytes_2_HexString($Data);
	return $Data;
}

sub CRC_CCITT_Gen{
	my ($Buffer) = @_;
	my $ctx = Digest::CRC->new(type=>"crcccitt");
	$ctx = Digest::CRC->new(width=>16, init=>0xFFFF, xorout=>0xFFFF,
	refout=>1, poly=>0x1021, refin=>1, cont=>0);
	$ctx->add($Buffer);
	my $digest = $ctx->digest;
	my $MSB = int($digest / 256);
	my $LSB = $digest - $MSB * 256;
	$digest = 256 * $LSB + $MSB;
	return $digest;
}



##################################################################
# Traffic control ################################################
##################################################################
sub Tx_to_Network{
	my ($Buffer) = @_;
	$DefaultTalkGroupTimer = time;
	if ( ($LinkedTalkGroup > 11 and $LinkedTalkGroup < 10100) 
	    or ($LinkedTalkGroup > 10599 and $LinkedTalkGroup < 65535)
	    or ($P25NX_Enabled and $Cisco_DMVPN_Enabled == 0
	      and ($LinkedTalkGroup >= 10100 and $LinkedTalkGroup < 10600)) ) { # Case MMDVM.
		HDLC_to_MMDVM($Buffer);
	}
	if ($P25NX_Enabled and $Cisco_DMVPN_Enabled
	    and ($LinkedTalkGroup >= 10100 and $LinkedTalkGroup < 10600)) { # case P25NX.
		HDLC_to_P25NX($Buffer);
	}
	if ($P25Link_Enabled) {
		HDLC_to_P25Link($Buffer);
	}
}

sub HDLC_to_MMDVM{
	my ($Buffer) = @_;
	switch (ord(substr($Buffer, 2 , 1))) {
		case 0x00 {
			switch  (ord(substr($Buffer, 6, 1))) {
				case 0x0C {
					MMDVM_Tx(chr(0x72) . chr(0x7B) . 
						chr(0x3D) . chr(0x9E) . chr(0x44) . chr(0x00)
					);
				}
				case 0x25 {
					MMDVM_Tx(chr(0x80) . chr(0x00). chr(0x00) .
						chr(0x00) . chr(0x00) . chr(0x00) . chr(0x00) .
						chr(0x00) . chr(0x00) . chr(0x00) . chr(0x00) .
						chr(0x00) . chr(0x00) . chr(0x00) . chr(0x00) .
						chr(0x00)
					);
				}
			}
		}
		case [0x62..0x73] {
			$Buffer = substr($Buffer, 2, length($Buffer)); # Here we remove first 2 Quantar Bytes.
			if ($Verbose) {print "HDLC_to_MMDVM output:\n";}
			if ($Verbose == 2) {Bytes_2_HexString($Buffer);}
			MMDVM_Tx($Buffer);
		}
		else {
			print "HDLC_to_MMDVM Error code " . hex(ord(substr($Buffer, 2, 1))) . "\n";
			Bytes_2_HexString($Buffer);
			return;
		}	
	}
}

sub HDLC_to_P25NX{
	my ($Buffer) = @_;
	my $Stun_Header = chr(0x08) . chr(0x31) . chr(0x00) . chr(0x00) . chr(0x00) .
		chr(2 + length($Buffer)) . chr($P25NX_STUN_ID); #STUN Header.
	$Buffer = $Stun_Header . $Buffer;
	#print "HDLC_to_P25NX.\n";
	P25NX_Tx($Buffer);
}

sub MMDVM_to_HDLC{
	my ($Buffer) = @_;
	if ($HDLC_Handshake == 0 or length($Buffer) < 1) {return;}
	if ($MMDVM_Verbose == 2) {
		print "MMDVM_to_HDLC In.\n";
		Bytes_2_HexString($Buffer);
	}
	my $Address = 0xFD; #0x07 or 0xFD
	$Tx_Started = 1;
	my $OpCode = ord(substr($Buffer, 0, 1));
	switch ($OpCode) {
		case [0x62..0x73] { # Use to bridge MMDVM to HDLC.
			$Buffer = chr($Address) . chr($C_UI) . $Buffer;
			if ($MMDVM_Verbose == 2) {
				print "MMDVM_to_HDLC Out:\n";
				Bytes_2_HexString($Buffer);
			}
			$HDLC_TxTraffic = 1;
			HDLC_Tx($Buffer);
		}
		case 0x80 {
			$Tx_Started = 0;
			my $RTRT;
			if ($RTRT_Enabled == 1) {
				$RTRT = $C_RTRT_Enabled;
			} else {
				$RTRT = $C_RTRT_Disabled;
			}
			HDLC_Tx(chr($Address) . chr($C_UI) . chr(0x00) . chr(0x02). chr($RTRT) .
				chr($C_EndTx) . chr($C_DVoice) . chr(0x00) . chr(0x00) . chr(0x00) .
				chr(0x00) . chr(0x00));
			HDLC_Tx(chr($Address) . chr($C_UI) . chr(0x00) . chr(0x02). chr($RTRT) .
				chr($C_EndTx) . chr($C_DVoice) . chr(0x00) . chr(0x00) . chr(0x00) .
				chr(0x00) . chr(0x00));
			$HDLC_TxTraffic = 0;
		}
	}
}

sub P25NX_to_HDLC{ # P25NX packet contains Cisco STUN and Quantar packet.
	my ($Buffer) = @_;
	$Buffer = substr($Buffer, 7, length($Buffer)); # Here we remove Cisco STUN.
	$HDLC_TxTraffic = 1;
	HDLC_Tx($Buffer);
# Add a 1s timer to $HDLC_TxTraffic = 0;
}


sub ChangeLinkedTG{
	my ($TalkGroup) = @_;
	if ($LinkedTalkGroup == $TalkGroup) {
		return;
	}
	print "Quant->AstroTalkGroup " . $Quant->AstroTalkGroup . "\n";
	print "Change Linked TG from " . $LinkedTalkGroup . " to " . $TalkGroup . ".\n";

	# Disconnect from current network.
	if ($MMDVM_Connected) {
		WriteUnlink();
		WriteUnlink();
		WriteUnlink();
	}
	if ($P25NX_Connected) {
		P25NX_Disconnect($LinkedTalkGroup);
	}
	if ($P25Link_Connected) {
#		P25Link_Disconnect($LinkedTalkGroup);
	}
	# Now connect to a network.
	if ( $MMDVM_Enabled
	    and ($TalkGroup > 10 and $TalkGroup < 10100) # MMDVM.
	    or ($P25NX_Enabled and $Cisco_DMVPN_Enabled == 0 
		and ($TalkGroup >= 10100 and $TalkGroup < 10600)) # MMDVM P25NX Ref. 
	    or ($TalkGroup >= 10600 and $TalkGroup < 65535)) { # MMDVM.
		# Search for TG data.
		for (my $Index = 0; $Index < $NumberOfReflectors; $Index++) { 
			if ($Links[$Index][1] eq $TalkGroup) {
				$ActiveLinkIndex = $Index;
			}
		}
		if ($MMDVM_Verbose) {
			print "ActiveLinkIndex = $ActiveLinkIndex\n";
		}
		$MMDVM_Addr->Address($Links[$ActiveLinkIndex][2]);
		$MMDVM_Addr->Port($Links[$ActiveLinkIndex][3]);
		# Connect to TG.
		if ($Verbose) {print "MMDVM Connecting to TG " . $Links[$ActiveLinkIndex][1] .
			" IP " . $MMDVM_Addr->Address .
			" Port " . $MMDVM_Addr->Port . "\n";
		}
		#print "Local Port " . $MMDVM_Sock->LocalHost . "\n";
		$MMDVM_Sock = IO::Socket::INET->new(
			LocalPort => $MMDVM_LocalPort,
			Proto => 'udp',
			Blocking => 0,
			Broadcast => 0,
			ReuseAddr => 1,
			PeerHost => $MMDVM_Addr->Address,
			PeerPort => $MMDVM_Addr->Port
		) or die "Can not Bind MMDVM : $@\n";
		$MMDVM_Sel = IO::Select->new($MMDVM_Sock);
		$MMDVM_Listen_Enable = 1;
		WritePoll();
		WritePoll();
		WritePoll();
	}
	if ($P25NX_Enabled and $Cisco_DMVPN_Enabled
	    and $TalkGroup >= 10100 and $TalkGroup < 10600) { # case P25NX.
		my $MulticastAddress = makeMulticastAddress($TalkGroup);
		if ($Verbose) {print "P25NX Connecting to " . $TalkGroup .
			" Multicast Addr. " . $MulticastAddress . "\n";
		}
			$P25NX_Sock = IO::Socket::Multicast->new(
			LocalHost => $MulticastAddress,
			LocalPort => $P25NX_LocalPort,
			Proto => 'udp',
			Blocking => 0,
			Broadcast => 1,
			ReuseAddr => 1,
			PeerPort => $P25NX_RemotePort
			)
			or die "Can not create Multicast : $@\n";
		$P25NX_Sel = IO::Select->new($P25NX_Sock);
		$P25NX_Sock->mcast_add($MulticastAddress);
		$P25NX_Sock->mcast_ttl(10);
		$P25NX_Sock->mcast_loopback(0);
		$P25NX_Connected = 1;	
	}
	if ($P25Link_Enabled
	    and $TalkGroup >= 10100 and $TalkGroup < 10600) { # case P25Link.
		
	}
	# Finalize link.
	$LinkedTalkGroup = $TalkGroup;
	$DefaultTalkGroupTimer = time;
	if ($UseVoicePrompts) {
		$VA_Message = $LinkedTalkGroup; # Linked TalkGroup.
		$Pending_VA = 1;
	}
	print "System Linked to TG " . $LinkedTalkGroup . "\n";
}


##################################################################
# MMDVM ##########################################################
##################################################################
sub WritePoll{
	my $Filler = chr(0x20);
	my $Data = chr(0xF0) . $Callsign;
	for (my $x = length($Data); $x < 11; $x++) {
		$Data = $Data . $Filler;
	}
	$MMDVM_Sock->send($Data);
	if ($MMDVM_Verbose) {
		print "WritePoll IP " . $MMDVM_Addr->Address .
			" Port " . $MMDVM_Addr->Port . "\n";
	}
}

sub WriteUnlink{
	my $Filler = chr(0x20);
	my $Data = chr(0xF1) . $Callsign;
	for (my $x = length($Data); $x < 11; $x++) {
		$Data = $Data . $Filler;
	}
	$MMDVM_Sock->send($Data);
	if ($MMDVM_Verbose) {
		print "WriteUnlink TG " . $LinkedTalkGroup .
			" IP " . $MMDVM_Addr->Address .
			" Port " . $MMDVM_Addr->Port . "\n";
	}
}

sub StrToHex{
	my ($Data) = @_;
	my $x;
	my $HexData = "";
	for ($x = 0; $x < length($Data); $x++) {
		$HexData = $HexData . " " . sprintf("0x%X", ord(substr($Data, $x, 1)));
	}
	print $HexData . "\n";
}

sub MMDVM_Rx{ # Only HDLC UI Frame. Start on Quantar v.24 Byte 3.
	my ($Buffer) = @_;
	my $x = 0;
	my $HexData = "";
	#if ($MMDVM_Verbose) {print "MMDVM_Rx Len(Buffer) = " . length($Buffer) . "\n";}
	if (length($Buffer) < 1) {return;}
	my $OpCode = ord(substr($Buffer, 0, 1));
	if ($MMDVM_Verbose) {print "MMDVM_Rx OpCode = " . sprintf("0x%X", $OpCode) . "\n";}
	switch ($OpCode) {
		case [0x62..0x73] { # Audio data.
			MMDVM_to_HDLC($Buffer); # Use to bridge MMDVM to HDLC.
		}
		case 0x80 { # End Tx.
			if ($MMDVM_Verbose) {print "MMDVM_Rx End Tx.\n";}
			MMDVM_to_HDLC($Buffer); # Use to bridge MMDVM to HDLC.

		}
		case 0xF0 { # Ref. Poll Ack.
			if ($MMDVM_Verbose) {print "MMDVM_Rx Poll Reflector Ack.\n";}
			$MMDVM_Connected = 1;
		}	
		case 0xF1 { # Ref. Disconnect Ack.
			if ($MMDVM_Verbose) {print "MMDVM_Rx Ref. Disconnect Ack Rx.\n";}
			$MMDVM_Connected = 0;
			$MMDVM_Listen_Enable = 0;
		}
		case 0xF2 { # Start of Tx.
			if ($MMDVM_Verbose) {print "MMDVM_Rx 0xF2.\n";}
		} else {
			print "MMDVM_Rx else " . hex(ord(substr($Buffer, 0, 1))) ." Else Len=" . length($Buffer) . "\n";
		}
	}
}

sub MMDVM_Tx{
	my ($Buffer) = @_;
	$MMDVM_Sock->send($Buffer);
}

##################################################################
# P25NX ##########################################################
##################################################################
sub P25NX_Disconnect{
	my ($TalkGroup) = @_;
	if ($TalkGroup > 10099 and $TalkGroup < 10600){
		my $MulticastAddress = makeMulticastAddress($TalkGroup);
		$P25NX_Sock ->mcast_drop($MulticastAddress);
	}
	$P25NX_Connected = 0;
	print "P25NX TG " . $TalkGroup . " disconnected.\n";
}

sub makeMulticastAddress{
	my ($TG) = @_;
	my $x = $TG - 10099;
	my $b = 0;
	my $c = 0;
	my $i;
	my $Region;
	my $ThisAddress;
	for ($i = 1; $i < 1000; $i++) {
		if ($x < 254) {
			$c = $x;
		} else {
			$x = $x - 254;
			$b = $b + 1;
		}
	}
	$Region = substr($TG, 2, 1);
	$ThisAddress = "239." . $Region . "." . $b . "." . $c;
	#if ($Verbose) {print "makeMulticastAddress = " . $ThisAddress . "\n";}
	return $ThisAddress;
}

sub P25NX_Rx{
	my ($Buffer) = @_;
	if (length($Buffer) < 1) {return;}
	#if ($Verbose) {print "PNX_Rx\n";} if ($Verbose) {print "PNX_Rx HexData = " . StrToHex($Buffer) . "\n";}
	#MMDVM_Tx(substr($Buffer, 9, length($Buffer)));
	P25NX_to_HDLC($Buffer);

}

sub P25NX_Tx{ # This function expect to Rx a formed  Cisco STUN Packet.
	my ($Buffer) = @_;
	# Tx to the Network.
	if ($P25NX_Verbose >= 2) {print "P25NX_Tx Message " . StrToHex($Buffer) . "\n";}
	my $MulticastAddress = makeMulticastAddress($LinkedTalkGroup);
	my $P25NX_Tx_Sock = IO::Socket::Multicast->new(
		LocalHost => $MulticastAddress,
		LocalPort => $P25NX_LocalPort,
		Proto => 'udp',
		Blocking => 0,
		Broadcast => 1,
		ReuseAddr => 1,
		PeerPort => $P25NX_RemotePort
		)
		or die "Can not create Multicast : $@\n";
	$P25NX_Tx_Sock->mcast_ttl(10);
	$P25NX_Tx_Sock->mcast_loopback(0);
	$P25NX_Tx_Sock->mcast_send($Buffer, $MulticastAddress . ":" . $P25NX_RemotePort);
	$P25NX_Tx_Sock->close;
	if ($P25NX_Verbose) {
		print "P25NX_Tx TG " . $LinkedTalkGroup . " IP Mcast " . $MulticastAddress . "\n";
	}
	if ($P25NX_Verbose) {print "P25NX_Tx Done.\n";}
}

#################################################################################
# Main Loop #####################################################################
#################################################################################
sub MainLoop{
	for (;;) {
		(my $sec, my $min, my $hour, my $mday, my $mon, my $year, my $wday, my $yday, my $isdst) = localtime();
		$TickCount = $SerialPort->get_tick_count();
		# HDLC Receive Ready keep alive.
		my $RR_Timeout = $RR_NextTimer - time;
		if ($RR_Timer = 1 && $RR_Timeout <= 0) {
			#print $hour . ":" . $min . ":" . $sec . " Send RR by timer.\n"; 
			#warn "RR Timed out @{[int time - $^T]}\n";
			if ($Mode < 2 and $HDLC_TxTraffic == 0) {
				HDLC_RR_Tx();
			}
			$RR_NextTimer = $RR_TimerInterval + time;
		}
		# Serial Port Receiver.
		if ($Mode == 0) {
			Read_Serial();
		}
		# MMDVM WritePoll becon.
		my $MMDVM_Timeout = $MMDVM_Poll_NextTimer - time;
		#if ($Verbose) {print "Countdown to send WritePoll = " . $MMDVM_Timeout . "\n";}
		if ($MMDVM_Timeout <= 0) {
			#print $hour . ":" . $min . ":" . $sec . " Sending WritePoll beacon.\n";
			#warn "MMDVM_Poll Timed out @{[int time - $^T]}\n";
			if ($MMDVM_Connected) {
				WritePoll();
			}
			$MMDVM_Poll_NextTimer = $MMDVM_Poll_Timer_Interval + time;
		}
		# MMDVM Receiver.
		if ($MMDVM_Listen_Enable) {
			for my $MMDVM_fh ($MMDVM_Sel->can_read(0.001)) {
				$MMDVM_RemoteHost = $MMDVM_fh->recv(my $MMDVM_Buffer, $MaxLen);
				$MMDVM_RemoteHost = $MMDVM_fh->peerhost;
				if ($MMDVM_Verbose) {print "MMDVM_LocalHost = " . $MMDVM_LocalHost . "\n";}
				if (($MMDVM_RemoteHost cmp $MMDVM_LocalHost) != 0) {
					#if ($Verbose) {print $hour . ":" . $min . ":" . $sec .
					#	" " . $MMDVM_RemoteHost .
					#	" MMDVM Data len(" . length($MMDVM_Buffer) . ")\n";}
					MMDVM_Rx($MMDVM_Buffer);
				}
			}
		}
		# P25NX Receiver
		if ($P25NX_Connected) {
			for my $P25NX_fh ($P25NX_Sel->can_read(0.001)) {
				$P25NX_RemoteHost = $P25NX_fh->recv(my $P25NX_Buffer, $MaxLen);
				$P25NX_RemoteHost = $P25NX_fh->peerhost;
				#if ($Verbose) {print "P25NX_LocalHost = " . $PNX_LocalHost . "\n";}
				my $MulticastAddress = makeMulticastAddress($LinkedTalkGroup);
				if (($P25NX_RemoteHost cmp $MulticastAddress) != 0) {
					if ($Verbose) {print $hour . ":" . $min . ":" . $sec .
						" " . $P25NX_RemoteHost .
						" P25NX Data len(" . length($P25NX_Buffer) . ")\n";
					}
					P25NX_Rx($P25NX_Buffer);
				}	
			}
		}
		# Default Talk Group timeout.
		if ($LinkedTalkGroup != $DefaultTalkGroup 
			and $DefaultTalkGroupTimeout > 0 
			and $DefaultTalkGroupTimer + $DefaultTalkGroupTimeout * 60  <=  time) {
			print "Default Talk Group Timeout.\n";
			$DefaultTalkGroupTimer = time;
			ChangeLinkedTG($DefaultTalkGroup);
			if ($UseVoicePrompts) {
				$VA_Message = 1; # Default Revert.
				$Pending_VA = 1;
			}
		}
		# End of Tx timmer (1 sec).
		if ($Quant->LocalRx and ($Quant->LocalRx_Time + 1000 >= $TickCount)) {
			$Quant->LocalRx(0);
		}


		# Voice Announce.
		if ($HDLC_Handshake and $Quant->LocalRx == 0 and $Pending_VA) {
			SaySomething($VA_Message);
			$Pending_VA = 0;
		}



#		if ($Mode == 0) {
#			$TickCount = sprintf("%d", $SerialPort->get_tick_count());
#			if ($TickCount > $FutureTickCount){
#				if ($UseVoicePrompts) {SaySomething(0);}
#				$FutureTickCount = $TickCount + 10000;
#			}
			#my $FutureTick = sprintf("%d", $SerialPort->get_tick_count()) + 1000;
			#print "TickCount = " . $SerialPort->get_tick_count() . " <-> " . $FutureTick . "\n";
#		}
	}
}

sub SaySomething{
	my ($ThingToSay) = @_;
	my @Speech;
	print "Voice Announcement running.\n";
	$HDLC_TxTraffic = 1;
	switch ($ThingToSay) {
		case 0x00 {
			@Speech = @Speech_SystemStart;
		}
		case 0x01 {
			@Speech = @Speech_DefaultRevert;
		}
		case 0x02 {
			@Speech = @HDLC_TestPattern;
		}
		case 10100 {
			@Speech = @Speech_WW;
		}
		case 10101 {
			@Speech = @Speech_WWTac1;
		}
		case 10102 {
			@Speech = @Speech_WWTac2;
		}
		case 10103 {
			@Speech = @Speech_WWTac3;
		}
		case 10200 {
			@Speech = @Speech_NA;
		}
		case 10201 {
			@Speech = @Speech_NATac1;
		}
		case 10202 {
			@Speech = @Speech_NATac2;
		}
		case 10203 {
			@Speech = @Speech_WWTac3;
		}
		case 10300 {
			@Speech = @Speech_Europe;
		}
		case 10301 {
			@Speech = @Speech_EuTac1;
		}
		case 10302 {
			@Speech = @Speech_EuTac2;
		}
		case 10303 {
			@Speech = @Speech_EuTac3;
		}
		case 10310 {
			@Speech = @Speech_France;
		}
		case 10320 {
			@Speech = @Speech_Germany;
		}
		case 10400 {
			@Speech = @Speech_Pacific;
		}
		case 10401 {
			@Speech = @Speech_PacTac1;
		}
		case 10402 {
			@Speech = @Speech_PacTac2;
		}
		case 10403 {
			@Speech = @Speech_PacTac3;
		}
	}
	for (my $x = 0; $x < scalar(@Speech); $x++) {
		$Message = HexString_2_Bytes($Speech[$x]);
		HDLC_Tx($Message);
		my $SerialWait = (8.0 / 9600.0) * 1; # 1 Byte length delay for VA.
		nanosleep($SerialWait * 1000000000);
	}
	$HDLC_TxTraffic = 0;
	print "  Voice Announcement done.\n";
}


sub Pin5_Interrupt_Handler {
    print "Pin5 Interrupt Handler.\n";
}


