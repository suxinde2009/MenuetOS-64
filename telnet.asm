;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;    Telnet for Menuet
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Telnet (port 23, every character sent)
; RAW (other ports, line sent after enter)

macro pusha { push  rax rbx rcx rdx rsi rdi }
macro popa  { pop   rdi rsi rdx rcx rbx rax }

use64

    org   0x0

    db    'MENUET64'              ; Header identifier
    dq    0x01                    ; Version
    dq    START                   ; Start of code
    dq    I_END                   ; Size of image
    dq    0x200000                ; Memory for app
    dq    0x1ffff0                ; Rsp
    dq    0x00                    ; Prm
    dq    0x00                    ; Icon

include 'dns.inc'
include 'textbox.inc'

START:

    ; System font

    mov   rax , 141
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    ; Clear the screen memory

    mov   eax, '    '
    mov   edi,text
    mov   ecx,80*30 /4
    cld
    rep   stosd

    ; Draw the window

    call  draw_window

still:

    ; Check connection status
    mov   eax,53
    mov   ebx,6
    mov   ecx,[socket]
    int   0x40

    mov   ebx, [socket_status]
    mov   [socket_status], eax

    cmp   eax, ebx
    je    waitev
    call  draw_window
  waitev:

    mov   eax,23                 ; Wait here for event
    mov   ebx,1
    int   0x60

    test  eax,1                  ; Redraw request
    jnz   red
    test  eax,2                  ; Key in buffer
    jnz   key
    test  eax,4                  ; Button in buffer
    jnz   button

    ; Any data ?

    mov   eax, 53
    mov   ebx, 2
    mov   ecx, [socket]
    int   0x40
    cmp   eax, 0
    jne   read_input

    jmp   still


read_input:

    push  rcx
    mov   eax, 53
    mov   ebx, 3
    mov   ecx, [socket]
    int   0x40
    pop   rcx

    call  handle_data

    push  rcx
    mov   eax, 53
    mov   ebx, 2
    mov   ecx, [socket]
    int   0x40
    pop   rcx

    cmp   eax, 0
    jne   read_input

    call  draw_text

    jmp   still


handle_data:

    ;
    ; Telnet protocol for port 23
    ; Raw protocol for other ports
    ;

    telnetport equ 23

    cmp   dword [port],dword telnetport
    jne   hd001

    ; Telnet options start with
    ; the byte 0xff and are 3 bytes long.

    mov   al, [telnetstate]
    cmp   al, 0
    je    state0
    cmp   al, 1
    je    state1
    cmp   al, 2
    je    state2
    jmp   hd001

  state0:

    cmp   bl, 255
    jne   hd001
    mov   al, 1
    mov   [telnetstate], al
    ret

  state1:
    mov   al, 2
    mov   [telnetstate], al
    ret

  state2:
    mov   al, 0
    mov   [telnetstate], al
    mov   [telnetrep+2], bl

    mov   edx, 3
    mov   eax,53
    mov   ebx,7
    mov   ecx,[socket]
    mov   esi, telnetrep
    int   0x40
    ret

hd001:

    ; Beginning of line

    cmp   bl,13
    jne   nobol
    mov   ecx,[pos]
    add   ecx,1
  boll1:
    sub   ecx,1
    mov   eax,ecx
    xor   edx,edx
    mov   ebx,80
    div   ebx
    cmp   edx,0
    jne   boll1
    mov   [pos],ecx
    jmp   newdata
  nobol:

    ; Line down

    cmp   bl,10
    jne   nolf
   addx1:
    add   [pos],dword 1
    mov   eax,[pos]
    xor   edx,edx
    mov   ecx,80
    div   ecx
    cmp   edx,0
    jnz   addx1
    mov   eax,[pos]
    jmp   cm1
  nolf:

    ; Backspace

    cmp   bl,8
    jne   nobasp
    push  rax rbx rcx
    mov   eax , [pos]
    xor   rdx , rdx
    mov   rbx , 80
    div   rbx
    imul  rax , 80
    mov   rdx , rax
    pop   rcx rbx rax
    cmp   [pos], edx
    jbe   handledone
    mov   eax,[pos]
    dec   eax
    mov   [pos],eax
    mov   [eax+text],byte 32
    mov   [eax+text+60*80],byte 0
    jmp   newdata
   nobasp:

    ; Character

    cmp   bl,15
    jbe   newdata
    mov   eax,[pos]
    mov   [eax+text],bl
    mov   eax,[pos]
    add   eax,1
  cm1:
    mov   ebx,[scroll+4]
    imul  ebx,80
    cmp   eax,ebx
    jb    noeaxz
    mov   esi,text+80
    mov   edi,text
    mov   ecx,ebx
    cld
    rep   movsb
    mov   eax,ebx
    sub   eax,80
  noeaxz:
    mov   [pos],eax
  newdata:

  handledone:

    ret

red:

    call  draw_window
    jmp   still

key:

    mov   rax,2
    int   0x60

    cmp   [socket_status],dword 4
    jne   still

    test  rbx , 1
    jnz   still

    mov   rax , rcx

    cmp   ax,'Up'
    jne   noaup
    mov   al,'A'
    call  arrow
    jmp   still
  noaup:
    cmp   ax,'Do'
    jne   noadown
    mov   al,'B'
    call  arrow
    jmp   still
  noadown:
    cmp   ax,'Ri'
    jne   noaright
    mov   al,'C'
    call  arrow
    jmp   still
  noaright:
    cmp   ax,'Le'
    jne   noaleft
    mov   al,'D'
    call  arrow
    jmp   still
  noaleft:

    cmp   ax  , 'En'
    jne   noenter
    mov   rax , 13
    jmp   nostill
  noenter:

    cmp   dword [port],dword telnetport
    je    nobackspace
    cmp   ax  , 'Ba'
    jne   nobackspace
    mov   rax , 8
    jmp   nostill
  nobackspace:

    cmp   rbx , 0
    jne   still

    cmp   al  , ' '
    jb    still

  nostill:

    and   rax , 0xff
    call  to_server

    jmp   still

button:

    mov   eax,17
    int   0x40

    mov   rbx , rax
    shr   rbx , 8
    and   rbx , 0xffff

    cmp   rbx , 1001
    jne   notb1
    mov   r14 , textbox1
    call  read_textbox
    jmp   still
  notb1:

    cmp   rbx , 1002
    jne   notb2
    mov   r14 , textbox2
    call  read_textbox
    mov   esi,textbox2+6*8-1
    mov   edi,port
    xor   eax,eax
   ip11:
    inc   esi
    cmp   [esi],byte '0'
    jb    ip21
    cmp   [esi],byte '9'
    jg    ip21
    imul  eax,10
    movzx ebx,byte [esi]
    sub   ebx,48
    add   eax,ebx
    jmp   ip11
   ip21:
    mov   [edi],al
    inc   edi
    mov   [edi],ah

    jmp   still
  notb2:

    ; Close program

    cmp   ah,1
    jne   noclose
    mov   eax,53
    mov   ebx,8
    mov   ecx,[socket]
    int   0x40
    mov   eax,-1
    int   0x40
  noclose:

    ; Connect

    cmp   ah, 4
    jne   notcon
    mov   eax, [socket_status]
    cmp   eax, 4
    je    still
    call  connect
    jmp   still
  notcon:

    ; Disconnect

    cmp   ah,5
    jne   notdiscon
    call  disconnect
    jmp   still
  notdiscon:

    ; Echo toggle

    cmp   ah, 6
    jne   noecho

    mov   al, [echo]
    inc   al
    and   al , 1
    mov   [echo], al

    call  draw_window

    jmp   still

  noecho:

    jmp   still

arrow:

    push  rax
    mov   al,27
    call  to_server
    mov   al,'['
    call  to_server
    pop   rax
    call  to_server

    ret

to_server:

    pusha

    push  ax

    ;
    ; RAW connection
    ;

    cmp   dword [port],dword telnetport
    je    norawl1
    cmp   al  , 13
    jbe   checkspecial
    cmp   dword [rawbufferpos],dword 190
    jae   notelnetsend
    mov   rbx , [rawbufferpos]
    mov   [rawbuffer+rbx],al
    inc   dword [rawbufferpos]
    jmp   notelnetsend
  norawl1:

    ;
    ; TELNET connection
    ;

    mov   [tx_buff], al
    mov   edx, 1

  checkspecial:

    ; Backspace (raw)

    cmp   al, 8
    jne   nobacksp
    cmp   [rawbufferpos],dword 0
    je    notelnetsend
    dec   dword [rawbufferpos]
    mov   rbx , [rawbufferpos]
    mov   [rawbuffer+rbx],byte 0
    jmp   notelnetsend
  nobacksp:

    ; Enter

    cmp   al, 13 ; 13,10
    jne   tm_000
    mov   edx, 2

    ; RAW

    cmp   dword [port],dword telnetport
    je    norawl2
    mov   rbx , [rawbufferpos] ; 13,10
    mov   [rawbuffer+rbx],byte 10
    inc   dword [rawbufferpos]
    mov   edx , [rawbufferpos]
    mov   eax , 53
    mov   ebx , 7
    mov   ecx , [socket]
    mov   esi , rawbuffer
    int   0x40
    mov   [rawbufferpos],dword 0
    jmp   notelnetsend
  norawl2:

  tm_000:

    ; TELNET

    mov   eax , 53
    mov   ebx , 7
    mov   ecx , [socket]
    mov   esi , tx_buff
    int   0x40

  notelnetsend:

    push  rax rbx
    mov   rax , 5
    mov   rbx , 4
    int   0x60
    pop   rbx rax

    pop   bx

    ;
    ; ECHO ON
    ;

    mov   al, [echo]
    cmp   al, 0
    je    tm_001
    push  bx
    call  handle_data
    pop   bx
    cmp   bl, 13
    jne   tm_002
    mov   bl, 10
    call  handle_data
  tm_002:
    call  draw_text
    ;

  tm_001:

    popa
    ret

disconnect:

    mov   eax,53
    mov   ebx,8
    mov   ecx,[socket]
    int   0x40

    ret

connect:

    pusha

    mov   ecx , 1000
  getlp3:
    inc   ecx
    push  rcx
    mov   eax , 53
    mov   ebx , 9
    int   0x40
    pop   rcx
    cmp   eax , 0
    jz    getlp3

    mov   rsi , ipstring
    mov   rdi , ip_address
    call  get_ip

    mov   eax , 53
    mov   ebx , 5
    mov   esi , dword [ip_address]
    movzx edx , word [port]
    mov   edi , 1
    int   0x40

    mov   [socket], eax

    popa

    ret


draw_window:

    pusha

    mov   eax,12
    mov   ebx,1
    int   0x40

    ; Draw window

    mov   rax , 0x0
    mov   rbx , 100*0x100000000+514
    mov   rcx , 100*0x100000000+295
    xor   rdx , rdx
    mov   edx , [wcolor]
    mov   r8  , 0x1
    mov   r9  , window_label
    mov   r10 , 0
    int   0x60

    ; Status bar

    mov   eax, 13
    mov   ebx, 4*65536+507
    mov   ecx, 273*65536+17
    mov   edx, 0xe0e0e0
    int   0x40
    mov   eax, 13
    mov   ebx, 4*65536+507
    mov   ecx, 272*65536+1
    mov   edx, 0xe0e0e0
    int   0x40

    ; Set server text

    mov   eax,4
    mov   ebx,6*65536+276+2
    mov   ecx,[cbtext]
    mov   edx,setipt
    mov   esi,setiplen-setipt
    int   0x40

    ; Port text

    mov   eax,4
    mov   ebx,182*65536+276+2
    mov   ecx,[cbtext]
    mov   edx,setportt
    mov   esi,setportlen-setportt
    int   0x40

    ; Connect button

    mov   eax,8
    mov   ebx,250*65536+50+2
    mov   ecx,273*65536+12+5
    mov   esi, 0x00557799
    mov   edx,4
    int   0x40
    mov   eax,4
    mov   ebx,255*65536+276+2
    mov   ecx,0x000000;[cbtext]
    mov   edx,cont
    mov   esi,conlen-cont
    int   0x40

    ; Disconnect button

    mov   eax,8
    mov   ebx,303*65536+70
    mov   ecx,273*65536+12+5
    mov   edx,5
    mov   esi, 0x00557799
    int   0x40
    mov   eax,4
    mov   ebx,307*65536+276+2
    mov   ecx,0x000000;[cbtext]
    mov   edx,dist
    mov   esi,dislen-dist
    int   0x40

    ; Display connection status

    mov   esi, contlen-contt
    mov   edx, contt
    mov   ebx, 377*65536+278
    cmp   dword [port],dword telnetport
    jne   noport23
    mov   esi, contellen-contel
    mov   edx, contel
    mov   ebx, 377*65536+278
  noport23:
    mov   eax, [socket_status]
    cmp   eax, 4
    je    pcon
    mov   esi, discontlen-discontt
    mov   edx, discontt
    mov   ebx, 380*65536+278
  pcon:
    mov   eax, 4
    mov   ecx, [cbtext]
    int   0x40

    ; Echo button

    mov   eax,8
    mov   ebx,460*65536+50
    mov   ecx,273*65536+12+5
    mov   edx,6
    mov   esi, 0x00557799
    int   0x40
    mov   edx,echot
    mov   esi,echolen-echot
    mov   al, [echo]
    cmp   al, 0
    jne   peo
    mov   edx,echoot
    mov   esi,echoolen-echoot
  peo:
    mov   eax,4
    mov   ebx,462*65536+276+2
    mov   ecx,0x000000;[cbtext]
    int   0x40

    ; Clear text area

    xor   eax,eax
    mov   edi,text+80*30
    mov   ecx,80*30 /4
    cld
    rep   stosd

    call  draw_text

    mov   r14 , textbox1
    call  draw_textbox
    mov   r14 , textbox2
    call  draw_textbox

    mov   eax,12
    mov   ebx,2
    int   0x40

    popa

    ret


draw_text:

    pusha

    mov   rax , 141
    mov   rbx , 1
    mov   rcx , 255
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    mov   esi,text
    mov   eax,0
    mov   ebx,0
  newletter:
    mov   cl,[esi]
    cmp   cl , ' '
    jbe   yesletter
    cmp   cl,[esi+30*80]
    jne   yesletter
    jmp   noletter
  yesletter:
    mov   [esi+30*80],cl

    ; Background

    pusha
    mov   edx, [wcolor]
    mov   ecx, ebx
    add   ecx, 26+2
    shl   ecx, 16
    mov   cx, 10
    mov   ebx, eax
    add   ebx, 6+2
    shl   ebx, 16
    mov   bx, 6
    mov   eax, 13
    int   0x40
    popa

    ; Draw character

    pusha
    mov   ecx, [ctext]
    push  bx
    mov   ebx,eax
    add   ebx,6+2
    shl   ebx,16
    pop   bx
    add   bx,26+3
    mov   eax,4
    mov   edx,esi
    mov   esi,1
    int   0x40
    popa

  noletter:

    add   esi,1
    add   eax,6
    cmp   eax,80*6
    jb    newletter
    mov   eax,0
    add   ebx,10
    cmp   ebx,24*10
    jb    newletter

    mov   rax , 141
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    popa
    ret


; Data area

textbox1:

    dq    0         ; Type
    dq    50        ; X position
    dq    126       ; X size
    dq    273       ; Y position
    dq    1001      ; Button ID
    dq    13        ; Current text length
ipstring:
    db    'telnet.server'
    times 50 db 0   ; Text

textbox2:

    dq    0         ;
    dq    213       ;
    dq    5*6+6     ;
    dq    273       ;
    dq    1002      ;
    dq    2         ;
portstring:
    db    '23'
    times 50 db 0   ;


telnetrep       db   0xff,0xfc,0x00
telnetstate     db   0

string_length   dd   16
string_x        dd   200
string_y        dd   60
string          db   '________________'

tx_buff         db   0, 10
ip_address      db   001,002,003,004
port            dq   23
echo            db   1
socket          dd   0x0
socket_status   dd   0x0
pos             dd   80 * 1
scroll          dd   1
                dd   24
wcolor          dd   0x000000
cbtext          dd   0
ctext           dd   0xffffff
cbar            dd   0xa0a0a0

rawbuffer:      times 256 db ?
rawbufferpos:   dq   0x0

window_label:   db   'TELNET',0
setipt          db   'Server:'
setiplen:
setportt        db   'Port:'
setportlen:
cont            db   'Connect'
conlen:
dist            db   'Disconnect'
dislen:
contt           db   'Connected(raw)'
contlen:
contel          db   'Connected(tel)'
contellen:
discontt        db   'Disconnected'
discontlen:
echot           db   'Echo On'
echolen:
echoot          db   'Echo Off'
echoolen:

text:

I_END:

