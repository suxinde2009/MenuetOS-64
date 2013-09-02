;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Icon for Menuet64
;
;   Compile with FASM 1.60 or above
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use64

    db    'MENUET64'         ; 8 byte id
    dq    0x01               ; header version
    dq    START              ; start of code
    dq    IMAGE_END          ; size of image
    dq    0x100000           ; memory for app
    dq    0x0ffff0           ; rsp
    dq    Param              ; Param
    dq    0x0                ; Icon

image_invert      equ   image_base + 10000
icon_background   equ   image_base + 20000
shape_map         equ   image_base + 40000
background_base   equ   image_base + 60000

winx equ  48
winy equ  61
xp   equ  ((winx-48)/2)

rex  equ  r8
rfx  equ  r9
rgx  equ  r10
rhx  equ  r11
rix  equ  r12
rjx  equ  r13
rkx  equ  r14
rlx  equ  r15

START:

    ; System font

    mov   rax , 141
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    ; Window shape

    call  create_shape_map

    ; IPC

    mov   rax , 60
    mov   rbx , 1
    mov   rcx , ipcarea
    mov   rdx , 20
    int   0x60

    ; Drag n drop

    mov   rax , 121
    mov   rbx , 1
    mov   rcx , dragndrop
    mov   rdx , 250
    int   0x60

    mov   [dragndrop],byte 0
              
    ; Events

    mov   rax , 40
    mov   rbx , 10111b
    int   0x60

    call  get_parameters
    call  get_sysdir
    call  load_icon
    call  calculate_icon_background

    call  draw_window

still:

    mov   rax , 23
    mov   rbx , 2
    int   0x60

    cmp   [ipcarea+16],byte 0
    jne   terminate
    cmp   [dragndrop],byte 0
    je    nodnd
    mov   rax , 256
    mov   rbx , Param + 8 + 36
    mov   rcx , dragndrop
    jmp   start_app
  nodnd:

    test  rax , 1b
    jnz   redraw

    test  rax , 10b
    jnz   key_event

    test  rax , 100b
    jnz   button

    test  rax , 10000b
    jnz   read_background

    jmp   still

key_event:

    mov   rax , 2
    int   0x60

    jmp   still

button:

    mov   rax , 17
    int   0x60

    ; rax = status
    ; rbx = button id

    mov   rax , 256
    mov   rbx , Param + 8 + 36
    mov   rcx , [app_param]

  start_app:

    mov   rex , rbx
    call  check_for_sysdir
    mov   rbx , rex

    int   0x60

    call  spin_icon

    mov   [dragndrop],byte 0

    jmp   still

redraw:

    call  draw_window
    jmp   still

terminate:

    mov   rax , 512
    int   0x60

read_background:

    call  calculate_icon_background
    call  draw_window

    jmp   still

create_shape_map:

    mov   rdi , shape_map
    mov   rcx , winx
    imul  rcx , winy
    mov   rax , 1
    cld
    rep   stosb

    mov   rdi , shape_map
    mov   rax , shape_map + winy*winx -1
    mov   rsi , edges
  shapel0:
    cmp   [rsi],byte 0
    je    shapel1
    mov   [rdi],byte 0
    mov   [rax],byte 0
  shapel1:
    inc   rsi
    inc   rdi
    dec   rax
    cmp   rsi , edges + winx*5
    jb    shapel0

    mov   rax , 50
    mov   rbx , 0
    mov   rcx , shape_map
    int   0x60

    ret


check_for_sysdir:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Description: Add system directory to path
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    cmp  [rex] , dword 'SYSD'
    je    cfsl1
    ret
  cfsl1:

    push  rax
    push  rbx
    push  rcx

    mov   rsi , rex
    add   rsi , 7
    mov   rdi , savedir
    mov   rcx , 50
    cld
    rep   movsb

    mov   rdi , newfile
    mov   rsi , savedir
    call  withsysdir

    pop   rcx
    pop   rbx
    pop   rax

    mov   rex , newfile

    ret

get_parameters:

    ; Do we have parameters

    cmp   [Param+8],word 'xx'
    jne   yespar
    mov   rax , 512
    int   0x60
  yespar:

    ;
    mov   rax , 26
    mov   rbx , 3
    mov   rcx , IMAGE_END
    mov   rdx , 256
    int   0x60

    ; X
    mov   rax , [IMAGE_END+4*8]
    mov  [graphics_x],rax

    ; Y
    mov   rax , [IMAGE_END+5*8]
    mov  [graphics_y],rax

    ;
    mov  [13+Param+8], byte 0
    mov  [34+Param+8], byte 0

    ; Mark application as asciiz

    mov   rdi , 38+Param+8
   mzl:
    inc   rdi
    cmp  [rdi], byte ' '
    jne   mzl
    mov  [rdi], byte 0

    ; Do we have a parameter for the application ?

    mov   [app_param],dword 0
    cmp  [rdi+1],byte 32
    jbe   noparameter
    cmp  [rdi+1],byte '-'
    je    noparameter
    inc   rdi
    mov   [app_param],rdi
    ; Mark as asciiz
    mov   rax , rdi
    add   rax , 256
   mzl2:
    inc   rdi
    cmp   rdi , rax
    ja    mzl3
    cmp  [rdi], byte '-'
    je    mzl3
    cmp  [rdi], byte ' '
    ja    mzl2
  mzl3:
    mov  [rdi], byte 0
  noparameter:

    ; X position
    mov   rbx , [Param+8]
    and   rbx , 0xff
    sub   rbx , 65
    cmp   rbx , 4   ; 0..4,5..9
    jbe   xlower
    sub   rbx , 5
    mov   rax , 4
    sub   rax , rbx
    mov   rbx , rax
    imul  rbx , 70
    add   rbx , 20+48
    mov   rax , [graphics_x]
    sub   rax , rbx
    mov   rbx , rax
    sub   rbx , xp
    jmp   setx
  xlower:
    imul  rbx , 70
    add   rbx , 20-xp
  setx:
    mov  [icon_x],rbx

    ; Y position
    mov   rcx , [Param+8+1]
    and   rcx , 0xff
    sub   rcx , 65
    call  get_menu_position
    cmp   rcx , 4   ; 0..4,5..9
    jbe   ylower
    sub   rcx , 5
    mov   rax , 4
    sub   rax , rcx
    mov   rcx , rax
    imul  rcx , 70
    add   rcx , 74
    mov   rax , [graphics_y]
    sub   rax , rcx
    mov   rcx , rax
    cmp   [position],byte 1 
    jne   nopos11
    sub   rcx , 30
  nopos11:
    jmp   sety
  ylower:
    imul  rcx , 70
    add   rcx , 55
    cmp   [position],byte 1 
    jne   nopos1
    sub   rcx , 40
  nopos1:
  sety:
    mov  [icon_y],rcx

    ret


get_menu_position:

    push  rax rbx rcx rdx r8 r9 r10 r11 r12 r13 r14 r15 rsi rdi rbp

    mov   [position],byte 0

    mov   r15 , 0

  til1:

    mov   rax , 9
    mov   rbx , 1
    mov   rcx , r15
    mov   rdx , 0x40000     
    mov   r8  , 1024
    int   0x60

    cmp   [0x40000+288],byte 0
    jne   notermicon

    mov   eax , 'MENU'     
    cmp   [0x40000+408+6],eax
    jne   notermicon

    cmp   [0x40000+8],dword 0
    je    notermicon

    mov   [position],byte 1

  notermicon: 

    inc   r15

    cmp   r15 , 64
    jbe   til1

    pop   rbp rdi rsi r15 r14 r13 r12 r11 r10 r9 r8 rdx rcx rbx rax

    ret


spin_icon:

    call  icon_delay
    mov   rax , 7                           ; draw image
    mov   rbx ,(xp+16) *0x100000000 + 16    ; x start & size
    mov   rcx , 6 *0x100000000 + 32         ; y start & size
    mov   rdx , image_base + 54 + 32*31*3   ; first pixel location
    mov   rex , -32*3 *2                    ; scanline difference
    mov   rfx , 0x000000                    ; tansparency color
    mov   rgx , 6
    int   0x60
    call  icon_delay
    mov   rax , 7                           ; draw image
    mov   rbx ,(xp+20) *0x100000000 + 8     ; x start & size
    mov   rcx , 6 *0x100000000 + 32         ; y start & size
    mov   rdx , image_base + 54 + 32*31*3   ; first pixel location
    mov   rex , -32*3 *2                    ; scanline difference
    mov   rfx , 0x000000                    ; transparency color
    mov   rgx , 12                          ; pixel alignment
    int   0x60
    call  icon_delay
    mov   rax , 7                           ; draw image
    mov   rbx ,(xp+20) *0x100000000 + 8     ; x start & size
    mov   rcx , 6 *0x100000000 + 32         ; y start & size
    mov   rdx , image_invert + 54 + 32*32*3 ; first pixel location
    mov   rex , 0                           ; scanline difference
    mov   rfx , 0x000000                    ; transparency color
    mov   rgx , -12
    int   0x60
    call  icon_delay
    mov   rax , 7                           ; draw image
    mov   rbx ,(xp+16) *0x100000000 + 16    ; x start & size
    mov   rcx , 6 *0x100000000 + 32         ; y start & size
    mov   rdx , image_invert + 54 + 32*32*3 ; first pixel location
    mov   rex , 0                           ; scanline difference
    mov   rfx , 0x000000                    ; transparency color
    mov   rgx , -6                          ; pixel alignment
    int   0x60
    call  icon_delay
    ; Full back
    mov   rax , 7                           ; draw image
    mov   rbx ,(xp+8) *0x100000000 + 32     ; x start & size
    mov   rcx , 6 *0x100000000 + 32         ; y start & size
    mov   rdx , image_invert + 54 + 32*32*3 ; first pixel location
    mov   rex , 0                           ; scanline difference
    mov   rfx , 0x000000                    ; transparency color
    mov   rgx , -3                          ; pixel alignment
    int   0x60
    call  icon_delay
    mov   rax , 7                           ; draw image
    mov   rbx ,(xp+16) *0x100000000 + 16    ; x start & size
    mov   rcx , 6 *0x100000000 + 32         ; y start & size
    mov   rdx , image_invert + 54 + 32*32*3 ; first pixel location
    mov   rex , 0                           ; scanline difference
    mov   rfx , 0x000000                    ; transparency color
    mov   rgx , -6                          ; pixel alignment
    int   0x60
    call  icon_delay
    mov   rax , 7                           ; draw image
    mov   rbx ,(xp+20) *0x100000000 + 8     ; x start & size
    mov   rcx , 6 *0x100000000 + 32         ; y start & size
    mov   rdx , image_invert + 54 + 32*32*3 ; first pixel location
    mov   rex , 0                           ; scanline difference
    mov   rfx , 0x000000                    ; transparency color
    mov   rgx , -12                         ; pixel alignment
    int   0x60
    call  icon_delay
    mov   rax , 7                           ; draw image
    mov   rbx ,(xp+20) *0x100000000 + 8     ; x start & size
    mov   rcx , 6 *0x100000000 + 32         ; y start & size
    mov   rdx , image_base + 54 + 32*31*3   ; first pixel location
    mov   rex , -32*3 *2                    ; scanline difference
    mov   rfx , 0x000000                    ; tansparency color
    mov   rgx , 12
    int   0x60
    call  icon_delay
    mov   rax , 7                           ; draw image
    mov   rbx ,(xp+16) *0x100000000 + 16    ; x start & size
    mov   rcx , 6 *0x100000000 + 32         ; y start & size
    mov   rdx , image_base + 54 + 32*31*3   ; first pixel location
    mov   rex , -32*3 *2                    ; scanline difference
    mov   rfx , 0x000000                    ; transparency color
    mov   rgx , 6                           ; pixel alignment
    int   0x60
    call  icon_delay
    ; Back to original
    mov   rax , 7                           ; draw image
    mov   rbx ,(xp+8) *0x100000000 + 32     ; x start & size
    mov   rcx , 6 *0x100000000 + 32         ; y start & size
    mov   rdx , image_base + 54 + 32*31*3   ; first pixel location
    mov   rex , -32*3 *2                    ; scanline difference
    mov   rfx , 0x000000                    ; transparency color
    mov   rgx , 3                           ; pixel alignment
    int   0x60

    ret


icon_delay:

    mov   rax , 5
    mov   rbx , 4
    int   0x60

    mov   rax , 7                           ; draw image
    mov   rbx , 0 *0x100000000 + winx       ; x start & size
    mov   rcx , 0 *0x100000000 + 38         ; y start & size
    mov   rdx , icon_background             ; first pixel location
    mov   rex , 0                           ; scanline difference
    mov   rfx , 0x1000000                   ; tansparency color
    mov   rgx , 3                           ; pixel alignment
    int   0x60

    ret


draw_window:

    mov   rax , 12
    mov   rbx , 1
    int   0x60

    ; Get configuration parameter
    mov   rax , 112
    mov   rbx , 2
    mov   rcx , string_icon_font
    mov   rdx , 0
    mov   r8  , 0xfffff
    int   0x60
    mov   [fonttype],rbx

    ; X position
    mov   rbx , [icon_x]
    shl   rbx , 32

    ; Y position
    mov   rcx , [icon_y]
    shl   rcx , 32

    mov   rax , 0                           ; draw window
    add   rbx , winx                        ; x start & size
    add   rcx , winy                        ; y start & size
    mov   rdx , 1 *0x100000000 + 0xffffff   ; type    & border color
                                            ; type 1 = do not draw
    mov   rex , 1b                          ; draw buttons - close,full,minimiz
    mov   rfx , 0                           ; 0 or label - asciiz
    mov   rgx , 0                           ; pointer to menu struct or 0
    int   0x60

    ; Draw icon background

    mov   rax , 7                           ; draw image
    mov   rbx , 0 *0x100000000 + winx       ; x start & size
    mov   rcx , 0 *0x100000000 + winy       ; y start & size
    mov   rdx , icon_background             ; first pixel location
    mov   rex , 0                           ; scanline difference
    mov   rfx , 0x1000000                   ; tansparency color
    mov   rgx , 3                           ; pixel alignment
    int   0x60

    ; Icon button
    mov   rax , 8                           ; button
    mov   rbx , 0 *0x100000000 + winx       ; x start & size
    mov   rcx , 0 *0x100000000 + winy       ; y start & size
    mov   rdx , 0x1                         ; button id
    mov   rex , 0xA000000000000000          ; flags and color
    mov   rfx , 0
    int   0x60

    mov   rax , 7                           ; draw image
    mov   rbx , (xp+8) *0x100000000 + 32    ; x start & size
    mov   rcx , 6 *0x100000000 + 32         ; y start & size
    mov   rdx , image_base + 54 + 32*31*3   ; first pixel location
    mov   rex , -32*3 *2                    ; scanline difference
    mov   rfx , 0x000000                    ; tansparency color
    mov   rgx , 3
    int   0x60

    ; Search icon name length

    mov   r15 , Param + 8 + 5
    dec   r15
  inl1:
    inc   r15
    cmp  [r15], byte 32
    ja    inl1
    mov  [r15], byte 0
    sub   r15 , Param + 8 + 5

    imul  r15 , 3
    and   r15 , 0x1f

    call  adjust_string

    mov   rax , 4                           ; Black text
    mov   rbx , icon_text
    mov   rcx , (xp+26)
    sub   rcx , r15
    mov   rdx , 47
    mov   rsi , 0x000000
    mov   rfx , 1
    int   0x60

    mov   rax , 4                           ; White text
    mov   rbx , icon_text
    mov   rcx , (xp+25)
    sub   rcx , r15
    mov   rdx , 46
    mov   rsi , 0xffffff
    mov   rfx , 1
    int   0x60

    mov   rax , 12
    mov   rbx , 2
    int   0x60

    ret


adjust_string:

    push    rcx rsi rdi

    mov     rsi , Param + 8 + 5
    mov     rdi , icon_text
    mov     rcx , 8
    cld
    rep     movsb

    cmp     [fonttype],dword 0
    je      nofadjust

    mov     rsi , icon_text
    cmp     [rsi],byte 0
    je      nofadjust

    cmp     [fonttype],dword 1
    jne     noftype1
    inc     rsi
    cmp     [rsi],byte 0
    je      nofadjust
  noftype1:

  newadjust:

    cmp     [rsi],byte 0
    je      nofadjust
    cmp     [rsi],byte 'A'
    jb      noadj
    cmp     [rsi],byte 'Z'+3
    ja      noadj
    add     [rsi],byte 32
  noadj:
    inc     rsi
    cmp     rsi , icon_text+8
    jbe     newadjust

  nofadjust:

    pop     rdi rsi rcx

    ret




load_icon:

    mov   rfx , Param + 8 + 16   ; name pointer

    mov   rex , rfx
    call  check_for_sysdir
    mov   rfx , rex

    mov   rax , 58               ; FileSYS
    mov   rbx , 0                ; Read
    mov   rcx , 0                ; first block to read
    mov   rdx , -1               ; blocks to read
    mov   rex , image_base       ; return pointer
    int   0x60

    ;call  soften_image

    mov   rsi , image_base
    mov   rdi , image_invert
    mov   rcx , 5000
    cld
    rep   movsb

    mov   rdi , image_invert
    mov   rcx , 32*32*3+200

  newpix:

    mov   rax ,[rdi]
    and   rax , 0xffffff
    shr   rax , 1
    and   rax , 0x7f7f7f
    mov  [rdi], ax
    shr   rax , 16
    mov  [rdi+2], al

    add   rdi , 3

    loop  newpix

    ret

if 0=1
soften_image:

    mov   rdi , image_base + 54

  sil1:

    mov   rax , [rdi]
    and   rax , 0xffffff
    mov   rbx , [rdi+3]
    and   rbx , 0xffffff
    mov   rcx , [rdi+6]
    and   rcx , 0xffffff

    mov   rdx , [rdi-3]
    and   rdx , 0xffffff
    cmp   rdx , 0
    jne   nofirstblack
    cmp   rax , 0
    jne   nofirstblack
    cmp   rbx , 0
    je    nofirstblack
    cmp   rcx , 0
    je    nofirstblack
    call  soften_middle_pixel
  nofirstblack:

    mov   rdx , [rdi+9]
    and   rdx , 0xffffff
    cmp   rdx , 0
    jne   nolastblack
    cmp   rcx , 0
    jne   nolastblack
    cmp   rbx , 0
    je    nolastblack
    cmp   rax , 0
    je    nolastblack
    call  soften_middle_pixel
  nolastblack:

    add   rdi , 3
    cmp   rdi , image_base + 54 + 32*32*3
    jbe   sil1

    ret

soften_middle_pixel:

    push  rax rbx rcx

    shr   rax , 1
    shr   rbx , 1
    and   rax , 0x7f7f7f
    and   rbx , 0x7f7f7f
    add   rax , rbx

    mov   [rdi+3],ax
    shr   rax , 16
    mov   [rdi+5],al

    pop   rcx rbx rax

    ret
end if

calculate_icon_background:

    ; Background size

    mov   rax , 15
    mov   rbx , 13
    int   0x60

    mov   rbx , rax
    shr   rax , 32
    and   rbx , 0xfffffff
    mov  [bgr_x],rax
    mov  [bgr_y],rbx

    ;

    mov   rax , 0
    mov   rbx , 0

    mov   rlx , icon_background

  newbpix:

    push  rax
    push  rbx

    add   rax , [icon_x]
    add   rbx , [icon_y]

    mov   rcx ,[bgr_x]
    imul  rax , rcx
    mov   rdx , 0

    mov   rcx ,[graphics_x]
    div   rcx     
    mov   rcx , 3
    imul  rax , rcx

    push  rax

    mov   rax , rbx
    mov   rcx ,[bgr_y]
    imul  rax , rcx
    mov   rdx , 0

    mov   rcx ,[graphics_y]
    div   rcx      
    mov   rcx , 3
    imul  rax , rcx

    mov   rcx ,[bgr_x]

    imul  rax , rcx

    pop   rbx

    add   rax , rbx
    mov   rcx , rax         ; source

    mov   rax , 15
    mov   rbx , 12          ; get background
    mov   rdx , 3           ; bytes to return
    mov   rex , background_base
    int   0x60

    mov   rcx ,[background_base]
    and   rcx , 0xffffff

    mov   [rlx], ecx

    mov   rsi , [rsp+8]
    mov   rdi , [rsp+0]
    cmp   rdi , 5
    jae   noedge
    imul  rdi , winx
    add   rdi , rsi
    cmp   [rdi+edges],byte 1
    je    nodarken
  noedge:

    mov   rsi , [rsp+8]
    mov   rdi , [rsp+0]
    cmp   rdi , (winy-1)-5
    jbe   noedge2
    mov   rax , (winy-1)
    sub   rax , rdi
    mov   rdi , rax
    imul  rdi , winx
    add   rdi , rsi
    cmp   [rdi+edges],byte 1
    je    nodarken
  noedge2:

    mov   r8  , 8 ; Full bgr
    cmp   [Param+11],byte '-'
    je    fullbgr
    mov   r8  , 8
    movzx rax , byte [Param+11]
    sub   rax , 48
    sub   r8  , rax 
  fullbgr:

    xor   rax , rax
    mov   al , cl
    imul  rax , r8
    shr   rax , 3
    mov   [rlx+0],al

    shr   rcx , 8

    xor   rax , rax
    mov   al , cl
    imul  rax , r8
    shr   rax , 3
    mov   [rlx+1],al

    shr   rcx , 8

    xor   rax , rax
    mov   al , cl
    imul  rax , r8
    shr   rax , 3
    mov   [rlx+2],al

  nodarken:

    pop   rbx
    pop   rax

    add   rlx , 3

    add   rax , 1
    cmp   rax , winx
    jb    newbpix

    mov   rax , 0

    add   rbx , 1
    cmp   rbx , winy
    jb    newbpix

    ret

get_sysdir:

    mov   rax , 112
    mov   rbx , 1
    mov   rcx , sys_parameter
    mov   rdx , 128
    mov   rex , sysdir
    int   0x60

    ret

withsysdir:

    push  rsi

    mov   rsi , sysdir
  newsearch:
    mov   al , [rsi]

    cmp   al , byte 0
    je    outsearch

    mov  [rdi],al

    inc   rsi
    inc   rdi

    jmp   newsearch

  outsearch:

    pop   rsi
    mov   rcx , 12
    cld
    rep   movsb

    ret

edges:

    db  1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    times (winx-48) db 0
    db  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1
    db  1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    times (winx-48) db 0
    db  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1
    db  1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    times (winx-48) db 0
    db  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1
    db  1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    times (winx-48) db 0
    db  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
    db  1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    times (winx-48) db 0
    db  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1

color_black: dd 0x000000

position: dq 0

ipcarea:

    dq    0
    dq    16
    times 20 db 0

app_param:    dq   0x0
icon_x:       dq   0x0
icon_y:       dq   0x0
bgr_x:        dq   0x0
bgr_y:        dq   0x0
graphics_x:   dq   640
graphics_y:   dq   480

string_icon_font:

              db 'icon_font           ',0

fonttype:     dq 0x0

Param:  dq    80
        db   'xx t  FRACT1  - /RD/1/HD      BMP -'
        db   ' /RD/1/FRACT                    - *'
        dq   0,0,0,0,0

sys_parameter: db   'system_directory',0

IMAGE_END:  db 123
            times 2048 db ?

dragndrop:  times  256 db ?
savedir:    times   60 db ?
newfile:    times  256 db ?
sysdir:     times  128 db ?
icon_text:  times  256 db ?

image_base:

