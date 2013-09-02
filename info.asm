;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Info for Menuet64
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

    mov   rax , 0xA         ; Wait here for event
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

    mov   rax , 0xC                          ; Beginning of window draw
    mov   rbx , 0x1
    int   0x60

    mov   rax , 0x0                          ; Draw window
    mov   rbx , 0x000000D000000148           ; x start & size
    mov   rcx , 0x00000060000000BC+194       ; y start & size
    mov   rdx , 0x0000000000FFFFFF           ; type    & border color
    mov   r8  , 0x0000000000000001           ; draw flags
    mov   r9  , window_label                 ; 0 or label - asciiz
    mov   r10 , menu_struct                  ; 0 or pointer to menu struct
    int   0x60

    mov   rax , 0x4                          ; Display text
    mov   rbx , text
    mov   rcx , 32
    mov   rdx , 53
    mov   rsi , 0
    mov   r9  , 1
    mov   r8  , 26
  newline:
    int   0x60
    add   rbx , 46
    add   rdx , 12
    dec   r8
    jnz   newline

    mov   rax , 0xC                          ; End of window draw
    mov   rbx , 0x2
    int   0x60

    ret


; Data area

window_label:

    db    'M64',0     ; Window label

text:

    db    'MENUET 64 bit                                ',0
    db    '                                             ',0
    db    'Config.mnt - Setup and graphics acceleration ',0
    db    'Icon.mnt   - Desktop icons                   ',0
    db    'Menu.mnt   - Menu applications               ',0
    db    'Stack.txt  - Network info                    ',0
    db    '/Driver    - Driver examples                 ',0
    db    'E64.asm    - Example application             ',0
    db    '                                             ',0
    db    'Credits:                                     ',0
    db    '                                             ',0
    db    'Ville Turjanmaa   - Process management, Gui  ',0
    db    'Jarek Pelczar     - Quake, Doom, Dosbox ports',0
    db    'Mike Hibbett      - Networking               ',0
    db    'Madis Kalme       - Graphic functions        ',0
    db    'Tom Tollet        - Floppy driver            ',0
    db    'Akos Mogyorosi    - Image/audio decoders     ',0
    db    '                                             ',0
    db    'Thomas Mathys          - C4                  ',0
    db    'Dieter Marfurt         - 3dmaze              ',0
    db    'Ivan Poddubny          - MineSweeper         ',0
    db    'baze@stonline.sk       - Tube                ',0
    db    'trans397@yahoo.com     - Hunter              ',0
    db    'www.crown-s-soft.com   - Crownscr            ',0
    db    '                                             ',0
    db    'Contact : vmt@menuetos.net                   ',0


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

