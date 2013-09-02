;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;    Stack Status Monitor
;
;    Compile with FASM for Menuet
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use64

    org   0x0

    db    'MENUET64'              ; Header identifier
    dq    0x01                    ; Version
    dq    START                   ; Start of code
    dq    I_END                   ; Size of image
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

    call  draw_window            ; at first, draw the window

still:

    mov   eax,23                 ; Wait here for event
    mov   ebx,200
    int   0x40

    cmp   eax,1                  ; Redraw request
    jz    red
    cmp   eax,2                  ; Key in buffer
    jz    key
    cmp   eax,3                  ; Button in buffer
    jz    button

    call  draw_info

    jmp   still


draw_info:

    ; Read the stack status data, and write it to the screen buffer

    mov   eax, 53
    mov   ebx, 255
    mov   ecx, 6
    int   0x40

    mov   ebx, text + 24
    call  printhex

    mov   eax, 53
    mov   ebx, 255
    mov   ecx, 2
    int   0x40

    mov   ebx, text + 107
    call  printhex

    mov   eax, 53
    mov   ebx, 255
    mov   ecx, 5
    int   0x40

    mov   ebx, text + 107 + 40
    call  printhex

    mov   eax, 53
    mov   ebx, 255
    mov   ecx, 4
    int   0x40

    mov   ebx, text + 107 + 80
    call  printhex

    mov   eax, 53
    mov   ebx, 255
    mov   ecx, 3
    int   0x40

    mov   ebx, text + 107 + 120
    call  printhex

    mov   eax, 53
    mov   ebx, 255
    mov   ecx, 100
    int   0x40

    mov   ebx, text + 258 + 40
    call  printhex

    mov   eax, 53
    mov   ebx, 255
    mov   ecx, 101
    int   0x40

    mov   ebx, text + 258 + 80
    call  printhex

    mov   eax, 53
    mov   ebx, 255
    mov   ecx, 102
    int   0x40

    mov   ebx, text + 258 + 120
    call  printhex

    mov   eax, 53
    mov   ebx, 255
    mov   ecx, 103
    int   0x40

    mov   ebx, text + 258 + 160
    call  printhex

    call  draw_entries

    ret


red:                            ; Redraw
    call  draw_window
    jmp   still

key:                            ; Keys are not valid at this part of the
    mov   eax,2                 ; loop. Just read it and ignore
    int   0x40
    jmp   still

button:                         ; Button

    mov   rax,17
    int   0x60

    cmp   rbx , 0x10000001
    jne   no_button_close
    mov   rax,512
    int   0x60
  no_button_close:

    cmp   rbx , 0x106
    jne   no_menu_close
    mov   rax,512
    int   0x60
  no_menu_close:

    jmp   still

; Window definitions and draw

draw_window:

    mov   eax,12
    mov   ebx,1
    int   0x40

    mov   rax , 0x0                          ; Draw window
    mov   rbx,  100*0x100000000+265
    mov   rcx,  100*0x100000000+210

    push  rax rbx
    mov   rax , 141
    mov   rbx , 3
    int   0x60
    and   rax , 0xff
    sub   rax , 9
    imul  rax , 9
    add   rcx , rax
    pop   rbx rax

    mov   rdx , 0xFFFFFF
    mov   r8  , 0x1
    mov   r9  , window_label
    mov   r10 , menu_struct
    int   0x60

    call  draw_info

    mov   eax,12
    mov   ebx,2
    int   0x40

    ret


draw_entries:

    ; Draw background

    mov   rax , 13
    mov   rbx , 25*0x100000000+37*6
    mov   rcx , 53*0x100000000+12*11
    mov   rdx , 0xffffff
    int   0x60

    push  rax rbx
    mov   rax , 141
    mov   rbx , 3
    int   0x60
    and   rax , 0xff
    add   rax , 3
    mov   r12 , rax
    pop   rbx rax

    ; Redraw the screen text

    mov   ebx,25*65536+53
    mov   ecx,0x000000
    mov   edx,text
    mov   esi,40
  newline:
    mov   eax,4
    int   0x40
    add   ebx,r12d
    add   edx,40
    cmp   [edx],byte 'x'
    jnz   newline

    ret


printhex:

; number in eax
; print to ebx
; xlat from hextable

    mov   esi, ebx
    add   esi, 8
    mov   ebx, hextable
    mov   ecx, 8
  phex_loop:
    mov   edx, eax
    and   eax, 15
    xlatb
    mov   [esi], al
    mov   eax, edx
    shr   eax, 4
    dec   esi
    loop  phex_loop

    ret


; Data area

text:

    db ' Ethernet card status: 0xxxxxxxxx       '
    db '                                        '
    db ' IP packets received    : 0xxxxxxxxx    '
    db ' ARP packets received   : 0xxxxxxxxx    '
    db ' Dumped received packets: 0xxxxxxxxx    '
    db ' Sent packets           : 0xxxxxxxxx    '
    db '                                        '
    db ' Empty queue   : 0xxxxxxxxx             '
    db ' IPout queue   : 0xxxxxxxxx             '
    db ' IPin  queue   : 0xxxxxxxxx             '
    db ' Net1out queue : 0xxxxxxxxx             '
    db 'x <- END MARKER, DONT DELETE            '

window_label:

    db   'STACK STATUS',0

hextable:

    db   '0123456789ABCDEF'

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

I_END:

