;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Exit for Menuet64
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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

    mov   rax , 141
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    call  draw_window

still:

    mov   rax , 10
    int   0x60

    test  rax , 0x1         ; Window redraw
    jnz   window_event
    test  rax , 0x2         ; Keyboard press
    jnz   keyboard_event
    test  rax , 0x4         ; Button press
    jnz   button_event

    jmp   still

window_event:

    call  draw_window
    jmp   still

keyboard_event:

    mov   rax , 0x2
    int   0x60
    jmp   still

button_event:

    mov   rax , 17
    int   0x60

    ; rax = status
    ; rbx = button id

    cmp   rbx , 0x1
    jne   no_reboot
    mov   rax , 500   ; System
    mov   ebx , 1     ; Reboot
    int   0x60
  no_reboot:

    ; Any other -> close window

    mov   rax , 512
    int   0x60


draw_window:     ; draw window

    mov   rax , 0xC
    mov   rbx , 0x1
    int   0x60

    mov   rax , 26
    mov   rbx , 3
    mov   rcx , image_end
    mov   rdx , 30*8
    int   0x60

    ; Middle of screen

    mov   rbx , [image_end+0x20]
    shr   rbx , 1
    sub   rbx , 0xc2/2
    shl   rbx , 32
    add   rbx , 0xc3

    mov   rax , 0x0                          ; draw window
    mov   rcx , 0x000000800000005E           ; y start & size
    mov   rdx , 0xFFFFFF                     ; type    & border color
    mov   r8  , 0x1                          ; draw flags
    mov   r9  , window_label                 ; 0 or label - asciiz
    mov   r10 , 0x0                          ; pointer to menu struct or 0
    int   0x60

    mov   rax , 8                           ; button
    mov   rbx , 25 * 0x100000000 + 70       ; x start & size
    mov   rcx , 53 * 0x100000000 + 18       ; y start & size
    mov   rdx , 0x1                         ; button id
    mov   r8  , 0x0                         ; ignored
    mov   r9  , button_label_1              ; button_text
    int   0x60

    mov   rax , 8                           ; button
    mov   rbx , 100 * 0x100000000 + 70      ; x start & size
    mov   rcx , 053 * 0x100000000 + 18      ; y start & size
    mov   rdx , 0x2                         ; button id
    mov   r8  , 0                           ; ignored
    mov   r9  , button_label_2              ; button_text
    int   0x60

    mov   rax , 0xC
    mov   rbx , 0x2
    int   0x60

    ret   ;

; Data area

button_label_1:

    db 'YES',0

button_label_2:

    db 'NO',0

window_label:

    db    'EXIT MENUET ?',0

image_end:

