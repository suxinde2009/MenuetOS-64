use64

define B byte
define W word
define D dword
define Q qword

inwav   equ (stacktop+0x100000)
buffer  equ (stacktop+0x200000)
memm    equ (stacktop+0x300000)

macro push [arg]    ;push - pop
{                   ;
 reverse push arg   ;
}                   ;
                    ;
macro pop [arg]     ;
{                   ;
 reverse pop arg    ;
}                   ;


org 0x0

  db  "MENUET64"
  dq  0x01
  dq  main
  dq  image_end             ;size of image
  dq  memm+0x100000*12      ;memory size
  dq  stacktop-16           ;*stack
  dq  0
  dq  0x0

  align 16

  include "fftcv.inc"      ;
  include "sc.inc"         ;

  include "play.inc"
  include "spa.inc"
  include "eq.inc"

image_end:

align 16
spa_sciface:    dq ?               ;spa variables
spa_ffttab:     dq ?               ;
fmchiface:      dq ?
fftcvif:        dq ?
success:        dq ?
errcode:        dq ?
spa_type:       dq ?

align 16
spa_fftbuff0:   times 4096   dd ?
spa_fftbuff1:   times 4096   dd ?
spa_fftbuff2:   times 4096*2 dq ?

dragndrop:      times 512 db ?
wavname:        times 512 db ?

cblock:         times 0x10000 db ?
wave:           times 0xf0000 db ?
playlist:       times 0x10000 db ?

fftcvifaces:    times 48 dq ?

spectrumimage:  times 205*65 dd ?

buffer0:        times frsize*7*512 db ?
buffer1:        times frsize*7*512 db ?

dispblock:      times (8192+8192) db ?  ;; kept as a pair
dispblock2:     times (8192+8192) db ?  ;;


                times 4096 dd ?
readbufstack:
                times 4096 dd ?
stacktop:

