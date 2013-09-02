define NUMQ1 3.4
define NUMQ2 5.6
define NUMD1 3.4
define NUMD2 5.6

define Q qword
define D dword
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


macro int60 {
;call syscall_mathlib
int 0x60
}
;include "math.inc"

macro dtextq2 aa
{
    cmp r14,72
    jl @f
    mov       rax  , 4       ;t
    mov       rbx  , aa
    mov       rcx  , 10
    mov       rdx  , r14
    mov       r9   , 1
    mov       esi  , 0x0
    int       0x60
    mov       rax  , 47      ;num
    mov       rbx  , 0x0000000000100100
    mov       rcx  , [numr0 + 0]
    mov       rdx  , 48 shl 32
    or        rdx  , r14
    mov       esi  , 0x0
    int       0x60
    mov       rax  , 47      ;num
    mov       rbx  , 0x0000000000100100
    mov       rcx  , [numr0 + 8]
    mov       rdx  , 152 shl 32
    or        rdx  , r14
    mov       esi  , 0x0
    int       0x60
    @@:
}
macro dtextq2_ aa
{
    cmp r14,72
    jl @f
    mov       rax  , 4       ;t
    mov       rbx  , aa
    mov       rcx  , 10
    mov       rdx  , r14
    mov       r9   , 1
    mov       esi  , 0x0
    int       0x60
    mov       rax  , 47      ;num
    mov       rbx  , 0x0000000000100100
    mov       rcx  , [numr0 + 0]
    mov       rdx  , 48 shl 32
    or        rdx  , r14
    mov       esi  , 0x0
    int       0x60
    mov       rax  , 47      ;num
    mov       rbx  , 0x0000000000100100
    mov       rcx  , [numr0 + 8]
    mov       rdx  , 152 shl 32
    or        rdx  , r14
    mov       esi  , 0x0
    int       0x60
    mov       rax  , 47      ;num
    mov       rbx  , 0x0000000000100100
    mov       rcx  , [numr1 + 0]
    mov       rdx  , 48 shl 32
    or        rdx  , r14
    add       rdx  , 12
    mov       esi  , 0x0
    int       0x60
    mov       rax  , 47      ;num
    mov       rbx  , 0x0000000000100100
    mov       rcx  , [numr1 + 8]
    mov       rdx  , 152 shl 32
    or        rdx  , r14
    add       rdx  , 12
    mov       esi  , 0x0
    int       0x60
    @@:
}
macro dtextq aa
{
    cmp r14,72
    jl @f
    mov       rax  , 47      ;num
    mov       rbx  , 0x0000000000100100
    mov       rcx  , [numr0 + 0]
    mov       rdx  , 340 shl 32
    or        rdx  , r14
    mov       esi  , 0x0
    int       0x60
    @@:
}
macro dtextq_ aa
{
    cmp r14,72
    jl @f
    mov       rax  , 47      ;num
    mov       rbx  , 0x0000000000100100
    mov       rcx  , [numr0 + 0]
    mov       rdx  , 340 shl 32
    or        rdx  , r14
    mov       esi  , 0x0
    int       0x60
    mov       rax  , 47      ;num
    mov       rbx  , 0x0000000000100100
    mov       rcx  , [numr0 + 8]
    mov       rdx  , 340 shl 32
    or        rdx  , r14
    add       rdx  , 12
    mov       esi  , 0x0
    int       0x60
    @@:
}

macro stextq2 aa
{
    cmp r14,72
    jl @f
    mov       rax  , 4       ;t
    mov       rbx  , aa
    mov       rcx  , 10
    mov       rdx  , r14
    mov       r9   , 1
    mov       esi  , 0x0
    int       0x60
    mov       rax  , 47      ;num
    mov       rbx  , 0x0000000000080100
    mov       ecx  , D [numr0 + 0]
    mov       rdx  , 48 shl 32
    or        rdx  , r14
    mov       esi  , 0x0
    int       0x60
    mov       rax  , 47      ;num
    mov       rbx  , 0x0000000000080100
    mov       ecx  , D [numr0 + 4]
    mov       rdx  , 100 shl 32
    or        rdx  , r14
    mov       esi  , 0x0
    int       0x60
    mov       rax  , 47      ;num
    mov       rbx  , 0x0000000000080100
    mov       ecx  , D [numr0 + 8]
    mov       rdx  , 152 shl 32
    or        rdx  , r14
    mov       esi  , 0x0
    int       0x60
    mov       rax  , 47      ;num
    mov       rbx  , 0x0000000000080100
    mov       ecx  , D [numr0 + 12]
    mov       rdx  , 204 shl 32
    or        rdx  , r14
    mov       esi  , 0x0
    int       0x60
    @@:
}
macro stextq2_ aa
{
    cmp r14,72
    jl @f
    mov       rax  , 4       ;t
    mov       rbx  , aa
    mov       rcx  , 10
    mov       rdx  , r14
    mov       r9   , 1
    mov       esi  , 0x0
    int       0x60
    mov       rax  , 47      ;num
    mov       rbx  , 0x0000000000080100
    mov       ecx  , D [numr0 + 0]
    mov       rdx  , 48 shl 32
    or        rdx  , r14
    mov       esi  , 0x0
    int       0x60
    mov       rax  , 47      ;num
    mov       rbx  , 0x0000000000080100
    mov       ecx  , D [numr0 + 4]
    mov       rdx  , 100 shl 32
    or        rdx  , r14
    mov       esi  , 0x0
    int       0x60
    mov       rax  , 47      ;num
    mov       rbx  , 0x0000000000080100
    mov       ecx  , D [numr0 + 8]
    mov       rdx  , 152 shl 32
    or        rdx  , r14
    mov       esi  , 0x0
    int       0x60
    mov       rax  , 47      ;num
    mov       rbx  , 0x0000000000080100
    mov       ecx  , D [numr0 + 12]
    mov       rdx  , 204 shl 32
    or        rdx  , r14
    mov       esi  , 0x0
    int       0x60

    mov       rax  , 47      ;num
    mov       rbx  , 0x0000000000080100
    mov       ecx  , D [numr1 + 0]
    mov       rdx  , 48 shl 32
    or        rdx  , r14
    add       rdx  , 12
    mov       esi  , 0x0
    int       0x60
    mov       rax  , 47      ;num
    mov       rbx  , 0x0000000000080100
    mov       ecx  , D [numr1 + 4]
    mov       rdx  , 100 shl 32
    or        rdx  , r14
    add       rdx  , 12
    mov       esi  , 0x0
    int       0x60
    mov       rax  , 47      ;num
    mov       rbx  , 0x0000000000080100
    mov       ecx  , D [numr1 + 8]
    mov       rdx  , 152 shl 32
    or        rdx  , r14
    add       rdx  , 12
    mov       esi  , 0x0
    int       0x60
    mov       rax  , 47      ;num
    mov       rbx  , 0x0000000000080100
    mov       ecx  , D [numr1 + 12]
    mov       rdx  , 204 shl 32
    or        rdx  , r14
    add       rdx  , 12
    mov       esi  , 0x0
    int       0x60
    @@:
}
macro stextq aa
{
    cmp r14,72
    jl @f
    mov       rax  , 47      ;num
    mov       rbx  , 0x0000000000080100
    mov       ecx  , D [numr0 + 0]
    mov       rdx  , 340 shl 32
    or        rdx  , r14
    mov       esi  , 0x0
    int       0x60
    @@:
}
macro stextq_ aa
{
    cmp r14,72
    jl @f
    mov       rax  , 47      ;num
    mov       rbx  , 0x0000000000080100
    mov       ecx  , D [numr0 + 0]
    mov       rdx  , 340 shl 32
    or        rdx  , r14
    mov       esi  , 0x0
    int       0x60
    mov       rax  , 47      ;num
    mov       rbx  , 0x0000000000080100
    mov       ecx  , D [numr0 + 4]
    mov       rdx  , 340 shl 32
    or        rdx  , r14
    add       rdx  , 12
    mov       esi  , 0x0
    int       0x60
    @@:
}


START:

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

    jmp   still

button_event:

    mov   rax , 17
    int   0x60

    ; rax = status
    ; rbx = button id

    cmp   rbx , 0x1000
    jb    .f
    cmp   rbx , 0x1000+800-1
    ja    .f
    mov   [sbval], rbx
    call  draw_window
    jmp   still

    .f:

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
    mov   rbx , 10 shl 32 + 500             ; X start & size
    mov   rcx , 10 shl 32 + 400             ; Y start & size
    mov   rdx , 0x0000000000FFFFFF           ; Type    & border color
    mov   r8  , 0x0000000000000001           ; Flags (set as 1)
    mov   r9  , window_label                 ; 0 or label - asciiz
    mov   r10 , menu_struct                  ; 0 or pointer to menu struct
    int   0x60

    mov   rax , 113
    mov   rbx , 1
    mov   rcx , 0x1000
    mov   rdx , 800
    mov   r8  , [sbval]
    mov   r9  , 480
    mov   r10 , 50
    mov   r11 , 340
    int   0x60


    fninit

    call  rand
    call  rand
    call  rand
    call  rand
    call  rand

    call  rand
    and   rax , 65535
    sub   rax , 32768
    push  rax
    fild  Q [rsp]
    push  10000
    fidiv D [rsp]
    fst   Q [numq]
    fstp  D [numd]
    add   rsp , 16

    call  rand
    and   rax , 65535
    sub   rax , 32768
    push  rax
    fild  Q [rsp]
    push  10000
    fidiv D [rsp]
    fst   Q [numq+8]
    fstp  D [numd+4]
    add   rsp , 16

    mov rax,NUMQ1
    mov rbx,NUMQ2
    mov [numq+0],rax
    mov [numq+8],rbx
    mov eax,NUMD1
    mov ebx,NUMD2
    mov [numd+0],eax
    mov [numd+4],ebx


    mov       r14  , 60      ;Y

    mov       rax  , 47      ;num
    mov       rbx  , 0x0000000000100100
    mov       rcx  , [numq + 0]
    mov       rdx  , 48 shl 32
    or        rdx  , r14
    mov       esi  , 0x0
    int       0x60
    mov       rax  , 47      ;num
    mov       rbx  , 0x0000000000100100
    mov       rcx  , [numq + 8]
    mov       rdx  , 158 shl 32
    or        rdx  , r14
    mov       esi  , 0x0
    int       0x60

    mov       rax  , 47      ;num
    mov       rbx  , 0x0000000000080100
    mov       ecx  , D [numd + 0]
    mov       rdx  , 340 shl 32
    or        rdx  , r14
    mov       esi  , 0x0
    int       0x60
    mov       rax  , 47      ;num
    mov       rbx  , 0x0000000000080100
    mov       ecx  , D [numd + 4]
    mov       rdx  , 400 shl 32
    or        rdx  , r14
    mov       esi  , 0x0
    int       0x60

    add       r14  , 24
    sub       r14  , [sbval]
    add       r14  , 0x1000





    movsd     xmm0 , [numq]  ;cos
    unpcklpd  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 0
    int60
    movapd    dqword [numr0], xmm0

    dtextq2 t00
    fld       Q [numq]
    fcos
    fstp      Q [numr0]

    dtextq  t00
    add       r14  , 12


    movsd     xmm0 , [numq]  ;sin
    unpcklpd  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 1
    int60
    movapd    dqword [numr0], xmm0

    dtextq2 t01
    fld       Q [numq]
    fsin
    fstp      Q [numr0]

    dtextq  t01
    add       r14  , 12


    movsd     xmm0 , [numq]  ;sincos
    unpcklpd  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 2
    int60
    movapd    dqword [numr0], xmm0
    movapd    dqword [numr1], xmm1

    dtextq2_ t02
    fld       Q [numq]
    fsincos
    fxch
    fstp      Q [numr0]
    fstp      Q [numr0 + 8]

    dtextq_  t02
    add       r14  , 12+12


    movsd     xmm0 , [numq]  ;tan
    unpcklpd  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 3
    int60
    movapd    dqword [numr0], xmm0

    dtextq2 t03
    fld       Q [numq]
    fptan
    fcomp st0
    fstp      Q [numr0]

    dtextq  t03
    add       r14  , 12


    movsd     xmm0 , [numq]  ;atan
    unpcklpd  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 4
    int60
    movapd    dqword [numr0], xmm0

    dtextq2 t04
    fld       Q [numq]
    fld1
    fpatan
    fstp      Q [numr0]

    dtextq  t04
    add       r14  , 12


    movsd     xmm0 , [numq]  ;atan2
    unpcklpd  xmm0 , xmm0
    movsd     xmm1 , [numq + 8]
    unpcklpd  xmm1 , xmm1
    mov       eax  , 151
    mov       ebx  , 5
    int60
    movapd    dqword [numr0], xmm0

    dtextq2 t05
    fld       Q [numq]
    fld       Q [numq + 8]
    fpatan
    fstp      Q [numr0]

    dtextq  t05
    add       r14  , 12


    movsd     xmm0 , [numq]  ;acos
    unpcklpd  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 6
    int60
    movapd    dqword [numr0], xmm0

    dtextq2 t06
    mov rax,0x8000000000000000
    mov [numr0],rax

    dtextq  t06
    add       r14  , 12


    movsd     xmm0 , [numq]  ;asin
    unpcklpd  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 7
    int60
    movapd    dqword [numr0], xmm0

    dtextq2 t07
    mov rax,0x8000000000000000
    mov [numr0],rax

    dtextq  t07
    add       r14  , 12


    movsd     xmm0 , [numq]  ;pow
    unpcklpd  xmm0 , xmm0
    movsd     xmm1 , [numq + 8]
    unpcklpd  xmm1 , xmm1
    mov       eax  , 151
    mov       ebx  , 8
    int60
    movapd    dqword [numr0], xmm0

    dtextq2 t08
    fld       Q [numq + 8]
    fld       Q [numq]
    fyl2x
    fld1
    fld st1  ;z1z
    fprem    ;rem(z) 1 z
    f2xm1    ;2^rem(z)-1 1 z
    faddp st1,st0 ;2^rem(z) z
    fscale    ;2^z
    fstp      Q [numr0]
    fcomp st0

    dtextq  t08
    add       r14  , 12


    movsd     xmm0 , [numq]  ;cbrt
    unpcklpd  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 9
    int60
    movapd    dqword [numr0], xmm0

    dtextq2 t09
    mov rax,0x8000000000000000
    mov [numr0],rax

    dtextq  t09
    add       r14  , 12


    movsd     xmm0 , [numq]  ;exp
    unpcklpd  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 10
    int60
    movapd    dqword [numr0], xmm0

    dtextq2 t10
    fld       Q [numq]
    fldl2e
    fmulp st1,st0
    fld1
    fld st1  ;z1z
    fprem    ;rem(z) 1 z
    f2xm1    ;2^rem(z)-1 1 z
    faddp st1,st0 ;2^rem(z) z
    fscale    ;2^z
    fstp      Q [numr0]
    fcomp st0

    dtextq  t10
    add       r14  , 12


    movsd     xmm0 , [numq]  ;exp2
    unpcklpd  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 11
    int60
    movapd    dqword [numr0], xmm0

    dtextq2 t11
    fld       Q [numq]
    fld1
    fmulp st1,st0
    fld1
    fld st1  ;z1z
    fprem    ;rem(z) 1 z
    f2xm1    ;2^rem(z)-1 1 z
    faddp st1,st0 ;2^rem(z) z
    fscale    ;2^z
    fstp      Q [numr0]
    fcomp st0

    dtextq  t11
    add       r14  , 12


    movsd     xmm0 , [numq]  ;exp10
    unpcklpd  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 12
    int60
    movapd    dqword [numr0], xmm0

    dtextq2 t12
    fld       Q [numq]
    fldl2t
    fmulp st1,st0
    fld1
    fld st1  ;z1z
    fprem    ;rem(z) 1 z
    f2xm1    ;2^rem(z)-1 1 z
    faddp st1,st0 ;2^rem(z) z
    fscale    ;2^z
    fstp      Q [numr0]
    fcomp st0

    dtextq  t12
    add       r14  , 12


    movsd     xmm0 , [numq]  ;log
    unpcklpd  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 13
    int60
    movapd    dqword [numr0], xmm0

    dtextq2 t13
    fldl2e
    fld1
    fdivrp st1,st0
    fld       Q [numq]
    fyl2x
    fstp      Q [numr0]

    dtextq  t13
    add       r14  , 12


    movsd     xmm0 , [numq]  ;log2
    unpcklpd  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 14
    int60
    movapd    dqword [numr0], xmm0

    dtextq2 t14
    fld1
    fld1
    fdivrp st1,st0
    fld       Q [numq]
    fyl2x
    fstp      Q [numr0]

    dtextq  t14
    add       r14  , 12


    movsd     xmm0 , [numq]  ;log10
    unpcklpd  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 15
    int60
    movapd    dqword [numr0], xmm0

    dtextq2 t15
    fldl2t
    fld1
    fdivrp st1,st0
    fld       Q [numq]
    fyl2x
    fstp      Q [numr0]

    dtextq  t15
    add       r14  , 12


    movsd     xmm0 , [numq]  ;ldexp
    unpcklpd  xmm0 , xmm0
    movsd     xmm1 , [numq + 8]
    unpcklpd  xmm1 , xmm1
    cvtpd2dq  xmm1 , xmm1
    mov       eax  , 151
    mov       ebx  , 18
    int60
    movapd    dqword [numr0], xmm0

    dtextq2 t16
    fld       Q [numq + 8]
    frndint
    fld       Q [numq]
    fscale
    fstp      Q [numr0]
    fcomp st0

    dtextq  t16
    add       r14  , 12


    movsd     xmm0 , [numq]  ;ilogb
    unpcklpd  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 19
    int60
    movapd    dqword [numr0], xmm0

    dtextq2 t17
    fld       Q [numq]
    fxtract
    fisttp    Q [numr0] ;!sse3
    fcomp st0

    dtextq  t17
    add       r14  , 12

    add       r14  , 12






    xorpd xmm0,xmm0
    movsd     xmm0 , [numq]  ;cos
;    unpcklpd  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 20
    int60
    movapd    dqword [numr0], xmm0

    dtextq2 t00
    fld       Q [numq]
    fcos
    fstp      Q [numr0]

    dtextq  t00
    add       r14  , 12


    xorpd xmm0,xmm0
    movsd     xmm0 , [numq]  ;sin
;    unpcklpd  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 21
    int60
    movapd    dqword [numr0], xmm0

    dtextq2 t01
    fld       Q [numq]
    fsin
    fstp      Q [numr0]

    dtextq  t01
    add       r14  , 12


    xorpd xmm0,xmm0
    movsd     xmm0 , [numq]  ;sincos
;    unpcklpd  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 22
    int60
    movapd    dqword [numr0], xmm0
    movapd    dqword [numr1], xmm1

    dtextq2_ t02
    fld       Q [numq]
    fsincos
    fxch
    fstp      Q [numr0]
    fstp      Q [numr0 + 8]

    dtextq_  t02
    add       r14  , 12+12


    xorpd xmm0,xmm0
    movsd     xmm0 , [numq]  ;tan
;    unpcklpd  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 23
    int60
    movapd    dqword [numr0], xmm0

    dtextq2 t03
    fld       Q [numq]
    fptan
    fcomp st0
    fstp      Q [numr0]

    dtextq  t03
    add       r14  , 12


    xorpd xmm0,xmm0
    movsd     xmm0 , [numq]  ;atan
;    unpcklpd  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 24
    int60
    movapd    dqword [numr0], xmm0

    dtextq2 t04
    fld       Q [numq]
    fld1
    fpatan
    fstp      Q [numr0]

    dtextq  t04
    add       r14  , 12


    xorpd xmm0,xmm0
    xorpd xmm1,xmm1
    movsd     xmm0 , [numq]  ;atan2
;    unpcklpd  xmm0 , xmm0
    movsd     xmm1 , [numq + 8]
;    unpcklpd  xmm1 , xmm1
    mov       eax  , 151
    mov       ebx  , 25
    int60
    movapd    dqword [numr0], xmm0

    dtextq2 t05
    fld       Q [numq]
    fld       Q [numq + 8]
    fpatan
    fstp      Q [numr0]

    dtextq  t05
    add       r14  , 12


    xorpd xmm0,xmm0
    movsd     xmm0 , [numq]  ;acos
;    unpcklpd  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 26
    int60
    movapd    dqword [numr0], xmm0

    dtextq2 t06
    mov rax,0x8000000000000000
    mov [numr0],rax

    dtextq  t06
    add       r14  , 12


    xorpd xmm0,xmm0
    movsd     xmm0 , [numq]  ;asin
;    unpcklpd  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 27
    int60
    movapd    dqword [numr0], xmm0

    dtextq2 t07
    mov rax,0x8000000000000000
    mov [numr0],rax

    dtextq  t07
    add       r14  , 12


    xorpd xmm0,xmm0
    xorpd xmm1,xmm1
    movsd     xmm0 , [numq]  ;pow
;    unpcklpd  xmm0 , xmm0
    movsd     xmm1 , [numq + 8]
;    unpcklpd  xmm1 , xmm1
    mov       eax  , 151
    mov       ebx  , 28
    int60
    movapd    dqword [numr0], xmm0

    dtextq2 t08
    fld       Q [numq + 8]
    fld       Q [numq]
    fyl2x
    fld1
    fld st1  ;z1z
    fprem    ;rem(z) 1 z
    f2xm1    ;2^rem(z)-1 1 z
    faddp st1,st0 ;2^rem(z) z
    fscale    ;2^z
    fstp      Q [numr0]
    fcomp st0

    dtextq  t08
    add       r14  , 12


    xorpd xmm0,xmm0
    movsd     xmm0 , [numq]  ;cbrt
;    unpcklpd  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 29
    int60
    movapd    dqword [numr0], xmm0

    dtextq2 t09
    mov rax,0x8000000000000000
    mov [numr0],rax

    dtextq  t09
    add       r14  , 12


    xorpd xmm0,xmm0
    movsd     xmm0 , [numq]  ;exp
;    unpcklpd  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 30
    int60
    movapd    dqword [numr0], xmm0

    dtextq2 t10
    fld       Q [numq]
    fldl2e
    fmulp st1,st0
    fld1
    fld st1  ;z1z
    fprem    ;rem(z) 1 z
    f2xm1    ;2^rem(z)-1 1 z
    faddp st1,st0 ;2^rem(z) z
    fscale    ;2^z
    fstp      Q [numr0]
    fcomp st0

    dtextq  t10
    add       r14  , 12


    xorpd xmm0,xmm0
    movsd     xmm0 , [numq]  ;exp2
;    unpcklpd  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 31
    int60
    movapd    dqword [numr0], xmm0

    dtextq2 t11
    fld       Q [numq]
    fld1
    fmulp st1,st0
    fld1
    fld st1  ;z1z
    fprem    ;rem(z) 1 z
    f2xm1    ;2^rem(z)-1 1 z
    faddp st1,st0 ;2^rem(z) z
    fscale    ;2^z
    fstp      Q [numr0]
    fcomp st0

    dtextq  t11
    add       r14  , 12


    xorpd xmm0,xmm0
    movsd     xmm0 , [numq]  ;exp10
;    unpcklpd  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 32
    int60
    movapd    dqword [numr0], xmm0

    dtextq2 t12
    fld       Q [numq]
    fldl2t
    fmulp st1,st0
    fld1
    fld st1  ;z1z
    fprem    ;rem(z) 1 z
    f2xm1    ;2^rem(z)-1 1 z
    faddp st1,st0 ;2^rem(z) z
    fscale    ;2^z
    fstp      Q [numr0]
    fcomp st0

    dtextq  t12
    add       r14  , 12


    xorpd xmm0,xmm0
    movsd     xmm0 , [numq]  ;log
;    unpcklpd  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 33
    int60
    movapd    dqword [numr0], xmm0

    dtextq2 t13
    fldl2e
    fld1
    fdivrp st1,st0
    fld       Q [numq]
    fyl2x
    fstp      Q [numr0]

    dtextq  t13
    add       r14  , 12


    xorpd xmm0,xmm0
    movsd     xmm0 , [numq]  ;log2
;    unpcklpd  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 34
    int60
    movapd    dqword [numr0], xmm0

    dtextq2 t14
    fld1
    fld1
    fdivrp st1,st0
    fld       Q [numq]
    fyl2x
    fstp      Q [numr0]

    dtextq  t14
    add       r14  , 12


    xorpd xmm0,xmm0
    movsd     xmm0 , [numq]  ;log10
;    unpcklpd  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 35
    int60
    movapd    dqword [numr0], xmm0

    dtextq2 t15
    fldl2t
    fld1
    fdivrp st1,st0
    fld       Q [numq]
    fyl2x
    fstp      Q [numr0]

    dtextq  t15
    add       r14  , 12


    xorpd xmm0,xmm0
    xorpd xmm1,xmm1
    movsd     xmm0 , [numq]  ;ldexp
;    unpcklpd  xmm0 , xmm0
    movsd     xmm1 , [numq + 8]
;    unpcklpd  xmm1 , xmm1
    cvtpd2dq  xmm1 , xmm1
    mov       eax  , 151
    mov       ebx  , 38
    int60
    movapd    dqword [numr0], xmm0

    dtextq2 t16
    fld       Q [numq + 8]
    frndint
    fld       Q [numq]
    fscale
    fstp      Q [numr0]
    fcomp st0

    dtextq  t16
    add       r14  , 12


    xorpd xmm0,xmm0
    movsd     xmm0 , [numq]  ;ilogb
;    unpcklpd  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 39
    int60
    movapd    dqword [numr0], xmm0

    dtextq2 t17
    fld       Q [numq]
    fxtract
    fisttp    Q [numr0] ;!sse3
    fcomp st0

    dtextq  t17
    add       r14  , 12

    add       r14  , 12





    movss     xmm0 , [numd]  ;cos
    unpcklps  xmm0 , xmm0
    unpcklps  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 40
    int60
    movapd    dqword [numr0], xmm0

    stextq2 t00
    fld       D [numd]
    fcos
    fstp      D [numr0]

    stextq  t00
    add       r14  , 12


    movss     xmm0 , [numd]  ;sin
    unpcklps  xmm0 , xmm0
    unpcklps  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 41
    int60
    movapd    dqword [numr0], xmm0

    stextq2 t01
    fld       D [numd]
    fsin
    fstp      D [numr0]

    stextq  t01
    add       r14  , 12


    movss     xmm0 , [numd]  ;sincos
    unpcklps  xmm0 , xmm0
    unpcklps  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 42
    int60
    movapd    dqword [numr0], xmm0
    movapd    dqword [numr1], xmm1

    stextq2_ t02
    fld       D [numd]
    fsincos
    fxch
    fstp      D [numr0]
    fstp      D [numr0 + 4]

    stextq_  t02
    add       r14  , 12+12


    movss     xmm0 , [numd]  ;tan
    unpcklps  xmm0 , xmm0
    unpcklps  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 43
    int60
    movapd    dqword [numr0], xmm0

    stextq2 t03
    fld       D [numd]
    fptan
    fcomp st0
    fstp      D [numr0]

    stextq  t03
    add       r14  , 12


    movss     xmm0 , [numd]  ;atan
    unpcklps  xmm0 , xmm0
    unpcklps  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 44
    int60
    movapd    dqword [numr0], xmm0

    stextq2 t04
    fld       D [numd]
    fld1
    fpatan
    fstp      D [numr0]

    stextq  t04
    add       r14  , 12


    movss     xmm0 , [numd]  ;atan2
    unpcklps  xmm0 , xmm0
    unpcklps  xmm0 , xmm0
    movss     xmm1 , [numd + 4]
    unpcklps  xmm1 , xmm1
    unpcklps  xmm1 , xmm1
    mov       eax  , 151
    mov       ebx  , 45
    int60
    movapd    dqword [numr0], xmm0

    stextq2 t05
    fld       D [numd]
    fld       D [numd + 4]
    fpatan
    fstp      D [numr0]

    stextq  t05
    add       r14  , 12


    movss     xmm0 , [numd]  ;acos
    unpcklps  xmm0 , xmm0
    unpcklps  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 46
    int60
    movapd    dqword [numr0], xmm0

    stextq2 t06
    mov eax,0x80000000
    mov D [numr0],eax

    stextq  t06
    add       r14  , 12


    movss     xmm0 , [numd]  ;asin
    unpcklps  xmm0 , xmm0
    unpcklps  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 47
    int60
    movapd    dqword [numr0], xmm0

    stextq2 t07
    mov eax,0x80000000
    mov D [numr0],eax

    stextq  t07
    add       r14  , 12


    movss     xmm0 , [numd]  ;pow
    unpcklps  xmm0 , xmm0
    unpcklps  xmm0 , xmm0
    movss     xmm1 , [numd + 4]
    unpcklps  xmm1 , xmm1
    unpcklps  xmm1 , xmm1
    mov       eax  , 151
    mov       ebx  , 48
    int60
    movapd    dqword [numr0], xmm0

    stextq2 t08
    fld       D [numd + 4]
    fld       D [numd]
    fyl2x
    fld1
    fld st1  ;z1z
    fprem    ;rem(z) 1 z
    f2xm1    ;2^rem(z)-1 1 z
    faddp st1,st0 ;2^rem(z) z
    fscale    ;2^z
    fstp      D [numr0]
    fcomp st0

    stextq  t08
    add       r14  , 12


    movss     xmm0 , [numd]  ;cbrt
    unpcklps  xmm0 , xmm0
    unpcklps  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 49
    int60
    movapd    dqword [numr0], xmm0

    stextq2 t09
    mov eax,0x80000000
    mov D [numr0],eax

    stextq  t09
    add       r14  , 12


    movss     xmm0 , [numd]  ;exp
    unpcklps  xmm0 , xmm0
    unpcklps  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 50
    int60
    movapd    dqword [numr0], xmm0

    stextq2 t10
    fld       D [numd]
    fldl2e
    fmulp st1,st0
    fld1
    fld st1  ;z1z
    fprem    ;rem(z) 1 z
    f2xm1    ;2^rem(z)-1 1 z
    faddp st1,st0 ;2^rem(z) z
    fscale    ;2^z
    fstp      D [numr0]
    fcomp st0

    stextq  t10
    add       r14  , 12


    movss     xmm0 , [numd]  ;exp2
    unpcklps  xmm0 , xmm0
    unpcklps  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 51
    int60
    movapd    dqword [numr0], xmm0

    stextq2 t11
    fld       D [numd]
    fld1
    fmulp st1,st0
    fld1
    fld st1  ;z1z
    fprem    ;rem(z) 1 z
    f2xm1    ;2^rem(z)-1 1 z
    faddp st1,st0 ;2^rem(z) z
    fscale    ;2^z
    fstp      D [numr0]
    fcomp st0

    stextq  t11
    add       r14  , 12


    movss     xmm0 , [numd]  ;exp10
    unpcklps  xmm0 , xmm0
    unpcklps  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 52
    int60
    movapd    dqword [numr0], xmm0

    stextq2 t12
    fld       D [numd]
    fldl2t
    fmulp st1,st0
    fld1
    fld st1  ;z1z
    fprem    ;rem(z) 1 z
    f2xm1    ;2^rem(z)-1 1 z
    faddp st1,st0 ;2^rem(z) z
    fscale    ;2^z
    fstp      D [numr0]
    fcomp st0

    stextq  t12
    add       r14  , 12


    movss     xmm0 , [numd]  ;log
    unpcklps  xmm0 , xmm0
    unpcklps  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 53
    int60
    movapd    dqword [numr0], xmm0

    stextq2 t13
    fldl2e
    fld1
    fdivrp st1,st0
    fld       D [numd]
    fyl2x
    fstp      D [numr0]

    stextq  t13
    add       r14  , 12


    movss     xmm0 , [numd]  ;log2
    unpcklps  xmm0 , xmm0
    unpcklps  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 54
    int60
    movapd    dqword [numr0], xmm0

    stextq2 t14
    fld1
    fld1
    fdivrp st1,st0
    fld       D [numd]
    fyl2x
    fstp      D [numr0]

    stextq  t14
    add       r14  , 12


    movss     xmm0 , [numd]  ;log10
    unpcklps  xmm0 , xmm0
    unpcklps  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 55
    int60
    movapd    dqword [numr0], xmm0

    stextq2 t15
    fldl2t
    fld1
    fdivrp st1,st0
    fld       D [numd]
    fyl2x
    fstp      D [numr0]

    stextq  t15
    add       r14  , 12


    movss     xmm0 , [numd]  ;ldexp
    unpcklps  xmm0 , xmm0
    unpcklps  xmm0 , xmm0
    movss     xmm1 , [numd + 4]
    unpcklps  xmm1 , xmm1
    unpcklps  xmm1 , xmm1
    cvtps2dq  xmm1 , xmm1
    mov       eax  , 151
    mov       ebx  , 58
    int60
    movapd    dqword [numr0], xmm0

    stextq2 t16
    fld       D [numd + 4]
    frndint
    fld       D [numd]
    fscale
    fstp      D [numr0]
    fcomp st0

    stextq  t16
    add       r14  , 12


    movss     xmm0 , [numd]  ;ilogb
    unpcklps  xmm0 , xmm0
    unpcklps  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 59
    int60
    movapd    dqword [numr0], xmm0

    stextq2 t17
    fld       D [numd]
    fxtract
    fisttp    D [numr0] ;!sse3
    fcomp st0

    stextq  t17
    add       r14  , 12

    add       r14  , 12






    xorps  xmm0,xmm0
    movss     xmm0 , [numd]  ;cos
;    unpcklps  xmm0 , xmm0
;    unpcklps  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 60
    int60
    movapd    dqword [numr0], xmm0

    stextq2 t00
    fld       D [numd]
    fcos
    fstp      D [numr0]

    stextq  t00
    add       r14  , 12


    xorps  xmm0,xmm0
    movss     xmm0 , [numd]  ;sin
;    unpcklps  xmm0 , xmm0
;    unpcklps  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 61
    int60
    movapd    dqword [numr0], xmm0

    stextq2 t01
    fld       D [numd]
    fsin
    fstp      D [numr0]

    stextq  t01
    add       r14  , 12


    xorps  xmm0,xmm0
    movss     xmm0 , [numd]  ;sincos
;    unpcklps  xmm0 , xmm0
;    unpcklps  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 62
    int60
    movapd    dqword [numr0], xmm0
    movapd    dqword [numr1], xmm1

    stextq2_ t02
    fld       D [numd]
    fsincos
    fxch
    fstp      D [numr0]
    fstp      D [numr0 + 4]

    stextq_  t02
    add       r14  , 12+12


    xorps  xmm0,xmm0
    movss     xmm0 , [numd]  ;tan
;    unpcklps  xmm0 , xmm0
;    unpcklps  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 63
    int60
    movapd    dqword [numr0], xmm0

    stextq2 t03
    fld       D [numd]
    fptan
    fcomp st0
    fstp      D [numr0]

    stextq  t03
    add       r14  , 12


    xorps  xmm0,xmm0
    movss     xmm0 , [numd]  ;atan
;    unpcklps  xmm0 , xmm0
;    unpcklps  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 64
    int60
    movapd    dqword [numr0], xmm0

    stextq2 t04
    fld       D [numd]
    fld1
    fpatan
    fstp      D [numr0]

    stextq  t04
    add       r14  , 12


    xorps  xmm0,xmm0
    xorps  xmm1,xmm1
    movss     xmm0 , [numd]  ;atan2
;    unpcklps  xmm0 , xmm0
;    unpcklps  xmm0 , xmm0
    movss     xmm1 , [numd + 4]
;    unpcklps  xmm1 , xmm1
;    unpcklps  xmm1 , xmm1
    mov       eax  , 151
    mov       ebx  , 65
    int60
    movapd    dqword [numr0], xmm0

    stextq2 t05
    fld       D [numd]
    fld       D [numd + 4]
    fpatan
    fstp      D [numr0]

    stextq  t05
    add       r14  , 12


    xorps  xmm0,xmm0
    movss     xmm0 , [numd]  ;acos
;    unpcklps  xmm0 , xmm0
;    unpcklps  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 66
    int60
    movapd    dqword [numr0], xmm0

    stextq2 t06
    mov eax,0x80000000
    mov D [numr0],eax

    stextq  t06
    add       r14  , 12


    xorps  xmm0,xmm0
    movss     xmm0 , [numd]  ;asin
;    unpcklps  xmm0 , xmm0
;    unpcklps  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 67
    int60
    movapd    dqword [numr0], xmm0

    stextq2 t07
    mov eax,0x80000000
    mov D [numr0],eax

    stextq  t07
    add       r14  , 12


    xorps  xmm0,xmm0
    xorps  xmm1,xmm1
    movss     xmm0 , [numd]  ;pow
;    unpcklps  xmm0 , xmm0
;    unpcklps  xmm0 , xmm0
    movss     xmm1 , [numd + 4]
;    unpcklps  xmm1 , xmm1
;    unpcklps  xmm1 , xmm1
    mov       eax  , 151
    mov       ebx  , 68
    int60
    movapd    dqword [numr0], xmm0

    stextq2 t08
    fld       D [numd + 4]
    fld       D [numd]
    fyl2x
    fld1
    fld st1  ;z1z
    fprem    ;rem(z) 1 z
    f2xm1    ;2^rem(z)-1 1 z
    faddp st1,st0 ;2^rem(z) z
    fscale    ;2^z
    fstp      D [numr0]
    fcomp st0

    stextq  t08
    add       r14  , 12


    xorps  xmm0,xmm0
    movss     xmm0 , [numd]  ;cbrt
;    unpcklps  xmm0 , xmm0
;    unpcklps  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 69
    int60
    movapd    dqword [numr0], xmm0

    stextq2 t09
    mov eax,0x80000000
    mov D [numr0],eax

    stextq  t09
    add       r14  , 12


    xorps  xmm0,xmm0
    movss     xmm0 , [numd]  ;exp
;    unpcklps  xmm0 , xmm0
;    unpcklps  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 70
    int60
    movapd    dqword [numr0], xmm0

    stextq2 t10
    fld       D [numd]
    fldl2e
    fmulp st1,st0
    fld1
    fld st1  ;z1z
    fprem    ;rem(z) 1 z
    f2xm1    ;2^rem(z)-1 1 z
    faddp st1,st0 ;2^rem(z) z
    fscale    ;2^z
    fstp      D [numr0]
    fcomp st0

    stextq  t10
    add       r14  , 12


    xorps  xmm0,xmm0
    movss     xmm0 , [numd]  ;exp2
;    unpcklps  xmm0 , xmm0
;    unpcklps  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 71
    int60
    movapd    dqword [numr0], xmm0

    stextq2 t11
    fld       D [numd]
    fld1
    fmulp st1,st0
    fld1
    fld st1  ;z1z
    fprem    ;rem(z) 1 z
    f2xm1    ;2^rem(z)-1 1 z
    faddp st1,st0 ;2^rem(z) z
    fscale    ;2^z
    fstp      D [numr0]
    fcomp st0

    stextq  t11
    add       r14  , 12


    xorps  xmm0,xmm0
    movss     xmm0 , [numd]  ;exp10
;    unpcklps  xmm0 , xmm0
;    unpcklps  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 72
    int60
    movapd    dqword [numr0], xmm0

    stextq2 t12
    fld       D [numd]
    fldl2t
    fmulp st1,st0
    fld1
    fld st1  ;z1z
    fprem    ;rem(z) 1 z
    f2xm1    ;2^rem(z)-1 1 z
    faddp st1,st0 ;2^rem(z) z
    fscale    ;2^z
    fstp      D [numr0]
    fcomp st0

    stextq  t12
    add       r14  , 12


    xorps  xmm0,xmm0
    movss     xmm0 , [numd]  ;log
;    unpcklps  xmm0 , xmm0
;    unpcklps  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 73
    int60
    movapd    dqword [numr0], xmm0

    stextq2 t13
    fldl2e
    fld1
    fdivrp st1,st0
    fld       D [numd]
    fyl2x
    fstp      D [numr0]

    stextq  t13
    add       r14  , 12


    xorps  xmm0,xmm0
    movss     xmm0 , [numd]  ;log2
;    unpcklps  xmm0 , xmm0
;    unpcklps  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 74
    int60
    movapd    dqword [numr0], xmm0

    stextq2 t14
    fld1
    fld1
    fdivrp st1,st0
    fld       D [numd]
    fyl2x
    fstp      D [numr0]

    stextq  t14
    add       r14  , 12


    xorps  xmm0,xmm0
    movss     xmm0 , [numd]  ;log10
;    unpcklps  xmm0 , xmm0
;    unpcklps  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 75
    int60
    movapd    dqword [numr0], xmm0

    stextq2 t15
    fldl2t
    fld1
    fdivrp st1,st0
    fld       D [numd]
    fyl2x
    fstp      D [numr0]

    stextq  t15
    add       r14  , 12


    xorps  xmm0,xmm0
    movss     xmm0 , [numd]  ;ldexp
;    unpcklps  xmm0 , xmm0
;    unpcklps  xmm0 , xmm0
    movss     xmm1 , [numd + 4]
;    unpcklps  xmm1 , xmm1
;    unpcklps  xmm1 , xmm1
    cvtps2dq  xmm1 , xmm1
    mov       eax  , 151
    mov       ebx  , 78
    int60
    movapd    dqword [numr0], xmm0

    stextq2 t16
    fld       D [numd + 4]
    frndint
    fld       D [numd]
    fscale
    fstp      D [numr0]
    fcomp st0

    stextq  t16
    add       r14  , 12


    xorps  xmm0,xmm0
    movss     xmm0 , [numd]  ;ilogb
;    unpcklps  xmm0 , xmm0
;    unpcklps  xmm0 , xmm0
    mov       eax  , 151
    mov       ebx  , 79
    int60
    movapd    dqword [numr0], xmm0

    stextq2 t17
    fld       D [numd]
    fxtract
    fisttp    D [numr0] ;!sse3
    fcomp st0

    stextq  t17
    add       r14  , 12

    add       r14  , 12




    mov   rax , 12                           ; End of window draw
    mov   rbx , 2
    int   0x60

    ret


rand:
                      push   rbx
                      mov    rax,qword [randseed]
                      rol    rax,32
                      mov    rbx,rax
                      rol    rbx,3
                      xor    rbx,rax
                      shr    rax,32
                      shl    rbx,32
                      shld   rax,rbx,32
                      mov    qword [randseed],rax
                      pop    rbx
                      ret


align 16
; Data area

    numr0  dq 0,0  ;
    numr1  dq 0,0

    numq   dq 0,0
    numd   dd 0,0

    sbval  dq 0x1000


randseed         db 'aabacadaaabacada'


window_label:

    db    'Mathlib example',0     ; Window label

t00  db    'cos',0
t01  db    'sin',0
t02  db    'sincos',0
t03  db    'tan',0
t04  db    'atan',0
t05  db    'atan2',0
t06  db    'acos',0
t07  db    'asin',0
t08  db    'pow',0
t09  db    'cbrt',0
t10  db    'exp',0
t11  db    'exp2',0
t12  db    'exp10',0
t13  db    'log',0
t14  db    'log2',0
t15  db    'log10',0
t16  db    'ldexp',0
t17  db    'ilogb',0


menu_struct:               ; Menu Struct

    dq   0                 ; Version

    dq   0x100             ; Start value of ID to return ( ID + Line )

                           ; Returned when menu closes and
                           ; user made no selections.

;    db   0,'FILE',0        ; ID = 0x100 + 1
;    db   1,'New',0         ; ID = 0x100 + 2
;    db   1,'Open..',0      ; ID = 0x100 + 3
;    db   1,'Save..',0      ; ID = 0x100 + 4
;    db   1,'-',0           ; ID = 0x100 + 5
;    db   1,'Quit',0        ; ID = 0x100 + 6

    db   0,'HELP',0        ; ID = 0x100 + 7
    db   1,'Contents..',0  ; ID = 0x100 + 8
    db   1,'About..',0     ; ID = 0x100 + 9

    db   255               ; End of Menu Struct

image_end:

