
; COPYRIGHT (C) 2008-2010 Akos Mogyorosi <flowwolf>
; FOR DETAILS SEE THE FILE README

  DEF_STREAMBUFFSIZE    =  4096 ;stream buffer size
  DEF_MEMORY_STREAM     =  1    ;1=enable 0=disable stream type
  DEF_FILE_STREAM       =  0    ;
  DEF_CALLBACK_STREAM   =  0    ;

  STREAM_TYPE_MEM       =  1
  STREAM_TYPE_FILE      =  2
  STREAM_TYPE_CALLBACK  =  3
  STREAM_SEEK_BEGIN         =  0
  STREAM_SEEK_CURRENT       =  1
  STREAM_SEEK_FORCECURRENT  =  3
  STREAM_ERR_OK                 =  0
  STREAM_ERR_NOT_ENOUGH_MEMORY  =  1
  STREAM_ERR_FILE_NOT_FOUND     =  2
  STREAM_ERR_STREAM_READ        =  3
  STREAM_ERR_STREAM_SEEK        =  4
  STREAM_ERR_STREAM_BUFFER      =  5

;memory   stream:  param1=rsi            param2=r15
;file     stream:  param1=filename       param2=0  (filehndl)
;callback stream:  param1=*callbackproc  param2=id
;         (id, *mem, size, filepointer, *numberofbytesread) ret zero on error
;          if *mem is zero, filesize or zero should be returned

;error codes
macro setlasterror a
{
 if a<256
  mov    [rbp+lasterror], B a
 else
  mov    [rbp+lasterror], D a
 end if
}

 lasterror        =  8
 streamtype       =  12
 streamparam1     =  16
 streamparam2     =  24
 streambuff       =  32
 streamfileptr    =  40
 streambuffsize   =  48

 INVALID_HANDLE_VALUE  = -1

