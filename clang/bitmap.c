// llvm x16 test
//
// vim: set et ts=4 sw=4

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>

// Commodore common definitions
#include <cbm.h>
// Commander X16 machine definitions
#include <cx16.h>

#include "bitmap.h"

// 320x200 8-bpp video mode
//
// 00000-F9FF 320x200 8-bpp bitmap

#define BITMAP_VADDR 0x00000UL // base VRAM address of bitmap
#define BITMAP_WIDTH 320       // 320 bytes/pixels wide (doubled to add up to 640)
#define BITMAP_HEIGHT 200      // 200 lines high (either doubled or tripled to add up to 480)

void vera_bitmap_320x200_8bpp()
{
    VERA.control = 0;
    VERA.display.video |= 0b01110000; // enable sprites and layer 0 & 1 (leave video mode untouched)
    VERA.display.hscale = 64;         // 2x pixel H zoom (320/640 * 128 [128 is 1.0])
    VERA.display.vscale = 53;         // 2x pixel V zoom (200/480 * 128 [128 is 1.0])

    // layer0 is left alone

    VERA.layer1.config = 0b00000111; // bitmap | 8-bpp
    VERA.layer1.mapbase = 0;         // not used for bitmap mode
    VERA.layer1.tilebase =
        ((BITMAP_VADDR >> 11) << 2) | 0; // bitmap address (shifted and aligned), tile-width = 0 for 320
    VERA.layer1.hscroll = 0;
    VERA.layer1.vscroll = 0;
}

int main(void)
{
    static bool done = false;
    static uint8_t c;
    static uint16_t h;
    static uint16_t v;

    vera_bitmap_320x200_8bpp();

    // set bitmap to colored lines

    c = 0; // starting color to fill
    while (!done)
    {
        // set DATA0 to point to start of bitmap, with auto-increment of 1
        VERA.control = 0;
        VERA.address_hi = VERA_INC_1 | (BITMAP_VADDR >> 16);
        VERA.address = BITMAP_VADDR & 0xffff;

        // loop over lines
        for (v = 0; v < BITMAP_HEIGHT; v++)
        {
            for (h = 0; h < BITMAP_WIDTH; h++)
            {
                VERA.data0 = c; // plot pixel (and auto-increment)
            }
            c++; // next color
            waitvsync();

            // kernal call to check for key press
            if (cbm_k_getin() != 0)
            {
                done = true;
                break;
            }
        }
    }

    __asm__ __volatile__ ("jsr  $FF81");
}
