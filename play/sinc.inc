
; THIS FILE IS PART OF THE 'SINC RESAMPLING KERNEL' LIBRARY SOURCE CODE
; COPYRIGHT (C) 2008-2010 Akos Mogyorosi <flowwolf>
; FOR DETAILS SEE THE FILE README

  SINC_CONVBUFFSIZE  =  1024

  SINC_TABLE_VERY_HIGH_QUALITY  =  0
  SINC_TABLE_HIGH_QUALITY       =  1
  SINC_TABLE_MEDIUM_QUALITY     =  2
  SINC_TABLE_LOW_QUALITY        =  3
  SINC_TABLE_VERY_LOW_QUALITY   =  4

;------------------------------------------------------------------------------------
;state
  SINC_ST_LEADING_DELAY  =  1
  SINC_ST_FETCH          =  2
  SINC_ST_DECIMATION     =  4
  SINC_ST_FIRST_START    =  8

;sample formats
  SINC_FORMAT_8B_M          =  (4     )
  SINC_FORMAT_8B_ST_L       =  (4+2+0 )
  SINC_FORMAT_8B_ST_R       =  (4+2+1 )
  SINC_FORMAT_16B_M         =  (8     )
  SINC_FORMAT_16B_ST_L      =  (8+2+0 )
  SINC_FORMAT_16B_ST_R      =  (8+2+1 )
  SINC_FORMAT_32B_M         =  (16    )
  SINC_FORMAT_32B_ST_L      =  (16+2+0)
  SINC_FORMAT_32B_ST_R      =  (16+2+1)
  SINC_FORMAT_FLOAT32_M     =  (32    )
  SINC_FORMAT_FLOAT32_ST_L  =  (32+2+0)
  SINC_FORMAT_FLOAT32_ST_R  =  (32+2+1)
  SINC_TRAILING_DELAY         = -1
  SINC_TRAILING_DELAY_LENGTH  = -2
;------------------------------------------------------------------------------------
;error codes
  SINC_ERR_OK                  =  0
  SINC_ERR_NOT_ENOUGH_MEMORY   = -1
  SINC_ERR_SSE2_NOT_SUPPORTED  = -2
  SINC_ERR_INVALID_FORMAT      = -3
;------------------------------------------------------------------------------------

