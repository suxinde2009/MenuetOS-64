;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Mixer for Menuet64
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

    mov   rax , 141
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    call  read_mixer_values

    call  draw_window       ; At first, draw the window

still:

    mov   rax , 23          ; Wait here for event
    mov   rbx , 2
    int   0x60

    test  rax , 0x1         ; Window redraw
    jnz   window_event
    test  rax , 0x2         ; Keyboard press
    jnz   key_event
    test  rax , 0x4         ; Button press
    jnz   button_event

    call  read_mixer_values
    call  draw_scrolls

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

    cmp   rbx , 1000
    jb    noscroll
    mov   rax , rbx
    mov   rcx , 1000
    xor   rdx , rdx
    div   rcx
    dec   rax
    imul  rax , 8
    add   rax , sc
    mov  [rax+4*8],rbx
    call  draw_scrolls
    call  set_values
    jmp   still
  noscroll:

    jmp   still


draw_window:

    mov   rax , 0xC                          ; Beginning of window draw
    mov   rbx , 0x1
    int   0x60

    mov   rax , 0x0                          ; Draw window
    mov   rbx , 0x0000010A00000000+240       ; x start & size
    mov   rcx , 0x0000008000000000+202       ; y start & size
    mov   rdx , 0x0000000000FFFFFF           ; type    & border color
    mov   r8  , 0x0000000000000001           ; draw flags
    mov   r9  , window_label                 ; 0 or label - asciiz
    mov   r10 , menu_struct                  ; 0 or pointer to menu struct
    int   0x60

    mov   rax , 0x4                          ; Display text
    mov   rbx , text
    mov   rcx , 16
    mov   rdx , 180
    mov   rsi , 0x0
    mov   r9  , 0x1
    int   0x60
    mov   rbx , text2
    add   rcx , 3
    int   0x60

    mov   rdi , sc
    mov   rax , 0
    mov   rcx , 4
    cld
    rep   stosq

    call  draw_scrolls

    mov   rax , 0xC                          ; End of window draw
    mov   rbx , 0x2
    int   0x60

    ret


draw_scrolls:

    mov   r15 , 0

  newmixer:

    mov   rax , 113
    mov   rbx , 1
    mov   rcx , r15
    imul  rcx , 1000
    add   rcx , 1000
    mov   rdx , 32
    mov   r8  , r15
    imul  r8  , 8
    add   r8  , sc
    mov   r14 , [r8+4*8]
    cmp   r14 , [r8]
    je    no_scroll_change
    mov   [r8], r14
    mov   r8  , r14
    mov   r9  , r15
    imul  r9  , 54
    add   r9  , 33
    mov   r10 , 51
    mov   r11 , 117
    int   0x60
  no_scroll_change:

    inc   r15
    cmp   r15 , 3
    jbe   newmixer

    ret


set_values:

    mov   r15 , 0

  newsetvalue:

    mov   rax , 117
    mov   rbx , 6
    mov   rcx , r15
    mov   r9  , r15
    imul  r9  , 8
    mov   r9  , [sc+r9]

    mov   r8  , r15
    inc   r8
    imul  r8  , 1000

    sub   r9  , r8     ; 31-0 -> 0-255,0-255
    imul  r9  , 0x08
    mov   rdx , 0xff
    and   r9  , 0xff
    sub   rdx , r9
    imul  rdx , 0x0101
    int   0x60

    inc   r15
    cmp   r15 , 3
    jbe   newsetvalue

    ret


read_mixer_values:

    mov   r15 , 0

  readnext:

    mov   rax , 117
    mov   rbx , 6
    mov   rcx , 0x1000
    add   rcx , r15
    int   0x60

    cmp   rax , 0
    jne   no_set_values

    mov   rax , rbx  ; 0-255,0-255 -> 31-0
    mov   rbx , 0xff
    and   rax , 0xff
    sub   rbx , rax
    shr   rbx , 3

    mov   rax , r15
    imul  rax , 1000
    add   rax , 1000
    add   rbx , rax

    mov   rax , r15
    imul  rax , 8
    add   rax , sc+4*8

    mov   [rax],rbx

    inc   r15
    cmp   r15 , 3
    jbe   readnext

  no_set_values:

    ret



; Data area

window_label:

    db    'MIXER',0

sc:

    dq    0x0    ; Values
    dq    0x0
    dq    0x0
    dq    0x0
    dq    1023   ; Change
    dq    2023
    dq    3023
    dq    4023

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

text:   db    '  MAIN      CD      WAVE          ',0
text2:  db    '                             MIC  ',0

image_end:

