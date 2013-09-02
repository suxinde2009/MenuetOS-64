;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   64 bit Menuet background generator
;   by V.Turjanmaa
;
;   Cellural Texture Generation by
;   Cesare Castiglia, dixan@spinningkids.org
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use64

    org   0x0

    db    'MENUET64'              ; Header identifier
    dq    0x01                    ; Version
    dq    START                   ; Start of code
    dq    image_end               ; Size of image
    dq    0x200000                ; Memory for app
    dq    0xffff0                 ; Esp
    dq    Param                   ; Prm
    dq    0x00                    ; Icon

START:

    mov   rax , 141
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    call  check_parameters  ; Bootup image

    call  generate_background

    call  draw_window       ; At first, draw the window

still:

    mov   rax , 0xA         ; Wait here for event
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


button_event:

    mov   rax , 0x11
    int   0x60

    ; rax = status
    ; rbx = button id

    cmp   rbx , 1000
    jb    no_scroll
    cmp   rbx , 10000
    ja    no_scroll
    mov   rax , rbx
    mov   rcx , 1000
    xor   rdx , rdx
    div   rcx
    mov   rdx , rax
    dec   rdx
    imul  rdx , 8
    mov   [scroll_values+rdx],rbx
    mov   r14 , rax
    imul  r14 , 1000
    call  draw_scroll
    call  generate_background
    call  draw_preview
    jmp   still
  no_scroll:

    cmp   rbx , 0x10000001
    jne   no_application_terminate_button
    mov   rax , 0x200
    int   0x60
  no_application_terminate_button:

    cmp   rbx , 0x106
    jne   no_application_terminate_menu
    mov   rax , 0x200
    int   0x60
  no_application_terminate_menu:

    cmp   rbx , 10
    jne   no_set_bgr

    call  set_background
    jmp   still

  no_set_bgr:

    jmp   still



scroll_values:

    dq    1000  ; red
    dq    2024  ; green
    dq    3030  ; blue
    dq    4000  ; rows
    dq    5000  ; cols
    dq    6000  ; diff
    dq    7000  ; random

scroll_step equ 34

draw_scroll:

; In : R14 = start of scroll value ( 1000,2000,.. )

    mov   rax , r14
    xor   rdx , rdx
    mov   rbx , 1000
    div   rbx
    dec   rax
    mov   r15 , rax

    mov   rax , 113
    mov   rbx , 2
    mov   rcx , r14
    mov   rdx , 64
    mov   r8  , r15
    imul  r8  , 8
    mov   r8  , [scroll_values+r8]
    mov   r9  , r15
    imul  r9  , scroll_step
    add   r9  , 63
    mov   r10 , 248
    mov   r11 , 200
    int   0x60

    mov   rax , 13
    mov   rbx , 435 * 0x100000000 + 6*2
    mov   rcx , r15
    imul  rcx , scroll_step
    add   rcx , 49
    shl   rcx , 32
    add   rcx , 12
    mov   rdx , 0xffffff
    int   0x60

    mov   rdx , rcx
    shr   rdx , 32
    inc   rdx
    add   rdx , 435*65536

    mov   rax , 47
    mov   rbx , 2 * 65536
    mov   rcx , r15
    imul  rcx , 8
    mov   rcx , [scroll_values+rcx]
    mov   r10 , r15
    imul  r10 , 1000
    sub   rcx , r10
    mov   rsi , 0x000000
    int   0x40

    ret



draw_window:

    mov   rax , 0xC                          ; Beginning of window draw
    mov   rbx , 0x1
    int   0x60

    mov   rax , 0x0                          ; Draw window
    mov   rbx , 0x00000080000001D8           ; x start & size
    mov   rcx , 0x0000004000000130           ; y start & size
    mov   rdx , 0x0000000000FFFFFF           ; type    & border color
    mov   r8  , 0x0000000000000001           ; draw flags
    mov   r9  , window_label                 ; 0 or label - asciiz
    mov   r10 , menu_struct                  ; 0 or pointer to menu struct
    int   0x60

    mov   rax , 0x4                          ; Display text
    mov   rbx , text
    mov   rcx , 250
    mov   rdx , 50
    mov   rsi , 0x0
    mov   r9  , 0x1
    mov   r8  , 0x7

  newline:

    int   0x60

    add   rbx , 0x1F
    add   rdx , scroll_step
    dec   r8
    jnz   newline

    call  draw_preview

    mov   r14 , 1000
  newscroll:
    call  draw_scroll
    add   r14 , 1000
    cmp   r14 , 7000
    jbe   newscroll

    mov   rax , 8
    mov   rdx , 10
    mov   rsi , button_info
  newbutton:
    mov   rbx , [rsi]
    mov   rcx , [rsi+8]
    mov   r8  , 0
    mov   r9  , [rsi+16]
    int   0x60
    add   rsi , 24
    inc   rdx
    cmp   [rsi],dword 0
    jne   newbutton

    mov   rax , 0xC                          ; End of window draw
    mov   rbx , 0x2
    int   0x60

    ret

draw_preview:

    mov   rax , 0
    mov   rbx , 0
  dpl5:
    push  rax rbx

    mov   rcx , [scroll_values+3*8]
    sub   rcx , 3999
    imul  rax , rcx
    xor   rdx , rdx
    mov   rcx , 200
    div   rcx
    mov   r10 , rax

    mov   rax , rbx
    mov   rcx , [scroll_values+4*8]
    sub   rcx , 4999
    imul  rax , rcx
    xor   rdx , rdx
    mov   rcx , 200
    div   rcx

    mov   rcx , [scroll_values+3*8]
    sub   rcx , 3999
    imul  rax , rcx

    add   rax , r10
    imul  rax , 3
    mov   r10 , [image_end+rax]

    pop   rbx rax
    push  rax rbx

    imul  rbx , 200
    add   rbx , rax
    imul  rbx , 3
    mov   [0x80000+rbx],r10

    pop   rbx rax


    inc   rax
    cmp   rax , 199
    jbe   dpl5

    mov   rax , 0

    inc   rbx
    cmp   rbx , 199
    jbe   dpl5

    mov   rax , 7
    mov   rbx , 20 * 0x100000000 + 200
    mov   rcx , 50 * 0x100000000 + 200
    mov   rdx , 0x80000
    mov   r8  , 0
    mov   r9  , 0x1000000
    mov   r10 , 3
    int   0x60

    ret




basic:   dq  0x772222
random:  dq  0x987422

generate_background:

    mov   rax , [scroll_values+6*8]
    mov   [random],rax

    mov   rax , [scroll_values]
    sub   rax , 1000
    mov   rbx , rax
    shr   rbx , 4
    imul  rax , 4
    add   rax , rbx
    mov   [basic+2],al
    mov   rax , [scroll_values+8]
    sub   rax , 2000
    mov   rbx , rax
    shr   rbx , 4
    imul  rax , 4
    add   rax , rbx
    mov   [basic+1],al
    mov   rax , [scroll_values+16]
    sub   rax , 3000
    mov   rbx , rax
    shr   rbx , 4
    imul  rax , 4
    add   rax , rbx
    mov   [basic],al

    mov   rdi , image_end

    mov   r10 , [random]
    add   r10 , 0x873487
    and   r10 , 0x3fffff

    mov   r12 , [scroll_values+8*5]
    sub   r12 , 6000
    mov   r11 , r12
    shl   r12 , 8
    add   r12 , r11
    shl   r12 , 8
    add   r12 , r11

    add   [random],dword 0x874857

  gbl1:

    imul  r10 , 0x327433

    mov   r11 , r10
    and   r11 , r12
    and   r11 , 0xffffff

    mov   rax , [basic]
    add   rax , r11

    mov   [rdi],rax
    add   rdi , 3
    cmp   rdi , image_end+3*256*256
    jb    gbl1

    ret


set_background:

    mov   rax , 15
    mov   rbx , 2
    mov   rcx , image_end
    mov   rdx , 0
    mov   r8  , 256*256*3
    int   0x60

    mov   rax , 15
    mov   rbx , 3
    mov   rcx , [scroll_values+8*3]
    sub   rcx , 3999
    mov   rdx , [scroll_values+8*4]
    sub   rdx , 4999
    int   0x60

    mov   rax , 15
    mov   rbx , 1
    int   0x60

    ret


check_parameters:

   ; Return if no parameter

   cmp  [Param+8], dword '1234'
   jne  cpl1
   ret
 cpl1:

   mov  rax , 112
   mov  rbx , 2
   mov  rcx , string_bgr
   mov  rdx , 100
   mov  r8  , bgrstr
   int  0x60

   ; If background is a file -> start DRAW to set background picture

   cmp  [bgrstr], byte '/'
   jne  cpl7

   mov  rsi , bgrstr
   mov  rdi , dparam+1
   mov  rcx , 90
   cld
   rep  movsb

   mov  rax , 256
   mov  rbx , drawstr
   mov  rcx , dparam
   int  0x60

   mov  rax , 5
   mov  rbx , 10
   int  0x60

   mov  rax , 512
   int  0x60

 cpl7:

    ; Generate [DEFAULT] background

    call generate_texture

    mov  eax,15
    mov  ebx,1
    mov  ecx,256
    mov  edx,256
    int  0x40

    mov  eax,15
    mov  ebx,5
    mov  ecx,image+1
    mov  edx,0
    mov  esi,256*3*256
    int  0x40

    mov  eax,15
    mov  ebx,4
    mov  ecx,2
    int  0x40

    mov  eax,15
    mov  ebx,3
    int  0x40

    mov  rax,512
    int  0x60


ptarray:

    dd   40  , 50
    dd   98  , 50
    dd   666


generate_texture:

; *********************************************
; ******* CELLULAR TEXTURE GENERATION *********
; **** by Cesare Castiglia (dixan/sk/mfx) *****
; ********* dixan@spinningkids.org   **********
; *********************************************
; * the algorythm is kinda simple. the color  *
; * component for every pixel is evaluated    *
; * according to the squared distance from    *
; * the closest point in 'ptarray'.           *
; *********************************************

  mov ecx,0             ; ycounter
  mov edi,256*256*3-3   ; pixel counter

  mov ebp,ptarray

 ylup:

  mov ebx , 0

 xlup:

  push rdi

  mov edi, 0
  mov esi, 512000000           ; abnormous initial value :)

 pixlup:

   push rsi

   mov eax,ebx                 ; evaluate first distance
   sub eax, [ebp+edi]          ; x-x1
   call wrappit
   imul eax
   shr  eax , 3
   mov esi, eax                ; (x-x1)^2
   mov eax, ecx
   add edi,4
   sub eax, [ebp+edi]          ; y-y1
   call wrappit
   imul eax                    ; (y-y1)^2
   shr  eax , 3
   add eax,esi                 ; (x-x1)^2+(y-y1)^2

   pop rsi

   cmp esi,eax
   jb  ok                      ; compare and take the smaller one
   mov esi,eax
  ok:

   add edi,4
   cmp [ebp+edi],dword 666
   jne pixlup

   mov eax,esi                 ; now evaluate color...

   mov edi,24            ; 50 = max shaded distance
   idiv edi

   pop rdi

   mov [image+edi],al

   sub edi,3

  add ebx,1              ; bounce x loop
  cmp ebx,256            ; xsize
  jne xlup

  add ecx,1
  cmp ecx,256            ; ysize
  jne ylup

  ret

wrappit:

  cmp eax,0              ; this makes the texture wrap
  jg noabs

  neg eax

 noabs:

  cmp eax,128
  jb nowrap

  neg eax
  add eax,256

 nowrap:

  ret


; Data area

button_info:

    dq     19 * 0x100000000 + 201
    dq     263* 0x100000000 + 17
    dq     preset1
    dq     0

preset1:

    db     'BACKGROUND',0

window_label:

    db     'BACKGROUND',0

text:

    db    'Red                           ',0
    db    'Green                         ',0
    db    'Blue                          ',0
    db    'Columns                       ',0
    db    'Rows                          ',0
    db    'Differentiate                 ',0
    db    'Random seed                   ',0

menu_struct:               ; Menu Struct

    dq   0                 ; Version
    dq   0x100             ; Start value of ID to return ( ID + Line )
                           ; Returned when menu closes and
                           ; user made no selections.
    db   0,'FILE',0        ; ID = 0x100 + 1
    db   1,'New',0         ; ID = 0x100 + 2
    db   1,'Open..',0      ; ID = 0x100 + 3
    db   1,'Save..',0      ; ID = 0x100 + 4
    db   1,'-',0           ; ID = 0x100 + 5
    db   1,'Quit',0        ; ID = 0x100 + 6
    db   0,'HELP',0        ; ID = 0x100 + 7
    db   1,'Contents..',0  ; ID = 0x100 + 8
    db   1,'About..',0     ; ID = 0x100 + 9
    db   255               ; End of Menu Struct

bgrstr:     times  110 db 0
string_bgr: db     'background',0

drawstr:    db     '/fd/1/draw',0
dparam:     db     'B'
            times  100 db 0

Param:      dq     100
            db     '1234'
            times  110 db ?

image:

image_end:

