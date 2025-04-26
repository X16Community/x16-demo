;
; R48 Mach 28, 2025
; 
; this was written using assembler ca65 (version V2.19 and above)
; 
; mkdir bin
; cl65 -t cx16 -o bin/FXAFFINE.PRG fx_affine-one.asm 
; x16emu.exe -prg bin/FXAFFINE.PRG -run
;

.org $080D
.segment "STARTUP"
.segment "INIT"
.segment "ONCE"
.segment "CODE"


jmp start

;------------------------------------------------------------------------------
; This ONE PAGER draws one VERA FX affine tiles as presented in the VERA FX tutorial

;------------------------------------------------------------------------------
; Kernal subroutine alias
screen_mode = $FF5F

;------------------------------------------------------------------------------
; Vera memory map
vreg_bmp  = $00000  ; $0:0000-$1:2BFF | 320x240@256c Bitmap
                    ; $1:2C00-$1:2FFF | unused (1024 bytes)
vreg_sprd = $13000  ; $1:3000-$1:AFFF | Sprite Image Data (up to $1000 per sprite at 64x64 8-bit)
vreg_txt  = $1B000  ; $1:B000-$1:EBFF | Text Mode
                    ; $1:EC00-$1:EFFF | unused (1024 bytes)
vreg_cmp  = $1F000  ; $1:F000-$1:F7FF | charset 
                    ; $1:F800-$1:F9BF | unused (448 bytes)
                    ; $1:F9C0-$1:F9FF | VERA PSG Registers (16 x 4 bytes)
vreg_pal  = $1FA00  ; $1:FA00-$1:FBFF | VERA Color Palette (256 x 2 bytes)
vreg_spra = $1FC00  ; $1:FC00-$1:FFFF | VERA Sprite Attributes (128 x 8 bytes)


vreg_tile_base = $13000 ; these have to be chosen such that only the top 6 bits 
vreg_map_base  = $13800 ; are set on the FX registers

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

fx_tile_base = verareg+10  ; when DCSEL=2
fx_map_base  = verareg+11 

; x position register (write only)
fx_x_pos_l = verareg+9  ; when DCSEL=4
fx_x_pos_h = verareg+10 
fx_y_pos_l = verareg+11 ; when DCSEL=4
fx_y_pos_h = verareg+12 

; x increment register (write only)
fx_x1_inc_l = verareg+9  ; when DCSEL=3
fx_x1_inc_h = verareg+10 
fx_y_inc_l  = verareg+11 ; when DCSEL=3
fx_y_inc_h  = verareg+12 



VERA_STRIDE_1          = 1<<4  ; stride = 1: use this number of bytes to increment 
                               ; the current vera address when accessing the data port
VERA_STRIDE_320        = 14<<4

CTRL_ADDRSEL_0 = 0
CTRL_ADDRSEL_1 = 1     ; address select
CTRL_RESET     = 1<<7  ; reset 

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

TILE_BASE_ENABLE_AFFINE_CLIP = 1<<1

FX_MAP_SIZE_2   = 0
FX_MAP_SIZE_8   = 1
FX_MAP_SIZE_32  = 2
FX_MAP_SIZE_128 = 3

DCSEL_0  = %00000000
DCSEL_2  = %00000100
DCSEL_3  = %00000110
DCSEL_4  = %00001000
DCSEL_5  = %00001010
DCSEL_6  = %00001100

;------------------------------------------------------------------------------
; palette 0 colors
COLOR_BLACK       = 0
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

TILE_NUM_BYTES = 64

BITMAP_WIDTH  = 320 ; pixels
BITMAP_HEIGTH = 240

; use a ZP Load address
.define LOAD_ADDRESS $04

; address of the top left of the bitmap (vreg_bmp)
VRAM_ADDR_DESTINATION: .byte $00, $00, $00

start:
    ; set screen mode to bitmap 
    lda #$80
    clc ; a clear tells the kernel this is setting a value from reg A
    jsr screen_mode ; same things as 'SCREEN $80' in BASIC

    jsr ClearBitmap

    jsr SetupMapData
    jsr SetupTileData

    ;--------------------------------------------------------------------------
    ; setup the affine helper registers
    ; -- Set up tile data and map data addresses, map size and clipping
    
    lda #(DCSEL_2 | CTRL_ADDRSEL_0)          ; DCSEL=2, ADDRSEL=0
    sta veractl
    
    lda #(vreg_tile_base >> 9)
    and #%11111100                      ; the 6 highest bits of the tile address are set
    ora #TILE_BASE_ENABLE_AFFINE_CLIP   ; clip = 1
    sta fx_tile_base
    
    lda #(vreg_map_base >> 9)
    and #%11111100       ; the 6 highest bits of the map address are set
    ora #FX_MAP_SIZE_32   ; Map size = 32x32 tiles
    sta fx_map_base

    ;--------------------------------------------------------------------------
    ; setup the shear
    
    lda #(FX_CTRL_TRANSPARENT_WR | FX_CTRL_ADRESS_AFFINE)  ; transparent writes = 1, affine helper mode
    sta verafx ; when DCSEL = 2

    ; -- Set up x and y increments --

    lda #(DCSEL_3 | CTRL_ADDRSEL_0)    ; DCSEL=3, ADDRSEL=0
    sta veractl
    
    lda #0        
    sta fx_x1_inc_l
    lda #%00000010    ; X increment = 1.0 pixel to the right each step
    sta fx_x1_inc_h
    lda #<(-40<<1)
    sta fx_y_inc_l
    lda #>(-40<<1)    ; Y increment = -40/256th of a pixel each step
    and #%01111111    ; increment is only 15 bits long
    sta fx_y_inc_h

    ; We start to draw at the top-left position on screen
    stz VRAM_ADDR_DESTINATION
    stz VRAM_ADDR_DESTINATION+1
    stz VRAM_ADDR_DESTINATION+2

    ;--------------------------------------------------------------------------
    ; draw the rows
    ldx #0
       
    draw_next_row:

        lda #(DCSEL_3 | CTRL_ADDRSEL_0) ; DCSEL=3, ADDRSEL=0
        sta veractl

        lda #VERA_STRIDE_1              ; ADDR0 increment is +1 byte
        ora VRAM_ADDR_DESTINATION+2
        sta verahi
        lda VRAM_ADDR_DESTINATION+1
        sta veramid
        lda VRAM_ADDR_DESTINATION
        sta veralo
        
        ; Setting the source x/y position
        
        lda #(DCSEL_4 | CTRL_ADDRSEL_1) ; DCSEL=4, ADDRSEL=1
        sta veractl
        
        lda #0          ; X pixel position low [7:0] = 0
        sta fx_x_pos_l
        lda #0          ; X pixel position high [10:8] = 0
        sta fx_x_pos_h
        
        txa             ; Lazy and simple: we use register x (= destination y) as our y-position in the source
        sta fx_y_pos_l
        lda #%00000000  ; Y pixel position high [10:8] = 0
        sta fx_y_pos_h
        
        ldy #0
        @draw_next_pixel:
            lda veradat1
            sta veradat0
            
            iny
            bne @draw_next_pixel

        ; at end of each row
        ; We increment our destination address with +320
        clc
        lda VRAM_ADDR_DESTINATION
        adc #<BITMAP_WIDTH
        sta VRAM_ADDR_DESTINATION
        lda VRAM_ADDR_DESTINATION+1
        adc #>BITMAP_WIDTH
        sta VRAM_ADDR_DESTINATION+1
        lda VRAM_ADDR_DESTINATION+2
        adc #0
        sta VRAM_ADDR_DESTINATION+2

        inx
        cpx #180                 ; we do 180 rows
        bne draw_next_row

    @stay_forever:
    jmp @stay_forever

    rts


;------------------------------------------------------------------------------
SetupMapData:
    ;--------------------------------------------------------------------------
    ; -- Setting up the VRAM address for the map data --
    lda #VERA_STRIDE_1         ; increment 1 byte
    ora #^vreg_map_base
    sta verahi
    lda #>vreg_map_base
    sta veramid
    lda #<vreg_map_base
    sta veralo
    
    ; -- Load tile indexes into VRAM (32x32 map) --
    
    lda #<tile_map_data
    sta LOAD_ADDRESS
    lda #>tile_map_data
    sta LOAD_ADDRESS+1
    
    ldx #4
    @next_eight_rows:
        ldy #0
        @next_tile_index:
            lda (LOAD_ADDRESS), y
            sta veradat0
            iny
            bne @next_tile_index
        inc LOAD_ADDRESS+1     ; we increment the address by 256 
        dex
        bne @next_eight_rows

    rts


;------------------------------------------------------------------------------
SetupTileData:
    ;--------------------------------------------------------------------------
    ; -- Setting up the VRAM address for the tile data --
    lda #VERA_STRIDE_1
    ora #^vreg_tile_base
    sta verahi
    lda #>vreg_tile_base
    sta veramid
    lda #<vreg_tile_base
    sta veralo
    
    lda #COLOR_BLACK         ; tile 0 is black
    ldx #TILE_NUM_BYTES
    @next_black_pixel:
        sta veradat0
        dex
        bne @next_black_pixel
    
    lda #COLOR_RED           ; tile 1 is red
    ldx #TILE_NUM_BYTES
    @next_red_pixel:
        sta veradat0
        dex
        bne @next_red_pixel
    
    lda #COLOR_WHITE         ; tile 2 is white
    ldx #TILE_NUM_BYTES
    @next_white_pixel:
        sta veradat0
        dex
        bne @next_white_pixel
    
    lda #COLOR_BLUE          ; tile 3 is blue
    ldx #TILE_NUM_BYTES
    @next_blue_pixel:
        sta veradat0
        dex
        bne @next_blue_pixel

    rts


;------------------------------------------------------------------------------
; clear the bitmap
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


tile_map_data:

    .byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte 2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    
    .byte 2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte 2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte 3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte 3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    
    .byte 3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
