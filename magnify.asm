;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Magnify for Menuet64
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use64

      org   0x0

      db    'MENUET64'         ; 8 byte id
      dq    0x01               ; header version
      dq    START              ; start of code
      dq    I_END              ; size of image
      dq    0x100000           ; memory for app
      dq    0xffff0            ; rsp
      dq    0x0,0x0            ; Parameter, Icon

x_size equ 50
y_size equ 40

rex equ r8
rfx equ r9
rgx equ r10
rhx equ r11
rix equ r12
rjx equ r13
rkx equ r14
rlx equ r15

START:

    call  draw_window
    call  draw_magnify

still:

    mov   rax , 11
    int   0x60

    test  rax , 1b    ; Window redraw
    jnz   red

    test  rax , 10b   ; Key press
    jnz   key

    test  rax , 100b  ; Button press
    jnz   button

    mov   rax , 5
    mov   rbx , 20
    int   0x60

    call  draw_magnify

    jmp   still

red:

    call  draw_window
    jmp   still

key:

    mov   rax , 2
    int   0x60

    mov   rax , 512
    int   0x60

    jmp   still

button:

    mov   rax , 17
    int   0x60

    ; rax = status
    ; rbx = button id

    cmp   rbx , 0x10000001
    jne   no_application_terminate
    mov   rax , 512
    int   0x60
  no_application_terminate:

    jmp   still


draw_window:

    mov   rax , 12
    mov   rbx , 1
    int   0x60

    mov   rax , 0                           ; draw window
    mov   rbx , 50 *0x100000000 + 252       ; x start & size
    mov   rcx , 50 *0x100000000 + 230       ; y start & size
    mov   rdx , 1  *0x100000000 + 0xffffff  ; type    & border color
    mov   rex , 1b                          ; draw buttons - close,full,minimize
    mov   rfx , window_label                ; 0 or label - asciiz
    mov   rgx , 0                           ; pointer to menu struct or 0
    int   0x60

    ; Left and right lines

    mov   rbx , 0
    mov   rfx , 0x848484
    mov   rax , 38
    mov   rcx , 0
    mov   rex , 230
    mov   rdx , rbx
    int   0x60
    add   rbx , 50*5+1
    add   rdx , 50*5+1
    int   0x60

    ; Up and Down lines

    mov   rcx , 0
    mov   rfx , 0xe0e0e0
  newup:
    mov   rax , 38
    mov   rbx , 0
    mov   rdx , 280
    mov   rex , rcx
    int   0x60
    push  rcx
    add   rcx , 40*5 +15
    add   rex , 40*5 +15
    int   0x60
    pop   rcx
    mov   rex , rcx
    sub   rfx , 0x0a0a0a
    inc   rcx
    cmp   rcx , 15
    jb    newup

    ;

    mov   rax , 12
    mov   rbx , 2
    int   0x60

    ret


draw_magnify:

    mov   rax , 26
    mov   rbx , 1
    mov   rcx , sys_data
    mov   rdx , 256
    int   0x60

    mov   rkx , 0
    mov   rlx , 0

  newpix:

    mov   rax , 35
    mov   rbx , 1
    mov   rcx , rkx
    mov   rdx , rlx
    add   rcx ,[sys_data+6*8]
    add   rdx ,[sys_data+7*8]
    sub   rcx , x_size
    sub   rdx , y_size
    int   0x60

    mov   rdx , rax

    mov   rax , 13
    mov   rbx , rkx
    imul  rbx , 5
    inc   rbx
    shl   rbx , 32
    add   rbx , 5
    mov   rcx , rlx
    imul  rcx , 5
    add   rcx , 15
    shl   rcx , 32
    add   rcx , 5
    int   0x60

    inc   rkx
    cmp   rkx , x_size
    jb    newpix

    mov   rkx , 0

    inc   rlx
    cmp   rlx , y_size
    jb    newpix

    ret


; Data

window_label:

    db   'MAGNIFIER',0

sys_data:


I_END:

