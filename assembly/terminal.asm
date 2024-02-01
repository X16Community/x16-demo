;terminal example
;2024 David Murray
;dfwgreencars@gmail.com

!to "TERMINAL.PRG",cbm
!cpu 65c02

*=$0801		;START ADDRESS IS $0801

TXRX_BUFFER		=$9F60     
INTERRUPT_ENABLE	=$9F61
INTERRUPT_IDENT		=$9F62 	
FIFO_CONTROL		=$9F62   	
LINE_CONTROL		=$9F63
MODEM_CONTROL		=$9F64
LINE_STATUS		=$9F65
MODEM_STATUS		=$9F66
SCRATCH			=$9F67
DIVISOR_LATCH_LOW	=$9F60	;same as TXRX, but when bit-7 of line control is high
DIVISOR_LATCH_HI	=$9F61	;same as IRQE, but when bit-7 of line control is high

;ZERO PAGE VARIABLES
BAUD_SELECT		=$20
TERM_TYPE		=$21	;0=Commodore 1=ASCII

;Kernal routines
GETIN		=$FFE4
CHROUT		=$FFD2
SET_CHARSET	=$FF62

BASIC:	!BYTE $0B,$08,$01,$00,$9E,$32,$30,$36,$31,$00,$00,$00
		;Adds BASIC line:  1 SYS 2061
START_HERE:
	JSR	ASK_BAUD
	JSR	ASK_TERM
	JSR	INIT_SERIAL
	JSR	SET_TERM_TYPE
	JSR	PRINT_TERMINAL_READY	
	JMP	TERMINAL_LOOP

SET_TERM_TYPE:
        LDA    TERM_TYPE
        CMP    #0    ;commodore
        BNE    STT3
    	LDA    #$0E    ;Set upper/lower case
	JSR    CHROUT
	RTS
STT3:   CMP    #1    ;ASCII
	BNE    STT4
	LDA    #15    
	JSR    CHROUT
STT4:   RTS

INIT_SERIAL:
	LDA	#%10000000	;Enable DLAB registers
	STA	LINE_CONTROL
	LDX	BAUD_SELECT
	LDA	BAUD_TABLE_L,X
	STA	DIVISOR_LATCH_LOW
	LDA	BAUD_TABLE_H,X
	STA	DIVISOR_LATCH_HI
	LDA	#%00000011	;Set N-8-1 / disable DLAB register
	STA	LINE_CONTROL
	LDA	#%00001111	;Enable and reset FIFO
	STA	FIFO_CONTROL		
	LDA	#%00000001	;Turn on DTR
	STA	MODEM_CONTROL
	RTS

TERMINAL_LOOP:
	LDA	LINE_STATUS	;check if data is waiting in buffer
	AND	#%00000001
	CMP	#%00000001	;byte waiting in buffer
	BNE	TERM1
	JSR	RX_BYTE	
TERM1:	JSR	GETIN
	CMP	#0
	BEQ	TERMINAL_LOOP
	CMP	#3		;run/stop key
	BNE	TERM2
	RTS			;RETURN TO BASIC
TERM2:	JSR	TX_BYTE
	JMP	TERMINAL_LOOP

RX_BYTE:
	LDA	TXRX_BUFFER	;read byte from buffer
	JSR	CHROUT		;send byte to screen
	RTS

TX_BYTE:
	TAY	
	LDA	LINE_STATUS	;Make sure TX buffer is ready
	AND	#%00100000
	CMP	#%00100000	;1= THR IS EMPTY
	BNE	TX_BYTE		;should probably add some sort of time-out
	STY	TXRX_BUFFER	;in the future to this routine.
	RTS

ASK_BAUD:
	LDX	#0
ASK1:	LDA	BAUD_STRING,X
	CMP	#0
	BEQ	ASK2
	JSR	CHROUT
	INX	
	JMP	ASK1
ASK2:	JSR	GETIN
	CMP	#0
	BEQ	ASK2
	CMP	#65
	BCC	ASK2
	CMP	#73
	BCS	ASK2
	SEC
	SBC	#65
	STA	BAUD_SELECT
	RTS

ASK_TERM:
	LDX	#0
ASK3:	LDA	TERM_STRING,X
	CMP	#0
	BEQ	ASK4
	JSR	CHROUT	
	INX
	JMP	ASK3
ASK4:	JSR	GETIN
	CMP	#0
	BEQ	ASK4
	CMP	#65
	BCC	ASK4
	CMP	#67
	BCS	ASK4
	SEC
	SBC	#65
	STA	TERM_TYPE
	RTS

PRINT_TERMINAL_READY:
	LDX	#0
TR2:	LDA	TERM_READY_STRING,X
	CMP	#0
	BEQ	TR3
	JSR	CHROUT	
	INX
	JMP	TR2
TR3:	RTS

BAUD_STRING:
	!PET	"select baud rate",13
	!PET	"a-300",13
	!PET	"b-1200",13
	!PET	"c-2400",13
	!PET	"d-9600",13
	!PET	"e-19200",13
	!PET	"f-38400",13
	!PET	"g-57600",13
	!PET	"h-115200",13,0

TERM_STRING:
	!PET	"select terminal type",13
	!PET	"a-commodore",13
	!PET	"b-ascii",13,0

TERM_READY_STRING:
    !BYTE    $90,$01,$05,$93    ;set color to white on black, clear screen.
    !PET    "terminal ready.",13,0

BAUD_TABLE_L:
	!BYTE	$00	;300
	!BYTE	$C0	;1200
	!BYTE	$E0	;2400
	!BYTE	$78	;9600
	!BYTE	$3C	;19200
	!BYTE	$1E	;38400
	!BYTE	$14	;57600
	!BYTE	$0A	;115200
BAUD_TABLE_H:
	!BYTE	$0F	;300
	!BYTE	$03	;1200
	!BYTE	$01	;2400
	!BYTE	$00	;9600
	!BYTE	$00	;19200
	!BYTE	$00	;38400
	!BYTE	$00	;57600
	!BYTE	$00	;115200








