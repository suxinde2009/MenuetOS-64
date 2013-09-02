;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   64 bit Menuet example
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
    dq    0xffff0                 ; Rsp
    dq    0x00                    ; Prm
    dq    0x00                    ; Icon


START:

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

    jmp   still


draw_window:

    mov   rax , 12                           ; Beginning of window draw
    mov   rbx , 1
    int   0x60

    mov   rax , 0                            ; Draw window
    mov   rbx , 256 shl 32 + 256             ; X start & size
    mov   rcx , 128 shl 32 + 192             ; Y start & size
    mov   rdx , 0x0000000000FFFFFF           ; Type    & border color
    mov   r8  , 0x0000000000000001           ; Flags (set as 1)
    mov   r9  , window_label                 ; 0 or label - asciiz
    mov   r10 , menu_struct                  ; 0 or pointer to menu struct
    int   0x60

    mov   rax , 4                            ; Display text
    mov   rbx , text                         ; Pointer to text
    mov   rcx , 32                           ; X position
    mov   rdx , 64                           ; Y position
    mov   rsi , 0x000000                     ; Color
    mov   r9  , 1                            ; Font
  newline:
    int   0x60
    add   rdx , 16
    add   rbx , 31
    cmp   [rbx],byte ' '
    jae   newline

    mov   rax , 12                           ; End of window draw
    mov   rbx , 2
    int   0x60

    ret


; Data area

window_label:

    db    'EXAMPLE',0     ; Window label

text:

    db    'HELLO WORLD FROM 64 BIT MENUET',0
    db    'Second line                   ',0
    db    'Third line                    ',0
    db    0

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

