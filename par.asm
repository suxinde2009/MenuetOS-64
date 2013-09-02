;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Parameters for Menuet64
;
;   Compile with FASM 1.60 or above
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use64

         org    0x0

         db     'MENUET64'              ; 8 byte id
         dq     0x01                    ; header version
         dq     START                   ; start of code
         dq     IMAGE_END               ; size of image
         dq     0x100000                ; memory for app
         dq     0xffff0                 ; esp
         dq     0x0 , 0x0               ; I_Param , I_Icon

taby     equ  23
buty     equ  40
linesize equ  05

START:

    mov   rax , 141
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    call  draw_window

    call  display_general_data

    ; Window stack numbers

    mov   rdi , wstacknum
    mov   rcx , 1
  wsl1:
    push  rdi rcx
    mov   rcx , 34
    mov   rax , 32
    cld
    rep   stosb
    mov   rax , 0
    stosb
    pop   rcx rdi
    mov   rax , rcx
    mov   rbx , 10
    xor   rdx , rdx
    div   rbx
    add   al , 48
    add   dl , 48
    mov   [rdi+30],al
    mov   [rdi+31],dl
    add   rdi , 35
    inc   rcx
    cmp   rcx , 90
    jb    wsl1

still:

    mov   rax , 23
    mov   rbx , 100
    int   0x60

    test  rax , 1b    ; Window redraw
    jnz   red
    test  rax , 10b   ; Key press
    jnz   key
    test  rax , 100b  ; Button press
    jnz   button

    call  display_general_numbers

    jmp   still

red:

    call  draw_window
    call  display_general_data
    jmp   still

key:

    mov   rax , 2
    int   0x60
    jmp   still

redraw:

    call  display_general_data
    jmp   still

button:

    mov   rax , 17
    int   0x60

    ; rax = status
    ; rbx = button id

    cmp   rbx , 0x10000001
    jne   no_application_terminate
    mov   rax , 512
    int   0x60
  no_application_terminate:

    cmp   rbx , 1000
    jb    noscroll
    cmp   rbx , 1100
    ja    noscroll
    mov  [scroll_value],rbx
    push  rbx
    call  draw_scroll
    pop   rbx
    sub   rbx , 1000
    mov  [display_from],rbx
    call  display_general_data
    jmp   still
  noscroll:

    cmp   rbx , 800
    jne   noupdate
    call  display_general_data
    jmp   still
  noupdate:

    mov   rcx , rbx
    mov  [dip],rcx

    call  display_general_data
    jmp   still


draw_scroll:

    mov   rax , 113
    mov   rbx , 1
    mov   rcx , 1000
    mov   rdx , 45
    mov   r8  ,[scroll_value]
    mov   r9  , 355
    mov   r10 , 45+taby
    mov   r11 , 236+linesize*10
    int   0x60

    ret


fontsize: dq 0x0


draw_window:

    mov   rax , 12
    mov   rbx , 1
    int   0x60

    mov   rax , 141
    mov   rbx , 3
    int   0x60
    and   rax , 0xff
    mov   [fontsize],rax
    mov   rbx , rax
    inc   rbx
    mov   rax , 270 ; 55-38-2
    xor   rdx , rdx
    div   rbx
    mov   [lines],rax

    mov   rax , 0
    mov   rbx , 100 shl 32 + 385
    mov   rcx , 90  shl 32 + 325 + linesize*10
    mov   rdx , 0   shl 32 + 0xffffff
    mov   r8 , 1b
    mov   r9 , window_label
    mov   r10 , 0
    int   0x60

    call  draw_scroll

    ; Draw area frames

    mov   rax , 38
    mov   rbx , 15
    mov   rcx , 44 + taby
    mov   rdx , 15
    mov   r8  , 282 + taby + linesize*10
    mov   r9  , 0x000000
    int   0x60

    mov   rax , 38
    mov   rbx , 15
    mov   rcx , 44 + taby
    mov   rdx , 367
    mov   r8  , 44 + taby
    mov   r9  , 0x000000
    int   0x60

    mov   rax , 38
    mov   rbx , 15
    mov   rcx , 282 + taby + linesize*10
    mov   rdx , 367
    mov   r8  , 282 + taby + linesize*10
    mov   r9 , 0x000000
    int   0x60

    mov   rax , 8
    mov   rbx , 15 shl 32 + 60
    mov   rcx , buty shl 32 + 18
    mov   rdx , 0x1
    mov   r8 , 0x446688
    mov   r9 , button_text_1
    int   0x60

    mov   rax , 8
    mov   rbx , 75 shl 32 + 60
    mov   rcx , buty shl 32 + 18
    mov   rdx , 0x2
    mov   r8 , 0x446688
    mov   r9 , button_text_2
    int   0x60

    mov   rax , 8
    mov   rbx , 135 shl 32 + 60
    mov   rcx , buty shl 32 + 18
    mov   rdx , 0x3
    mov   r8 , 0x446688
    mov   r9 , button_text_3
    int   0x60

    mov   rax , 8
    mov   rbx , 195 shl 32 + 60
    mov   rcx , buty shl 32 + 18
    mov   rdx , 0x4
    mov   r8 , 0x446688
    mov   r9 , button_text_4
    int   0x60

    mov   rax , 12
    mov   rbx , 2
    int   0x60

    ret


display_info:

    mov   [disover],byte 0
    mov   rax , [dip]
    sub   rax , 1
    imul  rax , 8
    add   rax , text_pointers
    mov   rax , [rax]
    mov   rcx , [display_from]
    inc   rcx
  diso0:
    cmp   [rax],byte 'x'
    je    diso
    add   rax , 35
    loop  diso0
    jmp   diso2
  diso:
    mov   [disover],byte 1
  diso2:

    mov   rax , [dip]
    sub   rax , 1
    imul  rax , 8
    add   rax , text_pointers
    mov   rbx , [rax]
    mov   rax , [display_from]
    imul  rax , 35
    add   rbx , rax
    mov   rax , 4
    mov   rcx , 20
    mov   rdx , 50+taby
    mov   r9  , 1
    mov   r15 , 0

  newline_3:

    push  rax
    push  rbx
    push  rcx
    push  rdx
    mov   rax , 13
    mov   rbx , rcx
    shl   rbx , 32
    add   rbx , 208
    mov   rcx , rdx
    dec   rcx
    shl   rcx , 32
    add   rcx , 12
    mov   rdx , 0xffffff
    int   0x60
    pop   rdx
    pop   rcx
    pop   rbx
    pop   rax

    cmp   [rbx],byte 'x'
    jne   nodover
    mov   [disover],byte 1
  nodover:

    cmp   [disover],byte 1
    je    nodisp
    int   0x60
  nodisp:

    add   rbx , 35
    add   rdx , [fontsize]
    add   rdx , 1
    add   r15 , 1
    cmp   r15 , [lines] ; 22+linesize
    jbe   newline_3

    ret


display_general_data:

    mov   rsi , 0x000000
    call  display_info

display_general_numbers:

    mov   rax , 26                ; return system info
    mov   rbx , dip
    mov   rbx ,[rbx]              ; 1 general - 2 window - 3 boot data
    mov   rcx , system_general_1  ; - where to return
    mov   rdx , 1024              ; - bytes to return
    int   0x60

    mov   r12 , 230
    mov   r13 , 1
    mov   r11 , system_general_1
    mov   r15 , 0x00
    call  display_system_info

    ret


display_system_info:

    mov   r14 , 23+linesize
    imul  r14 , 8
    add   r14 , r11
    mov   rax , ypos
    mov   rdx , 40+taby
    mov  [rax], rdx

    mov   r10 , 0

  dsil1:

    mov   rbx , r12
    mov   rcx , [ypos]
    add   rcx , 9
    shl   rbx , 32
    shl   rcx , 32
    add   rbx , 110
    add   rcx , 12
    mov   rdx , 0xffffff
    mov   rax , 13
    int   0x60

    cmp   r15 , 0xffffff
    je    noclear
    mov   rax , r11
    mov   rbx ,[display_from]
    imul  rbx , 8
    add   rax , rbx
    mov   rax ,[rax]
    mov   rdi , hex_text + 2
    call  hex_to_ascii
    mov   rax , ypos
    mov   rdx ,[rax]
    add   rdx , [fontsize]
    add   rdx , 1
    mov  [rax], rdx
    mov   rax , 4
    mov   rbx , hex_text
    mov   rcx , r12
    mov   rsi , r15
    mov   r9 , 1
    int   0x60
  noclear:
    add   r11 , 8

    add   r10 , 1
    cmp   r10 , [lines]
    jbe   dsil1

    ret


hex_to_ascii:

    push  rax
    push  rbx
    push  rcx
    push  rdx
    push  rdi
    push  r8
    push  r9
    add   rdi , 15
    mov   r8 , 16
    mov   r9 , 0
  htal1:
    mov   rdx , 0
    mov   rbx , 16
    div   rbx
    mov   rcx , 65 - 58
    mov   rbx , 10
    cmp   rdx , rbx
    jne   nh10
    add   rdx , rcx
  nh10:
    mov   rbx , 11
    cmp   rdx , rbx
    jne   nh11
    add   rdx , rcx
  nh11:
    mov   rbx , 12
    cmp   rdx , rbx
    jne   nh12
    add   rdx , rcx
  nh12:
    mov   rbx , 13
    cmp   rdx , rbx
    jne   nh13
    add   rdx , rcx
  nh13:
    mov   rbx , 14
    cmp   rdx , rbx
    jne   nh14
    add   rdx , rcx
  nh14:
    mov   rbx , 15
    cmp   rdx , rbx
    jne   nh15
    add   rdx , rcx
  nh15:
    add   rdx , 48
    mov  [rdi], dl
    dec   rdi
    dec   r8
    cmp   r8 , r9
    jne   htal1
    pop   r9
    pop   r8
    pop   rdi
    pop   rdx
    pop   rcx
    pop   rbx
    pop   rax

    ret

text_pointers:

    dq    example_text_3
    dq    window_stack_text
    dq    boot_text
    dq    paging_table_use

window_label:    db    'GEN/STACK/BOOT',0

button_text_1:   db    'GENERAL',0
button_text_2:   db    'WSTACK',0
button_text_3:   db    'BOOT',0
button_text_4:   db    'PAGING',0
button_text_5:   db    'UPDATE',0

hex_text:        db    '0x0000000000000000',0

display_from:    dq   0
scroll_value:    dq   1000
ypos:            dq   0
dip:             dq   1
disover:         dq   0
lines:           dq   10

example_text_3:

    db   'Current running process slot . . .',0
    db   'Maximum process slot used  . . . .',0
    db   'Buttons in button list . . . . . .',0
    db   'PID of currently running process .',0
    db   'Background requests 0/1  . . . . .',0
    db   'Uptime in 1/100 seconds  . . . . .',0
    db   'Mouse x position . . . . . . . . .',0
    db   'Mouse y position . . . . . . . . .',0
    db   'Mouse buttons pressed  . . . . . .',0
    db   'Previous mouse x position  . . . .',0
    db   'Previous mouse y position  . . . .',0
    db   'If > uptime, do not draw mouse . .',0
    db   'Mouse picture on/off . . . . . . .',0
    db   'Pressed button ID  . . . . . . . .',0
    db   'Pressed button PID . . . . . . . .',0
    db   'Entries in window stack  . . . . .',0
    db   'Background X size  . . . . . . . .',0
    db   'Background Y size  . . . . . . . .',0
    db   'Background draw type . . . . . . .',0
    db   'Entries in process queue base  . .',0
    db   'Idle time stamp counter increment ',0
    db   'Idle time stamp count / second . .',0
    db   'Time stamp count at previous sec .',0
    db   'Time stamp count / second  . . . .',0
    db   'Window color . . . . . . . . . . .',0
    db   'Close button color . . . . . . . .',0
    db   'Hide button color  . . . . . . . .',0
    db   'Window button color  . . . . . . .',0
    db   'Window menu bar color  . . . . . .',0
    db   'Window menu open color . . . . . .',0
    db   'Round window edges . . . . . . . .',0
    db   '/HD/1/ Port  . . . . . . . . . . .',0
    db   '/HD/1/ Primary/Secondary . . . . .',0
    db   '/HD/1/ Enable  . . . . . . . . . .',0
    db   '/HD/1/ Partition . . . . . . . . .',0
    db   '/HD/1/ Irq . . . . . . . . . . . .',0
    db   '/FD/1/ Enable  . . . . . . . . . .',0
    db   '/FD/1/ Base  . . . . . . . . . . .',0
    db   '/FD/1/ IRQ . . . . . . . . . . . .',0
    db   'Entries in scroll base . . . . . .',0
    db   '/CD/1/ Port  . . . . . . . . . . .',0
    db   '/CD/1/ Primary/Secondary . . . . .',0
    db   '/CD/1/ Enable  . . . . . . . . . .',0
    db   '/CD/1/ IRQ . . . . . . . . . . . .',0
    db   'Window menu text color . . . . . .',0
    db   'Window skinning (0/1=off/on) . . .',0
    db   'Mouse scroll wheel value . . . . .',0
    db   'Amount of ram from config.mnt  . .',0
    db   'Uptime in 1/1000 secs  . . . . . .',0
    db   'Window transparency (0/1=off/on) .',0
    db   'Process start memory . . . . . . .',0
    db   'Transparency A . . . . . . . . . .',0
    db   'Transparency B . . . . . . . . . .',0
    db   'EHCI base  . . . . . . . . . . . .',0
    db   'USB state (0/1/2+=off/on/error)  .',0
    db   'USB device scan count  . . . . . .',0
    db   'USB legacy disable (0/1=off/on)  .',0
    db   'Transparency opacity (0/1/2) . . .',0
    db   'MTRR wbinvd (0/1=off/on) . . . . .',0
    db   'MCE (0/1=off/on) . . . . . . . . .',0
    db   'Window content (0/1=no/yes)  . . .',0
    db   'Window content interval  . . . . .',0
    db   'Socket states  . . . . . . . . . .',0
    db   'EHCI cache method  . . . . . . . .',0
    db   'xxxxxxxxxxx'

boot_text:

    db   'Bits per pixel . . . . . . . . . .',0
    db   'Vesa video mode  . . . . . . . . .',0
    db   'Mouse port . . . . . . . . . . . .',0
    db   'Vesa 2.0 LFB address . . . . . . .',0
    db   'X resolution . . . . . . . . . . .',0
    db   'Y resolution . . . . . . . . . . .',0
    db   '[unused] . . . . . . . . . . . . .',0
    db   '[unused] . . . . . . . . . . . . .',0
    db   'Scanline length  . . . . . . . . .',0
    db   'Bytes per pixel  . . . . . . . . .',0
    db   'Mouse packet size  . . . . . . . .',0
    db   'Graphics (0/1=vesa/drv)  . . . . .',0
    db   'Bootup pixel count . . . . . . . .',0
    db   'xxxxxxxxxxx'

paging_table_use:

    db   'Paging Table Use                  ',0
    db   'xxxxxxxxxxxx'

window_stack_text:

    db   'Window Stack                      ',0

wstacknum:

    times 100 times 35 db ?

system_general_1:

    times 2048 db ?

IMAGE_END:

