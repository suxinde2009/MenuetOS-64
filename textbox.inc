;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Textbox.inc for Menuet
;
;   Compile with FASM 1.60 or above
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use64

read_textbox:

    ;mov   [r14+32],dword 0  ; Clears textbox
    ;mov   [r14+40],byte 0

    mov   rbp , [r14+40]     ; Cursor position

    ;mov   rax , 37          ; Cursor equals mouse position
    ;mov   rbx , 1
    ;int   0x60
    ;shr   rax , 32
    ;sub   rax , [r14+8]
    ;xor   rdx , rdx
    ;mov   rbx , 6
    ;div   rbx
    ;cmp   rax , rbp
    ;jge   no_cursor_position
    ;mov   rbp , rax
    ;no_cursor_position:

  read_more_print:

    call  draw_textbox

    mov   rax , 38
    mov   rbx , [r14+40]
    mov   rbx , rbp
    imul  rbx , 6
    add   rbx , [r14+8]
    add   rbx , 4
    mov   rcx , [r14+24]
    add   rcx , 2
    mov   rdx , rbx
    mov   r8  , rcx
    add   r8  , 12
    mov   r9  , 0x000000
    int   0x60

  read_more_keys:

    mov   rax , 10
    int   0x60

    cmp   rax , 2
    je    continue
    call  draw_textbox
    ret
  continue:

    mov   rax , 2
    int   0x60

    cmp   rbx , 10b
    jne   no_special

    mov   r8  , 'Delete  '
    cmp   rcx , r8
    jne   no_delete
    cmp   rbp , [r14+40]
    je    no_delete
    inc   rbp
    jmp   backspace
  no_delete:

    mov   r8  , 'Backspc '
    cmp   rcx , r8
    jne   no_backspc

  backspace:
    cmp   rbp , 0
    je    read_more_keys

    dec   dword [r14+40]

    mov   rdi , rbp
    add   rdi , r14
    add   rdi , 48

    mov   rax , [r14+16]
    imul  rax , 6
    xor   rdx , rdx
    mov   rbx , 6
    div   rbx

    mov   rcx , [r14+40]
    sub   rcx , rbp
    inc   rcx
    mov   rsi , rdi
    dec   rdi
    cld
    rep   movsb

    dec   rbp

    mov   rax , [r14+40]
    mov   [r14+48   +rax],byte 0
  skipthis:
    jmp   read_more_print
  no_backspc:

    mov   r8  , 'Esc     '
    cmp   rcx , r8
    je    exit_textbox

    mov   r8  , 'Enter   '
    cmp   rcx , r8
    je    exit_textbox

    mov   r8  , 'Left-A  '
    cmp   rcx , r8
    jne   no_left
    cmp   rbp , 0
    je    read_more_keys
    dec   rbp
    jmp   read_more_print
  no_left:

    mov   r8  , 'Right-A '
    cmp   rcx , r8
    jne   no_right
    cmp   rbp , [r14+40]
    jae   read_more_keys
    inc   rbp
    jmp   read_more_print
  no_right:

  no_special:

    cmp   rbx , 0
    jne   read_more_keys

    and   cx , 0xff
    mov   rax , [r14+40]
    mov   rax , rbp
    mov   rdi , rax
    add   rdi , r14
    add   rdi , 48

    mov   rax , [r14+16]
    sub   rax , 6
    mov   rbx , 6
    xor   rdx , rdx
    div   rbx
    cmp   rax , [r14+40]
    jbe   nomoretext
    inc   dword [r14+40]
    inc   rbp
    push  rcx
    push  rdi
    mov   rcx , rax
    sub   rcx , rbp
    mov   rsi , rdi
    inc   rdi
    add   rdi , rcx
    add   rsi , rcx
    inc   rcx
    std
    rep   movsb
    pop   rdi
    pop   rcx
    mov   [rdi],cl
    cmp   rbp , [r14+40]
    jne   nomoretext
    mov   [rdi+1],byte 0
  nomoretext:

    jmp   read_more_print

exit_textbox:

    push  rcx
    call  draw_textbox
    pop   rcx

    ret

draw_textbox:

    mov   rax , [r14+8]
    mov   r15 , [r14+16]

    push  rax

    ; Black frames

    mov   rax , 38
    mov   rbx , [r14+8]
    mov   rdx , [r14+16]
    add   rdx , rbx
    mov   rcx , [r14+24]
    mov   r8  , 16
    add   r8  , rcx
    mov   r9  , 0x202020
    push  rbx
    mov   rbx , rdx
    int   0x60
    pop   rbx
    push  rdx
    mov   rdx , rbx
    int   0x60
    pop   rdx
    push  rcx
    mov   rcx , r8
    int   0x60
    pop   rcx
    push  r8
    mov   r8  , rcx
    int   0x60
    pop   r8

    ; White

    mov   rax , 13
    mov   rbx , [rsp]
    add   rbx , 1
    shl   rbx , 32
    add   rbx , r15
    sub   rbx ,  2
    mov   rcx , [r14+24]
    add   rcx , 1
    shl   rcx , 32
    add   rcx , 15
    mov   rdx , 0xffffff
    int   0x60

    ; Text

    mov   rax , 4
    mov   rbx , r14
    add   rbx , 48
    mov   rcx ,  25
    mov   rcx , [rsp+0]
    add   rcx , 4
    mov   rdx , [r14+24]
    add   rdx , 5
    mov   rsi , 0x000000
    mov   r9  , 1
    int   0x60

    ; Button

    mov   rbx , [rsp]
    shl   rbx , 32
    mov   rax , 8
    add   rbx , r15
    inc   rbx
    mov   rcx , [r14+24]
    shl   rcx , 32
    add   rcx , 17
    mov   rdx , [r14+32]
    mov   r8  , 0
    bts   r8  , 63
    ;bts   r8  , 61
    mov   r9  , 0
    int   0x60

    pop   rax

    ret

