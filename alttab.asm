;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   ALT-TAB for Menuet
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

application_images   equ   0x400000
app_left             equ   0xC00000
app_right            equ   0xD00000

scalex    equ   160
scaley    equ   120
pr        equ   0x200000

windowx   equ   (1+(scalex+1)*3+14)
windowy   equ   ((scaley)+14+50)

imagey    equ   20
maxw      equ   2
step3d    equ   20
enable3d  equ   1

use64

      db    'MENUET64'
      dq    1
      dq    START
      dq    image_end
      dq    0xE00000
      dq    0x3ffff0
      dq    0
      dq    0

START:

    mov   rax , 141
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    mov   rax , 26
    mov   rbx , 3
    mov   rcx , pr
    mov   rdx , 1024
    int   0x60
    mov   rax , [pr+4*8]
    shr   rax , 1
    mov   rbx , [pr+5*8]
    shr   rbx , 1
    sub   rbx , 185

    mov   [previewx],rax
    mov   [previewy],rbx

    mov   rax , 2
    mov   rcx , windowx * windowy
    mov   rdi , pr+0x80000
    cld
    rep   stosb

    mov   rbx , 8

  news:

    mov   rax , 1
    mov   rcx , windowx-14 ; scalex*3
    mov   rdi , rbx
    imul  rdi , windowx
    add   rdi , 7
    add   rdi , pr+0x80000
    cld
    rep   stosb

    add   rbx , 1
    cmp   rbx , windowy-9
    jbe   news

    ; Soft corners - topleft

    mov   [pr+0x80000]            , dword 0
    mov   [pr+0x80000+1]          , dword 0
    mov   [pr+0x80000+windowx]    ,  word 0
    mov   [pr+0x80000+windowx+1]  ,  word 0
    mov   [pr+0x80000+windowx*2]  ,  word 0
    mov   [pr+0x80000+windowx*3]  ,  byte 0
    mov   [pr+0x80000+windowx*4]  ,  byte 0

    ; Soft corners - topright

    mov   [windowx-4+pr+0x80000]            , dword 0
    mov   [windowx-5+pr+0x80000]            , dword 0
    mov   [windowx-2+pr+0x80000+windowx]    ,  word 0
    mov   [windowx-3+pr+0x80000+windowx]    ,  word 0
    mov   [windowx-2+pr+0x80000+windowx*2]  ,  word 0
    mov   [windowx-1+pr+0x80000+windowx*3]  ,  byte 0
    mov   [windowx-1+pr+0x80000+windowx*4]  ,  byte 0

    ; Soft corners - bottomleft

    mov   [windowx*(windowy-1)+pr+0x80000]    , dword 0
    mov   [windowx*(windowy-1)+1+pr+0x80000]  , dword 0
    mov   [windowx*(windowy-2)+pr+0x80000]    ,  word 0
    mov   [windowx*(windowy-2)+1+pr+0x80000]  ,  word 0
    mov   [windowx*(windowy-3)+pr+0x80000]    ,  word 0
    mov   [windowx*(windowy-4)+pr+0x80000]    ,  byte 0
    mov   [windowx*(windowy-5)+pr+0x80000]    ,  byte 0

    ; Soft corners - bottomright

    mov   [windowx*(windowy)+pr+0x80000-5]    , dword 0
    mov   [windowx*(windowy)+pr+0x80000-4]    , dword 0
    mov   [windowx*(windowy-1)+pr+0x80000-2]  ,  word 0
    mov   [windowx*(windowy-1)+pr+0x80000-3]  ,  word 0
    mov   [windowx*(windowy-2)+pr+0x80000-2]  ,  word 0
    mov   [windowx*(windowy-3)+pr+0x80000-1]  ,  byte 0
    mov   [windowx*(windowy-4)+pr+0x80000-1]  ,  byte 0

    mov   rax , 50
    mov   rbx , 0
    mov   rcx , pr+0x80000
    int   0x60

    call  read_application_images

    ; Draw window

    call  draw_window

    mov   rax , 5
    mov   rbx , 10
    int   0x60

    call  read_application_images
    call  draw_application_window

    mov   rax , 5
    mov   rbx , 10
    int   0x60

    call  read_application_images
    call  draw_application_window

still:

    mov   rax , 23         ; Wait here for event
    mov   rbx , 10
    int   0x60

    cmp   rax , 0
    jne   do_event2

    mov   rax , 111
    mov   rbx , 2
    int   0x60
    cmp   rax , 0
    jne   stop_preview

    ; Wait one second before image update

    inc   dword [delaycount]
    cmp   [delaycount],dword 10
    jb    still

  do_event2:

    mov   [delaycount],dword 0

    test  rax , 0x1         ; Window redraw
    jnz   window_event
    test  rax , 0x2         ; Keyboard press
    jnz   key_event
    test  rax , 0x4         ; Button press
    jnz   button_event

    mov   rax , 125
    mov   rbx , 3
    int   0x60
    cmp   rax , 0
    je    still

    call  read_application_images
    call  draw_application_window

    jmp   still

window_event:

    call  draw_window

    jmp   still

key_event:

    mov   rax , 0x2        ; Read the key and ignore
    int   0x60

    test  rbx , 1
    jnz   still

    cmp   rbx , 0
    jne   nospacecheck
    cmp   cl , ' '
    je    yesenter
  nospacecheck:
    cmp   cx , 'En'
    jne   noenter
  yesenter:

    mov   rax , [selected]
    mov   rcx , [application_pids+rax*8]

    mov   rbx , 3
    cmp   rax , [windows_minimized]
    jb    rbxfine
    mov   rbx , 2
  rbxfine:

    mov   rax , 124
    int   0x60

    mov   rax , 5
    mov   rbx , 20
    int   0x60

    mov   rax , 512
    int   0x60
  noenter:

    cmp   cx , 'Es'
    jne   noclose
    mov   rax , 512
    int   0x60
  noclose:

    cmp   cx , 'Ta'
    jne   notab
    mov   rax , 66
    mov   rbx , 3
    int   0x60
    test  rax , 11b
    jz    yesadd
    jmp   yessub
  notab:

    cmp   ecx , 'Left'
    jne   nosub
  yessub:
    sub   dword [selected],1
    cmp   [selected],dword 0
    jne   nosub
    mov   [selected],dword 1
  nosub:

    cmp   ecx , 'Righ'
    jne   noadd
  yesadd:
    add   dword [selected],1
    mov   rax , [windows]
    cmp   [selected],rax
    jbe   noadd
    mov   [selected],rax
  noadd:

    call  draw_application_window

    jmp   still


stop_preview:

    mov   [preview_running],dword 0

    mov   rax , 512
    int   0x60

button_event:

    mov   rax , 0x11
    int   0x60

    jmp   still


draw_window:

    mov   rax , 0xC                          ; Beginning of window draw
    mov   rbx , 0x1
    int   0x60

    mov   rax , 0x0
    mov   rbx , [previewx]
    sub   rbx , windowx/2
    shl   rbx , 32
    add   rbx , windowx                      ; x start & size
    mov   rcx , [previewy]
    shl   rcx , 32
    add   rcx , windowy                      ; y start & size
    mov   rdx , 0x0000000100000000           ; type    & border color
    mov   r8  , 0x0000000000000001           ; draw flags
    mov   r9  , 0 ; window_label             ; 0 or label - asciiz
    mov   r10 , 0 ; menu_struct              ; 0 or pointer to menu struct
    int   0x60

    ; Edges

    mov   rax , 13
    mov   rbx , 0 shl 32 + windowx
    mov   rcx , 0 shl 32 + 8; owy
    mov   rdx , 0xd0d0d0
    int   0x60
    mov   rax , 13
    mov   rbx , 0 shl 32 + windowx
    mov   rcx , (windowy-8) shl 32 + 8
    mov   rdx , 0xd0d0d0
    int   0x60
    mov   rax , 13
    mov   rbx , 0 shl 32 + 8
    mov   rcx , 0 shl 32 + windowy
    mov   rdx , 0xd0d0d0
    int   0x60
    mov   rax , 13
    mov   rbx , (windowx-8) shl 32 + 8
    mov   rcx , 0 shl 32 + windowy
    mov   rdx , 0xd0d0d0
    int   0x60

    ; Frames

    call  draw_frames

    ; Inner black

    mov   rax , 13
    mov   rbx , 8 shl 32 + windowx-16
    mov   rcx , 8 shl 32 + windowy-16
    mov   rdx , 0;xd0d0d0
    int   0x60

    ; Draw windows

    call  draw_application_window

    mov   rax , 0xC                          ; End of window draw
    mov   rbx , 0x2
    int   0x60

    ret


draw_frames:

    mov   rax , 38
    mov   rbx , 0
    mov   rcx , 0
    mov   rdx , windowx-1
    mov   r8  , windowy-1
    mov   r9  , 0xfefefe
    push  rdx
    mov   rdx , rbx
    int   0x60
    pop   rdx
    push  rbx
    mov   rbx , rdx
    int   0x60
    pop   rbx
    push  rcx
    mov   rcx , r8
    int   0x60
    pop   rcx
    mov   r8 , rcx
    int   0x60

    ; Pixels - topleft

    mov   rax , 1
    mov   rbx , 4
    mov   rcx , 1
    mov   rdx , r9
    int   0x60
    dec   rbx
    int   0x60
    dec   rbx
    inc   rcx
    int   0x60
    dec   rbx
    inc   rcx
    int   0x60
    inc   rcx
    int   0x60

    ; Pixels - topright

    mov   rax , 1
    mov   rbx , windowx-5
    mov   rcx , 1
    mov   rdx , r9
    int   0x60
    inc   rbx
    int   0x60
    inc   rbx
    inc   rcx
    int   0x60
    inc   rbx
    inc   rcx
    int   0x60
    inc   rcx
    int   0x60

    ; Pixels - bottomleft

    mov   rax , 1
    mov   rbx , 4
    mov   rcx , windowy-2
    mov   rdx , r9
    int   0x60
    dec   rbx
    int   0x60
    dec   rbx
    dec   rcx
    int   0x60
    dec   rbx
    dec   rcx
    int   0x60
    dec   rcx
    int   0x60

    ; Pixels - bottomright

    mov   rax , 1
    mov   rbx , windowx-5
    mov   rcx , windowy-2
    mov   rdx , r9
    int   0x60
    inc   rbx
    int   0x60
    inc   rbx
    dec   rcx
    int   0x60
    inc   rbx
    dec   rcx
    int   0x60
    dec   rcx
    int   0x60

    ret


read_application_images:

    ; 1) Read application in window stack
    ; 2) Read minimized applications

    mov   rbp , 1

    mov   r11 , 0

  read_stack:

    cmp   rbp , 1
    jne   no_wstack
    ; Get amount of applications in window stack
    mov   rax , 26
    mov   rbx , 1
    mov   rcx , pr
    mov   rdx , 1024
    int   0x60
    mov   r15 , [pr+15*8]  ; Read visible windows
    cmp   r15 , 0
    jne   windowsok
    mov   rax , 512
    int   0x60
  windowsok:
  no_wstack:

    cmp   rbp , 2
    jne   no_minimized
    mov   r12 , r11
    inc   r12
    mov   [windows_minimized],r12
    mov   r15 , 64
  no_minimized:

  rail1:

    mov   rax , 26
    mov   rbx , 2
    mov   rcx , pr
    mov   rdx , 1024
    int   0x60

    mov   r10 , [pr+r15*8]

    ; Get window X and Y size - by pid ( window stack )

    mov   rax , 9
    mov   rbx , 2
    mov   rcx , r10
    mov   rdx , pr
    mov   r8  , 1024
    int   0x60

    cmp   rbp , 2
    jne   no_min

    ; Get window X and Y size - by process slot

    mov   rax , 9
    mov   rbx , 1
    mov   rcx , r15
    mov   rdx , pr
    mov   r8  , 1024
    int   0x60

    cmp   [pr+704],byte 1
    jne   no_window

    mov   r10 , [pr+264]

  no_min:

    ; Does the window have a label ?

    cmp   [pr+360],dword 0
    je    no_window

    ; Window OK

    inc   r11

    mov   rax , 0
    mov   rbx , 0

  newpix2:

    push  rax rbx

    ; X

    imul  rax , [pr+16]
    xor   rdx , rdx
    mov   rbx , scalex
    div   rbx
    mov   rdx , rax

    ; Y

    push  rdx
    mov   rax , [rsp+8]
    imul  rax , [pr+24]
    xor   rdx , rdx
    mov   rbx , scaley
    div   rbx
    mov   r8  , rax
    pop   rdx

    ; Get pixel

    mov   rax , 125
    mov   rbx , 4
    mov   rcx , r10
    int   0x60

    cmp   [rsp],dword 10
    jb    nobl
    cmp   [prevpix],dword 0x808080
    jb    nobl
    cmp   eax , 0x000000
    ja    nobl
    mov   eax , 0x404040
  nobl:
    mov   [prevpix],eax

    mov   rbx , [rsp+8]
    mov   rcx , [rsp]

    imul  rcx , scalex*3
    imul  rbx , 3
    add   rbx , rcx
    mov   rcx , r11
    imul  rcx , scalex*scaley*3+1000
    add   rcx , application_images
    and   eax , 0xffffff
    mov   [rcx+rbx],eax

    pop   rbx rax

    add   rax , 1
    cmp   rax , scalex
    jb    newpix2

    mov   rax , 0

    add   rbx , 1
    cmp   rbx , scaley
    jb    newpix2

    ; Get window name

    mov   rax , 110
    mov   rbx , 1
    mov   rcx , r10
    mov   rdx , r11
    imul  rdx , 32
    add   rdx , application_names
    mov   r8  , 20
    int   0x60

    ; Save PID

    mov   [application_pids+r11*8],r10

    ; Soften picture

    jmp   no_soften

    mov   rdi , 5
  softenagain:
    mov   rcx , r11
    imul  rcx , scalex*scaley*3+1000
    add   rcx , application_images
    mov   rsi , scalex*scaley
  newsoften:
    mov   eax , [rcx]
    and   eax , 0xffffff
    shr   eax , 2
    and   eax , 0x3f3f3f
    mov   ebx , [rcx+3]
    shr   ebx , 2
    and   ebx , 0x3f3f3f
    add   eax , ebx

    mov   ebx , [rcx+scalex*3]
    shr   ebx , 2
    and   ebx , 0x3f3f3f
    add   eax , ebx
    mov   ebx , [rcx+3+scalex*3]
    shr   ebx , 2
    and   ebx , 0x3f3f3f
    add   eax , ebx

    mov   [rcx],ax
    shr   rax , 16
    mov   [rcx+2],al

    add   rcx , 3
    dec   rsi
    jnz   newsoften

    dec   rdi
    jnz   softenagain

    mov   rsi , r11
    imul  rsi , scalex*scaley*3+1000
    add   rsi , application_images
    mov   rdi , rsi
    add   rdi , 6
    mov   rcx , scalex*scaley*3+1000
    add   rsi , rcx
    add   rdi , rcx
    std
    rep   movsb
    cld

  no_soften:

  no_window:

    dec   r15

    cmp   r15 , 2
    jae   rail1

    add   rbp , 1

    cmp   rbp , 2
    jbe   read_stack

    mov   [windows],r11

    cmp   r11 , 0
    je    stop_preview

    ret


draw_application_window:

    mov   rax , 0
    mov   rdi , app_left
    mov   rcx , 0x100000 / 8
    cld
    rep   stosq

    mov   rax , 0
    mov   rdi , app_right
    mov   rcx , 0x100000 / 8
    cld
    rep   stosq

    mov   rax , [selected]
    mov   [pidx],dword scalex+1

    push  rax

    ; Draw image in the middle

    mov   rdx , rax
    imul  rdx , scalex*scaley*3+1000
    add   rdx , application_images

    mov   rax , 7
    mov   rbx , [pidx]
    shl   rbx , 32
    mov   rcx , 7 shl 32 + scalex*4/4
    add   rbx , rcx
    mov   rcx , (9+imagey) shl 32 + scaley*4/4
    mov   r8  , 0
    mov   r9  , 0x1000000
    mov   r10 , 3
    int   0x60

    ; Clear area

    mov   rax , 13
    mov   rbx , [pidx]
    shl   rbx , 32
    mov   rcx , 7 shl 32 + scalex
    add   rbx , rcx
    mov   rcx , (imagey+scaley+9) shl 32 + 16
    mov   rdx , 0 ; xf8f8f8
    int   0x60

    ; Draw name

    mov   rdx , [rsp]
    imul  rdx , 32
    add   rdx , application_names

    mov   [rdx+15],byte 0
    mov   rsi , rdx
  findend:
    cmp   [rsi],byte 0
    je    endfound
    inc   rsi
    jmp   findend
  endfound:

    sub   rsi , rdx
    imul  rsi , 3

    push  rsi
    mov   rax , 4
    mov   rbx , rdx
    mov   rcx , scalex / 2
    add   rcx , 8+1
    sub   rcx , rsi
    add   rcx , [pidx]
    mov   rdx , scaley+12
    add   rdx , imagey

    push  rax rbx
    mov   rax , 141
    mov   rbx , 3
    int   0x60
    cmp   ax , 10
    jbe   yfine
    add   rdx , 1
  yfine:
    pop   rbx rax

    mov   r9  , 1
    mov   rsi , 0xffffff
    int   0x60
    pop   rsi

    mov   rax , 125
    mov   rbx , 3
    int   0x60
    cmp   rax , 0
    jne   no_enable_text

    mov   rax , 4
    mov   rbx , enable_transparency
    mov   rcx , scalex / 2
    add   rcx , [pidx]
    sub   rcx , 50
    mov   rdx , scaley/2
    add   rdx , imagey
    mov   r9  , 1
    mov   rsi , 0xa0a0a0
    int   0x60
    mov   rbx , enable_transparency_2
    add   rdx , 14
    int   0x60

  no_enable_text:

    pop   rax

    if    enable3d
    jmp   do3d
    end if

    push  rax

    ; Draw image at left

    mov   rdx , rax
    dec   rdx
    imul  rdx , scalex*scaley*3+1000
    add   rdx , application_images

    mov   rax , 7
    mov   rbx , 7 shl 32 + scalex*4/4
    mov   rcx , (9+imagey) shl 32 + scaley*4/4
    mov   r8  , 0
    mov   r9  , 0x1000000
    mov   r10 , 3
    int   0x60

    ; Clear area

    mov   rax , 13
    mov   rbx , [pidx]
    shl   rbx , 32
    mov   rcx , 7 shl 32 + scalex
    add   rbx , rcx
    mov   rcx , (imagey+scaley+9) shl 32 + 13
    mov   rdx , 0 ; xf8f8f8
    int   0x60

    ; Draw name

    mov   rdx , [rsp]
    imul  rdx , 32
    add   rdx , application_names

    mov   [rdx+15],byte 0
    mov   rsi , rdx
  findend2:
    cmp   [rsi],byte 0
    je    endfound2
    inc   rsi
    jmp   findend2
  endfound2:

    sub   rsi , rdx
    imul  rsi , 3

    mov   rax , 4
    mov   rbx , rdx
    mov   rcx , scalex / 2
    add   rcx , 8+1
    sub   rcx , rsi
    add   rcx , [pidx]
    mov   rdx , scaley+12
    add   rdx , imagey
    mov   r9  , 1
    mov   rsi , 0xffffff
    int   0x60

  noleft2:

    pop   rax

    push  rax

    ; Draw image at right

    mov   rdx , rax
    inc   rdx
    imul  rdx , scalex*scaley*3+1000
    add   rdx , application_images

    mov   rax , 7
    mov   rbx , (7+scalex*2) shl 32 + scalex*4/4
    mov   rcx , (9+imagey) shl 32 + scaley*4/4
    mov   r8  , 0
    mov   r9  , 0x1000000
    mov   r10 , 3
    int   0x60

    ; Clear area

    mov   rax , 13
    mov   rbx , [pidx]
    mov   rbx , scalex*2
    shl   rbx , 32
    mov   rcx , 7 shl 32 + scalex
    add   rbx , rcx
    mov   rcx , (imagey+scaley+9) shl 32 + 13
    mov   rdx , 0 ; xf8f8f8
    int   0x60

    ; Draw name

    mov   rdx , [rsp]
    imul  rdx , 32
    add   rdx , application_names

    mov   [rdx+15],byte 0
    mov   rsi , rdx
  findend3:
    cmp   [rsi],byte 0
    je    endfound3
    inc   rsi
    jmp   findend3
  endfound3:

    sub   rsi , rdx
    imul  rsi , 3

    mov   rax , 4
    mov   rbx , rdx
    mov   rcx , scalex / 2
    add   rcx , 8+1
    sub   rcx , rsi
    add   rcx , [pidx]
    mov   rdx , scaley+12
    add   rdx , imagey
    mov   r9  , 1
    mov   rsi , 0xffffff
    int   0x60

    pop   rax

    ret

  do3d:

    ; Draw applications at left

    mov   rax , [selected]
    cmp   rax , 1
    jbe   no_app_left

    mov   rax , 1

    ; Max 5 windows at left

    cmp   [selected],dword 6-maxw
    jbe   raxfine
    mov   rax , [selected]
    sub   rax , 5-maxw
  raxfine:


  newleft:

    push  rax

    mov   rdx , rax
    imul  rdx , scalex*scaley*3+1000
    add   rdx , application_images

    mov   rbx , 0
    mov   rcx , 0
  pixl1:
    push  rbx rcx
    imul  rbx , 3
    imul  rcx , 3*scalex
    add   rbx , rcx
    mov   rax , [rdx+rbx]
    pop   rcx rbx

    push  rbx rcx rdx

    mov   rdx , rax
    mov   rax , 1

    ; Scale Y according to X

    push  rax rbx rdx
    mov   rdx , scalex*4
    sub   rdx , rbx
    push  rbx
    imul  rcx , rdx
    mov   rax , rcx
    xor   rdx , rdx
    mov   rbx , scalex*2
    div   rbx
    mov   rcx , rax
    pop   rbx
    shr   rbx , 2
    add   rcx , rbx
    shr   rcx , 1
    pop   rdx rbx rax

    shr   rbx , 1

    sub   rbx , scalex/2

    mov   r10 , [selected]
    mov   r9  , [rsp+8*3]
    sub   r9  , r10
    imul  r9  , step3d

    add   rbx , r9

    add   rcx , 1

    imul  rcx , 3
    imul  rcx , scalex
    imul  rbx , 3

    add   rbx , rcx
    and   rbx , 0x1fffff

    mov   [app_left+rbx],dx
    ror   rdx , 16
    mov   [app_left+rbx+2],dl
    rol   rdx , 16
    add   rbx , scalex*3
    mov   [app_left+rbx],dx
    ror   rdx , 16
    mov   [app_left+rbx+2],dl

    pop   rdx rcx rbx

    add   rbx , 1
    cmp   rbx , scalex
    jb    pixl1

    mov   rbx , 0

    add   rcx , 1
    cmp   rcx , scaley
    jb    pixl1

    pop   rax

    inc   rax

    mov   rbx , [selected]

    cmp   rax , rbx
    jb    newleft

  no_app_left:

    mov   rax , 7
    mov   rbx , 8 shl 32 + scalex
    mov   rcx , (8+imagey) shl 32 + scaley
    mov   rdx , app_left
    mov   r8  , 0
    mov   r9  , 0x1000000
    mov   r10 , 3
    int   0x60

    ; Draw application at right

    mov   rax , [selected]
    cmp   rax , [windows]
    jae   no_app_right

    mov   rax , [windows]

    ; Max 5 windows at right

    mov   rbx , [windows]
    sub   rbx , [selected]

    cmp   rbx , 6-maxw
    jb    raxfine2
    mov   rax , [selected]
    add   rax , 5-maxw
  raxfine2:


  newright:

    push  rax

    mov   rdx , rax
    imul  rdx , scalex*scaley*3+1000
    add   rdx , application_images

    mov   rbx , 0
    mov   rcx , 0
  pixl1r:
    push  rbx rcx
    imul  rbx , 3
    imul  rcx , 3*scalex
    add   rbx , rcx
    mov   rax , [rdx+rbx]
    pop   rcx rbx

    push  rbx rcx rdx

    mov   rdx , rax
    mov   rax , 1

    ; Scale Y according to X

    push  rax rbx rdx
    mov   rdx , scalex*4
    sub   rdx , rbx
    mov   rdx , rbx
    add   rdx , scalex*3
    push  rbx
    imul  rcx , rdx
    mov   rax , rcx
    xor   rdx , rdx
    mov   rbx , scalex*2
    div   rbx
    mov   rcx , rax
    pop   rbx
    shr   rbx , 2
    mov   rax , scalex/4
    sub   rax , rbx
    add   rcx , rax
    shr   rcx , 1
    pop   rdx rbx rax

    shr   rbx , 1

    mov   r9  , [selected]
    mov   r10 , [rsp+8*3]
    sub   r10 , r9
    imul  r10 , step3d

    add   rbx , r10

    imul  rcx , 3
    imul  rcx , scalex
    imul  rbx , 3

    add   rbx , rcx
    and   rbx , 0x1fffff

    mov   [app_right+rbx],dx
    ror   rdx , 16
    mov   [app_right+rbx+2],dl
    rol   rdx , 16
    add   rbx , scalex*3
    mov   [app_right+rbx],dx
    ror   rdx , 16
    mov   [app_right+rbx+2],dl
    rol   rdx , 16

    pop   rdx rcx rbx

    add   rbx , 1
    cmp   rbx , scalex
    jb    pixl1r

    mov   rbx , 0

    add   rcx , 1
    cmp   rcx , scaley
    jb    pixl1r

    pop   rax

    dec   rax

    mov   rbx , [selected]

    cmp   rax , rbx
    ja    newright

  no_app_right:

    mov   rax , 7
    mov   rbx , (8+(scalex)*2) shl 32 + scalex
    mov   rcx , (8+imagey) shl 32 + scaley
    mov   rdx , app_right
    mov   r8  , 0
    mov   r9  , 0x1000000
    mov   r10 , 3
    int   0x60

    ret


; Data

preview_running:  dq  0x0
previewx:         dq  0x0
previewy:         dq  0x0

pidx:             dq  0x0
topsub:           dq  0x0
prevpix:          dq  0x0
delaycount:       dq  0x0

windows:             dq 0x0
windows_minimized:   dq 0x0
selected:            dq 0x1

enable_transparency:     db  'Enable transparency',0
enable_transparency_2:   db  'for window preview.',0

application_names:   times 32*70  db  ?
application_pids:    times 70     dq  ?

image_end:

