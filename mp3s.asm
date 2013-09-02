;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;    MP3 Shoutcast Server for Menuet64
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

version  equ  '0.7'

use64

    org   0x0

    db    'MENUET64'              ; Header identifier
    dq    0x01                    ; Version
    dq    START                   ; Start of code
    dq    I_END                   ; Size of image
    dq    0x400000                ; Memory for app
    dq    0x3ffff0                ; Esp
    dq    0x00                    ; Prm
    dq    0x00                    ; Icon

rex   equ   r8

include 'textbox.inc'

START:                           ; Start of execution

    mov   rax , 141
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    mov   [status],0
    call  clear_input
    call  draw_window            ; At first, draw the window

still:

    mov   rsp , 0x3ffff0

    mov   eax,23                 ; Wait here for event
    mov   ebx,2
    int   0x40

    call  check_events

    call  check_connection_status

    cmp   [status],2
    jge   start_transmission

    jmp   still

check_events:

    cmp   eax,1                  ; Redraw request
    jz    red
    cmp   eax,2                  ; Key in buffer
    jz    key
    cmp   eax,3                  ; Button in buffer
    jz    button

    ret

red:                             ; Redraw
    call  draw_window
    ret

key:
    mov   eax,2                  ; Just read it and ignore
    int   0x40
    ret

button:                          ; Button

    mov   eax,17
    int   0x40

    mov   rbx , rax
    shr   rbx , 8
    cmp   rbx , 1001
    jne   notextbox
    mov   r14 , textbox1
    call  read_textbox
    mov   rsi , tbf
    mov   rdi , filename
    mov   rcx , 50
    cld
    rep   movsb
    jmp   still
  notextbox:

    cmp   ah,1                   ; Close
    jne   no_close
    mov   eax,-1
    int   0x40
  no_close:

    cmp   ah,2                   ; Open socket
    jnz   tst3

    ; Socket open -> close first

    cmp   [server_active],0
    je    no_close_before
    mov   eax,53
    mov   ebx,8
    mov   ecx,[socket]
    int   0x40
    mov   [server_active],0
    mov   eax , 5
    mov   ebx , 20
    int   0x40
  no_close_before:

    mov   eax,53
    mov   ebx,5
    mov   ecx,8008
    mov   edx,0
    mov   esi,0
    mov   edi,0
    int   0x40

    mov   [socket], eax
    mov   [posy],1
    mov   [posx],0
    mov   [read_on],1
    mov   [server_active],1
    call  check_for_incoming_data

    ret
  tst3:

    cmp   ah,4                  ; Close socket
    je    close_socket
    cmp   ah,6
    je    close_socket
    jmp   no_socket_close
  close_socket:
    mov   edx, eax
    mov   eax, 53
    mov   ebx, 8
    mov   ecx, [socket]
    int   0x40
    mov   [server_active],0
    mov   rsp , 0x3ffff0
    cmp   dh,6
    je    read_string
    jmp   still
  no_socket_close:

    cmp   ah,9
    jne   no_bps_add
    cmp   [bps],256*1024
    jae   doret2
    add   [bps],8*1024
    call  display_bps
  doret2:
    ret
  no_bps_add:

    cmp   ah,8
    jne   no_bps_sub
    cmp   [bps],8*1024
    jbe   doret
    sub   [bps],8*1024
    call  display_bps
  doret:
    ret
  no_bps_sub:

    ret

macro pusha {

    push  rax
    push  rbx
    push  rcx
    push  rdx
    push  rsi
    push  rdi

}

macro popa {

     pop  rdi
     pop  rsi
     pop  rdx
     pop  rcx
     pop  rbx
     pop  rax

}

clear_input:

    mov   edi,input_text
    mov   eax,32
    mov   ecx,60*40
    cld
    rep   stosb

    ret

read_string:

    mov   [addr],dword filename
    mov   [ya],dword 95

    mov   edi,[addr]
    mov   eax,32
    mov   ecx,30
    cld
    rep   stosb

    call  print_text

    mov   edi,[addr]
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
    cmp   edi,[addr]
    jz    f11
    sub   edi,1
    mov   [edi],byte 32
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
    add   edi,1
    mov   esi,[addr]
    add   esi,30
    cmp   esi,edi
    jnz   f11

  read_done:

    mov   ecx,40
    mov   eax,0
    cld
    rep   movsb

    call  print_text

    jmp   still

print_text:

    pusha

    mov   eax,13
    mov   ebx,56*65536+26*6
    mov   ecx,[ya]
    dec   ecx
    shl   ecx,16
    mov   cx,12
    mov   edx,0xffffff
    int   0x40

    mov   eax,4
    mov   edx,[addr]
    mov   ebx,56*65536
    add   ebx,[ya]
    mov   ecx,0x000000
    mov   esi,30
    int   0x40

    popa
    ret


start_transmission:

    mov   [bufferunder],dword 0

    mov   rex , 200

  st_wait:

    call  check_connection_status
    cmp  [status], 4
    je    start_transmission_data

    mov   eax , 5
    mov   ebx , 1
    int   0x40

    dec   rex
    jnz   st_wait

    jmp   end_stream

  start_transmission_data:

    call  clear_input

    mov   eax,5
    mov   ebx,50
    int   0x40

    call  check_for_incoming_data
    call  draw_window

    call  send_header

    mov   [fileinfo+4],dword 0   ; Start from beginning
    mov   [read_to],0x40000
    mov   [playpos],0x40000

    mov   ecx,1024 / 512

  new_buffer:

    mov   eax,[read_to]
    mov   ebx,1
    call  read_file

    loop  new_buffer

  newpart:

    call  check_connection_status
    call  draw_window

    mov   eax,26
    mov   ebx,9
    int   0x40
    mov   [transmission_start],eax
    mov   [sentbytes],0

  newblock:

    mov   eax,[read_to]
    mov   ebx,2
    call  read_file

  wait_more:

    mov   eax,26
    mov   ebx,9
    int   0x40

    cmp   eax,[wait_for]
    jge   nomw

    mov   eax,5
    mov   ebx,1
    int   0x40

    jmp   wait_more

  nomw:

    add   eax,2
    mov   [wait_for],eax

    mov   eax,11
    int   0x40
    call  check_events

    ;mov   eax,53
    ;mov   ebx,255
    ;mov   ecx,103
    ;int   0x40
    ;cmp   eax,0
    ;jne   wait_more

    ; Write to socket
    mov   eax,53
    mov   ebx,7
    mov   ecx,[socket]
    mov   edx,[playadd]
    mov   esi,[playpos]
    int   0x40

    add   [sentbytes],edx

    mov   esi,[playpos]
    add   esi,[playadd]
    mov   edi,0x40000
    mov   ecx,110000 / 4
    cld
    rep   movsd

    mov   eax,[playadd]
    sub   [read_to],eax

    call  check_for_incoming_data
    call  show_progress
    call  check_rate

    ; Connection still open ?

    mov   eax, 53
    mov   ebx, 6
    mov   ecx, [socket]
    int   0x40
    cmp   eax,4
    jne   end_stream

    cmp   [bufferunder],dword 0
    jne   end_stream

    mov   eax , [sentbytes]
    cmp   eax , [filesize]
    jae   end_stream

    cmp   [read_to],0x40000
    jge   newblock

  end_stream:

    mov   rax , 5
    mov   rbx , 200
    int   0x60

    ; Close socket

    mov   eax, 53
    mov   ebx, 8
    mov   ecx, [socket]
    int   0x40
    mov   [server_active],0

    mov   eax,5
    mov   ebx,5
    int   0x40

    ; Open socket

    mov   eax,53
    mov   ebx,5
    mov   ecx,8008
    mov   edx,0
    mov   esi,0
    mov   edi,0
    int   0x40
    mov   [socket], eax
    mov   [posy],1
    mov   [posx],0
    mov   [read_on],0
    mov   [server_active],1

    call  draw_window

    jmp   still


check_rate:

    pusha

    mov   eax,[bps]
    xor   edx,edx
    mov   ebx,8*100
    div   ebx
    shl   eax,1
    mov   [playadd],eax

    mov   eax,26
    mov   ebx,9
    int   0x40

    sub   eax,[transmission_start]
    shr   eax,1

    imul  eax,[playadd]

    mov   edx,0x00dd00

    cmp   [sentbytes],eax
    jge   sendok

    push  rax

    ; >= 20000 byte underrun -> stop

    sub   eax , [sentbytes]
    cmp   eax , 20000
    jb    underrunok
    mov   [bufferunder],byte 1
  underrunok:

    pop   rax

    add   [playadd], 150
    mov   edx,0xdd0000

  sendok:

    mov   [progresscolor],edx

    popa

    ret



show_progress:

    pusha

    mov   ecx,[fileinfo+4]
    imul  ecx,512
    cmp   ecx,[progressprev]
    je    noshowprogress

    mov   [progressprev],ecx

    mov   eax,13
    mov   ebx,236*65536+10*6
    mov   ecx,135*65536+12
    mov   edx,0xffffff
    int   0x40

    mov   eax,47
    mov   ebx,9*65536
    mov   ecx,[progressprev]
    mov   edx,236*65536+136
    mov   esi,0x000000
    int   0x40

    mov   eax,13
    mov   ebx,321*65536+9
    mov   ecx,135*65536+9
    mov   edx,[progresscolor]
    int   0x40

  noshowprogress:

    popa
    ret


send_header:

    pusha

    mov   [playpos],0x40000

    mov   esi,fileinfo+5*4
    mov   edi,transname
    mov   ecx,30
    cld
    rep   movsb

    mov   eax, 53
    mov   ebx, 7
    mov   ecx, [socket]
    mov   edx, headere-headers
    mov   esi, headers
    int   0x40

    popa
    ret


read_file:

    cmp   [read_to],0x40000+2000
    jg    cache_ok
    mov   [read_on],1
  cache_ok:

    cmp   [read_to],0x40000+95500
    jg    no_read_1

    mov   [fileinfo+12],eax
    mov   [fileinfo+8],ebx

    mov   eax,58
    mov   ebx,fileinfo
    int   0x40

    mov   [filesize],ebx

    cmp   eax,0
    jne   no_read_1

    mov   eax,[fileinfo+8]
    add   [fileinfo+4],eax

    add   [read_to],512*2

    ret

  no_read_1:

    mov   [read_on],0
    ret



check_for_incoming_data:

    pusha

    mov   eax, 53
    mov   ebx, 2
    mov   ecx, [socket]
    int   0x40

    cmp   eax,0
    je    check_ret_now

  new_data:

    mov   eax, 53
    mov   ebx, 2
    mov   ecx, [socket]
    int   0x40

    cmp   eax,0
    je    check_ret

    mov   eax,53
    mov   ebx,3
    mov   ecx,[socket]
    int   0x40

    cmp   bl,10
    jne   no_lf
    inc   [posy]
    mov   [posx],0
    jmp   new_data
  no_lf:

    cmp   bl,20
    jb    new_data

    inc   [posx]
    cmp   [posx],60
    jbe   xok
    inc   [posy]
    mov   [posx],0
  xok:

    cmp   [posy],12
    jbe   yok
    mov   [posy],1
  yok:

    mov   eax,[posy]
    imul  eax,60
    add   eax,[posx]

    mov   [input_text+eax],bl

    jmp   new_data

  check_ret:

    ;call draw_window

  check_ret_now:

    popa
    ret


check_connection_status:

    pusha

    ; Server: Passive

    mov   eax , 0

    ; Server: Active

    cmp   [server_active],1
    jne   noserveractive

    mov   eax, 53
    mov   ebx, 6
    mov   ecx, [socket]
    int   0x40
    ; out: eax
    jmp   ccsl1

  noserveractive:

    ; Display status

  ccsl1:

    cmp   eax,[status]
    je    ccs_ret
    mov   [status],eax
    add   eax,48
    mov   [text+11],al
    call  draw_info_text
  ccs_ret:

    popa
    ret


; Window definitions and draw

draw_window:

    pusha

    mov   eax,12
    mov   ebx,1
    int   0x40

    mov   rax , 0x0
    mov   rbx,  110*0x100000000+410
    mov   rcx,  100*0x100000000+141+18
    mov   rdx , 0xFFFFFF
    mov   r8  , 0x1
    mov   r9  , window_label
    mov   r10 , 0
    int   0x60

    mov   rax,8
    mov   rbx,25 shl 32 + 130 ;+33
    mov   rcx,35 shl 32 + 17
    mov   rdx,2
    mov   r8 ,0
    mov   r9 ,string_activate
    int   0x60
    mov   rax,8
    mov   rbx,25 shl 32 + 130 ;+33
    mov   rcx,52 shl 32 + 17
    mov   rdx,4
    mov   r8 ,0
    mov   r9 ,string_close
    int   0x60
    mov   r14 , textbox1
    call  draw_textbox

    mov   rax,8                     ; Decrease transfer rate
    mov   rbx,28 shl 32+12
    mov   rcx,128 shl 32+15
    mov   rdx,8
    mov   r8,0
    mov   r9,0
    int   0x60
    mov   rax,8                     ; Increase transfer rate
    mov   rbx,40 shl 32+12
    mov   rcx,128 shl 32+15
    mov   rdx,9
    mov   r8,0
    mov   r9,0
    int   0x60

    call  draw_info_text

    call  display_bps

    mov   [input_text+0],dword 'RECE'
    mov   [input_text+4],dword 'IVED'
    mov   [input_text+8],dword ':   '

    mov   ebx,230*65536+35           ; Draw info text
    mov   ecx,0x00000000
    mov   edx,input_text
    mov   esi,28
    mov   edi,7
   newline2:
    mov   eax,4
    int   0x40
    add   ebx,12
    add   edx,60
    dec   edi
    jnz   newline2

    mov   eax,38
    mov   ebx,212*65536+212
    mov   ecx,24*65536+136+18
    mov   edx,0x000000
    int   0x40

    mov   eax,12
    mov   ebx,2
    int   0x40

    popa

    ret


draw_info_text:

    mov   ebx,8*65536+36+12*6 ; Draw info text
    mov   ecx,0x00000000
    mov   edx,text
    mov   esi,40
  newline:
    pusha
    ; No clear for last line
    cmp   [edx+40],byte 'x'
    je    noclear
    mov   ecx,ebx
    mov   bx,30*6
    dec   ecx
    shl   ecx,16
    mov   cx,12
    mov   eax,13
    mov   edx,0xffffff
    int   0x40
  noclear:
    popa
    mov   eax,4
    int   0x40
    add   ebx,24
    add   edx,40
    cmp   [edx],byte 'x'
    jnz   newline

    ret


display_bps:

    mov   rax , 13
    mov   rbx , 58 shl 32 + 6*3
    mov   rcx , 131 shl 32 + 11
    mov   rdx , 0xffffff
    int   0x60

    mov   eax , [bps]
    xor   edx , edx
    mov   ebx , 1024
    div   ebx
    mov   ecx , eax

    mov   eax , 47
    mov   ebx , 3*65536
    mov   edx , 58*65536+132
    mov   esi , 0x00000000
    int   0x40

    ret



; Data area

text:

   db '   Status: 0  Port: 8008                '
   db '    < >     Kbps                        '
   db 'x <- end marker                         '

string_activate:

   db  'ACTIVATE',0

string_close:

   db  'STOP',0

textbox1:

    dq   0x0
    dq   25
    dq   128 ;+33
    dq   80
    dq   1001
    dq   16
tbf:
    db  '/FD/1/MENUET.MP3',0
    times 50   db  0

headers:
   db   'ICY 200 OK',13,10
   db   'icy-notice1: Requires Winamp, Xmms, iTunes, ..',13,10
   db   'icy-url: http://www.menuetos.net',13,10
   db   'icy-pub: 1',13,10
   db   'icy-name: Menuet Mp3 Shoutcast ',version,' - '
  transname:
   db   '                              ',13,10,13,10
headere:

window_label:

  db   'MP3 SERVER',0

filesize:     dq 0x0
bufferunder:  dq 0x0  ; Timeout for socket data send

socket   dd  0
status   dd  0
posy     dd  1
posx     dd  0
read_on  db  1
read_to  dd  0
addr     dd  0
ya       dd  0
bps      dd  128*1024

server_active   dd  0
progresscolor:  dq  0
progressprev:   dq  0

fileinfo:  dd  0,0,0,0,0x20000
filename:  db  '/FD/1/MENUET.MP3',0
times 50   db  0

wait_for            dd  0x0
transmission_start  dd  0x0
sentbytes           dd  0x0
playadd             dd  256000/8/100
playpos             dd  0x100000

input_text:

I_END:

