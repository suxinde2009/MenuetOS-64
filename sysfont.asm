;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Sysfont for Menuet
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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

write_font_types:

    mov   [getset],byte 1

    mov   rsi , string_icon_font
    mov   rax , [btpointer1]
    call  get_font_type

    mov   rsi , string_main_menu_font
    mov   rax , [btpointer2]
    call  get_font_type

    mov   rsi , string_file_browser_font
    mov   rax , [btpointer3]
    call  get_font_type

    ret


read_font_types:

    mov   [getset],byte 0

    mov   rsi , string_icon_font
    call  get_font_type
    imul  rax , 6
    add   rax , string_up
    mov   [btpointer1],rax

    mov   rsi , string_main_menu_font
    call  get_font_type
    imul  rax , 6
    add   rax , string_up
    mov   [btpointer2],rax

    mov   rsi , string_file_browser_font
    call  get_font_type
    imul  rax , 6
    add   rax , string_up
    mov   [btpointer3],rax

    ret


get_font_type:

    sub   rax , string_up
    xor   rdx , rdx
    mov   rbx , 6
    div   rbx
    mov   [settype],rax

    mov   rax , 58
    mov   rbx , 0
    mov   rcx , 0
    mov   rdx , -1
    mov   r8  , 0x80000
    mov   r9  , configfile
    int   0x60

    mov   [filesize],rbx

    mov   rdx , 0x80000
    mov   r8  , rbx
    add   r8  , 0x80000

    mov   rax , [rsi]
    mov   rbx , [rsi+8]

  searchnext:

    cmp   [rdx],rax
    jne   nofound
    cmp   [rdx+8],rbx
    jne   nofound

  nextrdx:

    inc   rdx

    cmp   [rdx], word '0x'
    jne   nextrdx

    add   rdx , 1

  nextrdx2:

    inc   rdx

    cmp   [rdx],byte 13
    je    checkend
    cmp   [rdx],byte '#'
    je    checkend
    cmp   [rdx],byte ' '
    je    checkend

    jmp   nextrdx2

  checkend:

    cmp   [getset],byte 1
    je    settypel

    mov   rax , [rdx-1]
    and   rax , 0xff
    sub   rax , 48

    ret

  settypel:

    mov   rax , [settype]
    add   rax , 48
    mov   [rdx-1],al

    ; Delete

    mov   rax , 58
    mov   rbx , 2
    mov   rcx , 0
    mov   rdx , [filesize]
    mov   r8  , 0x80000
    mov   r9  , configfile
    int   0x60

    ; Write

    mov   rax , 58
    mov   rbx , 1
    mov   rcx , 0
    mov   rdx , [filesize]
    mov   r8  , 0x80000
    mov   r9  , configfile
    int   0x60

    mov   rax , 112
    mov   rbx , 3
    int   0x60

    ret

  nofound:

    add   rdx , 1
    cmp   rdx , r8
    jbe   searchnext

    ret


START:

    call  read_font_types

    mov   rax , 141
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    mov   rax , 141
    mov   rbx , 3
    int   0x60
    sub   ax , 9
    add   ax , 300
    mov   [vscroll_value],ax

    call  draw_window       ; At first, draw the window

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

    mov   rax , 0x2         ; Read the key and ignore
    int   0x60

    jmp   still

button_event:

    mov   rax , 0x11                      ; Get data
    int   0x60

    ; rax = status
    ; rbx = button id

    cmp   rbx , 300                       ;  Vertical scroll 300-319
    jb    no_vertical_scroll
    cmp   rbx , 319
    ja    no_vertical_scroll
    mov  [vscroll_value], rbx
    call  draw_vertical_scroll
    jmp   still
  no_vertical_scroll:

    cmp   rbx , 0x10000001                ; Terminate button
    jne   no_application_terminate_button
    mov   rax , 512
    int   0x60
  no_application_terminate_button:

    cmp   rbx , 0x106                     ; Menu
    jne   no_application_terminate_menu
    mov   rax , 0x200
    int   0x60
  no_application_terminate_menu:

    cmp   rbx , 20    ; set font size 09-12
    jne   nosetfont
    call  write_font_types
    mov   rcx , [vscroll_value]
    sub   rcx , 300
    add   rcx , 9
    mov   rax , 5 shl 32
    add   rcx , rax
    mov   rax , 141
    mov   rbx , 2
    int   0x60
    mov   rax , 120
    mov   rbx , 3
    int   0x60
    jmp   still
  nosetfont:

    cmp   rbx , 50
    jb    nofontchange
    cmp   rbx , 50+2
    ja    nofontchange
    sub   rbx , 50
    imul  rbx , 8
    mov   rax , [btpointer1+rbx]
    sub   rax , string_up
    add   rax , 6
    cmp   rax , 12
    jbe   raxfine
    mov   rax , 0
  raxfine:
    add   rax , string_up
    mov   [btpointer1+rbx],rax
    call  draw_buttons
    jmp   still
  nofontchange:


    jmp   still


draw_window:

    mov   rax , 0xC                       ; Beginning of window draw
    mov   rbx , 0x1
    int   0x60

    mov   rax , 0x0                       ; Draw window
    mov   rbx , 280 shl 32 + 0x116
    mov   rcx , 100 shl 32 + 165+13+42+13
    mov   rdx , 0xffffff
    mov   r8  , 0x1
    mov   r9  , window_label
    mov   r10 , menu_struct
    int   0x60

    call  draw_font_size

    ; Define button

    mov   rax , 8
    mov   rbx , 100 * 0x100000000 + 90
    mov   rcx , 194 * 0x100000000 + 20
    mov   rdx , 20
    mov   r8  , 0
    mov   r9  , button_text
    int   0x60

    call  draw_buttons

    ; Vertical scroll

    call  draw_vertical_scroll

    mov   rax , 0xc
    mov   rbx , 2
    int   0x60

    ret


draw_buttons:

    ; Define buttons

    mov   rax , 8
    mov   rbx , 173 * 0x100000000 + 71
    mov   rcx ,  84 * 0x100000000 + 13+2
    mov   rdx , 50
    mov   r8  , 0
    mov   r9  , button_text
    mov   rsi , btpointer1
    mov   r10 , 15 shl 32
  newbutton:
    mov   r9  , [rsi]
    int   0x60
    inc   rdx
    add   rsi , 8
    add   rcx , r10
    cmp   rsi , btpointer3
    jbe   newbutton

    ret



draw_font_size:

    mov   rax , [vscroll_value]
    sub   rax , 300
    add   rax , 9
    xor   rdx , rdx
    mov   rbx , 10
    div   rbx
    add   al , 48
    add   dl , 48
    mov   [text+18],al
    mov   [text+19],dl

    mov   rax , 13
    mov   rbx , 135 shl 32 + 12
    mov   rcx , 58 shl 32 + 14
    mov   rdx , 0xffffff
    int   0x60

    ; Text

    mov   rax , 4
    mov   rbx , text
    mov   rcx , 28
    mov   rdx , 60
    mov   rsi , 0x000000
    mov   r9  , 1
    int   0x60
    add   rbx , 40
    add   rdx , 13+13+2
    int   0x60
    add   rbx , 40
    add   rdx , 13+2
    int   0x60
    add   rbx , 40
    add   rdx , 13+2
    int   0x60
    add   rbx , 40
    add   rdx , 13+13+2
    int   0x60
    add   rbx , 40
    add   rdx , 13
    int   0x60
    add   rbx , 40
    add   rdx , 13
    int   0x60


    ret


draw_vertical_scroll:

    ; Vertical scroll

    mov   rax , 113
    mov   rbx , 2
    mov   rcx , 300
    mov   rdx , 4
    mov   r8  ,[vscroll_value]
    mov   r9  , 57
    mov   r10 , 173
    mov   r11 , 70
    int   0x60

    call  draw_font_size

    ret


; Data area

window_label:              ; Window label

    db    'SYSFONT',0

button_text:               ; Button text

    db    'APPLY',0

btpointer1:  dq  string_up
btpointer2:  dq  string_up
btpointer3:  dq  string_up

string_up:   db  'UPPER',0
string_cap:  db  ' Cap ',0
string_low:  db  'lower',0

filesize:    dq  0x0

string_icon_font:          db  'icon_font          '
string_main_menu_font:     db  'main_menu_font     '
string_file_browser_font:  db  'file_browser_font  '

configfile: db '/fd/1/config.mnt'

settype:  dq  0x0
getset:   dq  0x0

text:

    db    'Adjust font size (12px)                ',0
    db    'Icon font case:                        ',0
    db    'Main menu font case:                   ',0
    db    'File browser font case:                ',0
    db    'Define default fonts in Config.mnt     ',0
    db    'You may need to restart applications   ',0
    db    'to see the full effect.                ',0

vscroll_value:             ; Scroll value

    dq    305

menu_struct:               ; Menu Struct

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

image_end:

