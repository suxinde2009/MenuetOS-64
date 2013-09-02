;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Window transparency for Menuet
;
;   Compile with FASM 1.60 or above
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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

    mov   rax , 141
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    ; Get current update interval

    mov   rax , 125
    mov   rbx , 1
    int   0x60
    xor   rdx , rdx
    mov   rbx , 10
    div   rbx
    add   rax , 300
    dec   rax
    mov   [hscroll_value],rax

    ; Get current opacity

    mov   rax , 125
    mov   rbx , 5
    int   0x60
    add   rax , 400
    mov   [hscroll_value2],rax

    ; Get current window type

    mov   rax , 125
    mov   rbx , 7
    int   0x60
    mov   [window_move_type],rax

    ; Get current update interval

    mov   rax , 125
    mov   rbx , 9
    int   0x60
    sub   rax , 5
    cmp   rax , 25
    jbe   intervalfine
    mov   rax , 25
  intervalfine:
    add   rax , 500
    mov   [hscroll_value3],rax

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

    cmp   rbx , 300                       ;  Horizontal scroll 300-319
    jb    no_horizontal_scroll
    cmp   rbx , 319
    ja    no_horizontal_scroll
    mov  [hscroll_value], rbx
    call  draw_horizontal_scroll
    mov   rax , 125
    mov   rbx , 2
    mov   rcx , [hscroll_value]
    sub   rcx , 300
    imul  rcx , 10
    add   rcx , 10
    int   0x60
    jmp   still
  no_horizontal_scroll:

    cmp   rbx , 400                       ;  Horizontal scroll 400-402
    jb    no_horizontal_scroll2
    cmp   rbx , 402
    ja    no_horizontal_scroll2
    mov  [hscroll_value2], rbx
    call  draw_horizontal_scroll2
    mov   rax , 125
    mov   rbx , 6
    mov   rcx , [hscroll_value2]
    sub   rcx , 400
    int   0x60
    jmp   still
  no_horizontal_scroll2:

    cmp   rbx , 500                       ;  Horizontal scroll 500-524
    jb    no_horizontal_scroll3
    cmp   rbx , 525
    ja    no_horizontal_scroll3
    mov   [hscroll_value3], rbx
    call  draw_window_interval
    mov   rax , 125
    mov   rbx , 10
    mov   rcx , [hscroll_value3]
    sub   rcx , 500-5
    int   0x60
    jmp   still
  no_horizontal_scroll3:

    cmp   rbx , 50
    jne   no_windowmove
    inc   dword [window_move_type]
    and   dword [window_move_type],dword 1
    mov   rax , 125
    mov   rbx , 8
    mov   rcx , [window_move_type]
    int   0x60
    ; Get current window type
    mov   rax , 125
    mov   rbx , 7
    int   0x60
    mov   [window_move_type],rax
    call  draw_window_move
    jmp   still
  no_windowmove:

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

    jmp   still


draw_window:

    mov   rax , 0xC                       ; Beginning of window draw
    mov   rbx , 0x1
    int   0x60

    ; Window position

    mov   rax , 0x0                       ; Draw window
    mov   rbx , 0x00000090000001AB-10
    mov   rcx , 0x0000004800000117+90
    mov   rdx , 0xffffff
    mov   r8  , 0x1
    mov   r9  , window_label
    mov   r10 , menu_struct
    int   0x60

    mov   rax , 125
    mov   rbx , 3
    int   0x60

    add   rax , 48
    mov   [text+20],al

    mov   rax , 0x4                          ; Display text
    mov   rbx , text
    mov   rcx , 0x20
    mov   rdx , 0x40
    mov   rsi , 0x0
    mov   r9  , 0x1

  newline:

    cmp   [rbx],byte '_'
    je    lineskip

    int   0x60

    add   rbx , 60
  lineskip:
    add   rbx , 1
    add   rdx , 14
    cmp   [rbx],byte 0
    jne   newline

    ; Scroll

    call  draw_horizontal_scroll

    call  draw_horizontal_scroll2

    call  draw_window_move

    call  draw_window_interval

    mov   rax , 0xc
    mov   rbx , 2
    int   0x60

    ret


draw_horizontal_scroll:

    mov   rax , 113
    mov   rbx , 2
    mov   rcx , 300
    mov   rdx , 10
    mov   r8  ,[hscroll_value]
    mov   r9  , 193
    mov   r10 , 32
    mov   r11 , 230
    int   0x60

    ret

draw_horizontal_scroll2:

    mov   rax , 113
    mov   rbx , 2
    mov   rcx , 400
    mov   rdx , 3
    mov   r8  ,[hscroll_value2]
    mov   r9  , 235
    mov   r10 , 32
    mov   r11 , 230
    int   0x60

    ret


draw_window_move:

    mov   rax , 8
    mov   rbx , 32 shl 32 + 230
    mov   rcx , (235+31) shl 32 + 18
    mov   rdx , 50
    mov   r8  , 0
    mov   r9  , button_text_off
    cmp   [window_move_type],byte 1
    jne   nowmt1
    mov   r9  , button_text_on
  nowmt1:
    int   0x60

    ret


draw_window_interval:

    mov   rax , 113
    mov   rbx , 2
    mov   rcx , 500
    mov   rdx , 26
    mov   r8  , [hscroll_value3]
    mov   r9  , 235+84
    mov   r10 , 32
    mov   r11 , 230
    int   0x60

    ret


; Data area

window_label:              ; Window label

    db    'TRANSPARENCY',0

text:

    db  'Transparency state: 0                                       ',0
    db  '_0 - Disabled                                                ',0
    db  '1 - Enabled for window title and frames                     ',0
    db  '2 - Enabled for window title, menu and frames               ',0
    db  '_Modify transparency state in Config.mnt and reboot.         ',0
    db  '_Set transparency update interval (10-100ms)                 ',0
    db  '__Set transparency opacity (75:25,50:50,25:75)                ',0
    db  '_____Set window content move interval (5-30)                     ',0
    db  0

hscroll_value:             ; Scroll value

    dq    300

hscroll_value2:            ; Scroll value 2

    dq    400

hscroll_value3:

    dq    500

window_move_type:

    dq    0x0

button_text_on:  db 'Display window content when moving',0
button_text_off: db 'Display window frames when moving',0

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

