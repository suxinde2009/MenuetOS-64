
; THIS FILE IS PART OF THE 'FFT CONVOLUTION KERNEL' LIBRARY SOURCE CODE
; COPYRIGHT (C) 2010 Akos Mogyorosi <flowwolf>
; FOR DETAILS SEE THE FILE README

  FFTCV_CONVBUFFSIZE  =  1024

;------------------------------------------------------------------------------------
;eq
  FFTCV_EQ_64BANDS           =  -1
  FFTCV_EQ_64BANDSV1         =  -3
  FFTCV_EQ_32BANDS           =  -2
  FFTCV_EQ_32BANDSV1         =  -4
  FFTCV_LENGTH_64BANDS       =  16384+1
  FFTCV_LENGTH_64BANDSV1     =  4096+1
  FFTCV_LENGTH_32BANDS       =  8192+1
  FFTCV_LENGTH_32BANDSV1     =  2048+1

;states
  FFTCV_ST_LEADING_DELAY     =  1
  FFTCV_ST_LD_APPLIED        =  2

;wave formats
  FFTCV_FORMAT_8B_M          =  (4     )
  FFTCV_FORMAT_8B_ST_L       =  (4+2+0 )
  FFTCV_FORMAT_8B_ST_R       =  (4+2+1 )
  FFTCV_FORMAT_16B_M         =  (8     )
  FFTCV_FORMAT_16B_ST_L      =  (8+2+0 )
  FFTCV_FORMAT_16B_ST_R      =  (8+2+1 )
  FFTCV_FORMAT_32B_M         =  (16    )
  FFTCV_FORMAT_32B_ST_L      =  (16+2+0)
  FFTCV_FORMAT_32B_ST_R      =  (16+2+1)
  FFTCV_FORMAT_FLOAT32_M     =  (32    )
  FFTCV_FORMAT_FLOAT32_ST_L  =  (32+2+0)
  FFTCV_FORMAT_FLOAT32_ST_R  =  (32+2+1)
  FFTCV_TRAILING_DELAY         = -1
  FFTCV_TRAILING_DELAY_LENGTH  = -2
;------------------------------------------------------------------------------------
;error codes
  FFTCV_ERR_OK                 =  0
  FFTCV_ERR_NOT_ENOUGH_MEMORY  = -11
  FFTCV_ERR_SSE2_NOT_SUPPORTED = -12
  FFTCV_ERR_INVALID_FORMAT     = -13
  FFTCV_ERR_INVALID_OPERATION  = -14
;------------------------------------------------------------------------------------

