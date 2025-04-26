;
; R48 Feb 15, 2025
; 
; this was written using assembler ca65 (version V2.19 and above)
; 
; mkdir bin
; cl65 -t cx16 -o bin/SPRITEONE.PRG sprite-one.asm 
; x16emu.exe -prg bin/SPRITEONE.PRG -run
;

.org $080D
.segment "STARTUP"
.segment "INIT"
.segment "ONCE"
.segment "CODE"


;------------------------------------------------------------------------------
; This ONE PAGER merely turns on one sprite
;
; To display sprites:
; 1) Enable sprites on the video register
; 2) Initialize the sprite attribute data in Vera memory
;       a) attributes contain the pointer to the image data
;       b) can be used to flip the sprite
;       c) set the dimensions and coordinates of the sprite
;       d) containt he palette data for the sprite
;       e) sets the draw priority and z-order
; 3) Copy the image data to Vera memory
;       a) this is the raw, indexed pixel data
;       b) can be 8 bit or 4 bit per pixel
;       c) color index 0 is transparent
;
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; Kernel subroutine alias
screen_mode = $FF5F

;------------------------------------------------------------------------------
; Vera access registers
verareg  = $9f20
veralo   = verareg+0  ; vera memory pointer (3 bytes - hi, mid, lo)
veramid  = verareg+1
verahi   = verareg+2

veradat0 = verareg+3 ; data read / write port on Address Select = 0

veractl  = verareg+5 ; vera control register
veradcv  = verareg+9 ; vera video register

; sprite 0 registers
SPRITE_ATTRIBUTE_0  = vreg_spra
SPRITE_IMAGE_DATA_0 = vreg_sprd  ; $1:3000-$1:AFFF | Sprite Image Data (up to $1000 per sprite at 64x64 8-bit)

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

;------------------------------------------------------------------------------
; Vera register flag constants
DC_VIDEO_ENABLE_SPRITE = 1<<6  ; turn on sprites using the vera video register

VERA_STRIDE_1          = 1<<4  ; stride = 1: use this number of bytes to increment 
                               ; the current vera address when accessing the data port

; sprite attribute flags
SPRITE_ATTR_MODE_4bpp = 0
SPRITE_ATTR_MODE_8bpp = 1<<7

SPRITE_ATTR_Z_DISABLED      = 0     ; sprite is turned off
SPRITE_ATTR_Z_BG_LAYER0     = 1<<2  ; between background and layer 0
SPRITE_ATTR_Z_LAYER0_LAYER1 = 2<<2  ; between layer 0 and layer 1
SPRITE_ATTR_Z_TOP_MOST      = 3<<2  ; over layer 1

SPRITE_ATTR_WIDTH_8  = 0<<4 ;  8  pixels
SPRITE_ATTR_WIDTH_16 = 1<<4 ; 16  pixels
SPRITE_ATTR_WIDTH_32 = 2<<4 ; 32  pixels
SPRITE_ATTR_WIDTH_64 = 3<<4 ; 64  pixels

SPRITE_ATTR_HEIGHT_8  = 0<<6 ;  8  pixels
SPRITE_ATTR_HEIGHT_16 = 1<<6 ; 16  pixels
SPRITE_ATTR_HEIGHT_32 = 2<<6 ; 32  pixels
SPRITE_ATTR_HEIGHT_64 = 3<<6 ; 64  pixels

SPRITE_ATTR_PALETTE_0 = 0  ; Commodore 64 colors
SPRITE_ATTR_PALETTE_1 = 1  ; Gray scale

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
start:
    ; set screen mode 3
    lda #03
    clc ; a clear tells the kernel this is setting a value from reg A
    jsr screen_mode ; same things as 'SCREEN 3' in BASIC

    ; enable the sprite bit flag on the video register
    lda veradcv
    ora #DC_VIDEO_ENABLE_SPRITE
    sta veradcv

    jsr CopySpriteAttribute0
    jsr CopySpriteImageData0

    rts


;------------------------------------------------------------------------------
; Simply copy the 8 bytes of sprite attribute #0 into vera
NUM_BYTES_PER_ATTRIBUTE = $08
CopySpriteAttribute0:
    
    jsr SetSpriteAttr0Ptr

    ldx #$00
@CopyLoop:
    lda SpriteAttributes0,x
    sta veradat0
    inx
    cpx #NUM_BYTES_PER_ATTRIBUTE                 
    bne @CopyLoop
    rts


;------------------------------------------------------------------------------
; place the Sprite 0 attribute pointer on the vera access register
; 
; This Vera address pointer is used to shuttle data to and from
; Vera's FPGA memory.  Two data ports are available to do this.
; This demonstration uses data port 0.
SetSpriteAttr0Ptr:
    
    ; clear the vera control register; sets data port 0
    stz veractl

    ; destination vera pointer (3 bytes - hi, mid, and low)
    lda #^SPRITE_ATTRIBUTE_0   ; '^' = bits 23-16 (aka bank byte)
    ora #VERA_STRIDE_1         ; stride = 1 - increment this address by # of bytes 
                               ; amount while writing to selected veradata port
    sta verahi

    lda #>SPRITE_ATTRIBUTE_0   ; '>' = 2nd from lower, bits 15:8
    sta veramid

    lda #<SPRITE_ATTRIBUTE_0   ; '<' = lower byte, bits 7:0
    sta veralo

    rts


;------------------------------------------------------------------------------
; converts the ascii art to color sprite data, and stows it into Vera memory.
CopySpriteImageData0:

    jsr SetSpriteImage0Ptr

    ;--------------------------------------------------------------------------
    ldy #COLOR_BROWN ; this value indexes the palette set by the sprite attribute
    ldx #0
l1:	lda sprite,x
    jsr convert_color
    sta veradat0
    inx
    bne l1
l2:	lda sprite + $100,x
    jsr convert_color
    sta veradat0
    inx
    bne l2
l3:	lda sprite + $200,x
    jsr convert_color
    sta veradat0
    inx
    bne l3
l4:	lda sprite + $300,x
    jsr convert_color
    sta veradat0
    inx
    bne l4

    rts


;------------------------------------------------------------------------------
; place the Sprite 0 Image pointer
SetSpriteImage0Ptr:

    stz veractl

    ; destination vera pointer 
    lda #^SPRITE_IMAGE_DATA_0  
    ora #VERA_STRIDE_1         
    sta verahi

    lda #>SPRITE_IMAGE_DATA_0  
    sta veramid

    lda #<SPRITE_IMAGE_DATA_0  
    sta veralo
    rts


;------------------------------------------------------------------------------
; reg A - input character read from source sprite data
; returns COLOR_TRANSPARENT if '.', a chosen color, or reg Y => Reg A otherwise
convert_color:
    cmp #'.'
    bne :+
        lda #COLOR_TRANSPARENT
        rts
    :
    cmp #'P'
    bne :+
        lda #COLOR_PURPLE
        rts
    :
    cmp #'B'
    bne :+
        lda #COLOR_L_BLUE
        rts
    :
    cmp #'C'
    bne :+
        lda #COLOR_CYAN
        rts
    :
    cmp #'G'
    bne :+
        lda #COLOR_GREEN
        rts
    :
    cmp #'Y'
    bne :+
        lda #COLOR_YELLOW
        rts
    :
    cmp #'O'
    bne :+
        lda #COLOR_ORANGE
        rts
    :
    cmp #'R'
    bne :+
        lda #COLOR_RED
        rts
    :
    cmp #'W'
    bne :+
        lda #COLOR_WHITE
        rts
    :
cc1:	
    tya
    rts


;------------------------------------------------------------------------------
; sprite attributes: 8 bytes per sprite, 128 sprites available
SpriteAttributes0:
    .byte $00FF & (SPRITE_IMAGE_DATA_0>>5) ; Address (12:5)
    .byte SPRITE_ATTR_MODE_8bpp | (SPRITE_IMAGE_DATA_0>>13) ; Mode - Address (16:13)
    .byte $50 ; X (7:0) - low byte of the X coordinate
    .byte $00 ; X (9:8) - bottom 2 bits in hi byte of the X
    .byte $50 ; Y (7:0) - low byte of the Y coordinate
    .byte $00 ; Y (9:8) - bottom 2 bits in hi byte of the Y
    .byte SPRITE_ATTR_Z_TOP_MOST ; Collision mask|Z-depth|V-flip|H-flip
    .byte SPRITE_ATTR_HEIGHT_32 | SPRITE_ATTR_WIDTH_16 | SPRITE_ATTR_PALETTE_0 ; Sprite height | Sprite width | Palette offset


;------------------------------------------------------------------------------
; this data is 16 pixels wide by 32 pixels tall
sprite:
.byte "....PPPPPPP....."
.byte "..PPPPPPPPPPP..."
.byte ".BBB.BBBBB.BBB.."
.byte ".BBBB.BBB.BBBB.."
.byte "CCCCCC.C.CCCCCC."
.byte "CCCCCC.C.CCCCCC."
.byte "GGGGGG.G.GGGGGG."
.byte ".GGGG.GGG.GGGG.."
.byte ".YYY.YYYYY.YYY.."
.byte ".YYYYYYYYYYYYY.."
.byte ".W.OOOOOOOOO.W.."
.byte "..W.OOOOOOO.W..."
.byte "..W..RRRRR..W..."
.byte "...W..RRR..W...."
.byte "...W..RRR..W...."
.byte "....W..R..W....."
.byte "....W..R..W....."
.byte ".....*****......"
.byte ".....*****......"
.byte ".....*****......"
.byte "......***......."
.byte "................"
.byte "................"
.byte "................"
.byte "................"
.byte "................"
.byte "................"
.byte "................"
.byte "................"
.byte "................"
.byte "................"
.byte "................"
