;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Real-Time data fetch from com1 modem
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

    mov   rax , 141         ; Enable system font
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    call  Reserve_IRQ_Ports

    call  draw_window

still:

    mov   rax , 10          ; Wait here for event
    int   0x60

    test  rax , 0x1         ; Window redraw
    jnz   window_event
    test  rax , 0x2         ; Keyboard press
    jnz   key_event
    test  rax , 0x4         ; Button press
    jnz   button_event

    ; IRQ 4 event

    mov   rbx , 10000b shl 32
    test  rax , rbx
    jnz   IRQ4_event

    jmp   still

window_event:

    call  draw_window
    jmp   still

key_event:

    mov   rax , 0x2        ; Read the key and ignore
    int   0x60

    test  rbx , 1
    jnz   no_key_down

    mov   rax , 'Enter   '
    cmp   rcx , rax
    jne   no_enter
    mov   cl , 13
  no_enter:

    mov   al , cl
    mov   dx , 0x3f8
    out   dx , al

  no_key_down:

    jmp   still

button_event:

    mov   rax , 0x11
    int   0x60

    ; rax = status
    ; rbx = button id

    cmp   rbx , 0x10000001                   ; Terminte button
    je    application_terminate
    cmp   rbx , 0x106                        ; Menu quit
    je    application_terminate

    jmp   still

application_terminate:

    mov   rax , 512
    int   0x60

IRQ4_event:

    ; Read data

    mov   rax , 42
    mov   rbx , 4
    int   0x60

    cmp   rax , 1
    je    read_done

    ; Set to text area

    mov   rax , [xpos]
    inc   rax
    and   rax , 31
    mov  [xpos], rax

    mov  [text+38*2+rax], bl

    jmp   IRQ4_event

  read_done:

    call  display_text

    jmp   still


Reserve_IRQ_Ports:

    ; Reserve IRQ 4

    mov   rax , 45
    mov   rbx , 0
    mov   rcx , 4
    int   0x60

    ; Reserve ports 0x3f8-0x3ff

    mov   rcx , 0x3f8
   resport:
    mov   rax , 46
    mov   rbx , 0
    int   0x60
    inc   rcx
    cmp   rcx , 0x3ff
    jbe   resport

    ; Ports to read at IRQ 4

    mov   rax , 44
    mov   rbx , 4
    mov   rcx , irq_table
    int   0x60

    ; Program COM 1 port

    call  program_com1

    ; Enable event for IRQ 4

    mov   rax , 40
    mov   rbx , 10000b shl 32 + 111b
    int   0x60

    ret


irq_table:

    dd  0x3f8 , 0x1     ; Read from port 0x3f0 : read byte ( 0x1 )
    dd  0x000 , 0x0     ; End marker


baudrate_9600    equ 12
baudrate_57600   equ  2
baudrate_115200  equ  1

program_com1:         ; Set Baudrate

    mov   dx , 0x3f8+3
    mov   al , 0x80
    out   dx , al

    mov   dx , 0x3f8+1
    mov   al , 0x00
    out   dx , al

    mov   dx , 0x3f8+0
    mov   al , baudrate_9600
    out   dx , al

    mov   dx , 0x3f8+3
    mov   al , 0x3
    out   dx , al

    mov   dx , 0x3f8+4
    mov   al , 0xb
    out   dx , al

    mov   dx , 0x3f8+1
    mov   al , 0x1
    out   dx , al

    ret


draw_window:

    mov   rax , 0xC                          ; Beginning of window draw
    mov   rbx , 0x1
    int   0x60

    mov   rax , 0x0                          ; Draw window
    mov   rbx , 0x6000000000 + 6*46 + 10
    mov   rcx , 0x5000000000 + 12*10 + 50
    mov   rdx , 0xffffff
    mov   r8  , 0x0
    mov   r9  , window_label
    mov   r10 , 0
    int   0x60

    call  display_text

    mov   rax , 0xC                          ; End of window draw
    mov   rbx , 0x2
    int   0x60

    ret


display_text:

    ; Clear area

    mov   rax , 13
    mov   rbx , 20*0x100000000 + 40*6
    mov   rcx , 98*0x100000000 + 10
    mov   rdx , 0xffffff
    int   0x60

    ; Text

    mov   rax , 4
    mov   rbx , text
    mov   rcx , 20
    mov   rdx , 50
    mov   r9  , 1
    mov   rsi , 0x000000
  newtext:
    int   0x60
    add   rdx , 24
    add   rbx , 38
    cmp   rbx , text+38*3
    jb    newtext

    ret


; Data area

window_label:

    db    'RTDATA.ASM',0

xpos:

    dq    0x0

text:

    db    'Real-Time data fetch from COM1 modem.',0
    db    'Type a few letters. Echo from COM1:  ',0
    db    '                                     ',0


image_end:

