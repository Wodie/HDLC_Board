#!/usr/bin/perl

# Quantar HDLC to Serial.

use strict;
use warnings;
use Switch;
use Digest::CRC;
use Device::SerialPort;
use Socket;
use IO::Socket;
use IO::Select;


my $me = 'QSerial';
my $VERSION = '1.00';
my $Callsign = "XE1F";

my $RRTimer = 0;
my $RR_Time = time;
my $HDLC_Handshake = 0;
my $SABM_Counter = 0;
my $Message = "";
my $Quantar = 0xC2;
my $DIU3000 = 0x00;
my $UI = 0x03;
my $DVoice = 0x0B;
my $RTRT_E = 0x02;
my $EndTx = 0x25;
my $HDLC_Buffer = "";
my $RR_Timer = 0;


# Init Serial Port.
my $serialport = Device::SerialPort->new("/dev/ttyUSB0") || die "Cannot init serial port : $!\n";
$serialport->baudrate(19200);
$serialport->databits(8);
$serialport->parity("none");
$serialport->stopbits(1);
$serialport->handshake("xoff");
$serialport->buffers(4096, 4096);
$serialport->datatype('raw');
$serialport->write_settings;

# Init UDP.
my $WritePollTimer = 1;
my $WritePoll_Time = time;
my $P25Gtw_Connected = 1;
my $P25_Gtw_Linked_TG = 5995;
my $P25GtwHost = "192.168.1.100";
my $P25GtwLocalPort = 42010;
my $P25GtwSocket; 

my $Client1 = new IO::Socket::INET(
	PeerAddr => "192.168.1.100",
	PeerPort => 42010,
	Proto => 'udp');
my $Client2 = new IO::Socket::INET(
	PeerAddr => "192.168.1.33",
	PeerPort => 42010,
	Proto => 'udp');

my $select = new IO::Select();
$select->add($Client1);
$select->add($Client2);

my @sockets_ready;
my $socket;
my $answer;


socket($P25GtwSocket, PF_INET, SOCK_DGRAM, getprotobyname("udp")) 
	or die "socket: $!";
my $P25GtwPort = 41010;
bind($P25GtwSocket, sockaddr_in($P25GtwPort, INADDR_ANY))
	or die "Can't bind socket to port $P25GtwPort.\n";
my $handle = IO::Socket::INET->new(Proto => 'udp') or die "socket $@";
my $ipaddr = inet_aton($P25GtwHost);
my $portaddr = sockaddr_in($P25GtwPort, $ipaddr);

##### MAIN ##############
MAIN();
sub MAIN
{
print "Quantar v.24 to MMDVM.\n";
print "Version $VERSION\n";
print "By Juan Carlos Perez (Wodie) KM4NNO XE1F.\n\n";

WritePoll();
WritePoll();
WritePoll();

# Default values.
HDLC_Reset();
my $HDLC_Buffer = "";
my $RR_Timer = 0;

# Main LOOP.
my $Run = 1;
while ($Run == 1)
{
#	print "While... \n";
	Read_Serial();
	Read_Socket();


	# RR Timer every 5 seconds.
	if ($RRTimer == 1 && time - $RR_Time >= 5)
	{
		$RR_Time = time;
		RR_Tx();
	}
	# WritePoll Timer every 5 seconds.
	if ($WritePollTimer == 1 && time - $WritePoll_Time >= 5)
	{
		$WritePoll_Time = time;
		WritePoll();
	}


#	sleep(1);	
}

$serialport->close || die "Failed to close Serial Port\n";

print "Goodbye cruel world..\n";
return 0;
}





sub Read_Socket
{
#	my $Buffer;
#	@sockets_ready = $select->can_read(0.0);
#	if (! scalar(@sockets_ready))
#	{
#		print "Timeout.\n";
#	} else {
#		foreach $socket (@sockets_ready)
#		{
#			my $retValue = recv($socket, $Buffer, 1024, 0);
#			if (! $retValue)
#			{
#			print "Error Reading from socket: $!\n";
#			}else {
#				print "Message read: $Buffer\n";
#				process_message($socket, $Buffer);
#			}
#		}
#	}
#	return 0;
}

sub process_message
{
	my $client = shift;
	my $Buffer = shift;
}




sub WritePoll
{
	my $Data;
	my $Filler;
#	if (
	$Filler = chr(0x20) . chr(0x20) . chr(0x20) . chr(0x20) . chr(0x20) . chr(0x20) .
		 chr(0x20) . chr(0x20) . chr(0x20) . chr(0x20) . chr(0x20);
	$Data = $Callsign . $Filler;
	$Data = chr(0xF0) . substr($Data, 0, 11);
	# Send UDP data.
	$ipaddr = inet_aton($P25GtwHost);
	$portaddr = sockaddr_in($P25GtwPort, $ipaddr);
	send($P25GtwSocket, $Data, 0, $portaddr) == length($Data) or 
		die "Cannot send to $P25GtwHost($P25GtwPort)): $!";
	$ipaddr = inet_aton("192.168.1.2");
	$portaddr = sockaddr_in($P25GtwPort, $ipaddr);
	send($P25GtwSocket, $Data, 0, $portaddr) == length($Data) or
		die "Cannot send to $P25GtwHost($P25GtwPort)): $!";
	print "WritePoll_Tx\n";
	return 0;
}

sub WriteUnlink
{
	my $Data;
	my $Filler;
#	if (
	$Filler = chr(0x20) . chr(0x20) . chr(0x20) . chr(0x20) . chr(0x20) . chr(0x20) .
	chr(0x20) . chr(0x20) . chr(0x20) . chr(0x20) . chr(0x20);
	$Data = $Callsign . $Filler;
	$Data = chr(0xF1) . substr($Data, 0, 11);
	# Send UDP data.
	$ipaddr = inet_aton($P25GtwHost);
	$portaddr = sockaddr_in($P25GtwPort, $ipaddr);
	send($P25GtwSocket, $Data, 0, $portaddr) == length($Data) or
	die "Cannot send to $P25GtwHost($P25GtwPort)): $!";
	$ipaddr = inet_aton("192.168.1.2");
	$portaddr = sockaddr_in($P25GtwPort, $ipaddr);
	send($P25GtwSocket, $Data, 0, $portaddr) == length($Data) or
	die "Cannot send to $P25GtwHost($P25GtwPort)): $!";
	print "WriteUnlink_Tx.\n";
	return 0;
}

sub P25Gtw_Rx
{
	my ($Buffer) = @_;
	my $x;
	my $OpCode = ord(substr($Buffer, 0, 1));
	if ($OpCode != 0xF0 || $OpCode != 0xF1 || $OpCode != 0xF2)
	{
	 	Ref_DVoice_Tx ($P25_Gtw_Linked_TG, $Buffer);
	}
	if ($OpCode == 0xF0)
	{
		$P25Gtw_Connected = 0;
	}
	if ($OpCode == 0xF1)
	{
		$P25Gtw_Connected = 1;
	}
	return 0;
}

sub P25Gtw_Tx	# Only HDLC UI Frame. Start on Quantar v.24 Byte 3.
{
	my ($Buffer) = @_;
	$Buffer = substr($Buffer, 2, length($Buffer));
	# Send UDP data.
	$ipaddr = inet_aton($P25GtwHost);
	$portaddr = sockaddr_in($P25GtwPort, $ipaddr);
	send($P25GtwSocket, $Buffer, 0, $portaddr) == length($Buffer) or
	die "Cannot send to $P25GtwHost($P25GtwPort)): $!";
	$ipaddr = inet_aton("192.168.1.2");
	$portaddr = sockaddr_in($P25GtwPort, $ipaddr);
	send($P25GtwSocket, $Buffer, 0, $portaddr) == length($Buffer) or
		die "Cannot send to $P25GtwHost($P25GtwPort)): $!";
	#print "P25Gtw_Tx.\n";
	return 0;
}

sub Ref_DVoice_Tx
{
	my ($Buffer) = @_;
	my $Address = 0x07;
	my $RTRT = $RTRT_E;
	if ($HDLC_Handshake == 0)
	{
		print "Ref_DVoice_Tx Exit cause no HDLC handshake.\n";
		return 0;
	}
	if (ord(substr($Buffer, 0, 1)) == 0x80)
	{
		HDLC_Tx( chr($Address) . chr($UI) . $Buffer);  
	} else {
		HDLC_Tx( chr($Address) .  chr($UI) . chr(0x00) . chr(0x02) . chr($RTRT) . 
			chr($EndTx) . chr($DVoice) .chr(0x00) . chr(0x00) . chr(0x00) . 
			chr(0x00) . chr(0x00));
		HDLC_Tx( chr($Address) .  chr($UI) . chr(0x00) . chr(0x02) . chr($RTRT) .
			chr($EndTx) . chr($DVoice) .chr(0x00) . chr(0x00) . chr(0x00) .
			chr(0x00) . chr(0x00));
	}
	return 0;
}

























sub Read_Serial
{
	my $NumChars;
	my $SerialBuffer;
	($NumChars, $SerialBuffer) = $serialport->read(1);
	if ($SerialBuffer) { #Perl data Arrival test.
		#print "Serial NumChars = $NumChars\n";
		#print "Data Rx len() = ", length($SerialBuffer), "\n";
		for (my $x = 0; $x < length($SerialBuffer); $x++)
		{
			if (ord(substr($SerialBuffer, $x, 1)) == 0x7E)
			{
				if (length($HDLC_Buffer) > 0)
				{
					HDLC_Rx($HDLC_Buffer);
				}
				#print "Read_Serial len = ", length($HDLC_Buffer), "\n";		
				$HDLC_Buffer = "";
			} else {
				$HDLC_Buffer = $HDLC_Buffer . substr($SerialBuffer, $x, 1);
			}
		}
	}
}

sub HDLC_Rx {
	my ($Buffer) = @_;
	# CRC CCITT test patterns
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

	if (substr($Buffer, 0, 7) eq "!RESET!")
	{
		my $BoardID = ord(substr($Buffer, 7, 1));	
		print "HDLC_Rx Board $BoardID made a Reset!\n";
		return 0;
	}

	# Byte Stuff
	$Buffer =~ s/\}\^/\~/g; # 0x7D 0x5E to 0x7E 	
	$Buffer =~ s/\}\]/\}/g; # 0x7D 0x5D to 0x7D
	#print "Len(Buffer) = ", length($Buffer), "\n";

	# Show Raw data.
	#Bytes_2_HexString($Buffer);

	# CRC CCITT.
	if (length($Buffer) < 2)
	{
		print "HDLC_Rx Buffer < 2 Bytes.\n";
		return 0;
	}
	$Message = substr($Buffer, 0, length($Buffer) - 2);
	#print "Len(Message) = ", length($Message), "\n";
	my $CRC_Rx = 256 * ord(substr($Buffer, length($Buffer) - 2, 1 )) + ord(substr($Buffer, length($Buffer) - 1, 1));
	#print "CRC_Rx = $CRC_Rx\n";
	if (length($Message) == 0)
	{
		print "HDLC_Rx Message is Null.\n";
		return 0;
	}
	my $CRC_Gen = CRC_CCITT_Gen($Message);
	#print "CRC_Gen = $CRC_Gen\n";
	#print "CRCH ", sprintf("0x%x", ord(substr($CRC_Calc, 0, 1))), "\n";
	#print "CRCL ", sprintf("0x%x", ord(substr($CRC_Calc, 1, 1))), "\n";
	#print "Calc CRC16 in hex: ", unpack('H*', pack('S', $Message)), "\n";
	if ($CRC_Rx != $CRC_Gen)
	{
		print "HDLC_Rx CRC does not match.\n";
		return 0;
	}
	#my $HexData = Str_2_Hex($Message);
	#print "HDLC_Rx Message Rx $HexData\n";

	# Process data:
	# 01 Address
	my $Address = ord(substr $Message, 0, 1);
	#print "Address = ", sprintf("0x%x", $Address), "\n";

	my $FrameType = ord(substr $Message, 1, 1);
	#print "Frame Types = ", sprintf("0x%x", $FrameType), "\n";
	switch ($FrameType)
        {
                case 0x01 # RR.
                {
                        if ($Address == 253)
                        {
				#$RR_Timer = 1;
                                $HDLC_Handshake = 1;
                        } else
                        {
                                print "HDLC_Rx RR Address 253 != $Address\n";
                        }
                }
                case 0x03 # User Information.
                {
			#print "Case 0x03 UI.", substr($Message, 2, 1), "\n";
			P25Gtw_Tx($Buffer);
                }
                case 0x3F # SABM Rx
                {
                       print "HDLC_Rx SABM.\n";
                        $HDLC_Handshake = 0;
			$RRTimer = 0;
			UA_Tx (253);
			$SABM_Counter = $SABM_Counter + 1;
			if ($SABM_Counter > 3)
                        {
#				HDLC_Reset();
				$SABM_Counter = 0;
                        }
                }
                case 0x73 #
                {
                       print "Case 0x73 Unumbered Ack.\n";
                }
                case 0xBF # XID Quantar to DIU identification packet.
                {
			print "HDLC_Rx XID.\n";
			$SABM_Counter = 0;
			my $MessageType = ord(substr($Message, 2, 1));
			my $StationSiteNumber = (int(ord(substr($Message, 3, 1))) - 1) / 2;
			my $StationType = ord(substr($Message, 4, 1));
			if ($StationType == $Quantar)
			{
				print "HDLC_Rx Quantar Station type.\n";
			}
			if ($StationType == $DIU3000)
			{
				print "HDLC_Rx DIU 3000 Station type.\n";
			}	

			XID_Tx (0x0B);
                        $HDLC_Handshake = 1;
			$RRTimer = 1;
			RR_Tx();
                }

        }
}



sub HDLC_Tx
{
        my ($Data) = @_;
	my $CRC;
	my $MSB;
	my $LSB;
	$CRC = CRC_CCITT_Gen($Data);
	$MSB = int($CRC / 256);
	$LSB = $CRC - $MSB * 256; 
	#print "HDLC_Tx.\n";
	$Data = $Data . chr($MSB) . chr($LSB);
	# Byte Stuff
	$Data =~ s/\~/\}\^/g; # 0x7E to 0x7D 0x5E
	$Data =~ s/\}/\}\]/g; # 0x7D to 0x7D 0x5D
	#print "Len(Data) = ", length($Data), "\n";
        $serialport->write(chr(0x7E) . $Data . chr(0x7E));
}

sub HDLC_Reset
{
	#$serialport->write(chr(0x7D) . chr(0xFF));
	$serialport->pulse_rts_on(50);
	print "HDLC_Reset Sent.\n";
}

sub UA_Tx
{
	my ($Address) = @_;
	my $Data;
	$Data = chr($Address) . chr(0x73);
	HDLC_Tx ($Data);
	print "UA_Tx Sent.\n";
}

sub XID_Tx
{
        my ($Address) = @_;
	my $Data;
	my $ID = 13;
	$Data = chr($Address) . chr(0xBF) . chr(0x01) . chr($ID * 2 + 1) . chr(0x00) . chr(0x00) . chr(0x00) . chr(0x00) . chr(0x00) . chr(0xFF);
	HDLC_Tx ($Data);
	print "XID_Tx Sent.\n";
}


sub RR_Tx
{
        my $Data;
	$Data = chr(253) . chr(0x01);
       HDLC_Tx ($Data);
}


sub Bytes_2_HexString
{
	my ($Buffer) = @_;
	# Display Rx Hex String.
	#print "HDLC_Rx Buffer:              ";
	for (my $x = 0; $x < length($Buffer); $x++)
	{
	print sprintf(" %x", ord(substr($Buffer, $x, 1)));
	}
	print "\n";
	return 0;
}

sub CRC_CCITT_Gen
{
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

sub Str_2_Hex
{
	my ($Data) = @_;
	my $HexData;
	for (my $x = 0; $x <= length($Data); $x++)
	{
#		$HexData = $HexData . chr(32) . hex(ord(substr($Data, $x, 1)));
	}
}

sub HexStr_2_Str
{
	my ($DataC) = @_;
	my $DataS;
	#print "HexStr_2_Str in $DataC\n";
	#my $len = length($DataC);
	#print "HexStr_2_Str len = $len\n";
	for (my $x = 1; $x <= length($DataC) /2 - 2; $x++ )
	{
		$DataS = $DataS . chr(hex(substr($DataC, $x * 2 + 1, 2)));
		#$out = hex(substr($DataC, $x * 2, 2));
		#print"$x & 0x$out\n";
	}
	#print "HexStr_2_Str out $DataS\n";
	return $DataS;
}




