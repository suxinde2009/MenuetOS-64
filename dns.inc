;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;    DNS Domain name - IP lookup
;
;    Compile with FASM for Menuet
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use64

get_ip:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   In :  rsi  - Pointer to asciiz server string
;
;   Out: [rdi] - Resolved IP or Zero for error
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   [rsi_save],rsi
    mov   [rdi_save],rdi

    ; Is the address already in numerical IP form ?

    mov   r14 , rdi
    add   r14 , 4
  desl4:
    mov   rax , 0
  desl5:
    movzx rbx , byte [rsi]
    cmp   bl , '0'
    jb    desl6
    cmp   bl , '9'
    ja    desl7
    imul  rax , 10
    sub   rbx , 48
    add   rax , rbx
    inc   rsi
    jmp   desl5
  desl6:
    inc   rsi
    mov   [rdi],al
    inc   rdi
    cmp   rdi , r14
    jb    desl4
    ret
  desl7:

    ; Fetch IP address from server

    call  dtranslateData         ; Convert domain & DNS IP address

    call  dresolveDomain

    ret


rsi_save: dq 0x0
rdi_save: dq 0x0


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
dtranslateData:

    ; Move data and convert to uppercase

    mov   rdi , query
    mov   rcx , 50
  newmove:
    mov   al , [rsi]
    cmp   al , 96
    jbe   alfine
    sub   al , 32
  alfine:
    mov   [rdi],al
    cmp   al , 32
    jbe   dmovedone
    inc   rsi
    inc   rdi
    loop  newmove
  dmovedone:

    ; Clear return data

    mov   [hostIP], dword 0

    ; Get the IP address of the DNS server

    mov   eax , 52
    mov   ebx , 13
    int   0x40
    mov   [dnsIP],eax

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

  dtd002:
    mov   [esi], byte 0
    inc   ecx

  dtd0021:
    mov   al, [edx]

    cmp   al, ' '
    jbe   dtd001                  ; We have finished the string translation
    cmp   ecx , 200
    ja    dtd001

    cmp   al, '.'                 ; Finished the label
    je    td004

    inc   byte [esi]
    inc   ecx
    mov   [edi], al
    inc   edi
    inc   edx
    jmp   dtd0021

  td004:
    mov   esi, edi
    inc   edi
    inc   edx
    jmp   dtd002

    ; Write label len+label text

  dtd001:
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
dresolveDomain:

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

    mov   [dsocketNum], eax

    ; Wait for open

    mov   rax , 5
    mov   rbx , 5
    int   0x60

    ; Write to socket ( request DNS lookup )

    mov   eax, 53
    mov   ebx, 4
    mov   ecx, [dsocketNum]
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

    mov   r12 , 0

dctr001:

    ; Timeout

    inc   r12
    cmp   r12 , 100*10
    ja    ctrexit
    mov   eax , 5
    mov   ebx , 1
    int   0x40

    ; Events

    mov   eax , 11
    int   0x40

    cmp   eax,1                  ; Redraw request
    je    dctr003
    cmp   eax,2                  ; Key in buffer
    je    dctr004
    cmp   eax,3                  ; Button in buffer
    je    dctr005

    ; Any data in the UDP receive buffer?

    mov   eax, 53
    mov   ebx, 2
    mov   ecx, [dsocketNum]
    int   0x40

    ; No -> wait more

    cmp   eax, 0
    je    dctr001

    ; We have data - this will be the response

    mov   rax , 5 ; Wait for packets
    mov   rbx , 10
    int   0x60

dctr002:

    ; Read data

    mov   eax, 53
    mov   ebx, 3
    mov   ecx, [dsocketNum]
    int   0x40                ; Read byte - block (high byte)

    ; Store the data in the response buffer

    mov   eax, [dnsMsgLen]
    cmp   eax , dnsMsg+900
    ja    nodnsadd
    mov   [eax], bl
    inc   dword [dnsMsgLen]
  nodnsadd:

    mov   eax, 53
    mov   ebx, 2
    mov   ecx, [dsocketNum]
    int   0x40                ; Any more data ?

    cmp   eax, 0
    jne   dctr002              ; Yes, so get it

    ; Now parse the message to get the host IP
    ; Man, this is complicated. It's described in
    ; RFC 1035

    ; 1) Validate that we have an answer with > 0 responses
    ; 2) Find the answer record with TYPE 0001 ( host IP )
    ; 3) Finally, copy the IP address to the display
    ; Note: The response is in dnsMsg
    ;       The end of the buffer is pointed to by [dnsMsgLen]

    ; Clear the IP address

    mov   [hostIP], dword 0

    mov   esi, dnsMsg

    ; Is this a response to my question ?

    mov   al, [esi+2]
    and   al, 0x80
    cmp   al, 0x80
    jne   ctrexit

    ; Were there any errors ?

    mov   al, [esi+3]
    and   al, 0x0F
    cmp   al, 0x00
    jne   ctrexit

    ; Is there ( at least 1 ) answer ?

    mov   ax, [esi+6]
    cmp   ax, 0x00
    je    ctrexit

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

    jmp   ctrexit             ; And exit...

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

    jmp   ctrexit             ; Abort

    ;
    ; Events
    ;

    ; Redraw

  dctr003:

    jmp   ctrexit

    ; Key

  dctr004:

    mov   eax,2    ; Read and ignore
    int   0x40

    jmp   ctrexit

    ; Button

  dctr005:

    mov   eax,17   ; Get id
    int   0x40

    jmp   ctrexit

  ctrexit:

    ; Close socket

    mov   eax, 53
    mov   ebx, 1
    mov   ecx, [dsocketNum]
    int   0x40

    mov   [dsocketNum], dword 0xFFFF

    mov   eax , [hostIP]
    mov   rdi , [rdi_save]
    mov   [rdi],eax

    mov   rax , 5
    mov   rbx , 50
    int   0x60

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


query         db  '                                                        '
hostIP:       dq  0
dnsIP:        dq  0
dnsMsgLen:    dq  0
dsocketNum:   dq  0xFFFF
dnsMsg:       times 1024 db 0

