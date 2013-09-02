;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   FTP client for Menuet64
;
;   (c) Ville Turjanmaa
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use64

    org   0x0

    db    'MENUET64'              ; Header identifier
    dq    0x01                    ; Version
    dq    START                   ; Start of code
    dq    image_end               ; Size of image
    dq    0x500000                ; Memory for app
    dq    0xffff0                 ; Esp
    dq    0x00                    ; Prm
    dq    0x00                    ; Icon

include 'dns.inc'

START:

    mov   rax , 141
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    mov   rax , 0
    mov   [blocksize],rax
    mov   rax , tcpipblock
    mov   [blockpos],rax

    call  set_help

    call  draw_window       ; At first, draw the window

still:

    mov   rax , 23          ; Wait here for event
    mov   rbx , 10
    int   0x60

    test  rax , 0x1         ; Window redraw
    jnz   window_event
    test  rax , 0x2         ; Keyboard press
    jnz   key_event
    test  rax , 0x4         ; Button press
    jnz   button_event

    mov   [read_input_delay],dword 10
    call  read_input

    jmp   still

window_event:

    call  draw_window
    jmp   still

key_event:

    mov   rax , 0x2        ; Read the key and ignore
    int   0x60

    test  rbx , 1
    jnz   still

    cmp   ecx , 'Ente'
    je    enterpressed

    cmp   ecx , 'Back'
    jne   noback

    cmp   [cursor],dword 2
    jbe   still

    sub   [cursor],dword 1
    mov   rax , [cursor]
    mov   [text+25*81+rax],byte ' '
    call  draw_text_lastline
    jmp   still

  noback:

    cmp   rbx , 0
    jne   still

    mov   rax , [cursor]

    cmp   rax , 2
    jae   nostill
    call  scroll
    jmp   commandexit
  nostill:

    mov   [text+25*81+rax],cl

    inc   qword [cursor]

    call  draw_text_lastline

    jmp   still


set_help:

    mov   rdi , text
    mov   rcx , 25*81
    mov   rax , 0
    cld
    rep   stosb

    mov   rdi , text+10*81
    mov   rsi , helptext
    mov   rcx , 81*16
    cld
    rep   movsb

    ret


send_next_port:

    push  rax rbx rcx rdx rsi rdi

    mov   [cursor],dword 0
    call  scroll

    ; ; Passive data connection
    ;
    ; inc   qword [dataport]
    ; and   dword [dataport],0xfeff
    ; mov   rax , [dataport]
    ; and   rax , 0xff
    ; mov   rdi , portstring+27
    ; call  decodenumber
    ; mov   rax , 52
    ; mov   rbx , 1
    ; int   0x60
    ; mov   rdi , portstring+07
    ; call  decodenumber
    ; shr   rax , 8
    ; add   rdi , 4
    ; call  decodenumber
    ; shr   rax , 8
    ; add   rdi , 4
    ; call  decodenumber
    ; shr   rax , 8
    ; add   rdi , 4
    ; call  decodenumber
    ; mov   rax , 53
    ; mov   rbx , 7
    ; mov   rcx , [socket]
    ; mov   rdx , portstringend - portstring
    ; mov   rsi , portstring
    ; int   0x60

    ; Active data connection

    mov   rax , 53
    mov   rbx , 7
    mov   rcx , [socket]
    mov   rdx , pasvstringend - pasvstring
    mov   rsi , pasvstring
    int   0x60

    mov   [read_input_delay],dword 2000
    call  read_input
    call  draw_text

    ; Parse parameters

    cmp   [text+81*24],dword '227 '
    jne   nofoundl1

    ; Scan to '('

    mov   rbx , text+81*24
  scanl1:
    cmp   [rbx],byte '('
    je    foundl1
    inc   rbx
    cmp   rbx , text+81*25
    jb    scanl1
    jmp   nofoundl1
  foundl1:

    ; Parameters

    mov   rdi , parameters

  scantoparameter:

    mov   rcx , 0
  scanl3:
    inc   rbx
    ;
    cmp   [rbx],byte 13
    jbe   foundl3
    ;
    cmp   [rbx],byte ')'
    je    foundl3
    cmp   [rbx],byte ','
    je    foundl3
    ;
    cmp   [rbx],byte '0'
    jb    foundl3
    cmp   [rbx],byte '9'
    ja    foundl3
    ;
    movzx rdx , byte [rbx]
    sub   rdx , 48
    imul  rcx , 10
    add   rcx , rdx
    jmp   scanl3
  foundl3:

    mov   [rdi],rcx

    mov   rcx , 0

    add   rdi , 8
    cmp   rdi , parameters+6*8
    jb    scantoparameter

  scandone:

    xor   rcx , rcx
    mov   cl , [parameters+5*8]
    mov   ch , [parameters+4*8]
    mov   [dataport],rcx

    xor   rcx , rcx
    mov   ch , [parameters+3*8]
    mov   cl , [parameters+2*8]
    shl   rcx , 16
    mov   ch , [parameters+1*8]
    mov   cl , [parameters+0*8]
    mov   [dataip],rcx

    ; mov   rax , 47
    ; mov   rbx , 6*65536
    ; mov   rcx , rcx
    ; mov   rdx , 200 shl 32 + 24
    ; mov   rsi , 0x000000
    ; int   0x60

  nofoundl1:

    pop   rdi rsi rdx rcx rbx rax

    ret



openDataConnection:

    push  rax rbx rcx rdx rsi rdi

    mov   rax , 53
    mov   rbx , 5
    mov   rcx , [datalocalport]
    mov   rdx , [dataport]
    mov   rsi , [dataip]
    mov   rdi , 1 ; active
    int   0x60

    mov   [socket_data],rax

    mov   rdx , 0
  waitfordataopenc:
    mov   rax , 105
    mov   rbx , 1
    int   0x60
    inc   rdx
    cmp   rdx , 1000*20
    ja    dataopentimeoutc
    mov   rax , 53
    mov   rbx , 6
    mov   rcx , [socket_data]
    int   0x60
    cmp   rax , 4
    jb    waitfordataopenc
  dataopentimeoutc:

    pop   rdi rsi rdx rcx rbx rax

    mov   [datacount],dword 0

    ret



closedataconnection:

    push  rax rbx rcx rdx rsi rdi

    mov   rax , 53
    mov   rbx , 8
    mov   rcx , [socket_data]
    int   0x60

    pop   rdi rsi rdx rcx rbx rax

    ret


analyze:

    ; Remove leading spaces

  asl0:
    cmp   [command],byte ' '
    jne   asl1
    mov   rdi , command
    mov   rsi , command + 1
    mov   rcx , 250
    cld
    rep   movsb
    jmp   asl0
  asl1:

    ; To uppercase

    mov   rsi , command-1
  al0:
    inc   rsi
    cmp   [rsi],byte ' '
    jbe   al1
    cmp   [rsi],byte 97
    jb    al0
    sub   [rsi],byte 32
    jmp   al0
  al1:

    ; GET -> RETR

    cmp   [command],dword 'GET '
    jne   noget

    mov   rdi , command+1+240
    mov   rsi , command+240
    mov   rcx , 240
    std
    rep   movsb
    cld

    mov   [command],dword 'RETR'

    inc   dword [cursor]

  noget:

    ; LS -> LIST

    cmp   [command], word 'LS'
    jne   nols

    mov   rdi , command+2+240
    mov   rsi , command+240
    mov   rcx , 240
    std
    rep   movsb
    cld

    mov   [command],dword 'LIST'

    add   dword [cursor],2

  nols:

    ; DIR -> LIST

    cmp   [command], word 'DI'
    jne   nodir
    cmp   [command+2], byte 'R'
    jne   nodir

    mov   rdi , command+1+240
    mov   rsi , command+240
    mov   rcx , 240
    std
    rep   movsb
    cld

    mov   [command],dword 'LIST'

    add   dword [cursor],1

  nodir:

    ; FTP -> OPEN

    cmp   [command], word 'FT'
    jne   noftp
    cmp   [command+2], byte 'P'
    jne   noftp

    mov   rdi , command+1+240
    mov   rsi , command+240
    mov   rcx , 240
    std
    rep   movsb
    cld

    mov   [command],dword 'OPEN'

    add   dword [cursor],1

  noftp:

    ; DEL -> DELE

    cmp   [command], dword 'DEL '
    jne   nodel

    mov   rdi , command+1+240
    mov   rsi , command+240
    mov   rcx , 240
    std
    rep   movsb
    cld

    mov   [command],dword 'DELE'

    add   dword [cursor],1

  nodel:

    ; SEND -> STOR

    cmp   [command],dword 'SEND'
    jne   nosend

    mov   [command],dword 'STOR'

  nosend:

    mov   rax , [command]
    and   rax , 0xffffff
    cmp   rax , 'BIN'
    jne   nobin

    mov   rax , 'TYPE I'
    mov   [command],rax

    add   [cursor],dword 3

  nobin:

    mov   rax , [command]
    and   rax , 0xffffff
    cmp   rax , 'CD '
    jne   nocd

    mov   rdi , command+1+240
    mov   rsi , command+240
    mov   rcx , 240
    std
    rep   movsb
    cld

    mov   [command],dword 'CWD '

    add   [cursor],dword 1

  nocd:

    ret


enterpressed:

    mov   rsi , text+81*25+2
    mov   rdi , command
    mov   rcx , 200
    cld
    rep   movsb

    ;
    ; Analyze the command
    ;

    call  analyze

    ;
    ; Exit
    ;

    cmp   [command],dword 'EXIT'
    jne   noexit
    call  scroll
  startexit:
    cmp   [status],byte 0
    je    doexit
    cmp   [cursor],dword 0
    je    noscroll2
    call  scroll
  noscroll2:
    mov   [text+81*25+00], dword 'Conn'
    mov   [text+81*25+04], dword 'ecti'
    mov   [text+81*25+08], dword 'on o'
    mov   [text+81*25+12], dword 'pen.'
    call  scroll
    call  draw_text
    jmp   commandexit
  doexit:

    cmp   [status],byte 1
    jne   noclose2

    call  close_connection
    mov   rax , 5
    mov   rbx , 20
    int   0x60

  noclose2:

    mov   rax , 512
    int   0x60
  noexit:

    ;
    ; Help
    ;

    cmp   [command],dword 'HELP'
    jne   nohelp
    call  set_help
    jmp   commandexit
  nohelp:

    ;
    ; Open
    ;

    cmp   [command],dword 'OPEN'
    jne   noopen

    cmp   [status],byte 1
    jne   doopen
    call  scroll
    call  draw_text
    jmp   commandexit
  doopen:

    call  scroll

    mov   rsi , command+5
    call  decode

    cmp   [ip],dword 0
    je    exitopen

    mov   rax , 3
    mov   rbx , 1
    int   0x60
    mov   rcx , rax
    shr   rcx , 16
    and   rcx , 0xff
    add   rcx , 2048 ; local port

    mov   [datalocalport],rcx
    inc   dword [datalocalport]   ; dataport = commandport+1
    mov   rdi , [ip]
    mov   [dataip],rdi            ; same ip by default

    mov   rax , 53
    mov   rbx , 5
    mov   rdx , 21
    mov   rsi , [ip]
    mov   rdi , 1 ; active
    int   0x60

    mov   [socket],rax

    ; Wait for open

    mov   r8  , 0

  wait_for_open:

    inc   r8
    cmp   r8 , 200
    jb    waitmore ; timeout
  exitopen:
    mov   [text+81*25+00], dword 'Fail'
    mov   [text+81*25+04], dword '.   '
    call  scroll
    call  draw_text
    jmp   commandexit
  waitmore:

    mov   rax , 5
    mov   rbx , 1
    int   0x60

    mov   rax , 53
    mov   rbx , 6
    mov   rcx , [socket]
    int   0x60
    cmp   rax , 4
    jne   wait_for_open

    mov   [status],byte 1

    ; Read possible response

    mov   [read_input_delay],dword 2000
    call  read_input

    ; Welcome text -> send username / password

    cmp   [text+81*24], word '22'
    jne   commandexit
    cmp   [text+81*24+2], byte '0'
    jne   commandexit

    mov   rax , 'Username'
    mov   [text+81*25],rax
    mov   rax , ': '
    mov   [text+81*25+8],rax
    mov   [cursor],dword 10
    call  draw_text

    mov   [showtext],byte 1
    call  readstring

    call  scroll

    ; Send username

    mov   rax , 53
    mov   rbx , 7
    mov   rcx , [socket]
    mov   rdx , command_user_end-command_user
    mov   rsi , command_user
    int   0x60
    mov   rax , 53
    mov   rbx , 7
    mov   rcx , [socket]
    mov   rdx , [command_str_len]
    mov   rsi , command_str
    int   0x60
    mov   rax , 53
    mov   rbx , 7
    mov   rcx , [socket]
    mov   rdx , 2
    mov   rsi , command_lf
    int   0x60

    ; Read possible response

    mov   [read_input_delay],dword 2000
    call  read_input

    cmp   [text+81*24], word '33'
    jne   commandexit
    cmp   [text+81*24+2], byte '1'
    jne   commandexit

    mov   rax , 'Password'
    mov   [text+81*25],rax
    mov   rax , ': '
    mov   [text+81*25+8],rax
    mov   [cursor],dword 10
    call  draw_text

    mov   [showtext],byte 0
    call  readstring

    call  scroll

    ; Send password

    mov   rax , 53
    mov   rbx , 7
    mov   rcx , [socket]
    mov   rdx , command_pass_end-command_pass
    mov   rsi , command_pass
    int   0x60
    mov   rax , 53
    mov   rbx , 7
    mov   rcx , [socket]
    mov   rdx , [command_str_len]
    mov   rsi , command_str
    int   0x60
    mov   rax , 53
    mov   rbx , 7
    mov   rcx , [socket]
    mov   rdx , 2
    mov   rsi , command_lf
    int   0x60

    ; Read possible response

    mov   [read_input_delay],dword 3000
    call  read_input

    jmp   commandexit

  readstring:

    mov   [command_str_len],dword 0

  readmore:

    mov   rax , 10
    int   0x60

    test  rax , 1
    jz    nownd
    call  draw_window
    jmp   readmore
  nownd:

    test  rax , 2
    jz    readover

    mov   rax , 2
    int   0x60

    test  rbx , 1
    jnz   readmore

    cmp   cx , 'En'
    je    readover

    cmp   cx , 'Ba'
    jne   nobackspace
    cmp   [command_str_len],dword 0
    je    readmore
    dec   dword [command_str_len]
    mov   rax , [command_str_len]
    mov   [command_str+rax],byte 0

    cmp   [showtext],byte 1
    jne   noshowtext1

    dec   dword [cursor]
    mov   rax , [cursor]
    mov   [text+81*25+rax],byte 0
    call  draw_text

  noshowtext1:

    jmp   readmore
  nobackspace:

    cmp   rbx , 0
    jne   readmore

    mov   rax , [command_str_len]
    cmp   rax , 50
    ja    readmore
    mov   [command_str+rax],cl
    mov   [command_str+rax+1],byte 0

    cmp   [showtext],byte 1
    jne   noshowtext2

    mov   rax , [cursor]
    mov   [text+81*25+rax],cl
    mov   [text+81*25+rax+1],byte 0
    inc   dword [cursor]
    call  draw_text

  noshowtext2:

    inc   dword [command_str_len]

    jmp   readmore

  readover:

    ret

  noopen:

    ;
    ; Open data port connection
    ;

    mov   rax , [cursor]
    sub   rax , 2
    mov   [command+rax],word 13+256*10

    mov   rax , 53
    mov   rbx , 7
    mov   rcx , [socket]
    mov   rdx , [cursor]

    cmp   rdx , 2
    jg    nocommandexit
    call  scroll
    jmp   commandexit
  nocommandexit:
    cmp   [status],byte 0
    jne   commandfine2
    call  scroll
    call  draw_text
    jmp   commandexit
  commandfine2:

    mov   rsi , command

    cmp   [rsi],dword 'STOR'
    je    openc
    cmp   [rsi],dword 'LIST'
    je    openc
    cmp   [rsi],dword 'RETR'
    jne   noretr1
  openc:

    ; Port to use

    call  send_next_port

    push  rax rbx
    mov   rax , 5
    mov   rbx , 25
    int   0x60
    pop   rbx rax

    ; Send the actual command to server

    int   0x60

    push  rax rbx
    mov   rax , 5
    mov   rbx , 25
    int   0x60
    pop   rbx rax

    ; Open data connection

    call  openDataConnection

    jmp   commandsent

  noretr1:

    ;
    ; Send the actual command to server
    ;

    int   0x60

  commandsent:

    ;
    ; Quit
    ;

    cmp   [command],dword 'QUIT'
    jne   noquit
    call  scroll
    mov   [read_input_delay],dword 1000
    call  read_input
    mov   rax , 5
    mov   rbx , 50
    int   0x60
    call  close_connection
    jmp   commandexit
  noquit:

    ;
    ; List
    ;

    cmp   [command],dword 'LIST'
    jne    nodolist

    mov   [print],byte 1

    mov   [cursor],dword 0
    call  scroll

    mov   r8 , 0

  waitfordataend2:

    mov   rax , 5
    mov   rbx , 1
    int   0x60

    inc   r8
    cmp   r8 , 1000*10
    ja    timeout2

    push  r8
    mov   [read_input_delay],dword 20
    call  read_input
    mov   [read_input_delay],dword 20
    call  read_input_data
    pop   r8

    mov   rax , 53
    mov   rbx , 6
    mov   rcx , [socket_data]
    int   0x60
    cmp   rax , 4
    jbe   waitfordataend2

  timeout2:

    call  closedataconnection

    ; Do not save input

    mov   [print],byte 0

    mov   [read_input_delay],dword 1000
    call  read_input

    call  scroll

    jmp   commandexit

  nodolist:

    ;
    ; Retr
    ;

    cmp   [command],dword 'RETR'
    jne   noretr

    mov   r8 , 0
    mov   r9 , 0x100000

  waitfordataend:

    push  r9
    push  r8
    mov   [read_input_delay],dword 00
    call  read_input
    mov   [read_input_delay],dword 20
    call  read_input_data
    pop   r8
    pop   r9

    cmp   r9 , [datacount]
    je    nozero
    mov   r8 , 0
    mov   r9 , [datacount]
  nozero:

    ; Timeout ?
    inc   r8
    cmp   r8 , (1000*10) / 20
    ja    timeout

    ;mov   rax , 53
    ;mov   rbx , 6
    ;mov   rcx , [socket_data]
    ;int   0x60
    ;cmp   rax , 4
    ;jbe   waitfordataend

    ; 'transfer complete'
    cmp   [text+81*24],dword '226 '
    jne   waitfordataend

    mov   [read_input_delay],dword 200
    call  read_input_data

    call  closedataconnection

    mov   [read_input_delay],dword 2000
    call  read_input

    call  savefile

    call  scroll

    jmp   commandexit

  timeout:

    mov   [text+81*25+00], dword 'Time'
    mov   [text+81*25+04], dword 'out '
    mov   [text+81*25+08], dword 'erro'
    mov   [text+81*25+12], dword 'r.  '
    call  scroll
    call  draw_text

    call  closedataconnection

    mov   [read_input_delay],dword 2000
    call  read_input

    call  scroll

    jmp   commandexit

  noretr:

    ;
    ; Stor
    ;

    cmp   [command],dword 'STOR'
    jne   nostor

    call  openfile

    ; size ok

    mov   r8 , 0

    mov   r9  , 0x100000
    mov   r10 , 0x100000
    add   r10 , [datacount]

  waitfordataopen:

    mov   rax , 5
    mov   rbx , 1
    int   0x60

    mov   rax , 53
    mov   rbx , 6
    mov   rcx , [socket_data]
    int   0x60

    inc   r8
    cmp   r8 , 1000*10
    ja    timeout3

    cmp   rax , 4
    jne   waitfordataopen

  send_data_loop:

    mov   [read_input_delay],dword 50

    push  r9 r10

    call  read_input

    pop   r10 r9

    ; Send file in 512 byte chunks

    mov   r11 , r10
    sub   r11 , r9
    mov   rdx , 512
    cmp   r11 , 512
    jae   rdxfine
    mov   rdx , r11
  rdxfine:

    mov   rax , 53
    mov   rbx , 7
    mov   rcx , [socket_data]
    mov   rsi , r9
    int   0x60

    add   r9  , rdx

    mov   rax , 5
    mov   rbx , 3
    int   0x60

    cmp   r9 , r10
    je    timeout3

    mov   rax , 53
    mov   rbx , 6
    mov   rcx , [socket_data]
    int   0x60

    cmp   rax , 4
    je    send_data_loop

  timeout3:

    mov   rax , 5
    mov   rbx , 50
    int   0x60

    call  closedataconnection

    mov   [read_input_delay],dword 2000
    call  read_input

    call  scroll

    jmp   commandexit

  nostor:

    call  scroll

    mov   [read_input_delay],dword 2000
    call  read_input

  commandexit:

    mov   [cursor],dword 2

    mov   [text+81*25], dword '>   '

    call  draw_text

    jmp   still



close_connection:

    cmp   [status],byte 1
    jne   noclose

    mov   rax , 53
    mov   rbx , 8
    mov   rcx , [socket]
    int   0x60

  noclose:

    mov   [status],byte 0

    ret


decode:

    mov   rdi , ip
    call  get_ip

    ret


    mov   rax , 0
    mov   rdi , ip

  dl1:

    mov   bl , [rsi]
    sub   bl , 48

    imul  rax , 10
    add   al , bl

    inc   rsi

    cmp   [rsi],byte ' '
    jbe   dl22

    cmp   [rsi],byte '.'
    jne   dl1

  dl22:

    mov   [rdi],al
    mov   rax , 0
    inc   rsi
    inc   rdi
    cmp   rdi , ip+4
    jb    dl1

  dl2:

    ret



read_input:

    mov   r8  , 0

  read_more_1:

    mov   rax , 53
    mov   rbx , 2
    mov   rcx , [socket]
    int   0x60

    cmp   rax , 0
    jne   read_more

    inc   r8
    cmp   r8 , [read_input_delay]
    ja    read_end

    mov   rax , 105
    mov   rbx , 1
    int   0x60

    jmp   read_more_1

  read_more:

    mov   rax , 53
    mov   rbx , 3
    mov   rcx , [socket]
    int   0x60

    push  rax
    mov   al , bl
    call  add_letter
    pop   rax

    cmp   rax , 0
    jne   read_more

    jmp   read_more_1

  read_end:

    ret


read_input_data:

    mov   r8  , 0

  data_read_more_1:

    cmp   [blocksize],dword 0
    jne   data_read_more

    mov   rax , 53
    mov   rbx , 2
    mov   rcx , [socket_data]
    int   0x60

    cmp   rax , 0
    jne   data_read_more

    inc   r8
    cmp   r8 , [read_input_delay]
    ja    data_read_end

    mov   rax , 105
    mov   rbx , 1
    int   0x60

    jmp   data_read_more_1

  data_read_more:

    ;mov   rax , 53
    ;mov   rbx , 3
    ;mov   rcx , [socket_data]
    ;int   0x60

    call  read_data_block

    mov   rdx , [datacount]
    mov   [0x100000+rdx],bl
    inc   qword [datacount]

    cmp   [print],byte 1
    jne   noprint2
    push  rax
    mov   al , bl
    call  add_letter
    pop   rax
  noprint2:

    cmp   rax , 0
    jne   data_read_more

    jmp   data_read_more_1

  data_read_end:

    ret


read_data_block:

    cmp   [blocksize],dword 0
    jne   getblockbyte

    push  rdx
    mov   rax , 53
    mov   rbx , 13
    mov   ecx , [socket_data]
    mov   rdx , tcpipblock
    int   0x60
    pop   rdx

    mov   [blocksize],rax
    mov   [blockpos],dword tcpipblock

    cmp   rax , 0
    je    noreadblockbyte

  getblockbyte:

    mov   rbx , [blockpos]
    mov   bl  , [rbx]
    and   rbx , 0xff

    inc   dword [blockpos]
    dec   dword [blocksize]

    mov   rax , [blocksize]

  noreadblockbyte:

    ret



savefile:

    call  set_filename

    mov   rax , 58
    mov   rbx , 2
    mov   r9  , filename
    int   0x60

    mov   rax , 58
    mov   rbx , 1
    mov   rcx , 0
    mov   rdx , [datacount]
    mov   r8  , 0x100000
    mov   r9  , filename
    int   0x60

    ret


openfile:

    call  set_filename

    mov   rax , 58
    mov   rbx , 0
    mov   rcx , 0
    mov   rdx , -1
    mov   r8  , 0x100000
    mov   r9  , filename
    int   0x60

    mov   [datacount],rbx

    ret

set_filename:

    mov   rdi , filename + 6

    mov   rsi , command + 2
  sfl1:
    inc   rsi
    cmp   rsi , command+250
    ja    sfl2
    cmp   [rsi-1],byte ' '
    ja    sfl1

  sfl11:
    cmp   [rsi],byte 32
    jbe   sfl2
    movsb
    jmp   sfl11

  sfl2:
    mov   [rdi],byte 0

    ret


add_letter:

    cmp   al , 13
    jne   noscroll
    call  scroll
    ret
  noscroll:

    cmp   al , 19
    jb    noprint

    mov   rbx , [cursor]

    cmp   rbx , 80
    jb    noscr
    push  rax
    call  scroll
    pop   rax
    mov   rbx , 0
  noscr:

    mov   [text+81*25+rbx],al

    inc   dword [cursor]

  noprint:

    ret


scroll:

    mov   rdi , text
    mov   rsi , text+81
    mov   rcx , 81*25+1
    cld
    rep   movsb

    mov   rdi , text+81*25
    mov   rcx , 81
    mov   rax , 0
    cld
    rep   stosb

    mov   [cursor],dword 0

    call  draw_text

    ret


draw_text_lastline:

    mov   rax , 4
    mov   rbx , text + 25 * 81
    mov   rcx , 6
    mov   rdx , 42 + 17 * 10 -4
    mov   rsi , 0x000000
    mov   r9  , 1
    mov   r10 , 16

    push  rax rbx rcx rdx

    mov   rax , 13
    mov   rbx , rcx
    mov   rcx , rdx
    sub   rcx , 1
    mov   rdx , 0xffffff

    shl   rbx , 32
    shl   rcx , 32

    add   rbx , 80*6
    add   rcx , 1
    add   rcx , [fontsize]

    int   0x60

    pop   rdx rcx rbx rax

    int   0x60

    call  draw_cursor

    ret



draw_text:

    mov   rax , 4
    mov   rbx , text + 81 * 9
    mov   rcx , 6
    mov   rdx , 48
    mov   rsi , 0x000000
    mov   r9  , 1
    mov   r10 , 17

    mov   r15 , 10

    cmp   [fontsize],dword 10
    jne   nofont10
    add   rbx , 81
    dec   r10
    mov   r15 , 11
    mov   rdx , 40+3
  nofont10:
    cmp   [fontsize],dword 11
    jne   nofont11
    add   rbx , 81*2
    dec   r10
    dec   r10
    mov   r15 , 12
    mov   rdx , 40
  nofont11:
    cmp   [fontsize],dword 12
    jne   nofont12
    add   rbx , 81*3
    dec   r10
    dec   r10
    dec   r10
    mov   r15 , 13
    mov   rdx , 40-1
  nofont12:

  newt:

    push  rax rbx rcx rdx

    mov   rax , 13
    mov   rbx , rcx
    mov   rcx , rdx
    mov   rdx , 0xffffff

    dec   rcx

    shl   rbx , 32
    shl   rcx , 32

    add   rbx , 80*6
    add   rcx , 1
    add   rcx , [fontsize]

    int   0x60

    pop   rdx rcx rbx rax

    int   0x60
    add   rbx , 81
    add   rdx , r15
    dec   r10
    jnz   newt

    call  draw_cursor

    ret


draw_cursor:

    mov   rax , 38
    mov   rbx , [cursor]
    imul  rbx , 6
    add   rbx , 6
    mov   rcx , 191
    mov   rcx , 207
    mov   rdx , rbx
    mov   r8  , rcx
    add   r8  , [fontsize]
    mov   r9  , 0x000000
    int   0x60

    ret



button_event:

    mov   rax , 0x11
    int   0x60

    ; rax = status
    ; rbx = button id

    cmp   rbx , 0x10000001
    je    startexit
    cmp   rbx , 0x102
    je    startexit

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
    mov   rbx , 0x0000006000000000+12+80*6   ; x start & size
    mov   rcx , 0x0000006000000000+50+13*14  ; y start & size
    mov   rdx , 0x0000000000FFFFFF           ; type    & border color
    mov   r8  , 0x0000000000000001           ; draw flags
    mov   r9  , window_label                 ; 0 or label - asciiz
    mov   r10 , menu_struct                  ; 0 or pointer to menu struct
    int   0x60

    call  draw_text

    mov   rax , 0xC                          ; End of window draw
    mov   rbx , 0x2
    int   0x60

    ret


; Data area

window_label:

    db    'FTP CLIENT',0  ; Window label

filename: db '/fd/1/'
          times 256 db 0

ip: db 0,0,0,0
    db 0,0,0,0

read_input_delay: dq 1000

socket:      dq 0x0
socket_data: dq 0x0

command: times 256 db 0

datalocalport:  dq 0x0
parameters:     dq 0,0,0,0,0,0,0,0

status: dq 0x0

fontsize:  dq 9
cursor:    dq 2
datacount: dq 0
print:     dq 0

dataport:  dq  16*256
dataip:    dq  192+168 shl 8+123 shl 16+123 shl 24

;portstring: db 'PORT 000,000,000,000,008,000',13,10
;portstringend:

pasvstring: db 'PASV',13,10
pasvstringend:

command_user:      db 'USER '
command_user_end:
command_pass:      db 'PASS '
command_pass_end:
command_lf:        db 13,10
command_str:       times 128 db 0
command_str_len:   dq 0x0
showtext:          dq 0x0

helptext:

    db    'Commands:                    ',0
    times 51 db 0
    times 81 db 0
    db    'open [server] - Open connection',0
    times 49 db 0
    db    'user [name]   - Send username  ',0
    times 49 db 0
    db    'pass [psw]    - Send password  ',0
    times 49 db 0
    db    'ls [opt]      - Show directory listing   ',0
    times 39 db 0
    db    'bin           - Set transfer mode to Binary',0
    times 37 db 0
    db    'get [file]    - Get file       ',0
    times 49 db 0
    db    'send [file]   - Send file      ',0
    times 49 db 0
    db    'cd [dir]      - Change directory         ',0
    times 39 db 0
    db    'dele [file]   - Delete file from server  ',0
    times 39 db 0
    db    'quit          - Close connection',0
    times 48 db 0
    db    'help          - Help            ',0
    times 48 db 0
    db    'exit          - Close ftp client         ',0
    times 39 db 0

    times 81*1  db 0

    db    '>                            ',0
    times 51 db 0

menu_struct:               ; Menu Struct

    dq   0                 ; Version

    dq   0x100             ; Start value of ID to return ( ID + Line )

                           ; Returned when menu closes and
                           ; user made no selections.

    db   0,'FILE',0        ; ID = 0x100 + 1
    db   1,'Quit',0        ; ID = 0x100 + 2

    db   255               ; End of Menu Struct

tcpipblock:         times 68000 db ?
blocksize:          dq ?
blockpos:           dq ?

text:

image_end:

