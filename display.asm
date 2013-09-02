;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   64 bit Menuet display.asm
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
    dq    0x100000                ; Memory for app
    dq    0xffff0                 ; Rsp
    dq    0x00                    ; Prm
    dq    0x00                    ; Icon


linelen     equ  (textline-texts)
vert        equ  30
vertb       equ  10
lineheight  equ  15
background  equ  0xf2f2f2


START:

    mov   rax , 141         ; Enable system font
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    mov   r10 , 1
    mov   rdi , text
  newl:
    mov   rsi , texts
    mov   rcx , linelen
    cld
    rep   movsb
    mov   rax , r10
    xor   rdx , rdx
    mov   rbx , 10
    div   rbx
    add   al , 48
    add   dl , 48
    mov   [rdi-linelen+0],al
    mov   [rdi-linelen+1],dl
    add   r10 , 1
    cmp   r10 , 99
    jbe   newl

    call  draw_window       ; At first, draw the window

still:

    mov   rax , 10          ; Wait here for event
    int   0x60

    test  rax , 1           ; Window redraw
    jnz   window_event
    test  rax , 2           ; Keyboard press
    jnz   key_event
    test  rax , 4           ; Button press
    jnz   button_event

    jmp   still

window_event:

    call  draw_window
    jmp   still

key_event:

    mov   rax , 2          ; Read the key and ignore
    int   0x60

    cmp   rbx , 0
    jne   still

    jmp   still

button_event:

    mov   rax , 17
    int   0x60

    ; rax = status
    ; rbx = button id

    cmp   rbx , 22
    jne   nosetgraphics
    cmp   [mode1],dword 0
    je    still

    mov   rax , 144
    mov   rbx , 4
    mov   rcx , [mode1]
    mov   rdx , [mode2]
    mov   r8  , [mode3]
    mov   r9  , [mode4]
    mov   r10 , [mode5]
    mov   r11 , [mode6]
    int   0x60

    jmp   still
  nosetgraphics:

    cmp   rbx , 0x10000
    jb    no_vertical_scroll
    cmp   rbx , 0x10000+512
    ja    no_vertical_scroll
    mov  [vscroll_value], rbx
    call  draw_vertical_scroll
    call  draw_modes
    jmp   still
  no_vertical_scroll:

    cmp   rbx , 100
    jb    nomodeselect
    cmp   rbx , 150
    ja    nomodeselect
    sub   rbx , 100
    add   rbx , [vscroll_value]
    sub   rbx , 0x10000
    mov   rcx , rbx
    mov   rax , 144
    mov   rbx , 3
    int   0x60
    cmp   rax , 0
    jne   still
    mov   [mode1],rcx
    mov   [mode2],rdx
    mov   [mode3],r8
    mov   [mode4],r9
    mov   [mode5],r10
    mov   [mode6],r11
    call  draw_selected_mode
    jmp   still
  nomodeselect:

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

    mov   rax , 12                           ; Beginning of window draw
    mov   rbx , 1
    int   0x60

    mov   rax , 0                            ; Draw window
    mov   rbx , 190 shl 32 + 375             ; X start & size
    mov   rcx , 072 shl 32 + 324+vert-vertb  ; Y start & size
    mov   rdx , background                   ; Type    & border color
    mov   r8  , 0x0000000000000001           ; Flags (set as 1)
    mov   r9  , window_label                 ; 0 or label - asciiz
    mov   r10 , menu_struct                  ; 0 or pointer to menu struct
    int   0x60

    call  read_modes

    call  draw_modes

    mov   rax , 144
    mov   rbx , 1
    int   0x60
    mov   rbx , 'Disabled'
    mov   rcx , 'Enabled '
    cmp   rax , 1
    cmove rbx , rcx
    mov   [textinit+15],rbx

    mov   rax , 4                            ; Display text
    mov   rbx , textexp                      ; Pointer to text
    mov   rcx , 32                           ; X position
    mov   rdx , 55+vert-8                    ; Y position
    mov   rsi , 0x000000                     ; Color
    mov   r9  , 1                            ; Font
    int   0x60
    sub   rdx , 24
    add   rcx , 2*6
    mov   rax , 4                            ; Display text
    mov   rbx , textinit                     ; Pointer to text
    int   0x60

    mov   rax , 4                            ; Display text
    mov   rbx , text2                        ; Pointer to text
    mov   rcx , 32                           ; X position
    mov   rdx , 275+vert-vertb               ; Y position
    mov   rsi , 0x000000                     ; Color
    mov   r9  , 1                            ; Font
    int   0x60
    add   rdx , 16
    mov   rax , 4                            ; Display text
    mov   rbx , text22                       ; Pointer to text
    int   0x60

    call  draw_vertical_scroll

    ; Define button
    mov   rax , 8
    mov   rbx , 233 shl 32 + 110
    mov   rcx , (240+vert-vertb) shl 32 + 20
    mov   rdx , 22
    mov   r8  , 0
    mov   r9  , button_text
    int   0x60

    call  draw_selected_mode

    mov   rax , 12                           ; End of window draw
    mov   rbx , 2
    int   0x60

    ret


draw_selected_mode:

    cmp   [mode1],dword 0
    je    noselmode

    mov   rax , [mode1]
    mov   rbx , 4
    mov   r14 , textsel+13
    mov   [r14-3],dword '    '
    call  set2num
    mov   rax , [mode2]
    mov   rbx , 4
    mov   r14 , textsel+18
    mov   [r14-3],dword '    '
    call  set2num
    mov   rax , [mode3]
    xor   rdx , rdx
    mov   rbx , 100
    div   rbx
    mov   rbx , 3
    mov   r14 , textsel+23
    mov   [r14-2], word '  '
    call  set2num

  noselmode:

    mov   rax , 13
    mov   rbx , 30 shl 32 + 6*30
    mov   rcx , (246+vert-4-vertb) shl 32 + 16
    mov   rdx , background
    int   0x60

    mov   rax , 4                            ; Display text
    mov   rbx , textsel                      ; Pointer to text
    mov   rcx , 32                           ; X position
    mov   rdx , 246+vert-vertb               ; Y position
    mov   rsi , 0x000000                     ; Color
    mov   r9  , 1                            ; Font
    int   0x60

    ret






draw_vertical_scroll:

    ; Vertical scroll
    mov   rax , 113
    mov   rbx , 1
    mov   rcx , 0x10000
    mov   rdx , 100-10
    mov   r8  , [vscroll_value]
    mov   r9  , 330
    mov   r10 , 64+vert
    mov   r11 , lineheight*10-1 ; 200
    int   0x60

    mov   rax , 38
    mov   rbx , 32
    mov   rcx , r10
    dec   rcx
    mov   rdx , r9
    add   rdx , 12
    mov   r8  , r10
    add   r8  , r11
    add   r8  , 1
    mov   r9  , 0;xc0d0ff
    push  r8
    mov   r8  , rcx
    int   0x60
    pop   r8
    push  rcx
    mov   rcx , r8
    int   0x60
    pop   rcx
    push  rdx
    mov   rdx , rbx
    int   0x60
    pop   rdx

    ret


draw_modes:

    mov   rax , 4                            ; Display text
    mov   rbx , [vscroll_value]
    sub   rbx , 0x10000
    imul  rbx , linelen
    add   rbx , text                         ; Pointer to text
    mov   rcx , 32                           ; X position
    mov   rdx , 64+vert                      ; Y position
    mov   rsi , 0x000000                     ; Color
    mov   r9  , 1                            ; Font
    mov   r10 , 10
    mov   r12 , 100
  newline:
    ; Clear
    push  rax rbx rcx rdx
    mov   rax , 13
    mov   rbx , rcx
    add   rbx , 1
    shl   rbx , 32
    add   rbx , 298-1
    mov   rcx , rdx
    shl   rcx , 32
    add   rcx , lineheight
    mov   rdx , 0xffffff
    int   0x60
    pop   rdx rcx rbx rax
    ; Button
    push  rax rbx rcx rdx r8 r9
    ; Define button
    mov   rax , 8
    mov   rbx , rcx
    add   rbx , 1
    shl   rbx , 32
    add   rbx , 298-1
    mov   rcx , rdx
    shl   rcx , 32
    add   rcx , lineheight
    mov   rdx , r12
    mov   r8  , 1 shl 63
    mov   r9  , 0
    int   0x60
    add   r12 , 1
    pop   r9 r8 rdx rcx rbx rax
    ; Text
    push  rcx rdx
    add   rcx , 12
    add   rdx , 3+1
    int   0x60
    pop   rdx rcx
    add   rdx , lineheight
    add   rbx , 31+20
    dec   r10
    jnz   newline



read_modes:

    mov   r15 , 0
    mov   rdi , text

  morereadmode:

    mov   rax , 144
    mov   rbx , 3
    mov   rcx , r15
    int   0x60

    cmp   rax , 0
    jne   nomoremodes

    mov   rax , rcx
    mov   rbx , 4
    mov   r14 , rdi
    add   r14 , 8
    call  set2num
    mov   rax , rdx
    mov   rbx , 4
    mov   r14 , rdi
    add   r14 , 14
    call  set2num
    mov   rax , r8
    xor   rdx , rdx
    mov   rbx , 100
    div   rbx
    mov   rbx , 4
    mov   r14 , rdi
    add   r14 , 19
    call  set2num
    mov   rax , r9
    mov   rbx , 16
    mov   r14 , rdi
    add   r14 , 32
    mov   [hex],byte 1
    call  set2num
    mov   [hex],byte 0
    mov   rax , r10
    mov   rbx , 5
    mov   r14 , rdi
    add   r14 , 39
    call  set2num
    mov   rax , r11
    imul  rax , 8
    mov   rbx , 3
    mov   r14 , rdi
    add   r14 , 44
    call  set2num

    add   rdi , linelen

    add   r15 , 1

    cmp   [rdi], byte ' '
    jae   morereadmode

  nomoremodes:

    ret




set2num:

    push  rax rbx rcx rdx r14

    mov   rcx , 10
    mov   rdx , 16
    cmp   [hex],byte 1
    cmove rcx , rdx

  news2n:
    xor   rdx , rdx
    div   rcx
    add   dl , 48
    cmp   dl , '9'
    jbe   dlfine
    add   dl , 'A'-'9'+1
  dlfine:
    mov   [r14],dl
    cmp   rax , 0
    je    noms2n
    dec   r14
    dec   rbx
    jnz   news2n
  noms2n:

    cmp   [hex],byte 1
    jne   nohexst
    mov   [r14-2],word '0x'
  nohexst:

    pop   r14 rdx rcx rbx rax

    ret





; Data area

window_label:

    db    'DISPLAY',0     ; Window label

textsel:

    db    'Selected: ----x---- @ --Hz ',0

textexp:

    db    '  Num  ResX  ResY   Hz  LFB-address Scanline bpp ',0

textinit:

    db    'Driver status: Disabled   ',0


texts:

    db    '01.   --                                          ',0

textline:

text2:   db    'When selecting resolution above boot-resolution,',0
text22:  db    'transparency will be disabled.',0

button_text:   db  'SET',0

hex:           dq  0x0
vscroll_value: dq  0x10000

mode1: dq 0x0
mode2: dq 0x0
mode3: dq 0x0
mode4: dq 0x0
mode5: dq 0x0
mode6: dq 0x0



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


text:

    times (linelen*101) db ?

image_end:

