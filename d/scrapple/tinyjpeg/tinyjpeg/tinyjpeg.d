/*
 * Small jpeg decoder library
 *
 * Copyright (c) 2006, Luc Saillard <luc@saillard.org>
 * All rights reserved.
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * - Redistributions of source code must retain the above copyright notice,
 *  this list of conditions and the following disclaimer.
 *
 * - Redistributions in binary form must reproduce the above copyright notice,
 *  this list of conditions and the following disclaimer in the documentation
 *  and/or other materials provided with the distribution.
 *
 * - Neither the name of the author nor the names of its contributors may be
 *  used to endorse or promote products derived from this software without
 *  specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 *
 */

/*
 * Ported to the D programming language by
 * Tomas Lindquist Olsen <tomas@famolsen.dk>
 */

module tinyjpeg.tinyjpeg;

version(Tango) {
    import tango.stdc.stdint;
    import tango.stdc.stdlib;
    import tango.stdc.string;
    private char[] format(...)
    {
        return "formatted output is not yet supported with Tango";
    }
}
else {
    import std.c.stdlib;
    import std.c.string;
    import std.stdint;
    import std.string;
    debug(TinyJpegTrace) {
        import std.stdio;
    }
}

import tinyjpeg.jidctflt;
public import tinyjpeg.internal;

/* Flags that can be set by any applications */
enum { TINYJPEG_FLAGS_MJPEG_TABLE = (1<<1) }

/* Format accepted in outout */
enum /*tinyjpeg_fmt*/ {
   TINYJPEG_FMT_GREY = 1,
   TINYJPEG_FMT_BGR24,
   TINYJPEG_FMT_RGB24,
   TINYJPEG_FMT_YUV420P,
}

enum /*std_markers*/ {
   DQT  = 0xDB, /* Define Quantization Table */
   SOF  = 0xC0, /* Start of Frame (size information) */
   DHT  = 0xC4, /* Huffman Table */
   SOI  = 0xD8, /* Start of Image */
   SOS  = 0xDA, /* Start of Scan */
   RST  = 0xD0, /* Reset Marker d0 -> .. */
   RST7 = 0xD7, /* Reset Marker .. -> d7 */
   EOI  = 0xD9, /* End of Image */
   DRI  = 0xDD, /* Define Restart Interval */
   APP0 = 0xE0,
}

enum {
    cY  = 0,
    cCb = 1,
    cCr = 2
}

enum {
    BLACK_Y = 0,
    BLACK_U = 127,
    BLACK_V = 127
}

// thrown if some tinyjpeg error occured
private class TinyJpegException : Exception
{
    this(char[] msg)
    {
        super(msg);
    }
}

// debug trace function
debug(TinyJpegTrace) {
    version(Tango)
        private void trace(...) {}
    else
        private alias writef trace;
} else {
    private void trace(...) {}
}

private int error(jdec_private* priv, char[] err)
{
    priv.error_string = err;
    return -1;
}


/*private char *print_bits(uint value, char *bitstr)
{
  int i, j;
  i=31;
  while (i>0)
   {
     if (value & (1U<<i))
       break;
     i--;
   }
  j=0;
  while (i>=0)
   {
     bitstr[j++] = (value & (1U<<i))?'1':'0';
     i--;
   }
  bitstr[j] = 0;
  return bitstr;
}*/

private void print_next_16bytes(int offset, ubyte *stream)
{
  trace("%4.4x: %2.2x %2.2x %2.2x %2.2x %2.2x %2.2x %2.2x %2.2x %2.2x %2.2x %2.2x %2.2x %2.2x %2.2x %2.2x %2.2x\n",
    offset,
    stream[0], stream[1], stream[2], stream[3],
    stream[4], stream[5], stream[6], stream[7],
    stream[8], stream[9], stream[10], stream[11],
    stream[12], stream[13], stream[14], stream[15]);
}

private const ubyte zigzag[64] =
[
   0,  1,  5,  6, 14, 15, 27, 28,
   2,  4,  7, 13, 16, 26, 29, 42,
   3,  8, 12, 17, 25, 30, 41, 43,
   9, 11, 18, 24, 31, 40, 44, 53,
  10, 19, 23, 32, 39, 45, 52, 54,
  20, 22, 33, 38, 46, 51, 55, 60,
  21, 34, 37, 47, 50, 56, 59, 61,
  35, 36, 48, 49, 57, 58, 62, 63
];

/* Set up the standard Huffman tables (cf. JPEG standard section K.3) */
/* IMPORTANT: these are only valid for 8-bit data precision! */
private const ubyte bits_dc_luminance[17] =
[
  0, 0, 1, 5, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0
];
private const ubyte val_dc_luminance[] =
[
  0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
];

private const ubyte bits_dc_chrominance[17] =
[
  0, 0, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0
];
private const ubyte val_dc_chrominance[] =
[
  0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
];

private const ubyte bits_ac_luminance[17] =
[
  0, 0, 2, 1, 3, 3, 2, 4, 3, 5, 5, 4, 4, 0, 0, 1, 0x7d
];
private const ubyte val_ac_luminance[] =
[
  0x01, 0x02, 0x03, 0x00, 0x04, 0x11, 0x05, 0x12,
  0x21, 0x31, 0x41, 0x06, 0x13, 0x51, 0x61, 0x07,
  0x22, 0x71, 0x14, 0x32, 0x81, 0x91, 0xa1, 0x08,
  0x23, 0x42, 0xb1, 0xc1, 0x15, 0x52, 0xd1, 0xf0,
  0x24, 0x33, 0x62, 0x72, 0x82, 0x09, 0x0a, 0x16,
  0x17, 0x18, 0x19, 0x1a, 0x25, 0x26, 0x27, 0x28,
  0x29, 0x2a, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39,
  0x3a, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49,
  0x4a, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59,
  0x5a, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69,
  0x6a, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79,
  0x7a, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89,
  0x8a, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98,
  0x99, 0x9a, 0xa2, 0xa3, 0xa4, 0xa5, 0xa6, 0xa7,
  0xa8, 0xa9, 0xaa, 0xb2, 0xb3, 0xb4, 0xb5, 0xb6,
  0xb7, 0xb8, 0xb9, 0xba, 0xc2, 0xc3, 0xc4, 0xc5,
  0xc6, 0xc7, 0xc8, 0xc9, 0xca, 0xd2, 0xd3, 0xd4,
  0xd5, 0xd6, 0xd7, 0xd8, 0xd9, 0xda, 0xe1, 0xe2,
  0xe3, 0xe4, 0xe5, 0xe6, 0xe7, 0xe8, 0xe9, 0xea,
  0xf1, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8,
  0xf9, 0xfa
];

private const ubyte bits_ac_chrominance[17] =
[
  0, 0, 2, 1, 2, 4, 4, 3, 4, 7, 5, 4, 4, 0, 1, 2, 0x77
];

private const ubyte val_ac_chrominance[] =
[
  0x00, 0x01, 0x02, 0x03, 0x11, 0x04, 0x05, 0x21,
  0x31, 0x06, 0x12, 0x41, 0x51, 0x07, 0x61, 0x71,
  0x13, 0x22, 0x32, 0x81, 0x08, 0x14, 0x42, 0x91,
  0xa1, 0xb1, 0xc1, 0x09, 0x23, 0x33, 0x52, 0xf0,
  0x15, 0x62, 0x72, 0xd1, 0x0a, 0x16, 0x24, 0x34,
  0xe1, 0x25, 0xf1, 0x17, 0x18, 0x19, 0x1a, 0x26,
  0x27, 0x28, 0x29, 0x2a, 0x35, 0x36, 0x37, 0x38,
  0x39, 0x3a, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48,
  0x49, 0x4a, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58,
  0x59, 0x5a, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68,
  0x69, 0x6a, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78,
  0x79, 0x7a, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87,
  0x88, 0x89, 0x8a, 0x92, 0x93, 0x94, 0x95, 0x96,
  0x97, 0x98, 0x99, 0x9a, 0xa2, 0xa3, 0xa4, 0xa5,
  0xa6, 0xa7, 0xa8, 0xa9, 0xaa, 0xb2, 0xb3, 0xb4,
  0xb5, 0xb6, 0xb7, 0xb8, 0xb9, 0xba, 0xc2, 0xc3,
  0xc4, 0xc5, 0xc6, 0xc7, 0xc8, 0xc9, 0xca, 0xd2,
  0xd3, 0xd4, 0xd5, 0xd6, 0xd7, 0xd8, 0xd9, 0xda,
  0xe2, 0xe3, 0xe4, 0xe5, 0xe6, 0xe7, 0xe8, 0xe9,
  0xea, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8,
  0xf9, 0xfa
];


/*
 * 4 functions to manage the stream
 *
 *  fill_nbits: put at least nbits in the reservoir of bits.
 *              But convert any 0xff,0x00 into 0xff
 *  get_nbits: read nbits from the stream, and put it in result,
 *             bits is removed from the stream and the reservoir is filled
 *             automaticaly. The result is signed according to the number of
 *             bits.
 *  look_nbits: read nbits from the stream without marking as read.
 *  skip_nbits: read nbits from the stream but do not return the result.
 *
 * stream: current pointer in the jpeg data (read bytes per bytes)
 * nbits_in_reservoir: number of bits filled into the reservoir
 * reservoir: register that contains bits information. Only nbits_in_reservoir
 *            is valid.
 *                          nbits_in_reservoir
 *                        <--    17 bits    -.
 *            Ex: 0000 0000 1010 0000 1111 0000   <== reservoir
 *                        ^
 *                        bit 1
 *            To get two bits from this example
 *                 result = (reservoir >> 15) & 3
 *
 */
template fill_nbits(char[] reservoir, char[] nbits_in_reservoir, char[] stream, char[] nbits_wanted)
{
    const fill_nbits =
    "while ("~nbits_in_reservoir~"<"~nbits_wanted~"){"~
    "ubyte c;"~
    "if ("~stream~" >= priv.stream_end)"~
    "  throw new TinyJpegException(`longjmp(priv.jump_state, -EIO)`);"~
    "c = *"~stream~"++;"~
    reservoir~" <<= 8;"~
    "if (c == 0xff && *"~stream~" == 0x00)"~
      stream~"++;"~
    reservoir~" |= c;"~
    nbits_in_reservoir~"+=8;"~
    "}";
}
/*#define fill_nbits(reservoir,nbits_in_reservoir,stream,nbits_wanted) do { \
   while (nbits_in_reservoir<nbits_wanted) \
    { \
      ubyte c; \
      if (stream >= priv.stream_end) \
        longjmp(priv.jump_state, -EIO); \
      c = *stream++; \
      reservoir <<= 8; \
      if (c == 0xff && *stream == 0x00) \
        stream++; \
      reservoir |= c; \
      nbits_in_reservoir+=8; \
    } \
}  while(0);*/

/* Signed version !!!! */
template get_nbits(char[] reservoir, char[] nbits_in_reservoir, char[] stream, char[] nbits_wanted, char[] result)
{
    const get_nbits = "{"~
    "mixin(fill_nbits!(`"~reservoir~"`,`"~nbits_in_reservoir~"`,`"~stream~"`,`("~nbits_wanted~")`));"~
    result~" = (("~reservoir~")>>>("~nbits_in_reservoir~"-("~nbits_wanted~")));"~
    nbits_in_reservoir~" -= ("~nbits_wanted~");"~
    reservoir~" &= ((1U<<"~nbits_in_reservoir~")-1);"~
    "if (cast(uint)"~result~" < (1U<<(("~nbits_wanted~")-1)))"~
      result~" += (0xFFFFFFFFU<<("~nbits_wanted~"))+1;"~
    "}";
}
/*#define get_nbits(reservoir,nbits_in_reservoir,stream,nbits_wanted,result) do { \
   fill_nbits(reservoir,nbits_in_reservoir,stream,(nbits_wanted)); \
   result = ((reservoir)>>(nbits_in_reservoir-(nbits_wanted))); \
   nbits_in_reservoir -= (nbits_wanted);  \
   reservoir &= ((1U<<nbits_in_reservoir)-1); \
   if ((uint)result < (1UL<<((nbits_wanted)-1))) \
       result += (0xFFFFFFFFUL<<(nbits_wanted))+1; \
}  while(0);*/

template look_nbits(char[] reservoir, char[] nbits_in_reservoir, char[] stream, char[] nbits_wanted, char[] result)
{
    const look_nbits = "{"~
    "mixin(fill_nbits!(`"~reservoir~"`,`"~nbits_in_reservoir~"`,`"~stream~"`,`("~nbits_wanted~")`));"~
    result~" = (("~reservoir~")>>>("~nbits_in_reservoir~"-("~nbits_wanted~")));"~
    "}";
}
/*#define look_nbits(reservoir,nbits_in_reservoir,stream,nbits_wanted,result) do { \
   fill_nbits(reservoir,nbits_in_reservoir,stream,(nbits_wanted)); \
   result = ((reservoir)>>(nbits_in_reservoir-(nbits_wanted))); \
}  while(0);*/

/* To speed up the decoding, we assume that the reservoir have enough bit
 * slow version:
 * #define skip_nbits(reservoir,nbits_in_reservoir,stream,nbits_wanted) do { \
 *   fill_nbits(reservoir,nbits_in_reservoir,stream,(nbits_wanted)); \
 *   nbits_in_reservoir -= (nbits_wanted); \
 *   reservoir &= ((1U<<nbits_in_reservoir)-1); \
 * }  while(0);
 */
template skip_nbits(char[] reservoir, char[] nbits_in_reservoir, char[] stream, char[] nbits_wanted)
{
    const skip_nbits = "{"~
    nbits_in_reservoir~" -= ("~nbits_wanted~");"~
    reservoir~" &= ((1U<<"~nbits_in_reservoir~")-1);"~
    "}";
}
/*#define skip_nbits(reservoir,nbits_in_reservoir,stream,nbits_wanted) do { \
   nbits_in_reservoir -= (nbits_wanted); \
   reservoir &= ((1U<<nbits_in_reservoir)-1); \
}  while(0);*/


template be16_to_cpu(char[] x)
{
    version(LittleEndian)
        const be16_to_cpu = "((("~x~")[0]<<8)|("~x~")[1])";
    else
        const be16_to_cpu = "*cast(short*)"~x~".ptr";
}
//#define be16_to_cpu(x) (((x)[0]<<8)|(x)[1])

/**
 * Get the next (valid) huffman code in the stream.
 *
 * To speedup the procedure, we look HUFFMAN_HASH_NBITS bits and the code is
 * lower than HUFFMAN_HASH_NBITS we have automaticaly the length of the code
 * and the value by using two lookup table.
 * Else if the value is not found, just search (linear) into an array for each
 * bits is the code is present.
 *
 * If the code is not present for any reason, -1 is return.
 */
private int get_next_huffman_code(jdec_private *priv, huffman_table *huffman_tab)
{
  int value, hcode;
  uint extra_nbits, nbits;
  uint16_t *slowtable;

  mixin(look_nbits!("priv.reservoir", "priv.nbits_in_reservoir", "priv.stream", "HUFFMAN_HASH_NBITS", "hcode"));
  value = huffman_tab.lookup[hcode];
  if (value >= 0)
  {
     uint code_size = huffman_tab.code_size[value];
     mixin(skip_nbits!("priv.reservoir", "priv.nbits_in_reservoir", "priv.stream", "code_size"));
     return value;
  }

  /* Decode more bits each time ... */
  for (extra_nbits=0; extra_nbits<16-HUFFMAN_HASH_NBITS; extra_nbits++)
   {
     nbits = HUFFMAN_HASH_NBITS + 1 + extra_nbits;

     mixin(look_nbits!("priv.reservoir", "priv.nbits_in_reservoir", "priv.stream", "nbits", "hcode"));
     slowtable = huffman_tab.slowtable[extra_nbits].ptr;
     /* Search if the code is in this array */
     while (slowtable[0]) {
    if (slowtable[0] == hcode) {
       mixin(skip_nbits!("priv.reservoir", "priv.nbits_in_reservoir", "priv.stream", "nbits"));
       return slowtable[1];
    }
    slowtable+=2;
     }
   }
  return 0;
}




/**
 *
 * Decode a single block that contains the DCT coefficients.
 * The table coefficients is already dezigzaged at the end of the operation.
 *
 */
private void process_Huffman_data_unit(jdec_private *priv, int comp)
{
  ubyte j;
  uint huff_code;
  ubyte size_val, count_0;

  component *co = &priv.component_infos[comp];
  short DCT[64];

  /* Initialize the DCT coef table */
  memset(DCT.ptr, 0, DCT.sizeof);
  static assert (DCT.sizeof == 128);

  /* DC coefficient decoding */
  huff_code = get_next_huffman_code(priv, co.DC_table);
  //trace("+ %x\n", huff_code);
  if (huff_code) {
     mixin(get_nbits!("priv.reservoir", "priv.nbits_in_reservoir", "priv.stream", "huff_code", "DCT[0]"));
     DCT[0] += co.previous_DC;
     co.previous_DC = DCT[0];
  } else {
     DCT[0] = co.previous_DC;
  }


  /* AC coefficient decoding */
  j = 1;
  while (j<64)
   {
     huff_code = get_next_huffman_code(priv, co.AC_table);
     //trace("- %x\n", huff_code);

     size_val = huff_code & 0xF;
     count_0 = huff_code >>> 4;

     if (size_val == 0)
      { /* RLE */
    if (count_0 == 0)
      break;    /* EOB found, go out */
    else if (count_0 == 0xF)
      j += 16;  /* skip 16 zeros */
      }
     else
      {
    j += count_0;   /* skip count_0 zeroes */
    if (j >= 64)
    {
      error(priv,"Bad huffman data (buffer overflow)");
      break;
    }
    mixin(get_nbits!("priv.reservoir", "priv.nbits_in_reservoir", "priv.stream", "size_val", "DCT[j]"));
    j++;
      }
   }

  for (j = 0; j < 64; j++)
    co.DCT[j] = DCT[zigzag[j]];
}

/*
 * Takes two array of bits, and build the huffman table for size, and code
 *
 * lookup will return the symbol if the code is less or equal than HUFFMAN_HASH_NBITS.
 * code_size will be used to known how many bits this symbol is encoded.
 * slowtable will be used when the first lookup didn't give the result.
 */
private void build_huffman_table(ubyte *bits, ubyte *vals, huffman_table *table)
{
  uint i, j, code, code_size, val, nbits;
  ubyte huffsize[HUFFMAN_BITS_SIZE+1];
  ubyte *hz;
  uint huffcode[HUFFMAN_BITS_SIZE+1];
  uint *hc;
  int next_free_entry;

  /*
   * Build a temp array
   *   huffsize[X] => numbers of bits to write vals[X]
   */
  hz = huffsize.ptr;
  for (i=1; i<=16; i++)
   {
     for (j=1; j<=bits[i]; j++)
       *hz++ = i;
   }
  *hz = 0;

  memset(table.lookup.ptr, 0xff, table.lookup.sizeof);
  for (i=0; i<(16-HUFFMAN_HASH_NBITS); i++)
    table.slowtable[i][0] = 0;

  /* Build a temp array
   *   huffcode[X] => code used to write vals[X]
   */
  code = 0;
  hc = huffcode.ptr;
  hz = huffsize.ptr;
  nbits = *hz;
  while (*hz)
   {
     while (*hz == nbits)
      {
        *hc++ = code++;
        hz++;
      }
     code <<= 1;
     nbits++;
   }

  /*
   * Build the lookup table, and the slowtable if needed.
   */
  next_free_entry = -1;
  for (i=0; huffsize[i]; i++)
   {
     val = vals[i];
     code = huffcode[i];
     code_size = huffsize[i];

     trace("val=%2.2x code=%8.8x codesize=%2.2d\n", val, code, code_size);

     table.code_size[val] = code_size;
     if (code_size <= HUFFMAN_HASH_NBITS)
      {
    /*
     * Good: val can be put in the lookup table, so fill all value of this
     * column with value val
     */
    int repeat = 1U<<(HUFFMAN_HASH_NBITS - code_size);
    code <<= HUFFMAN_HASH_NBITS - code_size;
    while ( repeat-- )
      table.lookup[code++] = val;

      }
     else
      {
    /* Perhaps sorting the array will be an optimization */
    uint16_t *slowtable = table.slowtable[code_size-HUFFMAN_HASH_NBITS-1].ptr;
    while(slowtable[0])
      slowtable+=2;
    slowtable[0] = code;
    slowtable[1] = val;
    slowtable[2] = 0;
    /* TODO: NEED TO CHECK FOR AN OVERFLOW OF THE TABLE */
      }

   }

}

private void build_default_huffman_tables(jdec_private *priv)
{
  if (   (priv.flags & TINYJPEG_FLAGS_MJPEG_TABLE)
      && priv.default_huffman_table_initialized)
    return;

  build_huffman_table(bits_dc_luminance.ptr, val_dc_luminance.ptr, &priv.HTDC[0]);
  build_huffman_table(bits_ac_luminance.ptr, val_ac_luminance.ptr, &priv.HTAC[0]);

  build_huffman_table(bits_dc_chrominance.ptr, val_dc_chrominance.ptr, &priv.HTDC[1]);
  build_huffman_table(bits_ac_chrominance.ptr, val_ac_chrominance.ptr, &priv.HTAC[1]);

  priv.default_huffman_table_initialized = 1;
}



/*******************************************************************************
 *
 * Colorspace conversion routine
 *
 *
 * Note:
 * YCbCr is defined per CCIR 601-1, except that Cb and Cr are
 * normalized to the range 0..MAXJSAMPLE rather than -0.5 .. 0.5.
 * The conversion equations to be implemented are therefore
 *      R = Y                + 1.40200 * Cr
 *      G = Y - 0.34414 * Cb - 0.71414 * Cr
 *      B = Y + 1.77200 * Cb
 *
 ******************************************************************************/

private ubyte clamp(int i)
{
  if (i<0)
    return 0;
  else if (i>255)
    return 255;
  else
    return i;
}


/**
 *  YCrCb . YUV420P (1x1)
 *  .---.
 *  | 1 |
 *  `---'
 */
private void YCrCB_to_YUV420P_1x1(jdec_private *priv)
{
  ubyte* s, y;
  ubyte *p;
  int i,j;

  p = priv.plane[0];
  y = priv.Y.ptr;
  for (i=0; i<8; i++)
   {
     memcpy(p, y, 8);
     p+=priv.width;
     y+=8;
   }

  p = priv.plane[1];
  s = priv.Cb.ptr;
  for (i=0; i<8; i+=2)
   {
     for (j=0; j<8; j+=2, s+=2)
       *p++ = *s;
     s += 8; /* Skip one line */
     p += priv.width/2 - 4;
   }

  p = priv.plane[2];
  s = priv.Cr.ptr;
  for (i=0; i<8; i+=2)
   {
     for (j=0; j<8; j+=2, s+=2)
       *p++ = *s;
     s += 8; /* Skip one line */
     p += priv.width/2 - 4;
   }
}

/**
 *  YCrCb . YUV420P (2x1)
 *  .-------.
 *  | 1 | 2 |
 *  `-------'
 */
private void YCrCB_to_YUV420P_2x1(jdec_private *priv)
{
  ubyte *p;
  ubyte* s, y1;
  uint i;

  p = priv.plane[0];
  y1 = priv.Y.ptr;
  for (i=0; i<8; i++)
   {
     memcpy(p, y1, 16);
     p += priv.width;
     y1 += 16;
   }

  p = priv.plane[1];
  s = priv.Cb.ptr;
  for (i=0; i<8; i+=2)
   {
     memcpy(p, s, 8);
     s += 16; /* Skip one line */
     p += priv.width/2;
   }

  p = priv.plane[2];
  s = priv.Cr.ptr;
  for (i=0; i<8; i+=2)
   {
     memcpy(p, s, 8);
     s += 16; /* Skip one line */
     p += priv.width/2;
   }
}


/**
 *  YCrCb . YUV420P (1x2)
 *  .---.
 *  | 1 |
 *  |---|
 *  | 2 |
 *  `---'
 */
private void YCrCB_to_YUV420P_1x2(jdec_private *priv)
{
  ubyte* s, y;
  ubyte *p;
  int i,j;

  p = priv.plane[0];
  y = priv.Y.ptr;
  for (i=0; i<16; i++)
   {
     memcpy(p, y, 8);
     p+=priv.width;
     y+=8;
   }

  p = priv.plane[1];
  s = priv.Cb.ptr;
  for (i=0; i<8; i++)
   {
     for (j=0; j<8; j+=2, s+=2)
       *p++ = *s;
     p += priv.width/2 - 4;
   }

  p = priv.plane[2];
  s = priv.Cr.ptr;
  for (i=0; i<8; i++)
   {
     for (j=0; j<8; j+=2, s+=2)
       *p++ = *s;
     p += priv.width/2 - 4;
   }
}

/**
 *  YCrCb . YUV420P (2x2)
 *  .-------.
 *  | 1 | 2 |
 *  |---+---|
 *  | 3 | 4 |
 *  `-------'
 */
private void YCrCB_to_YUV420P_2x2(jdec_private *priv)
{
  ubyte *p;
  ubyte* s, y1;
  uint i;

  p = priv.plane[0];
  y1 = priv.Y.ptr;
  for (i=0; i<16; i++)
   {
     memcpy(p, y1, 16);
     p += priv.width;
     y1 += 16;
   }

  p = priv.plane[1];
  s = priv.Cb.ptr;
  for (i=0; i<8; i++)
   {
     memcpy(p, s, 8);
     s += 8;
     p += priv.width/2;
   }

  p = priv.plane[2];
  s = priv.Cr.ptr;
  for (i=0; i<8; i++)
   {
     memcpy(p, s, 8);
     s += 8;
     p += priv.width/2;
   }
}

/**
 *  YCrCb . RGB24 (1x1)
 *  .---.
 *  | 1 |
 *  `---'
 */
private void YCrCB_to_RGB24_1x1(jdec_private *priv)
{
  ubyte* Y, Cb, Cr;
  ubyte *p;
  int i,j;
  int offset_to_next_row;

  enum {
    SCALEBITS = 10,
    ONE_HALF = (1U << (SCALEBITS-1))
  }
  static int FIX(float x) {
    return cast(int)(x * (1U<<SCALEBITS) + 0.5);
  }

  p = priv.plane[0];
  Y = priv.Y.ptr;
  Cb = priv.Cb.ptr;
  Cr = priv.Cr.ptr;
  offset_to_next_row = priv.width*3 - 8*3;
  for (i=0; i<8; i++) {

    for (j=0; j<8; j++) {

       int y, cb, cr;
       int add_r, add_g, add_b;
       int r, g , b;

       y  = (*Y++) << SCALEBITS;
       cb = *Cb++ - 128;
       cr = *Cr++ - 128;
       add_r = FIX(1.40200) * cr + ONE_HALF;
       add_g = - FIX(0.34414) * cb - FIX(0.71414) * cr + ONE_HALF;
       add_b = FIX(1.77200) * cb + ONE_HALF;

       r = (y + add_r) >> SCALEBITS;
       *p++ = clamp(r);
       g = (y + add_g) >> SCALEBITS;
       *p++ = clamp(g);
       b = (y + add_b) >> SCALEBITS;
       *p++ = clamp(b);

    }

    p += offset_to_next_row;
  }

}

/**
 *  YCrCb . BGR24 (1x1)
 *  .---.
 *  | 1 |
 *  `---'
 */
private void YCrCB_to_BGR24_1x1(jdec_private *priv)
{
  ubyte* Y, Cb, Cr;
  ubyte *p;
  int i,j;
  int offset_to_next_row;

  enum {
    SCALEBITS = 10,
    ONE_HALF = (1U << (SCALEBITS-1))
  }
  static int FIX(float x) {
    return cast(int)(x * (1U<<SCALEBITS) + 0.5);
  }

  p = priv.plane[0];
  Y = priv.Y.ptr;
  Cb = priv.Cb.ptr;
  Cr = priv.Cr.ptr;
  offset_to_next_row = priv.width*3 - 8*3;
  for (i=0; i<8; i++) {

    for (j=0; j<8; j++) {

       int y, cb, cr;
       int add_r, add_g, add_b;
       int r, g , b;

       y  = (*Y++) << SCALEBITS;
       cb = *Cb++ - 128;
       cr = *Cr++ - 128;
       add_r = FIX(1.40200) * cr + ONE_HALF;
       add_g = - FIX(0.34414) * cb - FIX(0.71414) * cr + ONE_HALF;
       add_b = FIX(1.77200) * cb + ONE_HALF;

       b = (y + add_b) >> SCALEBITS;
       *p++ = clamp(b);
       g = (y + add_g) >> SCALEBITS;
       *p++ = clamp(g);
       r = (y + add_r) >> SCALEBITS;
       *p++ = clamp(r);

    }

    p += offset_to_next_row;
  }

}


/**
 *  YCrCb . RGB24 (2x1)
 *  .-------.
 *  | 1 | 2 |
 *  `-------'
 */
private void YCrCB_to_RGB24_2x1(jdec_private *priv)
{
  ubyte* Y, Cb, Cr;
  ubyte *p;
  int i,j;
  int offset_to_next_row;

  enum {
    SCALEBITS = 10,
    ONE_HALF = (1U << (SCALEBITS-1))
  }
  static int FIX(float x) {
    return cast(int)(x * (1U<<SCALEBITS) + 0.5);
  }

  p = priv.plane[0];
  Y = priv.Y.ptr;
  Cb = priv.Cb.ptr;
  Cr = priv.Cr.ptr;
  offset_to_next_row = priv.width*3 - 16*3;
  for (i=0; i<8; i++) {

    for (j=0; j<8; j++) {

       int y, cb, cr;
       int add_r, add_g, add_b;
       int r, g , b;

       y  = (*Y++) << SCALEBITS;
       cb = *Cb++ - 128;
       cr = *Cr++ - 128;
       add_r = FIX(1.40200) * cr + ONE_HALF;
       add_g = - FIX(0.34414) * cb - FIX(0.71414) * cr + ONE_HALF;
       add_b = FIX(1.77200) * cb + ONE_HALF;

       r = (y + add_r) >> SCALEBITS;
       *p++ = clamp(r);
       g = (y + add_g) >> SCALEBITS;
       *p++ = clamp(g);
       b = (y + add_b) >> SCALEBITS;
       *p++ = clamp(b);

       y  = (*Y++) << SCALEBITS;
       r = (y + add_r) >> SCALEBITS;
       *p++ = clamp(r);
       g = (y + add_g) >> SCALEBITS;
       *p++ = clamp(g);
       b = (y + add_b) >> SCALEBITS;
       *p++ = clamp(b);

    }

    p += offset_to_next_row;
  }

}

/*
 *  YCrCb . BGR24 (2x1)
 *  .-------.
 *  | 1 | 2 |
 *  `-------'
 */
private void YCrCB_to_BGR24_2x1(jdec_private *priv)
{
  ubyte* Y, Cb, Cr;
  ubyte *p;
  int i,j;
  int offset_to_next_row;

  enum {
    SCALEBITS = 10,
    ONE_HALF = (1U << (SCALEBITS-1))
  }
  static int FIX(float x) {
    return cast(int)(x * (1U<<SCALEBITS) + 0.5);
  }

  p = priv.plane[0];
  Y = priv.Y.ptr;
  Cb = priv.Cb.ptr;
  Cr = priv.Cr.ptr;
  offset_to_next_row = priv.width*3 - 16*3;
  for (i=0; i<8; i++) {

    for (j=0; j<8; j++) {

       int y, cb, cr;
       int add_r, add_g, add_b;
       int r, g , b;

       cb = *Cb++ - 128;
       cr = *Cr++ - 128;
       add_r = FIX(1.40200) * cr + ONE_HALF;
       add_g = - FIX(0.34414) * cb - FIX(0.71414) * cr + ONE_HALF;
       add_b = FIX(1.77200) * cb + ONE_HALF;

       y  = (*Y++) << SCALEBITS;
       b = (y + add_b) >> SCALEBITS;
       *p++ = clamp(b);
       g = (y + add_g) >> SCALEBITS;
       *p++ = clamp(g);
       r = (y + add_r) >> SCALEBITS;
       *p++ = clamp(r);

       y  = (*Y++) << SCALEBITS;
       b = (y + add_b) >> SCALEBITS;
       *p++ = clamp(b);
       g = (y + add_g) >> SCALEBITS;
       *p++ = clamp(g);
       r = (y + add_r) >> SCALEBITS;
       *p++ = clamp(r);

    }

    p += offset_to_next_row;
  }

}

/**
 *  YCrCb . RGB24 (1x2)
 *  .---.
 *  | 1 |
 *  |---|
 *  | 2 |
 *  `---'
 */
private void YCrCB_to_RGB24_1x2(jdec_private *priv)
{
  ubyte* Y, Cb, Cr;
  ubyte*p, p2;
  int i,j;
  int offset_to_next_row;

  enum {
    SCALEBITS = 10,
    ONE_HALF = (1U << (SCALEBITS-1))
  }
  static int FIX(float x) {
    return cast(int)(x * (1U<<SCALEBITS) + 0.5);
  }

  p = priv.plane[0];
  p2 = priv.plane[0] + priv.width*3;
  Y = priv.Y.ptr;
  Cb = priv.Cb.ptr;
  Cr = priv.Cr.ptr;
  offset_to_next_row = 2*priv.width*3 - 8*3;
  for (i=0; i<8; i++) {

    for (j=0; j<8; j++) {

       int y, cb, cr;
       int add_r, add_g, add_b;
       int r, g , b;

       cb = *Cb++ - 128;
       cr = *Cr++ - 128;
       add_r = FIX(1.40200) * cr + ONE_HALF;
       add_g = - FIX(0.34414) * cb - FIX(0.71414) * cr + ONE_HALF;
       add_b = FIX(1.77200) * cb + ONE_HALF;

       y  = (*Y++) << SCALEBITS;
       r = (y + add_r) >> SCALEBITS;
       *p++ = clamp(r);
       g = (y + add_g) >> SCALEBITS;
       *p++ = clamp(g);
       b = (y + add_b) >> SCALEBITS;
       *p++ = clamp(b);

       y  = (Y[8-1]) << SCALEBITS;
       r = (y + add_r) >> SCALEBITS;
       *p2++ = clamp(r);
       g = (y + add_g) >> SCALEBITS;
       *p2++ = clamp(g);
       b = (y + add_b) >> SCALEBITS;
       *p2++ = clamp(b);

    }
    Y += 8;
    p += offset_to_next_row;
    p2 += offset_to_next_row;
  }

}

/*
 *  YCrCb . BGR24 (1x2)
 *  .---.
 *  | 1 |
 *  |---|
 *  | 2 |
 *  `---'
 */
private void YCrCB_to_BGR24_1x2(jdec_private *priv)
{
  ubyte* Y, Cb, Cr;
  ubyte* p, p2;
  int i,j;
  int offset_to_next_row;

  enum {
    SCALEBITS = 10,
    ONE_HALF = (1U << (SCALEBITS-1))
  }
  static int FIX(float x) {
    return cast(int)(x * (1U<<SCALEBITS) + 0.5);
  }

  p = priv.plane[0];
  p2 = priv.plane[0] + priv.width*3;
  Y = priv.Y.ptr;
  Cb = priv.Cb.ptr;
  Cr = priv.Cr.ptr;
  offset_to_next_row = 2*priv.width*3 - 8*3;
  for (i=0; i<8; i++) {

    for (j=0; j<8; j++) {

       int y, cb, cr;
       int add_r, add_g, add_b;
       int r, g , b;

       cb = *Cb++ - 128;
       cr = *Cr++ - 128;
       add_r = FIX(1.40200) * cr + ONE_HALF;
       add_g = - FIX(0.34414) * cb - FIX(0.71414) * cr + ONE_HALF;
       add_b = FIX(1.77200) * cb + ONE_HALF;

       y  = (*Y++) << SCALEBITS;
       b = (y + add_b) >> SCALEBITS;
       *p++ = clamp(b);
       g = (y + add_g) >> SCALEBITS;
       *p++ = clamp(g);
       r = (y + add_r) >> SCALEBITS;
       *p++ = clamp(r);

       y  = (Y[8-1]) << SCALEBITS;
       b = (y + add_b) >> SCALEBITS;
       *p2++ = clamp(b);
       g = (y + add_g) >> SCALEBITS;
       *p2++ = clamp(g);
       r = (y + add_r) >> SCALEBITS;
       *p2++ = clamp(r);

    }
    Y += 8;
    p += offset_to_next_row;
    p2 += offset_to_next_row;
  }

}


/**
 *  YCrCb . RGB24 (2x2)
 *  .-------.
 *  | 1 | 2 |
 *  |---+---|
 *  | 3 | 4 |
 *  `-------'
 */
private void YCrCB_to_RGB24_2x2(jdec_private *priv)
{
  ubyte* Y, Cb, Cr;
  ubyte* p, p2;
  int i,j;
  int offset_to_next_row;

  enum {
    SCALEBITS = 10,
    ONE_HALF = (1U << (SCALEBITS-1))
  }
  static int FIX(float x) {
    return cast(int)(x * (1U<<SCALEBITS) + 0.5);
  }

  p = priv.plane[0];
  p2 = priv.plane[0] + priv.width*3;
  Y = priv.Y.ptr;
  Cb = priv.Cb.ptr;
  Cr = priv.Cr.ptr;
  offset_to_next_row = (priv.width*3*2) - 16*3;
  for (i=0; i<8; i++) {

    for (j=0; j<8; j++) {

       int y, cb, cr;
       int add_r, add_g, add_b;
       int r, g , b;

       cb = *Cb++ - 128;
       cr = *Cr++ - 128;
       add_r = FIX(1.40200) * cr + ONE_HALF;
       add_g = - FIX(0.34414) * cb - FIX(0.71414) * cr + ONE_HALF;
       add_b = FIX(1.77200) * cb + ONE_HALF;

       y  = (*Y++) << SCALEBITS;
       r = (y + add_r) >> SCALEBITS;
       *p++ = clamp(r);
       g = (y + add_g) >> SCALEBITS;
       *p++ = clamp(g);
       b = (y + add_b) >> SCALEBITS;
       *p++ = clamp(b);

       y  = (*Y++) << SCALEBITS;
       r = (y + add_r) >> SCALEBITS;
       *p++ = clamp(r);
       g = (y + add_g) >> SCALEBITS;
       *p++ = clamp(g);
       b = (y + add_b) >> SCALEBITS;
       *p++ = clamp(b);

       y  = (Y[16-2]) << SCALEBITS;
       r = (y + add_r) >> SCALEBITS;
       *p2++ = clamp(r);
       g = (y + add_g) >> SCALEBITS;
       *p2++ = clamp(g);
       b = (y + add_b) >> SCALEBITS;
       *p2++ = clamp(b);

       y  = (Y[16-1]) << SCALEBITS;
       r = (y + add_r) >> SCALEBITS;
       *p2++ = clamp(r);
       g = (y + add_g) >> SCALEBITS;
       *p2++ = clamp(g);
       b = (y + add_b) >> SCALEBITS;
       *p2++ = clamp(b);
    }
    Y  += 16;
    p  += offset_to_next_row;
    p2 += offset_to_next_row;
  }

}


/*
 *  YCrCb . BGR24 (2x2)
 *  .-------.
 *  | 1 | 2 |
 *  |---+---|
 *  | 3 | 4 |
 *  `-------'
 */
private void YCrCB_to_BGR24_2x2(jdec_private *priv)
{
  ubyte* Y, Cb, Cr;
  ubyte* p, p2;
  int i,j;
  int offset_to_next_row;

  enum {
    SCALEBITS = 10,
    ONE_HALF = (1U << (SCALEBITS-1))
  }
  static int FIX(float x) {
    return cast(int)(x * (1U<<SCALEBITS) + 0.5);
  }

  p = priv.plane[0];
  p2 = priv.plane[0] + priv.width*3;
  Y = priv.Y.ptr;
  Cb = priv.Cb.ptr;
  Cr = priv.Cr.ptr;
  offset_to_next_row = (priv.width*3*2) - 16*3;
  for (i=0; i<8; i++) {

    for (j=0; j<8; j++) {

       int y, cb, cr;
       int add_r, add_g, add_b;
       int r, g , b;

       cb = *Cb++ - 128;
       cr = *Cr++ - 128;
       add_r = FIX(1.40200) * cr + ONE_HALF;
       add_g = - FIX(0.34414) * cb - FIX(0.71414) * cr + ONE_HALF;
       add_b = FIX(1.77200) * cb + ONE_HALF;

       y  = (*Y++) << SCALEBITS;
       b = (y + add_b) >> SCALEBITS;
       *p++ = clamp(b);
       g = (y + add_g) >> SCALEBITS;
       *p++ = clamp(g);
       r = (y + add_r) >> SCALEBITS;
       *p++ = clamp(r);

       y  = (*Y++) << SCALEBITS;
       b = (y + add_b) >> SCALEBITS;
       *p++ = clamp(b);
       g = (y + add_g) >> SCALEBITS;
       *p++ = clamp(g);
       r = (y + add_r) >> SCALEBITS;
       *p++ = clamp(r);

       y  = (Y[16-2]) << SCALEBITS;
       b = (y + add_b) >> SCALEBITS;
       *p2++ = clamp(b);
       g = (y + add_g) >> SCALEBITS;
       *p2++ = clamp(g);
       r = (y + add_r) >> SCALEBITS;
       *p2++ = clamp(r);

       y  = (Y[16-1]) << SCALEBITS;
       b = (y + add_b) >> SCALEBITS;
       *p2++ = clamp(b);
       g = (y + add_g) >> SCALEBITS;
       *p2++ = clamp(g);
       r = (y + add_r) >> SCALEBITS;
       *p2++ = clamp(r);
    }
    Y  += 16;
    p  += offset_to_next_row;
    p2 += offset_to_next_row;
  }

}



/**
 *  YCrCb . Grey (1x1)
 *  .---.
 *  | 1 |
 *  `---'
 */
private void YCrCB_to_Grey_1x1(jdec_private *priv)
{
  ubyte *y;
  ubyte *p;
  uint i;
  int offset_to_next_row;

  p = priv.plane[0];
  y = priv.Y.ptr;
  offset_to_next_row = priv.width;

  for (i=0; i<8; i++) {
     memcpy(p, y, 8);
     y+=8;
     p += offset_to_next_row;
  }
}

/**
 *  YCrCb . Grey (2x1)
 *  .-------.
 *  | 1 | 2 |
 *  `-------'
 */
private void YCrCB_to_Grey_2x1(jdec_private *priv)
{
  ubyte *y;
  ubyte *p;
  uint i;

  p = priv.plane[0];
  y = priv.Y.ptr;

  for (i=0; i<8; i++) {
     memcpy(p, y, 16);
     y += 16;
     p += priv.width;
  }
}


/**
 *  YCrCb . Grey (1x2)
 *  .---.
 *  | 1 |
 *  |---|
 *  | 2 |
 *  `---'
 */
private void YCrCB_to_Grey_1x2(jdec_private *priv)
{
  ubyte *y;
  ubyte *p;
  uint i;

  p = priv.plane[0];
  y = priv.Y.ptr;

  for (i=0; i<16; i++) {
     memcpy(p, y, 8);
     y += 8;
     p += priv.width;
  }
}

/**
 *  YCrCb . Grey (2x2)
 *  .-------.
 *  | 1 | 2 |
 *  |---+---|
 *  | 3 | 4 |
 *  `-------'
 */
private void YCrCB_to_Grey_2x2(jdec_private *priv)
{
  ubyte *y;
  ubyte *p;
  uint i;

  p = priv.plane[0];
  y = priv.Y.ptr;

  for (i=0; i<16; i++) {
     memcpy(p, y, 16);
     y += 16;
     p += priv.width;
  }
}


/*
 * Decode all the 3 components for 1x1
 */
private void decode_MCU_1x1_3planes(jdec_private *priv)
{
  // Y
  process_Huffman_data_unit(priv, cY);
  IDCT(&priv.component_infos[cY], priv.Y.ptr, 8);

  // Cb
  process_Huffman_data_unit(priv, cCb);
  IDCT(&priv.component_infos[cCb], priv.Cb.ptr, 8);

  // Cr
  process_Huffman_data_unit(priv, cCr);
  IDCT(&priv.component_infos[cCr], priv.Cr.ptr, 8);
}

/*
 * Decode a 1x1 directly in 1 color
 */
private void decode_MCU_1x1_1plane(jdec_private *priv)
{
  // Y
  process_Huffman_data_unit(priv, cY);
  IDCT(&priv.component_infos[cY], priv.Y.ptr, 8);

  // Cb
  process_Huffman_data_unit(priv, cCb);
  IDCT(&priv.component_infos[cCb], priv.Cb.ptr, 8);

  // Cr
  process_Huffman_data_unit(priv, cCr);
  IDCT(&priv.component_infos[cCr], priv.Cr.ptr, 8);
}


/*
 * Decode a 2x1
 *  .-------.
 *  | 1 | 2 |
 *  `-------'
 */
private void decode_MCU_2x1_3planes(jdec_private *priv)
{
  // Y
  process_Huffman_data_unit(priv, cY);
  IDCT(&priv.component_infos[cY], priv.Y.ptr, 16);
  process_Huffman_data_unit(priv, cY);
  IDCT(&priv.component_infos[cY], priv.Y.ptr+8, 16);

  // Cb
  process_Huffman_data_unit(priv, cCb);
  IDCT(&priv.component_infos[cCb], priv.Cb.ptr, 8);

  // Cr
  process_Huffman_data_unit(priv, cCr);
  IDCT(&priv.component_infos[cCr], priv.Cr.ptr, 8);
}

/*
 * Decode a 2x1
 *  .-------.
 *  | 1 | 2 |
 *  `-------'
 */
private void decode_MCU_2x1_1plane(jdec_private *priv)
{
  // Y
  process_Huffman_data_unit(priv, cY);
  IDCT(&priv.component_infos[cY], priv.Y.ptr, 16);
  process_Huffman_data_unit(priv, cY);
  IDCT(&priv.component_infos[cY], priv.Y.ptr+8, 16);

  // Cb
  process_Huffman_data_unit(priv, cCb);

  // Cr
  process_Huffman_data_unit(priv, cCr);
}


/*
 * Decode a 2x2
 *  .-------.
 *  | 1 | 2 |
 *  |---+---|
 *  | 3 | 4 |
 *  `-------'
 */
private void decode_MCU_2x2_3planes(jdec_private *priv)
{
  // Y
  process_Huffman_data_unit(priv, cY);
  IDCT(&priv.component_infos[cY], priv.Y.ptr, 16);
  process_Huffman_data_unit(priv, cY);
  IDCT(&priv.component_infos[cY], priv.Y.ptr+8, 16);
  process_Huffman_data_unit(priv, cY);
  IDCT(&priv.component_infos[cY], priv.Y.ptr+64*2, 16);
  process_Huffman_data_unit(priv, cY);
  IDCT(&priv.component_infos[cY], priv.Y.ptr+64*2+8, 16);

  // Cb
  process_Huffman_data_unit(priv, cCb);
  IDCT(&priv.component_infos[cCb], priv.Cb.ptr, 8);

  // Cr
  process_Huffman_data_unit(priv, cCr);
  IDCT(&priv.component_infos[cCr], priv.Cr.ptr, 8);
}

/*
 * Decode a 2x2 directly in GREY format (8bits)
 *  .-------.
 *  | 1 | 2 |
 *  |---+---|
 *  | 3 | 4 |
 *  `-------'
 */
private void decode_MCU_2x2_1plane(jdec_private *priv)
{
  // Y
  process_Huffman_data_unit(priv, cY);
  IDCT(&priv.component_infos[cY], priv.Y.ptr, 16);
  process_Huffman_data_unit(priv, cY);
  IDCT(&priv.component_infos[cY], priv.Y.ptr+8, 16);
  process_Huffman_data_unit(priv, cY);
  IDCT(&priv.component_infos[cY], priv.Y.ptr+64*2, 16);
  process_Huffman_data_unit(priv, cY);
  IDCT(&priv.component_infos[cY], priv.Y.ptr+64*2+8, 16);

  // Cb
  process_Huffman_data_unit(priv, cCb);

  // Cr
  process_Huffman_data_unit(priv, cCr);
}

/*
 * Decode a 1x2 mcu
 *  .---.
 *  | 1 |
 *  |---|
 *  | 2 |
 *  `---'
 */
private void decode_MCU_1x2_3planes(jdec_private *priv)
{
  // Y
  process_Huffman_data_unit(priv, cY);
  IDCT(&priv.component_infos[cY], priv.Y.ptr, 8);
  process_Huffman_data_unit(priv, cY);
  IDCT(&priv.component_infos[cY], priv.Y.ptr+64, 8);

  // Cb
  process_Huffman_data_unit(priv, cCb);
  IDCT(&priv.component_infos[cCb], priv.Cb.ptr, 8);

  // Cr
  process_Huffman_data_unit(priv, cCr);
  IDCT(&priv.component_infos[cCr], priv.Cr.ptr, 8);
}

/*
 * Decode a 1x2 mcu
 *  .---.
 *  | 1 |
 *  |---|
 *  | 2 |
 *  `---'
 */
private void decode_MCU_1x2_1plane(jdec_private *priv)
{
  // Y
  process_Huffman_data_unit(priv, cY);
  IDCT(&priv.component_infos[cY], priv.Y.ptr, 8);
  process_Huffman_data_unit(priv, cY);
  IDCT(&priv.component_infos[cY], priv.Y.ptr+64, 8);

  // Cb
  process_Huffman_data_unit(priv, cCb);

  // Cr
  process_Huffman_data_unit(priv, cCr);
}

private void print_SOF(ubyte *stream)
{
  int width, height, nr_components, precision;
/*#if DEBUG
  const char *nr_components_to_string[] = {
     "????",
     "Grayscale",
     "????",
     "YCbCr",
     "CYMK"
  };
#endif*/

  precision = stream[2];
  height = mixin(be16_to_cpu!("stream+3"));
  width  = mixin(be16_to_cpu!("stream+5"));
  nr_components = stream[7];

  trace("> SOF marker\n");
  /*trace("Size:%dx%d nr_components:%d (%s)  precision:%d\n",
      width, height,
      nr_components, nr_components_to_string[nr_components],
      precision);*/
}

/*******************************************************************************
 *
 * JPEG/JFIF Parsing functions
 *
 * Note: only a small subset of the jpeg file format is supported. No markers,
 * nor progressive stream is supported.
 *
 ******************************************************************************/

private void build_quantization_table(float *qtable, ubyte *ref_table)
{
  /* Taken from libjpeg. Copyright Independent JPEG Group's LLM idct.
   * For float AA&N IDCT method, divisors are equal to quantization
   * coefficients scaled by scalefactor[row]*scalefactor[col], where
   *   scalefactor[0] = 1
   *   scalefactor[k] = cos(k*PI/16) * sqrt(2)    for k=1..7
   * We apply a further scale factor of 8.
   * What's actually stored is 1/divisor so that the inner loop can
   * use a multiplication rather than a division.
   */
  int i, j;
  static const double aanscalefactor[8] = [
     1.0, 1.387039845, 1.306562965, 1.175875602,
     1.0, 0.785694958, 0.541196100, 0.275899379
  ];
  ubyte *zz = zigzag.ptr;

  for (i=0; i<8; i++) {
     for (j=0; j<8; j++) {
       *qtable++ = ref_table[*zz++] * aanscalefactor[i] * aanscalefactor[j];
     }
   }

}

private int parse_DQT(jdec_private *priv, ubyte *stream)
{
  int qi;
  float *table;
  ubyte *dqt_block_end;

  trace("> DQT marker\n");
  dqt_block_end = stream + mixin(be16_to_cpu!("stream"));
  stream += 2;  /* Skip length */

  while (stream < dqt_block_end)
   {
     qi = *stream++;
static if (SANITY_CHECK) {
     if (qi>>>4)
       return error(priv,"16 bits quantization table is not supported\n");
     if (qi>4)
       return error(priv,format("No more 4 quantization table is supported (got ",qi,")\n"));
}
     table = priv.Q_tables[qi].ptr;
     build_quantization_table(table, stream);
     stream += 64;
   }
  trace("< DQT marker\n");
  return 0;
}

private int parse_SOF(jdec_private *priv, ubyte *stream)
{
  int i, width, height, nr_components, cid, sampling_factor;
  int Q_table;
  component *c;

  trace("> SOF marker\n");
  print_SOF(stream);

  height = mixin(be16_to_cpu!("stream+3"));
  width  = mixin(be16_to_cpu!("stream+5"));
  nr_components = stream[7];

static if (SANITY_CHECK) {
  if (stream[2] != 8)
    return error(priv,"Precision other than 8 is not supported\n");
  if (width>JPEG_MAX_WIDTH || height>JPEG_MAX_HEIGHT)
    return error(priv,format("Width and Height (%dx%d) seems suspicious\n", width, height));
  if (nr_components != 3)
    return error(priv,"We only support YUV images\n");
  if (height%16)
    return error(priv,format("Height need to be a multiple of 16 (current height is ",height," )\n"));
  if (width%16)
    return error(priv,format("Width need to be a multiple of 16 (current Width is ",width,")\n"));
}
  stream += 8;
  for (i=0; i<nr_components; i++) {
     cid = *stream++;
     sampling_factor = *stream++;
     Q_table = *stream++;
     c = &priv.component_infos[i];
static if (SANITY_CHECK) {
     c.cid = cid;
     if (Q_table >= COMPONENTS) {
       return error(priv,format("Bad Quantization table index (got ", Q_table, " max allowed ", COMPONENTS-1,")\n"));
     }
}
     c.Vfactor = sampling_factor&0xf;
     c.Hfactor = sampling_factor>>>4;
     c.Q_table = priv.Q_tables[Q_table].ptr;
     trace("Component:",cid,"  factor:",c.Hfactor,"x",c.Hfactor,"  Quantization table:",Q_table,"\n");
  }
  priv.width = width;
  priv.height = height;

  trace("< SOF marker\n");

  return 0;
}

private int parse_SOS(jdec_private *priv, ubyte *stream)
{
  uint i, cid, table;
  uint nr_components = stream[2];

  trace("> SOS marker\n");

static if (SANITY_CHECK) {
  if (nr_components != 3)
    return error(priv,"We only support YCbCr image\n");
}

  stream += 3;
  for (i=0;i<nr_components;i++) {
     cid = *stream++;
     table = *stream++;
static if (SANITY_CHECK) {
     if ((table&0xf)>=4)
       return error(priv,"We do not support more than 2 AC Huffman table\n");
     if ((table>>>4)>=4)
       return error(priv,"We do not support more than 2 DC Huffman table\n");
     if (cid != priv.component_infos[i].cid)
       return error(priv,format("SOS cid order (",i,":",cid,") isn't compatible with the SOF marker (",i,":",priv.component_infos[i].cid,")\n"));
     trace("ComponentId:",cid,"  tableAC:",table&0xf," tableDC:",table>>>4,"\n");
}
     priv.component_infos[i].AC_table = &priv.HTAC[table&0xf];
     priv.component_infos[i].DC_table = &priv.HTDC[table>>>4];
  }
  priv.stream = stream+3;
  trace("< SOS marker\n");
  return 0;
}

private int parse_DHT(jdec_private *priv, ubyte *stream)
{
  uint count, i;
  ubyte huff_bits[17];
  int length, index;

  length = mixin(be16_to_cpu!("stream")) - 2;
  stream += 2;  /* Skip length */

  trace("> DHT marker (length=",length,")\n");

  while (length>0) {
     index = *stream++;

     /* We need to calculate the number of bytes 'vals' will takes */
     huff_bits[0] = 0;
     count = 0;
     for (i=1; i<17; i++) {
    huff_bits[i] = *stream++;
    count += huff_bits[i];
     }
static if (SANITY_CHECK) {
     if (count >= HUFFMAN_BITS_SIZE)
       return error(priv,format("No more than ",HUFFMAN_BITS_SIZE," bytes is allowed to describe a huffman table\n"));
     if ( (index &0xf) >= HUFFMAN_TABLES)
       return error(priv,format("No more than ",HUFFMAN_TABLES," Huffman tables is supported (got ",index%0xf,")\n"));
     trace("Huffman table ",(index&0xf0)?"AC":"DC","[",index&0xf,"] length=",count,"\n");
}

     if (index & 0xf0 )
       build_huffman_table(huff_bits.ptr, stream, &priv.HTAC[index&0xf]);
     else
       build_huffman_table(huff_bits.ptr, stream, &priv.HTDC[index&0xf]);

     length -= 1;
     length -= 16;
     length -= count;
     stream += count;
  }
  trace("< DHT marker\n");
  return 0;
}

private int parse_DRI(jdec_private *priv, ubyte *stream)
{
  uint length;

  trace("> DRI marker\n");

  length = mixin(be16_to_cpu!("stream"));

static if (SANITY_CHECK) {
  if (length != 4)
    return error(priv,"Length of DRI marker need to be 4\n");
}

  priv.restart_interval = mixin(be16_to_cpu!("stream+2"));

debug {
  trace("Restart interval = ",priv.restart_interval,"\n");
}

  trace("< DRI marker\n");

  return 0;
}



private void resync(jdec_private *priv)
{
  int i;

  /* Init DC coefficients */
  for (i=0; i<COMPONENTS; i++)
     priv.component_infos[i].previous_DC = 0;

  priv.reservoir = 0;
  priv.nbits_in_reservoir = 0;
  if (priv.restart_interval > 0)
    priv.restarts_to_go = priv.restart_interval;
  else
    priv.restarts_to_go = -1;
}

private int find_next_rst_marker(jdec_private *priv)
{
  int rst_marker_found = 0;
  int marker;
  ubyte *stream = priv.stream;

  /* Parse marker */
  while (!rst_marker_found)
   {
     while (*stream++ != 0xff)
      {
    if (stream >= priv.stream_end)
      return error(priv,"EOF while search for a RST marker.");
      }
     /* Skip any padding ff byte (this is normal) */
     while (*stream == 0xff)
       stream++;

     marker = *stream++;
     if ((RST+priv.last_rst_marker_seen) == marker)
       rst_marker_found = 1;
     else if (marker >= RST && marker <= RST7)
       return error(priv,"Wrong Reset marker found, aborting");
     else if (marker == EOI)
       return 0;
   }
  trace("RST Marker ",priv.last_rst_marker_seen," found at offset ",stream - priv.stream_begin,"\n");

  priv.stream = stream;
  priv.last_rst_marker_seen++;
  priv.last_rst_marker_seen &= 7;

  return 0;
}

private int parse_JFIF(jdec_private *priv, ubyte *stream)
{
  int chuck_len;
  int marker;
  int sos_marker_found = 0;
  int dht_marker_found = 0;
  ubyte *next_chunck;

  /* Parse marker */
  while (!sos_marker_found)
   {
     if (*stream++ != 0xff)
       goto bogus_jpeg_format;
     /* Skip any padding ff byte (this is normal) */
     while (*stream == 0xff)
       stream++;

     marker = *stream++;
     chuck_len = mixin(be16_to_cpu!("stream"));
     next_chunck = stream + chuck_len;
     switch (marker)
      {
       case SOF:
     if (parse_SOF(priv, stream) < 0)
       return -1;
     break;
       case DQT:
     if (parse_DQT(priv, stream) < 0)
       return -1;
     break;
       case SOS:
     if (parse_SOS(priv, stream) < 0)
       return -1;
     sos_marker_found = 1;
     break;
       case DHT:
     if (parse_DHT(priv, stream) < 0)
       return -1;
     dht_marker_found = 1;
     break;
       case DRI:
     if (parse_DRI(priv, stream) < 0)
       return -1;
     break;
       default:
     trace("> Unknown marker ",marker,"\n");
     break;
      }

     stream = next_chunck;
   }

  if (!dht_marker_found) {
    trace("No Huffman table loaded, using the default one\n");
    build_default_huffman_tables(priv);
  }

static if (SANITY_CHECK) {
  if (   (priv.component_infos[cY].Hfactor < priv.component_infos[cCb].Hfactor)
      || (priv.component_infos[cY].Hfactor < priv.component_infos[cCr].Hfactor))
    return error(priv,"Horizontal sampling factor for Y should be greater than horitontal sampling factor for Cb or Cr\n");
  if (   (priv.component_infos[cY].Vfactor < priv.component_infos[cCb].Vfactor)
      || (priv.component_infos[cY].Vfactor < priv.component_infos[cCr].Vfactor))
    return error(priv,"Vertical sampling factor for Y should be greater than vertical sampling factor for Cb or Cr\n");
  if (   (priv.component_infos[cCb].Hfactor!=1)
      || (priv.component_infos[cCr].Hfactor!=1)
      || (priv.component_infos[cCb].Vfactor!=1)
      || (priv.component_infos[cCr].Vfactor!=1))
    return error(priv,"Sampling other than 1x1 for Cr and Cb is not supported");
}

  return 0;
bogus_jpeg_format:
  trace("Bogus jpeg format\n");
  return -1;
}

/*******************************************************************************
 *
 * Functions exported of the library.
 *
 * Note: Some applications can access directly to internal pointer of the
 * structure. It's is not recommended, but if you have many images to
 * uncompress with the same parameters, some functions can be called to speedup
 * the decoding.
 *
 ******************************************************************************/

/**
 * Allocate a new tinyjpeg decoder object.
 *
 * Before calling any other functions, an object need to be called.
 */
jdec_private *tinyjpeg_init()
{
  jdec_private *priv;

  priv = cast(jdec_private *)calloc(1, jdec_private.sizeof);
  if (priv is null)
    return null;
  return priv;
}

/**
 * Free a tinyjpeg object.
 *
 * No others function can be called after this one.
 */
void tinyjpeg_free(jdec_private *priv)
{
  int i;
  for (i=0; i<COMPONENTS; i++) {
     if (priv.components[i])
       free(priv.components[i]);
     priv.components[i] = null;
  }
  free(priv);
}

/**
 * Initialize the tinyjpeg object and prepare the decoding of the stream.
 *
 * Check if the jpeg can be decoded with this jpeg decoder.
 * Fill some table used for preprocessing.
 */
int tinyjpeg_parse_header(jdec_private *priv, ubyte *buf, uint size)
{
  int ret;

  /* Identify the file */
  if ((buf[0] != 0xFF) || (buf[1] != SOI))
    return error(priv,"Not a JPG file ?\n");

  priv.stream_begin = buf+2;
  priv.stream_length = size-2;
  priv.stream_end = priv.stream_begin + priv.stream_length;

  ret = parse_JFIF(priv, priv.stream_begin);

  return ret;
}

private const decode_MCU_fct decode_mcu_3comp_table[4] = [
   &decode_MCU_1x1_3planes,
   &decode_MCU_1x2_3planes,
   &decode_MCU_2x1_3planes,
   &decode_MCU_2x2_3planes,
];

private const decode_MCU_fct decode_mcu_1comp_table[4] = [
   &decode_MCU_1x1_1plane,
   &decode_MCU_1x2_1plane,
   &decode_MCU_2x1_1plane,
   &decode_MCU_2x2_1plane,
];

private const convert_colorspace_fct convert_colorspace_yuv420p[4] = [
   &YCrCB_to_YUV420P_1x1,
   &YCrCB_to_YUV420P_1x2,
   &YCrCB_to_YUV420P_2x1,
   &YCrCB_to_YUV420P_2x2,
];

private const convert_colorspace_fct convert_colorspace_rgb24[4] = [
   &YCrCB_to_RGB24_1x1,
   &YCrCB_to_RGB24_1x2,
   &YCrCB_to_RGB24_2x1,
   &YCrCB_to_RGB24_2x2,
];

private const convert_colorspace_fct convert_colorspace_bgr24[4] = [
   &YCrCB_to_BGR24_1x1,
   &YCrCB_to_BGR24_1x2,
   &YCrCB_to_BGR24_2x1,
   &YCrCB_to_BGR24_2x2,
];

private const convert_colorspace_fct convert_colorspace_grey[4] = [
   &YCrCB_to_Grey_1x1,
   &YCrCB_to_Grey_1x2,
   &YCrCB_to_Grey_2x1,
   &YCrCB_to_Grey_2x2,
];

/**
 * Decode and convert the jpeg image into @pixfmt@ image
 *
 * Note: components will be automaticaly allocated if no memory is attached.
 */
int tinyjpeg_decode(jdec_private *priv, int pixfmt)
{
  uint x, y, xstride_by_mcu, ystride_by_mcu;
  uint[3] bytes_per_blocklines, bytes_per_mcu;
  decode_MCU_fct decode_MCU;
  decode_MCU_fct *decode_mcu_table;
  convert_colorspace_fct *colorspace_array_conv;
  convert_colorspace_fct convert_to_pixfmt;

  /*if (setjmp(priv.jump_state))
    return -1;*/
  try {

  /* To keep gcc happy initialize some array */
  bytes_per_mcu[1] = 0;
  bytes_per_mcu[2] = 0;
  bytes_per_blocklines[1] = 0;
  bytes_per_blocklines[2] = 0;

  decode_mcu_table = decode_mcu_3comp_table.ptr;
  switch (pixfmt) {
     case TINYJPEG_FMT_YUV420P:
       colorspace_array_conv = convert_colorspace_yuv420p.ptr;
       if (priv.components[0] is null)
     priv.components[0] = cast(uint8_t *)malloc(priv.width * priv.height);
       if (priv.components[1] is null)
     priv.components[1] = cast(uint8_t *)malloc(priv.width * priv.height/4);
       if (priv.components[2] is null)
     priv.components[2] = cast(uint8_t *)malloc(priv.width * priv.height/4);
       bytes_per_blocklines[0] = priv.width;
       bytes_per_blocklines[1] = priv.width/4;
       bytes_per_blocklines[2] = priv.width/4;
       bytes_per_mcu[0] = 8;
       bytes_per_mcu[1] = 4;
       bytes_per_mcu[2] = 4;
       break;

     case TINYJPEG_FMT_RGB24:
       colorspace_array_conv = convert_colorspace_rgb24.ptr;
       if (priv.components[0] is null)
     priv.components[0] = cast(uint8_t *)malloc(priv.width * priv.height * 3);
       bytes_per_blocklines[0] = priv.width * 3;
       bytes_per_mcu[0] = 3*8;
       break;

     case TINYJPEG_FMT_BGR24:
       colorspace_array_conv = convert_colorspace_bgr24.ptr;
       if (priv.components[0] is null)
     priv.components[0] = cast(uint8_t *)malloc(priv.width * priv.height * 3);
       bytes_per_blocklines[0] = priv.width * 3;
       bytes_per_mcu[0] = 3*8;
       break;

     case TINYJPEG_FMT_GREY:
       decode_mcu_table = decode_mcu_1comp_table.ptr;
       colorspace_array_conv = convert_colorspace_grey.ptr;
       if (priv.components[0] is null)
     priv.components[0] = cast(uint8_t *)malloc(priv.width * priv.height);
       bytes_per_blocklines[0] = priv.width;
       bytes_per_mcu[0] = 8;
       break;

     default:
       trace("Bad pixel format\n");
       return -1;
  }

  xstride_by_mcu = ystride_by_mcu = 8;
  if ((priv.component_infos[cY].Hfactor | priv.component_infos[cY].Vfactor) == 1) {
     decode_MCU = decode_mcu_table[0];
     convert_to_pixfmt = colorspace_array_conv[0];
     trace("Use decode 1x1 sampling\n");
  } else if (priv.component_infos[cY].Hfactor == 1) {
     decode_MCU = decode_mcu_table[1];
     convert_to_pixfmt = colorspace_array_conv[1];
     ystride_by_mcu = 16;
     trace("Use decode 1x2 sampling (not supported)\n");
  } else if (priv.component_infos[cY].Vfactor == 2) {
     decode_MCU = decode_mcu_table[3];
     convert_to_pixfmt = colorspace_array_conv[3];
     xstride_by_mcu = 16;
     ystride_by_mcu = 16;
     trace("Use decode 2x2 sampling\n");
  } else {
     decode_MCU = decode_mcu_table[2];
     convert_to_pixfmt = colorspace_array_conv[2];
     xstride_by_mcu = 16;
     trace("Use decode 2x1 sampling\n");
  }

  resync(priv);

  /* Don't forget to that block can be either 8 or 16 lines */
  bytes_per_blocklines[0] *= ystride_by_mcu;
  bytes_per_blocklines[1] *= ystride_by_mcu;
  bytes_per_blocklines[2] *= ystride_by_mcu;

  bytes_per_mcu[0] *= xstride_by_mcu/8;
  bytes_per_mcu[1] *= xstride_by_mcu/8;
  bytes_per_mcu[2] *= xstride_by_mcu/8;

  /* Just the decode the image by macroblock (size is 8x8, 8x16, or 16x16) */
  for (y=0; y < priv.height/ystride_by_mcu; y++)
   {
     //trace("Decoding row %d\n", y);
     priv.plane[0] = priv.components[0] + (y * bytes_per_blocklines[0]);
     priv.plane[1] = priv.components[1] + (y * bytes_per_blocklines[1]);
     priv.plane[2] = priv.components[2] + (y * bytes_per_blocklines[2]);
     for (x=0; x < priv.width; x+=xstride_by_mcu)
      {
    decode_MCU(priv);
    convert_to_pixfmt(priv);
    priv.plane[0] += bytes_per_mcu[0];
    priv.plane[1] += bytes_per_mcu[1];
    priv.plane[2] += bytes_per_mcu[2];
    if (priv.restarts_to_go>0)
     {
       priv.restarts_to_go--;
       if (priv.restarts_to_go == 0)
        {
          priv.stream -= (priv.nbits_in_reservoir/8);
          resync(priv);
          if (find_next_rst_marker(priv) < 0)
        return -1;
        }
     }
      }
   }
  }
  catch(TinyJpegException e)
  {
    return -1;
  }

  trace("Input file size: ",priv.stream_length+2,"\n");
  trace("Input bytes actually read: ",priv.stream - priv.stream_begin + 2,"\n");
  return 0;
}

char[] tinyjpeg_get_errorstring(jdec_private *priv)
{
  return priv.error_string;
}

void tinyjpeg_get_size(jdec_private *priv, uint *width, uint *height)
{
  *width = priv.width;
  *height = priv.height;
}

int tinyjpeg_get_components(jdec_private *priv, ubyte **components)
{
  int i;
  for (i=0; priv.components[i] && i<COMPONENTS; i++)
    components[i] = priv.components[i];
  return 0;
}

int tinyjpeg_set_components(jdec_private *priv, ubyte **components, uint ncomponents)
{
  uint i;
  if (ncomponents > COMPONENTS)
    ncomponents = COMPONENTS;
  for (i=0; i<ncomponents; i++)
    priv.components[i] = components[i];
  return 0;
}

int tinyjpeg_set_flags(jdec_private *priv, int flags)
{
  int oldflags = priv.flags;
  priv.flags = flags;
  return oldflags;
}

