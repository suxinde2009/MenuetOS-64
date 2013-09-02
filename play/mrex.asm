;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Audio
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


use64

define B byte
define W word
define D dword
define Q qword


org 0x0

  db  "MENUET64"
  dq  0x01
  dq  _main
  dq  image_end             ;size of image
  dq  stacktop+0x100000*20  ;memory size
  dq  stacktop-16           ;*stack
  dq  0
  dq  0x0

  inwav  equ stacktop
  buffer equ (stacktop+0x400000)
  memm   equ (stacktop+0x800000)

  include "sinc.inc"      ;variable definitions
  include "sc.inc"        ;


;------------------------------------------------------------------------------------
_main:
                      call   draw_window
;------------------------------------------------------------------------------------
still:
                      mov    eax , 10
                      int    0x60

                      test   al  ,1                        ;event handler
                      jnz    event_win
                      test   al  ,2
                      jnz    event_key
                      test   al  ,4
                      jnz    event_button

                      jmp    still
;------------------------------------------------------------------------------------
;WINDOW EVENT
event_win:
                      call   draw_window
                      jmp    still
;------------------------------------------------------------------------------------


;------------------------------------------------------------------------------------
;KEY EVENT
event_key:
                      mov    eax , 2                       ;get key
                      int    0x60
                      jmp    still
;------------------------------------------------------------------------------------


;------------------------------------------------------------------------------------
;BUTTON EVENT
event_button:
                      mov    eax , 17
                      int    0x60
                      test   rax , rax
                      jnz    .end

                      cmp    rbx,0x10000001
                      jnz    .noex
                      mov    eax,512
                      int    0x60
             .noex:
                      cmp    rbx , 100
                      jnz    .end

                      ;define work area
                      mov    rax , 150
                      mov    rbx , 1
                      mov    rcx , memm
                      mov    rdx , 0x100000*10
                      int    0x60

                      ;read file
                      mov    rax , 58
                      mov    rbx , 0
                      mov    rcx , 0
                      mov    rdx , 0x3F0000/512
                      mov    r8  , inwav
                      mov    r9  , inname
                      int    0x60
                      mov    [errcode],byte 0xff
                      cmp    rbx , 0x2c
                      jbe    .endw
                      mov    [errcode],byte 0x00
                      mov    rax , 0x3F0000
                      cmp    rbx , rax
                      cmova  rbx , rax
                      mov    [filesize],rbx

                      ;multi-channel resampling interface follows:

                      mov    rcx , SINC_TABLE_MEDIUM_QUALITY  ;create sinc table
                      mov    rdx , sinctable
                      mov    r8  , 0
                      ;sinc_create
                      mov    rax , 150
                      mov    rbx , 51
                      int    0x60

                      test   rax , rax
                      mov    [errcode], rax
                      jnz    .endw

                      mov    rcx , smchiface                  ;init multi-ch interface
                      mov    rdx , [sinctable]
                      mov    r8  , (SC_FORMAT_16B_ST shl 32)  +  SC_FORMAT_16B_ST  ;format can be obtained by "wfc" too
                      mov    rax , 1.0
                      movq   xmm0, rax
                      mov    rax , 1.08843537414965986  ;48000/44100
                      movq   xmm1, rax
                      ;sinc_init_mch
                      mov    rax , 150
                      mov    rbx , 61
                      int    0x60

                      test   rax , rax
                      mov    [errcode], rax
                      jnz    .endw

                      mov    rdx , inwav + 0x2c               ;init in/out buffer and size
                      mov    r8  , buffer
                      mov    r9  , [filesize]
                      sub    r9  , 0x2c
                      shr    r9  , 2 ; /2/2

                      mov    rcx , [smchiface]                ;process
                      mov    rax , 44100.0
                      movq   xmm0, rax
                      mov    rax , 48000.0
                      movq   xmm1, rax
                      ;sinc_process_mch
                      mov    rax , 150
                      mov    rbx , 63
                      int    0x60

                      mov    ecx , SC_FORMAT_16B_ST           ;update output position
                      and    ecx , 15                         ;bits 3-0 is the sample type or "size"
                      imul   rax , rcx
                      mov    ecx , SC_FORMAT_16B_ST           ;bits 15-8 is the number of channels
                      shr    ecx , 8
                      and    ecx , 255                        ;(see "scextern.inc")
                      imul   rax , rcx
                      add    r8  , rax

                      mov    rcx , [smchiface]                ;get trailing delay
                      mov    r9  , SINC_TRAILING_DELAY
                      mov    rax , 44100.0
                      movq   xmm0, rax
                      mov    rax , 48000.0
                      movq   xmm1, rax
                      ;sinc_process_mch
                      mov    rax , 150
                      mov    rbx , 63
                      int    0x60

                      mov    ecx , SC_FORMAT_16B_ST           ;update output position
                      and    ecx , 15                         ;bits 3-0 is the sample type or "size"
                      imul   rax , rcx
                      mov    ecx , SC_FORMAT_16B_ST           ;bits 15-8 is the number of channels
                      shr    ecx , 8
                      and    ecx , 255                        ;(see "scextern.inc")
                      imul   rax , rcx
                      add    r8  , rax

                      mov    rcx , [smchiface]                ;deinit iface
                      ;sinc_deinit_mch
                      mov   rax , 150
                      mov   rbx , 62
                      int   0x60

                      mov    rcx , [sinctable]                ;destroy sinc table
                      ;sinc_destroy
                      mov   rax , 150
                      mov   rbx , 52
                      int   0x60

                      ;;;

                      mov    rax , 58                         ;write resampled file (no wav header)
                      mov    rbx , 1
                      mov    rdx , r8
                      sub    rdx , buffer
                      mov    r8  , buffer
                      mov    r9  , outname
                      int    0x60

                      inc    D [success]
               .endw:
                      call   draw_window
               .end:
                      jmp    still
;------------------------------------------------------------------------------------








;------------------------------------------------------------------------------------
;DRAW WINDOW
draw_window:
                      mov    eax , 12
                      mov    ebx , 1
                      int    0x60

                      xor    ebx , ebx                     ;define window
                      shl    rbx , 32
                      or     rbx , 400
                      xor    ecx , ecx
                      shl    rcx , 32
                      or     rcx , 200
                      xor    edx , edx
                      mov    r8  , 1
                      lea    r9  , [windowlabel]
                      xor    r10 , r10
                      xor    eax , eax
                      int    0x60

                      mov    rax , 8                       ;draw button
                      mov    rbx , (40 shl 32) + 300
                      mov    rcx , (40 shl 32) + 40
                      mov    edx , 100
                      xor    r8  , r8
                      lea    r9  , [button]
                      int    0x60

                      cmp    D [success],0                 ;write text on success
                      jz     .sk
                      mov    eax , 4
                      mov    rbx , str1
                      mov    rcx , 40
                      mov    rdx , 80
                      mov    r9  , 1
                      mov    rsi , 0x00ff00ff
                      int    0x60
                .sk:
                      mov    eax , 47                      ;display error code
                      mov    ebx , 0x00100100
                      mov    rcx , [errcode]
                      mov    rdx , (40 shl 32) + 100
                      mov    rsi , 0x00ff00ff
                      int    0x60

                      mov    eax , 12
                      mov    ebx , 2
                      int    0x60
                      ret
;------------------------------------------------------------------------------------

align 16

windowlabel db "resample ex 1 (multi-channel)",0
button      db "resample from 44khz to 48khz (out2.raw!)",0
str1        db "successful!",0

inname      db "/fd/1/in.wav",0
outname     db "/fd/1/out2.raw",0

image_end:

align 16

sinctable:  dq ?
smchiface:  dq ?
success:    dq ?
errcode:    dq ?
filesize:   dq ?

times 4096 db ?
stacktop:

