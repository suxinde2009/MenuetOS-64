;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Debug board for Menuet64
;
;   Compile with FASM 1.60 or above
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use64

    org    0x0

    db     'MENUET64'              ; 8 byte id
    dq     0x01                    ; header version
    dq     START                   ; start of code
    dq     IMAGE_END               ; size of image
    dq     0x200000                ; memory for app
    dq     0xffff0                 ; rsp
    dq     0x0,0x0                 ; I_Param , I_Icon

lines   equ 260

START:

    mov   rdi , text_area
    mov   rcx , 81*(lines+20)
    mov   rax , 0
    cld
    rep   stosb

    mov   rax , 141
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    call  draw_window

still:

    call  read_debug_board

    mov   rax , 23
    mov   rbx , 5
    int   0x60

    test  rax , 1b    ; Window redraw
    jnz   redraw

    test  rax , 10b   ; Key press
    jnz   keypress

    test  rax , 100b  ; Button press
    jnz   buttonpress

    jmp   still

redraw:

    call  draw_window
    jmp   still

keypress:

    mov   rax , 2
    int   0x60

    jmp   still

buttonpress:

    mov   rax , 17
    int   0x60

    ; rax = status
    ; rbx = button id

    cmp   rbx , 0x10000001
    jne   no_application_terminate
    mov   rax , 512
    int   0x60
  no_application_terminate:

    cmp   rbx , 1000
    jb    no_scroll
    cmp   rbx , 1400
    ja    no_scroll
    mov   [scroll_value], rbx
    call  draw_scroll
    call  draw_text
    jmp   still
  no_scroll:

    jmp   still


read_debug_board:

    mov   rax , 63
    mov   rbx , 2
    int   0x60

    ; rax = 0 : success
    ; rbx = character
    ; rcx = bytes left
    ; rax = 1 : no characters at board

    cmp   rax , 0
    jne   rdbl1

  rdbl2:

    mov   rax , [board_x] ; x
    mov   rsi , [board_y] ; y

    cmp   rbx , 15
    jb    no_character

    push  rax rsi
    imul  rsi , 81
    add   rax , rsi
    add   rax , text_area
    mov  [rax], bl
    pop   rsi rax

    ; Adjust X

    add   rax , 1

  no_character:

    cmp   rbx , 13   ; linefeed
    je    dolf

    cmp   rax , 79
    jb    xok
  dolf:
    mov   rax , 0
    add   rsi , 1
  xok:

    cmp   rsi , lines
    jbe   yok

    push  rbx rcx rsi
    mov   rdi , text_area
    mov   rsi , text_area+81
    mov   rcx , 81*(lines+1)
    cld
    rep   movsb
    pop   rsi rcx rbx

    mov   rsi , 1000+lines
    sub   rsi , [displaylines]

    cmp   [scroll_value],rsi
    je    noscrollsub
    cmp   [scroll_value],dword 1000
    jbe   noscrollsub
    sub   [scroll_value],dword 1
  noscrollsub:

    mov   rsi , lines

  yok:

    mov  [board_x], rax ; x
    mov  [board_y], rsi ; y

    ; Read next character

    mov   rax , 63
    mov   rbx , 2
    int   0x60
    mov   rdx , 0
    cmp   rax , rdx
    je    rdbl2

    call  draw_text
    call  draw_scroll

  rdbl1:

    ret


draw_window:

    mov   rax , 12
    mov   rbx , 1
    int   0x60

    mov   rax , 141
    mov   rbx , 3
    int   0x60
    and   rax , 0xff
    mov   [fontsize],rax

    mov   rax , 0
    mov   rbx , 15  *0x100000000 + 518
    mov   rcx , 280 *0x100000000 + 143
    mov   rdx , [fontsize]
    sub   rdx , 9
    imul  rdx , 9
    cmp   [fontsize],dword 9
    jne   nosubrcx
    sub   cx , 1
  nosubrcx:
    add   rcx , rdx
    mov   rdx , 0xffffff     ; type    & border color
    mov   r8  , 1b           ; draw buttons - close,full,minimize
    mov   r9  , window_label ; 0 or label - asciiz
    mov   r10 , 0            ; pointer to menu struct or 0
    int   0x60

    mov   rax , 111
    mov   rbx , 1
    int   0x60
    mov   rcx , rax
    mov   rax , 9
    mov   rbx , 2
    mov   rdx , process_info
    mov   r8  , 1000
    int   0x60

    call  calculate_displaylines
    call  draw_text
    call  draw_scroll

    mov   rax , 12
    mov   rbx , 2
    int   0x60

    ret


calculate_displaylines:

    mov   rax , [process_info+24]
    sub   rax , 40
    xor   rdx , rdx
    mov   rbx , [fontsize]
    add   rbx , 1
    div   rbx
    cmp   rax , [displaylines]
    je    nodlchange
    mov   [displaylines],rax
    mov   rax , 1000+lines
    sub   rax , [displaylines]
    mov   [scroll_value],rax
  nodlchange:

    ret


draw_text:

    cmp   [process_info+16],dword 150
    jb    nodtext
    cmp   [process_info+24],dword 100
    jb    nodtext

    mov   rax , 4
    mov   rbx , [scroll_value]
    sub   rbx , 1000
    imul  rbx , 81
    add   rbx , text_area
    mov   rcx , 10
    mov   rdx , 35-3
    mov   rsi , 0x000000
    mov   r9  , 1

    mov   rdi , [displaylines]
    imul  rdi , 81
    add   rdi , rbx

  newline:

    push  rax rbx rcx rdx r8 r9 r10 rdi

    mov   rax , 13
    mov   rbx , [process_info+16]
    sub   rbx , 10+25
    mov   rcx , 10 shl 32
    add   rbx , rcx
    mov   rcx , rdx
    sub   rcx , 1
    shl   rcx , 32
    add   rcx , 12
    mov   rdx , 0xffffff
    int   0x60

    pop   rdi r10 r9 r8 rdx rcx rbx rax

    push  rax rbx rcx rdx
    mov   rax , [process_info+16]
    sub   rax , 10+26
    xor   rdx , rdx
    mov   rbx , 6
    div   rbx
    mov   r11 , rax
    pop   rdx rcx rbx rax

    push  qword [rbx+r11]
    mov   [rbx+r11],byte 0
    int   0x60
    pop   qword [rbx+r11]

    add   rbx , 81
    add   rdx , [fontsize]
    add   rdx , 1

    cmp   rbx , rdi
    jb    newline

  nodtext:

    ret


draw_scroll:

    cmp   [process_info+16],dword 150
    jb    nodscroll
    cmp   [process_info+24],dword 100
    jb    nodscroll

    mov   rax , 113
    mov   rbx , 1
    mov   rcx , 1000
    mov   rdx , lines+1
    sub   rdx , [displaylines]
    mov   r8  , [scroll_value]
    mov   r9  , [process_info+16]
    sub   r9  , 23
    mov   r10 , 29
    mov   r11 , [fontsize]
    add   r11 , 1
    imul  r11 , [displaylines]
    add   r11 , 1
    int   0x60

  nodscroll:

    ret


;
; Data area
;

window_label:

    db  'DEBUG BOARD',0

board_x:   dq   0
board_y:   dq   lines
fontsize:  dq   0

displaylines: dq 20
scroll_value: dq 1000

process_info: times 1024 db ?

text_area:


IMAGE_END:

