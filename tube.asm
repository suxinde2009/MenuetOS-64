;  (м) ( ) м ) ( )   256b intro by baze/3SC for Syndeecate 2001   use NASM to
;  плп лмл ллл ллм   loveC: thanks, Serzh: eat my socks dude ;]   compile the
;  ( ) ( ) ( ) ( )   e-mail: baze@stonline.sk, web: www.3SC.sk    source code

;  Menuet port by VT

use64

    org   0x0

    db    'MENUET64'              ; Header identifier
    dq    0x01                    ; Version
    dq    START                   ; Start of code
    dq    I_END                   ; Size of image
    dq    0x100000                ; Memory for app
    dq    0xffff0                 ; Esp
    dq    0x00                    ; Prm
    dq    0x00                    ; Icon

START:

    call  draw_window
    call  init_tube

    push  rbx

still:

    pop   rbx

    call  MAIN

    push  rbx

    mov   eax,23
    mov   ebx,1
    int   0x40

    cmp   eax,1
    jne   no_red
    call  draw_window
    jmp   still
   no_red:

    cmp   eax,2
    jne   nokey
    push  rax rbx rcx
    mov   eax , 2
    int   0x60
    pop   rcx rbx rax
    jmp   still
  nokey:

    cmp   eax,0
    je    still
    mov   eax,-1
    int   0x40

SCREEN  equ 160
PIXBUF  equ 200h
EYE     equ EYE_P-2

MAIN:

    add   bh,10;8
    mov   rdi,PIXBUF
    fadd  dword [rdi-PIXBUF+TEXUV-4]
    push  di
    mov   dx,-80

TUBEY:

    mov   bp,-160

TUBEX:

    mov   rsi,TEXUV
    fild  word [rsi-TEXUV+EYE]
    mov   [rsi],bp
    fild  word [rsi]
    mov   [rsi],dx
    fild  word [rsi]
    mov   cl,2

ROTATE:

    fld   st3
    fsincos
    fld   st2
    fmul  st0,st1
    fld   st4
    fmul  st0,st3
    db    0xde,0xe9 ; fsubp   st1,st0
    db    0xd9,0xcb ; fxch    st3
    fmulp st2,st0
    fmulp st3,st0
    faddp st2,st0
    db    0xd9,0xca ; fxch    st2

    loop  ROTATE

    fld   st1
    db    0xdc,0xc8 ; fmul    st0,st
    fld   st1
    db    0xdc,0xc8 ; fmul    st0,st
    faddp st1,st0
    fsqrt
    db    0xde,0xfb ; fdivp   st3,st0
    fpatan
    fimul word [rsi-4]
    fistp word [rsi]
    fimul word [rsi-4]
    fistp word [rsi+1]
    mov   si,[rsi]

    lea   ax,[rbx+rsi]
    add   al,ah
    and   al,64
    mov   al,-5
    jz    stor

    shl   si,2
    lea   ax,[rbx+rsi]
    sub   al,ah
    mov   al,-16
    jns   stor

    shl   si,1
    mov   al,-48

stor:

    ; add    al,[ebx+esi+0x80000]
    add   [rdi],al
    inc   di

    inc   bp
    cmp   bp,160

EYE_P:

    jnz   TUBEX
    inc   dx
    cmp   dx,80
    jnz   TUBEY

    call  display_image

    pop   si
    mov   ch,SCREEN*320/256

BLUR:

    inc   si
    sar   byte [rsi],2
    loop  BLUR

    ret

display_image:

    push  rax rbx rcx rdi rsi rdi

    mov   rsi,PIXBUF
    mov   rdi,0xA0000
 newp:
    movzx edx,byte [rsi]
    shl   edx,4
    mov   [rdi],edx

    add   edi,3
    inc   esi

    cmp   esi,320*160+PIXBUF
    jbe   newp

    mov   eax,7
    mov   ecx,320*65536+159
    mov   edx,25*65536+42
    mov   ebx,0xA0000 + 320*3
    int   0x40

    pop   rdi rsi rdx rcx rbx rax
    ret


draw_window:

    push  rax rbx rcx rdx rsi rdi

    mov   eax,12
    mov   ebx,1
    int   0x40

    mov   rax , 0
    mov   rbx , 100 * 0x100000000 + 370
    mov   rcx , 100 * 0x100000000 + 225
    mov   rdx , 0x000000
    mov   r8  , 0
    mov   r9  , window_label
    mov   r10 , 0
    int   0x60

    mov   eax,12
    mov   ebx,2
    int   0x40

    pop   rdi rsi rdx rcx rbx rax

    ret

window_label:

    db   'TUBE',0

db 41,0,0xC3,0x3C

TEXUV:

init_tube:

    mov   ecx,256

PAL1:

    mov   dx,3C8h
    mov   ax,cx
    inc   dx
    sar   al,1
    js    PAL2
    mul   al
    shr   ax,6

PAL2:

    mov   al,0
    jns   PAL3
    sub   al,cl
    shr   al,1
    shr   al,1

PAL3:

    mov   bx,cx
    mov   [ebx+0x80000],bh
    loop  PAL1
    mov   ecx,256

TEX:

    mov   bx,cx
    add   ax,cx
    rol   ax,cl
    mov   dh,al
    sar   dh,5
    adc   dl,dh
    adc   dl,[ebx+255+0x80000]
    shr   dl,1
    mov   [ebx+0x80000],dl
    not   bh
    mov   [ebx+0x80000],dl
    loop  TEX

    fninit
    fldz

    ret


I_END:

