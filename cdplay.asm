;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   64 bit Menuet CD player
;
;   Compile with FASM 1.60 or above
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use64

    org   0x0

    db    'MENUET64'              ; Header identifier
    dq    0x01                    ; Version
    dq    START                   ; Start of code
    dq    image_end               ; Size of image
    dq    0x200000                ; Memory for app
    dq    0xffff0                 ; Esp
    dq    0x00                    ; Prm
    dq    0x00                    ; Icon


playlist      equ 0x080000
tocposition   equ 0x100000
tracklisttime equ 0x0a0000

ply equ 20

START:

    mov   rax , 141
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    call  draw_window       ; At first, draw the window

still:

    mov   rax , 23         ; Wait here for event
    mov   rbx , 5
    int   0x60

    test  rax , 0x1         ; Window redraw
    jnz   window_event
    test  rax , 0x2         ; Keyboard press
    jnz   key_event
    test  rax , 0x4         ; Button press
    jnz   button_event

    call  check_mouse

    jmp   still


check_mouse:

    mov   rax , 111
    mov   rbx , 2
    int   0x60
    cmp   rax , 0
    jne   nomousedown

    mov   rax , 37
    mov   rbx , 2
    int   0x60

    cmp   rax , 0
    je    nomousedown

    mov   rax , 37
    mov   rbx , 1
    int   0x60

    mov   rbx , rax
    shr   rax , 32
    and   rbx , 0xffffff

    cmp   rax , 22
    jb    nomousedown
    cmp   rax , 206
    ja    nomousedown
    cmp   rbx , 153+ply
    jb    nomousedown
    cmp   rbx , 246+ply
    ja    nomousedown

    sub   rbx , 153+ply
    mov   rax , rbx
    xor   rdx , rdx
    mov   rbx , 12
    div   rbx
    add   rax , [sc3]
    sub   rax , 3000

    cmp   rax , [playlistpointer]
    je    nomousedown

    mov   r12 , rax
    shl   r12 , 1
    add   r12 , tracklisttime
    cmp   r12 , [tracklisttimelast]
    jae   noplaymse

    mov   [playlistpointer],rax

    push  r12
    call  draw_playlist
    pop   r12

    cmp   [tracklisttimelast],dword 0
    je    noplaymse

    mov   rax , 114
    mov   rbx , 1
    movzx rcx , byte [r12]
    movzx rdx , byte [r12+1]
    mov   r8  , 1
    mov   r9  , [cdl]
    cmp   rcx , r9
    jae   noplaymse
    mov   r10 , 1
    mov   r11 , 1
    cmp   r9  , rcx
    jb    noplaymse
    int   0x60
  noplaymse:

    mov   rax , 5
    mov   rbx , 1
    int   0x60

  nomousedown:

    ret



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
    je    application_terminate
    cmp   rbx , 0x105
    je    application_terminate
    jmp   no_application_terminate
  application_terminate:
    ; Stop
    mov   rax , 114
    mov   rbx , 3
    int   0x60
    ; Terminate
    mov   rax , 0x200
    int   0x60
  no_application_terminate:

    cmp   rbx , 0x102
    jb    no_length
    cmp   rbx , 0x103
    ja    no_length
    sub   rbx , 0x102
    imul  rbx , 40
    add   rbx , 40
    mov   [cdl],rbx
    call  display_position
    jmp   still
  no_length:

    cmp   rbx , 1000
    jb    noscroll1
    cmp   rbx , 1900
    ja    noscroll1
    mov   [sc1],rbx
    call  scroll1
    call  display_position
    jmp   still
  noscroll1:

    cmp   rbx , 2000
    jb    noscroll2
    cmp   rbx , 2900
    ja    noscroll2
    mov   [sc2],rbx
    call  scroll2
    call  display_position
    jmp   still
  noscroll2:

    cmp   rbx , 4
    jne   noreadtoc
    ; Clear playlist area
    mov   rdi , playlist
    mov   rax , 0
    mov   rcx , 32768
    cld
    rep   stosb
    ;
    mov   [tocposition],dword 0
    ; ReadTOC
    mov   rax , 114
    mov   rbx , 2
    mov   rcx , tocposition
    int   0x60
    ; Analyze toc
    mov   rsi , tocposition
    movzx rcx , word [rsi]
    xchg  cl  , ch
    add   rcx , 4
    add   rcx , rsi
    add   rsi , 4
    mov   rdi , playlist
    mov   r8  , 1 ; count
    mov   r15 , tracklisttime
    mov   [cdl],dword 10
  newaudiosearch:
    cmp   [rsi+3],byte 0
    je    noaudioentry
    cmp   [rsi+3],byte 62
    ja    noaudioentry

    mov   [rdi],dword 'Trac'
    mov   [rdi+4],dword 'k   '

    xor   rdx , rdx
    mov   rax , r8
    mov   rbx , 10
    div   rbx
    add   al , 48
    add   dl , 48
    mov   [rdi+6],al
    mov   [rdi+7],dl
    mov   [rdi+8],dword ' Sta'
    mov   [rdi+12],dword 'rt  '
    inc   r8

    movzx rax , byte [rsi+8]
    cmp   [cdl],al
    jae   cdlfine
    mov   [cdl],al
    ;inc   byte [cdl]
  cdlfine:
    mov   [r15],al
    inc   r15
    xor   rdx , rdx
    mov   rbx , 10
    div   rbx
    add   al , 48
    add   dl , 48
    mov   [rdi+15],al
    mov   [rdi+16],dl
    ;
    mov   [rdi+17],byte ':'
    ;
    movzx rax , byte [rsi+9]
    mov   [r15],al
    inc   r15
    xor   rdx , rdx
    mov   rbx , 10
    div   rbx
    add   al , 48
    add   dl , 48
    mov   [rdi+18],al
    mov   [rdi+19],dl

    mov   [rdi+20],dword ' Len'
    mov   [rdi+24],dword ' --:'
    mov   [rdi+28],dword '--'

    add   rdi , 128

  noaudioentry:
    add   rsi , 11
    cmp   rsi , rcx
    jb    newaudiosearch

    mov   [tracklisttimelast],r15

    ; Durations

    mov   r15 , tracklisttime
    mov   rdi , playlist
  newduration:
    mov   rcx , 0
    movzx rax , byte [r15+3]
    cmp   al  , [r15+1]
    jae   subfine
    add   rax , 60
    mov   rcx , 1
  subfine:
    sub   al  , [r15+1]
    xor   rdx , rdx
    mov   rbx , 10
    div   rbx
    add   al , 48
    add   dl , 48
    mov   [rdi+28],al
    mov   [rdi+29],dl

    movzx rax , byte [r15+2]
    cmp   al  , [r15]
    jb    durationdone
    sub   al  , [r15]
    sub   al  , cl
    xor   rdx , rdx
    mov   rbx , 10
    div   rbx
    add   al , 48
    add   dl , 48
    mov   [rdi+25],al
    mov   [rdi+26],dl
    add   rdi , 128
    add   r15 , 2
    cmp   r15 , [tracklisttimelast]
    jb    newduration
  durationdone:

    ;
    mov   [sc3],dword 3000
    call  draw_playlist
    call  draw_scroll_playlist
    jmp   still
  noreadtoc:

    ; Playlist scroll
    cmp   rbx , 3000
    jb    noscroll3
    cmp   rbx , 3900
    ja    noscroll3
    mov   [sc3],rbx
    call  draw_playlist
    call  draw_scroll_playlist
    jmp   still
  noscroll3:


    cmp   rbx , 1
    jne   noplay

    ; Play

    mov   rax , 114
    mov   rbx , 1
    mov   rcx , [sc1]
    sub   rcx , 1000
    mov   rdx , [sc2]
    sub   rdx , 2000
    ; from min 0 - sec 2
    cmp   rcx , 0
    jne   nomin0
    cmp   rdx , 2
    jae   nomin0
    mov   rdx , 2
  nomin0:
    mov   r8  , 1
    mov   r9  , [cdl]
    mov   r10 , 1
    mov   r11 , 1
    int   0x60

    jmp   still
  noplay:

    cmp   rbx , 2
    jne   nostop

    ; Stop

    mov   rax , 114
    mov   rbx , 3
    int   0x60

    jmp   still
  nostop:

    cmp   rbx , 3
    jne   noopen

    ; Open tray

    mov   rax , 114
    mov   rbx , 4
    int   0x60

    jmp   still
  noopen:

    jmp   still


display_position:

    mov   rax , 13
    mov   rbx , 20 * 0x100000000 + 200
    mov   rcx , 50 * 0x100000000 + 40
    mov   rdx , 0x000000
    int   0x60

    ; Seconds

    mov   rax , [sc2]
    sub   rax , 2000
    xor   rdx , rdx
    mov   rbx , 10
    div   rbx
    push  rax
    mov   r8  , rdx
    mov   r13 , 170
    mov   r14 , 65
    call  cdnumber
    pop   r8
    mov   r13 , 158
    mov   r14 , 65
    call  cdnumber

    ; Minutes

    mov   rax , [sc1]
    sub   rax , 1000
    xor   rdx , rdx
    mov   rbx , 10
    div   rbx
    push  rax
    mov   r8  , rdx
    mov   r13 , 140
    mov   r14 , 65
    call  cdnumber
    pop   rax
    xor   rdx , rdx
    mov   rbx , 10
    div   rbx
    mov   r8  , rax
    mov   r13 , 116
    mov   r14 , 65
    push  rdx
    call  cdnumber
    pop   r8
    mov   r13 , 128
    mov   r14 , 65
    call  cdnumber

    ret

cdnumber:

    shl   r13 , 32
    shl   r14 , 32

    imul  r8  , 7
    add   r8  , lines
    mov   r9  , coord
    mov   r10 , 7
  newline2:
    cmp  [r8], byte 1
    jne   nonewline
    mov   rax , 13
    mov   rbx , [r9]
    mov   rcx , [r9+8]
    mov   rdx , 0xffffff
    add   rbx , r13
    add   rcx , r14
    int   0x60
  nonewline:
    inc   r8
    add   r9 , 16
    dec   r10
    jnz   newline2

    ret


draw_window:

    mov   rax , 0xC                          ; Beginning of window draw
    mov   rbx , 0x1
    int   0x60

    mov   rax , 0x0                          ; Draw window
    mov   rbx , 0x0000011600000000 + 240     ; x start & size
    mov   rcx , 0x0000005000000000 + 306     ; y start & size
    mov   rdx , 0x0000000000ffffff           ; type    & border color
    mov   r8  , 0x0000000000000001           ; draw flags
    mov   r9  , window_label                 ; 0 or label - asciiz
    mov   r10 , menu_struct                  ; 0 or pointer to menu struct
    int   0x60

    mov   rax , 8
    mov   rbx , 20 * 0x100000000 + 67
    mov   rcx , 140 * 0x100000000 + 20
    push  rax rbx
    mov   rax , 141
    mov   rbx , 3
    int   0x60
    cmp   ax  , 10
    jbe   yfine
    inc   rcx
  yfine:
    pop   rbx rax
    mov   rdx , 1
    mov   r8  , 0
    mov   r9  , button1
    int   0x60

    mov   rax , 8
    mov   rbx ,  87 * 0x100000000 + 67
    mov   rdx , 2
    mov   r8  , 0
    mov   r9  , button2
    int   0x60

    mov   rax , 8
    mov   rbx , 154 * 0x100000000 + 67
    mov   rdx , 3
    mov   r8  , 0
    mov   r9  , button3
    int   0x60

    call  display_position

    call  scroll1
    call  scroll2

    call  draw_playlist
    call  draw_scroll_playlist

    mov   rax , 8
    mov   rbx , 19 * 0x100000000 + 202
    mov   rcx , 270 shl 32 + 17
    mov   rdx , 4
    mov   r8  , 0
    mov   r9  , button4
    int   0x60

    mov   rax , 0xC                          ; End of window draw
    mov   rbx , 0x2
    int   0x60

    ret


draw_scroll_playlist:

    mov   rax , 113
    mov   rbx , 1
    mov   rcx , 3000
    mov   rdx , 60
    mov   r8  , [sc3]
    mov   r9  , 208
    mov   r10 , 151+ply
    mov   r11 , 96
    int   0x60

    ret



draw_playlist:

    push  rax rbx rcx rdx rsi r9 r10

    mov   rax , 38
    mov   rbx , 20
    mov   rcx , 150+ply
    mov   rdx , 220
    mov   r8  , 248+ply
    mov   r9  , 0x000000
    ;push  rbx
    ;mov   rbx , rdx
    ;int   0x60
    ;pop   rbx
    push  rdx
    mov   rdx , rbx
    int   0x60
    pop   rdx
    push  rcx
    mov   rcx , r8
    int   0x60
    pop   rcx
    push  r8
    mov   r8 , rcx
    int   0x60
    pop   r8

    mov   rax , 4
    mov   rbx , [sc3]
    sub   rbx , 3000
    imul  rbx , 128
    add   rbx , playlist
    mov   rcx , 24
    mov   rdx , 154+ply
    mov   rsi , 0x000000
    mov   r9  , 1
    mov   r10 , 0
  dpl1:
    push  rax rbx rcx rdx
    mov   rax , 13
    mov   rbx , rcx
    mov   rcx , rdx
    dec   rbx
    shl   rbx , 32
    sub   rcx , 2
    shl   rcx , 32
    add   rbx , 6*30+3
    add   rcx , 11
    mov   rdx , 0xffffff
    mov   rax , [sc3]
    sub   rax , 3000
    add   rax , r10
    cmp   rax , [playlistpointer]
    jne   nocurrentselected
    mov   rdx , 0xe0e0e0
  nocurrentselected:
    mov   rax , 13
    int   0x60
    pop   rdx rcx rbx rax
    push  qword [rbx+30]
    mov   [rbx+30],byte 0
    int   0x60
    pop   qword [rbx+30]
    inc   r10
    add   rdx , 12
    add   rbx , 128
    cmp   rdx , 12*8+154+ply
    jb    dpl1

    pop   r10 r9 rsi rdx rcx rbx rax

    ret


scroll1:

    mov   rax , 113
    mov   rbx , 2
    mov   rcx , 1000
    mov   rdx , [cdl]
    mov   r8  , [sc1]
    mov   r9  , 100
    mov   r10 , 20
    mov   r11 , 200
    int   0x60

    ret


scroll2:

    mov   rax , 113
    mov   rbx , 2
    mov   rcx , 2000
    mov   rdx ,  60
    mov   r8  , [sc2]
    mov   r9  , 118
    mov   r10 , 20
    mov   r11 , 200
    int   0x60

    ret


; Data area

window_label: db  'CD PLAYER',0

button1:  db  'PLAY',0
button2:  db  'STOP',0
button3:  db  'OPEN',0
button4:  db  'READ TRACKS',0

sc1:   dq 1000
sc2:   dq 2000
sc3:   dq 3000
cdl:   dq 40

playlistpointer:   dq  0x0
tracklisttimelast: dq  0x0

start_minute: dq 0x0
start_second: dq 0x0

lines:  db  1,1,1,0,1,1,1
        db  0,0,1,0,0,1,0
        db  1,0,1,1,1,0,1
        db  1,0,1,1,0,1,1
        db  0,1,1,1,0,1,0
        db  1,1,0,1,0,1,1
        db  1,1,0,1,1,1,1
        db  1,0,1,0,0,1,0
        db  1,1,1,1,1,1,1
        db  1,1,1,1,0,1,1

coord:  dq  1  * 0x100000000 + 8
        dq  0  * 0x100000000 + 1
        dq  0  * 0x100000000 + 1
        dq  1  * 0x100000000 + 4
        dq  9  * 0x100000000 + 1
        dq  1  * 0x100000000 + 4
        dq  1  * 0x100000000 + 8
        dq  5  * 0x100000000 + 1
        dq  0  * 0x100000000 + 1
        dq  6  * 0x100000000 + 4
        dq  9  * 0x100000000 + 1
        dq  6  * 0x100000000 + 4
        dq  1  * 0x100000000 + 8
        dq  10 * 0x100000000 + 1

menu_struct:               ; Menu Struct

    dq   0                 ; Version

    dq   0x100             ; Start value of ID to return ( ID + Line )

    db   0,'FILE  ',0      ; ID = 0x100 + 1
    db   1,'40 minutes',0
    db   1,'80 minutes',0
    db   1,'-',0
    db   1,'Quit',0

    db   255               ; End of Menu Struct

image_end:

