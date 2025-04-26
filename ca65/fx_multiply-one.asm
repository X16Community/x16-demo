;
; R48 April 17, 2025
; 
; this was written using assembler ca65 (version V2.19 and above)
; 
; mkdir bin
; cl65 -t cx16 -o bin/MULTIPLY.PRG fx_multiply-one.asm 
; x16emu.exe -prg bin/MULTIPLY.PRG -run
;

.org $080D
.segment "STARTUP"
.segment "INIT"
.segment "ONCE"
.segment "CODE"

;------------------------------------------------------------------------------
; This ONE PAGER uses the VERA FX 16 bit multiplier in the VERA FX tutorial

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

fx_tile_base = verareg+10  ; when DCSEL=2
fx_map_base  = verareg+11 
fx_multiply  = verareg+12  ; when DCSEL=2

fx_cache_l = verareg+9  ; when DCSEL=6
fx_cache_m = verareg+10 
fx_cache_h = verareg+11 
fx_cache_u = verareg+12 

fx_accum_reset = verareg+9 ; readonly when DCSEL=6, reading resets accumulator

CTRL_ADDRSEL_0 = 0
CTRL_ADDRSEL_1 = 1     ; address select
CTRL_RESET     = 1<<7  ; reset 


VERA_STRIDE_1          = 1<<4  ; stride = 1: use this number of bytes to increment 
                               ; the current vera address when accessing the data port
VERA_STRIDE_4          = 3<<4

DCSEL_0  = %00000000
DCSEL_2  = %00000100
DCSEL_3  = %00000110
DCSEL_4  = %00001000
DCSEL_5  = %00001010
DCSEL_6  = %00001100

; FX_MULT
MULTIPLY_ENABLE = 1<<4

; FX_CTRL
CACHE_WRITE_ENABLE = 1<<6
TRANSPARENT_WRITES = 1<<7


;------------------------------------------------------------------------------
lda #(DCSEL_2 | CTRL_ADDRSEL_0)    ; DCSEL=2, ADDRSEL=0
sta veractl
stz verafx                         ; (mainly to reset Addr1 Mode to 0)

lda #MULTIPLY_ENABLE               ; when DSCEL == 2
sta fx_multiply

;------------------------------------------------------------------------------
lda #(DCSEL_6 | CTRL_ADDRSEL_0)    ; DCSEL=6, ADDRSEL=0
sta veractl

; set value #1, Multiplier
lda #<69
sta fx_cache_l
lda #>69
sta fx_cache_m

; set value #2, Multiplicand
lda #<420
sta fx_cache_h
lda #>420
sta fx_cache_u

;------------------------------------------------------------------------------
lda fx_accum_reset ; reset accumulator

;------------------------------------------------------------------------------
; perform the muliplication by writing to VRAM (when multiply is enabled)
lda #DCSEL_2
sta veractl

lda #CACHE_WRITE_ENABLE ; when DCSEL == 2
sta verafx

stz veralo
stz veramid
stz verahi    ; no increment

stz veradat0  ; multply and write out result

;------------------------------------------------------------------------------
lda #VERA_STRIDE_1
sta verahi          ; read out result

lda veradat0
sta $1400
lda veradat0
sta $1401
lda veradat0
sta $1402
lda veradat0
sta $1403

stz verafx
stz veractl

rts

