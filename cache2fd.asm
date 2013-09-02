;WARNING! Spaghetti code, size optimized

use64

    org    0x0

    db     'MENUET64'              ; 8 byte id
    dq     0x01                    ; header version
    dq     START                   ; start of code
    dq     I_END                   ; size of image
    dq     0x100000                ; memory for app
    dq     0x0ffff0                ; rsp
    dq     0x0,0x0                 ; I_Param , I_Icon

START:

    mov  rax , 141
    mov  rbx , 1
    mov  rcx , 1
    mov  rdx , 5 shl 32 + 5
    mov  r8  , 9 shl 32 + 12
    int  0x60

    call draw_window

still:

    mov  rax,10                 ; wait here for event
    int  0x60

    test rax,1                  ; redraw request ?
    jnz  red
    test rax,2                  ; key in buffer ?
    jnz  key
    test rax,4                  ; button in buffer ?
    jnz  button

    jmp  still

  red:                          ; redraw

    call draw_window
    jmp  still

  key:                          ; key
                                ; just read it and ignore
    mov  rax , 2
    int  0x40
    jmp  still

  button:                       ; button

    mov  eax,17                 ; get id
    int  0x40

    cmp  ah,1                   ; button id=1 ?
    je   close
    cmp  ah,2
    je   ramdiskcopy
    cmp  ah,3
    je   ramdiskupdate
    cmp  ah,4
    je   togglewrite

    jmp  still

close:

    mov  rax , 512
    int  0x60

ramdiskcopy:

    mov eax,16
    xor ebx,ebx
    inc ebx
    jmp callsys

ramdiskupdate:

    mov eax,16
    xor ebx,ebx
    inc ebx
    inc ebx
    jmp callsys

callsys:

   int  0x60
   jmp  still

; get fdc settings for writing & invert them.

togglewrite:

    mov  rax,16
    mov  ebx,4
    int  0x60
    xchg ecx,eax
    xor  ecx,1
    mov  rax,16
    dec  ebx
    int  0x60
    call draw_window
    jmp  still


draw_window:

    mov  eax,12                    ; function 12:tell os about windowdraw
    xor  ebx,ebx                   ; 1, start of draw
    inc  ebx
    int  0x40

    mov  rax , 0
    mov  rbx , 100 shl 32 + 250
    mov  rcx , 100 shl 32 + 120
    mov  rdx , 0xffffff
    mov  r8  , 1
    mov  r9  , 0
    mov  r10 , 0
    int  0x60

    ;The important part, the buttons & text.

    mov ebx,9*65536+28
    mov ecx,41*65536+14
    xor edx,edx
    inc edx
    inc edx
    call clickbox

    mov ebx,57*65536+40
    inc edx
    call clickbox

    mov ebx,12*65536+12
    mov ecx,81*65536+12
    inc edx
    call clickbox

    mov ecx,96*65536+12
    xor edx,edx
    call clickbox

    mov edi,0x10000000
    mov edx,titlebar
    mov ebx,9*65536+9
    mov ecx,0x10ffffff
    call print

    mov ebx,11*65536+28
    mov ecx,0x10808080
    call print

    add ebx,15
    xchg ecx,edi
    call print

    add ebx,25
    xchg ecx,edi
    call print

    add ebx,15
    xchg ecx,edi
    call print

    add ebx,15
    xchg ecx,edi
    call print

    mov eax,16
    mov ebx,4
    int 0x60
    test al,1
    je nowritex
    mov ebx,15*65536+83
    xchg ecx,edi
    call print
  nowritex:

    mov  eax,12                    ; function 12:tell os about windowdraw
    xor  ebx,ebx                   ; 1, start of draw
    inc  ebx
    inc  ebx
    int  0x40

    ret


clickbox:

    push rax rbx rcx rdx rsi rdi

    mov edi,edx
    cmp edx, 0
    je .disabledbox
    mov  eax,8      ; function 8 : define and draw button
    int  0x40
    .disabledbox:
    inc ecx
    inc ebx
    mov eax,13
    mov edx, 0x808080
    int 0x40
    cmp edi,0
    je .grayed
    mov edx,0x80
    .grayed:
    sub ebx,65536
    sub ecx,65536
    int 0x40
    add ebx,65534
    add ecx,65534
    mov edx,0xffffff
    int 0x40

    pop rdi rsi rdx rcx rbx rax

    ret

print:

    mov eax,edx
    xor esi,esi
    addchar:
    inc eax
    inc esi
    cmp [eax],byte 0
    jne addchar
    mov eax,4
    int 0x40
    add edx,esi
    inc edx

    ret


; Data

titlebar:  db  'CACHE2FD',0
h1:        db  'Commands',0
comtext:   db  'Copy or Update cache to floppy',0
h2:        db  'Settings',0
setwrite:  db  '   Write directly to floppy',0
setread:   db  '   Read directly from floppy',0
xsign:     db  'X',0

I_END:

