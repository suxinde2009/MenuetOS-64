;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Drivers, background, skin for Menuet
;
;   Compile with FASM 1.60 or above
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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

    ; IPC

    mov   rax , 60
    mov   rbx , 1
    mov   rcx , ipc_memory
    mov   rdx , 100
    int   0x60

    call  draw_window       ; At first, draw the window

still:

    mov   rax , 23          ; Wait here for event
    mov   rbx , 10
    int   0x60

    test  rax , 0x1         ; Window redraw
    jnz   window_event
    test  rax , 0x2         ; Keyboard press
    jnz   key_event
    test  rax , 0x4         ; Button press
    jnz   button_event

    cmp   [ipc_memory+16],byte 0
    je    still

    mov   rdi , [waiting]
    imul  rdi , (textbox2-textbox1)
    add   rdi , textbox1+48
    mov   rax , rdi
    mov   rsi , ipc_memory+16
    mov   rcx , 48
    cld
    rep   movsb

    mov   rcx , 0
    dec   rcx
  nextlen:
    inc   rcx
    cmp   [ipc_memory+16+rcx],byte 0
    jne   nextlen
    mov   [rax-8],rcx

    mov   r14 , [waiting]
    imul  r14 , 8
    mov   r14 , [textbox_list+r14]
    call  draw_textbox

    mov   [waiting],dword 0
    mov   [ipc_memory+16],byte 0
    mov   [ipc_memory+8],dword 16

    jmp   still

window_event:

    call  draw_window
    jmp   still

key_event:

    mov   rax , 0x2        ; Read the key and ignore
    int   0x60

    cmp   rbx , 0
    je    still

    jmp   still


button_event:

    mov   rax , 0x11
    int   0x60

    cmp   rbx , 21
    jb    no_read_textbox
    cmp   rbx , 29
    ja    no_read_textbox
    sub   rbx , 21
    imul  rbx , 8
    mov   r14 , [textbox_list+rbx]
    call  read_textbox
    jmp   still
  no_read_textbox:

    cmp   rbx , 31
    jb    no_browse
    cmp   rbx , 39
    ja    no_browse
    sub   rbx , 31
    mov   [waiting],rbx
    mov   rax , 111
    mov   rbx , 1
    int   0x60
    mov   rdi , parameter+6
  newdec:
    mov   rbx , 10
    xor   rdx , rdx
    div   rbx
    add   rdx , 48
    mov   [rdi],dl
    dec   rdi
    cmp   rdi , parameter + 1
    jg    newdec
    mov   rax , 256
    mov   rbx , file_search
    mov   rcx , parameter
    int   0x60
    jmp   still
  no_browse:

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

    ; Load new background

    cmp   rbx , 15+1
    jne   no_new_background
    mov   rsi , textbox6+48
    mov   rdi , param+1
    mov   rcx , 50
    cld
    rep   movsb
    mov   rax , 256
    mov   rbx , draw
    mov   rcx , param
    int   0x60
    jmp   still
  no_new_background:

    ; Load new skin

    cmp   rbx , 14+1
    jne   no_new_skin
    mov   rax , 120
    mov   rbx , 1
    mov   rcx , textbox5+48
    int   0x60
    mov   rax , 120
    mov   rbx , 2
    mov   rcx , 1
    int   0x60
    mov   rax , 120
    mov   rbx , 3
    int   0x60
    jmp   still
  no_new_skin:

    ; Load new driver

    cmp   rbx , 11
    jb    no_new_driver
    cmp   rbx , 13+1
    ja    no_new_driver
    mov   rcx , rbx
    sub   rcx , 11
    imul  rcx , 8
    mov   rcx , [textbox_list+rcx]
    add   rcx , 48
    mov   rax , 116
    mov   rbx , 101
    mov   rdx , 1
    int   0x60
  no_new_driver:

    jmp   still


draw_window:

    mov   rax , 0xC                          ; Beginning of window draw
    mov   rbx , 0x1
    int   0x60

    mov   rax , 0x0                          ; Draw window
    mov   rbx , 72*0x100000000+443           ; x start & size
    mov   rcx , 55*0x100000000+305+50           ; y start & size
    mov   rdx , 0x0000000000ffffff           ; type    & border color
    mov   r8  , 0x0000000000000001           ; draw flags
    mov   r9  , window_label                 ; 0 or label - asciiz
    mov   r10 , menu_struct                  ; 0 or pointer to menu struct
    int   0x60

    ; Browse

    mov   rax , 8
    mov   rbx , 255 * 0x100000000 + 80
    mov   rcx ,  65 * 0x100000000 + 17
    mov   rdx , 31
    mov   r8  , 0
    mov   r9  , browse
    mov   r10 , 50  * 0x100000000
  newbrowse:
    int   0x60
    add   rcx , r10
    inc   rdx
    cmp   rdx , 35+1
    jbe   newbrowse

    ; Apply

    mov   rax , 8
    mov   rbx , 340* 0x100000000 +  80
    mov   rcx , 65  * 0x100000000 + 17
    mov   rdx , 11
    mov   r8  , 0x0
    mov   r9  , apply
    mov   r10 , 50  * 0x100000000
  newapply:
    int   0x60
    add   rcx , r10
    inc   rdx
    cmp   rdx , 15+1
    jbe   newapply

    call  draw_textboxes

    mov   rax , 4
    mov   rbx , text
    mov   rcx , 20
    mov   rdx , 50
    mov   rsi , 0x000000
    mov   r9  , 1
  newtext:
    int   0x60
    add   rdx , 50
    add   rbx , 19
    cmp   rbx , text+19*6
    jb    newtext

    mov   rax , 12
    mov   rbx , 2
    int   0x60

    ret


draw_textboxes:

    mov   r14 , textbox1
    call  draw_textbox
    mov   r14 , textbox2
    call  draw_textbox
    mov   r14 , textbox3
    call  draw_textbox
    mov   r14 , textbox4
    call  draw_textbox
    mov   r14 , textbox5
    call  draw_textbox
    mov   r14 , textbox6
    call  draw_textbox

    ret

; Data area

textbox1:

    dq    0
    dq    20
    dq    230
    dq    65
    dq    21
    dq    19
    db    '/FD/1/DRIVER/I8254X'
    times 50-19 db 0

textbox2:

    dq    0
    dq    20
    dq    230
    dq    115
    dq    22
    dq    21
    db    '/FD/1/DRIVER/INTELHDA'
    times 50-21 db 0

textbox3:

    dq    0
    dq    20
    dq    230
    dq    165
    dq    23
    dq    16
    db    '/FD/1/DRIVER/GRX'
    times 50-16 db 0

textbox4:

    dq    0
    dq    20
    dq    230
    dq    215
    dq    24
    dq    19
    db    '/FD/1/DRIVER/MPU401'
    times 50-19 db 0

textbox5:

    dq    0
    dq    20
    dq    230
    dq    265
    dq    25
    dq    14
    db    '/FD/1/SKIN.BMP'
    times 50-14 db 0

textbox6:

    dq    0
    dq    20   ; X start
    dq    230  ; X size
    dq    315  ; Y start
    dq    26   ; Button ID
    dq    13   ; Text length
    db    '/FD/1/BGR.JPG'
    times 50-13 db 0


window_label:

    db    'SETUP',0

apply:

    db   'APPLY',0

browse:

    db   'BROWSE',0

draw:   db '/FD/1/DRAW',0
param:  db 'B'
        times 256 db 0

textbox_list:  dq textbox1,textbox2,textbox3,textbox4,textbox5,textbox6
file_search:   db '/FD/1/FBROWSER',0
parameter:     db '[000000]',0
waiting:       dq 0x0

startx: dw 100
starty: dw 000

sx: dw 0
sy: dw 0

text:

    db   'Network driver    ',0
    db   'Audio driver      ',0
    db   'Graphics driver   ',0
    db   'Midi driver       ',0
    db   'Window skinning   ',0
    db   'Background picture',0

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

include 'textbox.inc'

ipc_memory:

    dq   0x0
    dq   16
    times 100 db 0

image_end:

