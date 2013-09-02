;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   64 bit Menuet textbox example
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

include "textbox.inc"

START:

    mov   rax , 141         ; Enable system font
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    call  draw_window       ; At first, draw the window

still:

    mov   rax , 10          ; Wait here for event
    int   0x60

    test  rax , 1           ; Window redraw
    jnz   window_event
    test  rax , 2           ; Keyboard press
    jnz   key_event
    test  rax , 4           ; Button press
    jnz   button_event

    jmp   still

window_event:

    call  draw_window
    jmp   still

key_event:

    mov   rax , 2          ; Read the key and ignore
    int   0x60

    jmp   still

button_event:

    mov   rax , 17
    int   0x60

    ; rax = status
    ; rbx = button id

    cmp   rbx , 11
    jne   no_textbox1
    mov   r14 , textbox1
    call  read_textbox
    jmp   still
  no_textbox1:

    cmp   rbx , 12
    jne   no_textbox2
    mov   r14 , textbox2
    call  read_textbox
    jmp   still
  no_textbox2:

    cmp   rbx , 0x10000001
    jne   no_application_terminate_button
    mov   rax , 512
    int   0x60
    jmp   still
  no_application_terminate_button:

    cmp   rbx , 0x106
    jne   no_application_terminate_menu
    mov   rax , 512
    int   0x60
  no_application_terminate_menu:

    jmp   still


draw_window:

    mov   rax , 12                           ; Beginning of window draw
    mov   rbx , 1
    int   0x60

    mov   rax , 0x0                          ; Draw window
    mov   rbx , 0x0000004000000120           ; x start & size
    mov   rcx , 0x00000040000000A0           ; y start & size
    mov   rdx , 0x0000000000FFFFFF           ; type    & border color
    mov   r8  , 0x0000000000000001           ; draw flags
    mov   r9  , window_label                 ; 0 or label - asciiz
    mov   r10 , menu_struct                  ; 0 or pointer to menu struct
    int   0x60

    mov   r14 , textbox1
    call  draw_textbox

    mov   r14 , textbox2
    call  draw_textbox

    mov   rax , 12                           ; End of window draw
    mov   rbx , 2
    int   0x60

    ret


; Data area

window_label:

    db    'TEXTBOX EXAMPLE',0

textbox1:

    dq    0         ; Type
    dq    20        ; X position
    dq    140       ; X size
    dq    50        ; Y position
    dq    11        ; Button ID
    dq    0         ; Current text length
    times 50 db 0   ; Text

textbox2:

    dq    0         ;
    dq    20        ;
    dq    140       ;
    dq    80        ;
    dq    12        ;
    dq    0         ;
    times 50 db 0   ;

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

