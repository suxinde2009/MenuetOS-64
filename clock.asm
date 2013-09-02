;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Image:
;   GPL/ChromeClock
;   http://www.kde-look.org/content/show.php?content=12972
;   A SuperKaramba analog clock
;   (c) 2004, Ido Abramovich <idoa01 at yahoo dot com>
;
;   Freeform Clock for Menuet 64
;   Compile with Fasm 1.60 and above
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use64

          org    0x0

          db     'MENUET64'            ; 8 byte id
          dq     0x01                  ; header version
          dq     START                 ; start of code
          dq     IMAGE_END             ; size of image
          dq     0x100000              ; memory for app
          dq     0xffff0               ; rsp
          dq     0x0,0x0               ; I_Param , I_Icon

START:

    call  calculate_line_table

    call  get_sysdir

    call  shape_window

    call  draw_window

still:

    mov   rax , 23
    mov   rbx , 100
    int   0x60

    test  rax , 1b    ; Window redraw
    jnz   red

    test  rax , 10b   ; Key press
    jnz   key

    test  rax , 100b  ; Button press
    jnz   button

    call  draw_time

    jmp   still

red:

    call  draw_window
    call  check_size

    jmp   still

key:

    mov   rax , 2
    int   0x60

    test  rbx , 1
    jz    still

    cmp   cx , 'Es'
    jne   still

    mov   rax, 512
    int   0x60

    jmp   still

button:

    mov   rax , 17
    int   0x60

    ; rax = status
    ; rbx = button id

    cmp   rbx , 0x10000001
    jne   no_application_terminate
    mov   rax , 512
    int   0x60
  no_application_terminate:

    jmp   still


check_size:

    mov   rax , 111
    mov   rbx , 1
    int   0x60

    mov   rcx , rax
    mov   rax , 9
    mov   rbx , 2
    mov   rdx , IMAGE_END
    mov   r8  , 4*8
    int   0x60

    cmp   [IMAGE_END+16],dword 128
    jne   terminate
    cmp   [IMAGE_END+24],dword 128
    jne   terminate

    ret

  terminate:

    mov   rax , 5
    mov   rbx , 20
    int   0x60

    mov   rax , 512
    int   0x60


draw_time:

    mov   rax , 7
    mov   rbx , 64 shl 32 + 64 ; 96
    mov   rcx , 64 ; 96
    mov   rdx , 0x60000
    mov   r8  , 0
    mov   r9  , 0xffff00
    mov   r10 , 3
    int   0x60

    mov   rax , 7
    mov   rbx , 64 shl 32 + 64 ; 96
    mov   rcx , 64 shl 32 + 64 ; 96
    mov   rdx , 0x60000  + 63*64*3
    mov   r8  , -64*3*2
    mov   r9  , 0xffff00
    mov   r10 , 3
    int   0x60

    mov   rax , 7
    mov   rbx , 64 ; 96
    mov   rcx , 64 ; 96
    mov   rdx , 0x60000  + 64*3-3
    mov   r8  , 64*3*2
    mov   r9  , 0xffff00
    mov   r10 , -3
    int   0x60

    mov   rax , 7
    mov   rbx , 64 ; 96
    mov   rcx , 64 shl 32 + 64 ; 96
    mov   rdx , 0x60000  + 64*64*3-3
    mov   r8  , 0
    mov   r9  , 0xffff00
    mov   r10 , -3
    int   0x60

    mov   rax , 3
    mov   rbx , 1
    int   0x60

    push  rax
    mov   r15 , 0x000000
    mov   rbx , rax
    shr   rbx , 8
    and   rbx , 0xff
    mov   rax , rbx
    mov   rbx , 12
    xor   rdx , rdx
    div   rbx
    mov   rbx , rax
    pop   rax
    push  rax
    and   rax , 0xff
    cmp   rax , 12
    jb    nosub12
    sub   rax , 12
  nosub12:
    imul  rax , 5
    add   rax , rbx
    mov   r14 , 1
    call  draw_line
    pop   rax

    mov   r14 , 0
    shr   rax , 8
    call  draw_line

    ; Seconds

    mov   r14 , 0
    shr   rax , 8
    mov   r15 , 0xff0000
    call  draw_line

    ret


draw_line:

    push  rax

    and   rax , 0xff

    imul  rax , 16
    cmp   r14 , 0
    jne   notable1
    add   rax , line_table
    jmp   notable2
  notable1:
    add   rax , short_line_table
  notable2:

    mov   rdx , [rax]
    mov   r8  , [rax+8]
    mov   rax , 38
    mov   rbx , 64
    mov   rcx , 64
    mov   r9  , r15
    int   0x60

    pop   rax

    ret


calculate_line_table:

    mov   rcx , 15
    mov   rsi , line_table+14*16
    mov   rdi , line_table+15*16 + 14*16

  newlc:

    mov   rax , [rsi]
    mov   rbx , [rsi+8]

    mov   rdx , 64
    sub   rdx , rbx
    mov   rbx , rdx
    add   rbx , 64

    mov   [rdi],rbx
    mov   [rdi+8],rax

    sub   rsi , 16
    sub   rdi , 16

    loop  newlc

    ;

    mov   rcx , 30
    mov   rsi , line_table+0
    mov   rdi , line_table+30 * 16

 newl2:

    mov   rax , [rsi]
    mov   rbx , [rsi+8]

    mov   rdx , 128
    sub   rdx , rax
    mov   rax , rdx

    mov   rdx , 128
    sub   rdx , rbx
    mov   rbx , rdx

    mov   [rdi],rax
    mov   [rdi+8],rbx

    add   rsi , 16
    add   rdi , 16

    loop  newl2

    ;

    mov   rsi , line_table
    mov   rdi , short_line_table
    mov   rcx , 60

  newlt1:

    mov   rax , [rsi]
    mov   rbx , [rsi+8]

    imul  rax , 6
    xor   rdx , rdx
    mov   r8  , 8
    div   r8

    add   rax , 16

    push  rax

    mov   rax , rbx
    imul  rax , 6
    xor   rdx , rdx
    div   r8
    add   rax , 16
    mov   rbx , rax

    pop   rax

    mov   [rdi],rax
    mov   [rdi+8],rbx

    add   rsi , 16
    add   rdi , 16

    loop  newlt1


    ret


shape_window:

    call  decode_external

    mov   rdi , 0x10000
    mov   rcx , 128*128
    mov   rax , 0
    cld
    rep   stosb

    mov   rsi , 0x60000
    mov   rdi , 0

    mov   r10 , 0
    mov   r11 , 0

  swl1:

    mov   rdx , 1

    mov   rax ,[rsi]
    mov   rbx , 0xffffff
    and   rax , rbx
    cmp   rax , 0xffff00
    jne   nopix
    mov   rdx , 0
   nopix:

    mov  [0x10000+rdi+63+128], dl

    mov   r12 , rdi
    sub   r12 , r10
    sub   r12 , r10
    mov  [0x10000+r12+64+128], dl

    mov   r12 , 128*127
    sub   r12 , rdi
    mov   [0x10000+r12+64-128],dl

    mov   r12 , 63
    sub   r12 , r11
    add   r12 , 64
    imul  r12 , 128
    mov   r13 , r10
    add   r13 , 64
    add   r12 , r13
    mov   [0x10000+r12-1-128],dl

    inc   rdi

    add   rsi , 3

    inc   r10

    cmp   r10 , 64
    jb    swl1

    mov   r10 , 0

    add   rdi , 64

    inc   r11
    cmp   r11 , 64
    jb    swl1

    mov   rax , 50         ; give shape
    mov   rbx , 0
    mov   rcx , 0x10000
    int   0x60

    ret


decode_external:

    mov   rax , 58        ; FileSYS
    mov   rbx , 0         ; Read
    mov   rcx , 0         ; first block to read
    mov   rdx , -1        ; blocks to read
    mov   r8  , 0x50000   ; picfile
    mov   r9  , filename  ; name pointer
    int   0x60

    mov   rax , 256
    mov   rbx , runpng
    mov   rcx , param
    int   0x60

    push  rbx

    ; IPC area at 0x60000

    mov   rax , 0
    mov   [0x60000-32],rax
    mov   rax , 16
    mov   [0x60000-32+8],rax
    mov   [0x60000+63*63*3],dword 123123

    ; Define IPC

    mov   rax , 60
    mov   rbx , 1
    mov   rcx , 0x60000-32
    mov   rdx , 0x40000
    int   0x60

    ; My PID

    mov   rax , 111
    mov   rbx , 1
    int   0x60
    mov   [0x50000-8],rax

    ;
    ; Send picture from 1 MB
    ;

    pop   rcx ; PID

    mov   rdi , 0

  sendtry:

    inc   rdi
    cmp   rdi , 1000*60 ; 1 minute timeout
    ja    notransformation

    mov   rax , 105
    mov   rbx , 1
    int   0x60

    mov   rax , 60
    mov   rbx , 2
    mov   rdx , 0x50000-8
    mov   r8 , 5000
    int   0x60

    cmp   rax , 0
    jne   sendtry

    ;
    ; Receive
    ;

    mov   rdi , 0

  waitmore:

    inc   rdi
    cmp   rdi , 1000*60 ; 1 minute timeout
    ja    notransformation

    mov   rax , 105
    mov   rbx , 1
    int   0x60

    cmp   [0x60000+63*63*3],dword 123123
    je    waitmore

 notransformation:

    ret



draw_window:

    mov   rax , 12
    mov   rbx , 1
    int   0x60

    mov   rax , 26
    mov   rbx , 3
    mov   rcx , IMAGE_END
    mov   rdx , 256
    int   0x60

    mov   rbx , [IMAGE_END+4*8]
    sub   rbx , 134
    shl   rbx , 32
    add   rbx , 128 ; 96

    mov   rax , 0                           ; draw window
    mov   rcx ,  50 *0x100000000 + 128 ; 96       ; y start & size
    mov   rdx , 1   *0x100000000 + 0xffffff ; type    & border color
    mov   r8  , 1b                          ; draw buttons
    mov   r9  , 0                           ; 0 or label - asciiz
    mov   r10 , 0                           ; pointer to menu struct or 0
    int   0x60

    call  draw_time

    mov   rax , 12
    mov   rbx , 2
    int   0x60

    ret

get_sysdir:

    mov   rax , 112
    mov   rbx , 1
    mov   rcx , sys_parameter
    mov   rdx , 128
    mov   r8  , sysdir
    int   0x60

    mov   rdi , filename
    mov   rsi , filename_orig
    call  withsysdir

    ret


withsysdir:

    push  rsi

    mov   rsi , sysdir
  newsearch:
    mov   al , [rsi]

    cmp   al , byte 0
    je    outsearch

    mov  [rdi],al

    inc   rsi
    inc   rdi

    jmp   newsearch

  outsearch:

    pop   rsi
    mov   rcx , 12
    cld
    rep   movsb

    ret

; Data area

filename:

    times 128 db 0

filename_orig:

    db    'CLOCK.PNG',0

sys_parameter:

    db   'system_directory',0

runpng:  db  '/fd/1/pngview',0
param:   db  'PARAM',0

line_table:

    dq    64 , 20
    dq    68 , 20
    dq    73 , 22
    dq    77 , 24
    dq    81 , 25
    dq    86 , 26
    dq    89 , 29
    dq    93 , 32
    dq    96 , 35
    dq    99 , 38
    dq   102 , 41
    dq   103 , 46
    dq   105 , 50
    dq   107 , 54
    dq   108 , 58

    times 50  dq  ?,?

short_line_table:

    times  65 dq  ?,?

sysdir:

    times 128 db ?

IMAGE_END:

