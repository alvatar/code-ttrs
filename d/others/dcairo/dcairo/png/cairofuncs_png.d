/**
 * This module contains functions related to cairo's PNG
 * functionality.
 *
 * This file is automatically generated; do not directly modify.
 *
 * Authors: Daniel Keep
 * Copyright: 2006, Daniel Keep
 * License: BSD v2 (http://www.opensource.org/licenses/bsd-license.php).
 */
/*
 * Copyright © 2006 Daniel Keep
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 *
 * * Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 *
 * * Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the distribution.
 *
 * * Neither the name of this software, nor the names of its contributors
 *   may be used to endorse or promote products derived from this software
 *   without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
module cairo.png.cairofuncs_png;

version( cairo_1_4 ) { version = cairo_1_2; }

private
{
    import cairo.loader;
    import cairo.png.cairotypes_png;
}

package void cairo_png_loadprocs(SharedLib lib)
{
    // cairo functions
    //Name = cast(pfName)getProc(lib, "Name");
    cairo_surface_write_to_png_stream = cast(pf_cairo_surface_write_to_png_stream)getProc(lib, "cairo_surface_write_to_png_stream");
    cairo_image_surface_create_from_png = cast(pf_cairo_image_surface_create_from_png)getProc(lib, "cairo_image_surface_create_from_png");
    cairo_image_surface_create_from_png_stream = cast(pf_cairo_image_surface_create_from_png_stream)getProc(lib, "cairo_image_surface_create_from_png_stream");
    cairo_surface_write_to_png = cast(pf_cairo_surface_write_to_png)getProc(lib, "cairo_surface_write_to_png");
}

// C calling convention for BOTH linux and Windows
extern(C):

//typedef Tr function( Ta... ) pfName;
typedef cairo_status_t function(cairo_surface_t* surface, cairo_write_func_t write_func, void* closure) pf_cairo_surface_write_to_png_stream;
typedef cairo_surface_t* function(char* filename) pf_cairo_image_surface_create_from_png;
typedef cairo_surface_t* function(cairo_read_func_t read_func, void* closure) pf_cairo_image_surface_create_from_png_stream;
typedef cairo_status_t function(cairo_surface_t* surface, char* filename) pf_cairo_surface_write_to_png;

//pfName Name;
pf_cairo_surface_write_to_png_stream cairo_surface_write_to_png_stream;
pf_cairo_image_surface_create_from_png cairo_image_surface_create_from_png;
pf_cairo_image_surface_create_from_png_stream cairo_image_surface_create_from_png_stream;
pf_cairo_surface_write_to_png cairo_surface_write_to_png;
