;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   PCIscan for Menuet64
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

    call  scan_devices

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

    cmp   rbx , 1000
    jb    noscroll
    cmp   rbx , 1500
    ja    noscroll
    mov   [sc],rbx
    call  scroll
    call  draw_devices
    jmp   still
  noscroll:

    jmp   still



draw_window:

    mov   rax , 0xC                          ; Beginning of window draw
    mov   rbx , 0x1
    int   0x60

    mov   rax , 141
    mov   rbx , 3
    int   0x60
    and   rax , 0xff
    mov   [fontsize],rax

    mov   rax , 0x0                          ; Draw window
    mov   rbx , 0x0000002000000000 +576      ; x start & size
    mov   rcx , 0x0000002000000000 +341      ; y start & size
    mov   rdx , 0x0000000000FFFFFF           ; type    & border color
    mov   r8  , 0x0000000000000001           ; draw flags
    mov   r9  , window_label                 ; 0 or label - asciiz
    mov   r10 , menu_struct                  ; 0 or pointer to menu struct
    int   0x60

    call  scroll

    call  draw_devices

    mov   rax , 0xC                          ; End of window draw
    mov   rbx , 0x2
    int   0x60

    ret


scan_devices:

    ; Clear area

    mov   rdi , scan_result
    mov   rax , 0
    mov   rcx , 4*16*1024
    cld
    rep   stosb

    ;

    mov   r15 , scan_result

    mov   rdi , - 0x100

  scan_next:

    add   rdi , 0x100

    mov   r11 , rdi
    and   r11 , 0x0000ff00
    cmp   r11 , 0x0000ff00
    jne   noskip
    add   rdi , 0x100
  noskip:

    cmp   edi , 0x00fd0000
    ja    scan_exit

    mov   rax , 115
    mov   rbx , 1
    mov   rcx , rdi
    int   0x60

    cmp   eax , 0xffffffff
    je    scan_next

    mov  [r15],rax

    push  r15
    push  rdi

    add   rdi , 4

    mov   r13 , 10
  newsub:
    mov   rax , 115
    mov   rbx , 1
    mov   rcx , rdi
    int   0x60

    add   r15 , 4
    mov   [r15],rax
    add   rdi , 4

    dec   r13
    jnz   newsub

    pop   rdi
    pop   r15

    add   r15 , 4*16

    jmp   scan_next

  scan_exit:

    ret


draw_devices:

    mov   r13 , [sc]
    sub   r13 , 1000
    imul  r13 , 4*16
    add   r13 , scan_result
    mov   r14 , 200
    mov   r15 , 55
    mov   r12 , 1
    add   r12 , [sc]
    sub   r12 , 1000

  nextPCIdevice:

    mov   rax , 13
    mov   rbx , 16
    shl   rbx , 32
    add   rbx , 190
    mov   rcx , r15
    dec   rcx
    shl   rcx , 32
    add   rcx , [fontsize]
    inc   rcx
    mov   rdx , 0xffffff
    int   0x60

    ; Count

    mov   rax , 47
    mov   rbx , 3*65536
    mov   rcx , r12
    mov   rdx , 16 * 0x10000
    add   rdx , r15
    mov   rsi , 0x000000
    int   0x40

    call  scan_manufacturer
    call  scan_device_type

    ; Manufacturer and device type

    mov   rax , 4
    mov   rbx , device
    mov   rcx , 44
    mov   rdx , r15
    mov   rsi , 0x000000
    mov   r9  , 1
    int   0x60

    ;

    push  r14
    push  r13

  newpci:

    mov   rax , 13
    mov   rbx , r14
    shl   rbx , 32
    add   rbx , 6*8
    mov   rcx , r15
    dec   rcx
    shl   rcx , 32
    add   rcx , [fontsize]
    inc   rcx
    mov   rdx , 0xffffff
    int   0x60

    mov   ecx , [r13]
    mov   eax , 47
    mov   rbx , 8*65536 + 1*256
    mov   rdx , r14
    shl   rdx , 16
    add   rdx , r15
    mov   esi , 0
    int   0x40

    add   r13 , 4
    add   r14 , 58

    cmp   r14 , 500
    jb    newpci

    pop   r13
    pop   r14

    add   r13 , 4*16

    inc   r12

    add   r15 , [fontsize]
    add   r15 , 2
    cmp   [fontsize],dword 9
    jbe   noydec
    dec   r15
  noydec:

    cmp   r15 , 320
    ja    PCIscanExit

    jmp   nextPCIdevice

  PCIscanExit:

    ret



scan_manufacturer:

    mov   rsi , unknown
    mov   rdi , device
    mov   rcx , 25
    cld
    rep   movsb

    mov   r8  , [r13]
    and   r8  , 0xffff
    mov   rsi , manulist

  newmsearch:

    xor   rcx , rcx
    mov   rbx , 0
  newhex:
    movzx rdx , byte [rsi]
    cmp   dl , '9'
    jbe   hexfine
    sub   dl , 'A'-10-'0'
  hexfine:
    sub   dl , '0'
    shl   rcx , 4
    add   rcx , rdx
    add   rsi , 1
    add   rbx , 1
    cmp   rbx , 4
    jb    newhex

    cmp   rcx , r8
    jne   notfound

    mov   rdi , device
    mov   rax , 32
    mov   rcx , 25
    cld
    rep   stosb

    add   rsi , 1

    mov   rdi , device+1
    mov   rcx , 25
  newchar:
    lodsb
    cmp   al , 13
    jbe   charok
    stosb
    loop  newchar
  charok:

    jmp   scanmexit

  notfound:

    inc   rsi

    cmp   rsi , manulistend
    ja    scanmexit

    mov   al , [rsi-1]
    cmp   al , 10
    je    newmsearch

    jmp   notfound

  scanmexit:

    ret


scan_device_type:

    device_pos equ 13
    device_len equ 13

    mov   rdi , device-3+device_pos
    mov   rcx , device_len+1
    mov   rax , ' '
    cld
    rep   stosb

    mov   r8  , [r13+8]
    shr   r8  , 8
    and   r8  , 0xffffff
    mov   rsi , devicelist

  newsearchdevice:

    cmp   [rsi],byte ' '
    jbe   scanexitdevice

    push  rsi
    xor   r10 , r10
    mov   rbx , 0
    mov   rcx , 4*6
  newhexdevice:
    movzx rdx , byte [rsi]
    cmp   dl , '9'
    jbe   hexfinedevice
    sub   dl , 'A'-10-'0'
  hexfinedevice:
    sub   dl , '0'
    shl   r10 , 4
    add   r10 , rdx
    add   rsi , 1
    add   rbx , 1
    sub   rcx , 4
    cmp   [rsi],byte 'x'
    je    trunc
    cmp   rbx , 6
    jb    newhexdevice
  trunc:
    pop   rsi
    add   rsi , 6

    mov   r9  , r8
    shr   r9  , cl

    cmp   r9  , r10
    jne   notfounddevice

    push  rsi
    mov   rsi , parenthesis
    mov   rdi , device-3+device_pos
    mov   rcx , device_len+1
    cld
    rep   movsb
    pop   rsi

    add   rsi , 1

    mov   rdi , device+device_pos
    mov   rcx , device_len-4
  newchardevice:
    lodsb
    cmp   al , 13
    jbe   charokdevice
    stosb
    loop  newchardevice
  charokdevice:

  notfounddevice:

    inc   rsi

    cmp   rsi , devicelistend
    ja    scanexitdevice

    mov   al , [rsi-1]
    cmp   al , 10
    je    newsearchdevice

    jmp   notfounddevice

  scanexitdevice:

    ret


scroll:

    mov   rax , 113
    mov   rbx , 1
    mov   rcx , 1000
    mov   rdx , 76+28
    mov   r8  , [sc]
    mov   r9  , 549
    mov   r10 , 55
    mov   r11 , 271
    int   0x60

    ret

;
; Data area
;

window_label:  db   'PCI DEVICES',0
device:        db   '                                                     ',0
unknown:       db   ' [unknown]                    '
parenthesis:   db   ' -                 '
fontsize:      dq   0x0
sc:            dq   1000

manulist:      file 'vendorn.inc'
manulistend:
devicelist:    file 'pcicla.inc'
devicelistend:

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

scan_result:

    ; 4*16 for each

image_end:

