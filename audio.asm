;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   64 bit Menuet audio example
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
    dq    0x0ffff0                ; Rsp
    dq    0x00                    ; Prm
    dq    0x00                    ; Icon


block equ 0x0E0000


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


playaudio:

    call  check_output_device

    cmp   [cardhz],dword 0
    je    playsongret

    ; Precalculate both buffers

    mov   rdx , 0
    call  calculate_block

    mov   rdx , 1
    call  calculate_block

    ; Play command

    mov   rax , 117
    mov   rbx , 3
    int   0x60

    ; Wait for first buffer to finish

  waitmore1:
    call  delay
    call  getindex
    cmp   rbx , 0
    je    waitmore1

    ; Recalculate first buffer

    mov   rdx , 0
    call  calculate_block

    ; Wait for second buffer to finish

  waitmore2:
    call  delay
    call  getindex
    cmp   rbx , 1
    je    waitmore2

    ; Recalculate second buffer

    mov   rdx , 1
    call  calculate_block

    mov   rax , 11
    int   0x60
    test  rax , 4
    jnz   stop

    inc   byte [tune]
    and   [tune], byte 1

    jmp   waitmore1

  stop:

    ; Stop playing at button press

    mov   rax , 117
    mov   rbx , 5
    int   0x60

    ; Free device

    mov   rax , 117
    mov   rbx , 255
    int   0x60

  playsongret:

    ret


check_output_device:

    ; Device available

    mov   rax , 117
    mov   rbx , 1
    int   0x60
    cmp   rax , 0
    jne   device_not_available

    ; Audio format

    mov   rax , 117
    mov   rbx , 7
    mov   rcx , 0
    int   0x60

    mov   rdx , 0xffffffffff shl 24
    mov   rcx , rbx
    and   rcx , rdx
    mov   rdx , 0x4000010210 shl 24
    cmp   rcx , rdx ; buffer 16384 : sign extended lsb : 2 channel : 16bit/ch
    jne   not_supported_output

    mov  [cardhz],bx
    ret

  not_supported_output:
  device_not_available:

    mov  rax , 4
    mov  rbx , unsupported
    mov  rcx , 30
    mov  rdx , 55
    mov  r9  , 1
    mov  rsi , 0x000000
    int  0x60

    mov  [cardhz],dword 0
    ret



calculate_block:

    push  rdx

    mov   rdi , block
    mov   rcx , 0
    mov   ebx , 0

    mov   rdx , [tune]
    inc   rdx
    imul  rdx , 0x01000100

  newbyte:

    mov  [rdi], ebx

    add   rbx , rdx

    add   rdi , 4
    inc   rcx
    cmp   rcx , 4095
    jbe   newbyte

    ; Give block

    mov   rax , 117
    mov   rbx , 2
    mov   rcx , block
    pop   rdx
    int   0x60

    ret


delay:

    mov   rax , 11
    int   0x60
    cmp   rax , 1
    jne   delayl1
    call  draw_window
  delayl1:

    mov   rax , 5
    mov   rbx , 2
    int   0x60

    ret


getindex:

    mov   rax , 117
    mov   rbx , 4
    int   0x60

    ret


button_event:

    mov   rax , 0x11
    int   0x60

    ; rax = status
    ; rbx = button id

    cmp   rbx , 1            ; Play audio
    jne   no_play
    call  playaudio
    jmp   still
  no_play:

    cmp   rbx , 0x10000001   ; Close button
    je    terminate_program
    cmp   rbx , 0x104        ; Menu selection
    je    terminate_program

    jmp   still


terminate_program:

    mov   rax , 512
    int   0x60


draw_window:

    mov   rax , 0xC                          ; Beginning of window draw
    mov   rbx , 0x1
    int   0x60

    mov   rax , 0x0                          ; Draw window
    mov   rbx , 0x0000010000000000 + 193     ; x start & size
    mov   rcx , 0x0000008000000000 + 120     ; y start & size
    mov   rdx , 0x0000000000FFFFFF           ; type    & border color
    mov   r8  , 0x0000000000000001           ; draw flags
    mov   r9  , window_label                 ; 0 or label - asciiz
    mov   r10 , menu_struct                  ; 0 or pointer to menu struct
    int   0x60

    mov   rax , 8
    mov   rbx , 20 * 0x100000000 + 70
    mov   rcx , 80 * 0x100000000 + 20
    mov   rdx , 1
    mov   r8  , 0
    mov   r9  , button1
    int   0x60

    mov   rax , 8
    mov   rbx , 100* 0x100000000 + 70
    mov   rcx , 80 * 0x100000000 + 20
    mov   rdx , 2
    mov   r8  , 0
    mov   r9  , button2
    int   0x60

    mov   rax , 0xC
    mov   rbx , 0x2
    int   0x60

    ret


; Data area

window_label:

    db    'AUDIO EXAMPLE',0

button1:

    db    'PLAY',0

button2:

    db    'STOP',0

cardhz:

    dq    0x0

tune:

    dq    0x0

unsupported:

    db    'Unable to detect audio.',0

menu_struct:               ; Menu Struct

    dq   0                 ; Version

    dq   0x100             ; Start value of ID to return ( ID + Line )

                           ; Returned when menu closes and
                           ; user made no selections.

    db   0,'FILE',0        ; ID = 0x100 + 1
    db   1,'Open..',0
    db   1,'-',0
    db   1,'Quit',0        ; ID = 0x100 + 2

    db   255               ; End of Menu Struct

image_end:


