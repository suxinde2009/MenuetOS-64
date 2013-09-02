;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Recyclebin for Menuet64
;
;   Compile with FASM 1.60 or above
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use64

    org   0x0

    db    'MENUET64'              ; Header identifier
    dq    0x01                    ; Version
    dq    START                   ; Start of code
    dq    image_end               ; Size of image
    dq    0x500000                ; Memory for app
    dq    0xffff0                 ; Esp
    dq    Parameter               ; Prm
    dq    0x00                    ; Icon

START:

    mov   rax , 141
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    cmp   [Parameter+8],byte 0
    je    startfbrowser

    mov   rax , 5
    mov   rbx , 5
    int   0x60

    call  get_filename

    ;
    ; File in recycle bin -> delete
    ;
    cmp   [Parameter+8+1],word 'fd'
    je    yesfdrb
    cmp   [Parameter+8+1],word 'Fd'
    je    yesfdrb
    cmp   [Parameter+8+1],word 'FD'
    je    yesfdrb
    jmp   nofdrb
  yesfdrb:
    mov   rax , 'recycleb'
    cmp   [Parameter+8+6],rax
    je    deletefileinrecyclebin
    mov   rax , 'Recycleb'
    cmp   [Parameter+8+6],rax
    je    deletefileinrecyclebin
    mov   rax , 'RECYCLEB'
    cmp   [Parameter+8+6],rax
    je    deletefileinrecyclebin
  nofdrb:

    ; Read
    mov   rax , 58
    mov   rbx , 0
    mov   rcx , 0
    mov   rdx , -1
    mov   r8  , 0x100000
    mov   r9  , Parameter+8
    int   0x60
    push  rbx
    ; Write
    mov   rax , 58
    mov   rbx , 1
    mov   rcx , 0
    pop   rdx
    mov   r8  , 0x100000
    mov   r9  , writefile
    int   0x60
    cmp   rax , 0
    jne   binfull

  deletefileinrecyclebin:

    ; Delete original file
    mov   rax , 58
    mov   rbx , 2
    mov   r9  , Parameter+8
    int   0x60
    cmp   rax , 0
    je    terminate

    jmp   draw_window

  terminate:

    mov   rax , 5
    mov   rbx , 50
    int   0x60

    mov   rax , 512
    int   0x60

  binfull:

    jmp   draw_window_full


get_filename:

    mov   r10 , 0

    mov   rsi , Parameter+8
  fnl0:
    cmp   [rsi],byte 0
    je    fnl1
    inc   rsi
    jmp   fnl0
  fnl1:
    cmp   [rsi],byte '/'
    je    fnl2
    inc   r10
    dec   rsi
    jmp   fnl1
  fnl2:
    inc   rsi
    mov   rdi , filename
    mov   rcx , 20
    cld
    rep   movsb

    ret


startfbrowser:

    mov   rax , 5
    mov   rbx , 10
    int   0x60

    mov   rax , 256
    mov   rbx , fbrowser
    mov   rcx , path
    int   0x60

    mov   rax , 5
    mov   rbx , 20
    int   0x60

    mov   rax , 512
    int   0x60


draw_window:

    mov   rax , 0xC                          ; Beginning of window draw
    mov   rbx , 0x1
    int   0x60

    mov   rax , 61
    mov   rbx , 1
    int   0x60
    shr   rax , 32
    shr   rax , 1
    sub   rax , 0x118/2
    mov   rbx , rax
    shl   rbx , 32
    add   rbx , 0x118

    mov   rax , 0x0                          ; Draw window
    mov   rcx , 0x0000008000000069           ; y start & size
    mov   rdx , 0x0000000000FFFFFF           ; type    & border color
    mov   r8  , 0x0000000000000001           ; draw flags
    mov   r9  , window_label                 ; 0 or label - asciiz
    mov   r10 , 0                            ; 0 or pointer to menu struct
    int   0x60

    mov   rax , 0x4
    mov   rbx , denied
    mov   rcx , 30-12
    mov   rdx , 41+3
    mov   rsi , 0x0
    mov   r9  , 0x1
    mov   r8  , 0x3
    int   0x60

    mov   rax , 8
    mov   rbx , (110-12) shl 32 + 80
    mov   rcx ,      68 shl 32 + 18
    mov   rdx , 10
    mov   r8  , 0
    mov   r9  , text1
    int   0x60

    mov   rax , 0xC                          ; End of window draw
    mov   rbx , 0x2
    int   0x60

    mov   rax , 5
    mov   rbx , 50
    int   0x60

  waitmore:

    mov   rax , 10
    int   0x60

    test  rax , 2
    jnz   readkey

    mov   rax , 512
    int   0x60

  readkey:

    mov   rax , 2
    int   0x60

    cmp   ecx , 'Dele'
    je    waitmore

    mov   rax , 512
    int   0x60



draw_window_full:

    mov   rax , 0xC                          ; Beginning of window draw
    mov   rbx , 0x1
    int   0x60

    mov   rax , 61
    mov   rbx , 1
    int   0x60
    shr   rax , 32
    shr   rax , 1
    sub   rax , 0x0e6/2
    mov   rbx , rax
    shl   rbx , 32
    add   rbx , 0x0e6

    mov   rax , 0x0                          ; Draw window
    mov   rcx , 0x0000008000000073           ; y start & size
    mov   rdx , 0x0000000000FFFFFF           ; type    & border color
    mov   r8  , 0x0000000000000001           ; draw flags
    mov   r9  , window_label                 ; 0 or label - asciiz
    mov   r10 , 0                            ; 0 or pointer to menu struct
    int   0x60

    mov   rax , 0x4
    mov   rbx , binfulltext1
    mov   rcx , 40
    mov   rdx , 40
    mov   rsi , 0x0
    mov   r9  , 0x1
    mov   r8  , 0x3
    int   0x60
    mov   rax , 0x4
    mov   rbx , binfulltext2
    mov   rcx , 40
    mov   rdx , 40+16
    mov   rsi , 0x0
    mov   r9  , 0x1
    mov   r8  , 0x3
    int   0x60

    mov   rax , 8
    mov   rbx , 115 shl 32 + 80
    mov   rcx , 079 shl 32 + 18
    mov   rdx , 10
    mov   r8  , 0
    mov   r9  , text1
    int   0x60
    mov   rax , 8
    mov   rbx , 031 shl 32 + 80
    mov   rcx , 079 shl 32 + 18
    mov   rdx , 11
    mov   r8  , 0
    mov   r9  , text2
    int   0x60

    mov   rax , 0xC                          ; End of window draw
    mov   rbx , 0x2
    int   0x60

    mov   rax , 5
    mov   rbx , 50
    int   0x60

  waitmore2:

    mov   rax , 10
    int   0x60

    test  rax , 2
    jnz   readkey2
    test  rax , 4
    jnz   permdelete

    mov   rax , 512
    int   0x60

  readkey2:

    mov   rax , 2
    int   0x60

    cmp   ecx , 'Dele'
    je    waitmore2

    mov   rax , 512
    int   0x60

  permdelete:

    mov   rax , 0x11
    int   0x60

    cmp   rbx , 10
    jne   endapp

    mov   rax , 58
    mov   rbx , 2
    mov   r9  , Parameter+8
    int   0x60

  endapp:

    mov   rax , 5
    mov   rbx , 20
    int   0x60

    mov   rax , 512
    int   0x60




; Data area

window_label:

    db    'RECYCLE BIN',0     ; Window label

text1:

    db    'OK',0

text2:

    db    'CANCEL',0


writefile:  db '/fd/1/recycleb/'
filename:   times 256 db 0

fbrowser:   db '/fd/1/fbrowser',0
path:       db '/fd/1/recycleb',0

denied:

    db    'Access denied to file and/or recycle bin.',0

binfulltext1:

    db    '    Recycle Bin full.    ',0

binfulltext2:

    db    'Delete file permanently ?',0

Parameter:

    dq   100
    dq   0

image_end:

