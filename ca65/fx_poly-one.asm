;
; R48 Mach 29, 2025
; 
; this was written using assembler ca65 (version V2.19 and above)
; 
; mkdir bin
; cl65 -t cx16 -o bin/FXPOLY.PRG fx_poly-one.asm 
; x16emu.exe -prg bin/FXPOLY.PRG -run
;

.org $080D
.segment "STARTUP"
.segment "INIT"
.segment "ONCE"
.segment "CODE"


jmp start

;------------------------------------------------------------------------------
; This ONE PAGER draws one VERA FX polygon as presented in the VERA FX tutorial

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

; x increment register (write only)
fx_x1_inc_l = verareg+9  ; when DCSEL=3
fx_x1_inc_h = verareg+10 
fx_x2_inc_l = verareg+11 ; when DCSEL=3
fx_x2_inc_h = verareg+12 

; x position register (write only)
fx_x_pos_l = verareg+9  ; when DCSEL=4
fx_x_pos_h = verareg+10 
fx_y_pos_l = verareg+11 ; when DCSEL=4
fx_y_pos_h = verareg+12 

fx_fill_len_l = verareg+11 ; when DCSEL=5
fx_fill_len_h = verareg+12 ; when DCSEL=5

l0_config = $9f2d

CTRL_ADDRSEL_0 = 0
CTRL_ADDRSEL_1 = 1     ; address select
CTRL_RESET     = 1<<7  ; reset 

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

FILL_LEN_HI            = 1<<7 ; If fill_len >= 16, this bit is set on fx_fill_len_l


BITMAP_WIDTH           = 320 ; pixels
BITMAP_HEIGTH          = 240

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



NUMBER_OF_ROWS: .byte $00
FILL_LENGTH_LOW: .byte $00
FILL_LENGTH_HIGH: .byte $00

start:
    ; set screen mode to bitmap 
    lda #$80
    clc ; a clear tells the kernel this is setting a value from reg A
    jsr screen_mode ; same things as 'SCREEN $80' in BASIC

    jsr ClearBitmap


    TRIANGLE_TOP_POINT_X=90
    TRIANGLE_TOP_POINT_Y=20


    ;--------------------------------------------------------------------------
    ; Set ADDR0 to the address of the y-position of the top point of the 
    ; triangle and x=0 
    lda #(DCSEL_2 | CTRL_ADDRSEL_0) ; DCSEL=2, ADDRSEL=0
    sta veractl
   
    lda #VERA_STRIDE_320            ; ADDR0 increment: +320 bytes
    sta verahi
    
    ; Note: we are setting ADDR0 to the leftmost pixel of a pixel row.
    lda #>(TRIANGLE_TOP_POINT_Y*BITMAP_WIDTH)
    sta veramid
    lda #<(TRIANGLE_TOP_POINT_Y*BITMAP_WIDTH)
    sta veralo

    ;--------------------------------------------------------------------------
    lda #FX_CTRL_ADRESS_POLY_FILL ; Entering *polygon filler mode* (when DCSEL==2)
    sta verafx
    
    ;--------------------------------------------------------------------------
    ; 
    lda #(DCSEL_3 | CTRL_ADDRSEL_0) ; DCSEL=3, ADDRSEL=0
    sta veractl
    
    ; IMPORTANT: these increments are *HALF* steps!
    lda #<(-110)             ; X1 increment low (signed)
    sta fx_x1_inc_l
    lda #>(-110)             ; X1 increment high (signed)
    and #%01111111           ; increment is only 15-bits long
    sta fx_x1_inc_h
    lda #<(380)              ; X2 increment low (signed)
    sta fx_x2_inc_l                
    lda #>(380)              ; X2 increment high (signed)
    and #%01111111           ; increment is only 15-bits long
    sta fx_x2_inc_h    

    ;--------------------------------------------------------------------------
    ; Setting x1 and x2 pixel position
   
    lda #(DCSEL_4 | CTRL_ADDRSEL_1) ; DCSEL=4, ADDRSEL=1
    sta veractl
    
    lda #<TRIANGLE_TOP_POINT_X
    sta fx_x_pos_l                ; X (=X1) pixel position low [7:0]
    sta fx_y_pos_l                ; Y (=X2) pixel position low [7:0]
    
    lda #>TRIANGLE_TOP_POINT_X
    sta fx_x_pos_h           ; X (=X1) pixel position high [10:8]
    ora #%00100000           ; Reset subpixel position
    sta fx_y_pos_h           ; Y (=X2) pixel position high [10:8]

    lda #VERA_STRIDE_1       ; ADDR1 increment: +1 byte
    sta verahi

    ldy #COLOR_WHITE         ; White color
    lda #150                 ; Hardcoded amount of lines to draw
    sta NUMBER_OF_ROWS

    jsr draw_polygon_part_using_polygon_filler


    ;--------------------------------------------------------------------------
    ; draw the lower part

    lda #(DCSEL_3 | CTRL_ADDRSEL_0) ; DCSEL=3, ADDRSEL=0
    sta veractl
    
    ; NOTE that these increments are *HALF* steps!!
    lda #<(-1590)             ; X2 increment low
    sta fx_x2_inc_l                
    lda #>(-1590)             ; X2 increment high
    and #%01111111            ; increment is only 15-bits long
    sta fx_x2_inc_h

    lda #50
    sta NUMBER_OF_ROWS
    jsr draw_polygon_part_using_polygon_filler

    rts


;------------------------------------------------------------------------------
; Routine to draw a triangle part
draw_polygon_part_using_polygon_filler:

    lda #(DCSEL_5 | CTRL_ADDRSEL_0)        ; DCSEL=5, ADDRSEL=0
    sta veractl

    polygon_fill_triangle_row_next:

        lda veradat1   ; This will do three things (inside of VERA): 
                       ;   1) Increment the X1 and X2 positions. 
                       ;   2) Calculate the fill_length value (= x2 - x1)
                       ;   3) Set ADDR1 to ADDR0 + X1

        ; What we do below is SLOW: we are not using all the information 
        ; we get here and are *only* reconstructing the 10-bit value.
        
        lda fx_fill_len_l     ; This contains: FILL_LENGTH >= 16, X1[1:0],
                              ;                FILL_LENGTH[3:0], 0
        lsr
        and #%00000111        ; We keep the 3 lower bits (note that bit 3
                              ; is ALSO in the HIGH byte, so we discard it)
        sta FILL_LENGTH_LOW   ; We now have 3 bits in FILL_LENGTH_LOW

        stz FILL_LENGTH_HIGH
        lda fx_fill_len_h     ; This contains: FILL_LENGTH[9:3], 0
        asl
        rol FILL_LENGTH_HIGH
        asl
        rol FILL_LENGTH_HIGH  ; FILL_LENGTH_HIGH now contains the two highest bits: 8 and 9
        ora FILL_LENGTH_LOW
        sta FILL_LENGTH_LOW   ; FILL_LENGTH_LOW now contains all lower 8 bits

        tax
        beq done_fill_triangle_pixel  ; If x = 0, we don't have to draw any pixels

        polygon_fill_triangle_pixel_next:
            sty veradat1        ; This draws a single pixel
            dex
            bne polygon_fill_triangle_pixel_next
    
        done_fill_triangle_pixel:
            ; We draw an additional FILL_LENGTH_HIGH * 256 pixels on this row
            lda FILL_LENGTH_HIGH
            beq polygon_fill_triangle_row_done

        polygon_fill_triangle_pixel_next_256:
            ldx #0
            polygon_fill_triangle_pixel_next_256_0:
                sty veradat1
                dex
                bne polygon_fill_triangle_pixel_next_256_0
                dec FILL_LENGTH_HIGH
                bne polygon_fill_triangle_pixel_next_256
            
        polygon_fill_triangle_row_done:

            ; We always increment ADDR0
            lda veradat0     ; this will increment ADDR0 with 320 bytes
                             ; So +1 vertically
            
            ; We check if we have reached the end, and if so we stop
            dec NUMBER_OF_ROWS
            bne polygon_fill_triangle_row_next

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