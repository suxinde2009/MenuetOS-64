;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Desktop icons and setup
;
;   Compile with FASM
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

config_data equ 0x100000

fx    equ  20
fy    equ  332

use64

    org    0x0

    db     'MENUET64'              ; 8 byte id
    dq     0x01                    ; header version
    dq     START                   ; start of code
    dq     I_END                   ; size of image
    dq     0x200000                ; memory for app
    dq     0x7fff0                 ; esp
    dq     I_Param , 0x0           ; I_Param , I_Icon

include 'textbox.inc'

START:

    mov  rax , 141
    mov  rbx , 1
    mov  rcx , 1
    mov  rdx , 5 shl 32 + 5
    mov  r8  , 9 shl 32 + 12
    int  0x60

    mov  rdi , icon_data
    mov  rcx , 72*200
    mov  rax , 0
    cld
    rep  stosb

    call get_menu_position

    call load_icon_list

    call check_parameters

    call draw_window            ; at first, draw the window

still:

    mov  eax , 23                 ; wait here for event
    mov  ebx , 50
    int  0x40

    cmp  eax,1                  ; redraw request ?
    je   red
    cmp  eax,2                  ; key in buffer ?
    je   key
    cmp  eax,3                  ; button in buffer ?
    je   button

    call check_ipc

    jmp  still

  red:                          ; redraw
    call draw_window
    jmp  still

  key:                          ; key
    mov  eax,2                  ; just read it and ignore
    int  0x40
    jmp  still

  button:                       ; button
    mov  eax,17                 ; get id
    int  0x40

    shr  eax,8

    cmp  eax , 27
    jne  nobgr

    mov  [dialog_wait],byte 1

    call dialog_open
    jmp  still

  dialog_wait: dq 0

  nobgr:

    cmp  eax , 28
    jne  noskin

    mov  [dialog_wait],byte 2

    call dialog_open
    jmp  still

  noskin:

    cmp  eax , 26
    jne  nomainmenuposchange

    mov  [positionchanged],byte 1

    inc  byte [position]
    and  byte [position],byte 1

    call draw_position_button

    jmp  still

  nomainmenuposchange:

    cmp  eax , 29
    jne  noiconbgr

    inc  byte [transparency]
    cmp  dword [transparency],dword 8
    jbe  trfine
    mov  byte [transparency], 0
  trfine:

    call draw_icon_transparency_button

    jmp  still

  noiconbgr:

    cmp  eax , 111
    jne  no_textbox1
    mov  r14 , textbox1
    call empty_textbox
    call read_textbox
    call set_values
    jmp  still
  no_textbox1:
    cmp  eax , 112
    jne  no_textbox2
    mov  r14 , textbox2
    call empty_textbox
    call read_textbox
    call set_values
    jmp  still
  no_textbox2:
    cmp  eax , 113
    jne  no_textbox3
    mov  r14 , textbox3
    call empty_textbox
    call read_textbox
    call set_values
    jmp  still
  no_textbox3:

    cmp  eax,1                  ; button id=1 ?
    jne  noclose
    mov  eax,-1                 ; close this program
    int  0x40
  noclose:

    cmp  eax,21                 ; apply changes
    jne  no_apply

    ; Add transparency marker

    call add_transparency_marker

    ; Save changes to config.mnt

    call modify_config_mnt

    ; Delete file

    mov  rax , 58
    mov  rbx , 2
    mov  r9  , icon_mnt
    int  0x60

    ; Save file

    mov  rax , 58
    mov  rbx , 1
    mov  rcx , 0
    mov  edx , [icons]
    imul edx , 72
    and  rdx , 0xfffff
    mov  r8  , icon_data
    mov  r9  , icon_mnt
    int  0x60

    call terminate_icons

    mov  rax , 5
    mov  rbx , 20
    int  0x60

    call  respond_to_window_draw

    cmp  [positionchanged],byte 1
    jne  nomenumove

    call move_mainmenu

    mov  rcx , 35 ; Wait and respond to window requests
  waitmove:
    push rcx
    mov  rax , 5
    mov  rbx , 10
    int  0x60
    call respond_to_window_draw
    pop  rcx
    loop waitmove

    mov  [positionchanged],byte 0

  nomenumove:

    call load_background

    call start_icons

    ;call load_background

    call load_skin

    call draw_background_skin_info

    jmp  still

  no_apply:

    ; Cancel

    cmp  eax , 30
    jne  nohalt

    mov  rax , 512
    int  0x60

  nohalt:

    ; Move icon

    cmp  eax,24
    jne  noiconmove

    mov  eax,13
    mov  ebx,24*65536+250
    mov  ecx,250*65536+10
    mov  edx,0xf0f0f0
    int  0x40
    mov  eax,4
    mov  ebx,24*65536+252
    mov  ecx,0xff0000
    mov  edx,move_text
    mov  esi,move_text_len-move_text
    int  0x40

    mov  eax,10
    int  0x40
    cmp  eax,3
    jne  no_found2
    mov  eax,17
    int  0x40
    shr  eax,8
    cmp  eax,40
    jb   no_found2
    sub  eax,40

    xor  edx,edx
    mov  ebx,16
    div  ebx
    imul eax,10
    add  eax,edx

    mov  ebx,eax
    add  ebx,icons_reserved
    cmp  [ebx],byte 'x'
    jne  no_found2

    mov  [ebx],byte ' '

    xor  edx,edx
    mov  ebx,10
    div  ebx
    shl  eax,8
    mov  al,dl

    add  eax,65*256+65

    mov  esi,icon_data
    mov  edi,72
    imul edi,[icons]
    add  edi,icon_data
  news2:
    cmp  word [esi],ax
    je   foundi2
    add  esi,72
    cmp  esi,edi
    jb   news2
    jmp  no_found2
  foundi2:

    push rax rbx rcx rdx rsi rdi
    mov  eax,13
    mov  ebx,24*65536+250
    mov  ecx,250*65536+10
    mov  edx,0xf0f0f0
    int  0x40
    mov  eax,4
    mov  ebx,24*65536+252
    mov  ecx,0xff0000
    mov  edx,dest_text
    mov  esi,dest_text_len-dest_text
    int  0x40
    pop  rdi rsi rdx rcx rbx rax

    mov  eax,10
    int  0x40
    cmp  eax,3
    jne  no_found2
    mov  eax,17
    int  0x40
    shr  eax,8
    cmp  eax,40
    jb   no_found2
    sub  eax,40

    xor  edx,edx
    mov  ebx,16
    div  ebx
    imul eax,10
    add  eax,edx

    mov  ebx,eax
    add  ebx,icons_reserved
    cmp  [ebx],byte 'x'
    je   no_found2

    mov  [ebx],byte 'x'

    xor  edx,edx
    mov  ebx,10
    div  ebx
    shl  eax,8
    mov  al,dl

    add  eax,65*256+65

    mov  [esi],ax

  no_found2:

    call draw_icons_and_menu
    call draw_info

  noiconmove:

    ; Add recycle icon

    cmp  eax,25
    jne  noaddrecycle

    mov  [recycle],byte 1

    jmp  add_icon

  noaddrecycle:

    cmp  eax,22                 ; user pressed the 'add icon' button
    jne  no_add_icon

  add_icon:

    mov  eax,13
    mov  ebx,24*65536+250
    mov  ecx,250*65536+10
    mov  edx,0xf0f0f0
    int  0x40
    mov  eax,4
    mov  ebx,24*65536+252
    mov  ecx,0xff0000
    mov  edx,add_text
    mov  esi,add_text_len-add_text
    int  0x40

    mov  eax,10
    int  0x40
    cmp  eax,3
    jne  still
    mov  eax,17
    int  0x40
    shr  eax,8
    cmp  eax,40
    jb   no_f
    sub  eax,40

    xor  edx,edx  ; bcd -> 10
    mov  ebx,16
    div  ebx
    imul eax,10
    add  eax,edx

    mov  ebx,eax
    add  ebx,icons_reserved
    cmp  [ebx],byte 'x'
    je   no_f
    mov  [ebx],byte 'x'

    xor  edx,edx
    mov  ebx,10
    div  ebx
    add  eax,65
    add  edx,65
    mov  [icon_default+0],dl
    mov  [icon_default+1],al
    mov  [icon_recycle+0],dl
    mov  [icon_recycle+1],al

    inc  dword [icons]
    mov  edi,[icons]
    dec  edi
    imul edi,72
    add  edi,icon_data

    mov  [current_icon],edi

    mov  esi,icon_default

    cmp  [recycle],byte 1
    jne  noaddrecycle2

    mov  esi,icon_recycle
    mov  [recycle],byte 0

  noaddrecycle2:

    mov  ecx,72
    cld
    rep  movsb

  no_f:

    call draw_icons_and_menu
    call draw_info

    jmp  still

  no_add_icon:


    cmp  eax,23                     ; user pressed the remove icon button
    jne  no_remove_icon

    mov  eax,13
    mov  ebx,24*65536+250
    mov  ecx,250*65536+10
    mov  edx,0xf0f0f0
    int  0x40
    mov  eax,4
    mov  ebx,24*65536+252
    mov  ecx,0xff0000
    mov  edx,rem_text
    mov  esi,rem_text_len-rem_text
    int  0x40

    mov  eax,10
    int  0x40
    cmp  eax,3
    jne  no_found
    mov  eax,17
    int  0x40
    shr  eax,8
    cmp  eax,40
    jb   no_found
    sub  eax,40

    xor  edx,edx
    mov  ebx,16
    div  ebx
    imul eax,10
    add  eax,edx

    mov  ebx,eax
    add  ebx,icons_reserved
    cmp  [ebx],byte 'x'
    jne  no_found
    mov  [ebx],byte ' '

    xor  edx,edx
    mov  ebx,10
    div  ebx
    shl  eax,8
    mov  al,dl

    add  eax,65*256+65

    mov  esi,icon_data
    mov  edi,72
    imul edi,[icons]
    add  edi,icon_data
  news:
    cmp  word [esi],ax
    je   foundi
    add  esi,72
    cmp  esi,edi
    jb   news
    jmp  no_found

  foundi:

    mov  ecx,edi
    sub  ecx,esi

    mov  edi,esi
    add  esi,72

    cld
    rep  movsb

    dec  [icons]

    mov  eax,icon_data
    mov  [current_icon],eax

  no_found:

    call draw_icons_and_menu
    call draw_info

    jmp  still

  no_remove_icon:

    cmp  eax,40                 ; user pressed button for icon position
    jb   no_on_screen_button

    sub  eax,40
    mov  edx,eax
    shl  eax,4
    and  edx,0xf
    mov  dh,ah
    add  edx,65*256+65

    mov  esi,icon_data
    mov  ecx,[icons]
    cmp  ecx , 0
    je   still   ; No icons
    cld
   findl1:
    cmp  dx,[esi]
    je   foundl1
    add  esi,70+2
    loop findl1
    jmp  still

   foundl1:

    mov  [current_icon],esi

    call print_strings

    jmp  still

  no_on_screen_button:

    jmp  still



add_transparency_marker:

    ; Adds transparency marker to all entries

    cmp  [icons],dword 0
    je   nomarkeradd
    mov  rax , 0
    mov  rdi , icon_data
  newmarkeradd:
    mov  [rdi+3],byte '-'
    mov  bl , [transparency]
    cmp  bl , 0
    je   notranspadd
    add  bl , 48
    mov  [rdi+3],bl
  notranspadd:
    add  rdi , d_end-d_start
    inc  eax
    cmp  eax , [icons]
    jb   newmarkeradd
  nomarkeradd:

    ret

load_background:

    ; Load new background

    cmp   [file1],dword '[CUR'
    je    nobgr3

    mov   rax , 256
    mov   rbx , app_bgr
    mov   rcx , boot
    int   0x60

    mov   [file1],dword '[CUR'
    mov   [file1+4],dword 'RENT'
    mov   [file1+8],dword ']'

    mov   rax , 5
    mov   rbx , 50
    int   0x60

    call  respond_to_window_draw

  nobgr3:

    ret

load_skin:

    ; Load new skin

    cmp   [file2],dword '[CUR'
    je    noskin3

    mov   rax , 120
    mov   rbx , 1
    mov   rcx , file2 ; textbox4+48
    int   0x60
    mov   rax , 120
    mov   rbx , 2
    mov   rcx , 1
    int   0x60
    mov   rax , 120
    mov   rbx , 3
    int   0x60

    mov   [file2],dword '[CUR'
    mov   [file2+4],dword 'RENT'
    mov   [file2+8],dword ']'

    mov   rax , 5
    mov   rbx , 50
    int   0x60

    call  respond_to_window_draw

  noskin3:

    ret


check_ipc:

    cmp   [ipc_memory+16],byte 0
    je    cil1

    mov   rsi , ipc_memory+16
    mov   rdi , file1
    cmp   [dialog_wait],byte 2
    jne   nofile2
    mov   rdi , file2
  nofile2:
    mov   rcx , 50
    cld
    rep   movsb

    call  draw_window

    call  draw_background_skin_info

    mov   [ipc_memory+16],byte 0
    mov   [ipc_memory+8],dword 16

  cil1:

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

    ; Define IPC memory

    mov   rax , 60           ; ipc
    mov   rbx , 1            ; define memory area
    mov   rcx , ipc_memory   ; memory area pointer
    mov   rdx , 100          ; size of area
    int   0x60

    ret


get_menu_position:

    push  rax rbx rcx rdx r8 r9 r10 r11 r12 r13 r14 r15 rsi rdi rbp

    mov   [position],byte 0

    mov   r15 , 0

  mtil1:

    mov   rax , 9
    mov   rbx , 1
    mov   rcx , r15
    mov   rdx , 0x40000
    mov   r8  , 1024
    int   0x60

    cmp   [0x40000+288],byte 0
    jne   nomp

    mov   eax , 'MENU'
    cmp   [0x40000+408+6],eax
    jne   nomp

    cmp   [0x40000+8],dword 0
    je    nomp

    mov   [position],byte 1

  nomp:

    inc   r15

    cmp   r15 , 64
    jbe   mtil1

    pop   rbp rdi rsi r15 r14 r13 r12 r11 r10 r9 r8 rdx rcx rbx rax

    ret


respond_to_window_draw:

    push rax rbx rcx

    mov  rax , 11
    int  0x60
    test rax , 1
    jz   nodrw
    call draw_window
  nodrw:

    pop  rcx rbx rax

    ret


move_mainmenu:

    mov   r15 , 0

  moma1:

    mov   rax , 9
    mov   rbx , 1
    mov   rcx , r15
    mov   rdx , 0x40000
    mov   r8  , 1024
    int   0x60

    cmp   [0x40000+288],byte 0
    jne   nomm

    mov   eax , 'MENU'
    cmp   [0x40000+408+6],eax
    jne   nomm

    mov   rax , 60
    mov   rbx , 2
    mov   rcx , [0x40000+264]
    mov   rdx , moveup
    cmp   [position],byte 1
    jne   nodownm
    mov   rdx , movedown
  nodownm:
    mov   r8  , 1
    int   0x60

  nomm:

    inc   r15

    cmp   r15 , 64
    jbe   moma1

    ret



terminate_icons:

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

    mov   eax , 'ICON'
    cmp   [0x40000+408+6],eax
    jne   notermicon

    mov   rax , 60
    mov   rbx , 2
    mov   rcx , [0x40000+264]
    mov   rdx , START
    mov   r8  , 10
    int   0x60

    mov   rax , 5
    mov   rbx , 5
    int   0x60

    push  r15
    call  respond_to_window_draw
    pop   r15

  notermicon:

    inc   r15

    cmp   r15 , 64
    jbe   til1

    ret


start_icons:

    cmp   [icons],dword 0
    je    no_icon_start

    mov   rcx , icon_data

    mov   r10 , 0

  new_icon:

    push  r10
    push  rcx
    call  respond_to_window_draw
    pop   rcx
    pop   r10

    push  qword [rcx+70]
    mov   [rcx+70],byte 0

    mov   rax , 256
    mov   rbx , icon_string
    int   0x60

    pop   qword [rcx+70]

    inc   r10
    cmp   r10d , [icons]
    jae   no_more_icons

    add   rcx , d_end - d_start
    cmp  [rcx], byte 'A'
    jge   new_icon

  no_more_icons:

  no_icon_start:

    ret



modify_config_mnt:

    ; Load file

    mov  rax , 58
    mov  rbx , 0
    mov  rcx , 0
    mov  rdx , -1
    mov  r8  , config_data
    mov  r9  , configmnt
    int  0x60

    mov  [configsize],rbx

    mov  rsi , config_data
  newreplace:

    ; Main Menu position

    mov  rax , 'main_men'
    cmp  [rsi],rax
    jne  nommre
    mov  rax , 'u_positi'
    cmp  [rsi+8],rax
    jne  nommre
  newl1:
    inc  rsi
    cmp  [rsi+0],byte '9'
    ja   newl1
    cmp  [rsi+0],byte '0'
    jb   newl1
    cmp  [rsi+1],byte '0'
    jae  newl1
    mov  al , [position]
    add  al , 48
    mov  [rsi], al
  nommre:

    ; Background

    cmp  [file1],dword '[CUR'
    je   nobgre
    mov  rax , 'backgrou'
    cmp  [rsi],rax
    jne  nobgre
  newl11:
    inc  rsi
    cmp  [rsi+0],byte 34
    je   newl112
    cmp  [rsi+0],byte 39
    je   newl112
    jmp  newl11
  newl112:
    mov  rax , rsi
  newl12:
    inc  rsi
    cmp  [rsi+0],byte 34
    je   newl122
    cmp  [rsi+0],byte 39
    je   newl122
    jmp  newl12
  newl122:
    mov  rbx , rsi
    mov  rcx , [configsize]
    mov  rdi , rax
    inc  rdi
    cmp  rdi , rsi
    je   nobgr1
    add  [configsize],rdi
    sub  [configsize],rsi
    push rdi
    push rsi
    cld
    rep  movsb
    pop  rsi
    pop  rdi
  nobgr1:
    mov  rdx , file1-1
  newfile1l:
    inc  rdx
    cmp  [rdx],byte 0
    jne  newfile1l
    sub  rdx , file1
    push rdi
    push rsi
    mov  rsi , rdi
    add  rdi , rdx
    mov  rcx , [configsize]
    add  rsi , rcx
    add  rdi , rcx
    add  rcx , rdx
    std
    rep  movsb
    cld
    pop  rsi
    pop  rdi
    push rsi
    mov  rsi , file1
    mov  rcx , rdx
    cld
    rep  movsb
    pop  rsi
    add  [configsize],rdx
  nobgre:

    ; Window skin

    cmp  [file2],dword '[CUR'
    je   noskre
    mov  rax , 'ndow_ski'
    cmp  [rsi],rax
    jne  noskre
  snewl11:
    inc  rsi
    cmp  [rsi+0],byte 34
    je   snewl112
    cmp  [rsi+0],byte 39
    je   snewl112
    jmp  snewl11
  snewl112:
    mov  rax , rsi
  snewl12:
    inc  rsi
    cmp  [rsi+0],byte 34
    je   snewl122
    cmp  [rsi+0],byte 39
    je   snewl122
    jmp  snewl12
  snewl122:
    mov  rbx , rsi
    mov  rcx , [configsize]
    mov  rdi , rax
    inc  rdi
    cmp  rdi , rsi
    je   snobgr1
    add  [configsize],rdi
    sub  [configsize],rsi
    push rdi
    push rsi
    cld
    rep  movsb
    pop  rsi
    pop  rdi
  snobgr1:
    mov  rdx , file2-1
  snewfile1l:
    inc  rdx
    cmp  [rdx],byte 0
    jne  snewfile1l
    sub  rdx , file2
    push rdi
    push rsi
    mov  rsi , rdi
    add  rdi , rdx
    mov  rcx , [configsize]
    add  rsi , rcx
    add  rdi , rcx
    add  rcx , rdx
    std
    rep  movsb
    cld
    pop  rsi
    pop  rdi
    push rsi
    mov  rsi , file2
    mov  rcx , rdx
    cld
    rep  movsb
    pop  rsi
    add  [configsize],rdx
  noskre:

    ;

    inc  rsi

    mov  rax , config_data
    add  rax , [configsize]

    cmp  rsi , rax
    jbe  newreplace

    ; Delete file

    mov  rax , 58
    mov  rbx , 2
    mov  r9  , configmnt
    int  0x60

    ; Save file

    mov  rax , 58
    mov  rbx , 1
    mov  rcx , 0
    mov  rdx , [configsize]
    mov  r8  , config_data
    mov  r9  , configmnt
    int  0x60

    ret


empty_textbox:

    mov  [r14+5*8],dword 0

    mov  rdi , r14
    add  rdi , 6*8
    mov  rcx , 40
    mov  rax , 32
    cld
    rep  stosb

    ret


print_strings:

    mov  ebp , [current_icon]
    and  rbp , 0xffffff

    mov  r14 , textbox1
    call empty_textbox

    mov  rsi , rbp
    add  rsi , 5
    mov  rdi , textbox1+6*8
    mov  rcx , 9
    cld
    rep  movsb

    mov  r14 , textbox2
    call empty_textbox
    mov  rsi , rbp
    add  rsi , 36
    mov  rdi , textbox2+6*8
    mov  rcx , 33
    cld
    rep  movsb

    push rbp

    mov  r14 , textbox3
    call empty_textbox

    pop  rbp

    mov  rsi , rbp
    add  rsi , 16
    mov  rdi , textbox3+6*8
    mov  rcx , 18
    cld
    rep  movsb

    mov  [textbox1+8], dword fx+56-20
    mov  [textbox2+8], dword fx+56-20
    mov  [textbox3+8], dword fx+140-20

    mov  [textbox1+24], dword fy+071-130
    mov  [textbox2+24], dword fy+097-130
    mov  [textbox3+24], dword fy+071-130

    mov  r14 , textbox1
    call draw_textbox

    mov  r14 , textbox2
    call draw_textbox

    mov  r14 , textbox3
    call draw_textbox

    ret


load_icon_list:

    push  rax rbx rcx rdx rsi rdi

    mov   rax , 58
    mov   rbx , 0
    mov   rcx , 0
    mov   rdx , -1
    mov   r8  , icon_data
    mov   r9  , icon_mnt
    int   0x60

    mov   rax , rbx
    and   rax , 0xffff

    add   eax,10
    xor   edx,edx
    mov   ebx,72
    div   ebx
    mov   [icons],eax

    ; Read Transparency

    mov   [transparency],dword 0
    cmp   [icons],dword 0
    je    transparencydone
    cmp   [icon_data+3],byte '-'
    je    transparencydone
    movzx rax , byte [icon_data+3]
    sub   rax , 48
    mov   [transparency],eax
  transparencydone:

    mov   edi,icons_reserved   ; clear reserved area
    mov   eax,32
    mov   ecx,10*10
    cld
    rep   stosb

    mov   ecx,[icons]          ; set used icons to reserved area
    cmp   ecx , 0
    je    icon_list_empty
    mov   esi,icon_data
    cld
  ldl1:
    movzx ebx,byte [esi+1]
    sub   ebx,65
    imul  ebx,10
    movzx eax,byte [esi]
    add   ebx,eax
    sub   ebx,65
    add   ebx,icons_reserved
    mov   [ebx],byte 'x'
    add   esi,70+2
    loop  ldl1
  icon_list_empty:

    pop   rdi rsi rdx rcx rbx rax

    ret


check_parameters:

    cmp   [I_Param+8], byte 'B'
    je    chpl1
    ret
   chpl1:

    call  terminate_icons

    call  start_icons

    mov   rax , 512
    int   0x60



set_values:

    mov   ebp , [current_icon]
    and   rbp , 0xffffff

    mov   rdi , rbp
    add   rdi , 5
    mov   rsi , textbox1+6*8
    mov   rcx , 8
    cld
    rep   movsb

    mov   rdi , rbp
    add   rdi , 36
    mov   rsi , textbox2+6*8
    mov   rcx , 32
    cld
    rep   movsb

    mov   rdi , rbp
    add   rdi , 16
    mov   rsi , textbox3+6*8
    mov   rcx , 18
    cld
    rep   movsb

    ; Clear 0s from text file

    mov   ecx , [icons]
    and   rcx , 0xffff
    inc   rcx
    imul  rcx , 72
    mov   rsi , icon_data
  newzerosearch:
    cmp   [rsi],byte 0
    jne   notzero
    mov   [rsi],byte 32
  notzero:
    inc   rsi
    loop  newzerosearch

    ret



draw_window:

    mov  eax,12                    ; function 12:tell os about windowdraw
    mov  ebx,1                     ; 1, start of draw
    int  0x40

    mov  rax , 0
    mov  rbx , 180 shl 32 + 300
    mov  rcx ,  40 shl 32 + 487
    mov  rdx , 0xffffff
    mov  r8  , 1
    mov  r9  , window_label
    mov  r10 , 0
    int  0x60

    call draw_icons_and_menu

    ; Button positions

    mov  rbx,fx shl 32+259
    mov  rcx,(fy-19-4) shl 32+17
    mov  rdx,21
    mov  r8 , 0

    push rbx rcx
    mov  eax,8                     ; add icon
    mov  rbx,fx shl 32 +130
    mov  r12 , 19 shl 32
    add  rcx , r12
    mov  edx , 22
    mov  r9 , string_add
    int  0x60
    mov  eax,8                     ; move
    mov  r12 , 130 shl 32
    add  rbx , r12
    mov  rdx , 24
    mov  r9 , string_move
    int  0x60
    pop  rcx rbx

    mov  eax,8                     ; add recycle
    mov  rbx,fx shl 32 +130
    mov  r12 , 36 shl 32
    add  rcx , r12
    mov  rdx , 25
    mov  r9 , string_recycle
    int  0x60
    mov  eax,8                     ; remove icon
    mov  r12 , 130 shl 32
    add  rbx , r12
    mov  rdx , 23
    mov  r9 , string_remove
    int  0x60

    call draw_position_button

    call draw_icon_transparency_button

    call draw_background_skin_info

    mov  rax,8                     ; apply and save
    mov  rbx,fx shl 32+130 ; 260
    mov  rcx,(fy+24*5) shl 32+17
    mov  rdx,21
    mov  r8 , 0
    mov  r9 , string_apply
    int  0x60
    mov  rax,8                     ; cancel
    mov  rbx,(fx+130) shl 32+130 ; 260
    mov  rcx,(fy+24*5) shl 32+17
    mov  rdx,30
    mov  r8 , 0
    mov  r9 , string_cancel
    int  0x60

    call draw_info

    mov  eax,12
    mov  ebx,2
    int  0x40

    ret



draw_background_skin_info:

    mov  rsi , file1
    mov  rdi , string_bgr+12
    mov  rcx , 20
    cld
    rep  movsb

    mov  rsi , file2
    mov  rdi , string_skin+13
    mov  rcx , 19
    cld
    rep  movsb

    mov  rax,13
    mov  rbx,(fx+00) shl 32 + 250
    mov  rcx,(fy+24*3+5) shl 32 + 34
    mov  rdx,0xf0f0f0
    int  0x60

    mov  rax , 4
    mov  rbx , string_bgr
    mov  rcx , fx+5
    mov  rdx , fy+24*3+5+5
    mov  rsi , 0x000000
    mov  r9  , 1
    int  0x60

    mov  rax , 4
    mov  rbx , string_skin
    mov  rcx , fx+5
    mov  rdx , fy+24*3+17+5+5
    mov  rsi , 0x000000
    mov  r9  , 1
    int  0x60

    mov  rax,8                     ; background picture
    mov  rbx,(fx+200) shl 32+60
    mov  rcx,(fy+24*3+5) shl 32+17
    mov  rdx,27
    mov  r8 , 0
    mov  r9 , string_browse
    int  0x60
    mov  rax,8                     ; window skin
    mov  rbx,(fx+200) shl 32+60
    mov  rcx,(fy+24*3+17+5) shl 32+17
    mov  rdx,28
    mov  r8 , 0
    mov  r9 , string_browse
    int  0x60

    ret


draw_position_button:

    mov  rax,8                     ; main menu position
    mov  rbx,fx shl 32+260
    mov  rcx,(fy+24*2-6+10) shl 32+17
    mov  rdx,26
    mov  r8 , 0
    mov  r9 , string_position_up
    cmp  [position],byte 1
    jne  nodownstr
    mov  r9 , string_position_down
  nodownstr:
    int  0x60

    ret


draw_icon_transparency_button:

    mov  rax , 8                     ; icon transparency
    mov  rbx , fx shl 32+260
    mov  rcx , (fy+24*2-6-12) shl 32+17
    mov  rdx , 29
    mov  r8  , 0
    mov  r9  , string_transparency_off
    cmp  [transparency],byte 1
    jne  notr1
    mov  r9  , string_transparency_on_1
  notr1:
    cmp  [transparency],byte 2
    jne  notr2
    mov  r9  , string_transparency_on_2
  notr2:
    cmp  [transparency],byte 3
    jne  notr3
    mov  r9  , string_transparency_on_3
  notr3:
    cmp  [transparency],byte 4
    jne  notr4
    mov  r9  , string_transparency_on_4
  notr4:
    cmp  [transparency],byte 5
    jne  notr5
    mov  r9  , string_transparency_on_5
  notr5:
    cmp  [transparency],byte 6
    jne  notr6
    mov  r9  , string_transparency_on_6
  notr6:
    cmp  [transparency],byte 7
    jne  notr7
    mov  r9  , string_transparency_on_7
  notr7:
    cmp  [transparency],byte 8
    jne  notr8
    mov  r9  , string_transparency_on_8
  notr8:
    int  0x60

    ret



draw_info:

    mov  rax , 13
    mov  rbx , (fx+1) shl 32 + 259
    mov  rcx , (fy-87) shl 32 + 84 ; +100
    mov  rdx , 0xf0f0f0
    int  0x60

    ; Text

    mov  ebx,(fx+4)*65536+(fy-80)
    mov  ecx,0x000000
    mov  edx,text
    mov  esi,40
  newline:
    mov  ecx,[edx]
    add  edx,4
    mov  eax,4
    int  0x40
    add  ebx,13
    add  edx,40
    cmp  [edx],byte 'x'
    jne  newline

    call print_strings

    ret


icony equ 37

draw_icons_and_menu:

    mov  eax,13
    mov  ebx,20*65536+260
    mov  ecx,icony*65536+200
    mov  edx,0x607080
    int  0x40

    mov  eax,38
    mov  ebx,150*65536+150
    mov  ecx,35*65536+237
    mov  edx,0xffffff
    int  0x40
    mov  eax,38
    mov  ebx,20*65536+280
    mov  ecx,135*65536+135
    mov  edx,0xffffff
    int  0x40

    mov  eax,0
    mov  ebx,20*65536+25
    mov  ecx,icony*65536+20
    mov  edi,icon_table
    mov  edx,40
   newbline:

    cmp  [edi],byte 'x'
    jne  no_button

    mov  esi,0;0x5577cc
    cmp  [edi+100],byte 'x'
    jne  nores
    mov  esi,1;0xcc5555
  nores:

    push rax
    mov  eax,8
    int  0x40
    cmp  esi , 1
    jne  noresb
    push rax rbx rcx rdx
    mov  eax , 13
    add  ebx , 1 * 65536 -1
    add  ecx , 1 * 65536 -2
    mov  edx , 0x909090
    int  0x40

    pop  rdx rcx rbx rax

  noresb:
    pop  rax

  no_button:

    add  ebx,26*65536

    inc  edi
    inc  edx

    inc  al
    cmp  al,9
    jbe  newbline
    mov  al,0

    add  edx,6

    ror  ebx,16
    mov  bx,20
    ror  ebx,16
    add  ecx,20*65536

    inc  ah
    cmp  ah,9
    jbe  newbline

    ret


; Data

textbox1:

    dq   0
    dq   56
    dq   8*6+8
    dq   273
    dq   111
    dq   0
    times 50 db 0

textbox2:

    dq   0
    dq   56
    dq   32*6+8
    dq   300
    dq   112
    dq   0
    times 50 db 0

textbox3:

    dq   0
    dq   140
    dq   18*6+8
    dq   273
    dq   113
    dq   0
    times 50 db 0


str1   db   '                   '
str2   db   '                   '

bcolor dd 0x335599

icon_table:

    times 4  db  'xxxx  xxxx'
    times 1  db  '          '
    times 1  db  '          '
    times 4  db  'xxxx  xxxx'

icons_reserved:

    times 10 db  '          '


text:

    db 0,0,0,0,         'SELECT ICON OR TASK                     '
    db 0,0,0,0,         '                                        '
    db 0,0,0,0,         'TEXT            BMP                     '
    db 0,0,0,0,         '                                        '
    db 0,0,0,0,         'APP                                     '

    db 'x'

string_apply:   db   'SAVE AND APPLY',0
string_cancel:  db   'CANCEL',0

string_add:     db   'ADD NEW ICON',0
string_recycle: db   'ADD RECYCLE ICON',0

string_move:    db   'MOVE ICON',0
string_remove:  db   'DELETE ICON',0

string_browse:  db   'BROWSE',0

window_label:   db   'DESKTOP',0

string_position_down:  db  'MAIN MENU POSITION: DOWN',0
string_position_up:    db  'MAIN MENU POSITION: UP',0

icons dd 0

addr  dd 0
ya    dd 0

transparency: dq 0x0

string_transparency_off:    db  'ICON BACKGROUND: 100%',0
string_transparency_on_1:   db  'ICON BACKGROUND: 087%',0
string_transparency_on_2:   db  'ICON BACKGROUND: 075%',0
string_transparency_on_3:   db  'ICON BACKGROUND: 062%',0
string_transparency_on_4:   db  'ICON BACKGROUND: 050%',0
string_transparency_on_5:   db  'ICON BACKGROUND: 037%',0
string_transparency_on_6:   db  'ICON BACKGROUND: 025%',0
string_transparency_on_7:   db  'ICON BACKGROUND: 012%',0
string_transparency_on_8:   db  'ICON BACKGROUND: 000%',0


add_text db 'PRESS BUTTON OF UNUSED ICON POSITION'
add_text_len:

rem_text db 'PRESS BUTTON OF USED ICON'
rem_text_len:

move_text db 'SELECT ICON TO MOVE'
move_text_len:

dest_text db 'SELECT NEW LOCATION'
dest_text_len:

file1:   db   '[CURRENT]                                                '
file2:   db   '[CURRENT]                                                '

file_search:  db   '/FD/1/FBROWSER   ',0
parameter:    db   '[000000]',0
app_bgr:      db   '/FD/1/BGR',0
boot:         db   'BOOT',0

string_bgr:  db 'BACKGROUND: x                   ',0

string_skin: db 'WINDOW SKIN: x                  ',0

position:    dq 0x0  ; main menu position ; 0=up - 1 =down

positionchanged: dq 0x0

positions  dd  5,36,16
lengths    dd  8,32,18
curlen     dd  0x0

current_icon dd icon_data

configmnt:   db  '/fd/1/config.mnt',0
configsize:  dq  0x0

moveup:    db  'U',0
movedown:  db  'D',0
recycle:   db 0

icon_mnt   db '/FD/1/ICON.MNT',0

ipc_memory:

    dq  0x0    ; lock - 0=unlocked , 1=locked
    dq  16     ; first free position from ipc_memory

    times 100 db 0

icon_name:

      db 'ICON       '

icon_string:

    db '/FD/1/ICON',0

    times 128 db 0

icon_start_parameters:

      db   25,1,1,1
      db   35,1,1,1
      db   'WRITE   BMP'
      db   'EDITOR     '
      db   'EDITOR ',0,0

I_Param:

      dq    30
      times 30 db 0

icon_recycle:

db '   - RECYCLE  - /FD/1/RECYCLE.BMP - /FD/1/RECYCLE                    -'
db 13,10


icon_default:

d_start:
db '   - SETUP    - /FD/1/HD.BMP      - /FD/1/SETUP                      -'
db 13,10
d_end:

icon_data:

I_END:

