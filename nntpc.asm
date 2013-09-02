;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   NNTP reader for Menuet64
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use64

    org    0x0

    db     'MENUET64'            ; 8 byte id
    dq     0x01                  ; header version
    dq     START                 ; start of code
    dq     I_END                 ; size of image
    dq     0x80000               ; memory for app
    dq     0x7fff0               ; rsp
    dq     0x0,0x0               ; I_Param,I_Icon

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

    call clear_text
    call draw_window

still:

    call state_machine_write
    call state_machine_read

    mov  eax,23
    mov  ebx,5
    int  0x40

    cmp  eax,1
    je   red
    cmp  eax,2
    je   key
    cmp  eax,3
    je   button

    mov  r14d, [ypos]
    call check_for_incoming_data
    cmp  r14d, [ypos]
    je   no_update
    call draw_text
  no_update:

    call connection_status

    jmp  still

red:

    call draw_window
    jmp  still

key:

    mov  eax,2
    int  0x40

    cmp  ah,' '
    jne  no_space
    mov  eax,[space]
    dec  eax
    add  [text_start],eax
    call draw_text
    jmp  still
  no_space:

    cmp  ah,177
    jne  no_plus
    inc  [text_start]
    call draw_text
    jmp  still
  no_plus:

    cmp  ah,178
    jne  no_minus
    cmp  [text_start],0
    je   no_minus
    dec  [text_start]
    call draw_text
    jmp  still
  no_minus:

    cmp  ah,179
    jne  no_next
    mov  ebx, [text_current]
    cmp  ebx, [article_all]
    jae  still
    inc  [text_current]
    call send_group
    call wait_read
    jmp  still
  no_next:

    cmp  ah,176
    jne  no_prev
    cmp  [text_current],0
    je   still
    dec  [text_current]
    call send_group
    call wait_read
    jmp  still
  no_prev:

    jmp  still


copy_strings:

    mov  esi,textbox2+6*8
    mov  edi,group+6
    mov  ecx,[textbox2+5*8]
    mov  eax,ecx
    cld
    rep  movsb
    mov  [group+6+eax],byte 13
    mov  [group+7+eax],byte 10
    add  eax,6+2
    mov  [grouplen],eax
    mov  [text_current],0

    ;call send_group
    ;call wait_read
    ;mov  esi,textbox3+6*8
    ;mov  edi,text_current
    ;call convert_text_to_number
    ;call send_group
    ;call wait_read

    ret


button:

    mov  eax,17
    int  0x40

    shr  eax,8

    cmp  eax , 1001
    jne  notb1
    mov  r14 , textbox1
    call read_textbox
    call copy_strings
    jmp  still
  notb1:
    cmp  eax , 1002
    jne  notb2
    mov  r14 , textbox2
    call read_textbox
    call copy_strings
    call send_group
    call wait_read
    jmp  still
  notb2:
    cmp  eax , 1003
    jne  notb3
    mov  r14 , textbox3
    call read_textbox
    call copy_strings
    mov  esi,textbox3+6*8
    mov  edi,text_current
    call convert_text_to_number
    call send_group
    call wait_read
    jmp  still
  notb3:

    cmp  eax , 1000
    jb   no_scroll
    cmp  eax , 4999
    ja   no_scroll
    sub  eax , 1000
    mov  [text_start],eax
    call draw_scroll
    call draw_text
    jmp  still
  no_scroll:

    cmp  eax,14
    jne  no_start
    call clear_text
    mov  rsi , textbox1+6*8
    mov  rdi , server_ip
    call get_ip
    cmp  dword [server_ip],dword 0
    je   no_start
    mov  eax,3
    int  0x40
    mov  ecx,eax
    mov  eax,53
    mov  ebx,5
    mov  edx,119
    mov  esi,dword [server_ip]
    mov  edi,1
    int  0x40
    mov  [socket],eax
    mov  [status],1
    jmp  still
  no_start:

    cmp  eax,15
    jne  no_end

    call disconnect

  no_end:

    cmp  eax , 16
    jne  no_headertoggle

    inc  byte [headerskip]
    and  [headerskip],byte 1

    call headerbutton
    call send_group
    call wait_read
    jmp  still

  no_headertoggle:

    cmp  eax , 1
    jne  noclose

    call disconnect
    mov  rax , 512
    int  0x60

  noclose:

    jmp  still


disconnect:

    cmp  [status],dword 0
    je   nodisconnect

    mov  eax,53
    mov  ebx,7
    mov  ecx,[socket]
    mov  edx,quitlen-quit
    mov  esi,quit
    int  0x40
    mov  eax,5
    mov  ebx,10
    int  0x40
    call check_for_incoming_data
    mov  eax,53
    mov  ebx,8
    mov  ecx,[socket]
    int  0x40
    mov  eax,5
    mov  ebx,5
    int  0x40
    mov  eax,53
    mov  ebx,8
    mov  ecx,[socket]
    int  0x40
    mov  [status],0

  nodisconnect:

    ret


headerbutton:

    mov   rax , 'All     '
    mov   rbx , '        '
    cmp   [headerskip],byte 1
    jne   noheaderskipyes
    mov   rax , 'Header s'
    mov   rbx , 'kip     '
  noheaderskipyes:
    mov   [text+74*4+10],rax
    mov   [text+74*4+18],rbx
    call  draw_entries

    ret


wait_read:

    cmp  [status],dword 0
    je   wrl2

    mov  [endreatched],dword 0

    mov  r15 , 200
  wrl1:
    call state_machine_read
    call state_machine_write
    call check_for_incoming_data
    mov  rax , 5
    mov  rbx , 1
    int  0x60
    cmp  [endreatched],byte 1
    je   wrl2
    dec  r15
    jnz  wrl1
  wrl2:

    call draw_text_skip
    call draw_text

    call draw_from
    call draw_subject

    ret

check_for_incoming_data:

    cmp  [status],0
    jne  go_on
    ret
  go_on:

    mov  eax,53
    mov  ebx,2
    mov  ecx,[socket]
    int  0x40

    cmp  eax,0
    je   ch_ret

    mov  eax,53
    mov  ebx,3
    mov  ecx,[socket]
    int  0x40

    and  ebx,0xff

    cmp  ebx , '.'
    jne  nodot
    cmp  [xpos],dword 0
    jne  nodot
    mov  [endreatched],byte 1
    ;call draw_text_skip
  nodot:

    cmp  ebx,13
    jb   no_print

    cmp  bl,13
    jne  char
    mov  [xpos],0
    inc  [ypos]
    jmp  no_print
  char:

    cmp  ebx,128
    jbe  char_ok
    mov  ebx,'?'
  char_ok:

    mov  ecx,[ypos]
    imul ecx,80
    add  ecx,[xpos]
    mov  [nntp_text+ecx],bl
    cmp  [xpos],78
    jg   noxinc
    inc  [xpos]
  noxinc:

  no_print:

    mov  eax,53
    mov  ebx,2
    mov  ecx,[socket]
    int  0x40

    cmp  eax,0
    jne  check_for_incoming_data

    ;call draw_text_skip
    ;call draw_scroll

  ch_ret:

    ret


connection_status:

    csy equ 60

    pusha

    mov  eax,53
    mov  ebx,6
    mov  ecx,[socket]
    int  0x40

    cmp  eax,[prev_state]
    je   no_cos

    mov  [prev_state],eax

    mov  eax,13
    mov  ebx,345*65536+12*6
    mov  ecx,(csy-1)*65536+10+3
    mov  edx,0xffffff
    int  0x40

    mov  ecx,-14
    mov  eax,[prev_state]

  next_test:

    add  ecx,14

    cmp  ecx,14*4
    je   no_cos

    cmp  al,[connect_state+ecx+0]
    jb   next_test
    cmp  al,[connect_state+ecx+1]
    jg   next_test

    mov  edx,ecx
    add  edx,2
    add  edx,connect_state

    mov  eax,4
    mov  ebx,345*65536+csy
    mov  ecx,0x000000
    mov  esi,12
    int  0x40

  no_cos:

    popa

    ret


convert_text_to_ip:

    pusha

    mov   edi,server_ip
    mov   esi,text+10
    mov   eax,0
    mov   edx,[xpost]
  newsip:
    cmp   [esi],byte '.'
    je    sipn
    cmp   esi,edx
    jge   sipn
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
    cmp   esi,text+50
    jg    sipnn
    inc   edi
    cmp   edi,server_ip+3
    jbe   newsip
  sipnn:

    popa

    ret


send_group:

    cmp  [status],dword 0
    je   sgl1

    mov  eax,53
    mov  ebx,7
    mov  ecx,[socket]
    mov  edx,[grouplen]
    mov  esi,group
    int  0x40
    mov  [status],3
    call clear_text
    call save_coordinates

  sgl1:

    ret


convert_number_to_text:

    pusha

    mov  eax,[esi]
    mov  ecx,0
  newch:
    inc  ecx
    xor  edx,edx
    mov  ebx,10
    div  ebx
    cmp  eax,0
    jne  newch

    add  edi,ecx
    dec  edi
    mov  [article_l],ecx

    mov  eax,[esi]
  newdiv:
    xor  edx,edx
    mov  ebx,10
    div  ebx
    add  edx,48
    mov  [edi],dl
    dec  edi
    loop newdiv

    popa

    ret


convert_text_to_number:

    pusha

    mov   edx,0
  newdigit:
    movzx eax,byte [esi]
    cmp   eax,'0'
    jb    cend
    cmp   eax,'9'
    jg    cend
    imul  edx,10
    add   edx,eax
    sub   edx,48
    inc   esi
    jmp   newdigit
  cend:
    mov   [edi],edx
    popa

    ret


clear_text:

    mov  [text_start],0
    mov  [xpos],0
    mov  [ypos],0
    mov  [xwait],0
    mov  [ywait],0
    mov  edi,nntp_text
    mov  ecx,0x50000
    mov  eax,32
    cld
    rep  stosb
    ret


state_machine_write:


    cmp  [status],2
    jne  no_22
    call send_group
    call wait_read
    ret
  no_22:

    cmp  [status],4
    jne  no_4
    mov  eax,53
    mov  ebx,7
    mov  ecx,[socket]
    mov  edx,[statlen] ;
    mov  esi,stat
    int  0x40
    mov  [status],5
    call save_coordinates
    ret
  no_4:

    cmp  [status],6
    jne  no_6
    mov  eax,53
    mov  ebx,7
    mov  ecx,[socket]
    mov  edx,articlelen-article
    mov  esi,article
    int  0x40
    mov  [status],7
    call save_coordinates
    ret
  no_6:

    ret

save_coordinates:

    mov  eax,[xpos]
    mov  ebx,[ypos]
    mov  [xwait],eax
    mov  [ywait],ebx

    ret


state_machine_read:

    cmp  [status],1
    jne  no_1
    mov  eax,'200 '
    call wait_for_string
    ret
  no_1:

    cmp  [status],3    ; response to group
    jne  no_3
    mov  eax,'211 '
    call wait_for_string
    ret
  no_3:

    cmp  [status],5    ; response to stat
    jne  no_5
    mov  eax,'223 '
    call wait_for_string
    ret
  no_5:

    ;  'article' request

    cmp  [status],9
    jne  no_9
    mov  eax,'222 '
    call wait_for_string
    ret
  no_9:

    ret



wait_for_string:

    mov  ecx,[ywait]
    imul ecx,80
    add  ecx,[xwait]

    mov  ecx,[nntp_text+ecx]

    cmp  eax,ecx
    jne  no_match

    cmp  [status],3
    jne  no_stat_ret

    mov  esi,[ywait]
    imul esi,80
    add  esi,[xwait]

  new32s:
    inc  esi
    movzx eax,byte [esi+nntp_text]
    cmp  eax,47
    jge  new32s
  new32s2:
    inc  esi
    movzx eax,byte [esi+nntp_text]
    cmp  eax,47
    jge  new32s2
    inc  esi
    add  esi,nntp_text
    ;mov  [esi-1],byte '.'

    mov  edi,article_n
    call convert_text_to_number
    mov  eax,[article_n]
    mov  [article_start],eax

  new32s3:
    inc  esi
    movzx eax,byte [esi]
    cmp  eax,47
    jge  new32s3
    inc  esi

    mov  edi,article_last
    call convert_text_to_number

    mov  eax,[text_current]
    add  [article_n],eax

    mov  esi,article_n
    mov  edi,nntp_text+71
    call convert_number_to_text

    mov  esi,article_n
    mov  edi,stat+5
    call convert_number_to_text

    mov  eax,[article_l]
    mov  [stat+5+eax],byte 13
    mov  [stat+6+eax],byte 10
    add  eax,5+2
    mov  [statlen],eax

    pusha
    mov  edi,textbox3+6*8 ; +10+74*2
    mov  ecx,25
    mov  eax,32
    cld
    rep  stosb
    mov  esi,text_current
    mov  edi,textbox3+6*8 ; +10+74*2
    call convert_number_to_text
    mov  eax,32
    mov  ecx,10
    mov  edi,text+24+74*2
    cld
    rep  stosb
    mov  eax,[article_last]
    sub  eax,[article_start]
    mov  [article_all],eax
    mov  esi,article_all
    mov  edi,text+24+74*2
    call convert_number_to_text
    call draw_entries
    mov  r14 , textbox3
    call draw_textbox
    popa

    ;call draw_text

  no_stat_ret:

    inc  [status]

    mov  eax,5
    mov  ebx,10
    int  0x40

    call check_for_incoming_data

  no_match:

    ret



draw_window:

    pusha

    mov  [prev_state],-1

    mov  eax,12
    mov  ebx,1
    int  0x40

    mov  rax , 0
    mov  rbx , 90 * 0x100000000 + 530-5
    mov  rcx , 60 * 0x100000000 + 460
    mov  rdx , 0xffffff
    mov  r8  , 0
    mov  r9  , window_label
    mov  r10 , 0
    int  0x60

    mov  rax,8
    mov  rbx,304 shl 32+67
    mov  rcx,34  shl 32+17
    mov  rdx,14
    mov  r8 , 0
    mov  r9 , button1
    int  0x60
    mov  rax,8
    mov  rbx,371 shl 32+67
    mov  rcx,34  shl 32+17
    mov  rdx,15
    mov  r8 , 0
    mov  r9 , button2
    int  0x60

    call headerbutton
    call draw_entries
    call draw_text
    call draw_scroll
    call draw_from
    call draw_subject

    mov  r14 , textbox1
    call draw_textbox
    mov  r14 , textbox2
    call draw_textbox
    mov  r14 , textbox3
    call draw_textbox

    call connection_status

    mov  eax,12
    mov  ebx,2
    int  0x40

    popa

    ret


draw_scroll:

    mov  rax , 111
    mov  rbx , 1
    int  0x60

    mov  rcx , rax
    mov  rax , 9
    mov  rbx , 2
    mov  rdx , 0x70000
    mov  r8  , 1024
    int  0x60

    mov  rax , 113
    mov  rbx , 1
    mov  rcx , 1000
    xor  rdx , rdx
    mov  edx , [ypos]
    add  rdx , 35
    xor  r8  , r8
    mov  r8d , [text_start]
    add  r8  , 1000
    mov  r9  , 512
    mov  r10 , 133
    mov  r11 , [0x70000+24]
    sub  r11 , 139
    ;int  0x60

    ret


draw_entries:

    pusha

    mov  rax , 13
    mov  rbx , 170 shl 32 + 12*6
    mov  rcx , (75-1)  shl 32 + 14+3
    mov  rdx , 0xffffff
    int  0x60

    mov  ebx,30*65536+33+5
    mov  ecx,0x000000
    mov  edx,text
    mov  esi,74
    mov  edi,3

  newline2:

    mov  eax,4
    int  0x40
    add  ebx,20 ; 16 ; 11
    add  edx,74
    dec  edi
    jnz  newline2

    popa

    ret


draw_from:

    pusha

    mov  rax , 111
    mov  rbx , 1
    int  0x60

    mov  rcx , rax
    mov  rax , 9
    mov  rbx , 2
    mov  rdx , 0x70000
    mov  r8  , 1024
    int  0x60

    mov   rax , 13
    mov   rbx , 5  * 0x100000000
    add   rbx , [0x70000+16]
    sub   rbx , 10
    mov   rcx , (100)* 0x100000000 + 18+10+3
    mov   rdx , 0xededed
    int   0x60

    mov   rsi , nntp_text
  fnext:
    cmp   [rsi+1],dword 'rom:'
    je    foundfrom
    add   rsi , 80
    cmp   rsi , nntp_text + 30 *80
    jb    fnext
    jmp   nofrom

  foundfrom:

    mov   [rsi+70],byte 0

    mov   rax , 4
    mov   rbx , rsi
    mov   rcx , 20
    mov   rdx , 106
    mov   r9  , 1
    mov   rsi , 0x000000
    int   0x60

  nofrom:

    popa

    ret


draw_subject:

    pusha

    ;mov   rax , 13
    ;mov   rbx , 5  * 0x100000000
    ;add   rbx , [0x70000+16]
    ;sub   rbx , 10
    ;mov   rcx , 135* 0x100000000 + 18
    ;mov   rdx , 0xe0e0e0
    ;int   0x60

    mov   rsi , nntp_text
  snext:
    cmp   [rsi+1],dword 'ubje'
    je    foundsubject
    add   rsi , 80
    cmp   rsi , nntp_text + 30 *80
    jb    snext
    jmp   nosubject

  foundsubject:

    mov   [rsi+70],byte 0

    mov   rax , 4
    mov   rbx , rsi
    mov   rcx , 20
    mov   rdx , 118
    mov   r9  , 1
    mov   rsi , 0x000000
    int   0x60

  nosubject:

    popa

    ret




draw_text_skip:

    pusha

    cmp  [headerskip],byte 1
    jne   draw_text_l1

    mov  [text_start],dword 0

    mov  rsi , nntp_text
  tnext:
    cmp  [esi+3], dword '    '
    jne  notfound
    cmp  [esi+80],dword '    '
    je   notfound
    jmp  founddouble
  notfound:
    add  rsi , 80
    cmp  rsi , nntp_text+100*80
    jb   tnext
    jmp  draw_text_l1
  founddouble:
    sub  rsi , nntp_text
    mov  rax , rsi
    mov  rbx , 80
    xor  rdx , rdx
    div  rbx
    inc  eax
    cmp  [text_start],eax
    ja   nochange
    mov  [text_start],eax
  nochange:

    jmp  draw_text_l1

draw_text:

    pusha

  draw_text_l1:

    call draw_scroll

    ;call draw_from
    ;call draw_subject

    mov  eax,9
    mov  ebx,0x70000
    mov  ecx,-1
    int  0x40

    mov  eax,[0x70000+46]
    cmp  eax,170
    jbe  dtret

    push  rax rbx
    mov   rax , 141
    mov   rbx , 3
    int   0x60
    and   rax , 0xff
    mov   r14 , rax
    add   r14 , 1
    pop   rbx rax

    sub  eax,165
    mov  ebx,r14d
    xor  edx,edx
    div  ebx
    mov  edi,eax
    and  edi , 0xffff
    inc  edi

    mov  [space],edi

    mov  ebx,20*65536+145-2
    mov  ecx,0x000000
    mov  edx,[text_start]
    imul edx,80
    add  edx,nntp_text
    mov  esi,80

    xor  r12 , r12
    mov  r12d, [text_start]
    add  r12 , 1

  newline:

    pusha
    mov  ecx,ebx
    dec  ecx
    shl  ecx,16
    mov  eax,13
    mov  ebx,20*65536+80*6
    mov  cx,10+3
    mov  edx,0xffffff
    int  0x40
    popa

    inc  r12
    cmp  r12 , 10
    jb   noskip
    cmp  r12d, [ypos]
    ja   skipline

  noskip:

    mov  eax , 4
    int  0x40

  skipline:

    add  ebx,r14d
    add  edx,80
    dec  edi
    jnz  newline

  dtret:

    popa

    ret


; Data area

textbox1:

    dq    0         ; Type
    dq    88        ; X position
    dq    159       ; X size
    dq    33        ; Y position
    dq    1001      ; Button ID
    dq    11        ; Current text length
    db    'news.server'
    times 50 db 0   ; Text

textbox2:

    dq    0         ;
    dq    88        ;
    dq    159       ;
    dq    33+20     ;
    dq    1002      ;
    dq    17        ;
    db    'comp.lang.asm.x86'
    times 50 db 0   ;

textbox3:

    dq    0         ;
    dq    88        ;
    dq    6*10      ;
    dq    33+40     ;
    dq    1003      ;
    dq    1
    db    '0'
    times 50 db 0   ;

button1: db 'CONNECT',0
button2: db 'CLOSE',0



connect_state  db  0,0,'            '
               db  1,3,'Opening..   '
               db  4,4,'Connected   '
               db  5,9,'Closing..   '

prev_state     dd  -1
sc:            dq  1000
headerskip:    dq  1
space          dd  0x0
text_start     dd  0x0
text_current   dd  0x0
status         dd  0x0
server_ip      db  192,168,0,96
socket         dd  0x0
xpos           dd  0x0
ypos           dd  0x0

group      db  'GROUP alt.lang.asm',13,10
           db  '                              '
grouplen   dd  20
stat       db  'STAT                          '
statlen    dd  0x0
article    db  'ARTICLE',13,10
articlelen:
quit       db  'QUIT',13,10
quitlen:

xwait          dd  0x0
ywait          dd  0x0
article_n      dd  0x0
article_l      dd  0x0
article_start  dd  0x0
article_last   dd  0x0
article_all    dd  0x0
article_fetch  dd  0x0
endreatched:   dq  0x0
xpost          dd  0x0
edisave        dd  0x0

window_label:

     db   'NNTP READER',0

text:

db 'Server  :                                                                 '
db 'Group   :                                                                 '
db 'Article :            of [x]                Read/fetch: Arrows and Space   '
db 'Art.max : -                             Fetch Prev/Next: Arrows Left/Right'
db 'Display :                        <      Scroll: Arrows Up/Down & Space    '
db '                                                                          '
db 'Fetch Prev/Next: Arrows Left/Right  Scroll: Arrows Up/Down & Space        '

nntp_text:

I_END:

