;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Menuet protection tests
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use64

    org  0x0

    db   'MENUET64'             ; 8 byte id
    dq   0x01                   ; header version
    dq   START                  ; start of code
    dq   I_END                  ; size of image
    dq   0x200000               ; memory for app
    dq   0x1ffff0               ; rsp
    dq   0x0,0x0                ; I_Param , I_Icon

START:                          ; start of execution

    mov  rax , 141
    mov  rbx , 1
    mov  rcx , 1
    mov  rdx , 5 shl 32 + 5
    mov  r8  , 9 shl 32 + 12
    int  0x60

    call draw_window            ; at first, draw the window

still:

    mov  rax,10                 ; wait here for event
    int  0x60

    test eax,1                  ; redraw request ?
    jnz  red
    test eax,2                  ; key in buffer ?
    jnz  key
    test eax,4                  ; button in buffer ?
    jnz  button

    jmp  still

  red:                          ; redraw
    call draw_window

    jmp  still

  key:                          ; key
    mov  eax,2                  ; just read it and ignore
    int  0x40

    jmp  still

  button:                       ; button
    mov  eax,17
    int  0x40

    shr  rax , 8

    cmp  rax , 0x10000001       ; button id=1 ?
    jnz  noclose
    mov  eax,512                ; close this program
    int  0x60
  noclose:

    cmp  rax , 2
    jnz  notest2
    cli
  notest2:

    cmp  rax , 3
    jnz  notest3
    sti
  notest3:

    cmp  rax , 4
    jnz  notest4
    mov  [0x200000],byte 1
   notest4:

    cmp  rax , 5
    jnz  notest5
    jmp  qword 0x200000
  notest5:

    cmp  rax , 6
    jnz  notest6
    mov  rsp,0
    push rax
  notest6:

    cmp  rax , 7
    jnz  notest7
    in   al,0x60
  notest7:

    cmp  rax , 8
    jnz  notest8
    out  0x60,al
  notest8:

    cmp  rax , 9
    jnz  notest9
    int  0x5f
  notest9:

    jmp  still


draw_window:

    mov  eax,12                    ; function 12:tell os about windowdraw
    mov  ebx,1                     ; 1, start of draw
    int  0x40

                                   ; DRAW WINDOW
    mov  rax,0                     ; function 0 : define and draw window
    mov  rbx,100 shl 32 + 300      ; [x start] *65536 + [x size]
    mov  rcx,100 shl 32 + 255      ; [y start] *65536 + [y size]
    mov  rdx, 0xffffff             ; color of work area RRGGBB
    mov  r8 , 0
    mov  r9 , window_label         ; color of grab bar  RRGGBB,8->color glid
    mov  r10, 0                    ; color of frames    RRGGBB
    int  0x60

    mov  eax,8                     ; function 8 : define and draw button
    mov  ebx,25*65536+11           ; [x start] *65536 + [x size]
    mov  ecx,80*65536+11           ; [y start] *65536 + [y size]
    mov  edx,2                     ; button id
    mov  esi,0x4466bb              ; button color RRGGBB
  newb:
    int  0x40
    add  ecx,20*65536
    inc  edx
    cmp  edx,10
    jb   newb

    mov  ebx,25*65536+42           ; draw info text with function 4
    mov  ecx,0x000000
    mov  edx,text
    mov  esi,41
  newline:
    mov  eax,4
    int  0x40
    add  ebx,10
    add  edx,41
    cmp  [edx],byte 'x'
    jnz  newline

    mov  eax,12                    ; function 12:tell os about windowdraw
    mov  ebx,2                     ; 2, end of draw
    int  0x40

    ret


; DATA AREA


text:

    db 'APPLICATION USES 0x200000 BYTES OF MEMORY'
    db '                                         '
    db 'OPEN DEBUG BOARD FOR PARAMETERS          '
    db '                                         '
    db '     CLI                                 '
    db '                                         '
    db '     STI                                 '
    db '                                         '
    db '     MOV [0x200000],BYTE 1               '
    db '                                         '
    db '     JMP DWORD 0x200000                  '
    db '                                         '
    db '     MOV RSP,0 & PUSH RAX                '
    db '                                         '
    db '     IN  AL,0x60                         '
    db '                                         '
    db '     OUT 0x60,AL                         '
    db '                                         '
    db '     INT 0x5F                            '
    db 'x                                        '


window_label:

    db   'PROTECTION TEST',0

I_END:

