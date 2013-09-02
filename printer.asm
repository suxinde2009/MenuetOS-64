;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Printer setup
;
;   Compile with FASM 1.60 or above
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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

include  'textbox.inc'

printer_data  equ  0x80000

START:

    mov   rax , 141
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    call  read_printer_setup

    cmp   [Param+8],dword 'NET'
    je    spool_to_net_printer

    call  draw_window       ; At first, draw the window

still:

    call  check_status

    mov   rax , 23          ; Wait here for event
    mov   rbx , 100
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

    cmp   rbx , 1001
    jne   no_textbox1
    mov   r14 , textbox1
    call  read_textbox
    call  decode_textbox
    jmp   still
  no_textbox1:

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

    cmp   rbx , 100
    jb    no_group_1
    cmp   rbx , 199
    ja    no_group_1
    sub   rbx , 99
    mov   [paper],rbx
    call  draw_buttons
    jmp   still
  no_group_1:

    cmp   rbx , 200
    jb    no_group_2
    cmp   rbx , 299
    ja    no_group_2
    sub   rbx , 199
    mov   [language],rbx
    call  draw_buttons
    jmp   still
  no_group_2:

    cmp   rbx, 400
    jb    no_group_3
    cmp   rbx , 499
    ja    no_group_3
    sub   rbx , 399
    mov   [resolution],rbx
    call  draw_buttons
    jmp   still
  no_group_3:

    cmp   rbx, 500
    jb    no_group_4
    cmp   rbx , 599
    ja    no_group_4
    sub   rbx , 500
    mov   [datato],rbx
    call  draw_buttons
    jmp   still
  no_group_4:

    cmp   rbx , 10000
    jb    no_scroll_top
    cmp   rbx , 10999
    ja    no_scroll_top
    mov   [scroll_top_value],rbx
    call  scroll_top
    jmp   still
  no_scroll_top:

    cmp   rbx , 11000
    jb    no_scroll_left
    cmp   rbx , 11999
    ja    no_scroll_left
    mov   [scroll_left_value],rbx
    call  scroll_left
    jmp   still
  no_scroll_left:

    cmp   rbx , 12000
    jb    no_scroll_right
    cmp   rbx , 12999
    ja    no_scroll_right
    mov   [scroll_right_value],rbx
    call  scroll_right
    jmp   still
  no_scroll_right:

    cmp   rbx , 13000
    jb    no_scroll_bottom
    cmp   rbx , 13999
    ja    no_scroll_bottom
    mov   [scroll_bottom_value],rbx
    call  scroll_bottom
    jmp   still
  no_scroll_bottom:

    cmp   rbx , 301
    jne   no_read
    call  read_printer_setup
    call  draw_window
    jmp   still
  no_read:

    cmp   rbx , 302
    jne   no_set
    call  set_printer_setup
    jmp   still
  no_set:

    jmp   still


spool_to_net_printer:

    ; Open socket

    mov   rax , 3
    mov   rbx , 1
    int   0x60
    mov   rcx , rax
    shr   rcx , 16
    and   rcx , 0xff
    add   rcx , 9000 ; local port

    mov   rax , 53
    mov   rbx , 5
    mov   edx , [printer_port]
    mov   esi , [printer_ip]
    mov   rdi , 1
    int   0x60

    mov   [printer_socket],rax

    mov   rax , 5
    mov   rbx , 100
    int   0x60

    call  show_status

    ; Send 700+ bytes at a time

    mov   [data_pointer],dword printer_data

  newdataprint:

    mov   r15 , 0

  newdataprint2:

    mov   rax , 129
    mov   rbx , 7
    mov   rcx , 1
    mov   rdx , [data_pointer]
    mov   r8  , [net_status]
    int   0x60

    cmp   rbx , 0
    jne   nodelay
    push  rbx
    mov   rax , 5
    mov   rbx , 1
    int   0x60
    pop   rbx
    inc   r15
    cmp   r15 , 100
    jae   datasent
  nodelay:

    cmp   rbx , 0
    je    newdataprint2

    add   [data_pointer],rbx

    cmp   [data_pointer],dword printer_data+700
    jb    newdataprint

    ; If network printer isnt connected, just read the data, no send

    cmp   [net_status],dword 4
    jne   send_ok

    mov   r10 , 20*5

  new_send_try:

    mov   rax , 53
    mov   rbx , 7
    mov   rcx , [printer_socket]
    mov   rdx , [data_pointer]
    sub   rdx , printer_data
    mov   rsi , printer_data
    int   0x60

    cmp   rax , 0
    je    send_ok

    dec   r10
    jz    send_timeout

    mov   rax , 5
    mov   rbx , 5
    int   0x60

    jmp   new_send_try

  send_timeout:

    mov   rax , 5
    mov   rbx , 100
    int   0x60

    ; Close socket

    mov   rax , 53
    mov   rbx , 8
    mov   rcx , [printer_socket]
    int   0x60

  send_ok:

    call  show_status

    mov   [data_pointer],dword printer_data

    mov   rax , 5
    mov   rbx , 5
    int   0x60

    jmp   newdataprint

  datasent:

    ; Send rest of the data

    mov   rax , 53
    mov   rbx , 7
    mov   rcx , [printer_socket]
    mov   rdx , [data_pointer]
    sub   rdx , printer_data
    cmp   rdx , 0
    je    nodataout
    mov   rsi , printer_data
    int   0x60
  nodataout:

    mov   rax , 5
    mov   rbx , 100
    int   0x60

    ; Close socket

    mov   rax , 53
    mov   rbx , 8
    mov   rcx , [printer_socket]
    int   0x60

    mov   rax , 512
    int   0x60


show_status:

    ; Get status

    mov   rax , 53
    mov   rbx , 6
    mov   rcx , [printer_socket]
    int   0x60
    mov   [net_status],rax

    ret


    ; Update once a second

    mov   rax , 26
    mov   rbx , 1
    mov   rcx , image_end
    mov   rdx , 1024
    int   0x60
    mov   rax , [image_end+5*8]
    cmp   rax , [update]
    jb    no_update
    add   rax , 100
    mov   [update],rax

    ; Get status

    mov   rax , 53
    mov   rbx , 6
    mov   rcx , [printer_socket]
    int   0x60
    mov   [net_status],rax

    ; If status fine, do not draw window

    cmp   rax , 4
    je    no_window_draw

    mov   rax , '        '
    mov   [text+30],rax
    mov   rax , '        '
    mov   [text+38],eax

    call  draw_window

    ; Display status

    mov   rax , 13
    mov   rbx , 30 shl 32 + 200
    mov   rcx , 79 shl 32 + 20+2
    mov   rdx , 0xffffff
    int   0x60
    mov   rbx , net_connected
    cmp   [net_status],dword 4
    je    netconnected
    mov   rbx , net_disconnected
  netconnected:

    mov   rax , 4
    mov   rcx , 30
    mov   rdx , 80
    mov   rsi , 0x000000
    mov   r9  , 1
    int   0x60

  no_window_draw:
  no_update:

    ret



decode_textbox:

    mov   rsi , textbox1+6*8
    mov   rdi , printer_ip
  decodemore:
    mov   rax , 0
  decodechar:
    cmp   [rsi] , byte '.'
    je    dedone
    cmp   [rsi] , byte ':'
    je    dedone
    cmp   [rsi] , byte ' '
    jbe   dedone2
    imul  rax , 10
    movzx rbx , byte [rsi]
    add   rax , rbx
    sub   rax , 48
    inc   rsi
    jmp   decodechar
  dedone:
    mov   [rdi],al
    inc   rdi
    inc   rsi
    jmp   decodemore
  dedone2:
    mov   [printer_port],ax

    call  set_text

    mov   r14 , textbox1
    call  draw_textbox

    ret


set_text:

    mov   rdi , textbox1+6*8
    mov   rsi , printer_ip

  newip:

    movzx rax , byte [rsi]
    xor   rdx , rdx
    mov   rbx , 10
    div   rbx
    add   dl , 48
    mov   [rdi+2],dl
    xor   rdx , rdx
    div   rbx
    add   dl , 48
    add   al , 48
    mov   [rdi+1],dl
    mov   [rdi+0],al

    inc   rsi

    mov   [rdi+3],byte '.'
    add   rdi , 4
    cmp   rdi , textbox1+6*8+15
    jb    newip

    mov   [rdi-1],byte ':'

    movzx rax , word [printer_port]
    xor   rdx , rdx
    mov   rbx , 10
    div   rbx
    add   dl , 48
    mov   [rdi+4],dl
    xor   rdx , rdx
    div   rbx
    add   dl , 48
    mov   [rdi+3],dl
    xor   rdx , rdx
    div   rbx
    add   dl , 48
    mov   [rdi+2],dl
    xor   rdx , rdx
    div   rbx
    add   al , 48
    add   dl , 48
    mov   [rdi+1],dl
    mov   [rdi+0],al

    mov   [textbox1+5*8],dword 21
    mov   r10 , 4
  newtbmove:
    cmp   [textbox1+6*8+16],byte '0'
    jne   notbmove
    dec   dword [textbox1+5*8]
    mov   rdi , textbox1+6*8+16
    mov   rsi , rdi
    inc   rsi
    mov   rcx , 5
    cld
    rep   movsb
    dec   r10
    jnz   newtbmove
  notbmove:

    ret


read_printer_setup:

    mov   rax , 129
    mov   rbx , 2
    mov   rcx , 1
    int   0x60

    shr   rbx , 8
    mov   [datato],bl
    shr   rbx , 8
    mov   [printer_port],bx
    shr   rbx , 16
    mov   [printer_ip],ebx

    push  rax
    call  set_text
    pop   rax

    shr   rax , 8
    cmp   al , 1
    jne   noascii
    mov   al , 1
  noascii:
    cmp   al , 30
    jne   nopcl3
    mov   al , 2
  nopcl3:
    cmp   al , 55
    jne   nopcl5
    mov   al , 3
  nopcl5:
    cmp   al , 102
    jne   nops2
    mov   al , 4
  nops2:
    mov   [language],al
    shr   rax , 8
    mov   [paper],al
    shr   rax , 8
    mov   [resolution],al

    shr   rax , 8
    movzx rbx , al
    add   rbx , 13000
    mov   [scroll_bottom_value], rbx
    shr   rax , 8
    movzx rbx , al
    add   rbx , 12000
    mov   [scroll_right_value], rbx
    shr   rax , 8
    movzx rbx , al
    add   rbx , 11000
    mov   [scroll_left_value], rbx
    shr   rax , 8
    movzx rbx , al
    add   rbx , 10000
    mov   [scroll_top_value], rbx

    ret


set_printer_setup:

    mov   rbx , [scroll_top_value]
    sub   rbx , 10000
    mov   rax , rbx
    mov   rbx , [scroll_left_value]
    sub   rbx , 11000
    shl   rax , 8
    add   rax , rbx
    mov   rbx , [scroll_right_value]
    sub   rbx , 12000
    shl   rax , 8
    add   rax , rbx
    mov   rbx , [scroll_bottom_value]
    sub   rbx , 13000
    shl   rax , 8
    add   rax , rbx

    shl   rax , 8
    mov   al , [resolution]
    shl   rax , 8
    mov   al , [paper]
    shl   rax , 8
    mov   al , [language]

    cmp   al , 1
    jne   noascii2
    mov   al , 1
  noascii2:
    cmp   al , 2
    jne   nopcl32
    mov   al , 30
  nopcl32:
    cmp   al , 3
    jne   nopcl52
    mov   al , 55
  nopcl52:
    cmp   al , 4
    jne   nops22
    mov   al , 102
  nops22:

    shl   rax , 8

    mov   rdx , rax

    mov   r8  , [printer_ip]
    shl   r8  , 16
    mov   r8w , [printer_port]
    shl   r8  , 8
    mov   r8b , [datato]
    shl   r8  , 8

    mov   rax , 129
    mov   rbx , 3
    mov   rcx , 1
    int   0x60

    ret

linestart  equ 60
linestep   equ 14
winx       equ 342

check_status:

    mov   rax , 129
    mov   rbx , 2
    mov   rcx , 1
    int   0x60

    and   rax , 0xff
    and   rbx , 0xff

    mov   rcx , rax
    shl   rcx , 8
    add   rcx , rbx
    cmp   rcx , [current_status]
    je    no_status_change

    mov   [current_status], rcx

    mov   rcx , 'USB 2.0 '
    mov   [text+09],rcx
    mov   rcx , 'Disconne'
    mov   [text+17],rcx
    mov   rcx , 'cted'
    mov   [text+25],ecx
    cmp   al , 0
    je    printer_disconnected
    mov   rcx , 'USB 2.0 '
    mov   [text+09],rcx
    mov   rcx , 'Connecte'
    mov   [text+17],rcx
    mov   rcx , 'd   '
    mov   [text+25],ecx
    cmp   al , 1
    je    usb_printer
    mov   rcx , 'Network '
    mov   [text+09],rcx
    mov   rcx , '        '
    mov   [text+17],rcx
    mov   rcx , '    '
    mov   [text+25],ecx
  usb_printer:

    mov   rax , rbx
    and   rax , 0xff
    xor   rdx , rdx
    mov   rbx , 10
    div   rbx
    add   dl  , 48
    mov   [text+45],dl
    xor   rdx , rdx
    div   rbx
    add   dl  , 48
    add   al  , 48
    mov   [text+44],dl
    mov   [text+43],al

  printer_disconnected:

    cmp   [Param+8],dword 'NET'
    je    no_net_window_2
    mov   rax , 13
    mov   rbx , 20 shl 32 + 300
    mov   rcx , 58 shl 32 + 11+2
    mov   rdx , 0xffffff
    int   0x60
  no_net_window_2:

    call  draw_text

  no_status_change:

    ret



draw_text:

    mov   rax , 0x4                          ; Display text
    mov   rbx , text
    mov   rcx , 30
    mov   rdx , linestart
    mov   rsi , 0x0
    mov   r9  , 0x1
    mov   r8  , 18
    cmp   [Param+8],dword 'NET'
    jne   nofirstline
    mov   r8  , 1
  nofirstline:
  newline:
    int   0x60
    add   rbx , 51
    add   rdx , linestep
    dec   r8
    jnz   newline

    ret


draw_window:

    mov   rax , 0xC                          ; Beginning of window draw
    mov   rbx , 0x1
    int   0x60

    mov   rax , 0x0                          ; Draw window
    mov   rbx , 0x000000C000000000+winx      ; x start & size
    mov   rcx , 0x0000003000000000+293+12*6  ; y start & size
    cmp   [Param+8],dword 'NET'
    jne   no_net_window
    mov   rbx , 0x0000000000000000+270 ; winx      ; x start & size
    mov   rcx , 0x0000000000000000+115       ; y start & size
  no_net_window:
    mov   rdx , 0x0000000000FFFFFF           ; type    & border color
    mov   r8  , 0x0000000000000001           ; draw flags
    mov   r9  , window_label                 ; 0 or label - asciiz
    mov   r10 , menu_struct                  ; 0 or pointer to menu struct
    int   0x60

    mov   [current_status],dword 0xffffff
    call  check_status

    call  draw_text

    cmp   [Param+8],dword 'NET'
    je    nowidgets

    call  draw_buttons

    bsize equ 97

    ; Read

    mov   rax , 8
    mov   rbx , (winx/2-bsize) shl 32 + bsize
    mov   rcx , (322) shl 32 + 19
    mov   rdx , 301
    mov   r8  , 0
    mov   r9  , read
    int   0x60

    ; Apply

    mov   rax , 8
    mov   rbx , (winx/2) shl 32 + bsize
    mov   rcx , (322) shl 32 + 19
    mov   rdx , 302
    mov   r8  , 0
    mov   r9  , apply
    int   0x60

    ; Scrolls

    call  scroll_top
    call  scroll_left
    call  scroll_right
    call  scroll_bottom

    ; Textbox

    mov   r14 , textbox1
    call  draw_textbox

  nowidgets:

    mov   rax , 0xC                          ; End of window draw
    mov   rbx , 0x2
    int   0x60

    ret


draw_buttons:

    ; Buttons group 1

    mov   rax , 8
    mov   rbx ,  29 shl 32 + 11
    mov   rcx , (linestart+linestep*3-3) shl 32 + 11
    mov   rdx , 100
    mov   r8  , 0
    mov   r9  , 0
    int   0x60
    mov   r10 , linestep shl 32
    add   rcx , r10
    inc   rdx
    int   0x60
    mov   r10 , linestep shl 32
    add   rcx , r10
    inc   rdx
    int   0x60
    mov   r10 , linestep shl 32
    add   rcx , r10
    inc   rdx
    int   0x60

    ; Buttons group 2

    mov   rax , 8
    mov   rbx ,  29 shl 32 + 11
    mov   rcx , (linestart+linestep*9-3) shl 32 + 11
    mov   rdx , 200
    mov   r8  , 0
    mov   r9  , 0
    int   0x60
    mov   r10 , linestep shl 32
    add   rcx , r10
    inc   rdx
    int   0x60
    mov   r10 , linestep shl 32
    add   rcx , r10
    inc   rdx
    int   0x60
    mov   r10 , linestep shl 32
    add   rcx , r10
    inc   rdx
    int   0x60

    ; Buttons group 3

    mov   rax , 8
    mov   rbx , (6*24+30) shl 32 + 11
    mov   rcx , (linestart+linestep*3-3) shl 32 + 11
    mov   rdx , 400
    mov   r8  , 0
    mov   r9  , 0
    int   0x60
    mov   r10 , linestep shl 32
    add   rcx , r10
    inc   rdx
    int   0x60
    mov   r10 , linestep shl 32
    add   rcx , r10
    inc   rdx
    int   0x60
    mov   r10 , linestep shl 32
    add   rcx , r10
    inc   rdx
    int   0x60

    ; Buttons group 4

    mov   rax , 8
    mov   rbx , (29) shl 32 + 11
    mov   rcx , (linestart+linestep*15-3) shl 32 + 11
    mov   rdx , 500
    mov   r8  , 0
    mov   r9  , 0
    int   0x60
    mov   r10 , linestep shl 32
    add   rcx , r10
    inc   rdx
    int   0x60

    ; Paper 'x'

    mov   rax , 0x4
    mov   rbx , xtext
    mov   rcx , 32
    mov   rdx , [paper]
    imul  rdx , linestep
    add   rdx , linestart+linestep*2-2
    mov   rsi , 0xffffff
    mov   r9  , 0x1
    int   0x60

    ; Language 'x'

    mov   rax , 0x4
    mov   rbx , xtext
    mov   rcx , 32
    mov   rdx , [language]
    imul  rdx , linestep
    add   rdx , linestart+linestep*8-2
    mov   rsi , 0xffffff
    mov   r9  , 0x1
    int   0x60

    ; Resolution 'x'

    mov   rax , 0x4
    mov   rbx , xtext
    mov   rcx , 32+6*24+1
    mov   rdx , [resolution]
    imul  rdx , linestep
    add   rdx , linestart+linestep*2-2
    mov   rsi , 0xffffff
    mov   r9  , 0x1
    int   0x60

    ; Send data to 'x'

    mov   rax , 0x4
    mov   rbx , xtext
    mov   rcx , 32
    mov   rdx , [datato]
    imul  rdx , linestep
    add   rdx , linestart+linestep*15-2
    mov   rsi , 0xffffff
    mov   r9  , 0x1
    int   0x60

    ret


scrollb equ (linestart+linestep*9-4)
scrolla equ linestep

scrollx equ 252
scrolls equ 60
scrolld equ 6*7


scroll_top:

    mov   rax , 113
    mov   rbx , 2
    mov   rcx , 10000
    mov   rdx , 100
    mov   r8  , [scroll_top_value]
    mov   r9  , scrollb
    mov   r10 , scrollx
    mov   r11 , scrolls
    int   0x60

    call  print_scroll_value

    ret

scroll_left:

    mov   rax , 113
    mov   rbx , 2
    mov   rcx , 11000
    mov   rdx , 100
    mov   r8  , [scroll_left_value]
    mov   r9  , scrollb+scrolla
    mov   r10 , scrollx
    mov   r11 , scrolls
    int   0x60

    call  print_scroll_value

    ret

scroll_right:

    mov   rax , 113
    mov   rbx , 2
    mov   rcx , 12000
    mov   rdx , 100
    mov   r8  , [scroll_right_value]
    mov   r9  , scrollb+scrolla*2
    mov   r10 , scrollx
    mov   r11 , scrolls
    int   0x60

    call  print_scroll_value

    ret

scroll_bottom:

    mov   rax , 113
    mov   rbx , 2
    mov   rcx , 13000
    mov   rdx , 100
    mov   r8  , [scroll_bottom_value]
    mov   r9  , scrollb+scrolla*3
    mov   r10 , scrollx
    mov   r11 , scrolls
    int   0x60

    call  print_scroll_value

    ret


print_scroll_value:

    sub   r8 , rcx

    sub   r10 , scrolld
    add   r9  , 4

    push  r10
    push  r9

    mov   rax , 13
    mov   rbx , r10
    add   rbx , 6
    mov   rcx , r9
    dec   rcx
    shl   rbx , 32
    shl   rcx , 32
    add   rbx , 3*6
    add   rcx , 8+2
    mov   rdx , 0xffffff
    int   0x60

    xor   rdx , rdx
    mov   rax , r8
    mov   rbx , 10
    div   rbx
    add   rdx , 48
    mov   [scrvalue+3],dl
    xor   rdx , rdx
    div   rbx
    add   rdx , 48
    add   rax , 48
    mov   [scrvalue+1],dl
    ;mov   [scrvalue+0],al

    mov   rax , 0x4                          ; Display text
    mov   rbx , scrvalue
    pop   rdx
    pop   rcx
    mov   rsi , 0x0
    mov   r9  , 0x1
    int   0x60

    ret



; Data area

window_label:

    db    'PRINTER',0     ; Window label

text:

    db    'Printer:                        Data sent: 100%   ',0
    db    '                                                  ',0
    db    'Paper size:             Resolution:               ',0
    db    '   A4                      75 dpi / 30 dpcm       ',0
    db    '   B4                      150 dpi / 60 dpcm      ',0
    db    '   Letter                  300 dpi / 120 dpcm     ',0
    db    '   Legal                   600 dpi / 240 dpcm     ',0
    db    '                                                  ',0
    db    'Printer language:       Marginals:                ',0
    db    '   ASCII                Top:      cm              ',0
    db    '   PCL-3 (B&W)          Left:     cm              ',0
    db    '   PCL-5c               Right:    cm              ',0
    db    '   Postscript-L2        Bottom:   cm              ',0
    db    '                                                  ',0
    db    'Send data to:                                     ',0
    db    '   USB 2.0 printer                                ',0
    db    '   Network printer IP:                            ',0
    db    '                                                  ',0


xtext:

    db    'x',0

datato:     dq  0
paper:      dq  0x2
language:   dq  0x3
resolution: dq  0x1

update:     dq  0
net_status: dq  4

net_connected:      db  'Sending data to network printer.',0
net_disconnected:   db  'Network printer not available.',0

scrvalue:        db  ' 0.0',0

printer_ip:      db  192,168,254,200
printer_port:    dq  9100
printer_socket:  dq  0
data_pointer:    dq  0

scroll_top_value:     dq  10000
scroll_left_value:    dq  11000
scroll_right_value:   dq  12000
scroll_bottom_value:  dq  13000

current_status:       dq  0x0

Param:                dq  8,0

textbox1:

    dq     0
    dq     174
    dq     22*6
    dq     279
    dq     1001
    dq     21
    db     '192.168.254.200:9100',0,0,0,0,0,0

read:

    db    'READ',0

apply:

    db    'APPLY',0

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

