;
; R48 Feb 22, 2025
; 
; this was written using assembler ca65 (version V2.19 and above)
; 
; mkdir bin
; cl65 -t cx16 -o bin/INTERRUPTONE.PRG interrupt-one.asm 
; x16emu.exe -prg bin/INTERRUPTONE.PRG -run
;

.org $080D
.segment "STARTUP"
.segment "INIT"
.segment "ONCE"
.segment "CODE"


;------------------------------------------------------------------------------
; This ONE PAGER uses raster line interrupts to split the border color into 
; two different colors.
;
; To use raster interrupts:
;     1) Disable interrupts
;     2) Set the address of the custom subroutine on the kernal interrupt vector
;           a) Chain interrupts by setting a new subroutine on the vector
;           b) A VSYNC interrupt should exist in the chain
;           c) Return custom interrupt via 'rti' after pulling x,y,a registers
;              off the stack
;           d) Return from VSYNC interrupt jumping to the system interrupt 
;              routine
;     4) Set the interrupt enable flags
;           a) scanline number
;           b) sprite collision
;           c) vblank
;           d) audio
;     5) re-enable interrupts
;
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; Kernal subroutine alias
screen_mode = $FF5F
kernal_irq  = $F928 ; the system interrupt routine
                    ; this is already stored in CINV on system startup

; kernal interrupt vector (CINV)
CINV_L = $0314 ; IRQ routine vector low byte
CINV_H = $0315 ; IRQ routine vector high byte

;------------------------------------------------------------------------------
; Vera access registers
VERA_DC_HSCALE = $9F2A ; VERA_ctrl(1) (DCSEL) = 0
VERA_DC_VSCALE = $9F2B ; VERA_ctrl(1) (DCSEL) = 0

VERA_DC_BORDER = $9F2C ; the border color, starting from palette 0

; Raster IRQ
VERA_IEN        = $9F26 ; interrupt enable register
VERA_ISR        = $9F27 ; interrupt status register
VERA_SCANLINE_L = $9F28 ; read-only current scanline, lower 8 bits
VERA_IRQLINE_L  = $9F28 ; write-only scanline, lower 8 bits 

;------------------------------------------------------------------------------
; interrupt enable / status register flags
VERA_VSYNC_FLAG = 1<<0 ; interrupt trigger on VSYNC (vertical synchronization)
VERA_LINE_FLAG  = 1<<1 ; trigger on drawing a specific scaneline
VERA_SPRCOL     = 1<<2 ; trigger on sprite collision (at vsync)
VERA_AFLOW      = 1<<3 ; trigger on audio synchronization

VERA_SCANLINE_H = 1<<6 ; the 9th bit of VERA_SCANLINE, to be read from VERA_IEN
VERA_IRQLINE_H  = 1<<7 ; the 9th bit of VERA_IRQLINE, to be stored in VERA_IEN

;------------------------------------------------------------------------------
; palette 0 colors
COLOR_TRANSPARENT = 0
COLOR_WHITE       = 1
COLOR_RED         = 2
COLOR_CYAN        = 3
COLOR_PURPLE      = 4
COLOR_GREEN       = 5
COLOR_BLUE        = 6
COLOR_YELLOW      = 7
COLOR_ORANGE      = 8
COLOR_BROWN       = 9
COLOR_PINK        = 10
COLOR_DK_GRY      = 11
COLOR_M_GRY       = 12
COLOR_L_GREEN     = 13
COLOR_L_BLUE      = 14
COLOR_L_GRY       = 15

;------------------------------------------------------------------------------
; params: raster line (2 bytes), address (2 bytes)
;
; - line - the scanline that the interrupt routine will be called.  
;          this is a 9 bit number where the high bit is stored in IEN
; - addr - this is the address of the subroutine for the interrupt
.macro SetupLineInterrupt line, addr

    lda #VERA_LINE_FLAG
    sta VERA_IEN

	lda #<line    ; set raster interrupt to trigger on scanline
	sta VERA_IRQLINE_L
    lda #>line
    beq @Unset
        ; if the high bit has value, set it on the IEN register
        jsr SetIRQLineHigh
        jmp @SetAddress

    @Unset:
        ;  else the high bit is not set, clear the IEN register
        jsr UnsetIRQLineHigh

    @SetAddress:
    	lda #<addr ; set raster interrupt routine address
    	sta CINV_L ; onto the kernal interrupt vector
    	lda #>addr
    	sta CINV_H

.endmacro

;------------------------------------------------------------------------------
; params: address (2 bytes)
;
; - addr - this is the address of the subroutine for the interrupt
.macro SetupVsyncInterrupt addr

    lda #VERA_VSYNC_FLAG
    sta VERA_IEN

	lda #<addr ; set raster interrupt routine address
	sta CINV_L ; onto the kernal interrupt vector
	lda #>addr
	sta CINV_H

.endmacro

;------------------------------------------------------------------------------
Main:

    ;--------------------------------------------------------------------------
    ; C64 style mode with border and 40 visible characters wide by 25 tall
    ; Note that typing in this setup won't wrap text the same way as C64

    lda #08
    clc ; a clear C tells the kernal this JSR is setting a value from reg A
    jsr screen_mode ; same things as 'SCREEN 8' in BASIC

    lda #80
    sta VERA_DC_HSCALE

    lda #64
    sta VERA_DC_VSCALE

    jsr SetupInterrupt

    rts


;------------------------------------------------------------------------------
; Initialize the interrupt for the first time.  This will start the 
; interrupt chain where First and Second interrupts will ping-pong each other.
SetupInterrupt:

    sei ; disable interrupts

    SetupLineInterrupt 100, FirstInterrupt

    cli ; enable interrupts

    rts    


;------------------------------------------------------------------------------
; set bit 8 on the interrupt enable register
SetIRQLineHigh:
    lda VERA_IEN
    ora #VERA_IRQLINE_H
    sta VERA_IEN
    rts


;------------------------------------------------------------------------------
; unset bit 8 on the interrupt enable register
UnsetIRQLineHigh:
    lda VERA_IEN
    and #(255-VERA_IRQLINE_H)
    sta VERA_IEN
    rts


;------------------------------------------------------------------------------
FirstInterrupt:

    lda VERA_ISR
    tax
    and #VERA_LINE_FLAG
    beq @SystemRoutine

        ; ACK the line interrupt
        txa 
        ora #VERA_LINE_FLAG
        sta VERA_ISR

        ; on this line, change color
        lda #COLOR_GREEN
        sta VERA_DC_BORDER

        ; chain to the second interrupt 
        SetupLineInterrupt 300, SecondInterrupt
        
        ; IRQ implicitly pushes return address and flags onto stack
        ; we need to pull these back off so rti can return nicely
        ply
        plx
        pla
        rti

    @SystemRoutine:
        ; reaching here is possibly an error, but go ahead and jump out nicely
        lda #$0F
        sta VERA_ISR ; ack the status register

        ; call the default system interrupt routine
        jmp kernal_irq


;------------------------------------------------------------------------------
SecondInterrupt:
    
    lda VERA_ISR
    tax
    and #VERA_LINE_FLAG
    beq @SystemRoutine

        ; ACK the line interrupt
        txa 
        ora #VERA_LINE_FLAG
        sta VERA_ISR

        ; on this line, change color
        lda #COLOR_PURPLE
        sta VERA_DC_BORDER

        ; chain to the VSYNC interrupt
        SetupVsyncInterrupt VerticalSync

        ; IRQ implicitly pushes return address and flags onto stack
        ; we need to pull these back off so rti can return nicely
        ply
        plx
        pla
        rti

    @SystemRoutine:
        ; reaching here is possibly an error, but go ahead and jump out nicely
        lda #$0F
        sta VERA_ISR ; ack the status register

        ; call the default system interrupt routine
        jmp kernal_irq


;------------------------------------------------------------------------------
VerticalSync:
    lda VERA_ISR
    tax
    and #VERA_VSYNC_FLAG
    beq @SystemRoutine

        ; ACK the vsync interrupt
        txa 
        ora #VERA_VSYNC_FLAG
        sta VERA_ISR

        ; do vsync things
        ; ...

        ; bounce back to the first interrupt 
        SetupLineInterrupt 100, FirstInterrupt

    @SystemRoutine:
        ; call the default system interrupt routine after vsync
        jmp kernal_irq

