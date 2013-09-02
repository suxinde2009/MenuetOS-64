
; THIS FILE IS PART OF THE 'SAMPLE CONVERTER' LIBRARY SOURCE CODE
; COPYRIGHT (C) 2009-2010 Akos Mogyorosi <flowwolf>
; FOR DETAILS SEE THE FILE README

;------------------------------------------------------------------------------------
;sample formats
;
; bits 63-16 : reserved
; bits 15-8  : number of channels (1-255)
; bits 7-4   : format descriptor  (+16=float +128=unsigned)
; bits 3-0   : sample type        (1=8-bit 2=16-bit 3=24-bit 4=32-bit)

  SC_FORMAT_8B       =  (1    )  ;  signed  8-bit
  SC_FORMAT_U8B      =  (1+128)  ;unsigned  8-bit
  SC_FORMAT_16B      =  (2    )  ;  signed 16-bit
  SC_FORMAT_U16B     =  (2+128)  ;unsigned 16-bit
  SC_FORMAT_24B      =  (3    )  ;  signed 24-bit
  SC_FORMAT_U24B     =  (3+128)  ;unsigned 24-bit
  SC_FORMAT_32B      =  (4    )  ;  signed 32-bit
  SC_FORMAT_U32B     =  (4+128)  ;unsigned 32-bit
  SC_FORMAT_FLOAT32  =  (4+16 )  ;  signed 32-bit float
  SC_FORMAT_M        =  (1 shl 8)
  SC_FORMAT_ST       =  (2 shl 8)
define  SC_FORMAT_8B_M    (SC_FORMAT_U8B or SC_FORMAT_M )
define  SC_FORMAT_8B_ST   (SC_FORMAT_U8B or SC_FORMAT_ST)
define  SC_FORMAT_16B_M   (SC_FORMAT_16B or SC_FORMAT_M )
define  SC_FORMAT_16B_ST  (SC_FORMAT_16B or SC_FORMAT_ST)
define  SC_FORMAT_24B_M   (SC_FORMAT_24B or SC_FORMAT_M )
define  SC_FORMAT_24B_ST  (SC_FORMAT_24B or SC_FORMAT_ST)
define  SC_FORMAT_32B_M   (SC_FORMAT_32B or SC_FORMAT_M )
define  SC_FORMAT_32B_ST  (SC_FORMAT_32B or SC_FORMAT_ST)
define  SC_FORMAT_FLOAT32_M   (SC_FORMAT_FLOAT32 or SC_FORMAT_M )
define  SC_FORMAT_FLOAT32_ST  (SC_FORMAT_FLOAT32 or SC_FORMAT_ST)
;------------------------------------------------------------------------------------
;error codes
  SC_ERR_OK                  =  0
  SC_ERR_NOT_ENOUGH_MEMORY   = -30
  SC_ERR_SSE2_NOT_SUPPORTED  = -31
;------------------------------------------------------------------------------------

