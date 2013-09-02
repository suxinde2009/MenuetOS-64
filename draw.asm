;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Draw.asm for Menuet
;
;   (c) V.Turjanmaa & Madis Kalme
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use64

    org   0x0

    db    'MENUET64'              ; Header identifier
    dq    0x01                    ; Version
    dq    START                   ; Start of code
    dq    image_end               ; Size of image
    dq    0xE00000                ; Memory for app
    dq    0x100000-2048           ; Rsp
    dq    PARAM                   ; Prm
    dq    0x00                    ; Icon

; 0x100000 - image
; 0x600000 - tmp copy of the image - Undo image - also IPC
; 0xA00000 - copy/paste selection - save area

; Mosaic stack      - 0x100000-48000-16384
; Contrast stack    - 0x100000-48000-8192
; Resize stack      - 0x100000-48000
; Brightness stack  - 0x100000-32768
; Adjust stack      - 0x100000-16384-8192
; RGB stack         - 0x100000-16384
; Palette stack     - 0x100000-8192
; Main stack        - 0x100000-2048

rex  equ  r8
rfx  equ  r9
rgx  equ  r10
rhx  equ  r11
rix  equ  r12
rjx  equ  r13
rkx  equ  r14
rlx  equ  r15

macro pusha { push  rax rbx rcx rdx rsi rdi rbp }
macro popa  { pop   rbp rdi rsi rdx rcx rbx rax }

START:

    mov   rax , 141
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    ; Uninitialized data

    mov   rdi , data_u_start
    mov   rcx , data_u_end - data_u_start
    mov   rax , 0
    cld
    rep   stosb

    ; Background as parameter

    cmp   [PARAM+08],byte 'B'
    jne   nobackground
    mov   rsi , PARAM+9
    mov   rdi , filename
    mov   rcx , 100
    cld
    rep   movsb
    call  load_picture
    call  set_as_background
    mov   rax , 512
    int   0x60
  nobackground:

    ; Drag n drop area

    mov   rax , 121
    mov   rbx , 1
    mov   rcx , dragndrop
    mov   rdx , 100
    int   0x60

    ; Start application

    call  init_picture

    ; Picture as parameter

    cmp   [PARAM+08],byte 0
    je    nopar
    mov   rsi , PARAM+8
    mov   rdi , filename
    mov   rcx , 100
    cld
    rep   movsb
    call  load_picture
    jmp   still
  nopar:

    call  draw_window       ; At first, draw the window

still:

    mov   rax , 23          ; Wait here for event
    mov   rbx , 1
    int   0x60

    test  rax , 0x1         ; Window redraw
    jnz   window_event
    test  rax , 0x2         ; Keyboard press
    jnz   key_event
    test  rax , 0x4         ; Button press
    jnz   button_event

    ; Brightness ?

    cmp   [brdo],dword 0
    je    nobrdo
    mov   [brightnessrunning],byte 0
    call  area_brightness
    mov   [brdo],dword 0
  nobrdo:

    ; Contrast ?

    cmp   [codo],dword 0
    je    nocodo
    mov   [contrastrunning],byte 0
    call  area_contrast
    mov   [codo],dword 0
  nocodo:

    ; Red/Green/Blue ?

    cmp   [adxnew],dword 0
    je    noadjust2
    mov   [adjustrunning],byte 0
    call  area_adjust
    mov   [adxnew],dword 0
  noadjust2:

    ; Resize or New ?

    cmp   [xnew],dword 0
    je    noredo
    cmp   [newpicture],byte 1
    jne   nonewpicture
    mov   [newpicture],byte 0
    call  init_picture
  nonewpicture:
    call  doresize
  noredo:

    ; Mosaic ?

    cmp   [mosx],dword 0
    je    nomodo
    call  domosaic
  nomodo:

    ; Color palette closed ?

    cmp   [paletterunning],byte 2
    jne   nopaletteclosed
    mov   [paletterunning],byte 0
    mov   [drawall],byte 1
    call  draw_window
  nopaletteclosed:

    ; Check Dragndrop

    cmp   [dragndrop],dword 0
    je    nodnd

    mov   rsi , dragndrop
    mov   rdi , filename
    mov   rcx , 99
    cld
    rep   movsb

    mov   [dragndrop],dword 0

    call  load_picture

  nodnd:

    ; Check Mouse

    mov   rax , 37
    mov   rbx , 2
    int   0x60
    cmp   rax , 0
    je    scsl1

    mov   rax , 37
    mov   rbx , 1
    int   0x60
    mov   rbx , rax
    shr   rax , 32
    and   rbx , 0xffff
    add   rax , 18
    cmp   rax , [image_end+16]
    jb    scsl2
    mov   [scroll_state],byte 1
  scsl2:
    cmp   rax , 38+18
    ja    scsl21
    mov   [scroll_state],byte 1
  scsl21:
    add   rbx , 18
    cmp   rbx , [image_end+24]
    jb    scsl3
    mov   [scroll_state],byte 1
  scsl3:
    cmp   rbx , 38+18
    ja    scsl4
    mov   [scroll_state],byte 1
  scsl4:

    cmp   [scroll_state],byte 0
    jne   still

  scsl1:

    mov   [scroll_state],byte 0

    call  check_mouse

    cmp   [draw_rect],byte 1
    jne   nodrre
    call  draw_select_rectangle_sub
    mov   [draw_rect],byte 0
  nodrre:

    ; IPC ?

    cmp  [ipc_memory+16],byte 0
    je    still

    ;mov   rax , 5
    ;mov   rbx , 20
    ;int   0x40

    mov   rsi , ipc_memory+16
    mov   rdi , filename
    dec   rsi
  newmove2:
    inc   rsi
    mov   al , [rsi]
    cmp   al , 32
    je    newmove2
    mov  [rdi] , al
    inc   rdi
    cmp   al , 0
    jne   newmove2

    mov  [ipc_memory+8] , dword 16
    mov  [ipc_memory+16] , byte 0

    cmp   [parameter],byte 'S'
    jne   nosaveas
    call  save_picture
    mov   rax , 12
    mov   rbx , 1
    int   0x60
    mov   rax , 12
    mov   rbx , 2
    int   0x60
    mov   rax , 12
    mov   rbx , 1
    int   0x60
    mov   rax , 12
    mov   rbx , 2
    int   0x60
    call  draw_window
    jmp   still
  nosaveas:

    call  load_picture

    jmp   still


window_event:

    call  draw_window
    jmp   still

key_event:

    mov   rax , 0x2        ; Read the key and ignore
    int   0x60

    jmp   still


define_fb_ipc:

    ; Define IPC memory

    mov   rax , 60           ; ipc
    mov   rbx , 1            ; define memory area
    mov   rcx , ipc_memory   ; memory area pointer
    mov   rdx , 100          ; size of area
    int   0x60

    ret

resize:

    cmp   [resizerunning],byte 1
    je    no_resize
    mov   rax , 51
    mov   rbx , 1
    mov   rcx , restart
    mov   rdx , 0x100000-48000
    int   0x60
    mov   [resizerunning],byte 1
    jmp   still
  resizerunning: dq 0x0
  no_resize:

    ret


doresize:

    call  save_undo

    mov   r14 , [sizex] ; Old size
    mov   r15 , [sizey]

    mov   r10 , [xnew]  ; New size
    mov   r11 , [ynew]

    mov   [sizex],r10
    mov   [sizey],r11

    mov   r12 , 0
    mov   r13 , 0

  resl1:

    push  r12 r13

    ; Old X

    imul  r12 , r14
    mov   rax , r12
    mov   rbx , r10
    xor   rdx , rdx
    div   rbx
    mov   r12 , rax

    ; Old Y

    imul  r13 , r15
    mov   rax , r13
    mov   rbx , r11
    xor   rdx , rdx
    div   rbx
    mov   r13 , rax

    mov   rax , r13
    imul  rax , r14
    add   rax , r12
    imul  rax , 3

    mov   ebx , [0x600000+rax]

    pop   r13 r12

    mov   rax , r13
    imul  rax , r10
    add   rax , r12
    imul  rax , 3

    mov   [0x100000+rax],ebx

    inc   r12
    cmp   r12 , r10
    jb    resl1

    mov   r12 , 0

    inc   r13
    cmp   r13 , r11
    jb    resl1

    mov   [magnify],byte 0

    mov   [selectx],dword 0
    mov   [selecty],dword 0
    mov   rax , [sizex]
    mov   [selectxe],rax
    mov   rax , [sizey]
    mov   [selectye],rax

    call  save_undo

    mov   rax , 13
    mov   rbx , 38 shl 32
    mov   rcx , 38 shl 32
    add   rbx , [image_end+16]
    add   rcx , [image_end+24]
    sub   rbx , 38+18
    sub   rcx , 38+18
    mov   rdx , 0xffffff
    int   0x60

    mov  [scroll1], dword 1000
    mov  [scroll2], dword 2000

    call  scroll_horizontal
    call  scroll_vertical
    call  draw_size
    mov   [drawall],byte 1
    call  draw_window ; picture

    mov   [xnew],dword 0
    mov   [ynew],dword 0

    ret


reset_selected:

    push  rax rbx rcx rdx r8 r9 r10 r11 r12 r13 r14 r15 rdi rsi rbp

    cmp   [magnify],byte 1
    jne   noreswhite

    cmp   [image_end+16],dword 38+25
    jbe   noreswhite
    cmp   [image_end+24],dword 38+25
    jbe   noreswhite

    mov   rax , 0
    cmp   [selectx],rax
    jne   dorecerase3

    mov   rax , 0
    cmp   [selecty],rax
    jne   dorecerase3

    mov   rax , [sizex]
    cmp   [selectxe],rax
    jne   dorecerase3

    mov   rax , [sizey]
    cmp   [selectye],rax
    jne   dorecerase3

    jmp   norecerase3

  dorecerase3:

    ; Draw white lines - horizontally

    mov   rbx , 38
    mov   rdx , [image_end+16]
    sub   rdx , 19
    mov   rcx , 38
  dowhiteline:
    mov   r8  , rcx
    mov   rax , 38
    mov   r9 , 0xffffff
    int   0x60
    mov   rax , [image_end+24]
    sub   rax , 20
    add   rcx , 8
    cmp   rcx , rax
    jbe   dowhiteline

    ; Draw white lines - vertically

    mov   rcx , 38
    mov   r8  , [image_end+24]
    sub   r8  , 19
    mov   rbx , 38
  dowhiteline2:
    mov   rdx , rbx
    mov   rax , 38
    mov   r9 , 0xffffff
    int   0x60
    mov   rax , [image_end+16]
    sub   rax , 20
    add   rbx , 8
    cmp   rbx , rax
    jbe   dowhiteline2

  norecerase3:

  noreswhite:

    mov   [selectx],dword 0
    mov   [selecty],dword 0
    mov   rax , [sizex]
    mov   [selectxe],rax
    mov   rax , [sizey]
    mov   [selectye],rax

    pop   rbp rsi rdi r15 r14 r13 r12 r11 r10 r9 r8 rdx rcx rbx rax

    ret


draw_selected_color:

    mov   rax , 13
    mov   rbx , 5 shl 32 + 32
    mov   rcx , 166 shl 32 +16
    mov   rdx , 0xd0d0d0 ; e0e0e0
    int   0x60

    mov   rax , 13
    mov   rbx , 13 shl 32 + 17
    mov   rcx , 171 shl 32 +7
    mov   rdx , [selected_color]
    imul  rdx , 4
    mov   rdx , [color+rdx]
    int   0x60

    ret



button_event:

    mov   rax , 0x11
    int   0x60

    ; rax = status
    ; rbx = button id

    cmp   rbx , 100
    jb    no_color
    cmp   rbx , 150
    ja    no_color
    call  save_undo
    sub   rbx , 100
    mov   [selected_color],rbx
    call  draw_selected_color
    jmp   still
  no_color:

    cmp   rbx , 200
    jb    no_thickness
    cmp   rbx , 299
    ja    no_thickness
    call  save_undo
    sub   rbx , 199
    mov   [selected_thickness],rbx
    jmp   still
  no_thickness:

    cmp   rbx , 308
    jne   nomagnify
    cmp   [image_end+16],dword 100
    jb    nomagnify
    cmp   [image_end+24],dword 100
    jb    nomagnify
    inc   dword [magnify]
    and   [magnify],byte 1
    cmp   [magnify],byte 1
    jne   noreset

    mov   [copyx],dword 0
    mov   [copyxe],dword 0
    mov   [copyy],dword 0
    mov   [copyye],dword 0

    mov   [selectx],dword 0
    mov   [selecty],dword 0
    mov   rax , [sizex]
    mov   [selectxe],rax
    mov   rax , [sizey]
    mov   [selectye],rax
  noreset:
    mov   [scroll1],dword 1000
    mov   [scroll2],dword 2000
    call  scroll_vertical
    call  scroll_horizontal
    mov   rax , 13
    mov   rbx , 38 shl 32
    mov   rcx , 38 shl 32
    add   rbx , [image_end+16]
    add   rcx , [image_end+24]
    sub   rbx , 38+18
    sub   rcx , 38+18
    mov   rdx , 0xffffff
    int   0x60
    call  draw_picture
    call  draw_select_rectangle_sub
    jmp   still
  nomagnify:

    cmp   rbx , 300
    jb    no_tool
    cmp   rbx , 399
    ja    no_tool
    call  save_undo
    sub   rbx , 299
    mov   [selected_tool],rbx

    cmp   dword [selected_tool],dword 8
    jne   no_all
    call  reset_selected
    call  draw_picture
  no_all:

    jmp   still

  no_tool:

    cmp   rbx , 1000           ; Vertical scroll values 1000-
    jb    no_vertical_scroll
    cmp   rbx , 1999
    ja    no_vertical_scroll
    push  rbx
    call  reset_selected
    pop   rbx
    mov  [scroll1], rbx
    call  scroll_vertical
    call  draw_picture
    jmp   still
  no_vertical_scroll:

    cmp   rbx , 2000           ; Horizontal scroll values 2000-
    jb    no_horizontal_scroll
    cmp   rbx , 2999
    ja    no_horizontal_scroll
    push  rbx
    call  reset_selected
    pop   rbx
    mov  [scroll2],rbx
    call  scroll_horizontal
    call  reset_selected
    call  draw_picture
    jmp   still
  no_horizontal_scroll:
                                          ; Terminate button
    cmp   rbx , 0x10000001
    jne   no_application_terminate_button
    mov   rax , 512
    int   0x60
  no_application_terminate_button:

    cmp   rbx , 10004
    jne   nosavepicture
    call  save_picture
    jmp   still
  nosavepicture:

    cmp   rbx , 10010                     ; Menu
    jne   no_application_terminate_menu
    mov   rax , 0x200
    int   0x60
  no_application_terminate_menu:

    cmp   rbx , 10012
    jne   no_undo

    mov   rax , [undosizex]
    mov   rbx , [undosizey]
    mov  [sizex],rax
    mov  [sizey],rbx

    mov   rsi , 0x600000
    mov   rdi , 0x100000
    mov   rcx , 0x400000 / 8
    cld
    rep   movsq

    call  reset_selected

    mov   [drawall],byte 1
    call  draw_window
    jmp   still
  no_undo:

    cmp   rbx , 10013
    jne   no_area_copy

    mov   rax , 142
    mov   rbx , 1
    mov   rcx , 2
    mov   rdx , [copyxe]
    sub   rdx , [copyx]
    mov   r8  , [copyye]
    sub   r8  , [copyy]
    mov   r9  , 0
    mov   r10 , [copyy]
    imul  r10 , [sizex]
    add   r10 , [copyx]
    imul  r10 , 3
    add   r10 , 0x100000
    mov   r11 , [copyxe]
    sub   r11 , [copyx]
    imul  r11 , 3
    mov   r14 , 0
  newcp:
    push  rax rbx rcx
    int   0x60
    pop   rcx rbx rax
    add   r9  , [copyxe]
    add   r9  , [copyxe]
    add   r9  , [copyxe]
    sub   r9  , [copyx]
    sub   r9  , [copyx]
    sub   r9  , [copyx]

    add   r10 , [sizex]
    add   r10 , [sizex]
    add   r10 , [sizex]
    add   r14 , 1
    cmp   r14 , [sizey]
    jb    newcp

    jmp   still
  no_area_copy:

    cmp   rbx , 10014
    jne   no_area_paste
    call  area_paste
    jmp   still
  no_area_paste:

    ;
    ; Image
    ;

    cmp   rbx , 10016
    jne   noturnleft
    call  save_undo
    mov   r15 , 0
    call  area_turnleft
    jmp   still
  noturnleft:

    cmp   rbx , 10017
    jne   noturnright
    call  save_undo
    mov   r15 , 1
    call  area_turnright
    jmp   still
  noturnright:

    cmp   rbx , 10018
    jne   nomirror
    call  save_undo
    mov   r15 , 2
    call  area_mirror
    jmp   still
  nomirror:

    cmp   rbx , 10019
    jne   noflip
    call  save_undo
    mov   r15 , 3
    call  area_flip
    jmp   still
  noflip:

    cmp   rbx , 10021
    jne   nopalette
    cmp   [paletterunning],byte 1
    je    nopalette
    mov   [paletterunning],byte 1
    mov   rax , 51
    mov   rbx , 1
    mov   rcx , palettestart
    mov   rdx , 0x100000-8192
    int   0x60
    jmp   still
  paletterunning: dq 0x0
  nopalette:

    cmp   rbx , 10022
    jne   no_21
    cmp   [rgbrunning],byte 1
    je    no_21
    mov   [rgbrunning],byte 1
    mov   rax , 51
    mov   rbx , 1
    mov   rcx , rgbstart
    mov   rdx , 0x100000-16384
    int   0x60
    jmp   still
  rgbrunning: dq 0x0
  no_21:

    ;
    ; Tools
    ;

    cmp   rbx , 10024
    jne   no_soften
    call  save_undo
    call  area_soften
    jmp   still
  no_soften:

    cmp   rbx , 10025
    jne   no_grayscale
    call  save_undo
    call  area_grayscale
    jmp   still
  no_grayscale:

    cmp   rbx , 10026
    jne   no_crop
    call  save_undo
    call  area_crop
    jmp   still
  no_crop:

    cmp   rbx , 10027
    jne   no_mosaic
    cmp   [mosaicrunning],byte 1
    je    no_mosaic
    call  save_undo
    mov   rax , 51
    mov   rbx , 1
    mov   rcx , mostart
    mov   rdx , 0x100000-48000-16384
    int   0x60
    mov   [mosaicrunning],byte 1
    jmp   still
  mosaicrunning: dq 0x0
    jmp   still
  no_mosaic:

    cmp   rbx , 10028
    jne   no_brightness
    cmp   [brightnessrunning],byte 1
    je    no_brightness
    call  save_undo
    mov   rax , 51
    mov   rbx , 1
    mov   rcx , brstart
    mov   rdx , 0x100000-32768
    int   0x60
    mov   [brightnessrunning],byte 1
    jmp   still
  brightnessrunning: dq 0x0
  no_brightness:

    cmp   rbx , 10029
    jne   no_contrast
    cmp   [contrastrunning],byte 1
    je    no_contrast
    call  save_undo
    mov   rax , 51
    mov   rbx , 1
    mov   rcx , costart
    mov   rdx , 0x100000-48000-8192
    int   0x60
    mov   [contrastrunning],byte 1
    jmp   still
  contrastrunning: dq 0x0
  no_contrast:

    cmp   rbx , 10030
    jne   no_rez
    mov   [newpicture],byte 0
    call  resize
    jmp   still
  no_rez:

    cmp   rbx , 10031
    jne   noadjust
    cmp   [adjustrunning],byte 1
    je    noadjust
    mov   [adjustrunning],byte 1
    mov   rax , 51
    mov   rbx , 1
    mov   rcx , adjuststart
    mov   rdx , 0x100000-8192-16384
    int   0x60
    jmp   still
  adjustrunning: dq 0x0
  noadjust:

    ;
    ; File
    ;

    cmp   rbx , 10002
    jne   no_new_picture
    mov   [newpicture],byte 1
    call  resize
    jmp   still
  no_new_picture:

    cmp   rbx , 10003
    jne   no_picture_load
    mov   [parameter],byte '['
    call  dialog_open
    jmp   still
  no_picture_load:

    cmp   rbx , 10005
    jne   nosaveaspicture
    mov   [parameter],byte 'S'
    call  dialog_open
    jmp   still
  nosaveaspicture:

    ; Set as background

    cmp   rbx , 10007
    jne   no_bgr
    call  set_as_background
    jmp   still
  no_bgr:

    ; Print

    cmp   rbx , 10008
    jne   no_print
    mov   rax , 129
    mov   rbx , 5
    mov   rcx , 1
    mov   rdx , [sizex]
    shl   rdx , 32
    add   rdx , [sizey]
    mov   r8  , 0x100000
    int   0x60
    jmp   still
  no_print:


    jmp   still


save_undo:

    push  rax rbx

    mov   rax , [sizex]
    mov   rbx , [sizey]

    mov   [undosizex],rax
    mov   [undosizey],rbx

    pop   rbx rax

    mov   rsi , 0x100000
    mov   rdi , 0x600000
    mov   rcx , 0x400000 / 8
    cld
    rep   movsq

    ret


save_picture:

    cmp   [filename],byte 0
    je    nosave

    ; search for .bmp

    mov   rsi , filename
  checksave:
    cmp   [rsi],byte 0
    je    save_error
    cmp   [rsi],dword '.bmp'
    je    dosave
    cmp   [rsi],dword '.BMP'
    je    dosave
    inc   rsi
    jmp   checksave
  dosave:

    ; Add header

    mov   rdi , 0xa00000
    mov   rsi , bmpheader
    mov   rcx , 54
    cld
    rep   movsb
    mov   eax , [sizex]
    mov   [0xa00000+0x12],eax
    mov   eax , [sizey]
    mov   [0xa00000+0x16],eax

    ; Add picture data

    mov   rdi , 0xa00000 + 54

    mov   rsi , [sizey]
    imul  rsi , [sizex]
    imul  rsi , 3
    and   rsi , 0x3fffff
    add   rsi , 0x100000
    mov   rax , [sizex]
    imul  rax , 3
    mov   rbx , [sizey]
    cmp   rbx , 0
    je    nosave

  newdatamove:

    sub   rsi , rax

    push  rsi
    mov   rcx , [sizex]
    imul  rcx , 3
    push  rcx
    cld
    rep   movsb
    pop   rcx

    ; dword alignment

    and   rcx , 3

    cmp   rcx , 0
    je    nordiadd

    push  rax
    mov   rax , 4
    sub   rax , rcx
    add   rdi , rax
    pop   rax

  nordiadd:

    pop   rsi

    dec   rbx
    jnz   newdatamove

    ; Delete file first

    mov   rax , 58
    mov   rbx , 2
    mov   rcx , 0
    mov   rex , 0
    mov   rfx , filename
    int   0x60

    ; Write the file

    mov   rax , 58
    mov   rbx , 1
    mov   rcx , 0
    mov   rdx , rdi
    sub   rdx , 0xa00000
    mov   rex , 0xa00000
    mov   rfx , filename
    int   0x60

  nosave:

    ret


save_error:

    mov   rax , 13
    mov   rbx , 38 shl 32 + 32 * 6
    mov   rcx , 38 shl 32 + 30
    mov   rdx , 0xf0f0f0
    int   0x60

    mov   rax , 4
    mov   rbx , saveerrormessage
    mov   rcx , 50
    mov   rdx , 50
    mov   rsi , 0x000000
    mov   r9  , 13
    int   0x60

    mov   rax , 5
    mov   rbx , 500
    int   0x60

    call  draw_window

    ret


addmagnify:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Adds magnify to rbx and rcx
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    push  rax

    push  rcx
    mov   rcx , [magnify]
    imul  rcx , 3
    shr   rbx , cl
    pop   rcx

    mov   rax , rcx
    mov   rcx , [magnify]
    imul  rcx , 3
    shr   rax , cl
    mov   rcx , rax

    pop   rax

    ret



check_mouse:

    mov   rax , 37
    mov   rbx , 1
    int   0x60

    mov   rbx , rax
    mov   rcx , rax
    mov   rax , 1
    mov   rdx , [selected_color]
    imul  rdx , 4
    mov   rdx , [color+rdx]
    and   rdx , 0xffffff
    shr   rbx , 32
    and   rcx , 0xffff
    sub   rcx , 39
    sub   rbx , 39

    call  addmagnify

    ; Color under mouse

    mov   [color_under_mouse],dword 0x000000
    mov   r10 , [scroll1]
    sub   r10 , 1000
    add   r10 , rcx
    cmp   r10 , [sizey]
    jae   nocm
    mov   r10 , [scroll2]
    sub   r10 , 2000
    add   r10 , rbx
    cmp   r10 , [sizex]
    jae   nocm

    mov   r10 , rcx
    add   r10 , [scroll1]
    sub   r10 , 1000
    imul  r10 , [sizex]
    add   r10 , rbx
    add   r10 , [scroll2]
    sub   r10 , 2000
    imul  r10 , 3
    and   r10 , 0x3fffff
    add   r10 , 0x100000
    mov   r10 , [r10]
    mov   [color_under_mouse],r10

  nocm:

    ; Window on top ?

    push  rbx rcx rdx
    call  check_window_pos
    pop   rdx rcx rbx
    cmp   [window_on_top],byte 1
    jne   cml10

    ; Event (window draw) -> return

    mov   rax , 11
    int   0x60
    cmp   rax , 0
    jne   cml10

    ; Mouse button pressed ?

    push  rbx
    mov   rax , 37
    mov   rbx , 2
    int   0x60
    pop   rbx
    cmp   rax , 0
    je    cml10

    cmp   rbx , [image_end+16]
    ja    cml10
    cmp   rcx , [image_end+24]
    ja    cml10

    cmp   [selected_tool],dword 7
    je    acceptedxy

    cmp   rbx , [sizex]
    ja    cml10
    cmp   rcx , [sizey]
    ja    cml10

  acceptedxy:

    ; Disable controls

    call  controls_disable

    ;

    cmp   dword [selected_tool],dword 1
    jne   no_pixel_draw

    call  draw_pixel_line
    call  draw_picture

    mov   [draw_rect],byte 1

    jmp   check_mouse

  draw_rect: dq 0x0

  no_pixel_draw:

    cmp   dword [selected_tool],dword 2
    jne   no_line_draw

    call  draw_line
    call  draw_picture
    mov   [draw_rect],byte 1

  no_line_draw:

    cmp   dword [selected_tool],dword 3
    jne   no_rectangle_draw

    call  draw_rectangle
    call  draw_picture
    mov   [draw_rect],byte 1

  no_rectangle_draw:

    cmp   dword [selected_tool],dword 4
    jne   no_circle_tool

    call  draw_circle
    mov   [draw_rect],byte 1

  no_circle_tool:

    cmp   dword [selected_tool],dword 5
    jne   no_ellipse_tool

    call  draw_ellipse
    mov   [draw_rect],byte 1

   no_ellipse_tool:

    cmp   dword [selected_tool],dword 6
    jne   no_fill

    call  draw_fill
    mov   [draw_rect],byte 1

  no_fill:

    cmp   dword [selected_tool],dword 7
    jne   no_select

    call  draw_select

  no_select:

    cmp   dword [selected_tool],dword 10
    jne   no_pick_color

    call  pick_color

  no_pick_color:


    ; Wait for mouse up

  waitformouseup:

    mov   rax , 5
    mov   rbx , 1
    int   0x60
    mov   rax , 37
    mov   rbx , 2
    int   0x60
    cmp   rax , 0
    jne   waitformouseup

    ; Enable controls

    call  controls_enable

    ;

    ret

  cml10:

    mov   [pixmemx],dword 99999

    ; Enable controls

    mov   rax , 37
    mov   rbx , 2
    int   0x60
    cmp   rax , 0
    jne   noenablecontrols

    call  controls_enable

  noenablecontrols:

    ;

    ret



controls_disable:

    push  rax rbx

    cmp   [controls_state],dword 011b
    je    csfine2

    mov   rax , 40
    mov   rbx , 011b
    int   0x60

    mov   [controls_state],dword 011b

  csfine2:

    pop   rbx rax

    ret


controls_enable:

    push  rax rbx

    cmp   [controls_state],dword 111b
    je    csfine

    mov   rax , 40
    mov   rbx , 111b
    int   0x60

    mov   [controls_state],dword 111b

  csfine:

    pop   rbx rax

    ret



set_as_background:

     mov   rax , 15
     mov   rbx , 2
     mov   rcx , 0x100000
     mov   rdx , 0
     mov   r8  , 0x1ff000
     int   0x60

     mov   rax , 15
     mov   rbx , 3
     mov   rcx , [sizex]
     mov   rdx , [sizey]
     int   0x60

     mov   rax , 15
     mov   rbx , 1
     int   0x60

     ret



dialog_open:

    ; Get my PID

    mov   rax , 111
    mov   rbx , 1
    int   0x60

    mov   rdi , parameter + 6
  newdec:
    mov   rbx , 10
    xor   rdx , rdx
    div   rbx
    add   rdx , 48
    mov  [rdi], dl
    dec   rdi
    cmp   rdi , parameter + 1
    jg    newdec

    ; Start fbrowser

    mov   rax , 256
    mov   rbx , file_search
    mov   rcx , parameter
    int   0x60

    call  define_fb_ipc

    ret



load_picture:

    mov   rax , 58
    mov   rbx , 0
    mov   rcx , 0
    mov   rdx , 1
    mov   r8  , 0x100000-1024
    mov   r9  , filename
    int   0x60

    mov   [loaded_file_size],rbx

    ;;Display header
    ;mov   rsi , 0x100000-1024 + 40
    ;mov   r10 , 100
    ;newprint:
    ;movzx rcx , byte [rsi]
    ;mov   rax , 47
    ;mov   rbx , 3*65536
    ;mov   rdx , 100 shl 32
    ;add   rdx , r10
    ;int   0x60
    ;add   r10 , 10
    ;add   rsi , 1
    ;cmp   rsi , 0x100000-1024 + 60
    ;jbe   newprint
    ;mov   rax , 5
    ;mov   rbx , 30000
    ;int   0x60

    cmp   [0x100000-1024],dword 'GIF8'
    jne   no_gif
    mov   r15 , 1 ; gif
    call  decode_external
    jmp   picture_ready
  no_gif:
    cmp   [0x100000-1024], byte 0xff
    jne   no_jpg
    mov   r15 , 2 ; jpg
    call  decode_external
    jmp   picture_ready
  no_jpg:
    cmp   [0x100000-1024+1], word 'PN'
    jne   no_png
    mov   r15 , 3 ; png
    call  decode_external
    jmp   picture_ready
  no_png:
    cmp   [0x100000-1024], word 'BM'
    jne   no_bmp
    mov   r15 , 4 ; bmp
    call  decode_external
    jmp   picture_ready
  no_bmp:

    jmp   typefail

  picture_ready:

    cmp   [PARAM+8],byte 'B'
    je    lpl2

    mov   rax , 12
    mov   rbx , 1
    int   0x60
    mov   rax , 12
    mov   rbx , 2
    int   0x60

    mov   [scroll1],dword 1000
    mov   [scroll2],dword 2000

    mov   [drawall],byte 1
    call  draw_window

    call  save_undo

    ret

  lpl1:

    cmp   [PARAM+8],byte 'B'
    je    lpl2

  typefail:

    mov   rax , 12
    mov   rbx , 1
    int   0x60
    mov   rax , 12
    mov   rbx , 2
    int   0x60

    mov   [sizex],dword 800
    mov   [sizey],dword 600
    call  init_picture
    mov   [scroll1],dword 1000
    mov   [scroll2],dword 2000
    mov   [drawall],byte 1
    call  draw_window

    mov   rax , 4
    mov   rbx , loadfail
    mov   rcx , 50
    mov   rdx , 50
    mov   r9  , 1
    mov   rsi , 0x000000
    int   0x60

  lpl2:

    ret


putpixel:

    push  rax rbx rcx rdx

    mov   rdx , rcx
    mov   rcx , rbx
    mov   rbx , rax

    call  draw_pixel

    pop   rdx rcx rbx rax

    ret


draw_line_complete:

; In: rax = x start
;     rbx = y start
;     rcx = x end
;     rdx = y end
;     rsi = color

    cmp   rbx , rdx
    jne   no_horizontal_line

    cmp   rax , rcx
    jbe   horizontal_line_l1
    xchg  rax , rcx
    xchg  rbx , rdx
  horizontal_line_l1:

    add   rcx , 1

  new_vertical_line_pixel:

    mov   rdi , rcx
    mov   rcx , rsi
    call  putpixel
    mov   rcx , rdi

    add   rax , 1
    cmp   rax , rcx
    jb    new_vertical_line_pixel

    jmp   exit_line_draw

  no_horizontal_line:

    cmp   rax , rcx
    jne   no_vertical_line

    cmp   rbx , rdx
    jbe   vertical_line_l1
    xchg  rbx , rdx
    xchg  rax , rcx
  vertical_line_l1:

    add   rdx , 1

  new_horizontal_line_pixel:

    mov   rdi , rcx
    mov   rcx , rsi
    call  putpixel
    mov   rcx , rdi

    add   rbx , 1
    cmp   rbx , rdx
    jb    new_horizontal_line_pixel

    jmp   exit_line_draw

  no_vertical_line:

    ; another line

    ; Longer draw in X or Y ?

    ; Swap from up to down and left to right

    push  rax rbx rcx rdx

    cmp   rax , rcx
    jbe   sdll30
    xchg  rax , rcx
  sdll30:
    cmp   rbx , rdx
    jbe   sdll31
    xchg  rbx , rdx
  sdll31:
    mov   rex , rcx
    sub   rex , rax
    mov   rfx , rdx
    sub   rfx , rbx

    pop   rdx rcx rbx rax

    cmp   rfx , rex
    jg    no_another_line_x

    cmp   rax , rcx
    jbe   sdll32
    xchg  rax , rcx
    xchg  rbx , rdx
  sdll32:

    push  rax

    mov   rhx , rcx   ; Line length
    sub   rhx , rax

    shl   rbx , 32    ; Add decimals
    shl   rdx , 32

    cmp   rdx , rbx
    jb    sdll11

    sub   rdx , rbx   ; y add            down line '\'
    mov   rax , rdx
    xor   rdx , rdx   ; y add / x length
    div   rhx
    mov   rex , rax   ; add to y coord.
    mov   rix , 0     ; add mark
    jmp   sdll12

  sdll11:

    mov   rax , rbx   ; y add - negative - up line '/'
    sub   rax , rdx
    xor   rdx , rdx   ; y add / x length
    div   rhx
    mov   rex , rax   ; add to y coord.
    mov   rix , 1     ; sub mark

  sdll12:

    pop   rax
    shl   rax , 32
    mov   rjx , 0x80000000

    inc   rhx

  newanother:

    push  rax
    push  rbx
    add   rax , rjx
    add   rbx , rjx
    shr   rax , 32
    shr   rbx , 32
    mov   rcx , rsi
    call  putpixel
    pop   rbx
    pop   rax

    mov   rfx , 0x100000000
    add   rax , rfx

    ; y repos

    cmp   rix , 0
    jne   sdll13
    add   rbx , rex
    jmp   sdll14
  sdll13:
    sub   rbx , rex
  sdll14:

    dec   rhx
    jnz   newanother

    jmp   exit_line_draw

  no_another_line_x:

    ;

    cmp   rbx , rdx
    jbe   sdll33
    xchg  rbx , rdx
    xchg  rax , rcx
  sdll33:

    push  rax rbx

    mov   rhx , rdx   ; Line length
    sub   rhx , rbx

    shl   rax , 32    ; Add decimals
    shl   rcx , 32

    cmp   rcx , rax
    jb    sdll211

    sub   rcx , rax   ; y add            down line '\'
    mov   rax , rcx
    xor   rdx , rdx   ; y add / x length
    div   rhx
    mov   rex , rax   ; add to y coord.
    mov   rix , 0     ; add mark
    jmp   sdll212

  sdll211:

    ;                     y add - negative - up line '/'
    sub   rax , rcx
    xor   rdx , rdx   ; y add / x length
    div   rhx
    mov   rex , rax   ; add to y coord.
    mov   rix , 1     ; sub mark

  sdll212:

    pop   rbx rax
    shl   rax , 32
    shl   rbx , 32
    mov   rjx , 0x80000000

    inc   rhx

  newanother2:

    push  rax
    push  rbx
    add   rax , rjx
    add   rbx , rjx
    shr   rax , 32
    shr   rbx , 32
    mov   rcx , rsi
    call  putpixel
    pop   rbx
    pop   rax

    mov   rfx , 0x100000000
    add   rbx , rfx

    ; x repos

    cmp   rix , 0
    jne   sdll213
    add   rax , rex
    jmp   sdll214
  sdll213:
    sub   rax , rex
  sdll214:

    dec   rhx
    jnz   newanother2

    jmp   exit_line_draw

  no_another_line_y:

  exit_line_draw:

    ret


area_turnright:
area_mirror:
area_flip:
area_turnleft:

    mov   rsi , 0x600000

    mov   rcx , [sizey]

    mov   r9  , 0

  newturnleft:

    push  rcx rsi

    mov   r8  , 0

    mov   rcx , [sizex]

  newxturnleft:

    mov   eax , [rsi]

    cmp   r15 , 0
    jne   nof0
    mov   r10 , [sizex]
    dec   r10
    sub   r10 , r8
    mov   rdi , r10
    imul  rdi , 3
    imul  rdi , [sizey]
    mov   r10 , r9
    add   rdi , r10
    add   rdi , r10
    add   rdi , r10
    add   rdi , 0x100000
  nof0:

    cmp   r15 , 1
    jne   nof1
    mov   r10 , r8
    mov   rdi , r10
    imul  rdi , 3
    imul  rdi , [sizey]
    mov   r10 , [sizey]
    dec   r10
    sub   r10 , r9
    add   rdi , r10
    add   rdi , r10
    add   rdi , r10
    add   rdi , 0x100000
  nof1:

    cmp   r15 , 2
    jne   nof2
    mov   r10 , [sizex]
    dec   r10
    sub   r10 , r8
    imul  r10 , 3
    mov   rdi , r10
    mov   r10 , r9
    imul  r10 , 3
    imul  r10 , [sizex]
    add   rdi , r10
    add   rdi , 0x100000
  nof2:

    cmp   r15 , 3
    jne   nof3
    mov   r10 , [sizey]
    dec   r10
    sub   r10 , r9
    imul  r10 , 3
    imul  r10 , [sizex]
    mov   rdi , r10
    ;
    mov   r10 , r8
    imul  r10 , 3
    add   rdi , r10
    add   rdi , 0x100000
  nof3:

    mov   [rdi],ax
    shr   eax , 16
    mov   [rdi+2],al

    add   r8  , 1

    add   rsi , 3
    dec   rcx
    jnz   newxturnleft

    mov   r8 , 0

    pop   rsi rcx

    add   rsi , [sizex]
    add   rsi , [sizex]
    add   rsi , [sizex]

    add   r9  , 1

    dec   rcx
    jnz   newturnleft

    cmp   r15 , 2
    jae   noflipchange
    push  qword [sizey] qword [sizex]
    pop   qword [sizey] qword [sizex]
  noflipchange:

    mov   [selectx],dword 0
    mov   [selecty],dword 0
    mov   rax , [sizex]
    mov   [selectxe],rax
    mov   rax , [sizey]
    mov   [selectye],rax

    mov   rax , 13
    mov   rbx , 38 shl 32
    mov   rcx , 38 shl 32
    add   rbx , [image_end+16]
    add   rcx , [image_end+24]
    sub   rbx , 38+18
    sub   rcx , 38+18
    mov   rdx , 0xffffff
    int   0x60

    call  draw_picture
    call  draw_size
    call  draw_select_rectangle_sub

    call  scroll_horizontal
    call  scroll_vertical

    ret




area_grayscale:

    mov   rdi , [selecty]
    imul  rdi , [sizex]
    add   rdi , [selectx]
    imul  rdi , 3
    add   rdi , 0x100000

    mov   rcx , [selectye]
    sub   rcx , [selecty]

  newgrayscale:

    push  rcx rdi

    mov   rcx , [selectxe]
    sub   rcx , [selectx]

  newxgray:

    movzx rax , byte [rdi]
    movzx rbx , byte [rdi+1]
    add   rax , rbx
    movzx rbx , byte [rdi+2]
    add   rax , rbx

    xor   rdx , rdx
    mov   rbx , 3
    div   rbx

    mov   [rdi],al
    mov   [rdi+1],al
    mov   [rdi+2],al

    add   rdi , 3
    loop  newxgray

    pop   rdi rcx

    add   rdi , [sizex]
    add   rdi , [sizex]
    add   rdi , [sizex]

    loop  newgrayscale

    call  draw_picture
    call  draw_select_rectangle_sub

    ret


area_crop:

    mov   rbx , [selecty]

    mov   rdi , 0x100000

  cropl1:

    mov   rcx , [selectxe]
    sub   rcx , [selectx]
    imul  rcx , 3

    mov   rsi , rbx
    imul  rsi , [sizex]
    add   rsi , [selectx]
    imul  rsi , 3
    add   rsi , 0x100000

    cld
    rep   movsb

    add   rbx , 1
    cmp   rbx , [selectye]
    jbe   cropl1

    mov   rax , [selectxe]
    sub   rax , [selectx]
    mov   [sizex],rax

    mov   rbx , [selectye]
    sub   rbx , [selecty]
    mov   [sizey],rbx

    call  reset_selected
    mov   [drawall],byte 1
    call  draw_window

    ret



mosx: dq 0
mosy: dq 0



domosaic:

    call  save_undo

    mov   rdi , [selecty]
    imul  rdi , [sizex]
    add   rdi , [selectx]
    imul  rdi , 3
    add   rdi , 0x100000

    mov   rbx , [sizex]
    add   rbx , [sizex]
    add   rbx , [sizex]

    mov   rax , [selectye]
    sub   rax , [selecty]
    xor   rdx , rdx
    mov   r8  , [mosy]
    div   r8
    mov   rcx , rax
    inc   rcx

    mov   r14 , [selectx] ; x
    mov   r15 , [selecty] ; y

  newmosaic:

    push  rcx rdi

    mov   rax , [selectxe]
    sub   rax , [selectx]
    xor   rdx , rdx
    mov   r8  , [mosx]
    div   r8
    mov   rcx , rax
    inc   rcx

  newxmosaic:

    push  rcx

    add   rdi , rbx
    add   rdi , rbx
    add   rdi , rbx
    mov   rax , [rdi]
    sub   rdi , rbx
    sub   rdi , rbx
    sub   rdi , rbx
    mov   rcx , rax

    mov   r9  , rdi
    mov   r10 , [mosy]

    ;
    ; XY block
    ;

    push  r15

  newspix:

    push  r14

    push  r9
    push  r10
    mov   r10 , [mosx]
  newmypix:
    call  setpix
    add   r9  , 3
    add   r14 , 1
    dec   r10
    jnz   newmypix
    pop   r10
    pop   r9

    pop   r14

    add   r15 , 1

    add   r9  , rbx
    dec   r10
    jnz   newspix

    pop   r15

    pop   rcx

    add   r14 , [mosx]

    add   rdi , [mosx]
    add   rdi , [mosx]
    add   rdi , [mosx]

    dec   rcx
    cmp   rcx , 1
    jae   newxmosaic

    pop   rdi rcx

    push  rbx
    imul  rbx , [mosy]
    add   rdi , rbx
    pop   rbx

    mov   r14 , [selectx]
    add   r15 , [mosy]

    dec   rcx
    cmp   rcx , 1
    jae   newmosaic

    mov   rax , 0
    mov   [mosx],rax
    mov   [mosy],rax

    call  draw_picture
    call  draw_select_rectangle_sub

    ret


setpix:

    cmp   r14 , [selectxe]
    jae   nosetpix
    cmp   r15 , [selectye]
    jae   nosetpix

    push  rax
    mov   [r9],ax
    shr   rax , 16
    mov   [r9+2],al
    pop   rax

  nosetpix:

    ret






area_soften:

    mov   rdi , [selecty]
    imul  rdi , [sizex]
    add   rdi , [selectx]
    imul  rdi , 3
    add   rdi , 0x100000

    mov   rcx , [selectye]
    sub   rcx , [selecty]

    mov   r10 , 1000b

  newsoften:

    push  rcx rdi

    mov   rcx , [selectxe]
    sub   rcx , [selectx]

    or    r10 , 0100b ; no left

  newxsoften:

    xor   rax , rax
    call  getmedium
    add   rax , rbx
    inc   rdi
    call  getmedium
    shl   rax , 8
    add   rax , rbx
    inc   rdi
    call  getmedium
    shl   rax , 8
    add   rax , rbx
    sub   rdi , 2
    mov   [rdi+2],al
    shr   rax , 8
    mov   [rdi+1],al
    shr   rax , 8
    mov   [rdi+0],al

    and   r10 , 1011b

    cmp   rcx , 2
    jne   nosetr
    or    r10 , 0010b ; no right
  nosetr:

    add   rdi , 3
    loop  newxsoften

    pop   rdi rcx

    add   rdi , [sizex]
    add   rdi , [sizex]
    add   rdi , [sizex]

    mov   r10 , 0000b
    cmp   rcx , 2
    jne   nosetb
    or    r10 , 0001b
  nosetb:

    dec   rcx
    jnz   newsoften

    call  draw_picture
    call  draw_select_rectangle_sub

    ret


getmedium:
; In : rdi
; Out: rbx = medium

    push  rax rcx rdx rsi rdi

    mov   r11 , 0

    mov   rax , [sizex]
    imul  rax , 3

    xor   rbx , rbx
    movzx rcx , byte [rdi]
    add   rbx , rcx
    inc   r11

    test  r10 , 0010b
    jnz   noright
    movzx rcx , byte [rdi+3]
    add   rbx , rcx
    inc   r11
  noright:

    test  r10 , 0100b
    jnz   noleft
    movzx rcx , byte [rdi-3]
    add   rbx , rcx
    inc   r11
  noleft:

    test  r10 , 0001b
    jnz   nobottom
    push  rdi
    add   rdi , rax
    movzx rcx , byte [rdi]
    add   rbx , rcx
    pop   rdi
    inc   r11
  nobottom:

    test  r10 , 1000b
    jnz   notop
    sub   rdi , rax
    movzx rcx , byte [rdi]
    add   rbx , rcx
    inc   r11
  notop:

    mov   rax , rbx
    xor   rdx , rdx
    mov   rbx , r11
    div   rbx
    mov   rbx , rax

    pop   rdi rsi rdx rcx rax

    ret



area_brightness:

    mov   rdi , [selecty]
    imul  rdi , [sizex]
    add   rdi , [selectx]
    imul  rdi , 3
    add   rdi , 0x100000

    sub   dword [brdo],dword 1

    mov   rcx , [selectye]
    sub   rcx , [selecty]

  newbrightness:

    push  rcx rdi

    mov   rcx , [selectxe]
    sub   rcx , [selectx]
    imul  rcx , 3

  newxbright:

    movzx rax , byte [rdi]

    imul  rax , [brdo]
    mov   rbx , 100
    xor   rdx , rdx
    div   rbx
    cmp   rax , 255
    jbe   raxfine
    mov   rax , 255
  raxfine:

    mov   [rdi],al

    add   rdi , 1
    loop  newxbright

    pop   rdi rcx

    add   rdi , [sizex]
    add   rdi , [sizex]
    add   rdi , [sizex]

    loop  newbrightness

    mov   [drawall],byte 1
    call  draw_window

    ret


area_contrast:

    mov   rdi , [selecty]
    imul  rdi , [sizex]
    add   rdi , [selectx]
    imul  rdi , 3
    add   rdi , 0x100000

    sub   dword [codo],dword 1

    mov   rcx , [selectye]
    sub   rcx , [selecty]

  newcontrast:

    push  rcx rdi

    mov   rcx , [selectxe]
    sub   rcx , [selectx]
    imul  rcx , 3

  newxcontrast:

    movzx rax , byte [rdi]

    imul  rax , [codo]
    xor   rdx , rdx
    mov   rbx , 100
    div   rbx

    cmp   [codo],dword 100
    ja    codo100

    mov   rbx , 100
    sub   rbx , [codo]
    imul  rbx , (128*1024)/100 ; 0-100 -> 0-128
    shr   rbx , 10
    add   rax , rbx

    jmp   setcontrast

  codo100:

    mov   rbx , [codo]
    sub   rbx , 100
    imul  rbx , (128*1024)/100 ; 0-100 -> 0-128
    shr   rbx , 10
    cmp   rax , rbx
    cmovb rax , rbx
    sub   rax , rbx

  setcontrast:

    mov   rbx , 255
    cmp   rax , rbx
    cmova rax , rbx

    mov   [rdi],al

    add   rdi , 1
    loop  newxcontrast

    pop   rdi rcx

    add   rdi , [sizex]
    add   rdi , [sizex]
    add   rdi , [sizex]

    dec   rcx
    jnz   newcontrast

    mov   [drawall],byte 1
    call  draw_window

    ret




area_adjust:

    mov   rdi , [selecty]
    imul  rdi , [sizex]
    add   rdi , [selectx]
    imul  rdi , 3
    add   rdi , 0x100000

    mov   rcx , [selectye]
    sub   rcx , [selecty]

  anewbrightness:

    push  rcx rdi

    mov   rcx , [selectxe]
    sub   rcx , [selectx]

  anewxbright:

    ; Red

    movzx rax , byte [rdi]
    imul  rax , [adznew]
    mov   rbx , 100
    xor   rdx , rdx
    div   rbx
    cmp   rax , 255
    jbe   arazfine
    mov   rax , 255
  arazfine:
    mov   [rdi],al

    ; Green

    inc   rdi

    movzx rax , byte [rdi]
    imul  rax , [adynew]
    mov   rbx , 100
    xor   rdx , rdx
    div   rbx
    cmp   rax , 255
    jbe   arayfine
    mov   rax , 255
  arayfine:
    mov   [rdi],al

    ; Red

    inc   rdi

    movzx rax , byte [rdi]
    imul  rax , [adxnew]
    mov   rbx , 100
    xor   rdx , rdx
    div   rbx
    cmp   rax , 255
    jbe   araxfine
    mov   rax , 255
  araxfine:
    mov   [rdi],al

    add   rdi , 1

    dec   rcx
    jnz   anewxbright

    pop   rdi rcx

    add   rdi , [sizex]
    add   rdi , [sizex]
    add   rdi , [sizex]

    dec   rcx
    jnz   anewbrightness

    mov   [drawall],byte 1
    call  draw_window

    ret



area_paste:

    call reset_selected

    mov  rsi , 0x100000
    mov  rdi , 0x600000
    mov  rcx , 0x400000 / 8
    cld
    rep  movsq

    mov   rax , 142
    mov   rbx , 2
    mov   rcx , 0
    mov   rdx , 0x100000
    mov   r8  , 0
    mov   r9  , 0
    int   0x60

    cmp   rax , 2
    jne   pasteret
    cmp   rbx , 0
    je    pasteret
    cmp   rcx , 0
    je    pasteret
    jmp   contpaste
  pasteret:
    ret
  contpaste:

    mov   [copyy],dword 0
    mov   [copyx],dword 0
    mov   [copyxe],rbx
    mov   [copyye],rcx

    mov   rcx , 0
    mov   rdx , 0xA00000
    mov   r8  , [copyxe]
    imul  r8  , 3
    mov   r9  , 0
  newcline:
    mov   rax , 142
    mov   rbx , 2
    push  rcx
    int   0x60
    pop   rcx
    add   rdx , [sizex]
    add   rdx , [sizex]
    add   rdx , [sizex]
    add   rcx , [copyxe]
    add   rcx , [copyxe]
    add   rcx , [copyxe]
    add   r9  , 1
    cmp   r9  , [copyye]
    jb    newcline

    mov   [pasteloop],dword 0

  apl1:

    mov  rax , 5
    mov  rbx , 1
    int  0x60

    mov  rax , 37
    mov  rbx , 1
    int  0x60

    mov  rcx , rax
    mov  rbx , rax
    and  rcx , 0xffff
    shr  rbx , 32

    mov  r15 , [copyxe]
    sub  r15 , [copyx]
    add  r15 , rbx
    add  r15 , 13
    cmp  r15 , [image_end+16]
    ja   apl21
    mov  r15 , [copyye]
    sub  r15 , [copyy]
    add  r15 , rcx
    add  r15 , 13
    cmp  r15 , [image_end+24]
    ja   apl21

    cmp  rbx , 38+4
    jb   apl21
    cmp  rcx , 38+5
    jb   apl21

    sub   rbx , 5
    sub   rcx , 5

    mov   rsi , 0x600000
    mov   rdi , 0x100000
    mov   rcx , 0x400000 / 8
    cld
    rep   movsq

    mov   rax , 37
    mov   rbx , 1
    int   0x60

  pastestart:

    inc   dword [pasteloop]

    mov   rbx , rax
    shr   rax , 32
    and   rbx , 0xffff
    sub   rax , 38
    sub   rbx , 38
    cmp   [magnify],byte 1
    jne   nopastemagn
    shr   rax , 3
    shr   rbx , 3
  nopastemagn:
    mov   r15 , [copyxe]
    sub   r15 , [copyx]
    shr   r15 , 1
    sub   rax , 5
    mov   r15 , [copyye]
    sub   r15 , [copyy]
    shr   r15 , 1
    sub   rbx , 5
    add   rax , [scroll2]
    sub   rax , 2000
    add   rbx , [scroll1]
    sub   rbx , 1000

    imul  rbx , [sizex]
    add   rax , rbx
    imul  rax , 3
    add   rax , 0x100000
    mov   rdi , rax

    mov   rax , [copyx]
    mov   rbx , [copyy]
    imul  rbx , [sizex]
    add   rax , rbx
    imul  rax , 3
    add   rax , 0xA00000
    mov   rsi , rax

    mov   rcx , [copyye]
    sub   rcx , [copyy]

  newlinemove:

    push  rsi
    push  rdi
    push  rcx
    mov   rcx , [copyxe]
    sub   rcx , [copyx]
    imul  rcx , 3
    cld
    rep   movsb
    pop   rcx
    pop   rdi
    pop   rsi

    add   rsi , [sizex]
    add   rsi , [sizex]
    add   rsi , [sizex]
    add   rdi , [sizex]
    add   rdi , [sizex]
    add   rdi , [sizex]

    loop  newlinemove

    ; If image is too big to be moved -> exit

    cmp   [pasteloop],dword 2
    jne   apl212
    call  draw_picture
    jmp   apl4
  apl212:

    ;

  apl21:

    ; Image was too big to be moved within the window -> paste to 0,0

    inc   dword [pasteloop]
    mov   rax , 43 shl 32 + 43
    cmp   [pasteloop],dword 1
    je    pastestart

    call  draw_picture

    mov   rax , 37
    mov   rbx , 2
    int   0x60

    cmp   rax , 0
    je    apl1

  apl4:
    mov   rax , 5
    mov   rbx , 1
    int   0x60
    mov   rax , 37
    mov   rbx , 2
    int   0x60
    cmp   rax , 0
    jne   apl4

    call  draw_select_rectangle_sub

    ret


draw_fill:

    add   rbx , [scroll2]
    add   rcx , [scroll1]
    sub   rbx , 2000
    sub   rcx , 1000

    mov   r8  , 0

    mov   rdi , 0x500000
    mov   r13 , rdx

    mov   [rdi],rbx
    mov   [rdi+8],rcx
    add   rdi , 16

    mov   rax , rcx
    imul  rax , [sizex]
    add   rax , rbx
    imul  rax , 3
    add   rax , 0x100000
    mov   r14 , [rax]
    and   r14 , 0xffffff

    ; Pick next

  newfill:

    mov   r11 , [0x500000]
    mov   r12 , [0x500008]

    mov   rax , [0x500008]
    imul  rax , [sizex]
    add   rax , [0x500000]
    imul  rax , 3
    add   rax , 0x100000
    push  r13
    mov   [rax],r13w
    shr   r13 , 16
    mov   [rax+2],r13b
    pop   r13
    sub   rdi , 16
    push  rdi
    mov   rcx , rdi
    mov   rdi , 0x500000
    mov   rsi , 0x500000+16
    sub   rcx , 0x500000
    add   rcx , 100
    shr   rcx , 3
    inc   rcx
    cld
    rep   movsq
    pop   rdi

    inc   r8
    cmp   r8 ,  5000
    jb    nofd
    mov   r8 , 0
    call  draw_picture
  nofd:

    ; Add  Pixels

    inc   r11
    call  checkfilladdxp
    sub   r11 , 2
    call  checkfilladdxn
    inc   r11
    dec   r12
    call  checkfilladd
    add   r12 , 2
    call  checkfilladd

    cmp   rdi , 0x500000
    jbe   filldone

    jmp   newfill


  filldone:

    call  draw_picture

    ret


checkfilladdxp:

    push  r11

  xpl1:

    mov   rax , r12
    imul  rax , [sizex]
    add   rax , r11
    imul  rax , 3
    add   rax , 0x100000

    mov   rbx , [rax]
    and   rbx , 0xffffff

    cmp   rbx , r14
    jne   xpn

    push  r13
    mov   [rax],r13w
    shr   r13 , 16
    mov   [rax+2],r13b
    pop   r13

    ; Check below

    mov   rax , r12
    inc   rax
    cmp   rax , [sizey]
    ja    xpn2

    imul  rax , [sizex]
    add   rax , r11
    imul  rax , 3
    add   rax , 0x100000

    mov   rbx , [rax]
    and   rbx , 0xffffff
    cmp   rbx , r14
    jne   xpn2

    mov   rbx , [rax-3]
    and   rbx , 0xffffff
    cmp   rbx , r14
    je    xpn2

    inc   r12

    mov   [rdi],r11
    mov   [rdi+8],r12
    add   rdi , 16

    dec   r12

  xpn2:

    ; Check above

    mov   rax , r12
    cmp   rax , 0
    je    xpn3

    dec   rax
    imul  rax , [sizex]
    add   rax , r11
    imul  rax , 3
    add   rax , 0x100000

    mov   rbx, [rax]
    and   rbx , 0xffffff
    cmp   rbx , r14
    jne   xpn3

    mov   rbx , [rax-3]
    and   rbx , 0xffffff
    cmp   rbx , r14
    je    xpn3

    dec   r12
    mov   [rdi],r11
    mov   [rdi+8],r12
    add   rdi , 16
    inc   r12

  xpn3:

    inc   r11
    cmp   r11 , [sizex]
    jb    xpl1

  xpn:

    pop   r11

    ret


checkfilladdxn:

    push  r11

  xnl1:

    mov   rax , r12
    imul  rax , [sizex]
    add   rax , r11
    imul  rax , 3
    add   rax , 0x100000

    mov   rbx , [rax]
    and   rbx , 0xffffff

    cmp   rbx , r14
    jne   xnn

    push  r13
    mov   [rax],r13w
    shr   r13 , 16
    mov   [rax+2],r13b
    pop   r13

    ; Check below

    mov   rax , r12
    inc   rax
    cmp   rax , [sizey]
    ja    xnn2

    imul  rax , [sizex]
    add   rax , r11
    imul  rax , 3
    add   rax , 0x100000

    mov   rbx , [rax]
    and   rbx , 0xffffff
    cmp   rbx , r14
    jne   xnn2

    mov   rbx , [rax+3]
    and   rbx , 0xffffff
    cmp   rbx , r14
    je    xnn2

    inc   r12

    mov   [rdi],r11
    mov   [rdi+8],r12
    add   rdi , 16

    dec   r12

  xnn2:

    ; Check above

    mov   rax , r12
    cmp   rax , 0
    je    xnn3

    dec   rax
    imul  rax , [sizex]
    add   rax , r11
    imul  rax , 3
    add   rax , 0x100000

    mov   rbx, [rax]
    and   rbx , 0xffffff
    cmp   rbx , r14
    jne   xnn3

    mov   rbx , [rax+3]
    and   rbx , 0xffffff
    cmp   rbx , r14
    je    xnn3

    dec   r12
    mov   [rdi],r11
    mov   [rdi+8],r12
    add   rdi , 16
    inc   r12

  xnn3:

    mov   r15 , r11
    dec   r11
    cmp   r15 , 0
    ja    xnl1

  xnn:

    pop   r11

    ret



checkfilladd:

    cmp   r11 , [sizex]
    jae   nofilladd
    cmp   r12 , [sizey]
    jae   nofilladd

    mov   rax , r12
    imul  rax , [sizex]
    add   rax , r11
    imul  rax , 3
    add   rax , 0x100000

    mov   rbx , [rax]
    and   rbx , 0xffffff

    cmp   rbx , r14
    jne   nofilladd
    cmp   rbx , r13
    je    nofilladd

    mov   rsi , 0x500000

  newdoublecheck:

    cmp   r11 , [rsi]
    jne   ndcl1
    cmp   r12 , [rsi+8]
    jne   ndcl1
    jmp   nofilladd

  ndcl1:

    add   rsi , 16
    cmp   rsi , rdi
    jb    newdoublecheck

    mov   [rdi],r11
    mov   [rdi+8],r12
    add   rdi , 16

  nofilladd:

    ret


pick_color:

    add   rbx , [scroll2]
    sub   rbx , 2000
    add   rcx , [scroll1]
    sub   rcx , 1000

    imul  rcx , [sizex]
    add   rcx , rbx
    imul  rcx , 3
    add   rcx , 0x100000

    cmp   rcx , 0x100000
    jb    pixout2
    cmp   rcx , 0x600000
    jae   pixout2

    mov   rcx , [rcx]
    and   rcx , 0xffffff

    mov   [selected_color],dword 8
    mov   [color+8*4],ecx

  pixout2:

    call  draw_selected_color
    call  draw_window_buttons

    mov   rax , 5
    mov   rbx , 2
    int   0x60

    ret



draw_select:

    push  rax rbx rcx rdx
    call  reset_selected
    pop   rdx rcx rbx rax

    mov   r11 , rbx
    mov   r12 , rcx

    cmp   r11 , [sizex]
    cmova r11 , [sizex]
    cmp   r12 , [sizey]
    cmova r12 , [sizey]

    mov   [selectx],r11
    mov   [selecty],r12
    mov   [selectxe],r11
    mov   [selectye],r12
    mov   [rectangle_color],dword 0xb8b0b0
    call  draw_select_rectangle_lines

    mov   rsi , 0x100000
    mov   rdi , 0x600000
    mov   rcx , 0x400000 / 8
    cld
    rep   movsq

  sel1:

    mov   rax , 5
    mov   rbx , 2
    int   0x60

    mov   rax , 37
    mov   rbx , 1
    int   0x60

    mov   rbx , rax
    shr   rax , 32
    and   rbx , 0xffff

    cmp   rax , 10000
    ja    sel5d1
    cmp   rax , 38
    jae   sel5f1
  sel5d1:
    mov   rax , 38
  sel5f1:
    cmp   rbx , 10000
    ja    sel5d2
    cmp   rbx , 38
    jae   sel5f2
  sel5d2:
    mov   rbx , 38
  sel5f2:
    mov   r15 , [image_end+16]
    sub   r15 , 19
    cmp   rax , r15
    jbe   sel5f3
    mov   rax , r15
  sel5f3:
    mov   r15 , [image_end+24]
    sub   r15 , 19
    cmp   rbx , r15
    jbe   sel5f4
    mov   rbx , r15
  sel5f4:

    sub   rax , 38
    sub   rbx , 38

    cmp   [magnify],byte 1
    jne   nodivsel
    shr   rax , 3
    shr   rbx , 3
  nodivsel:

    add   rax , [scroll2]
    sub   rax , 2000
    add   rbx , [scroll1]
    sub   rbx , 1000
    cmp   rax , [sizex]
    jbe   sel5done1
    mov   rax , [sizex]
  sel5done1:
    cmp   rbx , [sizey]
    jbe   sel5done2
    mov   rbx , [sizey]
  sel5done2:
    sub   rax , [scroll2]
    add   rax , 2000
    sub   rbx , [scroll1]
    add   rbx , 1000

    cmp   rax , [selectxe]
    jne   sel3
    cmp   rbx , [selectye]
    jne   sel3
    jmp   sel4

  sel3:

    push  rax rbx
    mov   rax , [sizex]
    cmp   [selectxe],rax
    jne   yeserase
    mov   rbx , [sizey]
    cmp   [selectye],rbx
    jne   yeserase
    jmp   norecerase
  yeserase:
    mov   [rectangle_color],dword 0xffffff
    call  draw_select_rectangle_lines
  norecerase:
    pop   rbx rax

    mov   [selectxe],rax
    mov   [selectye],rbx

    mov   [rectangle_color],dword 0xb8b0b0
    call  draw_select_rectangle_lines

    push  qword [sizex] qword [sizey]

    mov   rax , [selectxe]
    mov   rbx , [selectx]
    cmp   rax , rbx
    cmovb rax , [selectx]
    cmovb rbx , [selectxe]
    sub   rax , rbx
    mov   [sizex],rax

    mov   rax , [selectye]
    mov   rbx , [selecty]
    cmp   rax , rbx
    cmovb rax , [selecty]
    cmovb rbx , [selectye]
    sub   rax , rbx
    mov   [sizey],rax

    call  draw_size

    pop   qword [sizey] qword [sizex]

  sel4:

    mov   rax , 37
    mov   rbx , 2
    int   0x60

    cmp   rax , 0
    jne   sel1

  sel5:

    mov   rax , [selectx]
    add   rax , [scroll2]
    sub   rax , 2000
    mov   rbx , [selecty]
    add   rbx , [scroll1]
    sub   rbx , 1000
    mov   rcx , [selectxe]
    add   rcx , [scroll2]
    sub   rcx , 2000
    mov   rdx , [selectye]
    add   rdx , [scroll1]
    sub   rdx , 1000

    cmp   rax , rcx
    jbe   xsfine
    xchg  rax , rcx
  xsfine:
    cmp   rbx , rdx
    jbe   ysfine
    xchg  rbx , rdx
  ysfine:

    cmp    rax , rcx
    je     resetsel
    cmp    rbx , rdx
    je     resetsel
    jmp    rsizefine
  resetsel:
    call   reset_selected
    jmp    restore_controls
  rsizefine:

    mov   [selectx],rax
    mov   [selecty],rbx
    mov   [selectxe],rcx
    mov   [selectye],rdx

    mov   [copyx],rax
    mov   [copyy],rbx
    mov   [copyxe],rcx
    mov   [copyye],rdx

  restore_controls:

    ; Restore size

    call  draw_size

    ret



draw_pixel_line:

    ;

    mov   rsi , rdx

    mov   rdx , rcx
    mov   rcx , rbx

    mov   rax , rcx
    mov   rbx , rdx

    cmp   [pixmemx],dword 99999
    je    nostartdef
    mov   rax , [pixmemx]
    mov   rbx , [pixmemy]
  nostartdef:

    mov   [pixmemx],rcx
    mov   [pixmemy],rdx

    call  draw_line_complete

    ret



draw_pixel:

; rbx rcx = coordinates : rdx = color

    push  rax rbx rcx rdx

    add   rbx , [scroll2]
    sub   rbx , 2000
    add   rcx , [scroll1]
    sub   rcx , 1000

    imul  rcx , [sizex]
    add   rcx , rbx
    imul  rcx , 3
    add   rcx , 0x100000

    mov   rax , [selected_thickness]
  newpix:
    push  rcx
    push  rdx
    mov   rbx , [selected_thickness]
  newpixv:
    push  rdx
    cmp   rcx , 0x100000
    jb    pixout
    cmp   rcx , 0x600000
    jae   pixout
    mov   [rcx],dx
    shr   rdx , 16
    mov   [rcx+2],dl
  pixout:
    pop   rdx
    sub   rcx , 3
    dec   rbx
    jnz   newpixv
    pop   rdx
    pop   rcx
    sub   rcx , [sizex]
    sub   rcx , [sizex]
    sub   rcx , [sizex]
    dec   rax
    jnz   newpix

    pop   rdx rcx rbx rax

    ret


draw_line:

    mov   r11 , rbx
    mov   r12 , rcx
    mov   r13 , rdx

    push  rcx rdi rsi

    mov   rsi , 0x100000
    mov   rdi , 0x600000
    mov   rcx , 0x400000 / 8
    cld
    rep   movsq

    pop   rsi rdi rcx

  dll1:

    mov   rax , 5
    mov   rbx , 1
    int   0x60

    mov   rax , 37
    mov   rbx , 1
    int   0x60
    mov   rbx , rax
    shr   rax , 32
    and   rbx , 0xffff
    dec   rax
    dec   rbx

    mov   r8  , [image_end+16]
    mov   r9  , [image_end+24]
    sub   r8  , 20
    sub   r9  , 20
    cmp   rax , r8
    ja    nopre
    cmp   rbx , r9
    ja    nopre
    cmp   rax , 42
    jb    nopre
    cmp   rbx , 42
    jb    nopre

    mov   rcx , r11
    mov   rdx , r12
    sub   rax , 38
    sub   rbx , 38

    push  rcx
    mov   rcx , rbx
    mov   rbx , rax
    call  addmagnify
    mov   rax , rbx
    mov   rbx , rcx
    pop   rcx

    mov   rsi , r13

    cmp   rbx , r14
    jne   dopre
    cmp   rcx , r15
    jne   dopre
    jmp   nopre
  dopre:

    push  rcx rsi
    mov   rsi , 0x600000
    mov   rdi , 0x100000
    mov   rcx , 0x400000 / 8
    cld
    rep   movsq
    pop   rsi rcx

    push  r11 r12 r13 r14 r15
    call  draw_line_complete
    pop   r15 r14 r13 r12 r11

    call  draw_picture

  nopre:

    mov   r14 , rbx
    mov   r15 , rcx

    mov   rax , 37
    mov   rbx , 2
    int   0x60
    cmp   rax , 0
    jne   dll1

    call  draw_select_rectangle_sub

    ret


circlepix:

   pusha

   cmp   [onscreen],1
   jne   noonscreen
   int   0x40

   popa
   ret

 noonscreen:

   call  draw_pixel

   popa

   ret



drawcircle:

       mov    [u],3
       mov    [d],5
       mov    ecx,1      ;h=1-r => ecx
       sub    ecx,[r]    ;x= 0  => eax
       mov    ebx,[r]    ;y= r  => ebx
       sub    [d],ebx
       sub    [d],ebx
       mov    [oy],ebx
       and    eax,0
       mov    [ox],eax
       mov    esi,[x]
       mov    edi,[y]
       mov    edx,[c]
   startcircle:
       cmp    eax,ebx
       ja     enddraw
       pusha
       mov    eax,1
       mov    ebx,esi
       mov    ecx,edi
       mov    esi,[ox]
       mov    edi,[oy]
       sub    ebx,esi
       sub    ecx,edi
       call   circlepix
       lea    ebx,[ebx+2*esi]
       call   circlepix
       lea    ecx,[ecx+2*edi]
       call   circlepix
       sub    ebx,esi
       sub    ebx,esi
       call   circlepix
       add    ebx,esi
       sub    ebx,edi
       sub    ecx,edi
       sub    ecx,esi
       call   circlepix
       lea    ebx,[ebx+2*edi]
       call   circlepix
       lea    ecx,[ecx+2*esi]
       call   circlepix
       sub    ebx,edi
       sub    ebx,edi
       call   circlepix
       popa
       cmp    ecx,80000000h
       jc     selectd
       inc    eax
       inc    [ox]
       add    ecx,[u]
       add    [u],2
       add    [d],2
       jmp    startcircle
   selectd:
       inc    eax
       inc    [ox]
       dec    ebx
       dec    [oy]
       add    ecx,[d]
       add    [u],2
       add    [d],4
       jmp    startcircle
   enddraw:
       ret



drawellipse:

       ;s=a�*(1-2b)+2b�
       mov ecx,1
       mov eax,[b]
       mov [y],eax             ;y=b
       lea edx,[2*eax]
       sub ecx,edx             ;(1-2b)
       mul eax                 ;b�
       mov [b2],eax
       mov eax,[a]
       mul eax                 ;a�
       mov [a2],eax
       mov [x],0               ;x=0
       mul ecx                 ;a�*(1-2b)
       add eax,[b2]            ;+2b�
       add eax,[b2]
       mov [s],eax             ;s <= a�*(1-2b)+2b�
       ;t=b�-2a�*(2b-1)
       neg ecx                 ;(2b-1)
       mov eax,[a2]
       add eax,eax             ;2a�
       mul ecx                 ;*(2b-1)
       sub eax,[b2]            ;-b�
       neg eax                 ;-(a-b) == b-a
       mov [t],eax             ;t=b�-2a�*(2b-1)
       shl [a2],1              ;2a�
       shl [b2],1              ;2b�

       mov eax,1
       mov ebx,[xc]
       add ebx,[x]
       mov ecx,[yc]
       add ecx,[y]
       mov edx,[c]
       call circlepix
       sub ebx,[x]
       sub ebx,[x]
       call circlepix
       sub ecx,[y]
       sub ecx,[y]
       call circlepix
       add ebx,[x]
       add ebx,[x]
       call circlepix
   ellipse:
       cmp [s],80000000h
       jc  positives
       mov eax,[x]
       lea eax,[2*eax+3]
       mul [b2]
       add [s],eax     ;s=s+b�*(2x+3)

       sub eax,[b2]
       add [t],eax     ;t=t+2b�*(x+1)
       inc [x]
       jmp startellipse
   positives:
       cmp [t],80000000h
       jc  positivet
       mov eax,[x]             ;s=s+b2*(2*x+3)-2*a2*(y-1)
       lea eax,[2*eax+3]       ;(2x+3)
       mul [b2]                ;*b�
       add [s],eax             ;s+b�*(2x+3)

       sub eax,[b2]            ;+2b�*(x+1)
       add [t],eax

       mov eax,[y]
       lea eax,[2*eax-2]       ;2*(y-1)
       mul [a2]                ;*a�
       sub [s],eax

       sub eax,[a2]            ;t=t+2*b2*(x+1)-a2*(2*y-3)
       sub [t],eax

       inc [x]
       dec [y]
       jmp startellipse
   positivet:
       mov eax,[y]
       lea eax,[eax*2-2]
       mul [a2]
       sub [s],eax             ;s=s-2*a2*(y-1)
       sub eax,[a2]
       sub [t],eax             ;t=t-a2*(2*y-3)
       dec [y]
   startellipse:
       mov eax,1
       mov ebx,[xc]
       add ebx,[x]
       mov ecx,[yc]
       add ecx,[y]
       mov edx,[c]
       call circlepix
       sub ebx,[x]
       sub ebx,[x]
       call circlepix
       sub ecx,[y]
       sub ecx,[y]
       call circlepix
       add ebx,[x]
       add ebx,[x]
       call  circlepix

       cmp [y],0
       jne ellipse

       ret



draw_circle:

    mov   [x] , ebx
    mov   [y] , ecx
    mov   [c] , edx

    mov   r11 , rbx

    mov   rsi , 0x100000
    mov   rdi , 0x600000
    mov   rcx , 0x400000 / 8
    cld
    rep   movsq

  drcl1:

    mov   rax , 5
    mov   rbx , 1
    int   0x60

    mov   rax , 37
    mov   rbx , 1
    int   0x60
    mov   rbx , rax
    shr   rax , 32
    and   rbx , 0xffff
    sub   rax , 39
    sub   rbx , 39

    push  rcx
    mov   rcx , rbx
    mov   rbx , rax
    call  addmagnify
    mov   rax , rbx
    mov   rbx , rcx
    pop   rcx

    push  r11

    cmp   rax , r11
    ja    sizefine
    xchg  rax , r11
  sizefine:

    sub   eax , r11d
    mov   [r],eax

    pop   r11

    mov   eax , [x]
    cmp   eax , [r]
    jbe   circleout
    mov   eax , [y]
    cmp   eax , [r]
    jbe   circleout

    mov   rsi , 0x600000
    mov   rdi , 0x100000
    mov   rcx , 0x400000 / 8
    cld
    rep   movsq

    cmp   [r],2
    jb    nocircle

    call  drawcircle

  nocircle:

    call  draw_picture

    mov   rax , 37
    mov   rbx , 2
    int   0x60

    cmp   rax , 0
    jne   drcl1

  circleout:

    ret


draw_ellipse:

    mov   [xc] , ebx
    mov   [yc] , ecx
    mov   [c]  , edx

    mov   r11 , rbx
    mov   r12 , rcx

    mov   rsi , 0x100000
    mov   rdi , 0x600000
    mov   rcx , 0x400000 / 8
    cld
    rep   movsq

  drel1:

    mov   rax , 5
    mov   rbx , 1
    int   0x60

    mov   rax , 37
    mov   rbx , 1
    int   0x60
    mov   rbx , rax
    shr   rax , 32
    and   rbx , 0xffff
    sub   rax , 38
    sub   rbx , 38

    push  rcx
    mov   rcx , rbx
    mov   rbx , rax
    call  addmagnify
    mov   rax , rbx
    mov   rbx , rcx
    pop   rcx

    push  r11
    push  r12

    cmp   rax , r11
    ja    esizefine
    xchg  rax , r11
  esizefine:

    cmp   rbx , r12
    ja    esizefine2
    xchg  rbx , r12
  esizefine2:

    sub   eax , r11d
    mov   [a],eax
    sub   ebx , r12d
    mov   [b],ebx

    pop   r12
    pop   r11

    mov   eax , [xc]
    cmp   eax , [a]
    jbe   ellipseout
    mov   eax , [yc]
    cmp   eax , [b]
    jbe   ellipseout

    mov   rsi , 0x600000
    mov   rdi , 0x100000
    mov   rcx , 0x400000 / 8
    cld
    rep   movsq

    cmp   [a],3
    jb    noellipse
    cmp   [b],3
    jb    noellipse

    call  drawellipse

  noellipse:

    call  draw_picture

    mov   rax , 37
    mov   rbx , 2
    int   0x60

    cmp   rax , 0
    jne   drel1

  ellipseout:

    ret



draw_rectangle:

    mov   r11 , rbx
    mov   r12 , rcx
    mov   r13 , rdx

    mov   rdi , 0x600000
    mov   rsi , 0x100000
    mov   rcx , 0x400000 / 8
    cld
    rep   movsq

  drl1:

    mov   rax , 5
    mov   rbx , 1
    int   0x60

    mov   rax , 37
    mov   rbx , 1
    int   0x60
    mov   rbx , rax
    shr   rax , 32
    and   rbx , 0xffff
    dec   rax
    dec   rbx
    mov   rcx , rbx
    mov   rbx , rax
    mov   rax , 38
    mov   rdx , r11
    mov   r8  , r12
    add   rdx , 38
    add   r8  , 38
    mov   r9  , r13

    push  rbx rcx
    push  r11 r12

    cmp   rbx , r14
    jne   dopr
    cmp   rcx , r15
    jne   dopr
    jmp   nopr
  dopr:

    mov   rax , 37
    mov   rbx , 1
    int   0x60

    mov   rbx , rax
    mov   rcx , rax
    shr   rbx , 32
    and   rcx , 0xffff

    mov   r8  , [image_end+16]
    mov   r9  , [image_end+24]
    sub   r8  , 20
    sub   r9  , 20
    cmp   rbx , r8
    ja    nopr
    cmp   rcx , r9
    ja    nopr
    cmp   rbx , 42
    jb    nopr
    cmp   rcx , 42
    jb    nopr

    sub   rbx , 39
    sub   rcx , 39
    call  addmagnify
    mov   rdx , r13

    cmp   rbx , r11
    ja    xorderfine
    xchg  rbx , r11
  xorderfine:
    cmp   rcx , r12
    ja    yorderfine
    xchg  rcx , r12
  yorderfine:

    push  rsi rcx

    mov   rsi , 0x600000
    mov   rdi , 0x100000
    mov   rcx , 0x400000 / 8
    cld
    rep   movsq

    pop   rcx rsi

    push  rcx

  newyr:
    push  rbx
    call  draw_pixel
    mov   rbx , r11
    call  draw_pixel
    pop   rbx
    dec   rcx
    cmp   rcx , r12
    ja    newyr

    pop   rcx

  newxr:
    push  rcx
    call  draw_pixel
    mov   rcx , r12
    call  draw_pixel
    pop   rcx
    dec   rbx
    cmp   rbx , r11
    jae   newxr

    call  draw_picture

  nopr:

    pop   r12 r11
    pop   rcx rbx

    mov   r14 , rbx
    mov   r15 , rcx

    mov   rax , 37
    mov   rbx , 2
    int   0x60

    cmp   rax , 0
    jne   drl1

    call  draw_select_rectangle_sub

    ret


init_picture:

    mov   rdi , 0x100000
    mov   rax , 0xffffffffffffffff
    mov   rcx , 1280*1024*3 / 8
    cld
    rep   stosq

    call  save_undo

    ret


check_window_pos:

    mov   rax , 111
    mov   rbx , 1
    int   0x60
    mov   r15 , rax

    mov   [window_on_top],byte 1
    mov   rax , 26
    mov   rbx , 1
    mov   rcx , image_end
    mov   rdx , 1024
    int   0x60
    mov   r10 , [image_end+15*8]
    mov   rax , 26
    mov   rbx , 2
    mov   rcx , image_end
    mov   rdx , 1024
    int   0x60
    imul  r10 , 8
    cmp   [image_end+r10],r15
    je    wot
    mov   [window_on_top],byte 0
  wot:

    mov   rcx , r15
    mov   rax , 9
    mov   rbx , 2
    mov   rdx , image_end
    mov   r8  , 256
    int   0x60

    ; If window has a new size, reset scroll positions & selected area

    mov   rax , [image_end+16]
    imul  rax , 2000
    add   rax , [image_end+24]
    cmp   rax , [oldsize]
    je    noscrollreset
    mov   [scroll1],dword 1000
    mov   [scroll2],dword 2000

    push  rax
    mov   [selectx],dword 0
    mov   [selecty],dword 0
    mov   rax , [sizex]
    mov   [selectxe],rax
    mov   rax , [sizey]
    mov   [selectye],rax
    pop   rax

  noscrollreset:
    mov   [oldsize],rax

    ret


window_color equ 0xffffff

draw_window_buttons:

    ; Define button

    mov   rax , 8
    mov   rbx ,  5  * 0x100000000 + 16
    mov   rcx ,  38 * 0x100000000 + 16
    mov   rdx , 100
    mov   r8  , 0
    bts   r8  , 62
    mov   r9  , 0 ; on_text
    mov   r15 , color
  newbutton:

    int   0x60

    push  rax rbx rcx rdx
    mov   rax , 13
    ;cmp   rdx , 108
    ;jne   no_pick_color2
    ;push  rbx rcx
    ;mov   r10 , 1*0x100000000-2
    ;add   rbx , r10
    ;add   rcx , r10
    ;mov   rdx , 0xc0c0c0 ; a0a0a0
    ;int   0x60
    ;pop   rcx rbx
    ;no_pick_color2:
    mov   r10 , 5*0x100000000-10
    add   rbx , r10
    add   rcx , r10
    mov   rdx , [r15]
    int   0x60
    add   r15 , 4
    pop   rdx rcx rbx rax
    mov   r10 , 16*0x100000000
    add   rcx , r10
    inc   rdx
    cmp   rdx , 108
    jne   nocolc
    mov   rbx , 21*0x100000000 + 16
    mov   rcx , 38*0x100000000 + 16
  nocolc:
    cmp   rdx , 116
    jb    newbutton

    ret


draw_window_tools:

    mov   rax , 8
    mov   rbx , 5 * 0x100000000 + 32
    mov   rcx ,(166+16) * 0x100000000 + 16
    mov   rdx , 200
    mov   r8  , 0
    bts   r8  , 62
    mov   r9  , 0
    mov   r10 , 16*0x100000000
  newlinew:
    mov   rax , 8
    int   0x60
    push  rax rbx rcx rdx r8 r9
    mov   r14 , rdx
    sub   r14 , 199
    mov   rax , 38
    mov   rbx , 10
    mov   rdx , 31
    shr   rcx , 32
    push  r14
    shr   r14 , 1
    dec   r14
    sub   rcx , r14
    pop   r14
    add   rcx , 7
    mov   r8  , rcx
    mov   r9  , 0x000000
  newthickline:
    int   0x60
    inc   rcx
    inc   r8
    dec   r14
    jnz   newthickline
    pop   r9 r8 rdx rcx rbx rax
    inc   rdx
    add   rcx ,r10
    cmp   rdx , 204
    jb    newlinew

    mov   rax , 8
    mov   rbx , 5*0x100000000+32
    mov   rcx , (230+16)*0x100000000+16
    mov   rdx , 300
    mov   r8  , 0
    bts   r8  , 62
    mov   r9  , 0
    mov   r10 , 16*0x100000000
    int   0x60
    add   rcx , r10
    inc   rdx
    int   0x60
    add   rcx , r10
    inc   rdx
    int   0x60
    add   rcx , r10
    inc   rcx
    inc   rdx
    int   0x60
    add   rcx , r10
    mov   r11 , 0x100000000
    add   rcx , r11
    inc   rdx
    int   0x60
    add   rcx , r10
    add   rcx , r11
    inc   rdx
    int   0x60
    add   rcx , r10
    add   rcx , r11
    inc   rdx
    int   0x60
    add   rcx , r10
    add   rcx , r11
    inc   rdx
    int   0x60
    add   rcx , r10
    add   rcx , r11
    inc   rdx
    int   0x60
    add   rcx , r10
    add   rcx , r11
    inc   rdx
    int   0x60

    mov   rax , 38
    mov   rbx , 20
    mov   rcx , 237+16
    mov   rdx , 21
    mov   r8  , rcx
    mov   r9  , 0xffffff
    int   0x60
    inc   rcx
    inc   r8
    int   0x60
    add   rcx , 20
    add   r8  , 12
    mov   rbx , 12
    mov   rdx , 29
    int   0x60
    add   r8  , 16
    mov   rcx , r8
    int   0x60
    add   rcx , 7
    add   r8  , 7
    int   0x60
    mov   rdx , rbx
    sub   rcx , 7
    int   0x60
    add   rbx , 18
    add   rdx , 18
    int   0x60

    mov   [onscreen],1
    mov   [x],21
    mov   [y],286+16
    mov   [r],5
    mov   [c],0xffffff
    call  drawcircle
    mov   [xc],21
    mov   [yc],303+16
    mov   [a],10
    mov   [b],5
    call  drawellipse
    mov   [onscreen],0

    mov   rax , 4
    mov   rbx , fill
    mov   rcx , 10
    mov   rdx , 317+16
    mov   rfx , 1
    mov   rsi , 0xffffff
    int   0x60
    mov   rax , 4
    mov   rbx , sel
    mov   rcx , 10
    mov   rdx , 334+16
    mov   rfx , 1
    mov   rsi , 0xffffff
    int   0x60
    mov   rax , 4
    mov   rbx , all
    mov   rcx , 13
    mov   rdx , 351+16
    mov   rfx , 1
    mov   rsi , 0xffffff
    int   0x60
    mov   rax , 4
    mov   rbx , onetoone
    mov   rcx , 13
    mov   rdx , 368+16
    mov   rfx , 1
    mov   rsi , 0xffffff
    int   0x60
    mov   rax , 4
    mov   rbx , pick
    mov   rcx , 10
    mov   rdx , 368+32+1
    mov   rfx , 1
    mov   rsi , 0xffffff
    int   0x60

    ret



draw_window:

    mov   rax , 12
    mov   rbx , 1
    int   0x60

    mov   rax , 0
    mov   rbx ,  80 * 0x100000000 + 520 +1 + 40
    mov   rcx ,  60 * 0x100000000 + 420 +5 + 35
    mov   rdx , window_color
    mov   r8  , 1
    mov   r9  , window_label
    mov   r10 , menu_struct
    int   0x60

    call  check_window_pos
    call  draw_window_buttons
    call  draw_selected_color
    call  draw_window_tools

    call  scroll_vertical
    call  scroll_horizontal
    call  draw_picture

    call  draw_size

    call  draw_select_rectangle_sub

    mov   rax , 12
    mov   rbx , 3
    int   0x60

    cmp   [drawall],byte 0
    je    noredrawcheck
    cmp   eax , 2000
    ja    noredrawcheck
    ; Window was drawn only partially, new try
    mov   rax , 5
    mov   rbx , 1
    int   0x60
    jmp   draw_window
  noredrawcheck:
    mov   [drawall],byte 0

    ret

draw_select_rectangle_sub:

    push  qword [selectx] qword [selecty] qword [selectxe] qword [selectye]

    mov   rax , [selectx]
    sub   rax , [scroll2]
    add   rax , 2000
    mov   [selectx],rax
    mov   rbx , [selecty]
    sub   rbx , [scroll1]
    add   rbx , 1000
    mov   [selecty],rbx
    mov   rcx , [selectxe]
    sub   rcx , [scroll2]
    add   rcx , 2000
    mov   [selectxe],rcx
    mov   rdx , [selectye]
    sub   rdx , [scroll1]
    add   rdx , 1000
    mov   [selectye],rdx

    cmp   [selectx],dword 10000
    ja    nodrse
    cmp   [selecty],dword 10000
    ja    nodrse
    cmp   [selectxe],dword 10000
    ja    nodrse
    cmp   [selectye],dword 10000
    ja    nodrse

    call  draw_select_rectangle_lines

  nodrse:

    pop   qword [selectye] qword [selectxe] qword [selecty] qword [selectx]

    ret


draw_select_rectangle_lines:

    cmp    [selectx],dword 0
    jne    drse
    cmp    [selecty],dword 0
    jne    drse
    mov    rax , [sizex]
    cmp    [selectxe],rax
    jne    drse
    mov    rax , [sizey]
    cmp    [selectye],rax
    jne    drse
    ret
  drse:

    call   draw_picture

    cmp   [magnify],byte 1
    je    dorectmagn

    mov    rax , 38
    mov    rbx , [selectx]
    add    rbx , 38
    mov    rcx , [selecty]
    add    rcx , 38
    mov    rdx , rbx
    mov    r8  , [selectye]
    add    r8  , 38
    inc    dword [select_color]
    and    byte  [select_color],byte 1
    mov    r9  , [select_color]
    dec    r9
    and    r9  , 0x3f3f3f
    mov    r9  , [rectangle_color] ; 0xb8b0b0
    int    0x60

    mov    rbx , [selectxe]
    add    rbx , 38
    mov    rdx , rbx
    int    0x60

    mov    r8  , rcx
    mov    rbx , [selectx]
    add    rbx , 38
    int    0x60

    mov    rcx , [selectye]
    add    rcx , 38
    mov    r8  , rcx
    int    0x60

    ret

  dorectmagn:

    mov    rax , 38
    mov    rbx , [selectx]
    shl    rbx , 3
    add    rbx , 38
    mov    rcx , [selecty]
    shl    rcx , 3
    add    rcx , 38
    mov    rdx , rbx
    mov    r8  , [selectye]
    shl    r8  , 3
    add    r8  , 38
    inc    dword [select_color]
    and    byte  [select_color],byte 1
    mov    r9  , [select_color]
    dec    r9
    and    r9  , 0x3f3f3f
    mov    r9  , 0xb8b0b0
    mov    r9  , [rectangle_color]
    int    0x60

    mov    rbx , [selectxe]
    shl    rbx , 3
    add    rbx , 38
    mov    rdx , rbx
    int    0x60

    mov    r8  , rcx
    mov    rbx , [selectx]
    shl    rbx , 3
    add    rbx , 38
    int    0x60

    mov    rcx , [selectye]
    shl    rcx , 3
    add    rcx , 38
    mov    r8  , rcx
    int    0x60

    ret



draw_size:

    mov   r15 , [image_end+24]
    sub   r15 , 45

    cmp   [image_end+24],dword 395+32
    jb    nosize

    mov   r15 , 388+32

    mov   rax , 13
    mov   rbx , 6*0x100000000 + 31
    mov   rcx , 381+32
    shl   rcx , 32
    add   rcx , [image_end+24]
    sub   rcx , 386+32
    mov   rdx , 0xe0e0e0 ; window_color
    int   0x60

    mov   rax , 47
    mov   rbx , 4*65536
    mov   rcx , [sizex]
    mov   rdx , 09*65536+000
    add   rdx , r15
    mov   rsi , 0x000000
    int   0x40
    mov   rcx , [sizey]
    mov   rdx , 09*65536+000
    add   rdx , r15
    add   rdx , 10
    push  rax rbx
    mov   rax , 141
    mov   rbx , 3
    int   0x60 ; bug - diff between 10 and 11 ??
    and   rax , 0xff
    sub   rax , 9
    add   rdx , rax
    pop   rbx rax
    int   0x40

    ;mov   rcx , [selectx]
    ;mov   dx  , 330
    ;int   0x40
    ;mov   rcx , [selecty]
    ;mov   dx  , 340
    ;int   0x40
    ;mov   rcx , [selectxe]
    ;mov   dx  , 350
    ;int   0x40
    ;mov   rcx , [selectye]
    ;mov   dx  , 360
    ;int   0x40

  nosize:

    ret

draw_picture:

    push  rax rbx rcx rdx r8 r9 r10 r11 r12 r13 r14 r15

    ; Lines at the tool sides

    mov   rax , 38
    mov   rbx , 37
    mov   rcx , 38
    mov   rdx , 37
    mov   r8  , 400
    mov   r8  , [image_end+24]
    sub   r8  , 6
    mov   r9  , 0x000000
    int   0x60
    mov   rbx , 5
    mov   rdx , 5
    mov   r9  , 0xf8f8f8
    int   0x60

    cmp   [magnify],byte 0
    je    draw1to1

    mov   rax , [scroll1]
    sub   rax , 1000
    imul  rax , 3
    imul  rax , [sizex]
    mov   rsi , 0x100000
    add   rsi , rax
    mov   rax , [scroll2]
    sub   rax , 2000
    imul  rax , 3
    add   rsi , rax

    mov   r10 , 0
    mov   r11 , 0

  newblock:

    mov   rax , 13
    mov   rbx , r10
    imul  rbx , 8
    add   rbx , 39
    add   rbx , 26
    cmp   rbx , [image_end+16]
    ja    done60
    sub   rbx , 26
    mov   rcx , r11
    imul  rcx , 8
    add   rcx , 39
    add   rcx , 26
    cmp   rcx , [image_end+24]
    ja    done60
    sub   rcx , 26
    shl   rbx , 32
    shl   rcx , 32
    add   rbx , 7
    add   rcx , 7

    mov   rdx , [rsi]
    and   rdx , 0xffffff

    mov   r12 , r11
    add   r12 , [scroll1]
    sub   r12 , 1000
    cmp   r12 , [sizey]
    jae   noint60
    mov   r12 , r10
    add   r12 , [scroll2]
    sub   r12 , 2000
    cmp   r12 , [sizex]
    jae   noint60
    int   0x60
    jmp   done60
  noint60:
    mov   rdx , window_color
    int   0x60
  done60:

    add   rsi , 3

    inc   r10
    cmp   r10 , 100
    jb    newblock

    mov   rax , [sizex]
    sub   rax , 100
    imul  rax , 3
    add   rsi , rax

    mov   r10 , 0
    inc   r11
    cmp   r11 , 100
    jbe   newblock

    jmp   dpl1

  draw1to1:

    mov   r11 , [image_end+16]
    sub   r11 , 56
    mov   r12 , [image_end+24]
    sub   r12 , 56

    cmp   r11 , [sizex]
    jbe   sizexfine
    mov   r11 , [sizex]
  sizexfine:
    cmp   r12 , [sizey]
    jbe   sizeyfine
    mov   r12 , [sizey]
  sizeyfine:

    mov   rax , 7
    mov   rbx , 38 * 0x100000000
    add   rbx , r11
    mov   rcx , 38 * 0x100000000
    add   rcx , r12

    mov   rdx ,[scroll1]
    sub   rdx , 1000
    imul  rdx , [sizex]
    add   rdx , [scroll2]
    sub   rdx , 2000
    imul  rdx , 3
    add   rdx , 0x100000

    mov   r8  , [sizex]
    sub   r8  , r11
    imul  r8  , 3
    mov   r9  , 0x1000000
    mov   r10 , 3
    int   0x60

  dpl1:

    ; Draw gray lines to indicate end for X and Y

    cmp   [magnify],byte 1
    je    noseparatorlines

    greyseparator equ 0xe0e0e0

    mov   rax , 38
    mov   rbx , [sizex]
    add   rbx , 38
    mov   rcx , [image_end+16]
    sub   rcx , 26
    cmp   rbx , rcx
    ja    noxgrey
    cmp   [scroll2],dword 2000
    ja    noxgrey
    mov   rcx , 38
    mov   rdx , rbx
    mov   r8  , [sizey]
    add   r8  , 38
    mov   r9  , [image_end+24]
    sub   r9  , 26
    cmp   r8  , r9
    jbe   r9fine
    mov   r8  , r9
  r9fine:
    mov   r9  , greyseparator
    int   0x60
  noxgrey:

    mov   rax , 38
    mov   rcx , [sizey]
    add   rcx , 38
    mov   rdx , [image_end+24]
    sub   rdx , 26
    cmp   rcx , rdx
    ja    noygrey
    cmp   [scroll1],dword 1000
    ja    noygrey
    mov   rbx , 38
    mov   r8  , rcx
    mov   rdx , [sizex]
    add   rdx , 38
    mov   r9  , [image_end+16]
    sub   r9  , 26
    cmp   rdx , r9
    jbe   rdxfine
    mov   rdx , r9
  rdxfine:
    mov   r9  , greyseparator
    int   0x60
  noygrey:

  noseparatorlines:

    pop   r15 r14 r13 r12 r11 r10 r9 r8 rdx rcx rbx rax

    ret



scroll_vertical:

    ; Define vertical scroll

    mov   rax , 113
    mov   rbx , 1
    mov   rcx , 1000
    cmp   [magnify],byte 1
    je    scvl1
    mov   rdx , [sizey]
    add   rdx , 58
    cmp   rdx , [image_end+24]
    ja    scvl1
    mov   rdx , 0
    mov   [scroll1],dword 1000
    jmp   scvl2
  scvl1:
    mov   rdx , [sizey]
    cmp   [magnify],byte 1
    je    scvl2
    sub   rdx , [image_end+24]
    add   rdx , 57
  scvl2:
    mov   r8  ,[scroll1]
    mov   r9  , 250
    mov   r9  , [image_end+16]
    sub   r9  , 18
    mov   r10 , 38
    mov   r11 , 150
    mov   r11 , [image_end+24]
    sub   r11 , 57
    int   0x60

    ret


scroll_horizontal:

    ; Define horizontal scroll

    mov   rax , 113
    mov   rbx , 2
    mov   rcx , 2000
    cmp   [magnify],byte 1
    je    schl1
    mov   rdx , [sizex]
    add   rdx , 58
    cmp   rdx , [image_end+16]
    ja    schl1
    mov   rdx , 0
    mov   [scroll2],dword 2000
    jmp   schl2
  schl1:
    mov   rdx , [sizex]
    cmp   [magnify],byte 1
    je    schl2
    sub   rdx , [image_end+16]
    add   rdx , 57
  schl2:
    mov   r8  ,[scroll2]
    mov   r9  , 210
    mov   r9  , [image_end+24]
    sub   r9  , 18
    mov   r10 , 38
    mov   r11 , 220
    mov   r11 , [image_end+16]
    sub   r11 , 57
    int   0x60

    ret


decode_external:

; r15 - 1=gif , 2=jpg, 3=png, 4=bmp

    mov   rax , 58
    mov   rbx , 0
    mov   rcx , 0
    mov   rdx , -1
    mov   r8  , 0x100000
    mov   r9  , filename
    int   0x60

    ; GIF image

    cmp   r15 , 1
    jne   no_gif_image
    mov   rax , 256
    mov   rbx , rungif
    mov   rcx , param
    jmp   run_image_app
  no_gif_image:

    ; JPG image

    cmp   r15 , 2
    jne   no_jpg_image
    mov   rax , 256
    mov   rbx , runjpg
    mov   rcx , param
    jmp   run_image_app
  no_jpg_image:

    ; PNG image

    cmp   r15 , 3
    jne   no_png_image
    mov   rax , 256
    mov   rbx , runpng
    mov   rcx , param
    jmp   run_image_app
  no_png_image:

    ; BMP image

    cmp   r15 , 4
    jne   no_bmp_image
    mov   rax , 256
    mov   rbx , runbmp
    mov   rcx , param
    jmp   run_image_app
  no_bmp_image:

  run_image_app:

    int   0x60

    push  rbx

    mov   rax , 5
    mov   rbx , 10
    int   0x60

    ; Draw.asm IPC area at 6 MB

    mov   rax , 0
    mov   [0x600000-32],rax
    mov   rax , 16
    mov   [0x600000-24],rax
    mov   rdi , 0x600000
    mov   rcx , 0x200000 / 8
    mov   rax , 0
    cld
    rep   stosq
    mov   [0x600000],dword 123123

    ; Define IPC

    mov   rax , 60
    mov   rbx , 1
    mov   rcx , 0x600000-32
    mov   rdx , 0x400000
    int   0x60

    ; My PID

    mov   rax , 111
    mov   rbx , 1
    int   0x60
    mov   [0x100000-8],rax

    ; Send picture from 1 MB

    mov   rax , 60
    mov   rbx , 2
    pop   rcx
    mov   rdx , 0x100000-8
    mov   r8 , [loaded_file_size]
    add   r8 , 8
    int   0x60

    mov   rdi , 0

  waitmore:

    inc   rdi
    cmp   rdi , 100*60*2 ; 2 minute timeout
    ja    notransformation

    mov   rax , 5
    mov   rbx , 1
    int   0x60

    cmp   [0x600000],dword 123123
    je    waitmore

    mov   rax , 5
    mov   rbx , 10
    int   0x60

    mov   eax , [0x600000-16]
    mov   ebx , [0x600000-8]

    mov   [sizex],rax
    mov   [sizey],rbx

    mov   [selectx],dword 0
    mov   [selecty],dword 0
    mov   [selectxe],rax
    mov   [selectye],rbx

    mov   rsi , 0x600000
    mov   rdi , 0x100000
    mov   rcx , 0x400000
    cld
    rep   movsb

    ret

  notransformation:

    mov   [selectx],dword 0
    mov   [selecty],dword 0
    mov   rax , [sizex]
    mov   [selectxe],rax
    mov   rbx , [sizey]
    mov   [selectye],rbx

    ret





; Brightness

brstart:

    call  br_draw_window

brstill:

    mov   rax , 0xA         ; Wait here for event
    int   0x60

    test  rax , 0x1         ; Window redraw
    jnz   br_window_event
    test  rax , 0x2         ; Keyboard press
    jnz   br_key_event
    test  rax , 0x4         ; Button press
    jnz   br_button_event

    jmp   brstill

br_window_event:

    call  br_draw_window
    jmp   brstill

br_key_event:

    mov   rax , 0x2        ; Read the key and ignore
    int   0x60

    jmp   brstill

br_button_event:

    mov   rax , 0x11
    int   0x60

    ; rax = status
    ; rbx = button id

    cmp   rbx , 1000
    jb    nobrsc1
    cmp   rbx , 1999
    ja    nobrsc1
    mov   [brsv],rbx
    call  brscroll
    jmp   brstill
  nobrsc1:

    cmp   rbx , 10
    jne   brno_accept
    mov   [brightnessrunning],byte 0
    mov   rax , [brsv]
    sub   rax , 1100-100
    add   rax , 1 ; 1 -> 201
    mov   [brdo],rax
    mov   rax , 0x200
    int   0x60
  brno_accept:

    cmp   rbx , 11
    jne   brno_cancel
    mov   [brightnessrunning],byte 0
    mov   rax , 0x200
    int   0x60
  brno_cancel:

    cmp   rbx , 0x10000001
    jne   brno_cancel2
    mov   [brightnessrunning],byte 0
    mov   rax , 0x200
    int   0x60
  brno_cancel2:

    jmp   brstill


br_draw_window:

    mov   rax , 12
    mov   rbx , 1
    int   0x60

    mov   rax , 0
    mov   rbx , 160 * 0x100000000 + 260
    mov   rcx , 100 * 0x100000000 + 124
    mov   rdx , window_color
    mov   r8  , 1
    mov   r9  , string_brightness
    mov   r10 , 0
    int   0x60

    mov   rax , 8
    mov   rbx , 45 shl 32 + 70
    mov   rcx , 88 shl 32 + 17
    mov   rdx , 10
    mov   r8  , 0
    mov   r9  , brok
    int   0x60
    mov   rax , 8
    mov   rbx , 135 shl 32 + 70
    mov   rcx , 88  shl 32 + 17
    mov   rdx , 11
    mov   r8  , 0
    mov   r9  , brcancel
    int   0x60

    mov   rax , 4
    mov   rbx , brtext
    mov   rcx , 30
    mov   rdx , 40
    mov   rsi , 0x000000
    mov   r9  , 1
    int   0x60

    call  brscroll

    mov   rax , 12
    mov   rbx , 2
    int   0x60

    ret



brscroll:

    mov   rax , 113
    mov   rbx , 2
    mov   rcx , 1000
    mov   rdx , 201 ; 51
    mov   r8  , [brsv]
    mov   r9  , 60
    mov   r10 , 30
    mov   r11 , 190
    int   0x60

    mov   rax , 13
    mov   rbx , 116 shl 32 + 3 * 6
    mov   rcx , (40-1) shl 32 + 11+2
    mov   rdx , 0xffffff
    int   0x60

    mov   rax , 47
    mov   rbx , 3*65536
    mov   rcx , [brsv]
    sub   rcx , 1100-100
    mov   rdx , 116 shl 32 + 40
    mov   rsi , 0x000000
    int   0x60

    ret



; Contrast

costart:

    call  co_draw_window

costill:

    mov   rax , 0xA         ; Wait here for event
    int   0x60

    test  rax , 0x1         ; Window redraw
    jnz   co_window_event
    test  rax , 0x2         ; Keyboard press
    jnz   co_key_event
    test  rax , 0x4         ; Button press
    jnz   co_button_event

    jmp   costill

co_window_event:

    call  co_draw_window
    jmp   costill

co_key_event:

    mov   rax , 0x2        ; Read the key and ignore
    int   0x60

    jmp   costill

co_button_event:

    mov   rax , 0x11
    int   0x60

    ; rax = status
    ; rbx = button id

    cmp   rbx , 1000
    jb    nocosc1
    cmp   rbx , 1999
    ja    nocosc1
    mov   [cosv],rbx
    call  coscroll
    jmp   costill
  nocosc1:

    cmp   rbx , 10
    jne   cono_accept
    mov   [contrastrunning],byte 0
    mov   rax , [cosv]
    sub   rax , 1100-100
    add   rax , 1 ; 1 -> 201
    mov   [codo],rax
    mov   rax , 0x200
    int   0x60
  cono_accept:

    cmp   rbx , 11
    jne   cono_cancel
    mov   [contrastrunning],byte 0
    mov   rax , 0x200
    int   0x60
  cono_cancel:

    cmp   rbx , 0x10000001
    jne   cono_cancel2
    mov   [contrastrunning],byte 0
    mov   rax , 0x200
    int   0x60
  cono_cancel2:

    jmp   costill


co_draw_window:

    mov   rax , 12
    mov   rbx , 1
    int   0x60

    mov   rax , 0
    mov   rbx , 160 * 0x100000000 + 260
    mov   rcx , 100 * 0x100000000 + 124
    mov   rdx , window_color
    mov   r8  , 1
    mov   r9  , string_contrast
    mov   r10 , 0
    int   0x60

    mov   rax , 8
    mov   rbx , 45 shl 32 + 70
    mov   rcx , 88 shl 32 + 17
    mov   rdx , 10
    mov   r8  , 0
    mov   r9  , cook
    int   0x60
    mov   rax , 8
    mov   rbx , 135 shl 32 + 70
    mov   rcx , 88  shl 32 + 17
    mov   rdx , 11
    mov   r8  , 0
    mov   r9  , cocancel
    int   0x60

    mov   rax , 4
    mov   rbx , cotext
    mov   rcx , 30
    mov   rdx , 40
    mov   rsi , 0x000000
    mov   r9  , 1
    int   0x60

    call  coscroll

    mov   rax , 12
    mov   rbx , 2
    int   0x60

    ret



coscroll:

    mov   rax , 113
    mov   rbx , 2
    mov   rcx , 1000
    mov   rdx , 201 ; 51
    mov   r8  , [cosv]
    mov   r9  , 60
    mov   r10 , 30
    mov   r11 , 190
    int   0x60

    mov   rax , 13
    mov   rbx , 116 shl 32 + 3 * 6
    mov   rcx , (40-1) shl 32 + 11+2
    mov   rdx , 0xffffff
    int   0x60

    mov   rax , 47
    mov   rbx , 3*65536
    mov   rcx , [cosv]
    sub   rcx , 1100-100
    mov   rdx , 116 shl 32 + 40
    mov   rsi , 0x000000
    int   0x60

    ret





; Resize

restart:

    call  re_draw_window

restill:

    mov   rax , 0xA         ; Wait here for event
    int   0x60

    test  rax , 0x1         ; Window redraw
    jnz   re_window_event
    test  rax , 0x2         ; Keyboard press
    jnz   re_key_event
    test  rax , 0x4         ; Button press
    jnz   re_button_event

    jmp   restill

re_window_event:

    call  re_draw_window
    jmp   restill

re_key_event:

    mov   rax , 0x2        ; Read the key and ignore
    int   0x60

    jmp   restill

re_button_event:

    mov   rax , 0x11
    int   0x60

    ; rax = status
    ; rbx = button id

    cmp   rbx , 1000
    jb    noresc1
    cmp   rbx , 1000+1280-1
    ja    noresc1
    mov   [resv],rbx
    call  rescroll
    jmp   restill
  noresc1:

    cmp   rbx , 3000
    jb    noresc2
    cmp   rbx , 3000+1024-1
    ja    noresc2
    mov   [resv2],rbx
    call  rescroll2
    jmp   restill
  noresc2:

    cmp   rbx , 10
    jne   reno_accept

    mov   [resizerunning],byte 0

    mov   rax,[resv]
    sub   rax , 999
    mov   [xnew],rax

    mov   rax,[resv2]
    sub   rax , 2999
    mov   [ynew],rax

    mov   rax , 0x200
    int   0x60
  reno_accept:

    cmp   rbx , 11
    jne   reno_cancel
    mov   [resizerunning],byte 0
    mov   rax , 0x200
    int   0x60
  reno_cancel:

    cmp   rbx , 0x10000001
    jne   reno_cancel2
    mov   [resizerunning],byte 0
    mov   rax , 0x200
    int   0x60
  reno_cancel2:

    jmp   restill

yspos equ 37

re_draw_window:

    mov   rax , 12
    mov   rbx , 1
    int   0x60

    mov   rax , 0
    mov   rbx , 160 * 0x100000000 + 255
    mov   rcx , 100 * 0x100000000 + 126 + yspos
    mov   rdx , window_color
    mov   r8  , 1
    mov   r9  , string_resize
    mov   r10 , 0
    int   0x60

    mov   rax , 8
    mov   rbx , 45 shl 32 + 70
    mov   rcx , (90+yspos) shl 32 + 17
    mov   rdx , 10
    mov   r8  , 0
    mov   r9  , reok
    int   0x60
    mov   rax , 8
    mov   rbx , 135 shl 32 + 70
    mov   rcx , (90+yspos)  shl 32 + 17
    mov   rdx , 11
    mov   r8  , 0
    mov   r9  , recancel
    int   0x60

    ; X

    mov   rax , 4
    mov   rbx , retext
    mov   rcx , 30
    mov   rdx , 35+2
    mov   rsi , 0x000000
    mov   r9  , 1
    int   0x60

    call  rescroll

    ; Y

    mov   rax , 4
    mov   rbx , retext2
    mov   rcx , 30
    mov   rdx , 40+yspos+2
    mov   rsi , 0x000000
    mov   r9  , 1
    int   0x60

    call  rescroll2

    mov   rax , 12
    mov   rbx , 2
    int   0x60

    ret



rescroll:

    mov   rax , 113
    mov   rbx , 2
    mov   rcx , 1000
    mov   rdx , 1280 ; 999
    mov   r8  , [resv]
    mov   r9  , 55
    mov   r10 , 30
    mov   r11 , 190
    int   0x60

    mov   rax , 13
    mov   rbx , 76 shl 32 + 4 * 6
    mov   rcx , (37-1) shl 32 + 11+2
    mov   rdx , 0xffffff
    int   0x60

    mov   rax , 47
    mov   rbx , 4*65536
    mov   rcx , [resv]
    sub   rcx , 999
    mov   rdx , 76 shl 32 + 37
    mov   rsi , 0x000000
    int   0x60

    ret

rescroll2:

    mov   rax , 113
    mov   rbx , 2
    mov   rcx , 3000
    mov   rdx , 1024
    mov   r8  , [resv2]
    mov   r9  , 60+yspos
    mov   r10 , 30
    mov   r11 , 190
    int   0x60

    mov   rax , 13
    mov   rbx , 76 shl 32 + 4 * 6
    mov   rcx , (42+yspos-1) shl 32 + 11+2
    mov   rdx , 0xffffff
    int   0x60

    mov   rax , 47
    mov   rbx , 4*65536
    mov   rcx , [resv2]
    sub   rcx , 2999
    mov   rdx , 76 shl 32 + 42+yspos
    mov   rsi , 0x000000
    int   0x60

    ret



; Mosaic

mostart:

    call  mo_draw_window

mostill:

    mov   rax , 0xA         ; Wait here for event
    int   0x60

    test  rax , 0x1         ; Window redraw
    jnz   mo_window_event
    test  rax , 0x2         ; Keyboard press
    jnz   mo_key_event
    test  rax , 0x4         ; Button press
    jnz   mo_button_event

    jmp   mostill

mo_window_event:

    call  mo_draw_window
    jmp   mostill

mo_key_event:

    mov   rax , 0x2        ; Read the key and ignore
    int   0x60

    jmp   mostill

mo_button_event:

    mov   rax , 0x11
    int   0x60

    ; rax = status
    ; rbx = button id

    cmp   rbx , 1000
    jb    nomosc1
    cmp   rbx , 1000+1280-1
    ja    nomosc1
    mov   [mosv],rbx
    call  moscroll
    jmp   mostill
  nomosc1:

    cmp   rbx , 3000
    jb    nomosc2
    cmp   rbx , 3000+1024-1
    ja    nomosc2
    mov   [mosv2],rbx
    call  moscroll2
    jmp   mostill
  nomosc2:

    cmp   rbx , 10
    jne   mono_accept

    mov   [mosaicrunning],byte 0

    mov   rax,[mosv]
    sub   rax , 999
    mov   [mosx],rax

    mov   rax,[mosv2]
    sub   rax , 2999
    mov   [mosy],rax

    mov   rax , 0x200
    int   0x60
  mono_accept:

    cmp   rbx , 11
    jne   mono_cancel
    mov   [mosaicrunning],byte 0
    mov   rax , 0x200
    int   0x60
  mono_cancel:

    cmp   rbx , 0x10000001
    jne   mono_cancel2
    mov   [mosaicrunning],byte 0
    mov   rax , 0x200
    int   0x60
  mono_cancel2:

    jmp   mostill

yspos equ 37

mo_draw_window:

    mov   rax , 12
    mov   rbx , 1
    int   0x60

    mov   rax , 0
    mov   rbx , 160 * 0x100000000 + 255
    mov   rcx , 100 * 0x100000000 + 126 + yspos
    mov   rdx , window_color
    mov   r8  , 1
    mov   r9  , string_mosaic
    mov   r10 , 0
    int   0x60

    mov   rax , 8
    mov   rbx , 45 shl 32 + 70
    mov   rcx , (90+yspos) shl 32 + 17
    mov   rdx , 10
    mov   r8  , 0
    mov   r9  , mook
    int   0x60
    mov   rax , 8
    mov   rbx , 135 shl 32 + 70
    mov   rcx , (90+yspos)  shl 32 + 17
    mov   rdx , 11
    mov   r8  , 0
    mov   r9  , mocancel
    int   0x60

    ; X

    mov   rax , 4
    mov   rbx , motext
    mov   rcx , 30
    mov   rdx , 35+2
    mov   rsi , 0x000000
    mov   r9  , 1
    int   0x60

    call  moscroll

    ; Y

    mov   rax , 4
    mov   rbx , motext2
    mov   rcx , 30
    mov   rdx , 40+yspos+2
    mov   rsi , 0x000000
    mov   r9  , 1
    int   0x60

    call  moscroll2

    mov   rax , 12
    mov   rbx , 2
    int   0x60

    ret



moscroll:

    mov   rax , 113
    mov   rbx , 2
    mov   rcx , 1000
    mov   rdx , 256
    mov   r8  , [mosv]
    mov   r9  , 55
    mov   r10 , 30
    mov   r11 , 190
    int   0x60

    mov   rax , 13
    mov   rbx , 76 shl 32 + 4 * 6
    mov   rcx , (37-1) shl 32 + 11+2
    mov   rdx , 0xffffff
    int   0x60

    mov   rax , 47
    mov   rbx , 4*65536
    mov   rcx , [mosv]
    sub   rcx , 999
    mov   rdx , 76 shl 32 + 37
    mov   rsi , 0x000000
    int   0x60

    ret

moscroll2:

    mov   rax , 113
    mov   rbx , 2
    mov   rcx , 3000
    mov   rdx , 256
    mov   r8  , [mosv2]
    mov   r9  , 60+yspos
    mov   r10 , 30
    mov   r11 , 190
    int   0x60

    mov   rax , 13
    mov   rbx , 76 shl 32 + 4 * 6
    mov   rcx , (42+yspos-1) shl 32 + 11+2
    mov   rdx , 0xffffff
    int   0x60

    mov   rax , 47
    mov   rbx , 4*65536
    mov   rcx , [mosv2]
    sub   rcx , 2999
    mov   rdx , 76 shl 32 + 42+yspos
    mov   rsi , 0x000000
    int   0x60

    ret




; Adjust

adjuststart:

    call  ad_draw_window

adstill:

    mov   rax , 0xA         ; Wait here for event
    int   0x60

    test  rax , 0x1         ; Window redraw
    jnz   ad_window_event
    test  rax , 0x2         ; Keyboard press
    jnz   ad_key_event
    test  rax , 0x4         ; Button press
    jnz   ad_button_event

    jmp   adstill

ad_window_event:

    call  ad_draw_window
    jmp   adstill

ad_key_event:

    mov   rax , 0x2        ; Read the key and ignore
    int   0x60

    jmp   adstill

ad_button_event:

    mov   rax , 0x11
    int   0x60

    ; rax = status
    ; rbx = button id

    cmp   rbx , 1000
    jb    noadsc1
    cmp   rbx , 1999
    ja    noadsc1
    mov   [adsv],rbx
    call  adscroll
    jmp   adstill
  noadsc1:

    cmp   rbx , 2000
    jb    noadsc2
    cmp   rbx , 2999
    ja    noadsc2
    mov   [adsv2],rbx
    call  adscroll2
    jmp   adstill
  noadsc2:

    cmp   rbx , 3000
    jb    noadsc3
    cmp   rbx , 3999
    ja    noadsc3
    mov   [adsv3],rbx
    call  adscroll3
    jmp   adstill
  noadsc3:

    cmp   rbx , 10
    jne   adno_accept

    mov   [adjustrunning],byte 0

    mov   rax,[adsv]
    sub   rax , 999
    mov   [adxnew],rax

    mov   rax,[adsv2]
    sub   rax , 1999
    mov   [adynew],rax

    mov   rax,[adsv3]
    sub   rax , 2999
    mov   [adznew],rax

    mov   rax , 0x200
    int   0x60
  adno_accept:

    cmp   rbx , 11
    jne   adno_cancel
    mov   [adjustrunning],byte 0
    mov   rax , 0x200
    int   0x60
  adno_cancel:

    cmp   rbx , 0x10000001
    jne   adno_cancel2
    mov   [adjustrunning],byte 0
    mov   rax , 0x200
    int   0x60
  adno_cancel2:

    jmp   adstill


ad_draw_window:

    mov   rax , 12
    mov   rbx , 1
    int   0x60

    mov   rax , 0
    mov   rbx , 160 * 0x100000000 + 257
    mov   rcx , 100 * 0x100000000 + 166 + yspos
    mov   rdx , window_color
    mov   r8  , 1
    mov   r9  , string_adjust
    mov   r10 , 0
    int   0x60

    mov   rax , 8
    mov   rbx , 46 shl 32 + 70
    mov   rcx , (130+yspos) shl 32 + 17
    mov   rdx , 10
    mov   r8  , 0
    mov   r9  , reok
    int   0x60
    mov   rax , 8
    mov   rbx , 136 shl 32 + 70
    mov   rcx , (130+yspos)  shl 32 + 17
    mov   rdx , 11
    mov   r8  , 0
    mov   r9  , recancel
    int   0x60

    ; X

    mov   rax , 4
    mov   rbx , adtext
    mov   rcx , 30
    mov   rdx , 35+2
    mov   rsi , 0x000000
    mov   r9  , 1
    int   0x60

    call  adscroll

    ; Y

    mov   rax , 4
    mov   rbx , adtext2
    mov   rcx , 30
    mov   rdx , 40+yspos+2
    mov   rsi , 0x000000
    mov   r9  , 1
    int   0x60

    call  adscroll2

    ; Blue

    mov   rax , 4
    mov   rbx , adtext3
    mov   rcx , 30
    mov   rdx , 120
    mov   rsi , 0x000000
    mov   r9  , 1
    int   0x60

    call  adscroll3

    mov   rax , 12
    mov   rbx , 2
    int   0x60

    ret



adscroll:

    mov   rax , 113
    mov   rbx , 2
    mov   rcx , 1000
    mov   rdx , 199
    mov   r8  , [adsv]
    mov   r9  , 55
    mov   r10 , 30
    mov   r11 , 192
    int   0x60

    mov   rax , 13
    mov   rbx , 80 shl 32 + 3 * 6
    mov   rcx , (37-1) shl 32 + 11+2
    mov   rdx , 0xffffff
    int   0x60

    mov   rax , 47
    mov   rbx , 3*65536
    mov   rcx , [adsv]
    sub   rcx , 999
    mov   rdx , 80 shl 32 + 37
    mov   rsi , 0x000000
    int   0x60

    ret

adscroll2:

    mov   rax , 113
    mov   rbx , 2
    mov   rcx , 2000
    mov   rdx , 199
    mov   r8  , [adsv2]
    mov   r9  , 60+yspos
    mov   r10 , 30
    mov   r11 , 192
    int   0x60

    mov   rax , 13
    mov   rbx , 80 shl 32 + 3 * 6
    mov   rcx , (42+yspos-1) shl 32 + 11+2
    mov   rdx , 0xffffff
    int   0x60

    mov   rax , 47
    mov   rbx , 3*65536
    mov   rcx , [adsv2]
    sub   rcx , 1999
    mov   rdx , 80 shl 32 + 42+yspos
    mov   rsi , 0x000000
    int   0x60

    ret


adscroll3:

    mov   rax , 113
    mov   rbx , 2
    mov   rcx , 3000
    mov   rdx , 199
    mov   r8  , [adsv3]
    mov   r9  , 102+yspos
    mov   r10 , 30
    mov   r11 , 192
    int   0x60

    mov   rax , 13
    mov   rbx , 80 shl 32 + 3 * 6
    mov   rcx , (82+yspos-1) shl 32 + 11+2
    mov   rdx , 0xffffff
    int   0x60

    mov   rax , 47
    mov   rbx , 3*65536
    mov   rcx , [adsv3]
    sub   rcx , 1999
    mov   rdx , 80 shl 32 + 82+yspos
    mov   rsi , 0x000000
    int   0x60

    ret


; RGB thread

rgbstart:

    call  rgbwindow

rgbstill:

    call  rgbvalues

    mov   rax , 23
    mov   rbx , 15
    int   0x60

    test  rax , 1
    jz    nowinm
    mov   [rgbmem],dword 123123123
    call  rgbwindow
    jmp   rgbstill
  nowinm:
    test  rax , 2
    jnz   rgbend
    test  rax , 4
    jnz   rgbend

    jmp   rgbstill

  rgbend:

    mov   [rgbrunning],byte 0

    mov   rax , 512
    int   0x60


rgbwindow:

    mov   rax , 0xC                          ; Beginning of window draw
    mov   rbx , 0x1
    int   0x60

    mov   rax , 0x0                          ; Draw window
    mov   rbx , 0x0000010000000078           ; x start & size
    mov   rcx , 0x0000008000000034           ; y start & size
    mov   rdx , 0x0000000000FFFFFF           ; type    & border color
    mov   r8  , 0x0000000000000001           ; draw flags
    mov   r9  , rgblabel
    mov   r10 , 0
    int   0x60

    mov   [rgbmem],dword 1231231233
    call  rgbvalues

    mov   rax , 0xC                          ; End of window draw
    mov   rbx , 0x2
    int   0x60

    ret


rgbvalues:

    mov   rbx , [color_under_mouse]
    cmp   rbx , [rgbmem]
    je    norgbwin
    mov   [rgbmem],rbx

    mov   rax , 13
    mov   rbx , 20 shl 32 + 14 * 6
    mov   rcx , (31-1) shl 32 + 11+2
    mov   rdx , 0xffffff
    int   0x60

    mov   rax , 4
    mov   rbx , rgbt
    mov   rcx , 14
    mov   rdx , 31
    mov   rsi , 0x000000
    mov   r9  , 1
    int   0x60

    mov   rax , 47
    mov   rbx , 3*65536
    mov   rcx , [color_under_mouse]
    shr   rcx , 16
    and   rcx , 0xff
    mov   rdx , 20 shl 32 + 31
    mov   rsi , 0x000000
    int   0x60
    mov   rax , 47
    mov   rbx , 3*65536
    mov   rcx , [color_under_mouse]
    shr   rcx , 8
    and   rcx , 0xff
    mov   rdx , 50 shl 32 + 31
    mov   rsi , 0x000000
    int   0x60
    mov   rax , 47
    mov   rbx , 3*65536
    mov   rcx , [color_under_mouse]
    and   rcx , 0xff
    mov   rdx , 80 shl 32 + 31
    mov   rsi , 0x000000
    int   0x60

  norgbwin:

    ret



; Palette thread


palettestart:

    mov   rsi , color
    mov   rdi , palette_color
    mov   rcx , 16*4
    cld
    rep   movsb

    mov   [selected_button],dword 0
    call  color_to_scrolls

    call  palette_draw_window

palette_still:

    mov   rax , 0xA         ; Wait here for event
    int   0x60

    test  rax , 0x1         ; Window redraw
    jnz   palette_window_event
    test  rax , 0x2         ; Keyboard press
    jnz   palette_key_event
    test  rax , 0x4         ; Button press
    jnz   palette_button_event

    jmp   palette_still

palette_window_event:

    call  palette_draw_window
    jmp   palette_still

palette_key_event:

    mov   rax , 0x2        ; Read the key and ignore
    int   0x60

    jmp   palette_still


color_to_scrolls:

    mov   rbx , [selected_button]
    mov   rax , [palette_color+rbx*4]
    mov   rbx , rax
    and   rbx , 0xff
    mov   rcx , 255
    sub   rcx , rbx
    add   rcx , 3000
    mov   [pscroll3],rcx
    shr   rax , 8
    mov   rbx , rax
    and   rbx , 0xff
    mov   rcx , 255
    sub   rcx , rbx
    add   rcx , 2000
    mov   [pscroll2],rcx
    shr   rax , 8
    mov   rbx , rax
    and   rbx , 0xff
    mov   rcx , 255
    sub   rcx , rbx
    add   rcx , 1000
    mov   [pscroll1],rcx

    ret



palette_button_event:

    mov   rax , 0x11
    int   0x60

    ; rax = status
    ; rbx = button id

    cmp   rbx , 100
    jb    nocolb
    cmp   rbx , 199
    ja    nocolb
    sub   rbx , 100
    mov   [selected_button],rbx
    call  color_to_scrolls
    call  draw_palette_scroll_1
    call  draw_palette_scroll_2
    call  draw_palette_scroll_3
    call  draw_palette_color
    jmp   palette_still
  nocolb:

    cmp   rbx , 1000
    jb    nosc1
    cmp   rbx , 1999
    ja    nosc1
    mov   [pscroll1],rbx
    call  draw_palette_scroll_1
    call  draw_palette_color
    jmp   palette_still
  nosc1:

    cmp   rbx , 2000
    jb    nosc2
    cmp   rbx , 2999
    ja    nosc2
    mov   [pscroll2],rbx
    call  draw_palette_scroll_2
    call  draw_palette_color
    jmp   palette_still
  nosc2:

    cmp   rbx , 3000
    jb    nosc3
    cmp   rbx , 3999
    ja    nosc3
    mov   [pscroll3],rbx
    call  draw_palette_scroll_3
    call  draw_palette_color
    jmp   palette_still
  nosc3:

    cmp   rbx , 0x10000001
    jne   no_palette_terminate_button
    mov   [paletterunning],byte 2
    mov   rax , 0x200
    int   0x60
  no_palette_terminate_button:

    cmp   rbx , 0x106
    jne   no_palette_terminate_menu
    mov   [paletterunning],byte 2
    mov   rax , 0x200
    int   0x60
  no_palette_terminate_menu:

    cmp   rbx , 10
    jne   no_accept
    mov   rsi , palette_color
    mov   rdi , color
    mov   rcx , 16*4
    cld
    rep   movsb
    mov   [paletterunning],byte 2
    mov   rax , 0x200
    int   0x60
  no_accept:

    cmp   rbx , 11
    jne   no_cancel
    mov   [paletterunning],byte 2
    mov   rax , 0x200
    int   0x60
  no_cancel:

    jmp   palette_still



palettebgr equ 0xffffff


palette_draw_window:

    mov   rax , 0xC                          ; Beginning of window draw
    mov   rbx , 0x1
    int   0x60

    mov   rax , 0x0                          ; Draw window
    mov   rbx , 0x0000010000000100           ; x start & size
    mov   rcx , 0x00000080000000D9           ; y start & size
    mov   rdx , palettebgr                   ; type    & border color
    mov   r8  , 0x0000000000000001           ; draw flags
    mov   r9  , palette_window_label         ; 0 or label - asciiz
    mov   r10 , 0                            ; 0 or pointer to menu str
    int   0x60

    call  draw_palette_buttons
    call  draw_palette_color
    call  draw_palette_scroll_1
    call  draw_palette_scroll_2
    call  draw_palette_scroll_3

    mov   rax , 0x4                          ; Display text
    mov   rbx , palette_text
    mov   rcx , 77
    mov   rdx , 39
    mov   rsi , 0x0
    mov   r9  , 0x1
    mov   r8  , 0x3
    int   0x60

    ; Accept button

    mov   rax , 8
    mov   rbx ,  61 * 0x100000000 + 60
    mov   rcx , 181 * 0x100000000 + 18
    mov   rdx , 10
    mov   r8  , 0
    mov   r9  , accept
    int   0x60

    ; Cancel button

    mov   rax , 8
    mov   rbx , 131 * 0x100000000 + 60
    mov   rcx , 181 * 0x100000000 + 18
    mov   rdx , 11
    mov   r8  , 0
    mov   r9  , cancel
    int   0x60

    mov   rax , 0xC                          ; End of window draw
    mov   rbx , 0x2
    int   0x60

    ret



draw_palette_buttons:

    ; Define color buttons

    mov   rax , 8
    mov   rbx ,  20 * 0x100000000 + 16
    mov   rcx ,  38 * 0x100000000 + 16
    mov   rdx , 100
    mov   r8  , 0
    mov   r9  , 0 ; on_text
    mov   r15 , palette_color
  palette_newbutton:
    int   0x60
    push  rax rbx rcx rdx
    mov   rax , 13
    mov   r10 , 5*0x100000000-10
    add   rbx , r10
    add   rcx , r10
    mov   rdx , [r15]
    ;int   0x60
    add   r15 , 4
    pop   rdx rcx rbx rax
    mov   r10 , 16*0x100000000
    add   rcx , r10
    inc   rdx
    cmp   rdx , 108
    jne   palette_nocolc
    mov   rbx , 36*0x100000000 + 16
    mov   rcx , 38*0x100000000 + 16
  palette_nocolc:
    cmp   rdx , 116
    jb    palette_newbutton

    call  palette_draw_button_colors

    ret

palette_draw_button_colors:

    ; Define color buttons

    mov   rax , 8
    mov   rbx ,  20 * 0x100000000 + 16
    mov   rcx ,  38 * 0x100000000 + 16
    mov   rdx , 100
    mov   r8  , 0
    mov   r9  , 0 ; on_text
    mov   r15 , palette_color
  palette_newbutton2:
    ;int   0x60
    push  rax rbx rcx rdx
    mov   rax , 13
    mov   r10 , 5*0x100000000-10
    add   rbx , r10
    add   rcx , r10
    mov   rdx , [r15]
    int   0x60
    add   r15 , 4
    pop   rdx rcx rbx rax
    mov   r10 , 16*0x100000000
    add   rcx , r10
    inc   rdx
    cmp   rdx , 108
    jne   palette_nocolc2
    mov   rbx , 36*0x100000000 + 16
    mov   rcx , 38*0x100000000 + 16
  palette_nocolc2:
    cmp   rdx , 116
    jb    palette_newbutton2

    ret




draw_value:

    mov   r14 , rax
    sub   r14 , 2
    mov   r15 , rbx
    and   r15 , 0xff

    mov   rax , 13
    mov   rbx , r14
    shl   rbx , 32
    add   rbx , 3*6
    mov   rcx , (160-1) shl 32 + 10+2
    mov   rdx , palettebgr
    int   0x60

    mov   rax , 47
    mov   rbx , 3*65536
    mov   rcx , r15
    mov   rdx , r14
    shl   rdx , 32
    add   rdx , 160
    mov   rsi , 0x000000
    int   0x60

    ret



draw_palette_scroll_1:

    mov   rax , 113
    mov   rbx , 1
    mov   rcx , 1000
    mov   rdx , 256
    mov   r8  , [pscroll1]
    mov   r9  , 80
    mov   r10 , 39 + 14; + 15
    mov   r11 , 80 + 20
    int   0x60

    mov   rax , r9
    mov   rbx , [pscroll1]
    sub   rbx , 1000
    not   rbx
    call  draw_value

    ret


draw_palette_scroll_2:

    mov   rax , 113
    mov   rbx , 1
    mov   rcx , 2000
    mov   rdx , 256
    mov   r8  , [pscroll2]
    mov   r9  , 120
    mov   r10 , 39 + 14; + 15
    mov   r11 , 80 + 20
    int   0x60

    mov   rax , r9
    mov   rbx , [pscroll2]
    sub   rbx , 2000
    not   rbx
    call  draw_value

    ret


draw_palette_scroll_3:

    mov   rax , 113
    mov   rbx , 1
    mov   rcx , 3000
    mov   rdx , 256
    mov   r8  , [pscroll3]
    mov   r9  , 160
    mov   r10 , 39 + 14; + 15
    mov   r11 , 80 + 20
    int   0x60

    mov   rax , r9
    mov   rbx , [pscroll3]
    sub   rbx , 3000
    not   rbx
    call  draw_value

    ret


draw_palette_color:

    mov   rbx , [pscroll1]
    sub   rbx , 1000
    mov   rcx , 255
    sub   rcx , rbx
    mov   rax , rcx
    shl   rax , 8
    mov   rbx , [pscroll2]
    sub   rbx , 2000
    mov   rcx , 255
    sub   rcx , rbx
    add   rax , rcx
    shl   rax , 8
    mov   rbx , [pscroll3]
    sub   rbx , 3000
    mov   rcx , 255
    sub   rcx , rbx
    add   rax , rcx
    mov   [palette_color_current],eax

    mov   rbx , [selected_button]
    mov   [palette_color+rbx*4],eax

    mov   rax , 13
    mov   rbx ,200 shl 32 +  5
    mov   rcx , 39 shl 32 + 130
    mov   rdx , 0xc8c8c8
    int   0x60
    mov   rbx ,235 shl 32 +  5
    int   0x60
    mov   rbx ,200 shl 32 + 40
    mov   rcx , 39 shl 32 +  5
    int   0x60
    mov   rcx , 164 shl 32 + 5
    int   0x60

    mov   rax , 13
    mov   rbx ,205 shl 32 +  30
    mov   rcx , 44 shl 32 + 120
    mov   rdx , [palette_color_current]
    int   0x60

    call  palette_draw_button_colors

    ret


; Data area

pscroll1:  dq  1000
pscroll2:  dq  2000
pscroll3:  dq  3000

palette_color_current: dq 0xff0000

selected_button: dq 0x0

adsv:   dq  1100-1
adsv2:  dq  2100-1
adsv3:  dq  3100-1

adtext:  db 'Red  : %',0
adtext2: db 'Green: %',0
adtext3: db 'Blue : %',0

string_adjust:     db 'RED/GREEN/BLUE',0
string_mosaic:     db 'MOSAIC',0

rgbmem:  dq 0x1

resv:    dq 1800-1
resv2:   dq 3600-1

mosv:    dq 1008-1
mosv2:   dq 3008-1

motext:
retext:  db 'X size:',0
motext2:
retext2: db 'Y size:',0

adxnew:  dq 0x0
adynew:  dq 0x0
adznew:  dq 0x0

brsv:    dq  1100
brtext:  db 'Darken            %     Brighten',0

cosv:    dq  1100
cotext:  db 'Less              %         More',0


string_brightness: db 'BRIGHTNESS',0
string_contrast:   db 'CONTRAST',0
string_resize:     db 'IMAGE SIZE',0

accept:
brok:
cook:
reok:
mook:
adok:      db  'OK',0
cancel:
adcancel:
brcancel:
cocancel:
mocancel:
recancel:  db  'CANCEL',0

rungif:  db    '/FD/1/GIFVIEW',0
runjpg:  db    '/FD/1/JPEGVIEW',0
runpng:  db    '/FD/1/PNGVIEW',0
runbmp:  db    '/FD/1/BMPVIEW',0
param:   db    'PARAM',0

window_label:  db 'DRAW',0

rgbt:      db  '    ,    ,     ',0
rgblabel:  db 'RGB',0

scroll1:  dq    1000
scroll2:  dq    2000

selected_color: dq 0
window_on_top:  dq 0

newpicture:     dq 0

selected_thickness: dq 4
selected_tool:      dq 1

color:

    dd    0x000000
    dd    0x000080
    dd    0x0000ff
    dd    0x008000
    dd    0x008080
    dd    0x0080ff
    dd    0x00ff00
    dd    0x00ff80
    dd    0x00ffff ; user picked
    dd    0xff0000
    dd    0xff0080
    dd    0xff00ff
    dd    0xff8000
    dd    0xff8080
    dd    0xffff00
    dd    0xffffff

    ;dd    0x000000 ; user picked

sizex:   dq  800
sizey:   dq  600

menu_struct:               ; Menu Struct

    dq   0                 ; Version

    dq   10000             ; Start value of ID to return ( ID + Line )

    db   0,'FILE',0        ; ID = 10000 + 1
    db   1,'New..',0       ; ID = 10000 + 2
    db   1,'Open..',0      ; ID = 10000 + 3
    db   1,'Save',0
    db   1,'Save As..',0
    db   1,'-',0           ; ID = 10000 + 4
    db   1,'Wallpaper',0
    db   1,'Print image',0
    db   1,'-',0
    db   1,'Quit',0        ; ID = 10000 + 7

    db   0,'EDIT',0
    db   1,'Undo',0
    db   1,'Copy',0
    db   1,'Paste',0

    db   0,'IMAGE',0
    db   1,'Turn Left',0
    db   1,'Turn Right',0
    db   1,'Mirror (L/R)',0
    db   1,'Flip (U/D)',0
    db   1,'-',0
    db   1,'Palette..',0
    db   1,'Value..',0

    db   0,'TOOLS',0
    db   1,'Soften',0
    db   1,'Grayscale',0
    db   1,'Crop',0
    db   1,'Mosaic..',0
    db   1,'Brightness..',0
    db   1,'Contrast..',0
    db   1,'Resize..',0
    db   1,'Red/Green/Blue..',0

    db   255               ; End of Menu Struct

select_color:     dq  0x0
rectangle_color:  dq  0xb8b0b0
drawall:          dq  0x0

fill:     db  'FILL',0
sel:      db  'AREA',0
all:      db  'ALL',0
onetoone: db  '1:8',0
pick:     db  'PICK',0

oldsize:  dq  0x0

a2 dd ?
b2 dd ?
s  dd ?
t  dd ?
xc dd ?
yc dd ?
a  dd ?
b  dd ?
;c  dd ?

ox dd ?
oy dd ?
u  dd ?
d  dd ?
x  dd ?
y  dd ?
r  dd ?
c  dd ?

onscreen   db 0

pixmemx:   dq 99999
pixmemy:   dq 99999
copyx:     dq 0
copyy:     dq 0
copyxe:    dq 0
copyye:    dq 0
selectx:   dq 0
selecty:   dq 0
selectxe:  dq 800
selectye:  dq 600
pasteloop: dq 0x0

loadfail:     db 'Not a JPG, PNG, GIF or 24bit BMP picture.',0
file_search:  db  '/FD/1/FBROWSER   ',0
parameter:    db  '[000000]',0

bmpheader:

    db    66   ; 01
    db    77
    db    54
    db    12
    db    0
    db    0
    db    0
    db    0
    db    0
    db    0    ; 10
    db    54
    db    0
    db    0
    db    0
    db    40
    db    0
    db    0
    db    0
    db    32   ; x
    db    0    ; 20
    db    0
    db    0
    db    32   ; y
    db    0
    db    0
    db    0
    db    1
    db    0
    db    24
    db    0    ; 30
    db    0
    db    0
    db    0
    db    0
    db    0
    db    12
    db    0
    db    0
    db    0
    db    0    ; 40
    db    0
    db    0
    db    0
    db    0
    db    0
    db    0
    db    0
    db    0
    db    0
    db    0    ; 50
    db    0
    db    0
    db    0
    db    0    ; 54

loaded_file_size:   dq  0x0
controls_state:     dq  0x0
color_under_mouse:  dq  0x000000

saveerrormessage:   db  'Use .bmp extension for save.',0

magnify:    dq  0
undosizex:  dq  800
undosizey:  dq  600

xnew: dq 0x0
ynew: dq 0x0

scroll_state:  dq  0x0
brdo:          dq  0x0
codo:          dq  0x0


palette_window_label:

    db    'PALETTE',0     ; Window label

palette_text:

    db    'Red   Green  Blue             ',0

palette_menu_struct:

    dq   0                 ; Version

    dq   0x100             ; Start value of ID to return ( ID + Line )

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

PARAM:  dq 100         ;;
        times 256 db 0 ;; filled by os

ipc_memory:

    dq  0x0        ;; lock - 0=unlocked , 1=locked
    dq  16         ;; first free position from ipc_memory
                   ;;
data_u_start:      ;;
                   ;;
    times 100 db ? ;;

palette_color:  times 16  dd  ?
filename:       times 256 db  ?
dragndrop:      times 110 db  ?

data_u_end:

image_end:

