;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Stack configuration for Menuet
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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


START:                           ; start of execution

    mov   rax , 141
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    call  read_stack_setup       ; reads setup and draws the window

still:

    mov   rax,10                  ; wait here for event
    int   0x60

    test  rax,1                   ; redraw request ?
    jnz   red
    test  rax,2                   ; key in buffer ?
    jnz   key
    test  rax,4                   ; button in buffer ?
    jnz   button

    jmp   still

  red:                          ; redraw
    call  draw_window
    jmp   still

  key:                           ; key
    mov   rax,2                  ; just read it and ignore
    int   0x60
    jmp   still

  button:                        ; button
    mov   rax,17                 ; get id
    int   0x60

    cmp   rbx,0x10000001
    jne   noclose
    mov   rax,512                ; Button - Close this program
    int   0x60
  noclose:

    cmp   rbx,0x106
    jne   noclose2
    mov   rax,512                ; Menu - Close this program
    int   0x60
  noclose2:

    cmp   rbx,2
    je    read_stack_setup

    cmp   rbx,3
    je    apply_stack_setup

    cmp   rbx,11
    jb    no_set_interface
    cmp   rbx,14
    jg    no_set_interface
    sub   ebx,11
    mov   [interface],ebx
    call  draw_window
    jmp   still
   no_set_interface:

    cmp   ebx,21
    jb    no_ip_sf
    cmp   ebx,22
    jg    no_ip_sf
    sub   ebx,21
    not   ebx
    and   ebx,1
    mov   [assigned],ebx
    call  draw_window
    jmp   still
  no_ip_sf:

    cmp   ebx,7                ; Get IP
    jne   no_read_ip
    mov   [string_x],205
    mov   ebx , [linepos5]
    mov   [string_y],ebx
    mov   [string_length],15
    call  read_string
    mov   esi,string-1
    mov   edi,ip_address
    xor   eax,eax
   ip1:
    inc   esi
    cmp   [esi],byte '0'
    jb    ip2
    cmp   [esi],byte '9'
    jg    ip2
    imul  eax,10
    movzx ebx,byte [esi]
    sub   ebx,48
    add   eax,ebx
    jmp   ip1
   ip2:
    mov   [edi],al
    xor   eax,eax
    inc   edi
    cmp   edi,ip_address+3
    jbe   ip1
    call  draw_window
    jmp   still
   no_read_ip:

    cmp   ebx,5                ; Get COM port
    jne   no_read_comport
    mov   [string_x],272
    mov   [string_y],55
    mov   [string_length],3
    call  read_string
    movzx eax,byte [string]
    cmp   eax,'A'
    jb    gcp1
    sub   eax,'A'-'9'-1
   gcp1:
    sub   eax,48
    shl   eax,8
    mov   ebx,eax
    movzx eax,byte [string+1]
    cmp   eax,'A'
    jb    gcp2
    sub   eax,'A'-'9'-1
   gcp2:
    sub   eax,48
    shl   eax,4
    add   ebx,eax
    movzx eax,byte [string+2]
    cmp   eax,'A'
    jb    gcp3
    sub   eax,'A'-'9'-1
   gcp3:
    sub   eax,48
    add   ebx,eax
    mov   [com_add],ebx
    call  draw_window
    jmp   still
   no_read_comport:

    cmp   ebx,6                ; Get COM irq
    jne   no_read_comirq
    mov   [string_x],284
    mov   ebx , [linepos2]
    mov   [string_y],ebx
    mov   [string_length],1
    call  read_string
    movzx eax,byte [string]
    cmp   eax,'A'
    jb    gci1
    sub   eax,'A'-'9'-1
   gci1:
    sub   eax,48
    mov   [com_irq],eax
    call  draw_window
    jmp   still
  no_read_comirq:

    cmp   ebx, 8              ; Set gateway ip
    jne   no_set_gateway
    mov   [string_x],205
    mov   ebx , [linepos6]
    mov   [string_y],ebx
    mov   [string_length],15
    call  read_string
    mov   esi,string-1
    mov   edi,gateway_ip
    xor   eax,eax
   gip1:
    inc   esi
    cmp   [esi],byte '0'
    jb    gip2
    cmp   [esi],byte '9'
    jg    gip2
    imul  eax,10
    movzx ebx,byte [esi]
    sub   ebx,48
    add   eax,ebx
    jmp   gip1
   gip2:
    mov   [edi],al
    xor   eax,eax
    inc   edi
    cmp   edi,gateway_ip+3
    jbe   gip1
    call draw_window
    jmp     still
  no_set_gateway:

    cmp   ebx, 9          ; Get subnet mask
    jne   no_set_subnet
    mov   [string_x],205
    mov   ebx , [linepos7]
    mov   [string_y],ebx;3*5
    mov   [string_length],15
    call  read_string
    mov   esi,string-1
    mov   edi,subnet_mask
    xor   eax,eax
   sip1:
    inc   esi
    cmp   [esi],byte '0'
    jb    sip2
    cmp   [esi],byte '9'
    jg    sip2
    imul  eax,10
    movzx ebx,byte [esi]
    sub   ebx,48
    add   eax,ebx
    jmp   sip1
   sip2:
    mov   [edi],al
    xor   eax,eax
    inc   edi
    cmp   edi,subnet_mask+3
    jbe   sip1
    call  draw_window
    jmp   still
  no_set_subnet:

    cmp   ebx, 10          ; Get dns
    jne   no_set_dns
    mov   [string_x],205
    mov   ebx , [linepos8]
    mov   [string_y],ebx
    mov   [string_length],15
    call  read_string
    mov   esi,string-1
    mov   edi,dns_ip
    xor   eax,eax
   dip1:
    inc   esi
    cmp   [esi],byte '0'
    jb    dip2
    cmp   [esi],byte '9'
    jg    dip2
    imul  eax,10
    movzx ebx,byte [esi]
    sub   ebx,48
    add   eax,ebx
    jmp   dip1
   dip2:
    mov   [edi],al
    xor   eax,eax
    inc   edi
    cmp   edi,dns_ip+3
    jbe   dip1
    call  draw_window
    jmp   still
  no_set_dns:

    jmp  still



read_stack_setup:

    mov   rax,52
    mov   rbx,0
    int   0x40
    mov   [config],eax

    mov   rax,52
    mov   rbx,1
    int   0x40
    mov   [ip_address],eax

    mov   rax,52
    mov   rbx,9
    int   0x40
    mov   [gateway_ip],eax

    mov   rax,52
    mov   rbx,10
    int   0x40
    mov   [subnet_mask],eax

    mov   rax,52
    mov   rbx,13
    int   0x40
    mov   [dns_ip],eax

    mov   eax,[config]   ; Unwrap com IRQ
    shr   eax,8
    and   eax,0xf
    mov   [com_irq],eax

    mov   eax,[config]   ; Unwrap com PORT
    shr   eax,16
    and   eax,0xfff
    mov   [com_add],eax

    mov   eax,[config]   ; Unwrap IRQ
    and   eax,0xf
    mov   [interface],eax

    mov   eax,[config]   ; Unwrap server assigned
    shr   eax,7
    and   eax,1
    mov   [assigned],eax

    call  draw_window

    jmp   still


apply_stack_setup:

    mov   eax,[com_irq]
    shl   eax,8
    mov   ebx,[com_add]
    shl   ebx,16
    add   eax,ebx
    add   eax,[interface]
    mov   ebx,[assigned]
    shl   ebx,7
    add   eax,ebx
    mov   [config],eax

    mov   eax,52
    mov   ebx,3
    mov   ecx,[ip_address]
    int   0x40

    mov   eax,52
    mov   ebx,11
    mov   ecx,[gateway_ip]
    int   0x40

    mov   eax,52
    mov   ebx,12
    mov   ecx,[subnet_mask]
    int   0x40

    mov   eax,52
    mov   ebx,14
    mov   ecx,[dns_ip]
    int   0x40

    mov   eax,52
    mov   ebx,2
    mov   ecx,[config]
    int   0x40

    jmp   still


read_string:

    mov   edi,string
    mov   eax,'_'
    mov   ecx,[string_length]
    cld
    rep   stosb
    call  print_text

    mov   edi,string
  f11:
    mov   eax,10
    int   0x40
    cmp   eax,2
    jne   read_done
    mov   eax,2
    int   0x40
    shr   eax,8
    cmp   eax,13
    je    read_done
    cmp   eax,8
    jnz   nobsl
    cmp   edi,string
    jz    f11
    sub   edi,1
    mov   [edi],byte '_'
    call  print_text
    jmp   f11
  nobsl:
    cmp   eax,dword 31
    jbe   f11
    cmp   eax,dword 95
    jb    keyok
    sub   eax,32
  keyok:
    mov   [edi],al
    call  print_text

    inc   edi
    mov   esi,string
    add   esi,[string_length]
    cmp   esi,edi
    jnz   f11

  read_done:

    call  print_text

    ret


print_text:

    mov   eax,13
    mov   ebx,[string_x]
    shl   ebx,16
    add   ebx,[string_length]
    imul  bx,6
    mov   ecx,[string_y]
    dec   ecx
    shl   ecx,16
    mov   cx,12
    mov   edx,0xffffff
    int   0x40

    mov   eax,4
    mov   ebx,[string_x]
    shl   ebx,16
    add   ebx,[string_y]
    mov   ecx,0x000000
    mov   edx,string
    mov   esi,[string_length]
    int   0x40

    ret

; Window definitions and draw

draw_window:

    mov   eax,12                    ; Window draw
    mov   ebx,1                     ; 1 start
    int   0x40

    mov   rax , 141
    mov   rbx , 3
    int   0x60
    and   rax , 0xff
    sub   rax , 9
    shr   rax , 1
    add   rax , 9
    add   rax , 2
    mov   [linestep],rax

    mov   rax , 55
    mov   [linepos1],rax
    add   rax , [linestep]
    mov   [linepos2],rax
    add   rax , [linestep]
    mov   [linepos3],rax
    add   rax , [linestep]
    mov   [linepos4],rax
    add   rax , [linestep]
    mov   [linepos5],rax
    add   rax , [linestep]
    mov   [linepos6],rax
    add   rax , [linestep]
    mov   [linepos7],rax
    add   rax , [linestep]
    mov   [linepos8],rax

    add   rax , [linestep]
    add   rax , [linestep]
    add   rax , 5

    mov   [linepos9],rax

    mov   rax , 0x0                          ; Draw window
    mov   rbx , 152*0x100000000+340
    mov   rcx , 085*0x100000000;+204
    add   rcx , [linepos9]
    add   rcx , 36
    mov   rdx , 0x0000000000FFFFFF
    mov   r8  , 0x0000000000000001
    mov   r9  , window_label
    mov   r10 , menu_struct
    int   0x60

    mov   rax , 8                           ; Read setup
    mov   rbx ,  92 * 0x100000000 + 65
    mov   rcx , [linepos9]
    shl   rcx , 32
    add   rcx , 15
    mov   rdx , 2
    mov   r8  , 0
    mov   r9  , b1
    int   0x60

    mov   rax , 8                           ; Apply setup
    mov   rbx , 165 * 0x100000000 + 65
    mov   rcx , [linepos9]
    shl   rcx , 32
    add   rcx , 15
    mov   rdx , 3
    mov   r8  , 0
    mov   r9  , b2
    int   0x60

    mov   eax,8                     ; Buttons 11-14 : Select interface
    mov   ebx,27*65536+10+1
    mov   ecx,53*65536+10+1
    mov   edx,11
  interface_select:
    int   0x40
    mov   r8 , [linestep]
    shl   r8 , 16
    add   ecx, r8d
    inc   edx
    cmp   edx,11+4
    jb    interface_select

    mov   ebx,[interface]           ; Print selected interface
    imul  ebx,[linestep]
    add   ebx,31*65536+54
    mov   eax,4
    mov   ecx,0xffffff
    mov   edx,xx
    mov   esi,1
    int   0x40

    mov   eax,8                    ; Server / manual IP
    mov   ebx,141*65536+10+1
    mov   ecx,[linestep]
    imul  ecx,3
    add   ecx,53
    shl   ecx,16
    add   ecx,10+1
    mov   edx,21
    mov   esi,[button_color]
    mov   r8 , [linestep]
    shl   r8 , 16
    int   0x40
    mov   eax,8
    mov   ebx,141*65536+10+1
    add   ecx , r8d
    mov   edx,22
    int   0x40
    mov   ebx,[assigned]
    not   ebx
    and   ebx,1
    imul  ebx,[linestep]
    mov   ecx,[linestep]
    imul  ecx,3
    add   ecx,53+1
    add   ebx,145*65536;+93
    add   ebx,ecx
    mov   eax,4
    mov   ecx,0xffffff
    mov   edx,xx
    mov   esi,1
    int   0x40

    mov   eax,47                   ; COM address
    mov   ebx,3*65536+1*256
    mov   ecx,[com_add]
    mov   edx,272*65536+55
    mov   esi,0x000000
    int   0x40

    mov   eax,47                   ; COM irq
    mov   ebx,1*65536+1*256
    mov   ecx,[com_irq]
    mov   edx,(266+6*3)*65536 ; +65+3
    add   edx,[linestep]
    add   edx,55
    mov   esi,0x000000
    int   0x40

    mov   edi,ip_address
    mov   edx,205*65536;95+3*4
    add   edx,[linepos5]
    mov   esi,0x000000
    mov   ebx,3*65536
  ipdisplay:
    mov   eax,47
    movzx ecx,byte [edi]
    int   0x40
    add   edx,6*4*65536
    inc   edi
    cmp   edi,ip_address+4
    jb    ipdisplay

    mov   edi,gateway_ip
    mov   edx,205*65536;105+3*5
    add   edx,[linepos6]
    mov   esi,0x000000
    mov   ebx,3*65536
  gipdisplay:
    mov   eax,47
    movzx ecx,byte [edi]
    int   0x40
    add   edx,6*4*65536
    inc   edi
    cmp   edi,gateway_ip+4
    jb    gipdisplay

    mov   edi,subnet_mask
    mov   edx,205*65536;115+3*6
    add   edx,[linepos7]
    mov   esi,0x000000
    mov   ebx,3*65536
  sipdisplay:
    mov   eax,47
    movzx ecx,byte [edi]
    int   0x40
    add   edx,6*4*65536
    inc   edi
    cmp   edi,subnet_mask+4
    jb    sipdisplay

    mov   edi,dns_ip
    mov   edx,205*65536;125+3*7
    add   edx,[linepos8]
    mov   esi,0x000000
    mov   ebx,3*65536
  dipdisplay:
    mov   eax,47
    movzx ecx,byte [edi]
    int   0x40
    add   edx,6*4*65536
    inc   edi
    cmp   edi,dns_ip+4
    jb    dipdisplay

    mov   eax,8                     ; Set port
    mov   ebx,297*65536+10+1
    mov   ecx,[linepos1]
    sub   ecx,2
    shl   ecx,16
    add   ecx,10+1
    mov   edx,5
    mov   esi,[button_color]
    int   0x40
    mov   eax,8                     ; Set irq
    mov   ebx,297*65536+10+1
    mov   ecx,[linepos2]
    sub   ecx,2
    shl   ecx,16
    add   ecx,10+1

    mov   edx,6
    int   0x40

    mov   eax,8                     ; Set IP
    mov   ebx,297*65536+10+1
    mov   ecx,[linepos5]
    sub   ecx,2
    shl   ecx,16
    add   ecx,10+1
    mov   edx,7
    int   0x40

    mov   eax,8                     ; Set gateway IP
    mov   ebx,297*65536+10+1
    mov   ecx,[linepos6]
    sub   ecx,2
    shl   ecx,16
    add   ecx,10+1

    mov   edx,8
    int   0x40

    mov   eax,8                     ; Set subnet
    mov   ebx,297*65536+10+1
    mov   ecx,[linepos7]
    sub   ecx,2
    shl   ecx,16
    add   ecx,10+1
    mov   edx,9
    int   0x40

    mov   eax,8                     ; Set dns ip
    mov   ebx,297*65536+10+1
    mov   ecx,[linepos8]
    sub   ecx,2
    shl   ecx,16
    add   ecx,10+1
    mov   edx,10
    int   0x40

    mov   ebx,31*65536+55           ; Draw info text
    mov   ecx,0x000000
    mov   edx,text
    mov   esi,49
  newline:
    inc   edx
    mov   eax,4
    int   0x40
    add   ebx,[linestep]
    add   edx,49
    cmp   [edx],byte 'x'
    jne   newline

    mov   eax,12                    ; Window draw
    mov   ebx,2                     ; 2 end
    int   0x40

    ret


; Data area

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

text:

    db '   Not active       Modem Com Port:    0x     <   '
    db '   Slip             Modem Com Irq:       0x   <   '
    db '   PPP                                            '
    db '   Ethernet           IP server assigned          '
    db '                      Fixed:     .   .   .    <   '
    db '                      Gateway:   .   .   .    <   '
    db '                      Subnet:    .   .   .    <   '
    db '                      DNS IP:    .   .   .    <   '
    db '                                                  '
xx: db 'x - end marker                                    '

window_label:

    db  'STACK CONFIGURATION',0

b1: db  'READ',0
b2: db  'APPLY',0

button_color   dd  0x2254b9

linestep:      dq  012
linepos1:      dq  0x0
linepos2:      dq  0x0
linepos3:      dq  0x0
linepos4:      dq  0x0
linepos5:      dq  0x0
linepos6:      dq  0x0
linepos7:      dq  0x0
linepos8:      dq  0x0
linepos9:      dq  0x0

string_length  dd  16
string_x       dd  200
string_y       dd  60
string         db  '________________'

ip_address     dd  0
gateway_ip     dd  0
subnet_mask    dd  0
dns_ip         dd  0

com_irq        dd  0   ; irq for slip/ppp
com_add        dd  0   ; com port address for slip/ppp
interface      dd  0   ; not active,slip,ppp,ethernet
assigned       dd  1   ; get ip from server

config         dd  0

I_END:

