;
; R48 March 28, 2025
; 
; this was written using assembler ca65 (version V2.19 and above)
; 
; mkdir bin
; cl65 -t cx16 -o bin/FXLINE.PRG fx_line-one.asm 
; x16emu.exe -prg bin/FXLINE.PRG -run
;

.org $080D
.segment "STARTUP"
.segment "INIT"
.segment "ONCE"
.segment "CODE"

;------------------------------------------------------------------------------
; This ONE PAGER draws one VERA FX line as presented in the VERA FX tutorial

;------------------------------------------------------------------------------
; Kernal subroutine alias
screen_mode = $FF5F


;------------------------------------------------------------------------------
; Vera access registers
verareg  = $9f20
veralo   = verareg+0  ; vera memory pointer (3 bytes - hi, mid, lo)
veramid  = verareg+1
verahi   = verareg+2

veradat0 = verareg+3 ; data read / write port on Address Select = 0
veradat1 = verareg+4 ; data read / write port on Address Selct = 1

veractl  = verareg+5 ; vera control register
veradcv  = verareg+9 ; vera video register DCSEL=0
verafx   = verareg+9 ; vera FX register when DCSEL=2

; x increment register
fx_x_inc_l = verareg+9 ; when DCSEL=3
fx_x_inc_h = verareg+10 

l0_config = $9f2d

CTRL_ADDRSEL = 1<<0  ; address select
CTRL_RESET   = 1<<7  ; reset 

DCSEL_0  = %00000000
DCSEL_2  = %00000100
DCSEL_3  = %00000110
DCSEL_4  = %00001000
DCSEL_5  = %00001010
DCSEL_6  = %00001100

; enable bits
FX_CTRL_4BIT_MODE            = 1<<3
FX_CTRL_16BIT_HOP            = 1<<4
FX_CTRL_ONE_BYTE_CACHE_CYCLE = 1<<5
FX_CTRL_CACHE_FILL_ENABLE    = 1<<6
FX_CTRL_CACHE_ENABLE         = 1<<6
FX_CTRL_TRANSPARENT_WR       = 1<<7

; enumerated address modes 
FX_CTRL_ADRESS_TRADITIONAL = 0
FX_CTRL_ADRESS_LINE_DRAW   = 1
FX_CTRL_ADRESS_POLY_FILL   = 2
FX_CTRL_ADRESS_AFFINE      = 3

; config options
CONFIG_BITMAP_MODE = 1<<2

COLOR_DEPTH_1BPP = 0
COLOR_DEPTH_2BPP = 1
COLOR_DEPTH_4BPP = 2
COLOR_DEPTH_8BPP = 3

DC_VIDEO_ENABLE_LAYER_0 = 1<<4  ; turn on layer 0 using the vera video register
DC_VIDEO_ENABLE_LAYER_1 = 1<<5  ; turn on layer 1 using the vera video register

VERA_STRIDE_1          = 1<<4  ; stride = 1: use this number of bytes to increment 
                               ; the current vera address when accessing the data port
VERA_STRIDE_320        = 14<<4

VERA_DECREMENT         = 1<<3  ; the data port decrements instead of increment



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


start:
    ; set screen mode to bitmap 
    lda #$80
    clc ; a clear tells the kernel this is setting a value from reg A
    jsr screen_mode ; same things as 'SCREEN $80' in BASIC

    ;------------------------------------------------------------------------------
    ; setup layer 0 to be in bitmap mode, 320, 8bpp
    lda #(CONFIG_BITMAP_MODE | COLOR_DEPTH_8BPP)
    sta l0_config

    lda #DCSEL_0
    sta veractl

    ; enable layer 0, turn off layer 1
    lda veradcv
    ora #DC_VIDEO_ENABLE_LAYER_0
    and #(255-DC_VIDEO_ENABLE_LAYER_1)
    sta veradcv

    jsr ClearBitmap

    ;------------------------------------------------------------------------------
    ; setup the line draw helper
    ;------------------------------------------------------------------------------

    ;------------------------------------------------------------------------------
    ; setup ADDR0 in the direction of increment
    lda #DCSEL_2       ; DCSEL=2, ADDRSEL=0
    sta veractl

    lda #VERA_STRIDE_320 ; ADDR0 increment: +320 bytes for 8bpp bitmap 320px wide
    sta verahi
    stz veramid
    stz veralo

    ;------------------------------------------------------------------------------
    lda #FX_CTRL_ADRESS_LINE_DRAW ; Entering *line draw mode* (when DCSEL==2)
    sta verafx

    ;------------------------------------------------------------------------------
    ; setup ADDR1 to the address of the starting pixel
    lda #(DCSEL_2 | CTRL_ADDRSEL) ; DCSEL=2, ADDRSEL=1
    sta veractl

    lda #VERA_STRIDE_1 ; ADDR1 increment: +1 byte, address $0
    sta verahi
    stz veramid ; Setting start to $00000
    stz veralo  ; Setting start to $00000

    ;------------------------------------------------------------------------------
    ; start drawing the line

    ; DCSEL_3 enables fx_x_inc_l & fx_x_inc_h 
    lda #DCSEL_3 ; DCSEL=3, ADDRSEL=0
    sta veractl

    ; Note: 73<<1 is just a nice looking slope ;)
    ; 73<<1 (=146) means: for each x pixel-step there is 146/512th y pixel-step
    lda #<(73<<1)            ; X increment low 
    sta fx_x_inc_l
    lda #>(73<<1)            ; X increment high
    sta fx_x_inc_h

    ldx #150 ; pixels
    lda #COLOR_WHITE

    draw_line_next_pixel:
       sta veradat1
       dex
       bne draw_line_next_pixel

    rts


;------------------------------------------------------------------------------
; clear the bitmap to purple color
color_choice: .byte $00
ClearBitmap:

    lda #COLOR_PURPLE
    sta color_choice

    stz veractl ; clear vera, set dataport 0

    ; clear the Bitmap memory $1:2C00 (320 x 240)
    lda #(VERA_STRIDE_1) ; ADDR1 increment: +1 byte
    sta verahi
    stz veramid
    stz veralo

    clear_screen_start:
        ldx #$00
        lda color_choice
        @clear_loop:
            sta veradat0

            dex
            bne @clear_loop

            lda verahi
            and #$01
            beq clear_screen_start

            lda veramid
            cmp #$2C
            bcc clear_screen_start

    rts