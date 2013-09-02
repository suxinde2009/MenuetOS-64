;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   64 bit Menuet thread example
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
    dq    0x10000                 ; Rsp
    dq    0x00                    ; Prm
    dq    0x00                    ; Icon


START:

    mov   rax , 141         ; Enable system font
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

stackposition: dq 0x10000

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

    cmp   rbx , 10
    jne   no_thread_create

    add   [stackposition],dword 0x10000
    cmp   [stackposition],dword 0x100000
    jae   no_thread_create

    mov   rax , 51
    mov   rbx , 1
    mov   rcx , START
    mov   rdx , [stackposition]
    int   0x60

  no_thread_create:

    jmp   still


draw_window:

    mov   rax , 0xC                          ; Beginning of window draw
    mov   rbx , 0x1
    int   0x60

    mov   rbx , rsp
    shr   rbx , 16
    imul  rbx , 20
    add   rbx , 100
    shl   rbx , 32
    mov   rcx , rbx

    mov   rax , 0x0                          ; Draw window
    add   rbx , 300                          ; x start & size
    add   rcx , 150                          ; y start & size
    mov   rdx , 0x0000000000FFFFFF           ; type    & border color
    mov   r8  , 0x0000000000000001           ; draw flags
    mov   r9  , window_label                 ; 0 or label - asciiz
    mov   r10 , 0                            ; 0 or pointer to menu struct
    int   0x60

    mov   rax , 111
    mov   rbx , 1
    int   0x60
    mov   rcx , rax
    mov   rax , 9
    mov   rbx , 2
    mov   rdx , image_end
    mov   r8  , 2000
    int   0x60

    mov   rax , 'Parent  '
    cmp   [image_end+1040],byte 1
    jne   no_child
    mov   rax , 'Child   '
  no_child:
    mov   [text+14],rax

    mov   rax , 0x4                          ; Display text
    mov   rbx , text
    mov   rcx , 30
    mov   rdx , 50
    mov   rsi , 0x0
    mov   r9  , 0x1
    mov   r8  , 0x2
  newline:
    int   0x60
    add   rbx , 41
    add   rdx , 16
    dec   r8
    jnz   newline

    mov   rax , 8
    mov   rbx , 30 shl 32 + 100
    mov   rcx , 100 shl 32 + 20
    mov   rdx , 10
    mov   r8  , 0
    mov   r9  , button
    int   0x60

    mov   rax , 0xC                          ; End of window draw
    mov   rbx , 0x2
    int   0x60

    ret


; Data area

window_label:

    db    'THREAD.ASM',0  ; Window label

text:

    db    'Process type: Parent                    ',0
    db    'Closing parent closes all threads.      ',0


button: db 'CREATE THREAD',0

image_end:

