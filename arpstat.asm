;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;    ARP Status Monitor for Menuet
;
;    This program displays the ARP table, and it's settings
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


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

rex equ r8
rfx equ r9
rgx equ r10
rhx equ r11
rix equ r12
rjx equ r13
rkx equ r14
rlx equ r15

START:                           ; start of execution

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


display_num:

    mov   ecx, eax
  newnuml1:
    mov   eax, ecx
    shr   eax, 4
    and   eax, 0x0f
    mov   al, [eax + hextable]
    mov   [ebx], al
    inc   ebx
    mov   eax, ecx
    and   eax, 0x0f
    mov   al, [eax + hextable]
    mov   [ebx], al
    inc   ebx
    shr   ecx , 8
    dec   rex
    jnz   newnuml1

    ret


draw_info:

    ; Read the stack status data and write it to the screen buffer

    mov   eax, 53
    mov   ebx, 255
    mov   ecx, 200
    int   0x40

    push  rax
    mov   ebx, text + 25
    call  printhex

    mov   eax, 53
    mov   ebx, 255
    mov   ecx, 201
    int   0x40

    mov   ebx, text + 65
    call  printhex

    ; Fill the table with blanks

    mov   edx, text + 160
  doBlank:
    mov   esi, blank
    mov   edi, edx
    mov   ecx, 40
    rep   movsb
    add   edx, 40

    cmp   edx, text + 560
    jne   doBlank

    pop   rcx                 ; The number of entries

    mov   ebx, text+ 160 +1   ; Position for the first IP address line

    xor   edx, edx            ; edx is index into the ARP table

    cmp   ecx, 10
    jle   show_entries
    mov   ecx, 10

  show_entries:

    cmp   ecx , 0
    jne   no_last_entry
    call  draw_entries
    ret
  no_last_entry:

    push  rcx
    push  rdx
    push  rbx

    ; Select the arp table entry (in edx)
    mov   eax, 53
    mov   ebx, 255
    mov   ecx, 202
    int   0x40

    ; Read the IP address
    mov   eax, 53
    mov   ebx, 255
    mov   ecx, 203
    int   0x40

    ; IP in eax. Get the address to put it back
    pop   rbx
    push  rbx

    call  writeDecimal    ; Extract 1 byte from eax, store it in string
    add   ebx, 4
    shr   eax, 8
    call  writeDecimal    ; Extract 1 byte from eax, store it in string
    add   ebx, 4
    shr   eax, 8
    call  writeDecimal    ; Extract 1 byte from eax, store it in string
    add   ebx, 4
    shr   eax, 8
    call  writeDecimal    ; Extract 1 byte from eax, store it in string

    add   ebx, 4

    ; Now display the 6 byte MAC

    push  rbx
    mov   eax, 53
    mov   ebx, 255
    mov   ecx, 204
    int   0x40
    pop   rbx

    mov   rex , 4
    call  display_num

    push  rbx
    mov   eax, 53
    mov   ebx, 255
    mov   ecx, 205
    int   0x40
    pop   rbx

    mov   rex , 2
    call  display_num

    ; Now display the stat field

    inc   ebx
    push  rbx
    mov   eax, 53
    mov   ebx, 255
    mov   ecx, 206
    int   0x40
    pop   rbx

    mov   rex , 2
    call  display_num

    ; Now display the TTL field (this is intel word format)

    inc   ebx
    push  rbx
    mov   eax, 53
    mov   ebx, 255
    mov   ecx, 207
    int   0x40
    pop   rbx

    mov   ecx, eax
    shr   eax, 12
    and   eax, 0x0f
    mov   al, [eax + hextable]
    mov   [ebx], al
    inc   ebx
    mov   eax, ecx
    shr   eax, 8
    and   eax, 0x0f
    mov   al, [eax + hextable]
    mov   [ebx], al
    inc   ebx
    mov   eax, ecx
    shr   eax, 4
    and   eax, 0x0f
    mov   al, [eax + hextable]
    mov   [ebx], al
    inc   ebx
    mov   eax, ecx
    and   eax, 0x0f
    mov   al, [eax + hextable]
    mov   [ebx], al

    pop   rbx
    add   ebx, 40

    pop   rdx
    inc   edx

    pop   rcx

    dec   ecx
    jmp   show_entries


red:                            ; Redraw
    call  draw_window
    jmp   still

key:                          ; Keys are not valid at this part of the
    mov   eax,2                 ; loop. Just read it and ignore
    int   0x40
    jmp   still

button:

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


writeDecimal:

    push  rax rbx rcx

    and   eax, 0xff
    mov   ecx, eax
    mov   dl, 100
    div   dl
    mov   cl, ah
    add   al, '0'
    mov   [ebx], al
    inc   ebx
    mov   eax, ecx
    mov   dl, 10
    div   dl
    mov   cl, ah
    add   al, '0'
    mov   [ebx], al
    inc   ebx
    mov   al, ah
    add   al, '0'
    mov   [ebx], al

    pop   rcx rbx rax

    ret

; Window definitions and draw

draw_window:

    mov   eax,12
    mov   ebx,1
    int   0x40

    mov   rax , 0x0                          ; Draw window
    mov   rbx,  100*0x100000000+293
    mov   rcx,  100*0x100000000+243
    push  rax rbx
    mov   rax , 141
    mov   rbx , 3
    int   0x60
    and   rax , 0xff
    sub   rax , 9
    imul  rax , 14
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

    push  rax rbx
    mov   rax , 141
    mov   rbx , 3
    int   0x60
    and   rax , 0xff
    add   rax , 3
    mov   r12 , rax
    pop   rbx rax

    ; White background

    mov   rax , 13
    mov   rbx , 25*0x100000000+41*6
    mov   rcx , 50*0x100000000
    mov   rdx , r12
    imul  rdx , 14
    add   rcx , rdx
    mov   rdx , 0xffffff
    int   0x60

    ; Redraw the screen text

    mov   ebx,25*65536+50
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

    push  rax rbx rcx rdx rsi rdi

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

    pop   rdi rsi rdx rcx rbx rax

    ret

; Data area

text:

    db ' Number of entries    : 0xxxxxxxxx      '
    db ' Maximum entries      : 0xxxxxxxxx      '
    db '                                        '
    db ' IP Address      MAC          Stat TTL  '
    db ' ............... ............ .... .... '
    db ' ............... ............ .... .... '
    db ' ............... ............ .... .... '
    db ' ............... ............ .... .... '
    db ' ............... ............ .... .... '
    db ' ............... ............ .... .... '
    db ' ............... ............ .... .... '
    db ' ............... ............ .... .... '
    db ' ............... ............ .... .... '
    db ' ............... ............ .... .... '

    db 'x <- END MARKER, DONT DELETE            '

blank:

    db ' ............... ............ .... .... '

window_label:

    db 'ARP TABLE',0

hextable:

    db '0123456789ABCDEF'

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

