/**********************************************************************************
 * Copyright (c) 2008-2009 The Khronos Group Inc.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and/or associated documentation files (the
 * "Materials"), to deal in the Materials without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Materials, and to
 * permit persons to whom the Materials are furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be included
 * in all copies or substantial portions of the Materials.
 *
 * THE MATERIALS ARE PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
 * CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 * TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 * MATERIALS OR THE USE OR OTHER DEALINGS IN THE MATERIALS.
 **********************************************************************************/

// $Revision: 8407 $ on $Date: 2009-06-12 10:56:38 -0700 (Fri, 12 Jun 2009) $

module opencl.cl_gl;

import opencl.platform;
import opencl.opencl;

extern(C):

alias cl_uint     cl_gl_object_type;
alias cl_uint     cl_gl_texture_info;
alias cl_uint     cl_gl_platform_info;

enum
{
	// cl_gl_object_type
	CL_GL_OBJECT_BUFFER             = 0x2000,
	CL_GL_OBJECT_TEXTURE2D          = 0x2001,
	CL_GL_OBJECT_TEXTURE3D          = 0x2002,
	CL_GL_OBJECT_RENDERBUFFER       = 0x2003,

	// cl_gl_texture_info
	CL_GL_TEXTURE_TARGET            = 0x2004,
	CL_GL_MIPMAP_LEVEL              = 0x2005,
}

cl_mem clCreateFromGLBuffer(
	cl_context     /* context */,
	cl_mem_flags   /* flags */,
	GLuint         /* bufobj */,
	int*           /* errcode_ret */
);

cl_mem clCreateFromGLTexture2D(
	cl_context      /* context */,
	cl_mem_flags    /* flags */,
	GLenum          /* target */,
	GLint           /* miplevel */,
	GLuint          /* texture */,
	int*            /* errcode_ret */
);

cl_mem clCreateFromGLTexture3D(
	cl_context      /* context */,
	cl_mem_flags    /* flags */,
	GLenum          /* target */,
	GLint           /* miplevel */,
	GLuint          /* texture */,
	int*            /* errcode_ret */
);

cl_mem clCreateFromGLRenderbuffer(
	cl_context   /* context */,
	cl_mem_flags /* flags */,
	GLuint       /* renderbuffer */,
	int*         /* errcode_ret */
);

cl_int clGetGLObjectInfo(
	cl_mem                /* memobj */,
	cl_gl_object_type*    /* gl_object_type */,
	GLuint*               /* gl_object_name */
);
                  
cl_int clGetGLTextureInfo(
	cl_mem               /* memobj */,
	cl_gl_texture_info   /* param_name */,
	size_t               /* param_value_size */,
	void*                /* param_value */,
	size_t*              /* param_value_size_ret */
);

cl_int clEnqueueAcquireGLObjects(
	cl_command_queue      /* queue */,
	cl_uint               /* num_objects */,
	const(cl_mem)*        /* mem_objects */,
	cl_uint               /* num_events_in_wait_list */,
	const(cl_event)*      /* event_wait_list */,
	cl_event*             /* event */
);

cl_int clEnqueueReleaseGLObjects(
	cl_command_queue      /* queue */,
	cl_uint               /* num_objects */,
	const(cl_mem)*        /* mem_objects */,
	cl_uint               /* num_events_in_wait_list */,
	const(cl_event)*      /* event_wait_list */,
	cl_event*             /* event */
);