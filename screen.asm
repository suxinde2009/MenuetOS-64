;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Screen.asm for Menuet
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
    dq    0x800000                ; Memory for app
    dq    0x7ffff0                ; Esp
    dq    0x00                    ; Prm
    dq    0x00                    ; Icon

START:

    mov   rax , 141
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    mov   rax , 26
    mov   rbx , 3
    mov   rcx , image_end
    mov   rdx , 256
    int   0x60

    mov   rax ,[image_end+4*8]
    mov  [resolution_x] , rax

    mov   rax ,[image_end+5*8]
    mov  [resolution_y] , rax

    call  draw_window       ; At first, draw the window

still:

    mov   rax , 23          ; Wait here for event
    mov   rbx , 100
    int   0x60

    test  rax , 0x1         ; Window redraw
    jnz   window_event
    test  rax , 0x2         ; Keyboard press
    jnz   key_event
    test  rax , 0x4         ; Button press
    jnz   button_event

    call  draw_screen

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

    cmp   rbx , 0x102
    jne   no_application_terminate_menu
    mov   rax , 0x200
    int   0x60
  no_application_terminate_menu:

    cmp   rbx , 0x10
    je    save_screen


    jmp   still


draw_window:

    mov   rax , 0xC                          ; Beginning of window draw
    mov   rbx , 0x1
    int   0x60

    mov   rax , 0x0                          ; Draw window
    mov   rbx , 0x0000009000000000           ; x start & size
    mov   rcx , 0x0000006000000000           ; y start & size

    mov   rsi ,[resolution_x]
    shr   rsi , 2
    add   rsi , 20+21
    add   rbx , rsi

    mov   rsi ,[resolution_y]
    shr   rsi , 2
    add   rsi , 50+20+21
    add   rcx , rsi

    mov   rdx , 0x0000000000FFFFFF           ; type    & border color
    mov   r8  , 0x0000000000000001           ; draw flags
    mov   r9  , window_label                 ; 0 or label - asciiz
    mov   r10 , menu_struct                  ; 0 or pointer to menu struct
    int   0x60

    mov   rax , 8
    mov   rbx ,[resolution_x]
    shr   rbx , 2
    mov   r8  , 20 * 0x100000000
    add   rbx , r8
    mov   rcx ,[resolution_y]
    shr   rcx , 2
    add   rcx , 60
    shl   rcx , 32
    add   rcx , 16

    push  rax rbx
    mov   rax , 141
    mov   rbx , 3
    int   0x60
    cmp   ax  , 9
    je    nobinc
    add   rcx , 2
  nobinc:
    pop   rbx rax

    mov   rdx , 0x10
    mov   r8  , 0
    mov   r9  , button_text
    int   0x60

    call  draw_screen

    mov   rax , 0xC                          ; End of window draw
    mov   rbx , 0x2
    int   0x60

    ret

save_screen:

    mov   rax , 111
    mov   rbx , 1
    int   0x60

    mov   rcx , rax
    push  rcx
    mov   rax , 124
    mov   rbx , 1
    int   0x60

    mov   rax , 5
    mov   rbx , 100
    int   0x60

    mov   rsi , bmpheader
    mov   rdi , 0x100000
    mov   rcx , 60
    cld
    rep   movsb

    mov   eax , [resolution_x]
    mov   [0x100000+0x12],eax
    mov   eax , [resolution_y]
    mov   [0x100000+0x16],eax

    mov   rcx , 0
    mov   rdx , 0

    mov   rdi , [resolution_x]
    imul  rdi , [resolution_y]
    imul  rdi , 3
    add   rdi , 0x100000+54

  getpixely:

    sub   rdi , [resolution_x]
    sub   rdi , [resolution_x]
    sub   rdi , [resolution_x]

    push  rdi

  getpixel:

    mov   rax , 35
    mov   rbx , 1
    int   0x60

    mov  [rdi],ax
    shr   rax , 16
    mov  [rdi+2],al
    add   rdi ,3
    inc   rcx
    cmp   rcx ,[resolution_x]
    jb    getpixel

    pop   rdi

    mov   rcx , 0
    inc   rdx
    cmp   rdx ,[resolution_y]
    jb    getpixely

    mov   rax , 124
    mov   rbx , 2
    pop   rcx
    int   0x60

    call  draw_window

    ; Delete

    mov   rax , 58
    mov   rbx , 2
    mov   rcx , 0
    mov   rdx , 1024*768*3
    mov   r8  , 0x100000
    mov   r9  , path
    int   0x60

    ; Save

    mov   rax , 58
    mov   rbx , 1
    mov   rcx , 0
    mov   rdx ,[resolution_x]
    imul  rdx ,[resolution_y]
    imul  rdx , 3
    add   rdx , 54
    mov   r8  , 0x100000
    mov   r9  , path
    int   0x60

    jmp   still


draw_screen:

    mov   rcx , 0
    mov   rdx , 0

  newpix:

    push  rcx
    push  rdx
    imul  rcx , 4
    imul  rdx , 4
    mov   rax , 35
    mov   rbx , 1
    int   0x60
    pop   rdx
    pop   rcx

    push  rcx
    push  rdx
    push  rax
    mov   rbx , rcx
    mov   rcx , rdx
    pop   rdx
    mov   rax , 1          ; End of Menu Struct
    add   rbx , 20
    add   rcx , 50
    int   0x60
    pop   rdx
    pop   rcx

    add   rcx , 1
    mov   rsi ,[resolution_x]
    shr   rsi , 2
    cmp   rcx , rsi
    jb    newpix
    mov   rcx , 0

    add   rdx , 1
    mov   rsi,[resolution_y]
    shr   rsi , 2
    cmp   rdx , rsi
    jb    newpix

    ret


; Data area

resolution_x:

    dq    1024

resolution_y:

    dq    768


button_text:

    db    'Save as '

path:

    db    '/usb/1/screen.bmp',0

window_label:

    db    'SCREEN',0      ; Window label

menu_struct:               ; Menu Struct

    dq   0                 ; Version

    dq   0x100             ; Start value of ID to return ( ID + Line )

    db   0,'FILE',0        ; ID = 0x100 + 1
    db   1,'Quit',0
    db   255

bmpheader:

    db    66   ; 01
    db    77
    db    54
    db    12
    db    0
    db    0
    db    0
    db    0
    db    0
    db    0    ; 10
    db    54
    db    0
    db    0
    db    0
    db    40
    db    0
    db    0
    db    0
    db    32   ; x
    db    0    ; 20
    db    0
    db    0
    db    32   ; y
    db    0
    db    0
    db    0
    db    1
    db    0
    db    24
    db    0    ; 30
    db    0
    db    0
    db    0
    db    0
    db    0
    db    12
    db    0
    db    0
    db    0
    db    0    ; 40
    db    0
    db    0
    db    0
    db    0
    db    0
    db    0
    db    0
    db    0
    db    0
    db    0    ; 50
    db    0
    db    0
    db    0
    db    0    ; 54

bmpheader_end:


image_end:

