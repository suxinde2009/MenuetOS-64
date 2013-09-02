;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;    HTTP Server for MenuetOS by V.Turjanmaa
;
;    Compile with FASM 1.60 or above
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

macro pusha { push  rax rbx rcx rdx rsi rdi }
macro popa  { pop  rdi rsi rdx rcx rbx rax  }

board_default equ 0 ; off/on(0/1)
dir_default   equ 0 ; off/on(0/1)

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

include 'textbox.inc'

; 0x000000+   - program image
; 0x01ffff    - stack
; 0x020000+   - message board
; 0x100000+   - requested file

START:                          ; start of execution

    mov   rax , 141
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    call  board_setup
    call  getftopath

    mov   [status],-1
    mov   [last_status],-2
    call  clear_input
    call  draw_window

still:

    mov   rsp , 0x3ffff0

    call  check_status
    cmp   [status],2
    jge   start_transmission

    cmp   [status],0
    jne   nnn
    cmp   [server_active],1
    jne   nnn
    call  ops
   nnn:

    mov   eax,5
    mov   ebx,1
    int   0x40

    mov   eax,11
    int   0x40
    call  check_events

    jmp   still


check_events:

    cmp   eax,1                 ; Redraw request
    jz    red
    cmp   eax,2                 ; Key in buffer
    jz    key
    cmp   eax,3                 ; Button in buffer
    jz    button

    ret

red:                            ; Redraw
    call  draw_window
    ret

key:
    mov   eax,2
    int   0x40
    ret

button:                          ; Button

    mov   eax,17
    int   0x40

    cmp   ah , 101
    jb    noonoff
    cmp   ah , 102
    ja    noonoff
    sub   ah , 101
    shr   rax , 8
    and   rax , 0xff
    inc   byte [dataonoff+rax]
    and   byte [dataonoff+rax],byte 0x01
    call  draw_select
    ret
  noonoff:

    mov   rbx , rax
    shr   rbx , 8
    cmp   rbx , 1001
    jne   notextbox
    mov   r14 , textbox1
    call  read_textbox
    mov   rsi , tbf
    mov   rdi , getf
    mov   rcx , 40
    cld
    rep   movsb
    call  getftopath
    jmp   still
  notextbox:

    cmp   ah,1                   ; Close
    jnz   tst2
    mov   eax,53
    mov   ebx,8
    mov   ecx,[socket]
    int   0x40
    mov   eax,-1
    int   0x40
  tst2:

    cmp   ah,2                   ; Open
    jnz   tst3

    ; Close the opened socket before

    cmp   [server_active],0
    je    ops
    mov   eax,53
    mov   ebx,8
    mov   ecx,[socket]
    int   0x40
    mov   eax , 5
    mov   ebx , 20
    int   0x40
  ops:
    mov   eax,53
    mov   ebx,5
    mov   ecx,80
    mov   edx,0
    mov   esi,0
    mov   edi,0
    int   0x40
    mov   [socket], eax
    mov   [posy],1
    mov   [posx],0
    call  check_for_incoming_data
    call  clear_input
    call  draw_data
    mov   [server_active],1
    call  check_status
    ret
  tst3:

    cmp   ah,4                   ; Close
    jnz   no4
    mov   [server_active],0
  close_socket:
    mov   eax,53
    mov   ebx,8
    mov   ecx,[socket]
    int   0x40
    ;mov   eax,5
    ;mov   ebx,1
    ;int   0x40
    mov   eax,53
    mov   ebx,8
    mov   ecx,[socket]
    int   0x40

    cmp   [server_active],1
    jne   no_re_open
    mov   eax,53
    mov   ebx,5
    mov   ecx,80
    mov   edx,0
    mov   esi,0
    mov   edi,0
    int   0x40
    mov   [socket], eax
  no_re_open:

    mov   edi,input_text+256*16+1
    mov   [edi+2],dword ':  :'
    call  set_time
    mov   edi,input_text+256*17+1
    mov   [edi+2],dword '.  .'
    call  set_date

    mov   eax,[documents_served]
    mov   ecx,9
    mov   edi,input_text+256*16+12
    call  set_value

    mov   eax,[bytes_transferred]
    mov   ecx,9
    mov   edi,input_text+256*17+12
    call  set_value

    call  draw_data

    mov   esp,0x1ffff
    jmp   still
  no4:

    cmp   ah,6                   ; Read directory location
    je    read_string

    ret


board_setup:

    mov   eax,58
    mov   ebx,filel
    int   0x40
    mov   [board_size],ebx
    cmp   eax,0
    je    board_found

    mov   edi,bsmt
    call  set_time
    mov   edi,bsmd
    call  set_date

    mov   [board_size],board_end-board
    mov   esi,board
    mov   edi,0x20000
    mov   ecx,[board_size]
    cld
    rep   movsb

  board_found:

    mov   eax,58
    mov   ebx,files
    mov   ecx,[board_size]
    mov   [files+8],ecx
    int   0x40

    ret


getftopath:

    mov   rdi , path
    mov   rsi , getf
    cmp   [rsi],byte '/'
    jne   endofpathns
  dir1new:
    push  rdi
    cmp   [rsi],byte '/'
    jne   endofpath
    mov   rax , '/       '
    mov   [rdi],rax
    shr   rax , 8
    mov   [rdi+8],eax
    inc   rsi
    inc   rdi
  dir2new:
    mov   al , [rsi]
    cmp   al , '/'
    je    dir1done
    cmp   al , ' '
    jbe   dir1done
    mov   [rdi],al
    inc   rsi
    inc   rdi
    jmp   dir2new
  dir1done:
    pop   rdi
    add   rdi , 12
    jmp   dir1new
  endofpath:
    pop   rdi
    sub   rdi , 12
  endofpathns:
    mov   rax , 0
    mov   [rdi],rax
    mov   [rdi+8],eax

    ret


clear_input:

    mov   edi,input_text
    mov   eax,32
    mov   ecx,256*30
    cld
    rep   stosb

    ret


start_transmission:

    mov   r8  , 200

  st_wait:

    call  check_status
    cmp  [status], 4
    je    start_transmission_data

    mov   eax , 5
    mov   ebx , 1
    int   0x40

    dec   r8
    jnz   st_wait

    jmp   no_http_request

  start_transmission_data:

    mov   [posy],1
    mov   [posx],0
    call  clear_input
    mov   [retries],50

  wait_for_data:
    call  check_for_incoming_data
    cmp   [input_text+256+1],dword 'GET '
    je    data_received
    cmp   [input_text+256+1],dword 'POST'
    je    data_received
    mov   eax,5
    mov   ebx,1
    int   0x40
    dec   [retries]
    jnz   wait_for_data
    jmp   no_http_request
  data_received:

    mov   eax,0x100000
    mov   ebx,0x2f0000 / 512
    call  read_file

    call  do_events
    call  send_header

    mov   [filepos],0x100000
    mov   [fileadd],700

    call  check_status
    call  draw_data

  newblock:

    call  do_events

    mov   edx,[fileadd]
    cmp   edx,[file_left]
    jbe   file_size_ok
    mov   edx,[file_left]
  file_size_ok:
    sub   [file_left],edx

    ; Connection open ?

    call  check_status
    cmp  [status], 4
    jne   no_http_request

    ; Write to socket

    mov   eax,53
    mov   ebx,7
    mov   ecx,[socket]
    mov   esi,[filepos]
    int   0x40

    ; Stack unavailable ?

    cmp   eax , 0
    jne   no_http_request

    mov   eax,esi
    add   eax,edx
    sub   eax,0x100000
    call  display_progress

    mov   edx,[fileadd]
    add   [filepos],edx

    cmp   [file_left],0
    jg    newblock

  no_http_request:

    mov   rax , 5
    mov   rbx , 5
    int   0x60

    jmp   close_socket



do_events:

    pusha

    mov   eax,5
    mov   ebx,1
    int   0x40

    mov   eax,11
    int   0x40

    call  check_events

    popa
    ret


display_progress:

    pusha

    mov   edi,eax

    mov   eax,13
    mov   ebx,115*65536+8*6
    mov   ecx,190*65536+10+2
    mov   edx,0xffffff
    int   0x40

    mov   eax,47
    mov   ebx,8*65536
    mov   ecx,edi
    mov   edx,115*65536+191
    mov   esi,0x000000
    int   0x40

    popa
    ret


send_header:

    pusha

    mov   eax,53                  ; Send response and file length
    mov   ebx,7
    mov   ecx,[socket]
    mov   edx,h_len-html_header
    mov   esi,html_header
    int   0x40

    mov   eax,53                  ; Send file type
    mov   ebx,7
    mov   ecx,[socket]
    mov   edx,[type_len]
    mov   esi,[file_type]
    int   0x40

    popa
    ret


make_room:

    pusha

    mov   edx,ecx

    mov   esi,0x20000
    add   esi,[board_size]
    mov   edi,esi
    add   edi,edx
    mov   ecx,[board_size]
    sub   ecx,board1-board
    inc   ecx
    std
    rep   movsb
    cld

    popa

    ret


read_file:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Load the wanted file, board or server message
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   [fileinfo+12],eax
    mov   [fileinfo+8],ebx

    mov   [file_type],unk
    mov   [type_len],unkl-unk
    mov   [filename+40*2+6],dword '?   '

    ;
    ; BOARD
    ;

    cmp   [dataonoff],byte 1
    jne   no_server_message_2
    cmp   [input_text+256+1],dword 'POST'
    je    yes_new_message
    cmp   [input_text+256+7+1],dword 'oard' ; /mboard
    jne   no_server_message_2

  yes_new_message:

    mov   eax,58
    mov   ebx,filel
    int   0x40
    mov   [board_size],ebx

    cmp   [input_text+256+1],dword 'POST'
    jne   no_new_message

    mov   edi,bsmt
    call  set_time
    mov   edi,bsmd
    call  set_date

    call  check_for_incoming_data

    mov   esi,input_text+256   ; from
   newfroms:
    inc   esi
    cmp   esi,input_text+256*20
    je    no_server_message_2
    cmp   [esi],dword 'from'
    jne   newfroms

    add   esi,5
    mov   [from_i],esi

    mov   edx,0
   name_new_len:
    cmp   [esi+edx],byte 13
    je    name_found_len
    cmp   [esi+edx],byte '&'
    je    name_found_len
    cmp   edx,1000
    je    name_found_len
    inc   edx
    jmp   name_new_len
   name_found_len:

    mov   [from_len],edx

    mov   esi,input_text+256
   newmessages:
    inc   esi
    cmp   esi,input_text+256*20
    je    no_server_message_2
    cmp   [esi],dword 'sage'
    jne   newmessages

    add   esi,5
    mov   [message],esi

    mov   edx,0
   new_len:
    inc   edx
    cmp   [esi+edx],byte ' '
    je    found_len
    cmp   [esi+edx],byte 13
    jbe   found_len
    cmp   edx,input_text+5000
    je    found_len
    jmp   new_len
   found_len:
    mov   [message_len],edx

    ; Decode letters

    mov   edx,0

   change_letters:

    cmp   [esi+edx],byte '+'
    jne   no_space
    mov   [esi+edx],byte ' '
   no_space:

    cmp   [esi+edx+1],word '0D'
    jne   no_br
    mov   [esi+edx],dword '<br>'
    mov   [esi+edx+4],word '  '
  no_br:

    cmp   [esi+edx],byte '%'
    jne   no_ascii
    movzx eax,byte [esi+edx+2]
    sub   eax,48
    cmp   eax,9
    jbe   eax_ok
    sub   eax,7
   eax_ok:
    movzx ebx,byte [esi+edx+1]
    sub   ebx,48
    cmp   ebx,9
    jbe   ebx_ok
    sub   ebx,7
   ebx_ok:
    imul  ebx,16
    add   ebx,eax
    mov   [esi+edx],bl
    mov   [esi+edx+1],word '  '
    add   edx,2
   no_ascii:

    inc   edx
    cmp   edx,[message_len]
    jbe   change_letters

    ; Add space for new data

    mov   edx,board1e-board1 + board2e-board2 + board3e-board3
    add   edx,[from_len]
    add   edx,[message_len]
    add   [board_size],edx
    mov   ecx,edx
    call  make_room

    ; Add data

    mov   esi,board1
    mov   edi,0x20000
    add   edi,board1-board
    mov   ecx,edx
    cld
    rep   movsb

    mov   esi,[from_i]        ; Name
    mov   edi,0x20000
    add   edi,board1-board + board1e-board1
    mov   ecx,[from_len]
  newfrom:
    cmp   ecx,0
    je    fromdone
    mov   al , [esi]
    mov   bl , ' '
    cmp   al , '+'
    cmove eax , ebx
    mov   [edi],al
    inc   esi
    inc   edi
    dec   ecx
    jmp   newfrom
  fromdone:

    mov   esi,board2          ; Middle part
    mov   edi,0x20000
    add   edi,board1-board + board1e-board1
    add   edi,[from_len]
    mov   ecx,board2e-board2
    cld
    rep   movsb

    mov   esi,[message]       ; Message
    mov   edi,0x20000
    add   edi,board1-board + board1e-board1 +board2e-board2
    add   edi,[from_len]
    mov   ecx,[message_len]
    cld
    rep   movsb

    mov   esi,board3          ; End
    mov   edi,0x20000
    add   edi,board1-board + board1e-board1 +board2e-board2
    add   edi,[from_len]
    add   edi,[message_len]
    mov   ecx,board3e-board3
    cld
    rep   movsb

    inc   [board_messages]

    mov   eax,[board_size]
    mov   [files+8],eax

    mov   eax,58
    mov   ebx,filed
    int   0x40

    mov   eax,58
    mov   ebx,files
    int   0x40

  no_new_message:

    mov   esi,0x20000
    mov   edi,0x100000
    mov   ecx,[board_size]
    cld
    rep   movsb

    mov   [file_type],htm
    mov   [type_len],html-htm
    mov   [filename+40*2+6],dword 'HTM '

    mov   eax,0            ; found
    mov   ebx,[board_size] ; size

    jmp   file_loaded

  no_server_message_2:

    ;
    ; DISPLAY SERVER INFO
    ;

    cmp   [input_text+256+9],dword 'ysta' ;/tinystat
    jne   no_server_message_1

    ; Display server info if index.htm is not present

    jmp   no_server_message_1

  server_message:

    mov   edi,smt
    call  set_time
    mov   edi,smd
    call  set_date
    mov   eax,[documents_served]
    inc   eax
    mov   ecx,9
    mov   edi,sms+19
    call  set_value
    mov   eax,[bytes_transferred]
    add   eax,sme-sm
    ;
    mov   [directory_size],dword 0
    cmp   [dataonoff+1],byte 1
    jne   nodirsizeadd
    push  rax
    call  calculate_directory_size
    pop   rax
    add   eax,[directory_size]
  nodirsizeadd:
    ;
    add   eax,sme01-sm01
    mov   ecx,9
    mov   edi,smb+19
    call  set_value
    mov   eax,[board_messages]
    mov   ecx,9
    mov   edi,smm+21
    call  set_value
    mov   eax,[board_size]
    mov   ecx,9
    mov   edi,smz+21
    call  set_value
    mov   esi,sm
    mov   edi,0x100000
    mov   ecx,sme-sm
    cld
    rep   movsb
    mov   ebx,sme-sm

    mov   rsi , sme1e
    mov   rbx , sme1d
    cmp   [dataonoff],byte 0
    cmove rsi , rbx
    mov   rdi , sme1
    mov   rcx , 28
    cld
    rep   movsb
    mov   rax , 'Enabled '
    mov   rbx , 'Disabled'
    cmp   [dataonoff+1],byte 0
    cmove rax , rbx
    mov   [sme2+22],rax

    mov   [file_type],htm
    mov   [type_len],html-htm
    mov   [filename+40*2+6],dword 'HTM '

    ; Header

    mov   rsi , sm
    mov   rdi , 0x100000
    mov   rcx , sme-sm
    cld
    rep   movsb

    ; Directory files

    cmp   [dataonoff+1],byte 1
    jne   nodirdataadd
    mov   rsi , smfile
    mov   rcx , smfilee-smfile
    cld
    rep   movsb
    call  read_directory_files
  nodirdataadd:

    ; Footer

    mov   rsi , sm01
    mov   rcx , sme01-sm01
    cld
    rep   movsb

    ; File size

    mov   rax , 0                ; found
    mov   rbx , sme-sm           ; header size
    cmp   [dataonoff+1],byte 1
    jne   nodirsizeadd2
    add   rbx , [directory_size] ; directory size
  nodirsizeadd2:
    add   rbx , sme01-sm01       ; footer size

    jmp   file_loaded

  no_server_message_1:

    ;
    ; SEND REQUESTED FILE
    ;

    mov   esi,input_text+256+6
    cmp   [input_text+256+1],dword 'GET '
    jne   no_new_let
    mov   edi,wanted_file
    cld
  new_let:
    cmp   [esi],byte ' '
    je    no_new_let
    cmp   edi,wanted_file+30
    jge   no_new_let
    movsb
    jmp   new_let
  no_new_let:
    mov   [edi+0],dword 0
    mov   [edi+4],dword 0
    mov   [edi+8],dword 0

    cmp   esi,input_text+256+6
    jne   no_index

  try_index_file:

    mov   edi,wanted_file
    mov   [edi+0],dword  'inde'
    mov   [edi+4],dword  'x.ht'
    mov   [edi+8],byte   'm'
    mov   [edi+9],byte   0
    add   edi,9

    mov   [file_type],htm
    mov   [type_len],html-htm
    mov   [filename+40*2+6],dword 'HTM '

    jmp   html_file
  no_index:

    cmp   [edi-3],dword 'htm'+0
    je    htm_header
    cmp   [edi-3],dword 'HTM'+0
    je    htm_header
    jmp   no_htm_header
  htm_header:
    mov   [file_type],htm
    mov   [type_len],html-htm
    mov   [filename+40*2+6],dword 'HTM '
    jmp   found_file_type
  no_htm_header:

    cmp   [edi-3],dword 'png'+0
    je    png_header
    cmp   [edi-3],dword 'PNG'+0
    je    png_header
    jmp   no_png_header
  png_header:
    mov   [file_type],png
    mov   [type_len],pngl-png
    mov   [filename+40*2+6],dword 'PNG '
    jmp   found_file_type
  no_png_header:

    cmp   [edi-3],dword 'bmp'+0
    je    bmp_header
    cmp   [edi-3],dword 'BMP'+0
    je    bmp_header
    jmp   no_bmp_header
  bmp_header:
    mov   [file_type],bmp
    mov   [type_len],bmpl-bmp
    mov   [filename+40*2+6],dword 'BMP '
    jmp   found_file_type
  no_bmp_header:

    cmp   [edi-3],dword 'gif'+0
    je    gif_header
    cmp   [edi-3],dword 'GIF'+0
    je    gif_header
    jmp   no_gif_header
  gif_header:
    mov   [file_type],gif
    mov   [type_len],gifl-gif
    mov   [filename+40*2+6],dword 'GIF '
    jmp   found_file_type
  no_gif_header:

    cmp   [edi-3],dword 'jpg'+0
    je    jpg_header
    cmp   [edi-3],dword 'JPG'+0
    je    jpg_header
    cmp   [edi-3],dword 'jpe'+0
    je    jpg_header
    cmp   [edi-3],dword 'JPE'+0
    je    jpg_header
    jmp   no_jpg_header
  jpg_header:
    mov   [file_type],jpg
    mov   [type_len],jpgl-jpg
    mov   [filename+40*2+6],dword 'JPG '
    jmp   found_file_type
  no_jpg_header:

    cmp   [edi-3],dword 'asm'+0
    je    txt_header
    cmp   [edi-3],dword 'ASM'+0
    je    txt_header
    cmp   [edi-3],dword 'txt'+0
    je    txt_header
    cmp   [edi-3],dword 'TXT'+0
    je    txt_header
    jmp   no_txt_header
  txt_header:
    mov   [file_type],txt
    mov   [type_len],txtl-txt
    mov   [filename+40*2+6],dword 'TXT '
    jmp   found_file_type
  no_txt_header:

  html_file:

  found_file_type:

    mov   edi,getf
    add   edi,[getflen]
    mov   esi,wanted_file
    mov   ecx,40
    cld
    rep   movsb

    mov   esi,getf
    mov   edi,filename+6
    mov   ecx,30
    cld
    rep   movsb

    mov   [fileinfo+8],dword 1   ; File exists
    mov   eax,58
    mov   ebx,fileinfo
    int   0x40

    cmp   eax,0
    je    file_found

    ; Try index file first

    mov   rax , 'index.ht'
    cmp   [wanted_file],rax
    jne   try_index_file
    mov   rax , 'dex.htm'
    cmp   [wanted_file+2],rax
    jne   try_index_file

    ; Display server message

    jmp   server_message

    ; 404

    ;mov   edi,et
    ;call  set_time
    ;mov   edi,ed
    ;call  set_date
    ;mov   esi,fnf
    ;mov   edi,0x100000
    ;mov   ecx,fnfe-fnf
    ;cld
    ;rep   movsb
    ;mov   ebx,fnfe-fnf
    ;mov   [file_type],htm
    ;mov   [type_len],html-htm
    ;mov   [filename+40*2+6],dword 'HTM '
    ;jmp   file_not_found

   file_found:

    mov   [fileinfo+8],dword 0x2f0000 / 512
    mov   eax,58
    mov   ebx,fileinfo
    int   0x40

   file_not_found:
   file_loaded:

    and   ebx,0x3fffff
    mov   [filesize],ebx
    mov   [file_left],ebx

    mov   eax,ebx
    mov   edi,c_l+5
    mov   ebx,10
  newl:
    xor   edx,edx
    div   ebx
    mov   ecx,edx
    add   cl,48
    mov   [edi],cl
    dec   edi
    cmp   edi,c_l
    jge   newl

    mov   esi,c_l
    mov   edi,filename+46
    mov   ecx,7
    cld
    rep   movsb

    inc   [documents_served]
    mov   eax,[filesize]
    add   [bytes_transferred],eax

    call  draw_data

    ret


calculate_directory_size:

    ; Read filename count

    mov   r8  , pre_read
    mov   rcx , 0
    mov   r10 , 0
  new_pre_read:
    push  rax rcx rdi
    mov   rdi , r8
    mov   rax , 0
    mov   rcx , 302
    cld
    rep   stosb
    pop   rdi rcx rax
    mov   rax , 0
    mov   [r8 ],rax
    mov   rax , 0x2020202020202020
    mov   [r8 +8],rax
    mov   [r8 +16],rax
    mov   rax , 58
    mov   rbx , 3
    mov   rdx , 1
    mov   r9  , path
    int   0x60
    cmp   rax , 0
    jne   lastname
    add   rcx , 1
    mov   r11 , [r8 +8+256]
    cmp   r11 , 0
    je    nozerosize
    inc   r10
    add   r8  , 302
  nozerosize:
    cmp   rcx , 2048
    jb    new_pre_read
  lastname:
    mov   [files_in_directory],r10

    push  r10
    call  arrange_names
    pop   r10

    mov   rax , r10
    imul  rax , filelinee - fileline
    add   rax , smfilee   - smfile
    mov   [directory_size],rax
    ret


arrange_names:

    cmp   [files_in_directory],dword 0
    jne   doarrange
    ret
  doarrange:

    mov   rax , 0

  arrl1:

    mov   r8  , [files_in_directory]
    imul  r8  , 302
    add   r8  , pre_read

    mov   rsi , r8
    mov   rdi , arrtemp
    mov   rcx , 300
    cld
    rep   movsb

    mov   rbx , 0

  arrl2:

    mov   rcx , rbx
    imul  rcx , 302
    add   rcx , pre_read

    ; Arrange by name

    mov   r15 , 8
  newcomparison:
    mov   dl  , [arrtemp+r15]
    cmp   dl  , [rcx+r15]
    jb    rearr
    inc   r15
    cmp   dl  , [rcx+r15-1]
    je    newcomparison
  noname:

    add   rbx , 1
    cmp   rbx , rax
    jbe   arrl2

  rearr:

    push  rcx

    mov   rdi , [files_in_directory]
    inc   rdi
    imul  rdi , 302
    add   rdi , pre_read

    mov   rsi , rdi
    sub   rsi , 302
    mov   rdx , [rsp]
    mov   rcx , rdi
    sub   rcx , rdx
    std
    rep   movsb

    pop   rdi
    mov   rsi , arrtemp
    mov   rcx , 300
    cld
    rep   movsb

  arrfound:

    add   rax , 1
    cmp   rax , [files_in_directory]
    jbe   arrl1

    ret


read_directory_files:

    mov   rdx , [files_in_directory]
    mov   r10 , 0
  newfilesend:
    cmp   rdx , 0
    je    nomorefiles
    push  rdx rdi
    call  read_file_name
    pop   rdi rdx
    mov   rsi , fileline
    mov   rcx , filelinee-fileline
    cld
    rep   movsb
    dec   rdx
    jmp   newfilesend
  nomorefiles:
    ret


read_file_name:

    inc   r10

    mov   r8  , r10
    imul  r8  , 302
    add   r8  , pre_read

    ; Name

    mov   rdi , filelinec
    mov   rsi , r8
    add   rsi , 8
    mov   rcx , 12
  newname:
    mov   al , [rsi]
    cmp   al , ' '
    jbe   nameend
    mov   [rdi],al
    inc   rsi
    inc   rdi
    loop  newname
  nameend:
    mov   [rdi],dword '</a>'
    add   rdi , 4
  newclear:
    cmp   rdi , filelinec+12+4
    ja    cleardone
    mov   [rdi],byte ' '
    inc   rdi
    jmp   newclear
  cleardone:

    ; Link

    mov   rdi , fileline+8
    mov   rsi , r8
    add   rsi , 8
    mov   rcx , 12
    cld
    rep   movsb

    ; Size

    mov   rax , [r8+8+256]
    mov   rdi , filelinec+23+4
    mov   rbx , '        '
    mov   [rdi-7],rbx
    mov   [rdi-7-4],rbx
  newsizeadd:
    xor   rdx , rdx
    mov   rbx , 10
    div   rbx
    add   dl  , 48
    mov   [rdi],dl
    dec   rdi
    cmp   rax , 0
    jne   newsizeadd

    ; Date

    movzx rax , byte [r8+8+256+8]
    mov   rdi , filelinec+46+4
    call  numtostr
    movzx rax , byte [r8+8+256+8+1]
    mov   rdi , filelinec+49+4
    call  numtostr
    movzx rax , word [r8+8+256+8+2]
    mov   rdi , filelinec+54+4
    call  numtostr4

    ; Time

    movzx rax , byte [r8+8+256+8+8+0]
    mov   rdi , filelinec+37+4
    call  numtostr
    movzx rax , byte [r8+8+256+8+8+1]
    mov   rdi , filelinec+34+4
    call  numtostr
    movzx rax , byte [r8+8+256+8+8+2]
    mov   rdi , filelinec+31+4
    call  numtostr

    ret


numtostr:

    xor   rdx , rdx
    mov   rbx , 10
    div   rbx
    add   dl  , 48
    add   al  , 48
    mov   [rdi],al
    mov   [rdi+1],dl
    ret


numtostr4:

    xor   rdx , rdx
    mov   rbx , 10
    div   rbx
    add   dl  , 48
    mov   [rdi+1],dl
    xor   rdx , rdx
    mov   rbx , 10
    div   rbx
    add   dl  , 48
    mov   [rdi+0],dl
    xor   rdx , rdx
    mov   rbx , 10
    div   rbx
    add   dl  , 48
    mov   [rdi-1],dl
    xor   rdx , rdx
    mov   rbx , 10
    div   rbx
    add   dl  , 48
    mov   [rdi-2],dl
    ret


set_value:

    pusha

    add   edi,ecx
    mov   ebx,10
  new_value:
    xor   edx,edx
    div   ebx
    add   dl,48
    mov   [edi],dl
    dec   edi
    loop  new_value

    popa
    ret


set_time:

    pusha

    mov   eax,3
    int   0x40

    mov   ecx,3
  new_time_digit:

    push  rax

    and   eax , 0xff
    xor   edx , edx
    mov   ebx , 16
    div   ebx
    add   eax , 48
    add   edx , 48

    mov   [edi],al
    mov   [edi+1],dl

    pop   rax

    add   edi,3
    shr   eax,8
    loop  new_time_digit

    popa
    ret


set_date:

    pusha

    mov   eax,29
    int   0x40

    mov   ecx,3
    add   edi,6
  new_date_digit:

    push  rax

    and   eax , 0xff
    xor   edx , edx
    mov   ebx , 16
    div   ebx
    add   eax , 48
    add   edx , 48

    mov   [edi],al
    mov   [edi+1],dl

    pop   rax

    sub   edi,3
    shr   eax,8
    loop  new_date_digit

    popa
    ret


check_for_incoming_data:

    pusha

   check:

    mov   eax, 53
    mov   ebx, 2
    mov   ecx, [socket]
    int   0x40

    cmp   eax,0
    je    check_ret_now

  new_data:

    mov   eax,53
    mov   ebx,2
    mov   ecx,[socket]
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
    cmp   [posy],20
    jbe   yok
    mov   [posy],1
   yok:

    mov   eax,[posy]
    imul  eax,256
    add   eax,[posx]

    mov   [input_text+eax],bl

    jmp   new_data

  check_ret:

    call  draw_data

    mov   eax,5
    mov   ebx,1
    cmp   [input_text+256+1],dword 'POST'
    jne   no_ld
    mov   ebx,50
   no_ld:
    int   0x40

    jmp   check

  check_ret_now:

    popa
    ret


check_status:

    pusha

    mov   eax,53
    mov   ebx,6
    mov   ecx,[socket]
    int   0x40

    cmp   eax,[status]
    je    c_ret
    mov   [status],eax
    add   al,48
    mov   [sta+8],al
    call  draw_data
   c_ret:

    popa
    ret


read_string:

    mov   [addr],dword getf
    mov   [ya],dword 126

    mov   edi,[addr]
    mov   eax,0
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
    mov   [edi],al

    call  print_text

    add   edi,1
    mov   esi,[addr]
    add   esi,30
    cmp   esi,edi
    jnz   f11

  read_done:

    push  rdi

    mov   ecx,40
    mov   eax,32
    cld
    rep   stosb

    call  print_text

    pop   rdi
    sub   edi,[addr]
    mov   [getflen],edi

    jmp   still


print_text:

    pusha

    mov   eax,13
    mov   ebx,96*65536+23*6
    mov   ecx,[ya]
    dec   ecx
    shl   ecx,16
    mov   cx,12
    mov   edx,0xffffff
    int   0x40

    mov   eax,4
    mov   edx,[addr]
    mov   ebx,97*65536
    add   ebx,[ya]
    mov   ecx,0x000000
    mov   esi,23
    int   0x40

    popa
    ret


draw_window:

    mov   eax,12
    mov   ebx,1
    int   0x40

    mov   rax , 0x0                          ; Draw window
    mov   rbx,  100*0x100000000+480
    mov   rcx,  100*0x100000000+232
    mov   rdx , 0xFFFFFF
    mov   r8  , 0x1
    mov   r9  , window_label
    mov   r10 , 0
    int   0x60

    mov   rax,8
    mov   rbx,25 shl 32 + 120+26
    mov   rcx,40 shl 32 + 19
    mov   rdx,2
    mov   r8 ,0
    mov   r9 ,string_activate
    int   0x60

    mov   rax,8
    mov   rbx,25 shl 32 + 120+26
    mov   rcx,59 shl 32 + 19
    mov   rdx,4
    mov   r8 ,0
    mov   r9 ,string_close
    int   0x60

    mov   r14 , textbox1
    call  draw_textbox

    mov   eax,38
    mov   ebx,242*65536+242
    mov   ecx,24*65536+227
    mov   edx,0x000000
    int   0x40

    call  draw_data

    call  draw_select

    mov   eax,12
    mov   ebx,2
    int   0x40

    ret


draw_select:

    ; Board: on/off

    mov   rax , 8
    mov   rbx , (25+00) shl 32 + 73
    mov   rcx , 78 shl 32 + 17
    mov   rdx , 101
    mov   r8  , 0
    mov   r9  , string_board_off
    cmp   [dataonoff],byte 0
    je    stroff
    mov   r9  , string_board_on
  stroff:
    int   0x60

    ; Dir: on/off

    mov   rax , 8
    mov   rbx , (25+73) shl 32 + 73
    mov   rcx , 78 shl 32 + 17
    mov   rdx , 102
    mov   r9  , string_dir_off
    cmp   [dataonoff+1],byte 0
    je    stroff2
    mov   r9  , string_dir_on
  stroff2:
    int   0x60

    ret



draw_data:

    pusha

    mov   rax , 52
    mov   rbx , 1
    int   0x60
    mov   r15 , rax
    mov   edi,sta+10
    mov   r14 , 4
  newipset:
    mov   rax , r15
    and   rax , 0xff
    mov   ecx,3
    call  set_value
    shr   r15 , 8
    add   rdi , 4
    dec   r14
    jnz   newipset

    mov   ebx,25*65536+35+13*5+9
    mov   ecx,0x000000
    mov   edx,text
    mov   esi,35
  newline:
    pusha
    cmp   bx,140
    jb    now
    mov   ecx,ebx
    mov   bx,35*6
    dec   ecx
    shl   ecx,16
    mov   cx,12
    mov   eax,13
    mov   edx,0xffffff
    int   0x40
   now:
    popa
    mov   eax,4
    int   0x40
    add   ebx,13
    add   edx,40
    cmp   edx,sta
    jne   nobxsta
    mov   ebx,25*65536+35+13*9+3
  nobxsta:
   cmp   edx,filename
   jne   nobxfn
   mov   ebx,25*65536+35+13*11
 nobxfn:
    cmp   [edx],byte 'x'
    jnz   newline

    mov   [input_text+0],dword 'RECE'
    mov   [input_text+4],dword 'IVED'
    mov   [input_text+8],dword ':   '

    mov   ebx,255*65536+35
    mov   ecx,0x000000
    mov   edx,input_text
    mov   esi,35
    mov   edi,18
  newline2:
    pusha
    mov   ecx,ebx
    mov   bx,35*6
    dec   ecx
    shl   ecx,16
    mov   cx,12
    mov   eax,13
    mov   edx,0xffffff
    int   0x40
    popa
    mov   eax,4
    int   0x40
    add   ebx,10
    add   edx,256
    dec   edi
    jnz   newline2

    popa

    ret

; Data area

string_board_on:  db 'BOARD:ON',0
string_board_off: db 'BOARD:OFF',0
string_dir_on:    db 'DIR:ON',0
string_dir_off:   db 'DIR:OFF',0

retries     dd 50
last_status dd 0

dataonoff: db  board_default,dir_default,0,0,0

text:      db  'File location:                          '
sta:       db  'Status: 0 (xxx.xxx.xxx.xxx)             '
filename:  db  'File: -                                 '
           db  'Size: -                                 '
           db  'Type: -                                 '
           db  'x <- end marker, do not delete          '

html_header:

     db  'HTTP/1.0 200 OK',13,10
     db  'Server: Menuet',13,10
     db  'Content-Length: '
c_l: db  '000000',13,10

h_len:

fnf:
     db  '<body>'
     db  '<pre>'
     db  'M64 server                       ',13,10,13,10
     db  "Error 404 - File not found.",13,10,13,10
     db  "For more info about server: request /TinyStat",13,10,13,10
et:  db  "xx:xx:xx",13,10
ed:  db  "xx.xx.xx",13,10
     db  "</pre></body>"
fnfe:

sm:
     db  '<html>'
     db  '<body bgcolor=#e4e4e4 link=#000000 vlink=#000000 alink=#000000>'
     db  '<center><br>'
     db  '<table border=0 bgcolor=#ffffff cellpadding=25><tr><td>'
     db  '<h3>MenuetOS 64 server</h3>'
     db  '<pre>',13,10
sms: db  'Documents served  : xxxxxxxxx',13,10
smb: db  'Bytes transferred : xxxxxxxxx',13,10
     db  13,10
sme2:db  'Directory listing   : Enabled ',13,10
     db  'Server messageboard :'
sme1:db  '                            ',13,10
     db  13,10
     db  'Default page index.htm not found.',13,10,13,10
     db  'Server time/date : '
smt: db  'xx.xx:xx / '
smd: db  'xx.xx.xx',13,10

sme:

sm01:
     db  '</pre></td></tr></table><br></body></html>'
sme01:

     db  "MessageBoard:",13,10,13,10
smm: db  "- Messages          : xxxxxxxxx",13,10
smz: db  "- Size in bytes     : xxxxxxxxx",13,10
     db  "- Location          : "
     db  "<a href=/MessageBoard>/MessageBoard</a>",13,10
     db  13,10

sme1e:  db  " <a href=/mboard>Enabled</a>",13,10
sme1d:  db  " Disabled                   ",13,10

smfile:
     db  13,10
     db  'File                Size           Time             Date',13,10
     db  '--------------------------------------------------------',13,10
smfilee:

fileline:
     db  '<a href=            >'
filelinec:
     db  'BGR.JPG               123123       12.12:12       12.23.1000',13,10
filelinee:

string_activate:  db  'ACTIVATE',0
string_close:     db  'STOP',0
window_label:     db  'HTTP SERVER',0

documents_served  dd  0x0
bytes_transferred dd  0x0

file_type  dd  0
type_len   dd  0
status     dd  0

htm:   db  'Content-Type: text/html',13,10,13,10
html:
txt:   db  'Content-Type: text/plain',13,10,13,10
txtl:
png:   db  'Content-Type: image/png',13,10,13,10
pngl:
bmp:   db  'Content-Type: image/bmp',13,10,13,10
bmpl:
gif:   db  'Content-Type: image/gif',13,10,13,10
gifl:
jpg:   db  'Content-Type: image/jpeg',13,10,13,10
jpgl:
unk:   db  'Content-Type: unknown/unknown',13,10,13,10
unkl:

socket         dd  0x0
server_active  db  0x0

board:

db "<HTML><BODY BGCOLOR=#d0d0d0 ALINK=black VLINK=black><br>",13,10
db "<center><br>",13,10
db "<TABLE CELLPADDING=14 CELLSPACING=0 BORDER=0 bgcolor=#d0d0d0 width=594>"
db "<TR VALIGN=top><TD ALIGN=center bgcolor=#e8e8e8 colspan=2>",13,10
db "<font size=3>Messageboard</TD></TR></TABLE>",13,10
db "<TABLE CELLPADDING=14 CELLSPACING=3 BORDER=0 bgcolor=#d0d0d0 width=600>"

board1:
db "<TR VALIGN=top>",13,10
db '<TD width=80 style="width:14%" bgcolor=#e0e0e0>',13,10
db "<font size=3>",13,10
board1e:
db "WebMaster",13,10
board2:
db "</font>",13,10
db "<br><br><br>",13,10
db "<br><br><br><br>",13,10
bsmt:
db "12.10:45<br>",13,10
bsmd:
db "25.10.10",13,10
db "</TD>",13,10
db "<TD bgcolor=ffffff>",13,10
board2e:
db "Welcome!<br>",13,10
board3:
db "</TD></TR>",13,10
board3e:


boardadd:
db "</TABLE>",13,10
db "<TABLE CELLPADDING=14 CELLSPACING=0 BORDER=0 bgcolor=#d0d0d0 width=594>"
db "<TR VALIGN=top>",13,10
db "<TD ALIGN=left bgcolor=#e0e0e0><P>",13,10
db "<form method=Post Action=/mboard>",13,10
db "Name: <br><input type=text name=from size=20 MAXLENGTH=20><br>",13,10
db "Message: <br><textarea cols=60 rows=6 name=message></textarea><br>",13,10
db "<input type=Submit Value='   Send Message   '></form>",13,10
db "</TD></TR>",13,10
db "</TABLE><br><br>",13,10
db "</BODY>",13,10
db "</HTML>",13,10

board_end:

filel:

    dd    0x0,0x0,50000/512,0x20000,0x70000
    db    '/fd/1/board.htm',0

files:

    dd    0x1,0x0,0x0,0x20000,0x70000
    db    '/fd/1/board.htm',0

filed:

    dd    0x2,0x0,0x0,0x0,0x0
    db    '/fd/1/board.htm',0

files_in_directory:  dq  0x0
directory_size:      dq  0x0

board_size      dd  0x0
board_messages  dd  0x0

filepos   dd  0x100000
fileadd   dd  0x1
filesize  dd  0x0
file_left dd  0x0

fileinfo     dd  0,0,1,0x100000,0xf0000
getf         db  '/FD/1/'
             times 50 db 0
wanted_file: times 100 db 0

filename2:   times 100 db 32

from_i       dd  0x0
from_len     dd  0x0
message      dd  0x0
message_len  dd  0x0
posy         dd  0x1
posx         dd  0x0
addr         dd  0x0
ya           dd  0x0

textbox1:
         dq   0x0
         dq   25
         dq   120
         dq   114+11
         dq   1001
getflen: dq   6
tbf:     db   '/FD/1/',0
         times 50 db ?

path:    times 12*30 db ?

arrtemp: times 350 db ?

align 64
pre_read: times 302*2050 db ?

input_text:

I_END:

