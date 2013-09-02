;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   64 bit Menuet USB info
;
;   Compile with FASM 1.60 or above
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use64

    org   0x0

    db    'MENUET64'              ; Header identifier
    dq    0x01                    ; Version
    dq    START                   ; Start of code
    dq    image_end               ; Size of image
    dq    0x100000                ; Memory for app
    dq    0xffff0                 ; Esp
    dq    0x00                    ; Prm
    dq    0x00                    ; Icon


START:

    mov   rax , 141         ; Sysfont
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    call  draw_window       ; At first, draw the window

still:

    mov   rax , 23          ; Wait here for event
    mov   rbx , 20
    int   0x60

    test  rax , 0x1         ; Window redraw
    jnz   window_event
    test  rax , 0x2         ; Keyboard press
    jnz   key_event
    test  rax , 0x4         ; Button press
    jnz   button_event

    call  display_usb

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

    cmp   rbx , 200
    jb    nousbscreensw
    cmp   rbx , 201
    ja    nousbscreensw
    sub   rbx , 200
    cmp   [usbscreen],rbx
    je    still
    mov   [usbscreen],rbx
    call  clear_area
    mov   [prevstate], dword -1
    mov   [checksum], dword 0xff
    call  display_usb
    jmp   still
  nousbscreensw:

    jmp   still


draw_window:

    mov   rax , 0xC                          ; Beginning of window draw
    mov   rbx , 0x1
    int   0x60

    mov   rax , 141                          ; Current font size
    mov   rbx , 3
    int   0x60
    and   rax , 0xff
    mov   [fontsize],rax

    mov   rax , 0x0                          ; Draw window
    mov   rbx , 130 shl 32 + 519             ; x start & size
    mov   rcx ,  35 shl 32 + 317             ; y start & size
    mov   rdx , [fontsize]
    sub   rdx , 9
    imul  rdx , 16
    add   rcx , rdx
    mov   rdx , 0x0000000000FFFFFF           ; type    & border color
    mov   r8  , 0x0000000000000001           ; draw flags
    mov   r9  , window_label                 ; 0 or label - asciiz
    mov   r10 , menu_struct                  ; 0 or pointer to menu struct
    int   0x60

    mov   rax , 8                            ; USB 1.X
    mov   rbx , 384 shl 32 + 58
    mov   rcx , 050 shl 32 + 19
    mov   rdx , 200
    mov   r8  , 0
    mov   r9  , button_text
    int   0x60

    mov   rax , 8                            ; USB 2.0
    mov   rbx , 442 shl 32 + 58
    mov   rcx , 050 shl 32 + 19
    mov   rdx , 201
    mov   r8  , 0
    mov   r9  , button_text2
    int   0x60

    mov   [prevstate], dword -1
    mov   [checksum], dword 0xff
    call  display_usb

    mov   rax , 0xC                          ; End of window draw
    mov   rbx , 0x2
    int   0x60

    ret


display_usb:

    cmp   [usbscreen],dword 0
    jne   noscr0
    call  get_usb_state
    cmp   rax , 0
    je    noscr0
    call  draw_state
  noscr0:

    cmp   [usbscreen],dword 1
    jne   noscr1
    call  display_dev
  noscr1:

    ret


clear_area:

    mov   rax , 13
    mov   rbx , 10 shl 32 + 300
    mov   rcx , 50 shl 32 + 41
    mov   rdx , 0xffffff
    int   0x60

    mov   rax , 13
    mov   rbx , 10 shl 32 + 500
    mov   rcx , 90 shl 32 + 16
    mov   rdx , 0xffffff
    int   0x60

    ret


draw_state:

    tr equ 46

    mov   rax , 4                            ; Display text
    mov   rbx , text2                        ; Pointer to text
    mov   rcx , 21                           ; X position
    mov   rdx , 54                           ; Y position
    mov   rsi , 0x000000                     ; Color
    mov   r9  , 1                            ; Font
    int   0x60
    mov   rbx , tdu
    add   rdx , 20
    int   0x60

    ; Display port information

    mov   rax , 4
    mov   rbx , text22
    mov   rcx , 21
    mov   rdx , 0x36+40
    mov   rsi , 0x0
    mov   r9  , 0x1
    mov   r8  , 0x2
    int   0x60

    mov   rcx , 1

  new_device2:

    push  rcx

    ; Default device info

    mov   rsi , device_info_default
    mov   rdi , device_info
    mov   rcx , device_info_default_end - device_info_default
    cld
    rep   movsb

    s2    equ 41

    ; Port number

    mov   rax , [rsp]
    ; uhci
    cmp   [controller],dword 2
    jne   nouhcil1
    dec   rax
    and   rax , 7
    inc   rax
  nouhcil1:
    ;
    xor   rdx , rdx
    mov   rbx , 10
    div   rbx
    mov   [device_info],al
    mov   [device_info+1],dl
    add   [device_info],word 0x3030
    mov   [device_info+s2],al
    mov   [device_info+1+s2],dl
    add   [device_info+s2],word 0x3030

    ; Device present ?
    mov   rbx , 'No Devic'
    mov   [device_info+5],rbx
    mov   [device_info+5+s2],rbx
    mov   [device_info+13],byte 'e'
    mov   [device_info+13+s2],byte 'e'
    ;
    ; Left column
    ;
    ; Device connected
    mov   rax , 131
    mov   rbx , 12
    mov   rcx , 0
    mov   rdx , [rsp]
    ; uhci
    cmp   [controller],dword 2
    jne   nouhcil2
    dec   rdx
    mov   r10 , rdx
    shr   r10 , 3
    shl   r10 , 1
    add   rcx , r10
    and   rdx , 7
    inc   rdx
  nouhcil2:
    ;
    int   0x60
    cmp   rax , 0
    je    noportinuse
    mov   rbx , 'Connecte'
    mov   [device_info+5],rbx
    mov   [device_info+13],byte 'd'
  noportinuse:
    ;
    ; Right column
    ;
    mov   rax , 131
    mov   rbx , 12
    mov   rcx , 1
    mov   rdx , [rsp]
    ; uhci
    cmp   [controller],dword 2
    jne   nouhcil3
    dec   rdx
    mov   r10 , rdx
    shr   r10 , 3
    shl   r10 , 1
    add   rcx , r10
    and   rdx , 7
    inc   rdx
  nouhcil3:
    ;
    int   0x60
    cmp   rax , 0
    je    noportinuse2
    mov   rbx , 'Connecte'
    mov   [device_info+5+s2],rbx
    mov   [device_info+13+s2],byte 'd'
  noportinuse2:

    ; Mouse
    mov   rax , [rsp]
    mov   rbx , [mousepos]
    shr   rbx , 16
    cmp   rbx , rax
    jne   nomousec
    mov   rdx , [mousepos]
    shr   rdx , 8
    and   rdx , 0xff
    imul  rdx , s2
    mov   rbx , 'Mouse   '
    mov   [device_info+17+rdx],rbx
  nomousec:

    ; Keyboard
    mov   rax , [rsp]
    mov   rbx , [kbdpos]
    shr   rbx , 16
    cmp   rbx , rax
    jne   nokbdc
    mov   rdx , [kbdpos]
    shr   rdx , 8
    and   rdx , 0xff
    imul  rdx , s2
    mov   rbx , 'Keyboard'
    mov   [device_info+17+rdx],rbx
  nokbdc:

    ; Clear
    mov   rax , 13
    mov   rbx , 19 shl 32 + 6*80 +2
    mov   rcx , [rsp]
    mov   r12 , [fontsize]
    add   r12 , 3
    imul  rcx , r12 ; 12
    add   rcx , 97
    cmp   [fontsize],dword 10
    jbe   noydec2
    dec   rcx
  noydec2:
    shl   rcx , 32
    add   rcx , [fontsize]
    add   rcx , 2
    mov   rdx , 0xf2f2f2
    int   0x60
    mov   rbx , 258 shl 32 + 6
    mov   rdx , 0xffffff
    int   0x60

    ; Display
    mov   rax , 4
    mov   rbx , device_info
    mov   rcx , 21
    mov   rdx , [rsp]
    mov   r12 , [fontsize]
    add   r12 , 3
    imul  rdx , r12
    add   rdx , 99
    mov   rsi , 0x0
    mov   r9  , 0x1
    mov   r8  , 0x2
    int   0x60

    pop   rcx

    inc   rcx
    cmp   rcx , 16
    jbe   new_device2

    ret


get_usb_state:

    mov   rax , 131
    mov   rbx , 2
    int   0x60
    mov   r10 , rax
    mov   r11 , rbx
    mov   rax , 131
    mov   rbx , 1
    int   0x60
    mov   [controller],byte 1
    cmp   rax , 1
    je    show_ohci
    cmp   r10 , 0
    je    show_ohci
    mov   [controller],byte 2
    mov   rax , r10
    mov   rbx , r11
  show_ohci:

    mov   r15 , rax
    shl   r15 , 8
    add   r15 , rbx
    shl   r15 , 8

    tx equ 15

    mov   [text2+0*tr+tx+0],dword 'Disa'
    mov   [text2+0*tr+tx+4],dword 'bled'
    mov   [text2+0*tr+tx+8],dword '    '
    cmp   rax , 1
    jne   noohci1
    mov   [text2+0*tr+tx+0],dword 'Enab'
    mov   [text2+0*tr+tx+4],dword 'led '
    mov   [text2+0*tr+tx+8],dword '(x x'
    mov   [text2+0*tr+tx+12],dword ' ohc'
    mov   [text2+0*tr+tx+16],dword 'i)  '
    cmp   [controller],byte 2
    jne   nocuhci
    mov   [text2+0*tr+tx+12],dword ' uhc'
  nocuhci:
    add   bl , 48
    mov   [text2+0*tr+tx+8+1],bl
  noohci1:
    cmp   rax , 2
    jb    noohci2
    mov   [text2+0*tr+tx+0] ,dword 'Fail'
    mov   [text2+0*tr+tx+4] ,dword '(  ,'
    mov   [text2+0*tr+tx+8] ,dword 'ohci'
    cmp   [controller],byte 2
    jne   nocu
    mov   [text2+0*tr+tx+8] ,dword 'uhci'
  nocu:
    mov   [text2+0*tr+tx+12],dword ')   '
    xor   rdx , rdx
    mov   rbx , 10
    div   rbx
    add   al , 48
    add   dl , 48
    mov   [text2+0*tr+tx+4+1],al
    mov   [text2+0*tr+tx+4+2],dl
  noohci2:

    mov   rax , 131
    mov   rbx , 11
    int   0x60

    ; uhci
    cmp   [controller],dword 2
    jne   nouhcil4
    mov   rcx , rax
    shr   rcx , 8
    shr   rcx , 1
    shl   rcx , 3
    shl   rcx , 16
    add   rax , rcx
    and   rax , 0xff01ff
    mov   rcx , rbx
    shr   rcx , 8
    shr   rcx , 1
    shl   rcx , 3
    shl   rcx , 16
    add   rbx , rcx
    and   rbx , 0xff01ff
  nouhcil4:
    ;

    mov   [mousepos],rax
    mov   [kbdpos],rbx

    add   r15 , rax
    shl   r15 , 8
    add   r15 , rbx
    shl   r15 , 8

    mov   rdx , 1
  readps:
    mov   rax , 131
    mov   rbx , 12
    mov   rcx , 0
    int   0x60
    add   r15 , rax
    mov   rax , 131
    mov   rbx , 12
    mov   rcx , 1
    int   0x60
    add   r15 , rax
    ;uhci
    cmp   [controller],dword 2
    jne   nouhcil5
    mov   rax , 131
    mov   rbx , 12
    mov   rcx , 2
    int   0x60
    add   r15 , rax
    mov   rax , 131
    mov   rbx , 12
    mov   rcx , 3
    int   0x60
    add   r15 , rax
  nouhcil5:
    ;
    inc   rdx
    cmp   rdx , 16
    jbe   readps

    mov   rax , 0
    cmp   r15 , [prevstate]
    je    statesame
    mov   rax , 1
    mov   [prevstate],r15
  statesame:

    ret


display_dev:

    ;
    ; Scan for change
    ;

    mov   rcx , 1
    mov   r15 , 0

  newprescan:

    mov   rax , 127
    mov   rbx , 2
    int   0x60

    add   r15 , rax

    mov   rax , 127
    mov   rbx , 3
    mov   rdx , image_end
    mov   r8  , 32
    int   0x60

    add   r15 , [image_end]

    mov   rax , 127
    mov   rbx , 4
    mov   rdx , image_end
    mov   r8  , 32
    int   0x60

    add   r15 , [image_end]

    mov   rax , 127
    mov   rbx , 5
    mov   rdx , image_end
    mov   r8  , 32
    int   0x60

    add   r15 , [image_end]

    imul  r15 , rcx

    add   rcx , 1
    cmp   rcx , 16
    jbe   newprescan

    cmp   r15 , [checksum]
    je    no_device_display

    mov   [checksum],r15

    ;
    ; Display information
    ;

    mov   rax , 127
    mov   rbx , 1
    int   0x60

    mov   r15 , 'Disabled'
    cmp   rax , 1
    jne   usbs1
    mov   r15 , 'Enabled '
    ;mov   r14 , '(1 x ehc'
    ;mov  [text+11+4+8],r14
    ;mov  [text+11+4+8+8],word 'i)'
  usbs1:
    cmp   rax , 1
    jbe   usbs2
    xor   rdx , rdx
    mov   rbx , 10
    div   rbx
    mov   ah , dl
    mov   r15 , 'Fail(00)'
    shl   rax , 40
    add   r15 , rax
  usbs2:

    mov  [text+11+4],r15

    mov   rax , 4
    mov   rbx , text
    mov   rcx , 21
    mov   rdx , 0x36
    mov   rsi , 0x0
    mov   r9  , 0x1
    mov   r8  , 0x2
    int   0x60
    add   rbx , 50
    add   rdx , 20
    int   0x60
    add   rbx , 50
    add   rdx , 20
    int   0x60

    ;
    ; Display port information
    ;

    mov   rcx , 1

  new_device:

    push  rcx

    ; Default device info

    mov   rsi , device_info_default
    mov   rdi , device_info
    mov   rcx , device_info_default_end - device_info_default
    cld
    rep   movsb

    ; Port number

    mov   rax , [rsp]
    xor   rdx , rdx
    mov   rbx , 10
    div   rbx
    mov   [device_info],al
    mov   [device_info+1],dl
    add   [device_info],word 0x3030

    ; USB version

    mov   rax , 127
    mov   rbx , 2
    mov   rcx , [rsp]
    int   0x60

    cmp   rax , 0
    je    doclear

    mov   rbx , 'Reading '
    mov   [device_info+5],rbx
    mov   bl , ' '
    mov   [device_info+5+8],bl

    cmp   rax , 3
    je    doclear

    cmp   rax , 1
    jne   nousb1x
    mov   rbx , 'Disabled'
    mov   [device_info+5],rbx
    mov   [device_info+13],byte ' '
    mov   [device_info+17],dword 'USB '
    mov   [device_info+21],dword '1.X '
    jmp   doclear
  nousb1x:

    cmp   rax , 2
    jne   nousb2
    mov   rbx , 'Connecte'
    mov   [device_info+5],rbx
    mov   [device_info+13],byte 'd'
    mov   [device_info+17],dword 'USB '
    mov   [device_info+21],dword '2.0 '
  nousb2:

    ;
    ; Manufacturer/product present
    ;
    mov   r12 , 0

    ;
    ; Manufacturer string
    ;
    mov   rax , 127
    mov   rbx , 3
    mov   rcx , [rsp]
    mov   rdx , device_info+37
    mov   r8  , 32
    int   0x60
    mov   rdx , device_info+36
    ;mov   [rdx+1],byte 0
  news:
    inc   rdx
    cmp   [rdx],byte 0
    ja    news

    ;
    ; Manufacturer id
    ;
    cmp   rdx , device_info+37
    jne   nosetm
    mov   rsi , 8
    call  add_mp_string
  nosetm:

    ;
    ; Add space
    ;
    mov   [rdx],word ': '
    add   rdx , 2

    ;
    ; Product string
    ;
    mov   rax , 127
    mov   rbx , 4
    mov   rcx , [rsp]
    mov   r8  , 32
    int   0x60
    mov   r9 , rdx
    dec   rdx
    ;mov   [rdx+1],byte 0
  news2:
    inc   rdx
    cmp   [rdx],byte 0
    ja    news2

    ;
    ; Product id
    ;
    cmp   rdx , r9
    jne   nosetm2
    mov   rsi , 10
    call  add_mp_string
  nosetm2:

    ;
    ; Add space
    ;
    mov   [rdx],dword '    '
    add   rdx , 1
    mov   r14 , rdx

    ;
    ; Device class string
    ;
    cmp   r12 , 0
    je    noclassread
    mov   rax , 127
    mov   rbx , 6
    mov   rcx , [rsp]
    mov   rdx , 1
    mov   r8  , 4
    int   0x60
    cmp   rax , 0
    je    noclassread
    cmp   rax , 16
    ja    noclassread
    imul  rax , 10
    mov   rbx , [usb_classes+rax]
    mov   [r14],rbx
    mov   bx , [usb_classes+rax+8]
    mov   [r14+8],bx
  noclassread:

    ;
    ; Path
    ;
    mov   rax , 127
    mov   rbx , 5
    mov   rcx , [rsp]
    mov   rdx , device_info+27
    mov   r8  , 8
    int   0x60
    cmp   byte [device_info+27],byte 0
    jne   doclear
    mov   byte [device_info+27],'-'
  doclear:

    ;
    ; Ascii zeroes -> ' '
    ;
    mov   rdi , device_info
    mov   rcx , device_info_default_end - device_info_default-3
  asciizero:
    cmp   [rdi],byte 0
    jne   nozero
    mov   [rdi],byte ' '
  nozero:
    inc   rdi
    loop  asciizero

    ;
    ; Clear
    ;
    mov   rax , 13
    mov   rbx , 19 shl 32 + 6*80 +2
    mov   rcx , [rsp]
    mov   r12 , [fontsize]
    add   r12 , 3
    imul  rcx , r12 ; 12
    add   rcx , 97
    cmp   [fontsize],dword 10
    jbe   noydec
    dec   rcx
  noydec:
    shl   rcx , 32
    add   rcx , [fontsize]
    add   rcx , 2
    mov   rdx , 0xf2f2f2
    int   0x60

    ;
    ; Display
    ;
    mov   rax , 4
    mov   rbx , device_info
    mov   rcx , 21
    mov   rdx , [rsp]
    mov   r12 , [fontsize]
    add   r12 , 3
    imul  rdx , r12
    add   rdx , 99
    mov   rsi , 0x0
    mov   r9  , 0x1
    mov   r8  , 0x2
    int   0x60

    pop   rcx

    inc   rcx
    cmp   rcx , 16
    jbe   new_device

  no_device_display:

    ret


add_mp_string:

    ; configuration descriptor available
    push  rdx
    mov   rax , 127
    mov   rbx , 6
    mov   rdx , 1
    mov   r8  , 1
    int   0x60
    pop   rdx
    cmp   rax , 1
    jne   nosetstring
    ;
    mov   [rdx],dword '0x__'
    call  sethex
    add   rdx , 6
    add   r12 , 1
  nosetstring:

    ret



sethex:

    push  rax rbx rcx rdx r8 r9

    mov   r9  , rdx
    mov   rax , 127
    mov   rbx , 6
    mov   rdx , 1
    mov   r8  , rsi
    int   0x60
    mov   rbx , 16
    xor   rdx , rdx
    div   rbx
    and   rax , 0xff
    and   rdx , 0xff
    mov   rax , [hexchar+rax]
    mov   rdx , [hexchar+rdx]
    mov   [r9+5],dl
    mov   [r9+4],al

    mov   rax , 127
    mov   rbx , 6
    mov   rdx , 1
    mov   r8  , rsi
    add   r8  , 1
    int   0x60
    mov   rbx , 16
    xor   rdx , rdx
    div   rbx
    and   rax , 0xff
    and   rdx , 0xff
    mov   rax , [hexchar+rax]
    mov   rdx , [hexchar+rdx]
    mov   [r9+3],dl
    mov   [r9+2],al

    pop   r9 r8 rdx rcx rbx rax

    ret



;
; Data area
;

window_label:

    db    'USB DEVICES',0

device_info:

    db    '00   No Device  ---  ---  ---                             '
    db    '                                                          ',0

device_info_default:

    db    '00   No Device                                            '
    db    '                                                          ',0

device_info_default_end:

text:

    db    'USB 2.0 state:                                   ',0
tdu:db    'Define USB state at Config.mnt and reboot.       ',0
    db    'Port Status      Protocol  Path      Manufacturer and product',0

text2:

    db    'USB 1.X state:                               ',0

text22:

    db    'Port Status      Device                  '
    db    'Port Status      Device',0

usb_classes:

    db    '()        '
    db    '(Audio)   '
    db    '(Cdc-ctrl)'
    db    '(Hid)     '
    db    '()        '
    db    '(Pid)     '
    db    '(Image)   '
    db    '(Printer) '
    db    '(Storage) '
    db    '(Hub)     '
    db    '(Cdc-data)'
    db    '(Card)    '
    db    '()        '
    db    '(Security)'
    db    '(Video)   '
    db    '(Health)  '
    db    '(A/V)     '
    db    '()        '
    db    '()        '
    db    '()        '
    db    '()        '

usbscreen:  dq 0x1
fontsize:   dq 0x0
checksum:   dq 0x0
prevstate:  dq -1
mousepos:   dq 0x0
kbdpos:     dq 0x0
controller: dq 0x0

button_text:   db  'USB 1.X',0
button_text2:  db  'USB 2.0',0

hexchar:  db  '0123456789ABCDEF',0

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

image_end:

