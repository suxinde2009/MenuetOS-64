
; THIS FILE IS PART OF THE 'WAVE FORMAT CONVERTER' LIBRARY SOURCE CODE
; COPYRIGHT (C) 2010 Akos Mogyorosi <flowwolf>
; FOR DETAILS SEE THE FILE README

  WFC_INFO_FORMAT       =  0
  WFC_INFO_FORMAT_TAG   =  4
  WFC_INFO_CHANNELS     =  8
  WFC_INFO_RATE         =  12
  WFC_INFO_BITSPERSAMP  =  16
  WFC_INFO_SAMPSIZE     =  20
  WFC_INFO_SCFORMAT     =  24
  WFC_INFO_SIZE         =  28
  WFC_INFOSIZE          =  32

;------------------------------------------------------------------------------------
  WFC_FORMAT_RAW  =  0
  WFC_FORMAT_WAV  =  1

  WFC_FORMAT_TAG_PCM         =  1
  WFC_FORMAT_TAG_IEEE_FLOAT  =  3
;------------------------------------------------------------------------------------
;error codes
  WFC_ERR_OK                  =  0
  WFC_ERR_NOT_ENOUGH_MEMORY   = -40
  WFC_ERR_SSE2_NOT_SUPPORTED  = -41
;------------------------------------------------------------------------------------
















