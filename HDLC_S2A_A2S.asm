;************************************************************************
;																		*
;	Filename:	    HDLC S2A A2S v35.asm								*
;	Date:			Nov 10, 2018.										*
;	File Version:	3.5													*
;																		*
;	Author:		Juan Carlos Pérez De Castro (Wodie)	KM4NNO / XE1F		*
;	Project advisor:	Bryan Fiels W9CR								*
;																		*
;	This software is licenced under the GPL v3 and is intended for		*
;	amateur and educational use only. If you intend to use this			*
;	software for commercial purposes please get a writen permission		*
;	from Juan Carlos Pérez De Castro.									*
;																		*
;************************************************************************
;																		*
;	Files Required: P16F887.INC											*
;																		*
;************************************************************************
;																		*
;	Notes:																* 
;	S>A HDLC & A>S HDLC versions merged for only one PIC.				*
;	Memory extended to support TMS.										*
;	RS-232 port speed needs to be 19,200.								*
;																		*
;  ***	Missing:														*
;	Deep testing.														*
;																		*
;************************************************************************
	Title	"S>A HDLC & A>S HDLC interface for P25NX Quantar"

	#include	<p16f887.inc>	; processor specific variable definitions
	__CONFIG    _CONFIG1, _HS_OSC & _WDT_ON & _PWRTE_ON & _CP_ON & _CPD_OFF & _LVP_OFF & _MCLRE_ON & _FCMEN_ON & _IESO_OFF & _BOR_OFF & _DEBUG_OFF 
	__CONFIG    _CONFIG2, _WRT_OFF & _BOR21V
	list		p=16f887	; list directive to define processor

	RADIX	DEC

;*****GLOBAL DECLARATIONS	**************************************
#DEFINE	BANK0	BCF	STATUS,RP0 	; TO CHANGE RP0 TO BANK 0 OR BANK 2
#DEFINE	BANK1	BSF	STATUS,RP0 	; TO CHANGE RP0 TO BANK 1 OR BANK 3
#DEFINE	BANK0X	BCF	STATUS,RP1 	; TO CHANGE RP1 TO SHIFT BANKS 0 & 1
#DEFINE	BANK1X	BSF	STATUS,RP1 	; TO CHANGE RP1 TO SHIFT BANKS 2 & 3
#DEFINE	CARRY	STATUS,C		; MEMONIC FOR CARRY
#DEFINE	ZERO	STATUS,Z		; MEMONIC FOR ZERO
#DEFINE	SRxGLED	PORTA,2			; Green LED
#DEFINE	SRxRLED	PORTA,3			; Red LED
#DEFINE	ARxGLED	PORTA,0			; Green LED
#DEFINE	ARxRLED	PORTA,1			; Red LED

#DEFINE RxClock	PORTB,0			; Quantar Master Clock Output.
#DEFINE	RxPin	PORTB,1			; Data Rx from Quantar.
;#DEFINE	TxClock	PORTB,2			; Data Clock to Quantar.
#DEFINE	TxPin	PORTB,3			; Data Tx to Quantar.

#DEFINE	ServiceFlag		BITS1,0		; Developer debug mode flag.
#DEFINE	SRxFiveOnes		BITS1,1		; S to A HDLC flags.
#DEFINE	SRxSixOnes		BITS1,2		; ////
#DEFINE	SRxSevenOnes	BITS1,3		; ///
#DEFINE	SDummyZeroFlag	BITS1,4		; //
#DEFINE SRxComplete		BITS1,5		; /

#DEFINE EscapeCharFlag	BITS2,0		; A to S HDLC flags.
#DEFINE	TxBitRAM		BITS2,1		; ///
#DEFINE HeaderBeingTx	BITS2,2		; //
#DEFINE	WritingBuffer	BITS2,3		; /
#DEFINE DataReady		BITS2,4		; /
#DEFINE AddZeroBit		BITS2,5		; /

#DEFINE	SHeaderRx		BITS3,0
#DEFINE	FooterWasTx		BITS3,1

;*****	Define program constants
	INT_RAM		EQU	H'20'	; 96 General Porpouse registers 0x20 thru 0x7F.
	COMMON_RAM1	EQU	H'28'
	COMMON_RAM2	EQU	H'A0'	; F0 thru FF are common Access RAM.
	COMMON_RAM3	EQU	H'120'	; //
	COMMON_RAM4	EQU	H'1A0'	; /
	Osc_Freq	EQU	20000000; 20 MHz
	Baud_Rate	EQU	19200; 19.2 Kbauds
	Baud_Rate_Const	EQU	(Osc_Freq/(16*Baud_Rate))-1

	; Define HDLC constants.
	StartFlag	EQU	0x7E	; B'01111110' Flag for HDLC Header/Footer.
	EscapeOct	EQU	0x7D	; B'01111101' Escape Octet.


;*****	SET UP RAM	***************************************
;***	Define interrupt handler variables
	CBLOCK INT_RAM
	W_TEMP
	S_TEMP
	P_TEMP
	FSR_TEMP
	ENDC
;***	DEFINE RAM 1
	CBLOCK COMMON_RAM1
	BITS1		; Bit variables
	BITS2		; Bit variables
	BITS3		; Sync: Bit variables
	BitIndex	; HDLC Rx bit position
	OnesCount	; Continous 1 counter
	SRxByte		; Sync: RAM for the HDLC Rx Byte	
	ATxByte		; Async: Byte to be Tx via RS-232	

	ABufferInLen; Counter for Async Bytes Rx.
	SBufferOutLen; Counter for Sync Bytes to Tx.
	DataIndex	; Counter of Bytes Tx (table position index).
	ABufferIn0	; These are the RAM Bytes used to Rx
	ABufferIn1	; from Async HDLC.
	ABufferIn2
	ABufferIn3
	ABufferIn4
	ABufferIn5
	ABufferIn6
	ABufferIn7
	ABufferIn8
	ABufferIn9
	ABufferIn10
	ABufferIn11
	ABufferIn12
	ABufferIn13
	ABufferIn14
	ABufferIn15
	ABufferIn16
	ABufferIn17
	ABufferIn18
	ABufferIn19
	ABufferIn20
	ABufferIn21
	ABufferIn22
	ABufferIn23
	ABufferIn24
	ABufferIn25
	ABufferIn26
	ABufferIn27
	ABufferIn28
	ABufferIn29
	ABufferIn30
	ABufferIn31

	SBufferOut0	; These are the RAM Bytes used to Tx
	SBufferOut1	; to Sync HDLC.
	SBufferOut2
	SBufferOut3
	SBufferOut4
	SBufferOut5
	SBufferOut6
	SBufferOut7
	SBufferOut8
	SBufferOut9
	SBufferOut10
	SBufferOut11
	SBufferOut12
	SBufferOut13
	SBufferOut14
	SBufferOut15
	SBufferOut16
	SBufferOut17
	SBufferOut18
	SBufferOut19
	SBufferOut20
	SBufferOut21
	SBufferOut22
	SBufferOut23
	SBufferOut24
	SBufferOut25
	SBufferOut26
	SBufferOut27
	SBufferOut28
	SBufferOut29
	SBufferOut30
	SBufferOut31

	ARxByte

	TxBitIndex
	TxOnesCount
	TxByteIndex
	SyncTxByte

	Testing
	ENDC
;***	DEFINE RAM 2
	CBLOCK COMMON_RAM2
	ABufferIn32
	ABufferIn33
	ABufferIn34
	ABufferIn35
	ABufferIn36
	ABufferIn37
	ABufferIn38
	ABufferIn39
	ABufferIn40
	ABufferIn41
	ABufferIn42
	ABufferIn43
	ABufferIn44
	ABufferIn45
	ABufferIn46
	ABufferIn47
	ABufferIn48
	ABufferIn49
	ABufferIn50
	ABufferIn51
	ABufferIn52
	ABufferIn53
	ABufferIn54
	ABufferIn55
	ABufferIn56
	ABufferIn57
	ABufferIn58
	ABufferIn59
	ABufferIn60
	ABufferIn61
	ABufferIn62
	ABufferIn63
	ABufferIn64
	ABufferIn65
	ABufferIn66
	ABufferIn67
	ABufferIn68
	ABufferIn69
	ABufferIn70
	ABufferIn71

	SBufferOut32
	SBufferOut33
	SBufferOut34
	SBufferOut35
	SBufferOut36
	SBufferOut37
	SBufferOut38
	SBufferOut39
	SBufferOut40
	SBufferOut41
	SBufferOut42
	SBufferOut43
	SBufferOut44
	SBufferOut45
	SBufferOut46
	SBufferOut47
	SBufferOut48
	SBufferOut49
	SBufferOut50
	SBufferOut51
	SBufferOut52
	SBufferOut53
	SBufferOut54
	SBufferOut55
	SBufferOut56
	SBufferOut57
	SBufferOut58
	SBufferOut59
	SBufferOut60
	SBufferOut61
	SBufferOut62
	SBufferOut63
	SBufferOut64
	SBufferOut65
	SBufferOut66
	SBufferOut67
	SBufferOut68
	SBufferOut69
	SBufferOut70
	SBufferOut71
	ENDC
;***	DEFINE RAM 3
	CBLOCK COMMON_RAM3
	ABufferIn72
	ABufferIn73
	ABufferIn74
	ABufferIn75
	ABufferIn76
	ABufferIn77
	ABufferIn78
	ABufferIn79
	ABufferIn80
	ABufferIn81
	ABufferIn82
	ABufferIn83
	ABufferIn84
	ABufferIn85
	ABufferIn86
	ABufferIn87
	ABufferIn88
	ABufferIn89
	ABufferIn90
	ABufferIn91
	ABufferIn92
	ABufferIn93
	ABufferIn94
	ABufferIn95
	ABufferIn96
	ABufferIn97
	ABufferIn98
	ABufferIn99
	ABufferIn100
	ABufferIn101
	ABufferIn102
	ABufferIn103
	ABufferIn104
	ABufferIn105
	ABufferIn106
	ABufferIn107
	ABufferIn108
	ABufferIn109
	ABufferIn110
	ABufferIn111

	SBufferOut72
	SBufferOut73
	SBufferOut74
	SBufferOut75
	SBufferOut76
	SBufferOut77
	SBufferOut78
	SBufferOut79
	SBufferOut80
	SBufferOut81
	SBufferOut82
	SBufferOut83
	SBufferOut84
	SBufferOut85
	SBufferOut86
	SBufferOut87
	SBufferOut88
	SBufferOut89
	SBufferOut90
	SBufferOut91
	SBufferOut92
	SBufferOut93
	SBufferOut94
	SBufferOut95
	SBufferOut96
	SBufferOut97
	SBufferOut98
	SBufferOut99
	SBufferOut100
	SBufferOut101
	SBufferOut102
	SBufferOut103
	SBufferOut104
	SBufferOut105
	SBufferOut106
	SBufferOut107
	SBufferOut108
	SBufferOut109
	SBufferOut110
	SBufferOut111
	ENDC


;*****	PROGRAM	***********************************************************
	ORG	0x000
	GOTO	START
;*****	INTERRUPT VECTOR	*****************************
	ORG     0x004		; interrupt vector location.
	MOVWF	W_TEMP		; Save PIC state.
	SWAPF	STATUS,W
	CLRF    STATUS
	MOVWF	S_TEMP
	MOVFW	PCLATH
	MOVWF	P_TEMP
	CLRF	PCLATH
	BCF	STATUS,IRP
	MOVFW	FSR
	MOVWF	FSR_TEMP
;*****	INTERUPTIONS	*****************************
	BTFSC	INTCON,INTF	; HDLCRx Clock INT flag Hi?
	GOTO	HDLCRx		; Yes, handle it.
	BTFSC	PIR1,RCIF	; RS-232 Byte Received.
	GOTO	AUSARTRx	; Yes, Handle it.
    GOTO	INTEND		; No, exit int.

HDLCRx:	BCF	INTCON,INTF	; Clear int RB0 flag.
	BTFSC	TxBitRAM	; If Data is a 1 set output.
	BSF		TxPin		; / Make it 1.
	BTFSS	TxBitRAM	; If Data is a 0 clear output.
	BCF		TxPin		; / Make it 0.
	CALL	HDLC_Rx		; Read RxPin from Quantar and save it on Buffer.
	CALL	HDLC_Tx		; Prepare next TxBit (Pre-load).
    GOTO	INTEND

AUSARTRx:
	CALL	RS232_Rx
	;GOTO	INTEND

;*****	INTERUPTION FINALIZE	*****************************
INTEND:	MOVFW	FSR_TEMP		;Restore PIC state
	MOVWF	FSR
	MOVFW	P_TEMP
	MOVWF	PCLATH
	SWAPF	S_TEMP,W
	MOVWF	STATUS
	SWAPF	W_TEMP,F
	SWAPF	W_TEMP,W
    RETFIE

;*****	START	*****************************
START	CLRWDT
	BANK0
	BANK00
;***	CLEAR PORTS
	CLRF	PORTA		; Clear ports
	CLRF	PORTB		; ////
	CLRF	PORTC		; ///
	CLRF	PORTD		; //
	CLRF	PORTE		; /
	CLRF	BITS1		; Clear flags
	CLRF	BITS2		; //
	CLRF	BITS3		; /
;	BSF		ServiceFlag	; Flag for development use.
;***	CONFIGURE PORTS
	BANK1
	CLRF	TRISA		; PORTA OUT
	MOVLW	B'00000011'	; HDLC port data directions.
	;MOVLW	B'00000001'	; HDLC port data directions only for Debug.
	MOVWF	TRISB		; PORTB IN/OUT
	MOVLW	B'10001111'	; High Nible = AUSART Port, Low Nible = ID.
	MOVWF	TRISC		; PORTC OUT
	CLRF	TRISD		; PORTD IN/OUT
	CLRF	TRISE		; PORTE OUT
	BANK1X
	CLRF	ANSEL		; SET PORTA AS DIGITAL PORTS
	CLRF	ANSELH		; SET PORTB AS DIGITAL PORTS
	BANK0X
	BANK0
;***	Startup LEDs.
	MOVLW	0x0F		; Turn On all LEDs.
	MOVWF	PORTA
;***	Initialize AUSART RS-232 Tx
	BANK1
	MOVLW	B'00100110'	; AUSART Config.
	MOVWF	TXSTA
	MOVLW	Baud_Rate_Const	; Set the Raspberry Baud Rate.
	MOVWF	SPBRG
	BANK0
	BSF		RCSTA,SPEN	; Enable Serial Port.
	
;***	!RESET!n Message.
	MOVLW	StartFlag		; Start Flag to Tx.
	BTFSS	PIR1,TXIF		; Tx Modified Data Byte.
	GOTO	$-1				; //
	MOVWF	TXREG			; /
	MOVLW	"!"				; Char to Tx.
	BTFSS	PIR1,TXIF		; Tx Modified Data Byte.
	GOTO	$-1				; //
	MOVWF	TXREG			; /
	MOVLW	"R"				; Char to Tx.
	BTFSS	PIR1,TXIF		; Tx Modified Data Byte.
	GOTO	$-1				; //
	MOVWF	TXREG			; /
	MOVLW	"E"				; Char to Tx.
	BTFSS	PIR1,TXIF		; Tx Modified Data Byte.
	GOTO	$-1				; //
	MOVWF	TXREG			; /
	MOVLW	"S"				; Char to Tx.
	BTFSS	PIR1,TXIF		; Tx Modified Data Byte.
	GOTO	$-1				; //
	MOVWF	TXREG			; /
	MOVLW	"E"				; Char to Tx.
	BTFSS	PIR1,TXIF		; Tx Modified Data Byte.
	GOTO	$-1				; //
	MOVWF	TXREG			; /
	MOVLW	"T"				; Char to Tx.
	BTFSS	PIR1,TXIF		; Tx Modified Data Byte.
	GOTO	$-1				; //
	MOVWF	TXREG			; /
	MOVLW	"!"				; Char to Tx.
	BTFSS	PIR1,TXIF		; Tx Modified Data Byte.
	GOTO	$-1				; //
	MOVWF	TXREG			; /
	MOVFW	PORTC			; Board ID to Tx (jumper settings).
	ANDLW	0x0F			; Only Low Nibble.
	BTFSS	PIR1,TXIF		; Tx Modified Data Byte.
	GOTO	$-1				; //
	MOVWF	TXREG			; /
	MOVLW	StartFlag		; Footer FLag to Tx.
	BTFSS	PIR1,TXIF		; Tx Modified Data Byte.
	GOTO	$-1				; //
	MOVWF	TXREG			; /

;***	Initialize AUSART RS-232 Rx
	MOVLW	B'10010000'	; AUSART Config.
	MOVWF	RCSTA

;***	Initialize interrupts
	CLRF	INTCON
	BSF		INTCON,INTE		; Enable RB0 External Interrupt.
	BSF		INTCON,PEIE		; Enable periferial Interrupts (AUSART Rx, Timer 1).
	BANK1
	BCF	OPTION_REG,INTEDG	; Set RB0 Edge trigger to Low.
	BSF		PIE1,RCIE		; Enable AUSART Rx Interrupts.
	BANK0
	BCF		INTCON,INTF		; Clear RB0 Interrupt flag.
	MOVFW	RCREG			; Clear AUSART Rx Interrupt Flag by reading Rx Buffer.
	BTFSS	ServiceFlag		; Flag for development use.
	BSF		INTCON,GIE		; Enable Global Interrupts.
	
;***	Last setings
	CLRF	BitIndex		; Clear HDLC_Rx Bit position counter.
	CLRF	OnesCount		; Clear HDLC_Rx ONEs received Counter.
	CLRF	SRxByte			; Clear HDLC_Rx Byte Rx Buffer.
	BSF		FooterWasTx		; Async Footer was Tx.

	CLRF	ABufferInLen	; Clear RS232_Rx Counter.
	CLRF	ARxByte			; Clear RS232_Rx RAM Byte.
	CLRF	SBufferOutLen	
	CLRF	TxBitIndex
	CLRF 	TxOnesCount
	CLRF	TxByteIndex
	CLRF	SyncTxByte
	BSF		HeaderBeingTx	; Enable continous Idle HDLC_Tx StartByte.
	BCF		TxPin			; Clear HDLC_Tx Pin.		
	CLRW					; Clear W register.

;*****	Loops	*****************************
LOOPS:	CLRWDT				; Main loop
	CLRF	PORTA			; Turn Off all LEDs.

	;BTFSC	ServiceFlag		; Flag for development use.
	;CALL	A2S_TestPat

	BTFSC	SRxComplete	; If a HDCL frame was received from Quantar,
	CALL	RS232_Tx		; Send it to the raspberry Pi.
	NOP
	
	GOTO	LOOPS





;************************************************************
;*****	HDLC Receive	*************************************
;************************************************************
HDLC_Rx
	BTFSC	RxPin				; Read HDLC pin, if ValueRx is ONE then:
	GOTO	OneOptions			;	Goto see how many ONEs we have.
;000000000000000000000000000000000000000000000000000000000000
ZeroOptions:					; So it is a ZERO.
	BTFSC	SRxSixOnes			; If we are receiving a Header then
	GOTO	HeaderFinalZero		;	This is the last Header Byte, the ZERO.
	BTFSC	SRxFiveOnes			; If We have just Rx five ONEs.
	GOTO	DummyZero				;	Set a flag to remember for decide on next Bit arrival
	CLRF	OnesCount			; reset ONEs counter, because we Rx a ZERO.
	CALL	SaveZero			; Save the received Bit on Buffer word.
	RETURN
DummyZero:
	BCF		SRxFiveOnes
	CLRF	OnesCount
	RETURN
HeaderFinalZero:
	BCF		SRxFiveOnes
	BCF		SRxSixOnes
	CLRF	OnesCount
	CLRF	BitIndex
	BSF		SHeaderRx
	BSF		SRxComplete		; Rx Sync Frame is complete.
	RETURN

;1111111111111111111111111111111111111111111111111111111111111111111111
OneOptions:
	INCF	OnesCount,F		; ONEs + 1.
	MOVFW	OnesCount		; Review last number of consecutive ONEs.
	SUBLW	0x05
	BTFSC	ZERO			; If there were already five ONEs then this is ONE number six so:
	GOTO	FifthOneRx		; goto FiveOnesRx, which will activate 5 Ones flag.

	MOVFW	OnesCount		; Review last number of consecutive ONEs + valueRx(1).
	SUBLW	0x06
	BTFSC	ZERO			; If there were already five ONEs then this is ONE number six so:
	GOTO	SixthOneRx		; goto FLAGRx, which will check if it is Header or Footer and resync our clock.

	MOVFW	OnesCount		; Review last number of consecutive ONEs + valueRx(1).
	SUBLW	0x07
	BTFSC	ZERO			; If there were already six ONEs then this is ONE number seven so:
	GOTO	SeventhOneRx	; So AbortRx.

							; Less than 5 ONES have been Rx so:
	CALL	SaveOne			; Save the received Bit on Buffer word.
	BCF		SDummyZeroFlag	; Clear flag that aim us to find inserted ZEROs.
	RETURN

FifthOneRx:
	BSF		SRxFiveOnes
	CALL	SaveOne			; Save the received Bit on Buffer word.
	RETURN

SixthOneRx:
	BSF		SRxGLED
	BSF		SRxSixOnes		; else, this flag help us ignore last ZERO on Header B'01111110'
	RETURN

SeventhOneRx:
	BSF		SRxRLED
	BSF		SRxSevenOnes	; This flag help us know Abort happened.
	BCF		SRxComplete		; Ignore Rx Data.
	DECF	OnesCount,F		; ONEs - 1. Any way they are seven or more, so do not overrun our counter.
	RETURN

;************************************************************
;*****	RS-232 Tx	*****************************************
;************************************************************
RS232_Tx
	BTFSC	SHeaderRx
	GOTO	AHeaderTx
	CALL	TestEscapeCh	; Test for Escape Characters.
	BCF		SRxComplete		; Clear the flag to know data has been sent thru RS-232.
	RETURN

AHeaderTx:
	BTFSS	FooterWasTx		; Was previuos Byte an Async footer?
	GOTO	TxHeader1		; No so Tx Footer.
	BCF		SHeaderRx		; Flag to accept header.
	BCF		SRxComplete		; Clear the flag to know data has been sent thru RS-232.
	RETURN
TxHeader1:	
	BSF		FooterWasTx		; Flag to remember Start Flag was sent.
	BTFSS	PIR1,TXIF		; Transmit Start byte 0x7E.
	GOTO	$-1				; ///
	MOVLW	StartFlag		; //
	MOVWF	TXREG			; /
	BCF		SHeaderRx
	BCF		SRxComplete		; Clear the flag to know data has been sent thru RS-232.
	RETURN

TestEscapeCh
	BTFSC	FooterWasTx		; Previous Byte was Footer?
	CALL	AHeader			; New Data, so send its Header.
	MOVFW	ATxByte
	SUBLW	StartFlag
	BTFSS	ZERO			; If Byte is equal to 0x7E then we need to add escape character.
	GOTO	NOT0x7E			; Not a 0x7E.
	BTFSS	CARRY			;
	GOTO	NOT0x7E			; Not a 0x7E.
	GOTO	InsEsc			; It is a 0x7E si insert the Escape Character.

NOT0x7E:
	MOVFW	ATxByte
	SUBLW	EscapeOct
	BTFSS	ZERO			; If Byte is equal to 0x7D then we need to add escape character.
	GOTO	NOT0x7D			;  Not a 0x7D. 
	BTFSS	CARRY			;
	GOTO	NOT0x7D			;  Not a 0x7D.
InsEsc:
	; EscapeOctetInsert:
	MOVLW	EscapeOct		; Insert a 0x7D Escape Character.
	BTFSS	PIR1,TXIF		; ///	Tx Char.
	GOTO	$-1				; //
	MOVWF	TXREG			; /
	MOVFW	ATxByte			; Data to Tx. Make Bit stuffing:
	BTFSS	ATxByte,5		; If Bit 5 != 1.
	BSF		ATxByte,5		; Bit 5 = 1.
	BTFSC	ATxByte,5		; If Bit 5 != 0.
	BCF		ATxByte,5		; Bit 5 = 0.
	MOVFW	ATxByte			; Reload Modified Byte.
	BTFSS	PIR1,TXIF		; Tx Modified Data Byte.
	GOTO	$-1				; //
	MOVWF	TXREG			; /
	RETURN
NOT0x7D:
	MOVFW	ATxByte			; Byte is a normal Character so, send it.
	BTFSS	PIR1,TXIF		; ///
	GOTO	$-1				; //
	MOVWF	TXREG			; /
	RETURN

AHeader
	BTFSS	PIR1,TXIF		; Transmit Start byte 0x7E.
	GOTO	$-1				; ///
	MOVLW	StartFlag		; //
	MOVWF	TXREG			; /
	BCF		FooterWasTx		; Start Byte Tx, so we will nedd a footer later.
	RETURN



;************************************************************
;***** Copy Rx to Tx RAM. ***********************************
;************************************************************
SwapMem_A_S
	MOVFW	ABufferIn0	; Pass Rx Async Buffer data to Sync Data Tx RAM.
	MOVWF	SBufferOut0
	MOVFW	ABufferIn1
	MOVWF	SBufferOut1
	MOVFW	ABufferIn2
	MOVWF	SBufferOut2
	MOVFW	ABufferIn3
	MOVWF	SBufferOut3
	MOVFW	ABufferIn4
	MOVWF	SBufferOut4
	MOVFW	ABufferIn5
	MOVWF	SBufferOut5
	MOVFW	ABufferIn6
	MOVWF	SBufferOut6
	MOVFW	ABufferIn7
	MOVWF	SBufferOut7
	MOVFW	ABufferIn8
	MOVWF	SBufferOut8
	MOVFW	ABufferIn9
	MOVWF	SBufferOut9
	MOVFW	ABufferIn10
	MOVWF	SBufferOut10
	MOVFW	ABufferIn11
	MOVWF	SBufferOut11
	MOVFW	ABufferIn12
	MOVWF	SBufferOut12
	MOVFW	ABufferIn13
	MOVWF	SBufferOut13
	MOVFW	ABufferIn14
	MOVWF	SBufferOut14
	MOVFW	ABufferIn15
	MOVWF	SBufferOut15
	MOVFW	ABufferIn16
	MOVWF	SBufferOut16
	MOVFW	ABufferIn17
	MOVWF	SBufferOut17
	MOVFW	ABufferIn18
	MOVWF	SBufferOut18
	MOVFW	ABufferIn19
	MOVWF	SBufferOut19
	MOVFW	ABufferIn20
	MOVWF	SBufferOut20
	MOVFW	ABufferIn21
	MOVWF	SBufferOut21
	MOVFW	ABufferIn22
	MOVWF	SBufferOut22
	MOVFW	ABufferIn23
	MOVWF	SBufferOut23
	MOVFW	ABufferIn24
	MOVWF	SBufferOut24
	MOVFW	ABufferIn25
	MOVWF	SBufferOut25
	MOVFW	ABufferIn26
	MOVWF	SBufferOut26
	MOVFW	ABufferIn27
	MOVWF	SBufferOut27
	MOVFW	ABufferIn28
	MOVWF	SBufferOut28
	MOVFW	ABufferIn29
	MOVWF	SBufferOut29
	MOVFW	ABufferIn30
	MOVWF	SBufferOut30
	MOVFW	ABufferIn31
	MOVWF	SBufferOut31
	BANK1
	MOVFW	ABufferIn32
	MOVWF	SBufferOut32
	MOVFW	ABufferIn33
	MOVWF	SBufferOut33
	MOVFW	ABufferIn34
	MOVWF	SBufferOut34
	MOVFW	ABufferIn35
	MOVWF	SBufferOut35
	MOVFW	ABufferIn36
	MOVWF	SBufferOut36
	MOVFW	ABufferIn37
	MOVWF	SBufferOut37
	MOVFW	ABufferIn38
	MOVWF	SBufferOut38
	MOVFW	ABufferIn39
	MOVWF	SBufferOut39
	MOVFW	ABufferIn40
	MOVWF	SBufferOut40
	MOVFW	ABufferIn41
	MOVWF	SBufferOut41
	MOVFW	ABufferIn42
	MOVWF	SBufferOut42
	MOVFW	ABufferIn43
	MOVWF	SBufferOut43
	MOVFW	ABufferIn44
	MOVWF	SBufferOut44
	MOVFW	ABufferIn45
	MOVWF	SBufferOut45
	MOVFW	ABufferIn46
	MOVWF	SBufferOut46
	MOVFW	ABufferIn47
	MOVWF	SBufferOut47
	MOVFW	ABufferIn48
	MOVWF	SBufferOut48
	MOVFW	ABufferIn49
	MOVWF	SBufferOut49
	MOVFW	ABufferIn50
	MOVWF	SBufferOut50
	MOVFW	ABufferIn51
	MOVWF	SBufferOut51
	MOVFW	ABufferIn52
	MOVWF	SBufferOut52
	MOVFW	ABufferIn53
	MOVWF	SBufferOut53
	MOVFW	ABufferIn54
	MOVWF	SBufferOut54
	MOVFW	ABufferIn55
	MOVWF	SBufferOut55
	MOVFW	ABufferIn56
	MOVWF	SBufferOut56
	MOVFW	ABufferIn57
	MOVWF	SBufferOut57
	MOVFW	ABufferIn58
	MOVWF	SBufferOut58
	MOVFW	ABufferIn59
	MOVWF	SBufferOut59
	MOVFW	ABufferIn60
	MOVWF	SBufferOut60
	MOVFW	ABufferIn61
	MOVWF	SBufferOut61
	MOVFW	ABufferIn62
	MOVWF	SBufferOut62
	MOVFW	ABufferIn63
	MOVWF	SBufferOut63
	MOVFW	ABufferIn64
	MOVWF	SBufferOut64
	MOVFW	ABufferIn65
	MOVWF	SBufferOut65
	MOVFW	ABufferIn66
	MOVWF	SBufferOut66
	MOVFW	ABufferIn67
	MOVWF	SBufferOut67
	MOVFW	ABufferIn68
	MOVWF	SBufferOut68
	MOVFW	ABufferIn69
	MOVWF	SBufferOut69
	MOVFW	ABufferIn70
	MOVWF	SBufferOut70
	MOVFW	ABufferIn71
	MOVWF	SBufferOut71
	BANK1X
	BANK0
	MOVFW	ABufferIn72
	MOVWF	SBufferOut72
	MOVFW	ABufferIn73
	MOVWF	SBufferOut73
	MOVFW	ABufferIn74
	MOVWF	SBufferOut74
	MOVFW	ABufferIn75
	MOVWF	SBufferOut75
	MOVFW	ABufferIn76
	MOVWF	SBufferOut76
	MOVFW	ABufferIn77
	MOVWF	SBufferOut77
	MOVFW	ABufferIn78
	MOVWF	SBufferOut78
	MOVFW	ABufferIn79
	MOVWF	SBufferOut79
	MOVFW	ABufferIn80
	MOVWF	SBufferOut80
	MOVFW	ABufferIn81
	MOVWF	SBufferOut81
	MOVFW	ABufferIn82
	MOVWF	SBufferOut82
	MOVFW	ABufferIn83
	MOVWF	SBufferOut83
	MOVFW	ABufferIn84
	MOVWF	SBufferOut84
	MOVFW	ABufferIn85
	MOVWF	SBufferOut85
	MOVFW	ABufferIn86
	MOVWF	SBufferOut86
	MOVFW	ABufferIn87
	MOVWF	SBufferOut87
	MOVFW	ABufferIn88
	MOVWF	SBufferOut88
	MOVFW	ABufferIn89
	MOVWF	SBufferOut89
	MOVFW	ABufferIn90
	MOVWF	SBufferOut90
	MOVFW	ABufferIn91
	MOVWF	SBufferOut91
	MOVFW	ABufferIn92
	MOVWF	SBufferOut92
	MOVFW	ABufferIn93
	MOVWF	SBufferOut93
	BANK0X
	BANK0
	MOVFW	ABufferInLen	; Pass Data Length to be Tx.
	MOVWF	SBufferOutLen
	CLRF	ABufferInLen
	CLRF	TxByteIndex
	BCF		DataReady
	RETURN

;************************************************************
;*****	RS-232 Rx	*****************************************
;************************************************************
RS232_Rx
	BSF		ARxGLED			; Blink Green LED so we know RS-232 is Rx.
	MOVFW	RCREG			; /
	BTFSC	ServiceFlag		; This allow us insert a custom word to emulate we Rx data from RS-232 while debugging.
	MOVFW	Testing			; /
	MOVWF	ARxByte			; Save Rx data.
	SUBLW	StartFlag		; Test for Start Flag B'01111110'
	BTFSS	ZERO			; If Byte is equal to 0x7E then this is the Header.
	GOTO	TestEscChar		; //// It is not 0x7E.
	BTFSS	CARRY			; ///
	GOTO	TestEscChar		; // It is not 0x7E.
	GOTO	A_FooterRx		; /
	RETURN

A_FooterRx:
	BCF		WritingBuffer		; Footer Flag received 0x7E.
	MOVFW	ABufferInLen		; Save the number of words Rx.
	BTFSS	ZERO				; Set a flag to know a frame was Rx.
	BSF		DataReady			; /
	RETURN

TestEscChar:
	MOVFW	ARxByte			; Load Rx word.
	SUBLW	EscapeOct		; Test for Escape Oct 0x7D.
	BTFSS	ZERO			; If Byte is equal to 0x7D then this could be an escape character.
	GOTO	RxAData			; ///
	BTFSS	CARRY			; //
	GOTO	RxAData			; /
	BSF		EscapeCharFlag	; Escape Char Flag	
	RETURN

RxAData:
	BTFSC	EscapeCharFlag	; If previous byte was an Escape Character
	GOTO	EscChar			; /
	BSF		WritingBuffer	; So we know the Buffer contains some Data.
	CALL	SaveAsyncRx		; Save Byte on Buffer2.
	RETURN

EscChar:
	BCF		EscapeCharFlag	; Clear the Escape Char Flag	
	MOVFW	ARxByte
	SUBLW	0x5E
	BTFSS	ZERO			; If Byte is equal to 0x5E then it is a modified
	GOTO	Char_5D			; /// Character.
	BTFSS	CARRY			; //
	GOTO	Char_5D			; /
	MOVLW	0x7E			; Character 0x7E recovery. 
	MOVWF	ARxByte
	CALL	SaveAsyncRx		; Save Byte on Buffer2.
	RETURN

Char_5D:
	MOVFW	ARxByte			; If Byte is equal to 0x5D ten it is a modified Character preceded by a header.
	SUBLW	0x5D			; /////
	BTFSS	ZERO			; ////
	GOTO	RS232Rx_Err		; ///
	BTFSS	CARRY			; //
	GOTO	RS232Rx_Err		; /
	MOVLW	0x7D			; Character 0x7D recovery. 
	MOVWF	ARxByte			
	BSF		WritingBuffer	; So we know the Buffer contains some Data.
	CALL	SaveAsyncRx		; Save Byte on Buffer2.
	RETURN

RS232Rx_Err:
	GOTO	START			; Reset the PIC.























;************************************************************
;*****	Tables	*********************************************
;************************************************************

;*****	Save a ZERO from HDLC_Rx data	*****************************
	ORG     H'200'		; This lot must be at 200H or higher.
SaveZero	
	INCF	BitIndex,F	; Move to next Bit slot.
	MOVLW	H'02'		; Contain data tables for bit storage.
	MOVWF	PCLATH
	MOVFW	BitIndex
	ADDWF	PCL,F
	NOP					; Dummy because Bit Position is increased before table jumps.
	GOTO	Bit0C
	GOTO	Bit1C
	GOTO	Bit2C
	GOTO	Bit3C
	GOTO	Bit4C
	GOTO	Bit5C
	GOTO	Bit6C
	GOTO	Bit7C

Bit0C:
	CLRF	SRxByte
	RETURN
Bit1C:
	BCF		SRxByte,1
	RETURN
Bit2C:
	BCF		SRxByte,2
	RETURN
Bit3C:
	BCF		SRxByte,3
	RETURN
Bit4C:
	BCF		SRxByte,4
	RETURN
Bit5C:
	BCF		SRxByte,5
	RETURN
Bit6C:
	BCF		SRxByte,6
	RETURN
Bit7C:
	BCF		SRxByte,7
	CLRF	BitIndex
	MOVFW	SRxByte			; Copy Data to Tx RAM.
	MOVWF	ATxByte			; /
	BSF		SRxComplete
	RETURN

;*****	Save a ONE from HDLC_Rx	*****************************
	ORG     H'230'		; This lot must be at 220H or higher.
SaveOne	
	INCF	BitIndex,F	; Move to next Bit slot.
	MOVLW	H'02'		; Contain data tables for messages.
	MOVWF	PCLATH
	MOVFW	BitIndex
	ADDWF	PCL,F
	NOP					; Dummy because Bit Position is increased before table jumps.
	GOTO	Bit0S
	GOTO	Bit1S
	GOTO	Bit2S
	GOTO	Bit3S
	GOTO	Bit4S
	GOTO	Bit5S
	GOTO	Bit6S
	GOTO	Bit7S

Bit0S:
	CLRF	SRxByte
	BSF		SRxByte,0
	RETURN
Bit1S:
	BSF		SRxByte,1
	RETURN
Bit2S:
	BSF		SRxByte,2
	RETURN
Bit3S:
	BSF		SRxByte,3
	RETURN
Bit4S:
	BSF		SRxByte,4
	RETURN
Bit5S:
	BSF		SRxByte,5
	RETURN
Bit6S:
	BSF		SRxByte,6
	RETURN
Bit7S:
	BSF		SRxByte,7
	CLRF	BitIndex
	MOVFW	SRxByte			; Copy Data to Tx RAM.
	MOVWF	ATxByte			; /
	BSF		SRxComplete
	RETURN








;************************************************************
;*****	Async HDLC Rx Save data	*****************************
;************************************************************
	ORG     H'300'		; This lot must be at 300H or higher.
SaveAsyncRx
	MOVLW	H'03'		; Contain data tables for bit storage.
	MOVWF	PCLATH
	INCF	ABufferInLen,F	; Move to next WORD.
	MOVFW	ABufferInLen
	ADDWF	PCL,F
	NOP					; Dummy because Bit Position is increased before table jumps.
	GOTO	SaveAsyncRx0
	GOTO	SaveAsyncRx1
	GOTO	SaveAsyncRx2
	GOTO	SaveAsyncRx3
	GOTO	SaveAsyncRx4
	GOTO	SaveAsyncRx5
	GOTO	SaveAsyncRx6
	GOTO	SaveAsyncRx7
	GOTO	SaveAsyncRx8
	GOTO	SaveAsyncRx9
	GOTO	SaveAsyncRx10
	GOTO	SaveAsyncRx11
	GOTO	SaveAsyncRx12
	GOTO	SaveAsyncRx13
	GOTO	SaveAsyncRx14
	GOTO	SaveAsyncRx15
	GOTO	SaveAsyncRx16
	GOTO	SaveAsyncRx17
	GOTO	SaveAsyncRx18
	GOTO	SaveAsyncRx19
	GOTO	SaveAsyncRx20
	GOTO	SaveAsyncRx21
	GOTO	SaveAsyncRx22
	GOTO	SaveAsyncRx23
	GOTO	SaveAsyncRx24
	GOTO	SaveAsyncRx25
	GOTO	SaveAsyncRx26
	GOTO	SaveAsyncRx27
	GOTO	SaveAsyncRx28
	GOTO	SaveAsyncRx29
	GOTO	SaveAsyncRx30
	GOTO	SaveAsyncRx31
	GOTO	SaveAsyncRx32
	GOTO	SaveAsyncRx33
	GOTO	SaveAsyncRx34
	GOTO	SaveAsyncRx35
	GOTO	SaveAsyncRx36
	GOTO	SaveAsyncRx37
	GOTO	SaveAsyncRx38
	GOTO	SaveAsyncRx39
	GOTO	SaveAsyncRx40
	GOTO	SaveAsyncRx41
	GOTO	SaveAsyncRx42
	GOTO	SaveAsyncRx43
	GOTO	SaveAsyncRx44
	GOTO	SaveAsyncRx45
	GOTO	SaveAsyncRx46
	GOTO	SaveAsyncRx47
	GOTO	SaveAsyncRx48
	GOTO	SaveAsyncRx49
	GOTO	SaveAsyncRx50
	GOTO	SaveAsyncRx51
	GOTO	SaveAsyncRx52
	GOTO	SaveAsyncRx53
	GOTO	SaveAsyncRx54
	GOTO	SaveAsyncRx55
	GOTO	SaveAsyncRx56
	GOTO	SaveAsyncRx57
	GOTO	SaveAsyncRx58
	GOTO	SaveAsyncRx59
	GOTO	SaveAsyncRx60
	GOTO	SaveAsyncRx61
	GOTO	SaveAsyncRx62
	GOTO	SaveAsyncRx63

	GOTO	SaveAsyncRx64
	GOTO	SaveAsyncRx65
	GOTO	SaveAsyncRx66
	GOTO	SaveAsyncRx67
	GOTO	SaveAsyncRx68
	GOTO	SaveAsyncRx69
	GOTO	SaveAsyncRx70
	GOTO	SaveAsyncRx71
	GOTO	SaveAsyncRx72
	GOTO	SaveAsyncRx73
	GOTO	SaveAsyncRx74
	GOTO	SaveAsyncRx75
	GOTO	SaveAsyncRx76
	GOTO	SaveAsyncRx77
	GOTO	SaveAsyncRx78
	GOTO	SaveAsyncRx79
	GOTO	SaveAsyncRx80
	GOTO	SaveAsyncRx81
	GOTO	SaveAsyncRx82
	GOTO	SaveAsyncRx83
	GOTO	SaveAsyncRx84
	GOTO	SaveAsyncRx85
	GOTO	SaveAsyncRx86
	GOTO	SaveAsyncRx87
	GOTO	SaveAsyncRx88
	GOTO	SaveAsyncRx89
	GOTO	SaveAsyncRx90
	GOTO	SaveAsyncRx91
	GOTO	SaveAsyncRx92
	GOTO	SaveAsyncRx93
	GOTO	START			; Buffer Overflow, so reboot PIC.

SaveAsyncRx0:
	MOVFW	ARxByte
	MOVWF	ABufferIn0
	RETURN
SaveAsyncRx1:
	MOVFW	ARxByte
	MOVWF	ABufferIn1
	RETURN
SaveAsyncRx2:
	MOVFW	ARxByte
	MOVWF	ABufferIn2
	RETURN
SaveAsyncRx3:
	MOVFW	ARxByte
	MOVWF	ABufferIn3
	RETURN
SaveAsyncRx4:
	MOVFW	ARxByte
	MOVWF	ABufferIn4
	RETURN
SaveAsyncRx5:
	MOVFW	ARxByte
	MOVWF	ABufferIn5
	RETURN
SaveAsyncRx6:
	MOVFW	ARxByte
	MOVWF	ABufferIn6
	RETURN
SaveAsyncRx7:
	MOVFW	ARxByte
	MOVWF	ABufferIn7
	RETURN
SaveAsyncRx8:
	MOVFW	ARxByte
	MOVWF	ABufferIn8
	RETURN
SaveAsyncRx9:
	MOVFW	ARxByte
	MOVWF	ABufferIn9
	RETURN
SaveAsyncRx10:
	MOVFW	ARxByte
	MOVWF	ABufferIn10
	RETURN
SaveAsyncRx11:
	MOVFW	ARxByte
	MOVWF	ABufferIn11
	RETURN
SaveAsyncRx12:
	MOVFW	ARxByte
	MOVWF	ABufferIn12
	RETURN
SaveAsyncRx13:
	MOVFW	ARxByte
	MOVWF	ABufferIn13
	RETURN
SaveAsyncRx14:
	MOVFW	ARxByte
	MOVWF	ABufferIn14
	RETURN
SaveAsyncRx15:
	MOVFW	ARxByte
	MOVWF	ABufferIn15
	RETURN
SaveAsyncRx16:
	MOVFW	ARxByte
	MOVWF	ABufferIn16
	RETURN
SaveAsyncRx17:
	MOVFW	ARxByte
	MOVWF	ABufferIn17
	RETURN
SaveAsyncRx18:
	MOVFW	ARxByte
	MOVWF	ABufferIn18
	RETURN
SaveAsyncRx19:
	MOVFW	ARxByte
	MOVWF	ABufferIn19
	RETURN
SaveAsyncRx20:
	MOVFW	ARxByte
	MOVWF	ABufferIn20
	RETURN
SaveAsyncRx21:
	MOVFW	ARxByte
	MOVWF	ABufferIn21
	RETURN
SaveAsyncRx22:
	MOVFW	ARxByte
	MOVWF	ABufferIn22
	RETURN
SaveAsyncRx23:
	MOVFW	ARxByte
	MOVWF	ABufferIn23
	RETURN
SaveAsyncRx24:
	MOVFW	ARxByte
	MOVWF	ABufferIn24
	RETURN
SaveAsyncRx25:
	MOVFW	ARxByte
	MOVWF	ABufferIn25
	RETURN
SaveAsyncRx26:
	MOVFW	ARxByte
	MOVWF	ABufferIn26
	RETURN
SaveAsyncRx27:
	MOVFW	ARxByte
	MOVWF	ABufferIn27
	RETURN
SaveAsyncRx28:
	MOVFW	ARxByte
	MOVWF	ABufferIn28
	RETURN
SaveAsyncRx29:
	MOVFW	ARxByte
	MOVWF	ABufferIn29
	RETURN
SaveAsyncRx30:
	MOVFW	ARxByte
	MOVWF	ABufferIn30
	RETURN
SaveAsyncRx31:
	MOVFW	ARxByte
	MOVWF	ABufferIn31
	RETURN

SaveAsyncRx32:
	MOVFW	ARxByte
	BANK1
	MOVWF	ABufferIn32
	BANK0
	RETURN
SaveAsyncRx33:
	MOVFW	ARxByte
	BANK1
	MOVWF	ABufferIn33
	BANK0
	RETURN
SaveAsyncRx34:
	MOVFW	ARxByte
	BANK1
	MOVWF	ABufferIn34
	BANK0
	RETURN
SaveAsyncRx35:
	MOVFW	ARxByte
	BANK1
	MOVWF	ABufferIn35
	BANK0
	RETURN
SaveAsyncRx36:
	MOVFW	ARxByte
	BANK1
	MOVWF	ABufferIn36
	BANK0
	RETURN
SaveAsyncRx37:
	MOVFW	ARxByte
	BANK1
	MOVWF	ABufferIn37
	BANK0
	RETURN
SaveAsyncRx38:
	MOVFW	ARxByte
	BANK1
	MOVWF	ABufferIn38
	BANK0
	RETURN
SaveAsyncRx39:
	MOVFW	ARxByte
	BANK1
	MOVWF	ABufferIn39
	BANK0
	RETURN
SaveAsyncRx40:
	MOVFW	ARxByte
	BANK1
	MOVWF	ABufferIn40
	BANK0
	RETURN
SaveAsyncRx41:
	MOVFW	ARxByte
	BANK1
	MOVWF	ABufferIn41
	BANK0
	RETURN
SaveAsyncRx42:
	MOVFW	ARxByte
	BANK1
	MOVWF	ABufferIn42
	BANK0
	RETURN
SaveAsyncRx43:
	MOVFW	ARxByte
	BANK1
	MOVWF	ABufferIn43
	BANK0
	RETURN
SaveAsyncRx44:
	MOVFW	ARxByte
	BANK1
	MOVWF	ABufferIn44
	BANK0
	RETURN
SaveAsyncRx45:
	MOVFW	ARxByte
	BANK1
	MOVWF	ABufferIn45
	BANK0
	RETURN
SaveAsyncRx46:
	MOVFW	ARxByte
	BANK1
	MOVWF	ABufferIn46
	BANK0
	RETURN
SaveAsyncRx47:
	MOVFW	ARxByte
	BANK1
	MOVWF	ABufferIn47
	BANK0
	RETURN
SaveAsyncRx48:
	MOVFW	ARxByte
	BANK1
	MOVWF	ABufferIn48
	BANK0
	RETURN
SaveAsyncRx49:
	MOVFW	ARxByte
	BANK1
	MOVWF	ABufferIn49
	BANK0
	RETURN
SaveAsyncRx50:
	MOVFW	ARxByte
	BANK1
	MOVWF	ABufferIn50
	BANK0
	RETURN
SaveAsyncRx51:
	MOVFW	ARxByte
	BANK1
	MOVWF	ABufferIn51
	BANK0
	RETURN
SaveAsyncRx52:
	MOVFW	ARxByte
	BANK1
	MOVWF	ABufferIn52
	BANK0
	RETURN
SaveAsyncRx53:
	MOVFW	ARxByte
	BANK1
	MOVWF	ABufferIn53
	BANK0
	RETURN
SaveAsyncRx54:
	MOVFW	ARxByte
	BANK1
	MOVWF	ABufferIn54
	BANK0
	RETURN
SaveAsyncRx55:
	MOVFW	ARxByte
	BANK1
	MOVWF	ABufferIn55
	BANK0
	RETURN
SaveAsyncRx56:
	MOVFW	ARxByte
	BANK1
	MOVWF	ABufferIn56
	BANK0
	RETURN
SaveAsyncRx57:
	MOVFW	ARxByte
	BANK1
	MOVWF	ABufferIn57
	BANK0
	RETURN
SaveAsyncRx58:
	MOVFW	ARxByte
	BANK1
	MOVWF	ABufferIn58
	BANK0
	RETURN
SaveAsyncRx59:
	MOVFW	ARxByte
	BANK1
	MOVWF	ABufferIn59
	BANK0
	RETURN
SaveAsyncRx60:
	MOVFW	ARxByte
	BANK1
	MOVWF	ABufferIn60
	BANK0
	RETURN
SaveAsyncRx61:
	MOVFW	ARxByte
	BANK1
	MOVWF	ABufferIn61
	BANK0
	RETURN
SaveAsyncRx62:
	MOVFW	ARxByte
	BANK1
	MOVWF	ABufferIn62
	BANK0
	RETURN
SaveAsyncRx63:
	MOVFW	ARxByte
	BANK1
	MOVWF	ABufferIn63
	BANK0
	RETURN

SaveAsyncRx64:
	MOVFW	ARxByte
	BANK1
	MOVWF	ABufferIn64
	BANK0
	RETURN
SaveAsyncRx65:
	MOVFW	ARxByte
	BANK1
	MOVWF	ABufferIn65
	BANK0
	RETURN
SaveAsyncRx66:
	MOVFW	ARxByte
	BANK1
	MOVWF	ABufferIn66
	BANK0
	RETURN
SaveAsyncRx67:
	MOVFW	ARxByte
	BANK1
	MOVWF	ABufferIn67
	BANK0
	RETURN
SaveAsyncRx68:
	MOVFW	ARxByte
	BANK1
	MOVWF	ABufferIn68
	BANK0
	RETURN
SaveAsyncRx69:
	MOVFW	ARxByte
	BANK1
	MOVWF	ABufferIn69
	BANK0
	RETURN
SaveAsyncRx70:
	MOVFW	ARxByte
	BANK1
	MOVWF	ABufferIn70
	BANK0
	RETURN
SaveAsyncRx71:
	MOVFW	ARxByte
	BANK1
	MOVWF	ABufferIn71
	BANK0
	RETURN

SaveAsyncRx72:
	MOVFW	ARxByte
	BANK1X
	MOVWF	ABufferIn72
	BANK0X
	RETURN
SaveAsyncRx73:
	MOVFW	ARxByte
	BANK1X
	MOVWF	ABufferIn73
	BANK0X
	RETURN
SaveAsyncRx74:
	MOVFW	ARxByte
	BANK1X
	MOVWF	ABufferIn74
	BANK0X
	RETURN
SaveAsyncRx75:
	MOVFW	ARxByte
	BANK1X
	MOVWF	ABufferIn75
	BANK0X
	RETURN
SaveAsyncRx76:
	MOVFW	ARxByte
	BANK1X
	MOVWF	ABufferIn76
	BANK0X
	RETURN
SaveAsyncRx77:
	MOVFW	ARxByte
	BANK1X
	MOVWF	ABufferIn77
	BANK0X
	RETURN
SaveAsyncRx78:
	MOVFW	ARxByte
	BANK1X
	MOVWF	ABufferIn78
	BANK0X
	RETURN
SaveAsyncRx79:
	MOVFW	ARxByte
	BANK1X
	MOVWF	ABufferIn79
	BANK0X
	RETURN
SaveAsyncRx80:
	MOVFW	ARxByte
	BANK1X
	MOVWF	ABufferIn80
	BANK0X
	RETURN
SaveAsyncRx81:
	MOVFW	ARxByte
	BANK1X
	MOVWF	ABufferIn81
	BANK0X
	RETURN
SaveAsyncRx82:
	MOVFW	ARxByte
	BANK1X
	MOVWF	ABufferIn82
	BANK0X
	RETURN
SaveAsyncRx83:
	MOVFW	ARxByte
	BANK1X
	MOVWF	ABufferIn83
	BANK0X
	RETURN
SaveAsyncRx84:
	MOVFW	ARxByte
	BANK1X
	MOVWF	ABufferIn84
	BANK0X
	RETURN
SaveAsyncRx85:
	MOVFW	ARxByte
	BANK1X
	MOVWF	ABufferIn85
	BANK0X
	RETURN
SaveAsyncRx86:
	MOVFW	ARxByte
	BANK1X
	MOVWF	ABufferIn86
	BANK0X
	RETURN
SaveAsyncRx87:
	MOVFW	ARxByte
	BANK1X
	MOVWF	ABufferIn87
	BANK0X
	RETURN
SaveAsyncRx88:
	MOVFW	ARxByte
	BANK1X
	MOVWF	ABufferIn88
	BANK0X
	RETURN
SaveAsyncRx89:
	MOVFW	ARxByte
	BANK1X
	MOVWF	ABufferIn89
	BANK0X
	RETURN
SaveAsyncRx90:
	MOVFW	ARxByte
	BANK1X
	MOVWF	ABufferIn90
	BANK0X
	RETURN
SaveAsyncRx91:
	MOVFW	ARxByte
	BANK1X
	MOVWF	ABufferIn91
	BANK0X
	RETURN
SaveAsyncRx92:
	MOVFW	ARxByte
	BANK1X
	MOVWF	ABufferIn92
	BANK0X
	RETURN
SaveAsyncRx93:
	MOVFW	ARxByte
	BANK1X
	MOVWF	ABufferIn93
	BANK0X
	RETURN
	
;************************************************************
;*****	HDLC Transmit	*************************************
;************************************************************
	ORG     H'500'			; This lot must be at 500H or higher.
HDLC_Tx
	BTFSS	HeaderBeingTx
	GOTO	LoadSyncTx
TxHeaderLoop:
	INCF	TxBitIndex,F	; Move to next Bit slot.
	MOVLW	H'05'			; Contain data tables for bit storage.
	MOVWF	PCLATH
	MOVFW	TxBitIndex
	ADDWF	PCL,F
	NOP						; Dummy because BitPosition is increased before table jumps.
	GOTO	TxHeaderZero	; Header 0x7E B'01111110'
	GOTO	TxHeaderOne		; ///////
	GOTO	TxHeaderOne		; //////
	GOTO	TxHeaderOne		; /////
	GOTO	TxHeaderOne		; ////
	GOTO	TxHeaderOne		; ///
	GOTO	TxHeaderOne		; //
	GOTO	TxHeaderLastZero; /
	RETURN
TxHeaderZero:
	BCF		TxBitRAM
	BSF		HeaderBeingTx
	RETURN
TxHeaderOne:
	BSF		TxBitRAM
	RETURN
TxHeaderLastZero:
	BCF		TxBitRAM
	CLRF	TxBitIndex
	BCF		HeaderBeingTx	
	BTFSC	DataReady
	CALL	SwapMem_A_S
	CLRWDT
	RETURN

; **************************************************************************
	ORG     H'520'			; This lot must be at 520H or higher.
LoadSyncTx:
	MOVFW	SBufferOutLen	; Check how many bytes we have to Tx via Sync HDLC.
	SUBWF	TxByteIndex,W
	BTFSC	ZERO			; If there were all transmited thru HDLC then Tx Header/Footer.
	GOTO	TxHeaderLoop	;	Start sending the Header again.
							; Else, get next Byte to Tx.
	MOVLW	H'05'			;	Contain data tables for Byte storage.
	MOVWF	PCLATH
	MOVFW	TxByteIndex
	ADDWF	PCL,F
	GOTO	LoadSyncTx0
	GOTO	LoadSyncTx1
	GOTO	LoadSyncTx2
	GOTO	LoadSyncTx3
	GOTO	LoadSyncTx4
	GOTO	LoadSyncTx5
	GOTO	LoadSyncTx6
	GOTO	LoadSyncTx7
	GOTO	LoadSyncTx8
	GOTO	LoadSyncTx9
	GOTO	LoadSyncTx10
	GOTO	LoadSyncTx11
	GOTO	LoadSyncTx12
	GOTO	LoadSyncTx13
	GOTO	LoadSyncTx14
	GOTO	LoadSyncTx15
	GOTO	LoadSyncTx16
	GOTO	LoadSyncTx17
	GOTO	LoadSyncTx18
	GOTO	LoadSyncTx19
	GOTO	LoadSyncTx20
	GOTO	LoadSyncTx21
	GOTO	LoadSyncTx22
	GOTO	LoadSyncTx23
	GOTO	LoadSyncTx24
	GOTO	LoadSyncTx25
	GOTO	LoadSyncTx26
	GOTO	LoadSyncTx27
	GOTO	LoadSyncTx28
	GOTO	LoadSyncTx29
	GOTO	LoadSyncTx30
	GOTO	LoadSyncTx31
	GOTO	LoadSyncTx32
	GOTO	LoadSyncTx33
	GOTO	LoadSyncTx34
	GOTO	LoadSyncTx35
	GOTO	LoadSyncTx36
	GOTO	LoadSyncTx37
	GOTO	LoadSyncTx38
	GOTO	LoadSyncTx39
	GOTO	LoadSyncTx40
	GOTO	LoadSyncTx41
	GOTO	LoadSyncTx42
	GOTO	LoadSyncTx43
	GOTO	LoadSyncTx44
	GOTO	LoadSyncTx45
	GOTO	LoadSyncTx46
	GOTO	LoadSyncTx47
	GOTO	LoadSyncTx48
	GOTO	LoadSyncTx49
	GOTO	LoadSyncTx50
	GOTO	LoadSyncTx51
	GOTO	LoadSyncTx52
	GOTO	LoadSyncTx53
	GOTO	LoadSyncTx54
	GOTO	LoadSyncTx55
	GOTO	LoadSyncTx56
	GOTO	LoadSyncTx57
	GOTO	LoadSyncTx58
	GOTO	LoadSyncTx59
	GOTO	LoadSyncTx60
	GOTO	LoadSyncTx61
	GOTO	LoadSyncTx62
	GOTO	LoadSyncTx63
	GOTO	LoadSyncTx64
	GOTO	LoadSyncTx65
	GOTO	LoadSyncTx66
	GOTO	LoadSyncTx67
	GOTO	LoadSyncTx68
	GOTO	LoadSyncTx69
	GOTO	LoadSyncTx70
	GOTO	LoadSyncTx71
	GOTO	LoadSyncTx72
	GOTO	LoadSyncTx73
	GOTO	LoadSyncTx74
	GOTO	LoadSyncTx75
	GOTO	LoadSyncTx76
	GOTO	LoadSyncTx77
	GOTO	LoadSyncTx78
	GOTO	LoadSyncTx79
	GOTO	LoadSyncTx80
	GOTO	LoadSyncTx81
	GOTO	LoadSyncTx82
	GOTO	LoadSyncTx83
	GOTO	LoadSyncTx84
	GOTO	LoadSyncTx85
	GOTO	LoadSyncTx86
	GOTO	LoadSyncTx87
	GOTO	LoadSyncTx88
	GOTO	LoadSyncTx89
	GOTO	LoadSyncTx90
	GOTO	LoadSyncTx91
	GOTO	LoadSyncTx92
	GOTO	LoadSyncTx93
	GOTO	START			; Buffer Overflow, so reboot PIC.

LoadSyncTx0:
	MOVFW	SBufferOut0
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx1:
	MOVFW	SBufferOut1
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx2:
	MOVFW	SBufferOut2
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx3:
	MOVFW	SBufferOut3
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx4:
	MOVFW	SBufferOut4
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx5:
	MOVFW	SBufferOut5
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx6:
	MOVFW	SBufferOut6
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx7:
	MOVFW	SBufferOut7
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx8:
	MOVFW	SBufferOut8
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx9:
	MOVFW	SBufferOut9
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx10:
	MOVFW	SBufferOut10
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx11:
	MOVFW	SBufferOut11
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx12:
	MOVFW	SBufferOut12
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx13:
	MOVFW	SBufferOut13
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx14:
	MOVFW	SBufferOut14
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx15:
	MOVFW	SBufferOut15
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx16:
	MOVFW	SBufferOut16
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx17:
	MOVFW	SBufferOut17
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx18:
	MOVFW	SBufferOut18
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx19:
	MOVFW	SBufferOut19
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx20:
	MOVFW	SBufferOut20
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx21:
	MOVFW	SBufferOut21
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx22:
	MOVFW	SBufferOut22
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx23:
	MOVFW	SBufferOut23
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx24:
	MOVFW	SBufferOut24
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx25:
	MOVFW	SBufferOut25
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx26:
	MOVFW	SBufferOut26
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx27:
	MOVFW	SBufferOut27
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx28:
	MOVFW	SBufferOut28
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx29:
	MOVFW	SBufferOut29
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx30:
	MOVFW	SBufferOut30
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx31:
	MOVFW	SBufferOut31
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN

LoadSyncTx32:
	BANK1
	MOVFW	SBufferOut32
	BANK0
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx33:
	BANK1
	MOVFW	SBufferOut33
	BANK0
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx34:
	BANK1
	MOVFW	SBufferOut34
	BANK0
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx35:
	BANK1
	MOVFW	SBufferOut35
	BANK0
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx36:
	BANK1
	MOVFW	SBufferOut36
	BANK0
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx37:
	BANK1
	MOVFW	SBufferOut37
	BANK0
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx38:
	BANK1
	MOVFW	SBufferOut38
	BANK0
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx39:
	BANK1
	MOVFW	SBufferOut39
	BANK0
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx40:
	BANK1
	MOVFW	SBufferOut40
	BANK0
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx41:
	BANK1
	MOVFW	SBufferOut41
	BANK0
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx42:
	BANK1
	MOVFW	SBufferOut42
	BANK0
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx43:
	BANK1
	MOVFW	SBufferOut43
	BANK0
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx44:
	BANK1
	MOVFW	SBufferOut44
	BANK0
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx45:
	BANK1
	MOVFW	SBufferOut45
	BANK0
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx46:
	BANK1
	MOVFW	SBufferOut46
	BANK0
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx47:
	BANK1
	MOVFW	SBufferOut47
	BANK0
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx48:
	BANK1
	MOVFW	SBufferOut48
	BANK0
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx49:
	BANK1
	MOVFW	SBufferOut49
	BANK0
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx50:
	BANK1
	MOVFW	SBufferOut50
	BANK0
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx51:
	BANK1
	MOVFW	SBufferOut51
	BANK0
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx52:
	BANK1
	MOVFW	SBufferOut52
	BANK0
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx53:
	BANK1
	MOVFW	SBufferOut53
	BANK0
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx54:
	BANK1
	MOVFW	SBufferOut54
	BANK0
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx55:
	BANK1
	MOVFW	SBufferOut55
	BANK0
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx56:
	BANK1
	MOVFW	SBufferOut56
	BANK0
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx57:
	BANK1
	MOVFW	SBufferOut57
	BANK0
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx58:
	BANK1
	MOVFW	SBufferOut58
	BANK0
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx59:
	BANK1
	MOVFW	SBufferOut59
	BANK0
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx60:
	BANK1
	MOVFW	SBufferOut60
	BANK0
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx61:
	BANK1
	MOVFW	SBufferOut61
	BANK0
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx62:
	BANK1
	MOVFW	SBufferOut62
	BANK0
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx63:
	BANK1
	MOVFW	SBufferOut63
	BANK0
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx64:
	BANK1
	MOVFW	SBufferOut64
	BANK0
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx65:
	BANK1
	MOVFW	SBufferOut65
	BANK0
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx66:
	BANK1
	MOVFW	SBufferOut66
	BANK0
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx67:
	BANK1
	MOVFW	SBufferOut67
	BANK0
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx68:
	BANK1
	MOVFW	SBufferOut68
	BANK0
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx69:
	BANK1
	MOVFW	SBufferOut69
	BANK0
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx70:
	BANK1
	MOVFW	SBufferOut70
	BANK0
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx71:
	BANK1
	MOVFW	SBufferOut71
	BANK0
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
	
LoadSyncTx72:
	BANK1X
	MOVFW	SBufferOut72
	BANK0X
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx73:
	BANK1X
	MOVFW	SBufferOut73
	BANK0X
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx74:
	BANK1X
	MOVFW	SBufferOut74
	BANK0X
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx75:
	BANK1X
	MOVFW	SBufferOut75
	BANK0X
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx76:
	BANK1X
	MOVFW	SBufferOut76
	BANK0X
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx77:
	BANK1X
	MOVFW	SBufferOut77
	BANK0X
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx78:
	BANK1X
	MOVFW	SBufferOut78
	BANK0X
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx79:
	BANK1X
	MOVFW	SBufferOut79
	BANK0X
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx80:
	BANK1X
	MOVFW	SBufferOut80
	BANK0X
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx81:
	BANK1X
	MOVFW	SBufferOut81
	BANK0X
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx82:
	BANK1X
	MOVFW	SBufferOut82
	BANK0X
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx83:
	BANK1X
	MOVFW	SBufferOut83
	BANK0X
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx84:
	BANK1X
	MOVFW	SBufferOut84
	BANK0X
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx85:
	BANK1X
	MOVFW	SBufferOut85
	BANK0X
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx86:
	BANK1X
	MOVFW	SBufferOut86
	BANK0X
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx87:
	BANK1X
	MOVFW	SBufferOut87
	BANK0X
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx88:
	BANK1X
	MOVFW	SBufferOut88
	BANK0X
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx89:
	BANK1X
	MOVFW	SBufferOut89
	BANK0X
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx90:
	BANK1X
	MOVFW	SBufferOut90
	BANK0X
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx91:
	BANK1X
	MOVFW	SBufferOut91
	BANK0X
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx92:
	BANK1X
	MOVFW	SBufferOut92
	BANK0X
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN
LoadSyncTx93:
	BANK1X
	MOVFW	SBufferOut93
	BANK0X
	MOVWF	SyncTxByte
	GOTO	TxBitStuff
	RETURN




; ***************************************************************************
	ORG     H'260'			; This lot must be at 260H or higher.
TxBitStuff:
	MOVLW	H'02'			; Contain data tables for bit storage.
	MOVWF	PCLATH
	BTFSC	AddZeroBit		; Bit stuffing, insert a 0 if five Ones were sent.
	GOTO	InsZeroBit		; /
	MOVFW	TxBitIndex
	ADDWF	PCL,F
	GOTO	TxData0		; Header 0x7E B'01111110'
	GOTO	TxData1		; ///////
	GOTO	TxData2		; //////
	GOTO	TxData3		; /////
	GOTO	TxData4		; ////
	GOTO	TxData5		; ///
	GOTO	TxData6		; //
	GOTO	TxData7		; /

TxData0:
	BTFSS	SyncTxByte,0
	CALL	ZEROBit
	BTFSC	SyncTxByte,0
	CALL	ONEBit
	RETURN
TxData1:
	BTFSS	SyncTxByte,1
	CALL	ZEROBit
	BTFSC	SyncTxByte,1
	CALL	ONEBit
	RETURN
TxData2:
	BTFSS	SyncTxByte,2
	CALL	ZEROBit
	BTFSC	SyncTxByte,2
	CALL	ONEBit
	RETURN
TxData3:
	BTFSS	SyncTxByte,3
	CALL	ZEROBit
	BTFSC	SyncTxByte,3
	CALL	ONEBit
	RETURN
TxData4:
	BTFSS	SyncTxByte,4
	CALL	ZEROBit
	BTFSC	SyncTxByte,4
	CALL	ONEBit
	RETURN
TxData5:
	BTFSS	SyncTxByte,5
	CALL	ZEROBit
	BTFSC	SyncTxByte,5
	CALL	ONEBit
	RETURN
TxData6:
	BTFSS	SyncTxByte,6
	CALL	ZEROBit
	BTFSC	SyncTxByte,6
	CALL	ONEBit
	RETURN
TxData7:
	BTFSS	SyncTxByte,7
	CALL	ZEROBit
	BTFSC	SyncTxByte,7
	CALL	ONEBit
	CLRF	TxBitIndex			; Reset bit position counter so next Tx send bit 0.
	INCF	TxByteIndex,F		; Increse counter to Tx next Byte.
	RETURN

ZEROBit:	; Look for every 5 consecutive ONEs and insert a ZERO.
	CLRF	TxOnesCount
	INCF	TxBitIndex,F	; Move to next Bit slot.
	BCF		TxBitRAM		; Data to be Tx.
	RETURN
ONEBit:
	MOVFW	TxOnesCount		; Review last number of consecutive ONEs.
	SUBLW	0x04
	BTFSC	ZERO			; If there were already five ONEs then this is ONE number six so:
	GOTO	StartBitStuff	; goto ZEROBit to send an extra Zero.	
	INCF	TxOnesCount,F	; Inc Ones Counter.
	INCF	TxBitIndex,F	; Move to next Bit slot.
	BSF		TxBitRAM		; Data to be Tx.
	RETURN
StartBitStuff:
	BSF		AddZeroBit		; Bit stuff Zero Bit.
	CLRF	TxOnesCount		; A Zero is going to be inserted so clear consecutive ONEs counter. 
	INCF	TxBitIndex,F	; Move to next Bit slot.
	BSF		TxBitRAM		; Data to be Tx.
	RETURN

InsZeroBit:
	BCF		AddZeroBit		; Bit stuff Zero Bit.
	BCF		TxBitRAM		; Data to be Tx.
	RETURN





	END	;************************************
