;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Gifview, jpgview, pngview, bmpview
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use64

    org   0x0

    db    'MENUET64'              ; Header identifier
    dq    0x01                    ; Version
    dq    START                   ; Start of code
    dq    image_end               ; Size of image
    dq    0x100000*12             ; Memory for app
    dq    0x100000*12-10          ; Rsp
    dq    start_param             ; Prm
    dq    0x00                    ; Icon

debug        equ  0
ipcmempic    equ  0x380000
ipcfirstmem  equ  (ipcdata+208-8-16)

START:

    cmp   [start_param+8],dword 0
    je    close_application

    mov   eax , 0
    mov   [ipcfirstmem],rax
    mov   eax , 16
    mov   [ipcfirstmem+8],rax

    ; Receive only IPC events

    mov   eax , 40
    mov   ebx , 64
    int   0x60

    mov   eax , 60
    mov   ebx , 1
    mov   ecx , ipcfirstmem
    mov   edx , 0x100000*8
    int   0x60

    mov   eax , 23
    mov   ebx , 200
    int   0x60

    cmp   [ipcfirstmem+8],dword 16
    je    close_application

    mov   rax , [ipcfirstmem+16]
    mov   [return_pid],rax

    mov   ebx , [ipcfirstmem+8]
    sub   ebx , 16
    add   ebx , 208
    mov   [ipcdata+32],ebx

    mov   [ipcdata+208-8-16],dword 300
    mov   [ipcdata+208-8-12],dword 300
    mov   [ipcdata+208-8-8],dword 0
    mov   [ipcdata+208-8-4],dword 0

    mov   [ipcdata+208-8],dword 512
    mov   [ipcdata+208-4],dword 512

    call  send_data

    ; Data received successfully ?
    ; If not, send 1x1 picture

    cmp   [ipcmempic+8],dword 16
    jne   picture_fine
    mov   word [ipcmempic+3*8],word 1
    mov   word [ipcmempic+4*8],word 1
    mov   rdx , ipcmempic+128+256*4
    mov   [rdx+16],dword 0xf0f0f0
  picture_fine:

  receiver_not_enought_memory:

    movzx rbx , word [ipcmempic+3*8]
    movzx rcx , word [ipcmempic+4*8]
    mov   rdx , ipcmempic+128+256*4+16 - 16
    mov   [rdx],rbx
    mov   [rdx+8],rcx
    mov   r8 , rbx
    imul  r8 , rcx
    imul  r8 , 3
    add   r8 , 16

    ; Send image back

    mov   eax , 60
    mov   ebx , 2
    mov   ecx , [return_pid]
    int   0x60

    ; If receiver does not have enough memory reserved,
    ; subtract from Y size and try again

    cmp   rax , 4
    jne   close_application

    mov   eax , 105
    mov   ebx , 2
    int   0x60

    movzx rcx , word [ipcmempic+4*8]

    cmp   cx , 50
    jbe   close_application

    sub   rcx , 10
    mov   [ipcmempic+4*8],cx

    jmp   receiver_not_enought_memory

  close_application:

    mov   eax , 512
    int   0x60


send_data:

    mov   eax , 111
    mov   ebx , 1
    int   0x60
    mov   [ipcdata+8],rax

    mov   r9 , 0xffffffff
    mov   [ipcdata+48+64],r9 ; IF_IMAGE_BACKGCOLOR

    ;
    ;  Define receive area
    ;

    mov   eax , 60
    mov   ebx , 1
    mov   ecx , ipcmempic
    mov   edx , 0x100000*8
    int   0x60

    mov   eax , 0
    mov   [ipcmempic],rax
    mov   eax , 16
    mov   [ipcmempic+8],rax

    ;
    ;  Start picview
    ;

    mov   eax , 256
    mov   ebx , picview
    mov   ecx , param
    int   0x60

    mov   rcx , rbx
    mov   [decoder_pid],rcx

    ;
    ;  Send data
    ;

    mov   eax , 60
    mov   ebx , 2
    mov   edx , ipcdata
    mov   r8d , [ipcdata+32]
    add   r8d , 208
    mov   r15 , 500
  newdatasendtry:
    mov   rax , 5
    mov   rbx , 1
    int   0x60
    mov   rax , 60
    mov   rbx , 2
    int   0x60
    cmp   rax , 0
    je    datasendsuccess
    dec   r15
    jnz   newdatasendtry
  datasendsuccess:

    ;
    ;  Receive data
    ;

    mov   r15 , 60*2-10 ; 2 minute timeout (qemu)

  wait_for_data:

    mov   eax , 23
    mov   ebx , 100
    int   0x60

    cmp   eax , 0
    jne   data_arrived

    ; Check that decoder is still running

    mov   [process_test],dword 0x123123

    mov   eax , 9
    mov   ebx , 2
    mov   ecx , [decoder_pid]
    mov   edx , process_test
    mov   r8  , 8
    int   0x60

    dec   r15
    jz    data_timeout

    cmp   [process_test],dword 0x123123
    jne   wait_for_data

  data_timeout:

  data_arrived:

    ; Possible wait

    movzx rbx , word [ipcmempic+3*8]
    movzx rcx , word [ipcmempic+4*8]
    imul  ebx , ecx
    imul  ebx , 3
    add   ebx , 128+256*4
    sub   ebx , 256

    cmp   [ipcmempic+8],rbx
    ja    nopicturewait

    mov   eax , 5
    mov   ebx , 5
    int   0x60

  nopicturewait:

    ret


if debug

still:

    mov   rax , 0xA         ; Wait here for event
    int   0x60

    test  rax , 0x1         ; Window redraw
    jnz   window_event
    test  rax , 0x2         ; Keyboard press
    jnz   key_event
    test  rax , 0x4         ; Button press
    jnz   button_event

    jmp   still

window_event:

    call  draw_window
    jmp   still

key_event:

    mov   rax , 0x2        ; Read the key and ignore
    int   0x60

    jmp   still

button_event:

    mov   rax , 0x11
    int   0x60

    ; rax = status
    ; rbx = button id

    cmp   rbx , 0x10000001
    jne   no_application_terminate_button
    mov   rax , 0x200
    int   0x60
  no_application_terminate_button:

    cmp   rbx , 0x106
    jne   no_application_terminate_menu
    mov   rax , 0x200
    int   0x60
  no_application_terminate_menu:

    jmp   still


draw_window:

    mov   rax , 0xC                          ; Beginning of window draw
    mov   rbx , 0x1
    int   0x60

    mov   rax , 0x0                          ; Draw window
    mov   rbx , 0x0000010000000100           ; x start & size
    mov   rcx , 0x00000080000000C0           ; y start & size
    mov   rdx , 0x0000000000FFFFFF           ; type    & border color
    mov   r8  , 0x0000000000000001           ; draw flags
    mov   r9  , window_label                 ; 0 or label - asciiz
    mov   r10 , menu_struct                  ; 0 or pointer to menu struct
    int   0x60

    mov   rax , 0x4                          ; Display text
    mov   rbx , text
    mov   rcx , 0x20
    mov   rdx , 0x40
    mov   rsi , 0x0
    mov   r9  , 0x1
    mov   r8  , 0x3

  newline:

    int   0x60

    add   rbx , 0x1F
    add   rdx , 0x10
    dec   r8
    jnz   newline

    mov   rax , 47
    mov   rbx , 16 * 65536 + 1 * 256
    mov   rdx , 550 shl 32 + 100
    mov   rsi , 0x000000
    mov   r15 , ipcdata
  newnum:
    mov   rcx , [r15]
    int   0x60
    add   r15 , 8
    add   rdx , 10
    cmp   r15 , ipcdata+8*32
    jbe   newnum

    mov   rax , 47
    mov   rbx , 8 * 65536 + 1 * 256
    mov   rdx , 650 shl 32 + 100
    mov   rsi , 0x000000
    mov   r15 , ipcdata2
  newnum2:
    mov   rcx , [r15]
    int   0x60
    add   r15 , 4
    add   rdx , 10
    cmp   r15 , ipcdata2+4*32
    jbe   newnum2

    mov   rax , 47
    mov   rbx , 16 * 65536 + 1 * 256
    mov   rdx , 100 shl 32 + 100
    mov   rsi , 0x000000
    mov   r15 , ipcmempic
  newnum4:
    mov   rcx , [r15]
    int   0x60
    add   r15 , 8
    add   rdx , 10
    cmp   r15 , ipcmempic+8*32
    jbe   newnum4

    mov   rax , 7
    mov   rbx , 10 shl 32
    mov   rcx , 50 shl 32
    mov   bx  , [ipcmempic+3*8]
    mov   cx  , [ipcmempic+4*8]
    mov   rdx , ipcmempic+128+256*4+16
    mov   r8  , 0
    mov   r9  , 0x1000000
    mov   r10 , 3 ; 4
    int   0x60

    mov   rax , 0xC                          ; End of window draw
    mov   rbx , 0x2
    int   0x60

    ret


; Data area

window_label:

    db    'EXAMPLE',0     ; Window label

text:

    db    'HELLO WORLD FROM 64 BIT MENUET',0
    db    'Second line                   ',0
    db    'Third line                    ',0

menu_struct:               ; Menu Struct

    dq   0                 ; Version

    dq   0x100             ; Start value of ID to return ( ID + Line )

                           ; Returned when menu closes and
                           ; user made no selections.

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

end if

picview:       db  '/fd/1/picview',0
param:         dd  -1,0
start_param:   dq  8,0
decoder_pid:   dq  0x0
process_test:  dq  0x0
return_pid:    dq  0x0

ipcdata:   dq  1    ; 1=decode image
           dq  0    ; pid
           dq  1    ; 1=strem_type_mem
           dq  0    ; streamparam1
           dq  0    ; streamparam2
           dq  16+1 ; scanlineformat
           times 128 db 0
           dd  300
           dd  480
           dd  0,0,0,0
           dd  512,512

ipcdata_end:

image_end:

