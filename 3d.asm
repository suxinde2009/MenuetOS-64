;
;   Menuet 3D example for syscall 122
;
;   Compile with FASM 1.60 or above
;

use64

    org   0x0

    db    'MENUET64'              ; Header identifier
    dq    0x01                    ; Version
    dq    START                   ; Start of code
    dq    image_end               ; Size of image
    dq    0x100000*70             ; Memory for app
    dq    0xffff0                 ; Esp
    dq    0x00                    ; Prm
    dq    0x00                    ; Icon

; 3D area consists of 256 byte header and 256x256x256 dword pixels
; which can hold color, transparency or mirror pixel.
;
; 0x01RRGGBB = color pixel
; 0x020000DD = transparent pixel ( DD = dimming strength )
; 0x030000DD = mirror ( X axis, DD = dimming strength )
; 0x040000DD = mirror ( Y axis, DD = dimming strength )
; 0x050000DD = mirror ( Z axis, DD = dimming strength )
;
; 1) Initialize the area with syscall 122/1
; 2) Draw user data to area with syscall 122/2
; 3) Preprocess the area with syscall 122/4
; 4) Move the camera and calculate 2D images with syscall 122/5


screen  equ  0x100000        ; 2D image is calculated here
field   equ  0x600000-256    ; 3D area (64 MB) with header (256 bytes)

height      equ  6           ; Height from the surface of the track
trackwidth  equ  25          ; Overall track width
trackedge   equ  20          ; Start of red/white edge
trackcolor  equ  0x01404040  ; Color of track

picsizex    equ 560          ; 2D image width
picsizey    equ 350          ; 2D image height


START:

    mov   rax , 141
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    ; At first, draw the window.

    call  draw_window
    mov   rbx , 256*256*256
    call  print_init

    ; 1) Initialize field.

    mov   rbx , 1
    mov   rcx , field
    mov   rax , 122
    int   0x60

    ; 2) Generate user field.

    call  generate_field

    ; Display first image

    call  calculate_image
    call  draw_field
    mov   rbx , 256*256*256
    call  print_init

    ; 3) Preprocess field, speeds up image processing.

    call  preprocess

    ; 4) Move the camera in field.

still:

    mov   rax , 11
    int   0x60

    test  rax , 0x1         ; Window redraw
    jnz   window_event
    test  rax , 0x2         ; Keyboard press
    jnz   key_event
    test  rax , 0x4         ; Button press
    jnz   button_event

    call  check_gravity

    call  check_move

    call  update_time

    call  check_finish

    jmp   still


window_event:

    call  draw_window

    jmp   still


key_event:

    mov   rax , 0x2        ; Read the key and ignore
    int   0x60

    cmp   ecx , 'Left'
    jne   noleftarrow
    mov   [directionleft],byte 1
    test  ebx , 1
    jz    still
    mov   [directionleft],byte 0
    jmp   still
  noleftarrow:

    cmp   ecx , 'Righ'
    jne   norightarrow
    mov   [directionright],byte 1
    test  ebx , 1
    jz    still
    mov   [directionright],byte 0
    jmp   still
  norightarrow:

    cmp   ecx , 'Up-A'
    jne   nouparrow
    mov   [directionup],byte 1
    test  ebx , 1
    jz    still
    mov   [directionup],byte 0
    jmp   still
  nouparrow:

    cmp   ecx , 'Down'
    jne   nodownarrow
    mov   [directiondown],byte 1
    test  ebx , 1
    jz    still
    mov   [directiondown],byte 0
    jmp   still
  nodownarrow:

    jmp   still


check_move:

    ; Save current position

    mov   rsi , [posx]
    mov   [prevx],rsi
    mov   rsi , [posy]
    mov   [prevy],rsi
    mov   rsi , [posz]
    mov   [prevz],rsi
    mov   rsi , [angle]
    mov   [prevangle],rsi

    ; Keyboard

    cmp   [directionleft],byte 1
    jne   noleft
    cmp   [angle],dword 70
    jae   angle1
    add   [angle],dword 3600
  angle1:
    sub   [angle],dword 70
  noleft:

    cmp   [directionright],byte 1
    jne   noright
    cmp   [angle],dword 3600 - 70
    jb    angle2
    sub   [angle],dword 3600
  angle2:
    add   [angle],dword 70
  noright:

    cmp   [directionup],byte 1
    jne   mnoforward2
    mov   r14 , [angle]
    add   r14 , picsizex/20*36/2
    call  getsincos3600
    shl   rax , 2
    shl   rbx , 2
    add   [posx],rbx
    add   [posz],rax
  mnoforward2:

    cmp   [directiondown],byte 1
    jne   mnobackw2
    mov   r14 , [angle]
    add   r14 , picsizex/20*36/2
    call  getsincos3600
    shl   rax , 2
    shl   rbx , 2
    not   rax
    not   rbx
    add   [posx],rbx
    add   [posz],rax
  mnobackw2:

    mov   rax , [posx]
    mov   rbx , [posy]
    mov   rcx , [posz]

    cmp   eax , 5 shl 16
    jbe   wallhit
    cmp   ecx , 5 shl 16
    jbe   wallhit
    cmp   eax , 250 shl 16
    jae   wallhit
    cmp   ecx , 250 shl 16
    jae   wallhit

    ; Movement ?

    mov   rdx , [angle]
    add   rdx , rax
    add   rdx , rbx
    add   rdx , rcx
    cmp   rdx , [pos_sum]
    je    no_movement
    mov   [pos_sum],rdx

  doimage:

    ; Calculate track image

    call  calculate_image

    ; Wait for display time

    call  wait_for_next_frame

    ; Display image

    call  draw_field

    ret

  no_movement:

    call  wait_for_next_frame

    ret



wait_for_next_frame:

    mov   rsi , [nextframe]
  waitmore:
    call  get_current_time
    cmp   rsi , rax
    jbe   nowait
    mov   rax , 5
    mov   rbx , 1
    int   0x60
    jmp   waitmore
  nowait:
    add   rax , 4
    mov   [nextframe],rax

    ret


wallhit:

    mov   rax , [prevx]
    mov   [posx],rax
    mov   rax , [prevy]
    mov   [posy],rax
    mov   rax , [prevz]
    mov   [posz],rax

    jmp   doimage


button_event:

    mov   rax , 0x11
    int   0x60

    ; rax = status
    ; rbx = button id

    cmp   rbx , 0x10000001
    jne   no_application_terminate_button
    mov   rax , 0x200
    int   0x60
  no_application_terminate_button:

    cmp   rbx , 0x102
    jne   no_application_terminate_menu
    mov   rax , 0x200
    int   0x60
  no_application_terminate_menu:

    jmp   still


preprocess:

; Skipping preprocessing will make 2D calculations slower.
; You can move/display the field during preprocessing.

    ; Called until area is processed

    mov   rax , 122
    mov   rbx , 4
    mov   rcx , field
    int   0x60

    cmp   rbx , 0
    je    nopros

    call  print_init

    mov   rax , 11
    int   0x60

    test  rax , 0x1
    jz    preprol1
    call  draw_window
    call  draw_field
    jmp   preprocess
  preprol1:
    test  rax , 0x4
    jz    preprocess
    mov   rax , 512
    int   0x60
  nopros:

    call  draw_field

    ret


getfield:

    push rax rbx rcx r8 r9

    shr  rax , 16
    shr  rbx , 16
    shr  rcx , 16

    mov  r9  , rcx
    mov  r8  , rbx
    mov  rdx , rax

    mov  rax , 122
    mov  rbx , 3
    mov  rcx , field

    int  0x60

    mov  edx , ebx

    pop  r9 r8 rcx rbx rax

    ret


setfield:

    push  rax rbx rcx rdx r8 r9 r10

    ; Set three pixel layers to track

    mov   r10 , rdx
    mov   r9  , rcx
    mov   r8  , rbx
    mov   rdx , rax
    mov   rcx , field
    mov   rbx , 2
    mov   rax , 122
    int   0x60
    dec   r8
    mov   rbx , 2
    mov   rax , 122
    int   0x60
    dec   r8
    mov   rbx , 2
    mov   rax , 122
    int   0x60

    pop   r10 r9 r8 rdx rcx rbx rax

    ret


getsincos2000:

    mov   rax , r14
    imul  rax , 9
    mov   rbx , 5
    xor   rdx , rdx
    div   rbx
    mov   r14 , rax

  getsincos3600:

    mov   rcx , r14
    mov   rax , 122
    mov   rbx , 6
    int   0x60

    ret


get_current_time:

    mov   rax , 26
    mov   rbx , 1
    mov   rcx , infoblock
    mov   rdx , 6*8
    int   0x60

    mov   rax , [infoblock+5*8]

    ret


fontsize: dq 9


print_init:

    push  rbx

    mov   rax , 13
    mov   rbx , 10 shl 32 + 9 * 6+4 ; 4
    mov   rcx , 50 shl 32 + 11
    cmp   [fontsize],dword 10
    jne   nobc2
    mov   rcx , 50 shl 32 + 12
  nobc2:
    cmp   [fontsize],dword 10
    jbe   nobc
    mov   rcx , 49 shl 32 + 13
  nobc:
    mov   rdx , 0xffffff
    int   0x60

    mov   rax , 0x4                          ; Display text
    mov   rbx , string_init
    mov   rcx , 12
    mov   rdx , 52
    mov   rsi , 0x0
    mov   r9  , 0x1
    mov   r8  , 0x3
    int   0x60

    mov   rax , [rsp]
    imul  rax , 100
    mov   rbx , 256*256*256
    xor   rdx , rdx
    div   rbx
    mov   rcx , 100
    sub   rcx , rax

    mov   rax , 47
    mov   rbx , 3 * 65536
    mov   rdx , (12+5*6) shl 32 + 52
    mov   rsi , 0x000000
    int   0x60

    pop   rbx

    ret


check_gravity:

    mov   rax , [posx]
    mov   rbx , [posy]
    mov   rcx , [posz]
    add   rbx , height shl 16

    call  getfield
    cmp   edx , 0x01000000
    jae   doup

    sub   rax , 0x20000
    call  getfield
    cmp   edx , 0x01000000
    jae   doup
    sub   rcx , 0x20000
    call  getfield
    cmp   edx , 0x01000000
    jae   doup
    add   rax , 0x40000
    call  getfield
    cmp   edx , 0x01000000
    jae   doup
    add   rcx , 0x40000
    call  getfield
    cmp   edx , 0x01000000
    jae   doup

    add   rax , 0x20000
    add   rcx , 0x20000

    sub   rbx , 0x10000
    call  getfield
    cmp   edx , 0x01000000
    jae   doup
    sub   rbx , 0x10000
    call  getfield
    cmp   edx , 0x01000000
    jae   doup

    mov   rax , [posx]
    mov   rbx , [posy]
    mov   rcx , [posz]
    add   rbx , height shl 16
    call  getfield

    cmp   edx , 0x01000000
    jb    dodown

    ret

  dodown:

    add   dword [posy],dword 3 shl 16

    mov   rax , [posx]
    mov   rbx , [posy]
    mov   rcx , [posz]
    add   rbx , height shl 16
    call  getfield

    cmp   [posy],dword (255-height) shl 16
    jae   timezero
    cmp   edx , 0x01000000
    jae   nozero
    inc   dword [gravitydown]
    cmp   [gravitydown],dword 5
    jb    nozero
  timezero:
    mov   [time],dword 8888/4
    call  print_time
  nozero:

    ret

  doup:

    sub   dword [posy],dword 1 shl 16

    mov   [gravitydown],dword 0

    jmp   check_gravity



calculate_image:

    mov   rbx , 5
    mov   rcx , field
    mov   rdx , [posx]
    mov   r8  , [posy]
    mov   r9  , [posz]
    mov   r10 , [angle]
    mov   r11 , picsizex
    mov   r12 , picsizey
    mov   r13 , screen
    mov   rax , 122
    int   0x60

    ret


draw_field:

    mov   rax , 7
    mov   rbx , 05 shl 32 + picsizex
    mov   rcx , 38 shl 32 + picsizey
    mov   rdx , screen
    mov   r8  , 0
    mov   r9  , 0x1000000
    mov   r10 , 4
    int   0x60

    ret


generate_field:

    ; Make track

    mov   rsi , track_data-4
    mov   rdi , 0

  mkl0:

    add   rsi , 4

  mkl1:

    ; Read track entry

    mov   r15d, dword [rsi]
    cmp   r15d , 1000
    jne   noabsangle
    add   rsi , 4
    mov   r15d , [rsi]
    mov   [current_direction],r15d
    add   rsi , 4
    jmp   mkl1
  noabsangle:
    cmp   r15d, 3
    jne   no30
    mov   r15d, 0
  no30:
    test  rdi , 1
    jnz   nor15
    mov   r15 , 0
  nor15:
    cmp   r15d , dword 1
    jne   nor15d0
    mov   r15 , 0
  nor15d0:
    cmp   r15d , dword 2
    jne   nor15d02
    mov   r15 , 0
  nor15d02:
    cmp   r15 , 65535
    je    mkl2

    ; Left/Right turn

    cmp   r15b, 10
    jne   r146
    mov   r14 , [current_direction]
    add   r14d , r15d
    cmp   r14 , 2000
    jb    r146
    sub   r14 , 2000
    jmp   r14fine3
  r146:
    mov   r14 , [current_direction]
    add   r14d , r15d
    cmp   r14 , 2000
    jb    r14fine3
    mov   r14 , 2000
  r14fine3:
    mov   [current_direction],r14

    call  getsincos2000

    mov   r8  , [cux]
    mov   r9  , [cuz]
    shr   rax , 1
    shr   rbx , 1
    add   r8d , ebx
    add   r9d , eax
    mov   [cux] , r8
    mov   [cuz] , r9

    ; Draw right part of the track

    mov   r14 , [current_direction]
    add   r14 , 1500
    call  getsincos2000
    mov   r10 , rax
    mov   r11 , rbx
    shr   r10 , 1
    shr   r11 , 1
    mov   r15 , 1

  newright:

    mov   rax , [cux]
    mov   rbx , [cuy]
    mov   rcx , [cuz]

    push  r11 r10
    imul  r11 , r15
    imul  r10 , r15
    add   eax , r11d
    add   ecx , r10d
    pop   r10 r11

    shr   rax , 16
    shr   rbx , 16
    shr   rcx , 16
    mov   rdx , trackcolor
    cmp   [rsi],byte 3
    jne   nofinishline
    mov   rdx , 0x01ffffff
  nofinishline:

    cmp   r15 , trackedge
    jb    noedge
    mov   rdx , 0x01ff0000
    test  [redwhite],byte 10b
    jnz   nowhite2
    mov   rdx , 0x01ffffff
  nowhite2:
  noedge:

    call  setfield

    inc   r15
    cmp   r15 , trackwidth
    jb    newright

    ; Draw left part of the track

    mov   r14 , [current_direction]
    add   r14 , 500
    call  getsincos2000
    mov   r10 , rax
    mov   r11 , rbx
    shr   r10 , 1
    shr   r11 , 1
    mov   r15 , 1

  newleft:

    mov   rax , [cux]
    mov   rbx , [cuy]
    mov   rcx , [cuz]

    push  r11 r10
    imul  r11 , r15
    imul  r10 , r15
    add   eax , r11d
    add   ecx , r10d
    pop   r10 r11

    shr   rax , 16
    shr   rbx , 16
    shr   rcx , 16
    mov   rdx , trackcolor

    cmp   [rsi],byte 3
    jne   nofinishline2
    mov   rdx , 0x01ffffff
  nofinishline2:

    cmp   r15 , trackedge
    jb    noedge2
    mov   rdx , 0x01ff0000
    test  [redwhite],byte 10b
    jnz   nowhite3
    mov   rdx , 0x01ffffff
  nowhite3:

  noedge2:

    call  setfield

    inc   r15
    cmp   r15 , trackwidth
    jb    newleft

    ; Y axis

    mov   rbx , [cuy]
    cmp   rdi , 3
    je    yesaddebx
    cmp   rdi , 7
    je    yesaddebx
    jmp   noaddebx
  yesaddebx:
    cmp   [rsi],dword 1
    jne   nosubebx
    sub   ebx , 1 shl 16
  nosubebx:
    cmp   [rsi],dword 2
    jne   noaddebx
    add   ebx , 1 shl 16
  noaddebx:
    mov   [cuy] , rbx

    inc   rdi

    cmp   rdi , 10
    jb    mkl1

    inc   dword [redwhite]
    mov   rdi , 0

    jmp   mkl0

  mkl2:

    ret



check_finish:

    cmp   [posy],dword 230 shl 16
    jb    nofinish
    cmp   [posz],dword  (129+2) shl 16
    ja    nofinish
    cmp   [posz],dword  (129-2) shl 16
    jb    nofinish
    cmp   [posx],dword  45 shl 16
    ja    nofinish

    call  print_time

    mov   [time],dword 0

  nofinish:

    ret



update_time:

    cmp   [time],dword 8888/4
    jae   notimeupdate
    inc   dword [time]
  notimeupdate:

    mov   rax , [time]
    xor   rdx , rdx
    mov   rbx , 25
    div   rbx
    cmp   rdx , 0
    je    print_time

    ret

print_time:

    cmp   [time],dword 300/4
    jb    nostime
    mov   rax , [time]
    mov   [stime],rax
  nostime:

    mov   rax , 13
    mov   rbx , 450 shl 32 + 4*6+1
    mov   rcx , 27  shl 32 + 9
    mov   rdx , 0xf0f0f0
    int   0x60

    mov   rcx , [stime]
    imul  rcx , 4
    mov   rax , 47
    mov   rbx , 4*65536
    mov   rdx , 451 shl 32 + 28
    mov   rsi , 0x000000
    int   0x60

    ret


draw_window:

    mov   rax , 0xC                          ; Beginning of window draw
    mov   rbx , 0x1
    int   0x60

    mov   rax , 141
    mov   rbx , 3
    int   0x60
    and   rax , 0xff
    mov   [fontsize],rax

    mov   rax , 0x0                          ; Draw window
    mov   rbx , 0x0000005600000000 + 10+picsizex     ; x start & size
    mov   rcx , 0x0000003800000000 + 43+picsizey     ; y start & size
    mov   rdx , 0x0000000000ffffff           ; type    & border color
    mov   r8  , 0x0000000000000001           ; draw flags
    mov   r9  , window_label                 ; 0 or label - asciiz
    mov   r10 , menu_struct                  ; 0 or pointer to menu struct
    int   0x60

    mov   [pos_sum],dword 0

    mov   rax , 0xC                          ; End of window draw
    mov   rbx , 0x2
    int   0x60

    ret


; Data area

window_label:

    db    '3D',0     ; Window label

menu_struct:               ; Menu Struct

    dq   0                 ; Version

    dq   0x100             ; Start value of ID to return ( ID + Line )

    db   0,'FILE',0        ; ID = 0x100 + 1
    db   1,'Quit',0        ; ID = 0x100 + 2

    db   255               ; End of Menu Struct

string_init:

    db    'Init:   %',0

cux:    dq  025 shl 16
cuy:    dq  254 shl 16
cuz:    dq  045 shl 16

directionleft:     dq  0x0
directionright:    dq  0x0
directionup:       dq  0x0
directiondown:     dq  0x0
current_direction: dq 0x0

nextframe:    dq 0

prevx:        dq 0
prevy:        dq 0
prevz:        dq 0
prevangle:    dq 0
direction:    dq 0

time:         dq 0
stime:        dq 0

gravitydown:  dq 0
redwhite:     dq 0

posx:         dq  025 shl 16
posy:         dq (254-height) shl 16
posz:         dq  100 shl 16

angle:        dq  3095

pos_sum:      dq  0x0

infoblock:    times 6*8 db 0

track_data:

    dd   0 , 0 , 0 , 0 , 0
    dd   0 , 0 , 0 , 0 , 0 , 0 , 0 , 0
    dd   0 , 0 , 3 , 0 , 0 , 0 , 0 , 0
    dd   0 , 0 , 0 , 0 , 0 , 0 , 0 , 0
    dd   0 , 0 , 0
    dd   00 , 00 , 20 , 20 , 20 , 20 , 20 , 00 , 00 , 00
    dd   0 , 0 , 0 , 0 , 0 , 0 , 0
    dd   0 , 0 , 0 , 0 , 0 , 0 , 0
    dd   0 , 0 , 0 , 0
    dd   0 , 0 , 0 , 0
    dd   0 , 0 , 0
    dd   00 , 00 , 20 , 20 , 20 , 20 , 20 , 00 , 00 , 00
    dd   0 , 0
    dd   0 , 0 , 0 , 0 , 0 , 0 , 0
    dd   0 , 0 , 0 , 0 , 0 , 0 , 0
    dd   0 , 0 , 0 , 0 , 0 , 0 , 0
    dd   0 , 0 , 0 , 0
    dd   00 , 00 , 20 , 20 , 20 , 20 , 20 , 00 , 00 , 00
    dd   00 , 00 , 20 , 20 , 20 , 20 , 20 , 00 , 00 , 00
    dd   1 , 1 , 1 , 1 , 1 , 1 , 1
    dd   1 , 1 , 1 , 1 , 1 , 1 , 1 , 1 , 1 , 1
    dd   1 , 1 , 1 , 1 , 1 , 1
    dd   0 , 0 , 0 , 0
    dd   00 , 00 ,-20 ,-20 ,-20 ,-20 ,-20 , 00 , 00 , 00
    dd   00 , 00 ,-20 ,-20 ,-20 ,-20 ,-20 , 00 , 00 , 00
    dd   1000,1000
    dd   0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0
    dd   0 , 0 , 0 , 0 , 0 , 0 , 0
    dd   0 , 0 , 0 , 0 , 0
    dd   0 , 0 , 0 , 0 , 0
    dd   00 , 00 , 20 , 20 , 20 , 20 , 20 , 00 , 00 , 00
    dd   00 , 00 , 20 , 20 , 20 , 20 , 20 , 00 , 00 , 00
    dd   1 , 1 , 1 , 1 , 1
    dd   1 , 1 , 1 , 1 , 1
    dd   1 , 1 , 1 , 1 , 1 , 1 , 1 , 1 , 1 , 1
    dd   10 , 10 , 20 , 20 , 20 , 20 , 00 , 00 , 00 , 00
    dd   1 , 1 , 1 , 1 , 1 , 1 , 1
    dd   1 , 1 , 1 , 1 , 1 , 1 , 1
    dd   0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0
    dd   0 , 0 , 0
    dd   00 , 00 , 20 , 20 , 20 , 20 , 20 , 00 , 00 , 00
    dd   0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0
    dd   00 , 00 , 20 , 20 , 20 , 20 , 20 , 00 , 00 , 00
    dd   00 , 00 ,-20 ,-20 ,-20 ,-20 ,-20 , 00 , 00 , 00
    dd   00 , 00 , 20 , 20 , 20 , 20 , 20 , 00 , 00 , 00
    dd   0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0
    dd   0 , 0 , 0
    dd   00 , 00 , 00 , 00 , 00 , 20 , 20 , 20 , 20 , 20
    dd   10 , 10 , 10 , 10 , 10 , 10 , 10 , 10 , 10 , 10
    dd   2  , 2  ,  2 , 2 , 2 , 2 , 2
    dd   2  , 2  ,  2 , 2 , 2 , 2 , 2
    dd   00 , 00 ,-20 ,-20 ,-20 ,-20 ,-20 , 00 , 00 , 00
    dd   0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0
    dd   00 , 00 , 20 , 20 , 20 , 20 , 20 , 00 , 00 , 00
    dd   00
    dd   10 , 10 , 20 , 20 , 20 , 20 , 00 , 00 , 00 , 00
    dd   2 , 2 , 2 , 2 , 2 , 2 , 2 , 2 , 2
    dd   2 , 2 , 2 , 2 , 2 , 2 , 2 , 2 , 2
    dd   00 , 00 , 20 , 20 , 20 , 20 , 20 , 00 , 00 , 00
    dd   2 , 2 , 2 , 2 , 2
    dd   2 , 2 , 2 , 2 , 2 , 2 , 2
    dd   2 , 2 , 2 , 2 , 2 , 2 , 2 , 2 , 2
    dd   2 , 2 , 2 , 2
    dd   00 , 00 , 00 , 00 , 00 , 00
    dd   20 , 20 , 30 , 30 , 00
    dd   65535

image_end:









