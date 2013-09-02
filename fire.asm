;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;    Fire for Menuet
;
;    Compile with FASM
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use64

    org   0x0

    db    'MENUET64'           ; 8 byte id
    dq    0x01                 ; required os
    dq    START                ; program start
    dq    I_END                ; image size
    dq    0x100000             ; reguired amount of memory
    dq    0x07fff0
    dq    0,0

START:

    call  draw_window

still:

    mov   eax,11
    int   0x40

    cmp   eax,1
    jz    red
    cmp   eax,3
    jz    button

    call  fire_image

    jmp   still

  red:                            ; Draw window
    call  draw_window
    jmp   still

  button:                         ; Get button id

    mov   rax,17
    int   0x60

    cmp   rbx,0x10000001          ; Close program
    jne   noclose
    mov   rax,512
    int   0x60
  noclose:

    cmp   rbx,0x102               ; Change fire type
    jne   nob2
    mov   eax,[type]
    add   eax,1
    and   eax,1
    mov   [type],eax
    jmp   still
  nob2:

    cmp   rbx,0x103               ; Change delay
    jne   nob3
    mov   eax,[delay]
    sub   eax,1
    and   eax,1
    mov   [delay],eax
    jmp   still
  nob3:

    cmp   rbx,0x104               ; Change color
    jne   nob4
    mov   eax,[fcolor]
    add   eax,1
    cmp   eax,2
    jbe   fcfine
    mov   eax,0
  fcfine:
    mov   [fcolor],eax
    mov   eax,0
    mov   ecx,0x10000
    mov   edi,0x80000
    cld
    rep   stosd
    jmp   still
  nob4:

    cmp   rbx,0x106               ; Quit
    jne   nob6
    mov   rax,512
    int   0x60
   nob6:

    jmp   still


fire_image:

    mov   esi, FireScreen
    add   esi, 0x2300
    sub   esi, 80
    mov   ecx, 80
    xor   edx, edx

  NEWLINE:

    mov   eax , [FireSeed]
    mov   edx , 0x8405
    mul   edx
    inc   eax
    mov   dword [FireSeed], eax

    mov   [esi], dl
    inc   esi
    dec   ecx
    jnz   NEWLINE

    mov   ecx, 0x2300
    sub   ecx, 80
    mov   esi, FireScreen
    add   esi, 80

  FIRELOOP:

    xor   eax,eax

    cmp   [type],0
    jnz   notype1
    mov   al, [esi]
    add   al, [esi + 2]
    adc   ah, 0
    add   al, [esi + 1]
    adc   ah, 0
    add   al, [esi + 81]
    adc   ah, 0
  notype1:

    cmp   [type],1
    jnz   notype2
    mov   al, [esi]
    add   al, [esi - 1]
    adc   ah, 0
    add   al, [esi - 1]
    adc   ah, 0
    add   al, [esi + 79]
    adc   ah,0
  notype2:

    cmp   [type],2
    jnz   notype3
    mov   al, [esi]
    add   al, [esi - 1]
    adc   ah,0
    add   al, [esi + 1]
    adc   ah, 0
    add   al, [esi + 81]
    adc   ah,0
  notype3:

    shr   eax, 2
    jz    ZERO
    dec   eax

  ZERO:

    mov   [esi - 80], al
    inc   esi
    dec   ecx
    jnz   FIRELOOP

    push  rax rbx rcx rdx rsi rdi

    mov   eax,5
    mov   ebx,[delay]
    int   0x40

    mov   al,byte [calc]
    inc   al
    mov   byte [calc],al
    cmp   al,byte 2
    jz    pdraw

    jmp   nodrw

  pdraw:

    mov   byte [calc],byte 0

    mov   edi,0x80000
    add   edi,[fcolor]
    mov   esi,FireScreen
    xor   edx,edx

  newc:

    movzx eax,byte [esi]
    mov   ebx,eax
    mov   ecx,eax
    shl   ax,8
    shr   bx,1
    mov   al,bl
    add   ecx,eax
    shl   ax,8
    mov   ch,ah

    mov   [edi+0],cx
    mov   [edi+3],cx
    mov   [edi+6],cx
    mov   [edi+9],cx
    mov   [edi+0+320*3],cx
    mov   [edi+3+320*3],cx
    mov   [edi+6+320*3],cx
    mov   [edi+9+320*3],cx

    add   edi,12
    inc   edx
    cmp   edx,80
    jnz   nnl
    xor   edx,edx
    add   edi,320*3
   nnl:
    inc   esi
    cmp   esi,FireScreen+0x2000
    jnz   newc

    mov   eax,7                       ; display image
    mov   ebx,0x80000
    mov   ecx,4*80*65536+200
    mov   edx,5*65536+39
    int   0x40

  nodrw:

    pop   rdi rsi rdx rcx rbx rax

    ret


draw_window:

    mov   eax,12
    mov   ebx,1
    int   0x40

    mov   rax , 0
    mov   rbx , 100 * 0x100000000 + 330
    mov   rcx , 100 * 0x100000000 + 244
    mov   rdx , 0x000000
    mov   r8  , 0
    mov   r9  , window_label
    mov   r10 , menu_struct
    int   0x60

    mov   eax,12
    mov   ebx,2
    int   0x40

    ret


; Data area

calc    dd 0
fcolor  dd 2
type    dd 0
delay   dd 1

FireSeed  dd 0x1234

window_label:

    db 'FIRE',0

menu_struct:

   dq   0x000

   dq   0x100

   db   0,'FILE',0
   db   1,'Type',0
   db   1,'Speed',0
   db   1,'Color',0
   db   1,'-',0
   db   1,'Quit',0

   db   255

FireScreen:

I_END:

