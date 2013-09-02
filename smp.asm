;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   SMP for Menuet64
;
;   Compile with FASM 1.60 or above
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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

    call  draw_window       ; At first, draw the window

still:

    mov   rax , 23          ; Wait here for event
    mov   rbx , 100
    int   0x60

    test  rax , 0x1         ; Window redraw
    jnz   window_event
    test  rax , 0x2         ; Keyboard press
    jnz   key_event
    test  rax , 0x4         ; Button press
    jnz   button_event

    mov   rax , 140
    mov   rbx , 1
    int   0x60
    cmp   rbx , [smp_state]
    jne   window_event

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

    cmp   rbx , 11
    jne   noprocessliststart
    mov   rax , 256
    mov   rbx , string_cad
    mov   rcx , 0
    int   0x60
    jmp   still
  noprocessliststart:

    jmp   still


draw_window:

    mov   rax , 0xC                          ; Beginning of window draw
    mov   rbx , 0x1
    int   0x60

    ; SMP status

    mov   rax , 140
    mov   rbx , 1
    int   0x60
    mov   [smp_state],rbx

    mov   rax , rbx
    xor   rdx , rdx
    mov   rbx , 10
    div   rbx
    add   al  , 48
    add   dl  , 48
    mov   [text+11],al
    mov   [text+12],dl

    ; CPUs available

    mov   rax , 140
    mov   rbx , 2
    int   0x60
    mov   rax , rbx
    xor   rdx , rdx
    mov   rbx , 10
    div   rbx
    add   al  , 48
    add   dl  , 48
    mov   [text2+18],al
    mov   [text2+19],dl

    ;

    mov   rax , 0x0                          ; Draw window
    mov   rbx , 0x0000006000000110           ; x start & size
    mov   rcx , 0x000000600000010C           ; y start & size
    mov   rdx , 0x0000000000FFFFFF           ; type    & border color
    mov   r8  , 0x0000000000000001           ; draw flags
    mov   r9  , window_label                 ; 0 or label - asciiz
    mov   r10 , menu_struct                  ; 0 or pointer to menu struct
    int   0x60

    mov   rax , 141
    mov   rbx , 3
    int   0x60
    and   rax , 0xff
    mov   r14 , rax
    mov   r15 , rax
    sub   r14 , 9
    shr   r14 , 1
    add   r14 , 9
    add   r14 , 3

    sub   r15 , 9
    shr   r15 , 1
    imul  r15 , 6
    mov   r12 , 0x40
    sub   r12 , r15

    mov   rax , 0x4                          ; Display text
    mov   rbx , text
    mov   rcx , 0x20
    mov   rdx , r12
    mov   rsi , 0x0
    mov   r9  , 0x1
  newline:
    int   0x60
    add   rbx , 0x1F+30
    add   rdx , r14
    cmp   [rbx],byte 'x'
    jne   newline

    mov   rax , 8
    mov   rbx , 87 shl 32 + 100
    mov   rcx , 225 shl 32 + 20
    mov   rdx , 11
    mov   r8  , 0
    mov   r9  , string_button
    int   0x60

    mov   rax , 0xC                          ; End of window draw
    mov   rbx , 0x2
    int   0x60

    ret


; Data area

window_label:

    db    'SMP',0     ; Window label

text:

    db    'SMP state: xx                                               ',0
    db    '                                                            ',0
    db    '00 - Not initialized                                        ',0
    db    '01 - Initialized successfully                               ',0
    db    '10 - BSP APIC ID fail                                       ',0
    db    '11 - No Virtual Wire mode available                         ',0
    db    '12 - No MP/PCMP table available                             ',0
    db    '13 - MP table APIC ID/EN fail                               ',0
    db    '14 - No response from second CPU                            ',0
    db    '15 - Disabled with Ctrl-Alt-PageUp                          ',0
    db    '                                                            ',0
text2:
    db    'CPU(s) available: xx                                        ',0
    db    'x'

string_cad:

    db    '/FD/1/CAD',0

string_button:

    db    'PROCESS LIST',0

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

smp_state: dq 0x0

image_end:

