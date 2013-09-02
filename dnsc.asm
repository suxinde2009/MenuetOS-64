;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;    DNS Domain name -> IP lookup
;
;    Compile with FASM for Menuet
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;  If you like, you can change the DNS server default by changing the
;  IP address in the dnsServer string.
;  Enabling debugging puts the received response to the
;  debug board

DEBUGGING_ENABLED           equ     1
DEBUGGING_DISABLED          equ     0
DEBUGGING_STATE             equ     DEBUGGING_DISABLED

macro pusha { push  rax rbx rcx rdx rsi rdi }
macro popa  { pop  rdi rsi rdx rcx rbx rax  }

use64

    org   0x0

    db    'MENUET64'              ; Header identifier
    dq    0x01                    ; Version
    dq    START                   ; Start of code
    dq    I_END                   ; Size of image
    dq    0x400000                ; Memory for app
    dq    0x3ffff0                ; Rsp
    dq    0x00                    ; Prm
    dq    0x00                    ; Icon

include 'textbox.inc'

START:

    mov   rax , 141
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    mov   dword [prompt], p1
    mov   dword [promptlen], p1len - p1   ; Waiting for command

    call  draw_window                     ; At first, draw the window

still:

    mov   eax,10                          ; Wait here for event
    int   0x40

    cmp   eax,1                           ; Redraw request
    jz    red
    cmp   eax,2                           ; Key in buffer
    jz    key
    cmp   eax,3                           ; Button in buffer
    jz    button

    jmp   still

red:                            ; Redraw
    call  draw_window
    jmp   still

key:                            ; Keys are not valid at this part of the
    mov   eax,2                 ; loop. Just read it and ignore
    int   0x40
    jmp   still

button:                         ; Button
    mov   eax,17                ; Get id
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
    jmp   still
  notb2:

    cmp   ah,1                  ; Button id=1
    jnz   noclose

    ; Close socket before exiting

    mov   eax, 53
    mov   ebx, 1
    mov   ecx, [socketNum]
    int   0x40

    mov   eax,0xffffffff        ; Close this program
    int   0x40

  noclose:

    cmp   ah,3                  ; Resolve address
    jnz   noresolve

    mov   dword [prompt], p5
    mov   dword [promptlen], p5len - p5   ; Resolving
    call  draw_window

    call  translateData         ; Convert domain & DNS IP address

    call  resolveDomain

    jmp   still

  noresolve:

    jmp   still



;***************************************************************************
;   Function
;      translateData
;
;   Description
;      Coverts the domain name and DNS IP address typed in by the user into
;      a format suitable for the IP layer.
;
;    The ename, in query, is converted and stored in dnsMsg
;      The DNS ip, in dnsServer, is converted and stored in dnsIP
;
;***************************************************************************
translateData:

    ; First, get the IP address of the DNS server
    ; Then, build up the request string.

    xor   eax, eax
    mov   dh, 10
    mov   dl, al
    mov   [dnsIP], eax

    mov   esi, dnsServer
    mov   edi, dnsIP

    mov   ecx, 4
  td003:
    lodsb
    sub   al, '0'
    add   dl, al
    lodsb
    cmp   al, '.'
    je    ipNext
    cmp   al, ' '
    jbe   ipNext
    mov   dh, al
    sub   dh, '0'
    mov   al, 10
    mul   dl
    add   al, dh
    mov   dl, al
    lodsb
    cmp   al, '.'
    je    ipNext
    cmp   al, ' '
    jbe   ipNext
    mov   dh, al
    sub   dh, '0'
    mov   al, 10
    mul   dl
    add   al, dh
    mov   dl, al
    lodsb

  ipNext:
    mov   [edi], dl
    inc   edi
    mov   dl, 0
    loop  td003

    ; Build the request string
    mov   eax, 0x00010100
    mov   [dnsMsg], eax
    mov   eax, 0x00000100
    mov   [dnsMsg+4], eax
    mov   eax, 0x00000000
    mov   [dnsMsg+8], eax

    ; Domain name goes in at dnsMsg+12

    mov   esi, dnsMsg + 12         ; Location of label length
    mov   edi, dnsMsg + 13         ; Label start
    mov   edx, query
    mov   ecx, 12                  ; Total string length so far

  td002:
    mov   [esi], byte 0
    inc   ecx

  td0021:
    mov   al, [edx]
    cmp   al, ' '
    jbe   td001                   ; We have finished the string translation
    cmp   al, '.'                 ; Finished the label
    je    td004

    inc   byte [esi]
    inc   ecx
    mov   [edi], al
    inc   edi
    inc   edx
    jmp   td0021

  td004:
    mov   esi, edi
    inc   edi
    inc   edx
    jmp   td002

    ; Write label len+label text

  td001:
    mov   [edi], byte 0
    inc   ecx
    inc   edi
    mov   [edi], dword 0x01000100
    add   ecx, 4

    mov   [dnsMsgLen], ecx

    ret


;***************************************************************************
;   Function
;      resolveDomain
;
;   Description
;       Sends a question to the dns server
;       works out the IP address from the response from the DNS server
;
;***************************************************************************
resolveDomain:

    ; Get a free port number

    mov   ecx, 1000           ; Local port starting at 1000

  getlp:
    inc   ecx
    push  rcx
    mov   eax, 53
    mov   ebx, 9
    int   0x40
    pop   rcx
    cmp   eax, 0              ; Is this local port in use ?
    jz    getlp               ; Yes - so try next

    ; First, open socket

    mov   eax, 53
    mov   ebx, 0
    mov   edx, 53             ; Remote port - dns
    mov   esi, [dnsIP]
    int   0x40

    mov   [socketNum], eax

    ; Write to socket ( request DNS lookup )

    mov   eax, 53
    mov   ebx, 4
    mov   ecx, [socketNum]
    mov   edx, [dnsMsgLen]
    mov   esi, dnsMsg
    int   0x40

    ; Setup the DNS response buffer

    mov   eax, dnsMsg
    mov   [dnsMsgLen], eax

    ; now, we wait for
    ; UI redraw
    ; UI close
    ; or data from remote

ctr001:

    mov   eax , 23               ; Wait
    mov   ebx , 1
    int   0x40

    cmp   eax,1                  ; Redraw request
    je    ctr003
    cmp   eax,2                  ; Key in buffer
    je    ctr004
    cmp   eax,3                  ; Button in buffer
    je    ctr005

    ; Any data in the UDP receive buffer?

    mov   eax, 53
    mov   ebx, 2
    mov   ecx, [socketNum]
    int   0x40

    cmp   eax, 0
    je    ctr001

    ; We have data - this will be the response

ctr002:

    mov   eax, 53
    mov   ebx, 3
    mov   ecx, [socketNum]
    int   0x40                ; Read byte - block (high byte)

    ; Store the data in the response buffer

    mov   eax, [dnsMsgLen]
    mov   [eax], bl
    inc   dword [dnsMsgLen]

if DEBUGGING_STATE = DEBUGGING_ENABLED

    call debug_print_rx_ip

end if

    mov   eax, 53
    mov   ebx, 2
    mov   ecx, [socketNum]
    int   0x40                ; Any more data ?

    cmp   eax, 0
    jne   ctr002              ; Yes, so get it

    ; close socket
    mov   eax, 53
    mov   ebx, 1
    mov   ecx, [socketNum]
    int   0x40

    mov   [socketNum], dword 0xFFFF

    ; Now parse the message to get the host IP
    ; Man, this is complicated. It's described in
    ; RFC 1035

    ; 1) Validate that we have an answer with > 0 responses
    ; 2) Find the answer record with TYPE 0001 ( host IP )
    ; 3) Finally, copy the IP address to the display
    ; Note: The response is in dnsMsg
    ;       The end of the buffer is pointed to by [dnsMsgLen]

    ; Clear the IP address text

    mov   [hostIP], dword 0

    mov   esi, dnsMsg

    ; Is this a response to my question ?

    mov   al, [esi+2]
    and   al, 0x80
    cmp   al, 0x80
    jne   ctr002a

    ; Were there any errors ?

    mov   al, [esi+3]
    and   al, 0x0F
    cmp   al, 0x00
    jne   ctr002a

    ; Is there (at least 1) answer ?

    mov   ax, [esi+6]
    cmp   ax, 0x00
    je    ctr002a

    ; Header validated. Scan through and get my answer

    add   esi, 12             ; Skip to the question field

    ; Skip through the question field

    call  skipName
    add   esi, 4              ; Skip past the questions qtype, qclass

  ctr002z:

    ; Now at the answer. There may be several answers,
    ; find the right one ( TYPE = 0x0001 )

    call  skipName
    mov   ax, [esi]
    cmp   ax, 0x0100          ; Is this the IP address answer ?
    jne   ctr002c

    ; Yes! Point esi to the first byte of the IP address

    add   esi, 10

    mov   eax, [esi]
    mov   [hostIP], eax
    jmp   ctr002a             ; And exit...

  ctr002c:                    ; Skip through the answer, move to the next

    add   esi, 8
    movzx eax, byte [esi+1]
    mov   ah, [esi]
    add   esi, eax
    add   esi, 2

    ; Have we reached the end of the msg?
    ; This is an error condition, should not happen

    cmp   esi, [dnsMsgLen]
    jl    ctr002z             ; Check next answer
    jmp   ctr002a             ; Abort

  ctr002a:

    mov   dword [prompt], p4  ; Display IP address
    mov   dword [promptlen], p4len - p4

    call  draw_window

    jmp   ctr001

  ctr003:                     ; Redraw

    call  draw_window

    jmp   ctr001

  ctr004:                     ; Key

    mov   eax,2               ; Just read it and ignore
    int   0x40

    jmp   ctr001

  ctr005:                     ; Button

    mov   eax,17              ; Get id
    int   0x40

    ; Close socket

    mov   eax, 53
    mov   ebx, 1
    mov   ecx, [socketNum]
    int   0x40

    mov   [socketNum], dword 0xFFFF
    mov   [hostIP], dword 0

    mov   dword [prompt], p1
    mov   dword [promptlen], p1len - p1   ; Waiting for command

    call  draw_window                     ; Draw the window

    ret


;***************************************************************************
;   Function
;      skipName
;
;   Description
;       Increment esi to the first byte past the name field
;       Names may use compressed labels. Normally do.
;       RFC 1035 page 30 gives details
;
;***************************************************************************
skipName:

    mov   al, [esi]
    cmp   al, 0
    je    sn_exit
    and   al, 0xc0
    cmp   al, 0xc0
    je    sn001

    movzx eax, byte [esi]
    inc   eax
    add   esi, eax
    jmp   skipName

  sn001:
    add   esi, 2   ;  A pointer is always at the end
    ret

  sn_exit:
    inc   esi
    ret


draw_window:

    mov   eax,12
    mov   ebx,1
    int   0x40

    mov   rax , 0x0
    mov   rbx,  80*0x100000000+300
    mov   rcx,  80*0x100000000+150+2
    mov   rdx , 0xFFFFFF
    mov   r8  , 0x1
    mov   r9  , window_label
    mov   r10 , 0
    int   0x60

    mov   r14 , textbox1
    call  draw_textbox
    mov   r14 , textbox2
    call  draw_textbox

    mov   eax,8
    mov   ebx,20*65536+190
    mov   ecx,89*65536+17+2
    mov   edx,3
    mov   esi,0x557799
    int   0x40

    ; Copy the prompt to the screen buffer

    mov   esi,[prompt]
    mov   edi,text+206
    mov   ecx,[promptlen]
    cld
    rep   movsb

    mov   ebx,25*65536+40
    mov   ecx,0x000000
    mov   edx,text+1
    mov   esi,40
  newline:
    mov   eax,4
    int   0x40
    add   ebx,20
    add   edx,41
    cmp   [edx-1],byte '.'
    jne   nodot
    sub   ebx , 5
  nodot:
    cmp   [edx-1],byte 'x'
    jnz   newline

    ; Write the host IP, if we have one

    mov   eax, [hostIP]
    cmp   eax, 0
    je    dw001

    ; We have an IP address... display it

    mov   edi,hostIP
    mov   edx,97*65536+125
    mov   esi,0x000000
    mov   ebx,3*65536
  ipdisplay:
    mov   eax,47
    movzx ecx,byte [edi]
    int   0x40
    add   edx,6*4*65536
    inc   edi
    cmp   edi,hostIP+4
    jb    ipdisplay

  dw001:
    mov   eax,12
    mov   ebx,2
    int   0x40

    ret


if DEBUGGING_STATE = DEBUGGING_ENABLED
;***************************************************************************
;    Function
;       debug_print_string
;
;   Description
;       prints a string to the debug board
;
;       esi holds ptr to msg to display
;
;       Nothing preserved; I'm assuming a pusha/popa is done before calling
;
;***************************************************************************
debug_print_string:

    mov   cl, [esi]
    cmp   cl, 0
    jnz   dps_001
    ret

  dps_001:
    mov   eax,63
    mov   ebx, 1
    push  rsi
    int   0x40

    inc   word [ind]
    mov   ax, [ind]
    and   ax, 0x1f
    cmp   ax, 0
    jne   ds1

    mov   cl, 13
    mov   eax,63
    mov   ebx, 1
    int   0x40
    mov   cl, 10
    mov   eax,63
    mov   ebx, 1
    int   0x40

  ds1:
    pop   rsi
    inc   esi
    jmp   debug_print_string

ind: dw 0
; This is used for translating hex to ASCII for display or output
hexchars db '0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F'
IP_STR   db 'xx',0

debug_print_rx_ip:

    pusha
    mov   edi, IP_STR

    xor   eax, eax
    mov   al, bl
    shr   al, 4
    mov   ah, [eax + hexchars]
    mov   [edi], ah
    inc   edi

    xor   eax, eax
    mov   al, bl
    and   al, 0x0f
    mov   ah, [eax + hexchars]
    mov   [edi], ah
    mov   esi, IP_STR

    call  debug_print_string
    popa
    ret

end if

; Data area

text:

    db ' Host name  :                            '
    db ' DNS server :                            '
    db '.                                        '
    db '      RESOLVE ADDRESS                    '
    db '.                                        '
    db '.                                        '
    db 'x  <- END MARKER, DONT DELETE            '

window_label:

    db   'DNS CLIENT',0

textbox1:

    dq    0         ; Type
    dq    101       ; X position
    dq    170       ; X size
    dq    35        ; Y position
    dq    1001      ; Button ID
    dq    16        ; Current text length
  query:
    db    'WWW.MENUETOS.NET'
    times 50 db 32   ; Text
    db    0

textbox2:

    dq    0         ;
    dq    101       ;
    dq    170       ;
    dq    55        ;
    dq    1002      ;
    dq    13        ;
  dnsServer:
    db    '192.168.0.254'
    times 50 db 32
    db    0

p1:     db  'Waiting for Command        '
p1len:
p4:     db  'IP Address:    .   .   .   '
p4len:
p5:     db  'Resolving...               '
p5len:

prompt:     dd  0
promptlen:  dd  0
addr        dd  0
ya          dd  0

hostIP:     dd  0
dnsIP:      dd  0
dnsMsgLen:  dd  0
socketNum:  dd  0xFFFF
dnsMsg:

I_END:

