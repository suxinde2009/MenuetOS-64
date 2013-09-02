;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Mandelbrot fractal
;
;   Compile with FASM 1.60 or above
;
;   Based on TinyDemo by Andreas Agorander
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use64

    org   0x0

    db    'MENUET64'              ; Header identifier
    dq    0x01                    ; Version
    dq    START                   ; Start of code
    dq    image_end               ; Size of image
    dq    0x200000                ; Memory for app
    dq    0x1ffff0                ; Esp
    dq    0x00                    ; Prm
    dq    0x00                    ; Icon

START:

    mov   rax , 141
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    call  draw_window       ; At first, draw the window

    call  calculate_fractal

still:

    mov   rax , 10          ; Wait here for event
    int   0x60

    test  rax , 0x1         ; Window redraw
    jnz   window_event
    test  rax , 0x2         ; Keyboard press
    jnz   key_event
    test  rax , 0x4         ; Button press
    jnz   button_event

    jmp   still

window_event:

    call  draw_window
    jmp   still

key_event:

    mov   rax , 0x2        ; Read the key and ignore
    int   0x60

    jmp   still


sprite    equ  32768

mandel_calculate:

    finit

    ; First, calculate the floating point value of the current
    ; pixel -2 to 2 for 0-127

    sub   [curx],word 128
    sub   [cury],word 128

    fld1  ;ST0 = 1
    fidiv word [fdivc];ST0 = 1/32
    fst   ST1;ST1 = 1/32
    fimul word [curx];ST0 = 1/32*curx
    fisub word [two];ST0 = 1/32*curx-2
    fst   ST6;ST6 = ---  "  ---
    fxch;ST0 = 1/32 , ST1 = 1/16*curx-4
    fimul word [cury];ST0 = 1/32*cury
    fisub word [two];ST0 = 1/32*cury-2
    fst   ST7;ST7 = ---  "  ---

    ; cury is now in ST0 and curx in ST1

    add  [curx],word 128
    add  [cury],word 128

    mov  cx,[numiter]

iteration:

    ; The new values for the pixel is calculated
    ; curx is the real part and cury the imaginary part
    ;
    ; Formula:
    ;
    ;           curx = curx^2 - cury^2 + curx
    ;           cury = 2*curx*cury + cury
    ;           ST0 = ST7 = cury
    ;           ST1 = ST6 = curx

    fst   ST2;cury
    fxch
    fst   ST3;curx

    ;ST0 = ST3 = ST6 = curx
    ;ST1 = ST2 = ST7 = cury

    fmul  st0 , st0 ;
    fxch             ;ST0 = cury , ST1 = curx^2
    fmul  ST0 , st0
    fxch        ;ST0 = curx^2 , ST1 = cury^2
    fsub  st0 , st1 ;curx^2 - cury^2
    fadd  st0 , st6 ;curx^2 - cury^2 + curx
    fst  ST4;ST4 = curx^2 - cury^2 + curx

    ;ST0 = ST4 = curx^2 - cury^2 + curx
    ;ST1 = curx^2
    ;ST2 = ST7 = cury
    ;ST3 = ST6 = curx
    ;
    ; Now for the imaginary part

    fxch  ST2 ;cury -> ST0
    fmul  st0 , st3 ; urx
    fimul word [two] ; 2*cury*curx
    fadd  st0 , st7 ; *curx + cury

    ;ST0 = 2*cury*curx + cury
    ;ST1 = curx^2
    ;ST2 = curx^2 - cury^2 + curx
    ;ST3 = ST6 = curx
    ;ST4 = curx^2 - cury^2 + curx
    ;ST7 = cury
    ;
    ; Now ST0 contains the new cury and ST4 contains the new curx
    ; Time to check if the distance from origo is more than 2

    fst   ST2;cury -> ST2
    fabs
    fxch  ST4
    fst   ST3;curx -> ST3
    fabs
    fadd  st0 , st4
    ficom word [two]
    fstsw ax

    test ax , 0000000000000001b
    jnz  enditer

    fxch  ST3
    fxch  ST1
    fxch  ST2

    ; Next iteration

    loop  iteration

enditer:

    ; Calculate pixel position in sprite

    mov esi , 0

    mov ax, [cury]
    sub ax, [starty]
    shl ax, 8
    add si, ax
    mov bx, [curx]
    sub bx, [startx]
    add si, bx

    ; Paint pixel

    and  esi , 0xffff

    and  ecx , 0xff
    shl  ecx , 3+16

    imul esi , 3
    mov  [sprite+esi],ecx

    ; Now increase curx and cury to correct values

    mov  ax , [cury]
    mov  bx , [curx]

    inc  ax

    mov  cx , [starty]
    add  cx , 256

    cmp  ax , cx
    jb   contx

    mov  ax,[starty]

    inc  bx

   contx:

     mov  [curx], bx
     mov  [cury], ax

     ret


calculate_fractal:

    mov   ax , [scroll2]
    sub   ax , 2000
    mov   [sx],ax

    mov   ax , [scroll3]
    sub   ax , 3000
    mov   [sy],ax

    mov   ax , [scroll1]
    sub   ax , 999
    mov   bx , 64
    imul  bx , ax
    mov   [fdivc],bx

  newpicture:

    mov   rax , [fdivc]
    and   rax , 0xffff
    xor   rdx , rdx
    mov   rbx , 64
    div   rbx

    mov   bx , [sx]
    imul  bx , ax
    add   bx , dx
    mov   [startx],bx

    mov   bx , [sy]
    imul  bx , ax
    mov   [starty],bx

    mov   ax , [startx]
    mov   bx , [starty]

    mov   [curx],ax
    mov   [cury],bx

    call  draw_pic

    ;

    mov   rcx , 256*256

  il0:

    push  rcx

    call  mandel_calculate

    pop   rcx

    loop  il0

  nomore:

    call  draw_pic

    ;mov   ax , [fdivc]
    ;add   ax , 64
    ;mov   [fdivc],ax

    ret


draw_pic:

    mov   rax , 7
    mov   rbx , 22  * 0x100000000 + 256
    mov   rcx , 60  * 0x100000000 + 256
    mov   rdx , 32768
    mov   r8  , 0
    mov   r9  , 0x1000000
    mov   r10 , 3
    int   0x60

    ret


button_event:

    mov   rax , 0x11
    int   0x60

    ; rax = status
    ; rbx = button id

    cmp   rbx , 1000           ; Vertical scroll values 300-319
    jb    no_vertical_scroll
    cmp   rbx , 1999
    ja    no_vertical_scroll
    mov  [scroll1], rbx
    call  draw_scroll1
    call  calculate_fractal
    jmp   still
  no_vertical_scroll:

    cmp   rbx , 2000
    jb    nosc2
    cmp   rbx , 2999
    ja    nosc2
    mov   [scroll2],rbx
    call  draw_scroll2
    call  calculate_fractal
    jmp   still
  nosc2:

    cmp   rbx , 3000
    jb    nosc3
    cmp   rbx , 3999
    ja    nosc3
    mov   [scroll3],rbx
    call  draw_scroll3
    call  calculate_fractal
    jmp   still
  nosc3:

    cmp   rbx , 0x10000001
    jne   no_application_terminate_button
    mov   rax , 512
    int   0x60
  no_application_terminate_button:

    cmp   rbx , 0x105                     ; Menu
    jne   no_application_terminate_menu
    mov   rax , 0x200
    int   0x60
  no_application_terminate_menu:

    jmp   still


draw_window:

    mov   rax , 0xC                          ; Beginning of window draw
    mov   rbx , 0x1
    int   0x60

    mov   rax , 0x0                          ; Draw window
    mov   rbx , 125*0x100000000+300          ; x start & size
    mov   rcx ,  40*0x100000000+410          ; y start & size
    mov   rdx , 0x0000000000ffffff           ; type    & border color
    mov   r8  , 0x0000000000000001           ; draw flags
    mov   r9  , window_label                 ; 0 or label - asciiz
    mov   r10 , menu_struct                  ; 0 or pointer to menu struct
    int   0x60

    call  draw_pic

    call  draw_scroll1
    call  draw_scroll2
    call  draw_scroll3

    mov   rax , 12
    mov   rbx , 2
    int   0x60

    ret


draw_scroll1:

    mov   rcx , 1000
    mov   r9  , 335
    mov   r8  , [scroll1]

    jmp   scroll

draw_scroll2:

    mov   rcx , 2000
    mov   r9  , 355
    mov   r8  , [scroll2]

    jmp   scroll

draw_scroll3:

    mov   rcx , 3000
    mov   r9  , 375
    mov   r8  , [scroll3]

    jmp   scroll

scroll:

    mov   rax , 113
    mov   rbx , 2
    mov   rdx , 180
    mov   r10 , 22
    mov   r11 , 235
    int   0x60

    mov   rax , 13
    mov   rbx , 261*0x100000000+3*6
    mov   rcx , r9
    shl   rcx , 32
    add   rcx , 3+10
    mov   rdx , 0xffffff
    int   0x60

    mov   rax , 47
    mov   rbx , 3 * 65536
    mov   rcx , r8
    mov   rdx , 261 * 65536
    add   rdx , r9
    add   rdx , 3
    mov   rsi , 0x000000
    int   0x40

    ret


window_label:

    db    'MANDELBROT FRACTAL',0

scroll1:

    dq    1000 + 6

scroll2:

    dq    2000 + 120

scroll3:

    dq    3000 + 70

fdivc:     dw 64
two:       dw 2
curx:      dw 0
cury:      dw 0
numiter:   dw 255

startx:    dw   0
starty:    dw   0

sx:        dw   0
sy:        dw   0

menu_struct:               ; Menu Struct

    dq   0                 ; Version

    dq   0x100             ; Start value of ID to return ( ID + Line )

                           ; Returned when menu closes and
                           ; user made no selections.

    db   0,'FILE',0        ; ID = 0x100 + 1
    db   1,'New',0         ; ID = 0x100 + 2
    db   1,'Open..',0      ; ID = 0x100 + 3
    db   1,'-',0           ; ID = 0x100 + 4
    db   1,'Quit',0        ; ID = 0x100 + 5

    db   255               ; End of Menu Struct

image_end:

