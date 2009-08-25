/*
 * cart.c - Functions to access crt images
 *
 * (c) 2009 Thomas Giesel
 *
 * This software is provided 'as-is', without any express or implied
 * warranty.  In no event will the authors be held liable for any damages
 * arising from the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 *
 * Thomas Giesel skoe@directbox.com
 */

#include <stdint.h>
#include <conio.h>
#include <ctype.h>
#include <string.h>
#include <cbm.h>

#include "cart.h"
#include "screen.h"
#include "texts.h"

// global variables to make the code more compact on cc65
uint8_t      internalCartType;
CartHeader   cartHeader;
uint8_t      nChips;
uint32_t     nCartBytes;

// Names for internal CRT types, keep in sync with INTERNAL_CART_TYPE_*!
const char* aStrInternalCartTypeName[] =
{
    "",
    "Unknown",
    "Normal up to 8k",
    "Normal up to 16k",
    "MAX",
    "Ocean Type 1",
    "EasyFlash"
};


static const char strCartSignature[16] = CART_SIGNATURE;
static const char strChipSignature[4] = CHIP_SIGNATURE;


uint8_t readCartHeader(uint8_t lfn)
{
    int rv;
    uint8_t i;

    rv = cbm_read(lfn, &cartHeader, sizeof(cartHeader));
    if (rv != sizeof(cartHeader))
    {
        return 0;
    }

    if (memcmp(cartHeader.signature, strCartSignature,
               sizeof(strCartSignature)) != 0)
    {
        return 0;
    }

    // Evaluate the cartridge type
    switch (cartHeader.type[1])
    {
    case CART_TYPE_NORMAL:
        if (cartHeader.exromLine)
        {
            if (!cartHeader.gameLine)
                internalCartType = INTERNAL_CART_TYPE_ULTIMAX;
            else
                internalCartType = INTERNAL_CART_TYPE_UNKNOWN;
        }
        else
        {
            if (cartHeader.gameLine)
                internalCartType = INTERNAL_CART_TYPE_NORMAL_8K;
            else
                internalCartType = INTERNAL_CART_TYPE_NORMAL_16K;
        }
        break;

    case CART_TYPE_OCEAN1:
        internalCartType = INTERNAL_CART_TYPE_OCEAN1;
        break;

    case CART_TYPE_EASYFLASH:
    case CART_TYPE_EASYFLASH_TMP: // remove me!
        internalCartType = INTERNAL_CART_TYPE_EASYFLASH;
        break;

    default:
        internalCartType = INTERNAL_CART_TYPE_UNKNOWN;
    }

    return 1;
}

void eraseFlash()
{
}


/******************************************************************************/
/**
 * Read the next chip header and data.
 *
 * return   CART_RV_ERR     if wrong data has been read
 *          CART_RV_OKAY    if everything was oky
 *          CART_RV_EOF     if everything has been read already
 */
uint8_t __fastcall__ readNextBankHeader(BankHeader* pBankHeader, uint8_t lfn)
{
    if (cbm_read(lfn, pBankHeader, sizeof(BankHeader)) !=
        sizeof(BankHeader))
    {
        return CART_RV_EOF;
    }

    if (memcmp(pBankHeader->signature, strChipSignature,
               sizeof(strChipSignature)) != 0)
    {
        return CART_RV_ERR;
    }

    return CART_RV_OK;
}