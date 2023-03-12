;***********************************************************
;*
;*	This is the TRANSMIT skeleton file for Lab 7 of ECE 375
;*
;*  	Rock Paper Scissors
;* 	Requirement:
;* 	1. USART1 communication
;* 	2. Timer/counter1 Normal mode to create a 1.5-sec delay
;***********************************************************
;*
;*	 Author: Enter your name
;*	   Date: Enter Date
;*
;***********************************************************

.include "m32U4def.inc"         ; Include definition file

;***********************************************************
;*  Internal Register Definitions and Constants
;***********************************************************
.def    mpr = r16               ; Multi-Purpose Register
.def	mpr2 = r17


.equ	ready1 = 7
.equ	cycle = 4

.def	readyFlag = r18
.def	recFlag = r19



; Use this signal code between two boards for their game ready
.equ    SendReady = 0b11111111



;***********************************************************
;*  Start of Code Segment
;***********************************************************
.cseg                           ; Beginning of code segment

;***********************************************************
;*  Interrupt Vectors
;***********************************************************
.org    $0000                   ; Beginning of IVs
	    rjmp    INIT            ; Reset interrupt

.org	$0032
		rjmp	USART_Receive

.org    $0056                   ; End of Interrupt Vectors

;***********************************************************
;*  Program Initialization
;***********************************************************
INIT:
		;Stack Pointer (VERY IMPORTANT!!!!)
		ldi		mpr, HIGH(RAMEND)
		out		SPH, mpr
		ldi		mpr, LOW(RAMEND)
		out		SPL, mpr


		

		; Initialize Port B for output
		ldi		mpr, $FF		; Set Port B Data Direction Register
		out		DDRB, mpr		; for output
		ldi		mpr, $00		; Initialize Port B Data Register
		out		PORTB, mpr		; so all Port B outputs are low

		; Initialize Port D for input
		ldi		mpr, $00		; Set Port D Data Direction Register
		out		DDRD, mpr		; for input
		ldi		mpr, $FF 		; Initialize Port D Data Register
		out		PORTD, mpr		; so all Port D inputs are Tri-State

		/*ldi		mpr, (1<<PD3)
		out		DDRD, mpr*/


		; Initialize LCD display
		rcall	LCDInit
		rcall	LCDBacklightOn
		rcall	LCDClr


		;USART1
		ldi		mpr, (1<<U2X1)	
		sts		UCSR1A, mpr
		
		;Set baudrate at 2400bps
		ldi		mpr, high(416) 
		sts		UBRR1H, mpr
		ldi		mpr, low(416)
		sts		UBRR1L, mpr	

		;Set frame format: 8 data bits, 2 stop bits
		ldi		mpr, (1<<USBS1 | 1<<UCSZ11 | 1<<UCSZ10 | 0<<UMSEL11 | 0<<UMSEL10) 
		sts 	UCSR1C, mpr	
		
		;Enable receiver and transmitter
		ldi	mpr, (1<<TXEN1 | 1<<RXEN1 | 1<<RXCIE1) 
		sts	UCSR1B, mpr 	
		
		
		
		
		;TIMER/COUNTER1
			;Set Normal mode
		ldi		readyFlag, 0
		ldi		recFlag, 0
		rcall	SETUPLINES
		rcall	LINE1
		rcall	LINE2

		;Other
		sei

;***********************************************************
;*  Main Program
;***********************************************************
MAIN:

		in		mpr, PIND
		andi	mpr, (1<<4 | 1<<7 | 1<<5)
		cpi		mpr, $30		; check if left most is hit
		brne	NEXT			; branch to NEXT if not hit
		rcall	WAIT_OPPONENT	; display "WAITING FOR OPPONENT"
		rcall	READY			; display "WAITING FOR OPPONENT"
		rcall	WAITING			; display "WAITING FOR OPPONENT"
		rcall	USART_Transmit	; transmit ready signal
		rjmp	MAIN
NEXT:
		cpi		mpr, $90
		brne	MAIN
		nop
		rjmp	MAIN




;***********************************************************
;*	Functions and Subroutines
;***********************************************************
SETUPLINES:
	
		ldi		ZH, HIGH(STRING_BEG1<<1); Move strings from Program Memory to Data Memory
		ldi		ZL, LOW(STRING_BEG1<<1)
		lpm		r17, Z
		ldi		YL, $00
		ldi		YH, $01
		st		Y, r17
		ret

LINE1:
		lpm		mpr, Z+
		st		Y+, mpr
		cpi		ZL, low(STRING_END1<<1)
		brne	LINE1
		cpi		ZH, high(STRING_END1<<1)	

		ldi		ZH, HIGH(STRING_BEG2<<1); Move strings from Program Memory to Data Memory
		ldi		ZL, LOW(STRING_BEG2<<1)
		lpm		r17, Z
		ldi		YL, $10
		ldi		YH, $01
		st		Y, r17
		ret

LINE2:
		lpm		mpr, Z+
		st		Y+, mpr
		cpi		ZL, low(STRING_END2<<1)
		brne	LINE2
		cpi		ZH, high(STRING_END2<<1)

		rcall	LCDWrite
		ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
WAIT_OPPONENT:

		ldi		ZH, HIGH(STRING_BEG3<<1); Move strings from Program Memory to Data Memory
		ldi		ZL, LOW(STRING_BEG3<<1)
		lpm		r17, Z
		ldi		YL, $00
		ldi		YH, $01
		st		Y, r17
		ret

READY:
		lpm		mpr, Z+
		st		Y+, mpr
		cpi		ZL, low(STRING_END3<<1)
		brne	READY
		cpi		ZH, high(STRING_END3<<1)	

		ldi		ZH, HIGH(STRING_BEG4<<1); Move strings from Program Memory to Data Memory
		ldi		ZL, LOW(STRING_BEG4<<1)
		lpm		r17, Z
		ldi		YL, $10
		ldi		YH, $01
		st		Y, r17
		ret

WAITING:
		lpm		mpr, Z+
		st		Y+, mpr
		cpi		ZL, low(STRING_END4<<1)
		brne	WAITING
		cpi		ZH, high(STRING_END4<<1)

		rcall	LCDWrite
		ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

USART_Transmit: 
		;inc		readyFlag		; 1 + 1 = 2
		lds		mpr, UCSR1A
		ldi		mpr2, SendReady
		sbrs	mpr, UDRE1		; Loop until UDR1 is empty 
		rjmp	USART_Transmit 
		sts		UDR1, mpr2 		; Move data to transmit data buffer 
		rcall	USART_Receive
		ret

USART_Receive:
		inc		readyFlag
		cpi		readyFlag, 2	;2 == 2
		brne	NOTHING
		rcall	USART_Rec
		/*push	mpr
		lds		mpr2, UDR1
		cpi		mpr2, SendReady
		brne	USART_Receive
		rcall	LCDClr
		rcall	GAME_START
		rcall	GAME1
		;rcall	GAME2
		pop		mpr*/
		reti

NOTHING:
		ret

USART_Rec:
		push	mpr
		lds		mpr2, UDR1
		cpi		mpr2, SendReady
		brne	USART_Rec
		rcall	LCDClr
		rcall	GAME_START
		rcall	GAME1
		pop		mpr
		ldi		readyFlag, 0
		ret

GAME_START:
		ldi		ZH, HIGH(STRING_BEG5<<1); Move strings from Program Memory to Data Memory
		ldi		ZL, LOW(STRING_BEG5<<1)
		lpm		r17, Z
		ldi		YL, $00
		ldi		YH, $01
		st		Y, r17
		ret

GAME1:
		lpm		mpr, Z+
		st		Y+, mpr
		cpi		ZL, low(STRING_END5<<1)
		brne	GAME1
		cpi		ZH, high(STRING_END5<<1)	

		rcall	LCDWrite
		ret

;***********************************************************
;*	Stored Program Data
;***********************************************************

;-----------------------------------------------------------
; An example of storing a string. Note the labels before and
; after the .DB directive; these can help to access the data
;-----------------------------------------------------------
STRING_BEG1:
    .DB		"Welcome!"		; Declaring data in ProgMem
STRING_END1:
STRING_BEG2:
	.DB		"Please press PD7"
STRING_END2:
STRING_BEG3:
    .DB		"READY. Waiting"		; Declaring data in ProgMem
STRING_END3:
STRING_BEG4:
	.DB		"for the opponent"
STRING_END4:
STRING_BEG5:
    .DB		"GAME START"		; Declaring data in ProgMem
STRING_END5:
STRING_BEG6:
	.DB		"for the opponent"
STRING_END6:
/*STRING_BEG7:
	.DB		"ROCK"
STRING_END7:
STRING_BEG8:
	.DB		"PAPER"
STRING_END8:
STRING_BEG9:
	.DB		"SCISSOR"
STRING_END9:*/

.include "LCDDriver.asm"
