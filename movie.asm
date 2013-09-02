;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   64 bit Menuet Movie player
;
;   Compile with FASM 1.60 or above
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use64

    org   0x0

    db    'MENUET64'              ; Header identifier
    dq    0x01                    ; Version
    dq    START                   ; Start of code
    dq    image_end               ; Size of image
    dq    0x100000*10             ; Memory for app
    dq    0xffff0                 ; Rsp
    dq    0x00                    ; Prm 
    dq    0x00                    ; Icon

ipc_size equ 8192000

include "textbox.inc"

; 0x090000 - thread stack
; 0x0A0000 - data return area
; 0x0ffff0 - stack
; 0x100000 - read area

START:

    mov   rax , 141         ; Enable system font
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    call  draw_window       ; At first, draw the window

still:

    cmp   [ipc_memory+8],dword 16
    je    nofilereceived
    mov   [status],dword string_file
    mov   [prevstatus],dword 0xffffff
    call  draw_status
    mov   [ipc_memory+0],dword 00
    mov   [ipc_memory+8],dword 16
  nofilereceived:

    mov   rax , 5
    mov   rbx , 10
    int   0x60
    cmp   [makedelay],dword 0
    je    nomkdelay
    sub   [makedelay],dword 1
  nomkdelay:

    mov   rax , 11          ; Check for event
    int   0x60

    test  rax , 1           ; Window redraw
    jnz   window_event
    test  rax , 2           ; Keyboard press
    jnz   key_event
    test  rax , 4           ; Button press
    jnz   button_event

    cmp   [playstate],byte 1
    je    doplay

    jmp   still


window_event:

    call  draw_window
    jmp   still


key_event:

    mov   rax , 2          ; Read the key and ignore
    int   0x60

    jmp   still


doplay:

    ;
    ; Delay for next read
    ;
    cmp   [makedelay],dword 0
    jne   still

    ;
    ; Load file
    ;
    cmp   [loadpos],dword ipc_size
    jae   nosp

    cmp   [readprogress],byte 1
    je    draw_progress

    mov   [readprogress],byte 1

    mov   rax , 9
    mov   rbx , 2
    mov   rcx , [pid]
    mov   rdx , 0xA0000
    mov   [rdx+736],dword 0
    mov   r8  , 1024
    int   0x60

    movzx rax , byte [0xa0000+736]
    add   rax , 1
    mov   [targetcpu],rax

    mov   rax , 140
    mov   rbx , 2
    int   0x60
    cmp   [targetcpu],rbx
    jb    tcfine
    mov   [targetcpu],dword 0
  tcfine:

    mov   rdi , 0x100000
    mov   rcx , ipc_size/8
    mov   rax , 0
    cld
    rep   stosq

    mov   rax , 140
    mov   rbx , 3
    mov   rcx , readthread
    mov   rdx , 0x90000
    mov   rdi , [targetcpu]
    int   0x60    

    jmp   still

  draw_progress:

    mov   [status],dword string_buffering
    call  draw_status

    jmp   still

  nosp:

    mov   rax , [sendpos]
    imul  rax , 512
    mov   rbx , [filesize]
    add   rbx , ipc_size
    cmp   rax , rbx
    jb    noeof
    mov   [loadpos],dword 0
    mov   [restart],byte 0
    mov   [readprogress],dword 0
    mov   [playstate],dword 0
    mov   [status],dword string_file
    call  draw_status
    jmp   still
  noeof:

    call  check_player_start

    mov   [status],dword string_playing
    call  draw_status

    ; Possible change at check_player_start

    cmp   [makedelay],dword 0
    jne   still

    ;
    ; Send data
    ;
    mov   rax , 60
    mov   rbx , 2
    mov   rcx , [pid]
    mov   rdx , 0x100000
    mov   r8  , ipc_size
    int   0x60

    ; Command success

    cmp   rax , 0
    jne   nosendsuccess
    mov   [loadpos],dword 0
    mov   [restart],byte 0
    mov   [readprogress],dword 0
    jmp   commanddone
  nosendsuccess:

    ; Decoder not found -> restart

    cmp   rax , 1
    jne   norestart
    cmp   [restart],byte 1
    jne   norestart
    mov   [restart],byte 0
    mov   [pid],dword 0
    jmp   commanddone
  norestart:

    ; Decoder ipc full -> wait

  commanddone:

    ;
    ; Decoder scans for packet match
    ;
    mov   [makedelay],dword 10

    jmp   still



readthread:

    mov   [readprogress],byte 1

    mov   rax , 58
    mov   rbx , 0
    mov   rcx , [sendpos]
    mov   rdx , ipc_size/512
    mov   r8  , 0x100000
    ;add   r8  , [loadpos]
    mov   r9  , fileload
    int   0x60
    mov   [filesize],rbx

    cmp   [readprogress],dword 3
    je    readthread

    add   [sendpos],dword ipc_size/512
    add   [loadpos],dword ipc_size

    mov   [readprogress],byte 2

    mov   rax , 512
    int   0x60



update_scroll_position:

    ; Calculate new scroll position
    mov   rax , [filesize]
    mov   rbx , 512*100
    xor   rdx , rdx
    div   rbx
    cmp   rax , 0
    je    noupdatescroll
    mov   rbx , rax
    mov   rax , [sendpos]
    xor   rdx , rdx
    div   rbx
    mov   rbx , 99
    cmp   rax , rbx
    cmova rax , rbx
    add   rax , 300
    cmp   rax , [scroll_value]
    je    noupdatescroll
    ;
    mov   [scroll_value],rax
    call  draw_scroll
    ;
  noupdatescroll:

    ret



check_player_start:

    ;
    ; Start player
    ;
    cmp   [pid],dword 0
    jne   noplayerstart

    mov   rax , 256
    mov   rbx , filestart
    mov   rcx , ipcm
    int   0x60
    mov   [pid],rbx

    mov   [makedelay],dword 12 ; 1.2s delay before data

  noplayerstart:

    ret



button_event:

    mov   rax , 17
    int   0x60

    ; rax = status
    ; rbx = button id

    cmp   rbx , 0x10000001
    jne   no_application_terminate_button
    mov   rax , 0x200
    int   0x60
  no_application_terminate_button:

    cmp   rbx , 0x104
    jne   no_application_terminate_menu
    mov   rax , 0x200
    int   0x60
  no_application_terminate_menu:

    cmp   rbx , 0x102
    jne   no_decoder_start
    mov   [pid],dword 0
    call  check_player_start
    jmp   still
  no_decoder_start:

    cmp   rbx , 300                       ;  Vertical scroll 300-319
    jb    no_vertical_scroll
    cmp   rbx , 400
    ja    no_vertical_scroll
    mov   [scroll_value], rbx
    call  draw_scroll
    call  send_stop
    ; New read position
  waitforstop:
    mov   rax , 5
    mov   rbx , 2
    int   0x60
    cmp   [readprogress],dword 1
    je    waitforstop
    ; Calculate new position
    mov   rax , [filesize]
    mov   rbx , 100*512
    xor   rdx , rdx
    div   rbx
    mov   rbx , [scroll_value]
    sub   rbx , 300
    imul  rax , rbx
    mov   [sendpos],rax
    mov   [loadpos],dword 0
    ; Start player if needed
    mov   [restart],byte 1
    mov   rax , 5
    mov   rbx , 20
    int   0x60
    jmp   still
  no_vertical_scroll:

    cmp   rbx , 20
    jne   nofileopen
    mov   [playstate],byte 0
    call  send_stop
    mov   [restart],byte 1
    mov   [ipc_memory+0],dword 00
    mov   [ipc_memory+8],dword 16
    mov   [sendpos],dword 0
    call  dialog_open
    jmp   still
  nofileopen:

    cmp   rbx , 21
    jne   noplayon
    cmp   [ipc_memory+16],byte '/'
    jne   noplayon
    mov   [restart],byte 1
    mov   [playstate],byte 1
    mov   [loadpos],dword 0
    mov   [sendpos],dword 0
    mov   [scroll_value],dword 300
    call  draw_scroll
    jmp   still
  noplayon:

    cmp   rbx , 22
    jne   noplayoff
    cmp   [readprogress],byte 1
    jne   nostopping
    mov   [status],dword string_stopping
    call  draw_status
  nostopping:
    call  send_stop
  waitthreadstop:
    mov   rax , 5
    mov   rbx , 1
    int   0x60
    cmp   [readprogress],byte 1
    je    waitthreadstop
    mov   [restart],byte 1
    mov   [loadpos],dword 0
    mov   [sendpos],dword 0
    mov   [playstate],byte 0
    mov   [status],dword fileload
    call  draw_status
    jmp   still
  noplayoff:

    cmp   rbx , 11
    jne   no_textbox1
    mov   r14 , textbox1
    call  read_textbox
    jmp   still
  no_textbox1:

    jmp   still


send_stop:

    cmp   [pid],dword 0
    je    nostop

    mov   rax , 60
    mov   rbx , 2
    mov   rcx , [pid]
    mov   rdx , string_stop
    mov   r8  , 4
    int   0x60

  nostop:

    ret


dialog_open:

    mov   [parameter],byte '['

    ; Get my PID

    mov   rax , 111
    mov   rbx , 1
    int   0x60

    mov   rdi , parameter + 6
  newdec:
    mov   rbx , 10
    xor   rdx , rdx
    div   rbx
    add   rdx , 48
    mov  [rdi], dl
    dec   rdi
    cmp   rdi , parameter + 1
    jg    newdec

    ; Start fbrowser

    mov   rax , 256
    mov   rbx , file_search
    mov   rcx , parameter
    int   0x60

    ; Define IPC memory

    mov   rax , 60           ; ipc
    mov   rbx , 1            ; define memory area
    mov   rcx , ipc_memory   ; memory area pointer
    mov   rdx , 100          ; size of area
    int   0x60

    ret


draw_window:

    mov   rax , 12                           ; Beginning of window draw
    mov   rbx , 1
    int   0x60

    mov   rax , 0                            ; Draw window
    mov   rbx , (800-275) shl 32 + 275       ; X start & size
    mov   rcx , 230 shl 32 + 153+18*4        ; Y start & size
    mov   rdx , 0x0000000000f8f8f8           ; Type    & border color  
    mov   r8  , 0x0000000000000001           ; Flags (set as 1)
    mov   r9  , window_label                 ; 0 or label - asciiz
    mov   r10 , menu_struct                  ; 0 or pointer to menu struct
    int   0x60

    mov   rax , 4                            ; Display text
    mov   rbx , text1                        ; Pointer to text
    mov   rcx , 25                           ; X position
    mov   rdx , 58                           ; Y position
    mov   rsi , 0x000000                     ; Color
    mov   r9  , 1                            ; Font
    int   0x60
    mov   rax , 4                            ; Display text
    mov   rbx , text11                       ; Pointer to text
    mov   rcx , 25                           ; X position
    mov   rdx , 145                          ; Y position
    mov   rsi , 0x000000                     ; Color
    mov   r9  , 1                            ; Font
    int   0x60
    mov   rax , 4                            ; Display text
    mov   rbx , text2                        ; Pointer to text
    mov   rcx , 25                           ; X position
    mov   rdx , 145+18                       ; Y position
    mov   rsi , 0x000000                     ; Color
    mov   r9  , 1                            ; Font
    int   0x60
    mov   rax , 4                            ; Display text
    mov   rbx , text21                       ; Pointer to text
    mov   rcx , 25                           ; X position
    mov   rdx , 145+18*2                     ; Y position
    mov   rsi , 0x000000                     ; Color
    mov   r9  , 1                            ; Font
    int   0x60

    mov   [prevstatus],dword 0xffffff
    call  draw_status

    ; Define button
    mov   rax , 8
    mov   rbx , 025 shl 32 + 75
    mov   rcx , 110 shl 32 + 20
    mov   rdx , 20
    mov   r8  , 0
    mov   r9  , button_text_1
    int   0x60
    mov   r10 , rbx
    shl   r10 , 32
    add   rbx , r10
    inc   rdx
    mov   r9  , button_text_2
    int   0x60
    add   rbx , r10
    inc   rdx
    mov   r9  , button_text_3
    int   0x60

    ; Scroll

    call  draw_scroll

    mov   r14 , textbox1
    call  draw_textbox

    mov   rax , 12
    mov   rbx , 2
    int   0x60

    ret


draw_status:

    mov   rax , [status]
    cmp   rax , [prevstatus]
    je    nostatdraw

    mov   rax , 13
    mov   rbx , 25 shl 32 + 230
    mov   rcx , (145+18*3-3) shl 32 + 16
    mov   rdx , 0xf8f8f8
    int   0x60

    mov   rax , 4                            ; Display text
    mov   rbx , text3                        ; Pointer to text
    mov   rcx , 25                           ; X position
    mov   rdx , 145+18*3                     ; Y position
    mov   rsi , 0x000000                     ; Color
    mov   r9  , 1                            ; Font
    int   0x60

    mov   rax , 4                            ; Display text
    mov   rbx , [status]                     ; Pointer to text
    mov   rcx , 25+6*8                       ; X position
    mov   rdx , 145+18*3                     ; Y position
    mov   rsi , 0x000000                     ; Color
    mov   r9  , 1                            ; Font
    int   0x60

    mov   rax , [status]
    mov   [prevstatus],rax

  nostatdraw:

    call  update_scroll_position

    ret


draw_scroll:

    ; Scroll

    mov   rax , 113
    mov   rbx , 2
    mov   rcx , 300
    mov   rdx , 100
    mov   r8  , [scroll_value]
    mov   r9  , 85
    mov   r10 , 25
    mov   r11 , 75*3
    int   0x60

    ret


;
; Data area
;

filesize:   dq  0x0
loadpos:    dq  0x0
sendpos:    dq  0x0
pid:        dq  0x0
playstate:  dq  0x0
restart:    dq  0x0
makedelay:  dq  0x0

status:       dq  string_file
prevstatus:   dq  0x0
readprogress: dq  0x0 ; 0/1/2/3=start/running/stopped/new read
targetcpu:    dq  0x0

ipcm:         db  'IPC2',0
string_stop:  db  'STOP',0

textbox1:

    dq    0         ; Type
    dq    70        ; X position
    dq    180       ; X size
    dq    53        ; Y position
    dq    11        ; Button ID
    dq    13        ; Current text length
  filestart:
    db    '/fd/1/mplayer',0 ; text
    times 50 db 0
                   
scroll_value:   dq  300
button_text_1:  db  'FILE',0
button_text_2:  db  'PLAY',0
button_text_3:  db  'STOP',0
window_label:   db  'MOVIE PLAYER',0
file_search:    db  '/FD/1/FBROWSER   ',0
parameter:      db  '[000000]',0

text1:  db  'Decoder',0
text21: db  'Decoder: MediaPlayer 0.70',0
text11: db  'Video Support: MPEG-2(720x576,720x480)',0
text2:  db  'Audio Support: MP3(112-224kbps)',0
text3:  db  'Status:',0

string_playing:   db  'Playing',0
string_buffering: db  'Buffering',0
string_stopping:  db  'Stopping',0

menu_struct:               ; Menu Struct

    dq   0                 ; Version
    dq   0x100             ; Start value of ID to return ( ID + Line )
                           ; Returned when menu closes and
                           ; user made no selections.

    db   0,'FILE',0           ; ID = 0x100 + 1
    db   1,'Start Decoder',0  ; ID = 0x100 + 2
    db   1,'-',0              ; ID = 0x100 + 6
    db   1,'Quit',0           ; ID = 0x100 + 6

    db   255               ; End of Menu Struct


ipc_memory:

    dq  0x0    ; lock - 0=unlocked , 1=locked
    dq  16     ; first free position from ipc_memory

string_file:
fileload:

    db  'No movie file (.mpg) selected.'

    times 110 db 0


image_end:

