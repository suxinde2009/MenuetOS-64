;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;    IRC Client for Menuet64
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use64

    org   0x0

    db    'MENUET64'              ; 8 byte id
    dq    0x01                    ; required os
    dq    START                   ; program start
    dq    I_END                   ; program image size
    dq    0x200000                ; required amount of memory
    dq    0x1ffff0                ; stack
    dq    param                   ; startup parameter
    dq    0                       ; icon

macro pusha { push  rax rbx rcx rdx rsi rdi rbp }
macro popa  { pop   rbp rdi rsi rdx rcx rbx rax }

include 'dns.inc'
include 'textbox.inc'

START:

    mov   rax , 141
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    ; Clear uninitialized data

    mov   rdi , datau_start
    mov   rcx , datau_end - datau_start
    mov   rax , 0
    cld
    rep   stosb
    mov   rax , 0
    mov   [ipc_memory+0],rax
    mov   rax , 16
    mov   [ipc_memory+8],rax

    ; Main or channel window

    cmp   [param+8],byte 0
    jne   channel_thread

    mov   edi , [rxs]
    imul  rdi , 8
    add   rdi , I_END+132
    mov   rax , 'Type /? '
    mov   [rdi],rax
    mov   rax , 'for help'
    mov   [rdi+8],rax
    mov   rax , '        '
    mov   [rdi+16],rax

    ; IPC address

    mov   rax , 60
    mov   rbx , 1
    mov   rcx , channel_text
    mov   rdx , 190
    int   0x60

    ; Cursor address

    mov   eax ,[rxs]
    imul  eax , 11
    mov   [pos],eax

    ; Draw main window

    mov   ebp , 0
    mov   edx , I_END
    call  draw_window

still:

    call  check_channel_text
    call  send_data_to_server
    call  check_main_update
    call  send_data_to_channel_windows
    call  print_status
    call  read_incoming_data

    mov   eax,5
    mov   ebx,1
    int   0x60

    mov   rax,11
    int   0x60

    test  rax,1                  ; Redraw
    jnz   redraw
    test  rax,2                  ; Key
    jnz   main_window_key
    test  rax,4                  ; Button
    jnz   button

    jmp   still

check_main_update:

    mov   edx,[current_channel]
    imul  edx,120*80
    add   edx,I_END
    cmp   [edx+120*60],byte 1
    jne   no_main_update
    mov   [edx+120*60],byte 0
    call  draw_channel_text
    call  print_channel_list
    call  print_entry
   no_main_update:

    ret


show_instructions:

    pusha
    mov   rsi , instructions
    mov   rdi , I_END+132
    mov   rcx , 660
    cld
    rep   movsb
    popa
    ret


check_channel_text:

    mov   [channel_text+8],dword 16
    cmp   [channel_text+16],byte 0
    je    cctl1

    ; Remove Query name from list

    cmp   [channel_text+16],byte 240
    jb    nonameclose
    movzx rax , byte [channel_text+16]
    sub   rax , 240
    shl   eax , 5
    add   eax , channel_list
    mov   [eax],dword '    '
    mov   [eax+31],byte 1
    mov   [channel_text+16],byte 0
    call  print_channel_list
    jmp   cctl1
  nonameclose:

    ; Copy sent string to send_string

    mov   rsi , channel_text+16+2
    mov   rdi , send_string
    mov   rcx , 100
    cld
    rep   movsb

    ; Send data

    mov   al , [channel_text+16+1]
    mov   byte [xpos],al
    mov   al , [channel_text+16]
    mov   byte [send_to_channel],al
    mov   [send_to_server],byte 1
    mov   [channel_text+16],byte 0
    call  send_data_to_server

  cctl1:

    ret


send_data_to_channel_windows:

    inc   [data_send]
    cmp   [data_send],50
    jb    sdl1
    mov   [data_send],0

  sdtcw:

    mov   rcx , 10
    mov   r8  , 0
   newlist:
    push  r8
    push  rcx
    mov   rax , 60
    mov   rbx , 2
    mov   rcx , [pid_list+r8]
    cmp   rcx , 2
    jb    no_pid_send
    mov   rdx , I_END
    mov   r8  , 100000
    int   0x60
   no_pid_send:
    pop   rcx
    pop   r8
    add   r8 , 8
    loop  newlist

    ; Clear updated flags

    mov   rdi , I_END+120*60
    mov   rcx , 10
  newflagclear:
    mov  [rdi],byte 0
    add   rdi , 120*80
    loop  newflagclear

  sdl1:

    ret

redraw:

    call  draw_window
    jmp   still

button:

    mov   eax,17
    int   0x40

    mov   r10 , rax
    shr   r10 , 8
    and   r10 , 0xffff

    cmp   r10 , 101
    jne   nocts
    cmp   [status],dword 4
    je    nocts
    call  connect_to_server
    jmp   still
  nocts:

    cmp   r10 , 1001
    jne   noreadtb1
    mov   r14 , textbox1
    call  read_textbox
    call  copy_strings
    jmp   still
  noreadtb1:
    cmp   r10 , 1002
    jne   noreadtb2
    mov   r14 , textbox2
    call  read_textbox
    call  copy_strings
    jmp   still
  noreadtb2:
    cmp   r10 , 1003
    jne   noreadtb3
    mov   r14 , textbox3
    call  read_textbox
    call  copy_strings
    jmp   still
  noreadtb3:

    ; Close program

    cmp   ah,1
    jne   noclose
    mov   ah , 24
    call  socket_commands
    ; Close channel windows if open
    mov   r8  , 1
   newlist2:
    cmp   [pid_list+r8*8],dword 2  ; Has PID ?
    jb    no_pid_send2
    mov   rsi , r8
    imul  rsi , 120*80
    add   rsi , I_END
    cmp   [rsi+120*60+4],byte 1    ; Already closed ?
    je    no_pid_send2
    call  reset
    jmp   ready
   no_pid_send2:
    inc   r8
    cmp   r8d , [max_windows]
    jb    newlist2
  ready:
    ; Terminate main window
    mov   eax,-1
    int   0x40
   noclose:

    call  socket_commands

    jmp   still


copy_strings:

    ; Real name

    mov   ecx,[textbox1+5*8]
    mov   [user_real_name],ecx
    inc   ecx
    mov   esi,textbox1+6*8
    mov   edi,user_real_name+4
    cld
    rep   movsb

    ; Nick name

    mov   ecx,[textbox2+5*8]
    mov   [user_nick],ecx
    inc   ecx
    mov   esi,textbox2+6*8
    mov   edi,user_nick+4
    cld
    rep   movsb

    ; Server

    mov   esi,textbox3+6*8
    mov   edi,server_string
    mov   ecx,50
    cld
    rep   movsb

    ret

print_status:

    pusha

    mov   eax,53
    mov   ebx,6
    mov   ecx,[socket]
    int   0x40
    mov   [status],eax
    cmp   [old_status],eax
    je    nopr
    mov   [old_status],eax
    push  rax
    mov   eax,13
    mov   ebx,425*65536+30
    mov   ecx,(166+2*20-1)*65536+10+2
    mov   edx,0xffffff
    int   0x40
    pop   rcx
    mov   eax,47
    mov   ebx,2*65536
    mov   edx,425*65536+166+2*20
    mov   esi,0x000000
    int   0x40
   nopr:

    popa
    ret


socket_commands:

    ; Open socket

    cmp   ah,22
    jnz   no_open_socket
    mov   eax,3
    int   0x40
    mov   ecx,eax
    mov   eax,53
    mov   ebx,5
    mov   edx,6667
    mov   esi,dword [irc_server_ip]
    mov   edi,1
    int   0x40
    mov   [socket], eax
    ret
   no_open_socket:

    ; Write userinfo

    cmp   ah,23
    jnz   no_write_userinfo

    mov   eax,53
    mov   ebx,7
    mov   ecx,[socket]
    mov   edx,string0l-string0
    mov   esi,string0
    int   0x40
    mov   eax,53
    mov   ebx,7
    mov   ecx,[socket]
    mov   edx,[user_real_name]
    mov   esi,user_real_name+4
    int   0x40
    mov   eax,53
    mov   ebx,7
    mov   ecx,[socket]
    mov   edx,2
    mov   esi,line_feed
    int   0x40

    mov   eax,5
    mov   ebx,10
    int   0x40

    mov   eax,53
    mov   ebx,7
    mov   ecx,[socket]
    mov   edx,string1l-string1
    mov   esi,string1
    int   0x40
    mov   eax,53
    mov   ebx,7
    mov   ecx,[socket]
    mov   edx,[user_nick]
    mov   esi,user_nick+4
    int   0x40
    mov   eax,53
    mov   ebx,7
    mov   ecx,[socket]
    mov   edx,2
    mov   esi,line_feed
    int   0x40

    ret
   no_write_userinfo:

    ; Close socket

    cmp   ah,24
    jnz   no_close_socket
    mov   eax,53
    mov   ebx,8
    mov   ecx,[socket]
    int   0x40
    mov   rdi , channel_list
    mov   rax , 32
    mov   rcx , 32*10
    cld
    rep   stosb
    ret
   no_close_socket:

    ret


main_window_key:

    mov   rax,2
    int   0x60

    cmp   rbx , 10b
    jne   no_special_key

    ; Enter

    mov   r8  , 'Enter   '
    cmp   rcx , r8
    jne   noe
    cmp   [xpos],0
    je    still
    mov   [send_to_server],1
    call  send_data_to_server
    call  print_entry
    jmp   still
  noe:

    ; Backspace

    mov   r8 , 'Backspc '
    cmp   rcx , r8
    jne   nob
    cmp   [xpos],0
    je    still
    dec   [xpos]
    call  print_entry
    jmp   still
  nob:

  no_special_key:

    cmp   rbx , 0
    jne   still

    ; Character

    cmp   ecx,20
    jbe   no_char
    mov   ebx,[xpos]
    mov   [send_string+ebx],cl
    inc   [xpos]
    cmp   [xpos],80
    jb    noxposdec
    mov   [xpos],79
   noxposdec:
    call  print_entry
    jmp   still
   no_char:

    jmp   still


print_channel_list:

    pusha

    mov   eax,13
    mov   ebx,412*65536+6*15+5
    mov   ecx,(25)*65536+10*11-1
    mov   edx,0xffffff
    int   0x40
    mov   eax,4
    mov   ebx,415*65536+31
    mov   ecx,[index_list_1]
    mov   edx,channel_list+32

    mov   r12 , [channel_lines]
    imul  r12 , 32
    add   r12 , channel_list
    mov   r13 , [fontsize]
    sub   r13 , 9
    imul  r13 , 8
    mov   r13 , [linestep+r13]
    mov   r14 , [fontsize]
    sub   r14 , 9
    imul  r14 , 8
    mov   bx  , [linestart+r14]

   newchannel:
    movzx esi,byte [edx+31]
    and   esi,0x1f
    int   0x40
    add   edx,32
    add   ebx,r13d ; 10
    cmp   edx,r12d ; channel_list+32*10
    jbe   newchannel

    popa

    ret


print_user_list:

    pusha
    mov   edx,ebp
    imul  edx,120*80
    add   edx,120*60+8+I_END
    cmp   [edx],byte 1
    je    nonp
    mov   edx,ebp
    imul  edx,120*80
    add   edx,120*70+I_END
    mov   edi,edx
    mov   eax,[user_pos]
    mov   ebx,[edx-4]
    add   ebx,edx
    sub   ebx,3
    inc   eax
    dec   edx
   newnss:
    inc   edx
    dec   eax
    jz    startuserlist
   newtry:
    cmp   [edx],word '  '
    jne   nodouble
    inc   edx
   nodouble:
    cmp   [edx],byte ' '
    je    newnss
    inc   edx
    cmp   edx,ebx
    jbe   newtry
    dec   dword [edi-8]

    mov   ebx , [user_pos]
    sub   ebx , eax
    mov   [amount_of_users],ebx
    mov   [user_pos],dword 0

    popa

    jmp   print_user_list

    ret

   startuserlist:

    cmp   [edx],byte ' '
    jne   startpr
    inc   edx
   startpr:

    pusha
    mov   eax,13
    mov   ebx,412*65536+6*15+5-13
    mov   ecx,(25)*65536+10*11-1
    mov   edx,0xffffff
    int   0x40
    popa

    mov   r13 , [fontsize]
    sub   r13 , 9
    imul  r13 , 8
    mov   r13 , [linestep+r13]

    mov   eax,4
    mov   ebx,415*65536+31

    mov   r14 , [fontsize]
    sub   r14 , 9
    imul  r14 , 8
    mov   bx  , [linestart+r14]

    mov   ebp,0
   newuser:
    mov   esi,0
   newusers:
    cmp   [edx+esi],byte ' '
    je    do_print
    inc   esi
    cmp   esi,32
    jbe   newusers
   do_print:
    push  rsi
    cmp   esi , 13
    jbe   esiok
    mov   esi , 13
   esiok:
    mov   ecx,[index_list_1]
    int   0x40
    pop   rsi

    inc   ebp
    cmp   ebp,[channel_lines] ; 10
    je    nonp

    add   ebx,r13d ; 10
    add   edx,esi

    inc   edx
    cmp   [edx],byte ' '
    jne   newuser
    inc   edx
    jmp   newuser
   nonp:
    popa
    ret


send_data_to_server:

    pusha

    cmp   [send_to_server],1
    jne   sdts_ret

    mov   eax,[xpos]
    mov   [send_string+eax+0],byte 13
    mov   [send_string+eax+1],byte 10

    mov   eax,[rxs]
    imul  eax,11
    mov   [pos],eax
    mov   eax,[send_to_channel]
    imul  eax,120*80
    add   eax,I_END
    mov   [text_start],eax

    ; Message to channel or server command

    cmp   [send_string],byte '/'
    je    server_command

    mov   bl,13
    call  print_character
    mov   bl,10
    call  print_character
    mov   bl,'<'
    call  print_character

    mov   esi,user_nick+4
    mov   ecx,[user_nick]
   newnp:
    mov   bl,[esi]
    call  print_character
    inc   esi
    loop  newnp

    mov   bl,'>'
    call  print_character
    mov   bl,' '
    call  print_character

    mov   ecx,[xpos]
    mov   esi,send_string
   newcw:
    mov   bl,[esi]
    call  print_character
    inc   esi
    loop  newcw

    mov   eax,dword [send_to_channel]
    shl   eax,5
    add   eax,channel_list
    mov   esi,eax

    mov   edi,send_string_header+8
    movzx ecx,byte [eax+31]
    cld
    rep   movsb
    mov   [edi],word ' :'

    mov   esi, send_string_header
    mov   edx,10
    movzx ebx,byte [eax+31]
    add   edx,ebx

    ; Write channel

    mov   eax, 53
    mov   ebx, 7
    mov   ecx, [socket]
    int   0x40

    mov   esi,send_string
    mov   edx,[xpos]
    inc   edx

    ; Write message

    mov   eax, 53
    mov   ebx, 7
    mov   ecx, [socket]
    int   0x40

    jmp   send_done

  server_command:

    ; Connect

    cmp   [send_string+1],dword 'conn'
    jne   no_connect

    jmp   cts1

  connect_to_server:

    pusha

  cts1:

    ; Find out server IP

    pusha
    mov   rsi , server_string
    mov   rdi , irc_server_ip
    call  get_ip
    cmp   dword [irc_server_ip],dword 0
    jne   yes_connect
    mov   eax , I_END
    mov   [text_start],eax
    mov   r8 , server_not_found
   connect229:
    mov   bl , [r8]
    inc   r8
    cmp   bl , 0
    je    connect29
    call  print_character
    jmp   connect229
   connect29:
    mov   edx , I_END
    call  draw_channel_text
    popa
    jmp   no_connect

  yes_connect:
    popa

    ;

    mov   eax , I_END
    mov   [text_start],eax

    mov   r8 , connecting
   connect22:
    mov   bl , [r8]
    inc   r8
    cmp   bl , 0
    je    connect2
    call  print_character
    jmp   connect22
   connect2:

    mov   edx , I_END
    call  draw_channel_text
    mov   [xpos], 0
    mov   [send_to_server],0
    mov   ah , 22
    call  socket_commands

    call  print_status

    mov   rax , 5
    mov   rbx , 100
    int   0x60
    call  print_status
    mov   rax , 5
    mov   rbx , 100
    int   0x60
    call  print_status

    mov   r8 , connection_failed

    cmp   [status],4
    jne   no_send_userinfo
    mov   ah , 23
    call  socket_commands
    mov   r8 , connection_success
    jmp   connect1
  no_send_userinfo:
    mov   ah , 24
    call  socket_commands
  connect1:

  new_message_part:
    mov   bl , [r8]
    inc   r8
    cmp   bl , 0
    je    message_done
    call  print_character
    jmp   new_message_part
  message_done:
    popa
    ret
  no_connect:

    ; Help

    cmp   [send_string+1],byte '?'
    je    do_help
    cmp   [send_string+1],dword 'help'
    jne   no_help
  do_help:
    call  show_instructions
    mov   [xpos],0
    call  draw_window
    mov   [send_to_server],0
    popa
    ret
  no_help:

    ; Nick

    cmp   [send_string+1],dword 'anic'
    jne   no_set_nick

    mov   ecx,[xpos]
    sub   ecx,7
    mov   [user_nick],ecx

    mov   esi,send_string+7
    mov   edi,user_nick+4
    cld
    rep   movsb

    pusha
    mov   edi,text+70*1+15
    mov   eax,32
    mov   ecx,15
    cld
    rep   stosb
    popa

    mov   esi,user_nick+4
    mov   edi,text+70*1+15
    mov   ecx,[user_nick]
    cld
    rep   movsb

    call  draw_window
    mov   [xpos],0
    mov   [send_to_server],0

    popa
    ret

  no_set_nick:

    ; Real name

    cmp   [send_string+1],dword 'area'
    jne   no_set_real_name

    mov   ecx,[xpos]
    sub   ecx,7
    mov   [user_real_name],ecx

    mov   esi,send_string+7
    mov   edi,user_real_name+4
    cld
    rep   movsb

    pusha
    mov   edi,text+70*0+15
    mov   eax,32
    mov   ecx,15
    cld
    rep   stosb
    popa

    mov   esi,user_real_name+4
    mov   edi,text+70*0+15
    mov   ecx,[xpos]
    sub   ecx,7
    cld
    rep   movsb

    call  draw_window

    mov   [xpos],0
    mov   [send_to_server],0

    popa
    ret

  no_set_real_name:

    ; Server IP

    cmp   [send_string+1],dword 'aser'
    jne   no_set_server

    jmp   noipas

    pusha
    mov   edi,irc_server_ip
    mov   esi,send_string+7
    mov   eax,0
    mov   edx,[xpos]
    add   edx,send_string-1
  newsip:
    cmp   [esi],byte '.'
    je    sipn
    cmp   esi,edx
    jg    sipn
    movzx ebx,byte [esi]
    inc   esi
    imul  eax,10
    sub   ebx,48
    add   eax,ebx
    jmp   newsip
  sipn:
    mov   [edi],al
    xor   eax,eax
    inc   esi
    cmp   esi,send_string+30
    jg    sipnn
    inc   edi
    cmp   edi,irc_server_ip+3
    jbe   newsip
  sipnn:
    popa

  noipas:

    mov   ecx,[xpos]
    sub   ecx,7

    pusha
    mov   edi,text+70*2+15
    mov   eax,32
    mov   ecx,15
    cld
    rep   stosb
    popa

    mov   esi,send_string+7
    mov   edi,text+70*2+15
    cld
    rep   movsb

    call  draw_window

    mov   [xpos],0
    mov   [send_to_server],0

    popa
    ret

   no_set_server:

    ; Private messages

    cmp   [send_string+1],dword 'quer'
    jne   no_query_create

    mov   edi,I_END+120*80
    mov   eax,1 ; create channel window - search for empty slot
   newse2:
    mov   ebx,eax
    shl   ebx,5
    cmp   dword [channel_list+ebx],dword '    '
    je    free_found2
    add   edi,120*80
    inc   eax
    cmp   eax,[max_windows]
    jb    newse2

    ; No window create

    mov   [send_string],dword 0
    mov   [xpos],0
    mov   [send_to_server],0

    popa
    ret

  free_found2:

    mov   edx,send_string+7

    mov   ecx,[xpos]
    sub   ecx,7
    mov   [channel_list+ebx+31],cl

    call  create_channel_name

    push  rdi
    push  rax
    mov   [edi+120*60+8],byte 1 ; query window
    mov   eax,32
    mov   ecx,120*60
    cld
    rep   stosb
    pop   rax
    pop   rdi

    ; eax has the free position
    mov   [thread_screen],edi
    call  create_channel_window

    call  print_channel_list

    mov   [xpos],0
    mov   [send_to_server],0

    popa
    ret

  no_query_create:

    ; Send message to server

    mov   esi, send_string+1
    mov   edx, [xpos]
    add   edx,1

    mov   eax, 53      ; write server command
    mov   ebx, 7
    mov   ecx, [socket]
    int   0x40

  send_done:

    mov   [xpos],0
    mov   [send_to_server],0

    ; Quit server

    cmp   [send_string+1],dword 'quit'
    jne   no_quit_server

    mov   eax,5
    mov   ebx,100
    int   0x40

    call  read_incoming_data

    mov   ah , 24         ; close socket
    call  socket_commands

    call  reset

    popa
    ret

  no_quit_server:

  sdts_ret:

    popa
    ret


reset:

    mov   ecx,[max_windows]
    mov   edi,I_END
  newclose:
    mov   [edi+120*60+4],byte 1
    add   edi,120*80
    loop  newclose

    call  sdtcw
    call  print_channel_list

    mov   rdi , I_END+120*60
    mov   rcx , 190000
    mov   rax , 0
    cld
    rep   stosb

    mov   eax,I_END
    mov   [text_start],eax

    ; Wait two seconds for channel windows to close

    mov   rcx , 20
  closewait:
    mov   rax , 5
    mov   rbx , 10
    int   0x60
    mov   rax , 12
    mov   rbx , 1
    int   0x60
    mov   rax , 12
    mov   rbx , 2
    int   0x60
    loop  closewait

    call  draw_window

    ret


read_incoming_data:

    pusha

  read_new_byte:

    call  read_incoming_byte
    cmp   ecx,-1
    je    no_data_in_buffer

    cmp   bl,10
    jne   no_start_command
    mov   [cmd],1
  no_start_command:

    cmp   bl,13
    jne   no_end_command
    mov   eax,[cmd]
    mov   [eax+command-2],byte 0
    call  analyze_command
    mov   edi,command
    mov   ecx,250
    mov   eax,0
    cld
    rep   stosb
    mov   [cmd],0
  no_end_command:

    mov   eax,[cmd]
    cmp   eax,512
    jge   still

    mov   [eax+command-2],bl
    inc   [cmd]

    jmp   read_new_byte

  no_data_in_buffer:

    popa

    ret


create_channel_name:

    pusha

    mov   r8 , rdi
    and   r8 , 0xffffff
    add   r8 , 120*61

  search_first_letter:
    cmp   [edx],byte ' '
    jne   first_letter_found
    inc   edx
    jmp   search_first_letter
  first_letter_found:

    mov   esi,edx
    mov   edi,channel_list
    add   edi,ebx
    mov   ecx,30
    xor   eax,eax
  newcase:
    mov   al,[esi]
    cmp   eax,'a'
    jb    nocdec
    cmp   eax,'z'
    jg    nocdec
    sub   al,97-65
  nocdec:
    mov   [edi],al
    mov   [r8],al
    inc   r8
    inc   esi
    inc   edi
    loop  newcase

    mov   [r8],byte 0

    popa

    ret


create_channel_window:

    pusha

    mov   [cursor_on_off],0
    mov   [thread_nro],eax
    mov   r15 , rax

    ; Clear close window -flag

    mov   esi , eax
    imul  esi , 120*80
    mov   [I_END+esi+120*60+4],byte 0

    ; Window number parameter

    add   eax , 65
    mov   [ipcm],al

    ; Main window PID

    mov   rax , 111
    mov   rbx , 1
    int   0x60
    mov   rbx , 10
    xor   rdx , rdx
    div   rbx
    add   dl , 48
    mov   [ipcm+1],dl
    xor   rdx , rdx
    div   rbx
    add   dl , 48
    add   al , 48
    mov   [ipcm+2],dl
    mov   [ipcm+3],al

    ; Start window

    mov   rax , 256
    mov   rbx , thread_name
    mov   rcx , ipcm
    int   0x60

    ; Save PID

    imul  r15 , 8
    mov   [pid_list+r15],rbx

    popa

    ret


print_entry:

    pusha

    mov   eax,13
    mov   ebx,8*65536+6*80
    mov   ecx,137*65536+13+1
    mov   edx,0xffffff
    int   0x40

    mov   eax,4
    mov   ebx,8*65536+140
    mov   ecx,0x000000
    mov   edx,send_string
    mov   esi,[xpos]
    int   0x40

    call  blink_cursor

    popa
    ret


blink_cursor:

    pusha

    mov   edx , 0x000000
    mov   rax , 111
    mov   rbx , 2
    int   0x60
    cmp   eax , 0
    je    cursor_active
    mov   edx , 0xffffff
  cursor_active:

    mov   ebx,[xpos]
    imul  ebx,6
    add   ebx,8
    mov   cx,bx
    shl   ebx,16
    mov   bx,cx
    mov   ecx,137*65536+149
    mov   eax,38
    int   0x40

    popa
    ret


set_channel:

    pusha

    ; Case check

    mov   esi,eax
    mov   edi,channel_temp
    mov   ecx,40
    xor   eax,eax
  newcase2:
    mov   al,[esi]
    cmp   eax,'#'
    jb    newcase_over2
    cmp   eax,'a'
    jb    nocdec2
    cmp   eax,'z'
    jg    nocdec2
    sub   al,97-65
  nocdec2:
    mov   [edi],al
    inc   esi
    inc   edi
    loop  newcase2
  newcase_over2:
    sub   edi,channel_temp
    mov   [channel_temp_length],edi

    mov   eax,channel_temp

    mov   [text_start],I_END+120*80
    mov   ebx,channel_list+32
    mov   eax,[eax]
    mov   edx,[channel_temp_length]

  stcl1:
    cmp   dl,[ebx+31]
    jne   notfound

    pusha
    xor   eax,eax
    xor   edx,edx
    mov   ecx,0
  stc4:
    mov   dl,[ebx+ecx]
    mov   al,[channel_temp+ecx]
    cmp   eax,edx
    jne   notfound2
    inc   ecx
    cmp   ecx,[channel_temp_length]
    jb    stc4
    popa

    jmp   found
  notfound2:
    popa
  notfound:
    add   [text_start],120*80
    add   ebx,32
    cmp   ebx,channel_list+19*32
    jb    stcl1
    mov   [text_start],I_END
  found:
    popa
    ret


print_nick:

    pusha
    mov   eax,command+1
    mov   dl,'!'
    call  print_text
    popa
    ret


analyze_command:

    pusha

    mov   [text_start],I_END
    mov   ecx,[rxs]
    imul  ecx,11
    mov   [pos],ecx

    mov   edx,I_END
    call  draw_channel_text

    cmp   [cmd],10
    jge   cmd_len_ok
    mov   [cmd],10
  cmd_len_ok:

    ; Ping

    cmp   [command],dword 'PING'
    jne   no_ping_responce

    mov   [command],dword 'PONG'
    call  print_command_to_main

    mov   eax,53
    mov   ebx,7
    mov   ecx,[socket]
    mov   edx,[cmd]
    sub   edx,2
    and   edx,255
    mov   esi,command
    int   0x40

    mov   eax,53
    mov   ebx,7
    mov   ecx,[socket]
    mov   edx,2
    mov   esi,linef
    int   0x40

    popa
    ret

  no_ping_responce:

    mov   eax,[rxs]
    imul  eax,11
    mov   [pos],eax

    mov   [command],byte '<'

    mov   eax,command
    mov   ecx,100
   new_blank:
    cmp   [eax],byte ' '
    je    bl_found
    inc   eax
    loop  new_blank
    mov   eax,50
  bl_found:

    inc   eax
    mov   [command_position],eax

    mov   esi,eax
    mov   edi,irc_command
    mov   ecx,8
    cld
    rep   movsb

    ; Message to channel

    cmp   [irc_command],'PRIV'
    jne   no_privmsg

    ; compare nick

    mov   eax,[command_position]
    add   eax,8
    call  compare_to_nick
    cmp   [cresult],0
    jne   no_query_msg
    mov   eax,command+1
  no_query_msg:
    call set_channel

    mov   ecx,100 ; [cmd]
    mov   eax,[command_position]
  acl3:
    cmp   [eax],byte ':'
    je    acl4
    inc   eax
    loop  acl3
    mov   eax,10
  acl4:
    inc   eax

    ; Action

    cmp   [eax+1],dword 'ACTI'
    jne   no_action
    push  rax
    mov   eax,action_header_short
    mov   dl,0
    call  print_text
    mov   eax,command+1
    mov   dl,'!'
    call  print_text
    mov   bl,' '
    call  print_character
    pop   rax
    add   eax,8
    mov   dl,0
    call  print_text
    popa
    ret

  no_action:

    push  rax
    mov   bl,10
    call  print_character
    mov   eax,command
    mov   dl,'!'
    call  print_text
    mov   bl,'>'
    call  print_character
    mov   bl,' '
    call  print_character
    pop   rax

    mov   dl,0
    call  print_text

    popa
    ret

  no_privmsg:

    ; Leave channel

    cmp   [irc_command],'PART'
    jne   no_part

    ; compare nick

    mov   eax,command+1
    call  compare_to_nick
    cmp   [cresult],0
    jne   no_close_window

    mov   eax,[command_position]
    add   eax,5
    call  set_channel

    xor   rdi , rdi
    mov   edi , [text_start]
    mov   rcx , 120*80
    mov   rax , 0
    cld
    rep   stosb

    mov   eax,[text_start]
    mov   [eax+120*60+4],byte 1

    sub   eax , I_END
    xor   edx , edx
    mov   ebx , 120*80
    div   ebx
    imul  eax , 32
    add   eax , channel_list
    xor   rdi , rdi
    mov   edi , eax
    mov   rax , ' '
    mov   rcx , 32
    cld
    rep   stosb

    call  print_channel_list

    popa
    ret

  no_close_window:

    mov   eax,[command_position]
    add   eax,5
    call  set_channel

    mov   eax,action_header_red
    mov   dl,0
    call  print_text
    mov   eax,command+1
    mov   dl,'!'
    mov   cl,' '
    call  print_text
    mov   eax,has_left_channel
    mov   dl,0
    call  print_text
    mov   eax,[command_position]
    add   eax,5
    mov   dl,' '
    call  print_text

    popa
    ret

  no_part:

    ; Join channel

    cmp  [irc_command],'JOIN'
    jne  no_join

    ; compare nick

    mov   eax,command+1
    call  compare_to_nick
    cmp   [cresult],0
    jne   no_new_window

    mov   edi,I_END+120*80
    mov   eax,1 ; create channel window - search for empty slot
   newse:
    mov   ebx,eax
    shl   ebx,5
    cmp   dword [channel_list+ebx],dword '    '
    je    free_found
    add   edi,120*80
    inc   eax
    cmp   eax,[max_windows]
    jb    newse

    ; No window create

    mov   [send_string],dword 0
    mov   [xpos],0
    mov   [send_to_server],0

    popa
    ret

  free_found:

    mov   edx,[command_position]
    add   edx,6

    push  rax
    push  rdx
    mov   ecx,0
   finde:
    inc   ecx
    inc   edx
    movzx eax,byte [edx]
    cmp   eax,'#'
    jge   finde
    mov   [channel_list+ebx+31],cl
    pop   rdx
    pop   rax

    push  rdi
    push  rax
    mov   [edi+120*60+8],byte 0 ; channel window
    mov   eax,32
    mov   ecx,120*60
    cld
    rep   stosb
    mov   eax , 0
    mov   ecx , 120*20
    cld
    rep   stosb
    pop   rax
    pop   rdi

    call  create_channel_name

    ; eax has the free position
    mov   [thread_screen],edi
    call  create_channel_window
    call  print_channel_list

  no_new_window:

    mov   eax,[command_position]
    add   eax,6
    call  set_channel

    mov   eax,action_header_blue
    mov   dl,0
    call  print_text
    mov   eax,command+1
    mov   dl,'!'
    mov   cl,' '
    call  print_text

    mov   eax,joins_channel
    mov   dl,0
    call  print_text

    mov   eax,[command_position]
    add   eax,6
    mov   dl,0
    call  print_text

    popa
    ret

  no_join:

    ; Nick change

    cmp   [irc_command],'NICK'
    jne   no_nick_change

    mov   [text_start],I_END
    add   [text_start],120*80

 new_all_channels3:

    mov   eax,action_header_short
    mov   dl,0
    call  print_text
    mov   eax,command+1
    mov   dl,'!'
    call  print_text
    mov   eax,is_now_known_as
    mov   dl,0
    call  print_text
    mov   eax,[command_position]
    add   eax,6
    mov   dl,0
    call  print_text

    add   [text_start],120*80
    cmp   [text_start],I_END+120*80*20
    jb    new_all_channels3

    popa
    ret

  no_nick_change:

    ; Kick

    cmp   [irc_command],'KICK'
    jne   no_kick

    mov   [text_start],I_END
    add   [text_start],120*80

    mov   eax,[command_position]
    add   eax,5
    call  set_channel

    ; new_all_channels4:

    mov   eax,action_header_short
    mov   dl,0
    call  print_text
    mov   eax,command+1
    mov   dl,'!'
    call  print_text
    mov   eax,kicked
    mov   dl,0
    call  print_text
    mov   eax,[command_position]
    add   eax,5
    mov   dl,0
    call  print_text

    popa
    ret

  no_kick:

    ; Quit

    cmp   [irc_command],'QUIT'
    jne   no_quit

    mov   [text_start],I_END
    add   [text_start],120*80

 new_all_channels2:

    mov   eax,action_header_red
    mov   dl,0
    call  print_text
    mov   eax,command+1
    mov   dl,'!'
    call  print_text
    mov   eax,has_quit_irc
    mov   dl,0
    call  print_text

    add   [text_start],120*80
    cmp   [text_start],I_END+120*80*20
    jb    new_all_channels2

    popa
    ret

  no_quit:

    ; Channel mode change

    cmp   [irc_command],dword 'MODE'
    jne   no_mode

    mov   [text_start],I_END
    add   [text_start],120*80

    mov   eax,[command_position]
    add   eax,5
    call  set_channel

 new_all_channels:

    mov   eax,action_header_short
    mov   dl,0
    call  print_text

    call  print_nick

    mov   eax,sets_mode
    mov   dl,0
    call  print_text

    mov   eax,[command_position]
    add   eax,5
    mov   dl,0
    call  print_text

    popa
    ret

  no_mode:

    ; Channel user names

    cmp   [irc_command],dword '353 '
    jne   no_user_list

    mov   eax,[command_position]
   finde2:
    inc   eax
    cmp   [eax],byte '#'
    jne   finde2
    call  set_channel

   finde3:
    inc   eax
    cmp   [eax],byte ':'
    jne   finde3

    pusha
    cmp   [user_list_pos],0
    jne   no_clear_user_list
    mov   edi,[text_start]
    add   edi,120*70
    mov   [edi-8],dword 0
    mov   [edi-4],dword 0
    mov   eax,32
    mov   ecx,1200
    cld
    rep   stosb
  no_clear_user_list:
    popa

    push  rax

    mov   esi,eax
    inc   esi
    mov   edi,[text_start]
    add   edi,120*70
    add   edi,[user_list_pos]
    mov   edx,edi
    mov   ecx,command
    add   ecx,[cmd]
    sub   ecx,[rsp]
    sub   ecx,3
    and   ecx,0xfff
    cld
    rep   movsb

    pop   rax
    mov   ebx,command
    add   ebx,[cmd]
    sub   ebx,eax
    sub   ebx,2
    mov   [edx+ebx-1],dword '    '

    add   [user_list_pos],ebx

    mov   eax,[user_list_pos]
    mov   ebx,[text_start]
    add   ebx,120*70
    mov   [ebx-4],eax

    popa
    ret

  no_user_list:

    ; End of channel user names

    cmp   [irc_command],dword '366 '
    jne   no_user_list_end

    mov   [user_list_pos],0

    popa
    ret

  no_user_list_end:

    mov   [command],byte '-'
    call  print_command_to_main

    popa

    ret


compare_to_nick:

; input  : eax = start of compare
; output : [cresult] = 0 if match, [cresult]=1 if no match

    pusha

    mov   esi,eax
    mov   edi,0

  new_nick_compare:

    mov   bl,byte [esi]
    mov   cl,byte [user_nick+4+edi]

    cmp   bl,cl
    jne   nonickm

    add   esi,1
    add   edi,1

    cmp   edi,[user_nick]
    jb    new_nick_compare

    movzx eax,byte [esi]
    cmp   eax,40
    jge   nonickm

    popa
    mov   [cresult],0
    ret

  nonickm:

    popa
    mov   [cresult],1
    ret


print_command_to_main:

    pusha

    mov   [text_start],I_END
    mov   ecx,[rxs]
    imul  ecx,11
    mov   [pos],ecx
    mov   bl,13
    call  print_character
    mov   bl,10
    call  print_character
    mov   ecx,[cmd]
    sub   ecx,2
    mov   esi,command
   asa:
    dec   ecx
    jz    asb
    inc   esi
    cmp   [esi],byte ':'
    je    newcmdc2
    jmp   asa
   newcmdc2:
    mov   bl,[esi]
    call  print_character
    inc   esi
    loop  newcmdc2
    mov   edx,I_END
    call  draw_channel_text
   asb:

    popa
    ret


print_text:

    pusha
    mov   ecx,command-2
    add   ecx,[cmd]
  ptr2:
    mov   bl,[eax]
    cmp   bl,dl
    je    ptr_ret
    cmp   bl,0
    je    ptr_ret
    call  print_character
    inc   eax
    cmp   eax,ecx
    jbe   ptr2
  ptr_ret:
    mov   eax,[text_start]
    mov   [eax+120*60],byte 1
    popa
    ret


print_character:

    pusha

    ; Enter

    cmp   bl,13
    jne   nobol
    mov   ecx,[pos]
    add   ecx,1
  boll1:
    sub   ecx,1
    mov   eax,ecx
    xor   edx,edx
    mov   ebx,[rxs]
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
    mov   ecx,[rxs]
    div   ecx
    cmp   edx,0
    jnz   addx1
    mov   eax,[pos]
    jmp   cm1
  nolf:
  no_lf_ret:

    ; Character

    cmp   bl,15
    jbe   newdata
    mov   eax,[irc_data]
    shl   eax,8
    mov   al,bl
    mov   [irc_data],eax
    mov   eax,[pos]
    call  draw_data
    mov   eax,[pos]
    add   eax,1
  cm1:
    mov   ebx,[scroll+4]
    imul  ebx,[rxs]
    cmp   eax,ebx
    jb    noeaxz
    mov   esi,[text_start]
    add   esi,[rxs]
    mov   edi,[text_start]
    mov   ecx,ebx
    cld
    rep   movsb
    mov   esi,[text_start]
    mov   ecx,[rxs]
    imul  ecx,61
    add   esi,ecx
    mov   edi,[text_start]
    mov   ecx,[rxs]
    imul  ecx,60
    add   edi,ecx
    mov   ecx,ebx
    cld
    rep   movsb
    mov   eax,ebx
    sub   eax,[rxs]
  noeaxz:
    mov   [pos],eax
  newdata:
    mov   eax,[text_start]
    mov   [eax+120*60],byte 1
    popa
    ret


draw_data:

    pusha

    and   ebx,0xff
    cmp   bl,0xe4
    jne   noe4
    mov   bl,97
  noe4:
    cmp   bl,0xc4
    jne   noc4
    mov   bl,97
  noc4:
    cmp   ebx,229
    jne   no_swedish_a
    mov   bl,97
  no_swedish_a:
    add   eax,[text_start]
    mov   [eax],bl

    popa
    ret


read_incoming_byte:

    mov   eax, 53
    mov   ebx, 2
    mov   ecx, [socket]
    int   0x40

    mov   ecx,-1
    cmp   eax,0
    je    no_more_data
    mov   eax, 53
    mov   ebx, 3
    mov   ecx, [socket]
    int   0x40
    mov   ecx,0
  no_more_data:

    ret

fontsize: dq 0x0

get_font_info:

    push  rax rbx

    mov   rax , 141
    mov   rbx , 3
    int   0x60
    and   rax , 0xff
    mov   [fontsize],rax

    pop   rbx rax

    ret


draw_window:

    pusha

    mov   eax,12
    mov   ebx,1
    int   0x40
    mov   [old_status],300

    call  get_font_info

    mov   rax , 0
    mov   rbx , 150*0x100000000+499+14
    mov   rcx , 100*0x100000000+217+18
    mov   rdx , 0xffffff
    mov   r8  , 1
    mov   r9  , main_label
    mov   r10 , 0 ; menu_struct
    int   0x60

    mov   eax,38
    mov   ebx,5*65536+494+14
    mov   ecx,134*65536+134
    mov   edx,[main_line]
    int   0x40
    mov   eax,38
    mov   ebx,5*65536+494+14
    mov   ecx,152*65536+152
    int   0x40
    mov   eax,38
    mov   ebx,410*65536+410
    mov   ecx,24*65536+134
    int   0x40

    ; Info text

    mov   ebx, 5*65536+166
    mov   ecx,0x000000
    mov   edx,text
    mov   esi,70
  newline:
    mov   eax,4
    int   0x40
    add   ebx,20
    add   edx,70
    cmp   [edx],byte 'x'
    jne   newline

    mov   edx,I_END
    call  draw_channel_text
    call  print_entry
    call  print_channel_list

    mov   r14 , textbox1
    call  draw_textbox
    mov   r14 , textbox2
    call  draw_textbox
    mov   r14 , textbox3
    call  draw_textbox

    mov   rax , 8
    mov   rbx , 330 shl 32 + 80
    mov   rcx , 170 shl 32 + 18
    mov   rdx , 101
    mov   r8  , 0
    mov   r9  , string_connect
    int   0x60

    mov   eax,12
    mov   ebx,2
    int   0x40

    call  blink_cursor

    popa
    ret



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;                Channel windows
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

channel_thread:

    mov   rax , 60
    mov   rbx , 1
    mov   rcx , ipc_memory
    mov   rdx , 100000
    int   0x60

    mov   rax , 5
    mov   rbx , 100
    int   0x60

    mov   rbp, [param+8]
    and   rbp, 0xff
    sub   rbp, 65

    xor   rax,rax
    mov   al,[param+9]
    sub   al,48
    xor   rcx,rcx
    mov   cl,[param+10]
    sub   cl,48
    imul  rcx,10
    add   rax,rcx
    mov   bl,[param+11]
    sub   bl,48
    and   rbx,0xff
    imul  rbx,100
    add   rax,rbx
    mov   [mainpid],rax

    call  thread_draw_window

channel_window_wait:

    mov   [ipc_memory+8],dword 16

    mov   esi,ebp
    imul  esi,120*80
    add   esi,I_END
    cmp   [esi+120*60+4],byte 1
    jne   no_channel_leave
    mov   eax,-1
    int   0x40
   no_channel_leave:

    mov   rax,23
    mov   rbx,1
    int   0x60

    test  rax,1
    jz    no_draw_window
    call  thread_draw_window
  no_draw_window:

    test  rax,2
    jnz   thread_key

    test  rax,4
    jz    no_end
    mov   rax,17
    int   0x60
    cmp   rbx , 1000
    jb    no_scroll
    cmp   rbx , 2000
    ja    no_scroll
    mov   [sc],rbx
    sub   rbx , 1000
    mov   [user_pos],rbx
    call  draw_scroll
    call  print_user_list
    jmp   channel_window_wait
  no_scroll:
    mov   eax,ebp
    imul  eax,120*80
    add   eax,I_END
    cmp   [eax+120*60+8],byte 0 ; channel window
    je    not_close
    ; Data to main window
    mov   rax , rbp
    add   rax , 240 ; close
    mov   [send+0],al
    mov   rax , 60
    mov   rbx , 2
    mov   rcx , [mainpid]
    mov   rdx , send
    mov   r8  , 1
    int   0x60
    mov   eax,-1
    int   0x40
  not_close:
  no_end:

    mov   eax , ebp
    imul  eax , 120*80
    add   eax , I_END+120*60
    cmp   [eax],byte 0
    je    nopri2
    mov   [eax],byte 0
    call  draw_thread_texts
  nopri2:

    jmp   channel_window_wait


draw_thread_texts:

    call  print_entry
    mov   edx , ebp
    imul  edx , 120*80
    add   edx , I_END
    call  draw_channel_text
    mov   edx , ebp
    imul  edx , 120*80
    add   edx , 120*60
    call  print_user_list

    ret

thread_key:

    mov   rax,2
    int   0x60

    cmp   rbx , 10b
    jne   thread_no_special

    ; Enter

    mov   r8  , 'Enter   '
    cmp   rcx , r8
    jne   no_send
    cmp   [xpos],0
    je    no_send
    mov   rax , rbp
    mov   [send],al
    mov   al , byte [xpos]
    mov   [send+1],al
    mov   rdi , send+2
    mov   rsi , send_string
    mov   rcx , 100
    cld
    rep   movsb
    mov   rax , 60
    mov   rbx , 2
    mov   rcx , [mainpid]
    mov   rdx , send
    mov   r8  , 100
    int   0x60
    mov   [xpos],0
    call  print_entry
    jmp   channel_window_wait
  no_send:

    ; Backspace

    mov   r8 , 'Backspc '
    cmp   rcx , r8
    jne   thread_nob
    cmp   [xpos],0
    je    channel_window_wait
    dec   [xpos]
    call  print_entry
    jmp   channel_window_wait
  thread_nob:

  thread_no_special:

    cmp   rbx , 0
    jne   channel_window_wait

    ; Character

    cmp   ecx,20
    jbe   no_character
    mov   ebx,[xpos]
    mov   [send_string+ebx],cl
    inc   [xpos]
    cmp   [xpos],80
    jb    xpok
    mov   [xpos],79
  xpok:
    call  print_entry
    jmp   channel_window_wait
  no_character:

    jmp   channel_window_wait


draw_channel_text:

    pusha

    mov   eax,4
    mov   ebx,10*65536+26+4
    mov   ecx,10
    mov   esi,[rxs]
    add   edx , [rxs]
    add   edx , [rxs]

    mov   r12d , 10

    cmp   [fontsize],dword 9
    jbe   noydec
    mov   r12 , [fontsize]
    cmp   [fontsize],dword 10
    jne   nor12inc
    inc   r12
    add   ebx , 2
  nor12inc:
    cmp   [fontsize],dword 11
    jne   noebxinc
    add   ebx , 3
  noebxinc:
    sub   ebx , [fontsize]
    add   ebx , 9
    dec   ecx
    add   edx , [rxs]
  noydec:

    mov   [channel_lines],rcx

  dct:
    pusha
    mov   cx,bx
    dec   cx
    shl   ecx,16
    mov   cx,12
    mov   eax,13
    mov   ebx,10*65536
    mov   bx,word [rxs]
    imul  bx,6
    mov   edx,0xffffff
    int   0x40
    popa
    push  rcx
    mov   eax,4
    mov   ecx,0
    cmp   [edx],word '* '
    jne   no_red
    mov   ecx,0x0000a0
   no_red:
    cmp   [edx],word '**'
    jne   no_light_blue
    cmp   [edx+2],byte '*'
    jne   no_light_blue
    mov   ecx,0x0000a0
  no_light_blue:
    cmp   [edx],byte '#'
    jne   no_blue
    mov   ecx,0x0000a0
  no_blue:
    int   0x40
    add   edx,[rxs]
    add   ebx,r12d
    pop   rcx
    loop  dct

    popa
    ret



thread_draw_window:

    pusha

    mov   eax,12
    mov   ebx,1
    int   0x40

    call  get_font_info

    ; Search end of channel name

    xor   rsi , rsi
    mov   esi , ebp
    imul  esi , 120*80
    add   esi , 120*61+I_END-1
    mov   edi , esi
    add   edi , 13
  next_end_search:
    inc   esi
    cmp   esi , edi
    ja    no_more_search
    cmp   [esi],byte ' '
    jg    next_end_search
  no_more_search:
    mov   [esi],byte 0

    xor   rax,rax
    mov   rax,rbp
    mov   rbx,22*0x100000000
    imul  rax,rbx
    mov   rbx,20*0x100000000+513
    mov   rcx,20*0x100000000+158
    add   rbx,rax
    add   rcx,rax
    mov   rax,0
    mov   rdx,0xffffff
    mov   r8,1
    xor   r9,r9
    mov   r9d,ebp
    imul  r9,120*80
    add   r9,120*61
    add   r9,I_END
    mov   r10 , 0 ; menu_struct
    int   0x60

    mov   eax,38
    mov   ebx,5*65536+494+14
    mov   ecx,134*65536+134
    mov   edx,[channel_line_sun]
    int   0x40
    mov   eax,38
    mov   ebx,410*65536+410
    mov   ecx,24*65536+134
    mov   edx,[channel_line_sun]
    int   0x40

    call  draw_thread_texts
    call  draw_scroll

    mov   eax,12
    mov   ebx,2
    int   0x40

    call  blink_cursor

    popa
    ret


draw_scroll:

    ; Draw scroll

    mov   rax , 113
    mov   rbx , 1
    mov   rcx , 1000
    mov   rdx , [amount_of_users]
    inc   rdx
    mov   r8  , [sc]
    mov   r9  , 495
    mov   r10 , 24
    mov   r11 , 109
    int   0x60

    ret


; Data area

textbox1:
    dq    0         ; Type
    dq    95        ; X position
    dq    170       ; X size
    dq    161       ; Y position
    dq    1001      ; Button ID
    dq    7         ; Current text length
    db    'JoeUser'
    times 50 db 0   ; Text

textbox2:
    dq    0         ;
    dq    95        ;
    dq    170       ;
    dq    181       ;
    dq    1002      ;
    dq    10        ;
    db    'MyNickName'
    times 50 db 0   ;

textbox3:
    dq    0         ;
    dq    95        ;
    dq    170       ;
    dq    201       ;
    dq    1003      ;
    dq    10        ;
    db    'irc.server'
    times 50 db 0   ;

sc:     dq  1000
socket  dd  0x0

bgc  dd  0x000000
     dd  0x000000
     dd  0x00ff00
     dd  0x0000ff
     dd  0x005500
     dd  0xff00ff
     dd  0x00ffff
     dd  0x770077

tc   dd  0xffffff
     dd  0xff00ff
     dd  0xffffff
     dd  0xffffff
     dd  0xffffff
     dd  0xffffff
     dd  0xffffff
     dd  0xffffff

channel_line_sun    dd  0
cursor_on_off       dd  0
max_windows         dd  8

thread_stack        dd  0x9fff0
thread_nro          dd  1
thread_screen       dd  I_END+120*80*1

action_header_blue  db  10,'*** ',0
action_header_red   db  10,'*** ',0
action_header_short db  10,'* ',0

has_left_channel    db  ' left channel ',0
joins_channel       db  ' joined channel ',0
is_now_known_as     db  ' is now known as ',0
has_quit_irc        db  ' has quit irc',0
sets_mode           db  ' sets mode ',0
kicked              db  ' kicked from ',0

index_list_1        dd  0x000000
index_list_2        dd  0x000000
posx                dd  0
incoming_pos        dd  0
data_send           dq  0
pos                 dd  0
text_start          dd  I_END
irc_data            dd  0
print               db  0
cmd                 dd  2
rxs                 dd  66
res:                db  0,0
nick                dd  0,0,0
irc_command         dd  0,0
command_position    dd  0
counter             dd  0
send_to_server      db  0

channel_list:       times 32*20 db 32
send_to_channel     dd 0x0

send_string_header: db     'privmsg #eax :'
                    times  100  db  0x0

send_string:        times  200  db  0x0
xpos                dd  0

string0:  db  'PASS pswr',13,10,'USER guest 0 * :'
string0l:
string1:  db  'NICK '
string1l:

attribute dd  0
scroll    dd  1
          dd  12
numtext   db  '                     '
wcolor    dd  0x000000

string_connect:    db 'CONNECT',0
server_not_found:  db 13,10,'Server not found.',13,10,0

channel_lines:   dq 10
linestep:        dq 10,11,11,12
linestart:       dq 30,31,31,27
amount_of_users: dq 100000

menu_struct:

    dq    0x0
    dq    0x100
    db    0,'FILE',0
    db    1,'Close',0
    db    0,'HELP',0
    db    1,'About..',0
    db    255

main_label:
    db  'IRC',0

param: dq 8
       times 256 db 0

irc_server_ip   db      192,168,0,1
user_nick       dd      10                                ; length
                db      'MyCoolNick             '         ; string
user_real_name  dd      7                                 ; length
                db      'JoeUser                '         ; string

ipcm:           db 'XAAA',0
                dq 0x0

thread_name:    db '/FD/1/IRC',0

channel_text:

     dq 0x0
     dq 16
     times 200 db 0 ; channel (+240=query remove) : length : string

instructions:

  db  'How to connect to IRC server:                                     '
  db  '1) Define real name, nick name and IRC server.                    '
  db  '2) Press <Connect> to connect to IRC server.                      '
  db  '                                                                  '
  db  'Commands after established connection:                            '
  db  '/join #channel     - Join channel                                 '
  db  '/part #channel     - Leave channel                                '
  db  '/query nickname    - Private chat                                 '
  db  '/quit              - Disconnect from server                       '
  db  '/help              - Help text                                    '
  db  '                                                                  '
  db  '                                                                  '
  db  '                                                                  '
  db  '                                                                  '
  db  '                                                                  '
  db  '                                                                  '


current_channel     dd  0
status              dd  0
old_status          dd  0
line_feed:          db  13,10
start_user_list_at  dd  0

connecting:         db  13,10,13,10,'Connecting.. ',0
connection_success: db  'success. Userinfo sent.',13,10,0
connection_failed:  db  'failed.',13,10,0

channel_temp: times 100 db 0
channel_temp_length dd  0x0
linef               db  13,10
user_list_pos       dd  0x0
cresult             db  0x0
mainpid:            dq  0x10
main_line           dd  0x000000
main_button         dd  0x6565cc
user_pos:           dq  100000

text:

db '   Real name:                                                         '
db '   Nick name:                                                         '
db '   Server/IP:                                      Connection status: '
db 'x                                                                     '

;
; Channel data at I_END
;
; 120*80*channel window (1+)
;
;     At         Size
;
;     00      ,  120*60   Window text (120 char/row)
; 120*60      ,  1        Text update
; 120*60+4    ,  1        Close window
; 120*60+8    ,  1        0/1 = channel/query
; 120*61      ,  256      Channel name
; 120*61+254  ,  254      Channel entry from user
; 120*61+255  ,  1        Length of entry
; 120*69+248  ,  4        Display names from n:th name
; 120*69+252  ,  4        Length of names string
; 120*70      ,  1200     Names separated with space
;

; Uninitialized data

datau_start:

send:            times 300 db ?
pid_list:        times 100 dq ?
window_label:    times 256 db ?
server_string:   times 100 db ?
command:         times 600 db ?
incoming_string: times 128 db ?

datau_end:

ipc_memory:

    dq ? ; 0
    dq ? ; 16

I_END:










































