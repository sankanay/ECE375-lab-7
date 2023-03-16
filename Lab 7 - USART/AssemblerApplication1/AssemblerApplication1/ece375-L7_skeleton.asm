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
.def	readyFlag = r18
.def	btn1Flag = r19
.def	itemchoice = r23
.def	waitcnt = r24			; Wait Loop Counter
.def	ilcnt = r25				; Inner Loop Counter



; Use this signal code between two boards for their game ready
.equ    SendReady = 0b11111111
.equ	Rock = 0b00000000
.equ	Paper = 0b00000001
.equ	Scissor = 0b00000010


;***********************************************************
;*  Start of Code Segment
;***********************************************************
.cseg                           ; Beginning of code segment

;***********************************************************
;*  Interrupt Vectors
;***********************************************************
.org    $0000                   ; Beginning of IVs
	    rjmp    INIT            ; Reset interrupt

.org	$0022
		rjmp	TIMER_INTERRUPT

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

		; Initialize LCD display
		rcall	LCDInit
		;rcall	LCDBacklightOn
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
		ldi		mpr, (1<<TXEN1 | 1<<RXEN1 | 1<<RXCIE1) 
		sts		UCSR1B, mpr 			

		; Clear flags for communication
		ldi		readyFlag, 0
		ldi		btn1Flag, 0
		ldi		itemchoice, 0

		; Welcome screen for the players
		rcall	SETUPLINES

		; Turn on interrupts
		sei

;***********************************************************
;*  Main Program
;***********************************************************
MAIN:
		in		mpr, PIND
		andi	mpr, (1<<4 | 1<<7 | 1<<5)
		cpi		mpr, $30		; check if left most is hit
		brne	NEXT			; branch to NEXT if not hit
		cpi		btn1Flag, 0
		brne	MAIN
		inc		btn1Flag		; inc btn1 flag
		rcall	WAIT_OPPONENT	; display "WAITING FOR OPPONENT"
		rcall	READY			; display "WAITING FOR OPPONENT"
		rcall	WAITING			; display "WAITING FOR OPPONENT"
		rcall	USART_Transmit	; transmit ready signal readyFlag=0 btn1 = 1
		inc		readyFlag
		rcall	START_DISPLAY

		rjmp	MAIN

NEXT:
		cpi		btn1Flag, 2		; compare button flag
		brne	MAIN			; branch main
		rcall	Wait			; wait between taps
		cpi		mpr, $A0		; PD4 input
		brne	MAIN			; branch main
		rcall	CHOSE_ITEM		; chose items per player
		rjmp	MAIN			; loop

TIMER_INIT:

		;TIMER/COUNTER1
		ldi		mpr, 0x48       ; Set the timer compare match value (18750)
		sts		OCR1AH, r16		; Load into OCR1A
		ldi		mpr, 0xCC
		sts		OCR1AL, r16

		ldi		mpr, 0b00000000	; set normal mode
		sts		TCCR1A, mpr

		ldi		mpr, 0b00000100	; set prescalar 1024
		sts		TCCR1B, mpr

		ldi		mpr, 0b00000010	; enable interrupt
		sts		TIMSK1, mpr

		ldi		mpr, 0b11110000
		out		PORTB, mpr	

		sei						; turn on interrupt

		ret

;****************************************************************
;*	Functions and Subroutines
;****************************************************************
;----------------------------------------------------------------
;-		FUNCTION: Initial Welcome Screen
;----------------------------------------------------------------
SETUPLINES:
	
		ldi		ZH, HIGH(STRING_BEG1<<1); Move strings from Program Memory to Data Memory
		ldi		ZL, LOW(STRING_BEG1<<1)
		lpm		r17, Z
		ldi		YL, $00
		ldi		YH, $01
		st		Y, r17
		

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
		

LINE2:
		lpm		mpr, Z+
		st		Y+, mpr
		cpi		ZL, low(STRING_END2<<1)
		brne	LINE2
		cpi		ZH, high(STRING_END2<<1)

		rcall	LCDWrite
		ret

;----------------------------------------------------------------
;-		FUNCTION: Display Waiting for Opponenet
;----------------------------------------------------------------
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

		rcall	LCDWrite				; write to LCD
		ret

;----------------------------------------------------------------
;-		FUNCTION: Transmit Ready from Players
;----------------------------------------------------------------
USART_Transmit: 
		cpi		btn1Flag, 0x1
		brne	ROCK_TRANSMIT
		ldi		mpr2, SendReady	; load ready code
		inc     btn1Flag
		rjmp	TRANSMIT

ROCK_TRANSMIT: 
		cpi		itemchoice, 1
		brne	PAPER_TRANSMIT
		ldi		mpr2, Rock		; load ready code
		ldi		readyFlag, Rock
		rjmp	TRANSMIT

PAPER_TRANSMIT:
		cpi		itemchoice, 2
		brne	SCISSOR_TRANSMIT
		ldi		mpr2, Paper		; load ready code
		ldi		readyFlag, Paper
		rjmp	TRANSMIT

SCISSOR_TRANSMIT:
		cpi		itemchoice, 0
		brne	NOTHING
		ldi		mpr2, Scissor	; load ready code
		ldi		readyFlag, Scissor
		rjmp	TRANSMIT

TRANSMIT: 	
		lds		mpr, UCSR1A		; load UCSR1A value
		sbrs	mpr, UDRE1		; Loop until UDR1 is empty 
		rjmp	TRANSMIT		; loop till empty buffer
		sts		UDR1, mpr2 		; Move data to transmit data buffer 
		ret

NOTHING:		
		ret

;----------------------------------------------------------------
;-		FUNCTION: Recieve Ready from Players
;----------------------------------------------------------------
USART_Receive:
		push	mpr
		lds		mpr2, UDR1
		cpi		mpr2, SendReady
		brne	ROCK_RCV
		inc		readyFlag
		rcall	START_DISPLAY
		rjmp	POP_MPR

ROCK_RCV: 
		cpi		mpr2, Rock
		brne	PAPER_RCV
		rcall   DISPLAY_ROCK_LN1
		ldi		ilcnt, Rock
		rjmp	POP_MPR

PAPER_RCV:
		cpi		mpr2, Paper
		brne	SCISSOR_RCV
		rcall   DISPLAY_PAPER_LN1
		ldi		ilcnt, Paper
		rjmp	POP_MPR

SCISSOR_RCV: 
		cpi		mpr2, Scissor
		brne	POP_MPR
		rcall   DISPLAY_SCISSOR_LN1
		ldi		ilcnt, Scissor
		rjmp	POP_MPR

POP_MPR:
		pop		mpr
		reti

;----------------------------------------------------------------
;-		FUNCTION: Start Game Message
;----------------------------------------------------------------
START_DISPLAY:
		cpi		readyFlag, 2	
		brlt	NOTHING
		rcall	LCDClr
		rcall	TIMER_INIT
		rcall	GAME_START
		rcall	GAME1
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

;----------------------------------------------------------------
;-		FUNCTION: Scroll through choices
;----------------------------------------------------------------
CHOSE_ITEM:
		inc		itemchoice
		cpi		itemchoice, 1
		brne	CHOICE2
		rcall	LCDClrLn2
		rcall	DISPLAY_ROCK
		ret
		
CHOICE2: 
		cpi		itemchoice, 2
		brne	CHOICE3
		rcall	LCDClrLn2
		rcall	DISPLAY_PAPER
		ret

CHOICE3:
		cpi		itemchoice, 3
		brne	NOTHING
		rcall	LCDClrLn2
		rcall	DISPLAY_SCISSOR
		ldi		itemchoice, 0
		ret

;----------------------------------------------------------------
;-		FUNCTION: Display Rock
;----------------------------------------------------------------
DISPLAY_ROCK:
		
		ldi		ZH, HIGH(STRING_BEG7<<1); Move strings from Program Memory to Data Memory
		ldi		ZL, LOW(STRING_BEG7<<1)
		lpm		r17, Z
		ldi		YL, $10
		ldi		YH, $01
		st		Y, r17

DISPLAY_ROCK2:

		lpm		mpr, Z+
		st		Y+, mpr
		cpi		ZL, low(STRING_END7<<1)
		brne	DISPLAY_ROCK2
		cpi		ZH, high(STRING_END7<<1)
		rcall	LCDWrLn2
		ret

;----------------------------------------------------------------
;-		FUNCTION: Display Rock to Line 1
;----------------------------------------------------------------
DISPLAY_ROCK_LN1:

		rcall	LCDClrLn1
		ldi		ZH, HIGH(STRING_BEG7<<1); Move strings from Program Memory to Data Memory
		ldi		ZL, LOW(STRING_BEG7<<1)
		lpm		r17, Z
		ldi		YL, $00
		ldi		YH, $01
		st		Y, r17

DISPLAY_ROCK_LN1_2:

		lpm		mpr, Z+
		st		Y+, mpr
		cpi		ZL, low(STRING_END7<<1)
		brne	DISPLAY_ROCK_LN1_2
		cpi		ZH, high(STRING_END7<<1)
		rcall	LCDWrLn1
		ret

;----------------------------------------------------------------
;-		FUNCTION: Display Paper
;----------------------------------------------------------------
DISPLAY_PAPER:
		
		ldi		ZH, HIGH(STRING_BEG8<<1); Move strings from Program Memory to Data Memory
		ldi		ZL, LOW(STRING_BEG8<<1)
		lpm		r17, Z
		ldi		YL, $10
		ldi		YH, $01
		st		Y, r17

DISPLAY_PAPER2:

		lpm		mpr, Z+
		st		Y+, mpr
		cpi		ZL, low(STRING_END8<<1)
		brne	DISPLAY_PAPER2
		cpi		ZH, high(STRING_END8<<1)
		rcall	LCDWrLn2
		ret

;----------------------------------------------------------------
;-		FUNCTION: Display Paper to Line 1
;----------------------------------------------------------------
DISPLAY_PAPER_LN1:
		
		rcall	LCDClrLn1
		ldi		ZH, HIGH(STRING_BEG8<<1); Move strings from Program Memory to Data Memory
		ldi		ZL, LOW(STRING_BEG8<<1)
		lpm		r17, Z
		ldi		YL, $00
		ldi		YH, $01
		st		Y, r17

DISPLAY_PAPER_LN1_2:

		lpm		mpr, Z+
		st		Y+, mpr
		cpi		ZL, low(STRING_END8<<1)
		brne	DISPLAY_PAPER_LN1_2
		cpi		ZH, high(STRING_END8<<1)
		rcall	LCDWrLn1
		ret

;----------------------------------------------------------------
;-		FUNCTION: Display Scissors
;----------------------------------------------------------------
DISPLAY_SCISSOR:
		
		ldi		ZH, HIGH(STRING_BEG9<<1); Move strings from Program Memory to Data Memory
		ldi		ZL, LOW(STRING_BEG9<<1)
		lpm		r17, Z
		ldi		YL, $10
		ldi		YH, $01
		st		Y, r17

DISPLAY_SCISSOR2:

		lpm		mpr, Z+
		st		Y+, mpr
		cpi		ZL, low(STRING_END9<<1)
		brne	DISPLAY_SCISSOR2
		cpi		ZH, high(STRING_END9<<1)
		rcall	LCDWrLn2
		ret

;----------------------------------------------------------------
;-		FUNCTION: Display Scissors
;----------------------------------------------------------------
DISPLAY_SCISSOR_LN1:

		rcall	LCDClrLn1
		ldi		ZH, HIGH(STRING_BEG9<<1); Move strings from Program Memory to Data Memory
		ldi		ZL, LOW(STRING_BEG9<<1)
		lpm		r17, Z
		ldi		YL, $00
		ldi		YH, $01
		st		Y, r17

DISPLAY_SCISSOR_LN1_2:

		lpm		mpr, Z+
		st		Y+, mpr
		cpi		ZL, low(STRING_END9<<1)
		brne	DISPLAY_SCISSOR_LN1_2
		cpi		ZH, high(STRING_END9<<1)
		rcall	LCDWrLn1
		ret

;----------------------------------------------------------------
;-		FUNCTION: TIMER/COUNTER1 Countdown
;----------------------------------------------------------------
/*COUNTDOWN:

		ldi		mpr, 0b11110000
		out		PORTB, mpr	
		
		ret*/

;----------------------------------------------------------------
;-		FUNCTION: TIMER/COUNTER1 Interrupt
;----------------------------------------------------------------
TIMER_INTERRUPT:

		; 6 second timer on 4 LEDs
		in		mpr, PORTB
		lsr		mpr 
		andi	mpr, $F0
		out		PORTB, mpr

		; Check if all LEDs are off
		cpi		mpr, $00
		breq	INTERRUPT_OFF
		
		reti

INTERRUPT_OFF:

		; Turn off Timer Interrupt
		ldi		mpr, 0b00000000
		sts		TIMSK1, mpr
		cpi		itemchoice, 4
		breq	DETERMINE_WINNER
		cpi		itemchoice, 5
		breq	REINIT
		rcall	USART_Transmit
		rcall	TIMER_INIT
		ldi		itemchoice, 4
		reti

REINIT:
		
		
		jmp		INIT
		
		
DETERMINE_WINNER:

		ldi		itemchoice, 5
		cp		readyFlag, ilcnt	; if both values are the same
		breq	DISPLAY_DRAW

		cpi		readyFlag, Rock		; if personal has rock
		breq	PLAYER1_ROCK		; then go to personal rock

		cpi		readyFlag, Paper	; if personal has paper
		breq	PLAYER1_PAPER		; then go to personal paper 

		cpi		readyFlag, Scissor ; if personal has scissors
		breq	PLAYER1_SCISSORS

		reti


PLAYER1_ROCK:
		
		cpi		ilcnt, Scissor		; if opponent has scissors
		breq	DISPLAY_WINNER		; then display winner
		rcall	DISPLAY_LOSER		; else display loser
		rcall	TIMER_INIT
		reti

PLAYER1_PAPER:
		;ldi		itemchoice, 5
		cpi		ilcnt, Rock			; if opponent has rock
		breq	DISPLAY_WINNER		; then display winner
		rcall	DISPLAY_LOSER		; else display loser
		rcall	TIMER_INIT
		reti

PLAYER1_SCISSORS:
		;ldi		itemchoice, 5
		cpi		ilcnt, Paper
		breq	DISPLAY_WINNER
		rcall	DISPLAY_LOSER
		rcall	TIMER_INIT
		reti


;----------------------------------------------------------------
;-		FUNCTION: Display Winner 
;----------------------------------------------------------------
DISPLAY_WINNER:

		rcall	LCDClrLn1
		ldi		ZH, HIGH(STRING_BEG11<<1); Move strings from Program Memory to Data Memory
		ldi		ZL, LOW(STRING_BEG11<<1)
		lpm		r17, Z
		ldi		YL, $00
		ldi		YH, $01
		st		Y, r17

DISPLAY_WINNER2:

		lpm		mpr, Z+
		st		Y+, mpr
		cpi		ZL, low(STRING_END11<<1)
		brne	DISPLAY_WINNER2
		cpi		ZH, high(STRING_END11<<1)
		rcall	LCDWrLn1
		rcall	TIMER_INIT
		reti
;----------------------------------------------------------------
;-		FUNCTION: Display Loser 
;----------------------------------------------------------------
DISPLAY_LOSER:

		rcall	LCDClrLn1
		ldi		ZH, HIGH(STRING_BEG10<<1); Move strings from Program Memory to Data Memory
		ldi		ZL, LOW(STRING_BEG10<<1)
		lpm		r17, Z
		ldi		YL, $00
		ldi		YH, $01
		st		Y, r17

DISPLAY_LOSER2:

		lpm		mpr, Z+
		st		Y+, mpr
		cpi		ZL, low(STRING_END10<<1)
		brne	DISPLAY_LOSER2
		cpi		ZH, high(STRING_END10<<1)
		rcall	LCDWrLn1
		rcall	TIMER_INIT
		reti

;----------------------------------------------------------------
;-		FUNCTION: Display Draw
;----------------------------------------------------------------
DISPLAY_DRAW:

		rcall	LCDClrLn1
		ldi		ZH, HIGH(STRING_BEG12<<1); Move strings from Program Memory to Data Memory
		ldi		ZL, LOW(STRING_BEG12<<1)
		lpm		r17, Z
		ldi		YL, $00
		ldi		YH, $01
		st		Y, r17

DISPLAY_DRAW2:

		lpm		mpr, Z+
		st		Y+, mpr
		cpi		ZL, low(STRING_END12<<1)
		brne	DISPLAY_DRAW2
		cpi		ZH, high(STRING_END12<<1)
		rcall	LCDWrLn1
		rcall	TIMER_INIT
		reti

;----------------------------------------------------------------
; Sub:	Wait
; Desc:	A wait loop that is 16 + 159975*waitcnt cycles or roughly
;		waitcnt*10ms.  Just initialize wait for the specific amount
;		of time in 10ms intervals. Here is the general eqaution
;		for the number of clock cycles in the wait loop:
;			(((((3*ilcnt)-1+4)*olcnt)-1+4)*waitcnt)-1+16
;----------------------------------------------------------------
Wait:
		push	waitcnt		; Save wait register
		push	mpr		; Save ilcnt register
		push	mpr2		; Save olcnt register

Loop1:	ldi		mpr2, 90	; load olcnt register
OLoop1:	ldi		mpr, 80	; load ilcnt register
ILoop1:	dec		mpr		; decrement ilcnt
		brne	ILoop1		; Continue Inner Loop
		dec		mpr2		; decrement olcnt
		brne	OLoop1		; Continue Outer Loop
		dec		waitcnt		; Decrement wait
		brne	Loop1		; Continue Wait loop

		pop		mpr2		; Restore olcnt register
		pop		mpr		; Restore ilcnt register
		pop		waitcnt		; Restore wait register
		ret					; Return from subroutine

;***********************************************************
;*	Stored Program Data
;***********************************************************

;-----------------------------------------------------------
; An example of storing a string. Note the labels before and
; after the .DB directive; these can help to access the data
;-----------------------------------------------------------
STRING_BEG1:
    .DB		"Welcome!"				; Declaring data in ProgMem
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
    .DB		"GAME START"			; Declaring data in ProgMem
STRING_END5:
STRING_BEG6:
	.DB		"for the opponent"
STRING_END6:
STRING_BEG7:
	.DB		"ROCK"
STRING_END7:
STRING_BEG8:
	.DB		"PAPER "
STRING_END8:
STRING_BEG9:
	.DB		"SCISSORS"
STRING_END9:
STRING_BEG10:
	.DB		"You Lost! "
STRING_END10:
STRING_BEG11:
	.DB		"You Won!"
STRING_END11:
STRING_BEG12:
	.DB		"DRAW! "
STRING_END12:

.include "LCDDriver.asm"
