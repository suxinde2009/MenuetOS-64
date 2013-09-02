;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;    TFTP Client for Menuet
;
;    Compile with FASM 1.60 or above
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use64

    org   0x0

    db    'MENUET64'              ; Header identifier
    dq    0x01                    ; Version
    dq    START                   ; Start of code
    dq    I_END                   ; Size of image
    dq    0x400000                ; Memory for app
    dq    0x1ffff0                ; Rsp
    dq    0x00                    ; Prm
    dq    0x00                    ; Icon

include 'textbox.inc'
include 'dns.inc'

tcpipblock equ 0x200000

START:                          ; Start of execution

    ; System font

    mov   rax , 141
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    call  make_filename

    mov   dword [prompt], p1
    mov   dword [promptlen], p1len-p1

    call  draw_window            ; At first, draw the window

still:
    mov   eax,10                 ; Wait here for event
    int   0x40

    cmp   eax,1                  ; Redraw request
    jz    red
    cmp   eax,2                  ; Key in buffer
    jz    key
    cmp   eax,3                  ; Button in buffer
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

    mov   eax,17
    int   0x40

    mov   rbx , rax
    shr   rbx , 8

    cmp   rbx , 1001
    jne   notb1
    mov   r14 , textbox1
    call  read_textbox
    call  make_filename
    jmp   still
  notb1:

    cmp   rbx , 1002
    jne   notb2
    mov   r14 , textbox2
    call  read_textbox
    call  make_filename
    jmp   still
  notb2:

    cmp   ah,1                  ; Button id=1
    jnz   noclose
    ; close socket before exiting
    mov   eax, 53
    mov   ebx, 1
    mov   ecx, [socketNum]
    int   0x40
    mov   [socketNum], dword 0
    mov   eax,0xffffffff        ; Close this program
    int   0x40
  noclose:

    cmp   ah,2                       ; Copy file to local machine
    jnz   nocopyl
    mov   dword [prompt], p5
    mov   dword [promptlen], p5len - p5
    call  draw_window
    ; Copy File from Remote Host to this machine
    call  translateData              ; Convert Filename & IP address
    mov   edi, tftp_filename + 1
    mov   [edi], byte 0x01           ; Setup tftp msg
    call  copyFromRemote
    jmp   still
  nocopyl:

    cmp   ah,3                      ; Copy file to host
    jnz   nocopyh
    mov   dword [prompt], p5
    mov   dword [promptlen], p5len-p5
    call  draw_window
    ; Copy File from this machine to Remote Host
    call  translateData             ; Convert Filename & IP address
    mov   edi, tftp_filename + 1
    mov   [edi], byte 0x02          ; Setup tftp msg
    call  copyToRemote
    jmp   still
  nocopyh:

    cmp   ah,4                      ; Read text input
    jz    f1
    cmp   ah,5
    jz    f2
    jmp   nof12
  f1:
    mov   [addr],dword source
    mov   [ya],dword 40
    jmp   rk
  f2:
    mov   [addr],dword destination
    mov   [ya],dword 56
  rk:
    mov   ecx,15
    mov   edi,[addr]
    mov   al,' '
    rep   stosb
    call  print_text
    mov   edi,[addr]
  f11:
    mov   eax,10
    int   0x40
    cmp   eax,2
    jz    fbu
    jmp   still
  fbu:
    mov   eax,2
    int   0x40
    shr   eax,8
    cmp   eax,8
    jnz   nobs
    cmp   edi,[addr]
    jz    f11
    sub   edi,1
    mov   [edi],byte ' '
    call  print_text
    jmp   f11
  nobs:
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
    add   esi,15
    cmp   esi,edi
    jnz   f11
    jmp   still

  nof12:
    jmp   still


print_text:

    mov   eax,13
    mov   ebx,103*65536+15*6
    mov   ecx,[ya]
    shl   ecx,16
    mov   cx,8
    mov   edx,0xffffff
    int   0x40

    mov   eax,4
    mov   ebx,103*65536
    add   ebx,[ya]
    mov   ecx,0x000000
    mov   edx,[addr]
    mov   esi,15
    int   0x40

    ret

make_filename:

    push  rsi rdi rcx

    mov   rsi , source
    mov   rdi , filename+6
    mov   rcx , 15
    cld
    rep   movsb

    pop   rcx rdi rsi

    ret


;***************************************************************************
;   Function
;      translateData
;
;   Description
;      Coverts the filename and IP address typed in by the user into
;      a format suitable for the IP layer.
;
;    The filename, in source, is converted and stored in tftp_filename
;      The host ip, in destination, is converted and stored in tftp_IP
;
;***************************************************************************
translateData:

    ; first, build up the tftp command string. This includes the filename
    ; and the transfer protocol

    ; First, write 0,0
    mov   al, 0
    mov   edi, tftp_filename
    mov   [edi], al
    inc   edi
    mov   [edi], al
    inc   edi

    ; Now, write the file name itself, and null terminate it
    mov   ecx, 15
    mov   ah, 0 ; ' '
    mov   esi, source

  td001:
    lodsb
    stosb
    cmp   al, ah
    loopnz td001

    cmp   al,ah   ; Was the entire buffer full of characters?
    jne   td002
    dec   edi     ; No - so remove ' ' character

  td002:
    mov   [edi], byte 0
    inc   edi
    mov   [edi], byte 'O'
    inc   edi
    mov   [edi], byte 'C'
    inc   edi
    mov   [edi], byte 'T'
    inc   edi
    mov   [edi], byte 'E'
    inc   edi
    mov   [edi], byte 'T'
    inc   edi
    mov   [edi], byte 0

    mov   esi, tftp_filename
    sub   edi, esi
    mov   [tftp_len], edi

    mov   rsi , destination
    mov   rdi , tftp_IP
    call  get_ip

    ret



;***************************************************************************
;   Function
;      copyFromRemote
;
;   Description
;
;***************************************************************************

copyFromRemote:

    xor   eax, eax
    mov   [filesize], eax
    mov   eax, I_END + 512 ; This is the point where the file buffer is
    mov   [fileposition], eax

    ; Get a random # for the local socket port #
    mov   eax, 3
    int   0x40
    mov   ecx, eax
    shr   ecx, 8    ; Set up the local port # with a random #

    ; Open socket
    mov   eax, 53
    mov   ebx, 0
    mov   edx, 69         ; Remote port
    mov   esi, [tftp_IP]  ; Remote IP (internet format)
    int   0x40

    mov   [socketNum], eax

    ; Make sure there is no data in the socket

  cfr001:
    mov   eax, 53
    mov   ebx, 3
    mov   ecx, [socketNum]
    int   0x40    ; Read byte
    mov   eax, 53
    mov   ebx, 2
    mov   ecx, [socketNum]
    int   0x40    ; Any more data?
    cmp   eax, 0
    jne   cfr001  ; Yes, so get it

    mov   rax , 0
    mov   [blocksize],rax

    ; Now, request the file
    mov   eax, 53
    mov   ebx, 4
    mov   ecx, [socketNum]
    mov   edx, [tftp_len]
    mov   esi, tftp_filename
    int   0x40

    mov   [timeout],dword 0

cfr002:

    inc   dword [timeout]
    cmp   [timeout],dword 1000*5
    ja    cfr006

    mov   rax , 105
    mov   rbx , 1
    int   0x60
    mov   eax , 11               ; Event ?
    int   0x40

    cmp   eax,1                  ; redraw request
    je    cfr003
    cmp   eax,2                  ; key in buffer
    je    cfr004
    cmp   eax,3                  ; button in buffer
    je    cfr005

    ; Any data to fetch

    mov   rax , [blocksize]
    cmp   rax , 0
    jne   cfr002skip
    mov   eax, 53
    mov   ebx, 2
    mov   ecx, [socketNum]
    int   0x40
    cmp   eax, 0
    je    cfr002
  cfr002skip:

    mov   [timeout],dword 0

    push  rax     ; eax holds # chars

    ; Update the text on the display - once

    mov   eax, [prompt]
    cmp   eax, p3
    je    cfr008
    mov   dword [prompt], p3
    mov   dword [promptlen], p3len - p3
    call  draw_window
  cfr008:

    ; We have data - this will be a tftp frame
    ; Read first two bytes - opcode

    call   read_data_block
    call   read_data_block

    pop   rax

    ; bl holds tftp opcode.
    ; Can only be 3 (data) or 5 (error)

    cmp   bl, 3
    jne   cfrerr

    push  rax

    ; Read block #. Read data. Send Ack.

    call  read_data_block
    mov   [blockNumber], bl

    call  read_data_block
    mov   [blockNumber+1], bl

  cfr007:

    cmp   [blocksize],dword 0
    jne   yes_more_data
    mov   eax, 53
    mov   ebx, 2
    mov   ecx, [socketNum]
    int   0x40         ; More data?
    cmp   eax, 0
    je    no_more_data ; no
  yes_more_data:

    call  read_data_block

    mov   esi, [fileposition]
    mov   [esi], bl
    inc   dword [fileposition]
    inc   dword [filesize]

    jmp   cfr007

  no_more_data:

    ; Write the block number into the ack
    mov   al, [blockNumber]
    mov   [ack + 2], al
    mov   al, [blockNumber+1]
    mov   [ack + 3], al

    ; Send an 'ack'
    mov   eax, 53
    mov   ebx, 4
    mov   ecx, [socketNum]
    mov   edx, ackLen - ack
    mov   esi, ack
    int   0x40

    ; If # of chars in the frame is less that 516,
    ; this frame is the last
    pop   rax
    cmp   eax, 516
    je    cfr002

    ; Delete the file
    mov   rax , 58
    mov   rbx , 2
    mov   r9  , filename
    int   0x60
    mov   rax , 5
    mov   rbx , 20
    int   0x60

    ; Write the file
    mov   rax , 58
    mov   rbx , 1
    mov   rcx , 0
    xor   rdx , rcx
    mov   edx , [filesize]
    mov   r8  , I_END+512
    mov   r9  , filename
    int   0x60

    jmp   cfr_exit

  cfrerr:

    ; Simple implementation on error
    ; Just read all data, and return

    call  read_data_block

    cmp   [blocksize],dword 0
    jne   cfrerr
    mov   eax, 53
    mov   ebx, 2
    mov   ecx, [socketNum]
    int   0x40      ; More data?
    cmp   eax, 0
    jne   cfrerr    ; Yes, so get it

    jmp   cfr006    ; Close socket and exit


read_data_block:

    cmp   [blocksize],dword 0
    jne   getblockbyte

    push  rdx
    mov   rax , 53
    mov   rbx , 13
    mov   ecx , [socketNum]
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


cfr003:                          ; Redraw request
    call  draw_window
    jmp   cfr002

cfr004:                          ; Key pressed
    mov   eax,2                  ; Just read it and ignore
    int   0x40
    jmp   cfr002

cfr005:                          ; Button
    mov   eax,17                 ; Get id
    int   0x40

    cmp   ah,1                   ; Button id=1 ?
    jne   cfr002                 ; If not, ignore.

cfr006:

    ; Close socket

    mov   eax, 53
    mov   ebx, 1
    mov   ecx, [socketNum]
    int   0x40

    mov   [socketNum], dword 0
    mov   dword [prompt], p4e
    mov   dword [promptlen], p4elen-p4e
    call  draw_window

    ret

    ;mov   [socketNum], dword 0
    ;mov   eax,-1                 ; Close this program
    ;int   0x40

cfr_exit:

    ; Close socket

    mov   eax, 53
    mov   ebx, 1
    mov   ecx, [socketNum]
    int   0x40
    mov   [socketNum], dword 0
    mov   dword [prompt], p4
    mov   dword [promptlen], p4len-p4
    call  draw_window

    ret


;***************************************************************************
;   Function
;      copyToRemote
;
;   Description
;
;***************************************************************************
copyToRemote:

    ; Read file

    mov   rax , 58
    mov   rbx , 0
    mov   rcx , 0
    mov   rdx , -1
    mov   r8  , I_END+512
    mov   r9  , filename
    int   0x60

    cmp   rax , 0
    je    filefound
    cmp   rax , 5
    je    filefound

    mov   dword [prompt], p6
    mov   dword [promptlen], p6len - p6
    call  draw_window
    jmp   ctr_exit

filefound:

    mov   [filesize], ebx

    ; First, set up the file pointers

    mov   eax, 0x01000300
    mov   [blockBuffer], eax   ; This makes sure our TFTP header is valid

    mov   eax, I_END + 512     ; This is the point where the file buffer is
    mov   [fileposition], eax

    mov   eax, [filesize]
    cmp   eax, 512
    jb    ctr000
    mov   eax, 512
  ctr000:
    mov   [fileblocksize], ax

    ; Get a random # for the local socket port #

    mov   eax, 3
    int   0x40
    mov   ecx, eax
    shr   ecx, 8    ; Set up the local port # with a random #
    ; First, open socket
    mov   eax, 53
    mov   ebx, 0
    mov   edx, 69    ; Remote port
    mov   esi, [tftp_IP]
    int   0x40

    mov   [socketNum], eax

    ; Write to socket ( request write file )

    mov   eax, 53
    mov   ebx, 4
    mov   ecx, [socketNum]
    mov   edx, [tftp_len]
    mov   esi, tftp_filename
    int   0x40

    ; now, we wait for
    ; UI redraw
    ; UI close
    ; or data from remote

    mov   [timeout],dword 0

ctr001:

    inc   dword [timeout]
    cmp   [timeout],dword 100*5
    ja    ctr006e

    mov   eax , 23               ; Wait here for event
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

    mov   [timeout],dword 0

    ; Update the text on the display - once

    mov   eax, [prompt]
    cmp   eax, p2
    je    ctr002

    mov   dword [prompt], p2
    mov   dword [promptlen], p2len - p2
    call  draw_window

    ; We have data - this will be the ack

  ctr002:
    mov   eax, 53
    mov   ebx, 3
    mov   ecx, [socketNum]
    int   0x40   ; Read byte - opcode
    mov   [ackvalue+1],bl

    mov   eax, 53
    mov   ebx, 3
    mov   ecx, [socketNum]
    int   0x40   ; Read byte - opcode
    mov   [ackvalue],bl

    mov   eax, 53
    mov   ebx, 3
    mov   ecx, [socketNum]
    int   0x40   ; Read byte - block (high byte)
    mov   [blockNumber], bl

    mov   eax, 53
    mov   ebx, 3
    mov   ecx, [socketNum]
    int   0x40   ; Read byte - block (low byte )
    mov   [blockNumber+1], bl

  ctr0022:

    mov   eax, 53
    mov   ebx, 3
    mov   ecx, [socketNum]
    int   0x40   ; Read byte (shouldn't have worked)

    mov   eax, 53
    mov   ebx, 2
    mov   ecx, [socketNum]
    int   0x40   ; Any more data?

    cmp   eax, 0
    jne   ctr0022  ; Yes, so get it, and dump it

    ;; ; Error ?
    ;; cmp   [ackvalue],dword 5
    ;; je    ctr006e

    ; If the ack is 0, it is to the request

    mov   bx, [blockNumber]
    cmp   bx, 0
    je    txd

    ; Now, the ack should be one more than the current
    ; field - otherwise, resend

    cmp   bx, [blockBuffer+2]
    jne   txre     ; Not the same, so send again

    ; Update the block number

    mov   esi, blockBuffer + 3
    mov   al, [esi]
    inc   al
    mov   [esi], al
    cmp   al, 0
    jne   ctr008
    dec   esi
    inc   byte [esi]

  ctr008:

    ; Move forward through the file

    mov   eax, [fileposition]
    movzx ebx, word [fileblocksize]
    add   eax, ebx
    mov   [fileposition], eax

    ; new ..
    ; fs = 0 , fbs = 512 -> send with fbs = 0

    cmp   [filesize],0
    jne   no_special_end
    cmp   [fileblocksize],512
    jne   no_special_end
    mov   ax,0
    jmp   ctr006
  no_special_end:

    mov   eax, [filesize]
    cmp   eax, 0
    je    ctr009
    cmp   eax, 512
    jb    ctr006
    mov   eax, 512
  ctr006:
    mov   [fileblocksize], ax

  txd:

    ; Readjust the file size variable ( before sending )

    mov   eax, [filesize]
    movzx ebx, word [fileblocksize]
    sub   eax, ebx
    mov   [filesize], eax

  txre:

    ; Copy the fragment of the file to the block buffer

    movzx ecx, word [fileblocksize]
    mov   esi, [fileposition]
    mov   edi, I_END
    cld
    rep   movsb

    ; Send the file data

    mov   eax, 53
    mov   ebx, 4
    mov   ecx, [socketNum]
    movzx edx, word [fileblocksize]
    add   edx, 4
    mov   esi, blockBuffer
    int   0x40

    jmp   ctr001

  ctr003:                 ; Redraw
    call  draw_window
    jmp   ctr001

  ctr004:                 ; Key
    mov   eax,2           ; Just read it and ignore
    int   0x40
    jmp   ctr001

  ctr005:                 ; Button
    mov   eax,17          ; Get id
    int   0x40

    cmp   ah,1            ; Button id=1
    jne   ctr001

    ; Close socket

    mov   eax, 53
    mov   ebx, 1
    mov   ecx, [socketNum]
    int   0x40

    mov   [socketNum], dword 0

    mov   eax,-1         ; Close this program
    int   0x40

  ackvalue: dq 0x0
  timeout:  dq 0x0

  ctr006e:

    ; close socket

    mov   eax, 53
    mov   ebx, 1
    mov   ecx, [socketNum]
    int   0x40

    mov   [socketNum], dword 0
    mov   dword [prompt], p4e
    mov   dword [promptlen], p4elen-p4e
    call  draw_window

    ret

  ctr009:

    ; Close socket

    mov   eax, 53
    mov   ebx, 1
    mov   ecx, [socketNum]
    int   0x40

    mov   dword [prompt], p4
    mov   dword [promptlen], p4len-p4
    call  draw_window

  ctr_exit:

    ret

; Window definitions and draw

draw_window:

    mov   eax,12
    mov   ebx,1
    int   0x40

    mov   rax , 0x0                          ; Draw window
    mov   rbx , 100*0x100000000+230
    mov   rcx , 100*0x100000000+180
    mov   rdx , 0xFFFFFF
    mov   r8  , 0
    mov   r9  , window_label
    mov   r10 , 0
    int   0x60

    mov   eax,8
    mov   ebx,20*65536+190
    mov   ecx,87*65536+15+2
    mov   edx,2
    mov   esi,0x557799
    int   0x40

    mov   eax,8
    mov   ebx,20*65536+190
    mov   ecx,119*65536+15+2
    mov   edx,3
    mov   esi,0x557799
    int   0x40

    ;mov   eax,8
    ;mov   ebx,200*65536+10
    ;mov   ecx,39*65536+10
    ;mov   edx,4
    ;mov   esi,0x557799
    ;int   0x40

    ;mov   eax,8
    ;mov   ebx,200*65536+10
    ;mov   ecx,55*65536+10
    ;mov   edx,5
    ;mov   esi,0x557799
    ;int   0x40

    ;; Copy the file name to the screen buffer
    ;; file name is same length as IP address, to
    ;; make the math easier later.
    ;
    ;mov   esi,source
    ;mov   edi,text+13
    ;mov   ecx,15
    ;cld
    ;rep   movsb
    ;
    ;; copy the IP address to the screen buffer
    ;
    ;mov   esi,destination
    ;mov   edi,text+40+13
    ;mov   ecx,15
    ;rep   movsb

    ; copy the prompt to the screen buffer

    mov   esi,[prompt]
    mov   edi,text+280
    mov   ecx,[promptlen]
    cld
    rep   movsb

    ; Redraw the screen text

    mov   ebx,25*65536+40           ; Display info text
    mov   ecx,0x000000
    mov   edx,text
    mov   esi,40
    mov   r10 , 0
  newline:
    inc   r10
    cmp   r10 , 2
    jne   noincy
    add   ebx , 4
  noincy:
    mov   eax,4
    int   0x40
    add   ebx,16
    add   edx,40
    cmp   [edx],byte 'x'
    jnz   newline

    mov   r14 , textbox1
    call  draw_textbox

    mov   r14 , textbox2
    call  draw_textbox

    mov   eax,12
    mov   ebx,2
    int   0x40

    ret


; Data area

textbox1:

    dq    0         ; Type
    dq    60+40     ; X position
    dq    152-42    ; X size
    dq    35        ; Y position
    dq    1001      ; Button ID
    dq    7         ; Current text length
source:
    db    'E64.ASM'
    times 100 db 0 ; Text
    db    0

filename:
    db    '/FD/1/'
    times 50 db 0
    db    0

textbox2:

    dq    0         ;
    dq    60+40     ;
    dq    152-42    ;
    dq    55        ;
    dq    1002      ;
    dq    12        ;
destination:
    db    '192.168.0.54'
    times 100 db 0  ;


tftp_filename:  times 15+9   db   0x0
tftp_IP:                     dd   0x0,0
tftp_len:                    dd   0x0,0
addr                         dd   0x0,0
ya                           dd   0x0,0

fileposition dd 0    ; Points to the current point in the file
filesize  dd 0       ; The number of bytes written / left to write
fileblocksize dw 0   ; The number of bytes to send in this frame

text:

    db 'Source file: xxxxxxxxxxxxxxx            '
    db 'TFTP server: xxx.xxx.xxx.xxx            '
    db '                                        '
    db '  COPY HOST   ->   LOCAL                '
    db '                                        '
    db '  COPY LOCAL  ->   HOST                 '
    db '                                        '
    db '                                        '
    db 'x <- END MARKER, DONT DELETE            '

window_label:

    db   'TFTP CLIENT',0

prompt:     dd  0
promptlen:  dd  0

p1:  db 'Waiting for Command'
p1len:

p2:  db 'Sending File       '
p2len:

p3:  db 'Receiving File     '
p3len:

p4:  db 'Transfer Complete  '
p4len:

p4e: db 'File Transfer Error'
p4elen:

p5:  db 'Contacting Host... '
p5len:

p6:  db 'File not found.    '
p6len:

ack: db 00,04,0,1
ackLen:

socketNum:    dd 0
blockNumber:  dw 0

blocksize:    dq 0
blockpos:     dq 0

; This must be the last part of the file,
; blockBuffer continues at I_END.

blockBuffer:

     db 00, 03, 00, 01

I_END:

