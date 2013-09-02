;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Mandelbrot and Buddhabrot by randall (flatassembler forum)
;
;   32bit Menuet port by macgub (www.macgub.hekko.pl)
;
;   SMP 64bit Menuet port by V.Turjanmaa
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use64

    org   0x0

    db    'MENUET64'              ; Header identifier
    dq    0x01                    ; Version
    dq    START                   ; Start of code
    dq    image_end               ; Size of image
    dq    0x400000                ; Memory for app
    dq    0x3ffff0                ; Rsp
    dq    0x00                    ; Prm
    dq    0x00                    ; Icon


START:

    call  clear_memory

    call  get_cpu_count

    call  draw_window       ; At first, draw the window

    call  add_mouse_event

    call  generate_palette

    ; Calculate Mandelbrot
    call  calculate

still:

    mov   rax , 123          ; Wait here for event
    mov   rbx , 1000
    int   0x60

    test  rax , 1           ; Window redraw
    jnz   window_event
    test  rax , 2           ; Keyboard press
    jnz   key_event
    test  rax , 4           ; Button press
    jnz   button_event
    test  rax , 100000b     ; Button press
    jnz   mouse_event

    cmp   [viewselect],byte 1
    je    check_buddhabrot

    jmp   still


mouse_event:

    cmp   [viewselect],byte 0
    jne   still

    mov   rax , 111
    mov   rbx , 2
    int   0x60
    cmp   rax , 0
    jne   still

    mov   rax , 37
    mov   rbx , 2
    int   0x60

    cmp   rax , 0
    je    still

    ;
    ; Zoom in
    ;
    cmp    rax , 1
    jne    nomouseleft
    call   setcenter
    cmp    rax , 1
    je     still
    add    [zoomlevel],dword 1
    call   setbailout
    movaps xmm1 , dqword [g_zoom]
    divps  xmm1 , dqword [g_0_5]
    movaps dqword [g_zoom],xmm1
    call   calculate
    jmp    still
  nomouseleft:

    ;
    ; Zoom out
    ;
    cmp    rax , 2
    jne    nomouseright
    cmp    [zoomlevel],dword 1
    jbe    still
    call   setcenter
    cmp    rax , 1
    je     still
    sub    [zoomlevel],dword 1
    call   setbailout
    movaps xmm1 , dqword [g_zoom]
    mulps  xmm1 , dqword [g_0_5]
    movaps dqword [g_zoom],xmm1
    call   calculate
    jmp    still
  nomouseright:

    jmp   still



setbailout:

    push  rax

    mov   [g_bailout],dword 300
    cmp   [bailouttype],byte 1
    jne   sbol1
    mov   rax , [zoomlevel]
    imul  rax , 50
    mov   [g_bailout],eax
  sbol1:

    pop   rax

    ret


setcenter:

    mov   rax , 37
    mov   rbx , 1
    int   0x60

    mov   rbx , rax
    and   rbx , 0xffff
    sub   rbx , 38
    cmp   rbx , SIZE
    jae   nosearchnew

    shr   rax , 32
    and   rax , 0xffff
    sub   rax , 5
    cmp   rax , SIZE
    jae   nosearchnew

    cvtsi2ss xmm0,eax
    cvtsi2ss xmm1,ebx
    shufps   xmm0,xmm1,00000000b
    shufps   xmm0,xmm0,00001000b
    divps    xmm0,dqword [g_size]
    subps    xmm0,dqword [g_0_5]
    addps    xmm0,xmm0
    movaps   xmm13,xmm0
    divps    xmm13,dqword [g_zoom]
    addps    xmm13,dqword [g_center]
    movaps   dqword [g_center],xmm13

    mov   rax , 0
    ret

  nosearchnew:

    mov   rax , 1
    ret


calculate:

    call  mandelbrot_thread
    call  waitmouse

    ret


clear_memory:

    push  rax rcx rdi

    mov   rdi , threadys
    mov   rcx , image_end - threadys
    mov   rax , 0
    cld
    rep   stosb

    pop   rdi rcx rax

    ret


get_cpu_count:

    ; Get CPU count
    mov   rax , 140
    mov   rbx , 2
    int   0x60

    mov   rcx , 1
    mov   rdx , 4
    cmp   rbx , rcx
    cmovb rbx , rcx
    cmp   rbx , rdx
    cmova rbx , rdx
    mov   [cpucount],rbx

    ret


mandelbrot_thread:

    mov   [imageystart],dword 0

    ;
    ; Start threads
    ;

    mov   r10 , 0

  newmandelthread:

    mov   [threadrunning+8*r10],dword 0

    ; Calculate in thread
    mov   rax , 140
    mov   rbx , 3
    mov   rcx , mandelbrot
    mov   rdx , r10
    add   rdx , 1
    imul  rdx , 1024
    add   rdx , threadstack
    mov   rdi , r10
    int   0x60

    add   r10 , 1
    cmp   r10 , [cpucount]
    jb    newmandelthread

    ;
    ; Wait for threads to accept parameters
    ;

  waitthreadaccept:

    mov   rax , 105
    mov   rbx , 1
    int   0x60

    mov   rax , 0

  threadacceptcheck:

    cmp   [threadrunning+8*rax],byte 0
    jne   threadcalculating

    mov   rbx , [imageystart]
    mov   [threadys+8*rax],rbx
    mov   rcx , rbx
    add   rbx , SIZE/20
    mov   [threadye+8*rax],rbx
    imul  rcx , 4*SIZE
    add   rcx , image
    mov   [threadimage+8*rax],rcx
    mov   [threadrunning+8*rax],byte 1

    add   [imageystart],dword SIZE/20

    cmp   [imageystart],dword SIZE
    jae   imagedone

  threadcalculating:

    add   rax , 1
    cmp   rax , [cpucount]
    jb    threadacceptcheck

    jmp   waitthreadaccept

  imagedone:

    ;
    ; Wait for completion
    ;

  waitthreadend:

    mov   rax , 105
    mov   rbx , 1
    int   0x60

    mov   rax , 0

  newthreadendcheck:

    cmp   [threadrunning+8*rax],byte 2
    je    threadhalting

    cmp   [threadrunning+8*rax],byte 0
    jne   waitthreadend

    mov   [threadrunning+8*rax],byte 2

  threadhalting:

    add   rax , 1
    cmp   rax , [cpucount]
    jb    newthreadendcheck

    ;
    ; Display mandelbrot
    ;

    call  display_result

    ;
    ; Wait for threads to exit
    ;
    mov   rax , 5
    mov   rbx , 10
    int   0x60

    ret



waitmouse:

    mov   rax , 5
    mov   rbx , 1
    int   0x60
    mov   rax , 37
    mov   rbx , 2
    int   0x60
    cmp   rax , 0
    jne   waitmouse

    ret


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

    cmp   rbx , 0x10000001
    jne   no_application_terminate_button
    mov   rax , 0x200
    int   0x60
  no_application_terminate_button:

    cmp   rbx , 0x105
    jne   no_application_terminate_menu
    mov   rax , 0x200
    int   0x60
  no_application_terminate_menu:

    ; Select mandelbrot
    cmp   rbx , 0x102
    jne   no_mandelbrot
    cmp   [threadstatus],byte 2
    jne   still
    mov   [set],byte 0
    mov   [mb1+1],byte '>'
    mov   [mb2+1],byte ' '
    mov   [viewselect],byte 0
    call  clear_display
    call  draw_window
    call  add_mouse_event
    call  calculate
    call  display_result
    jmp   still
  no_mandelbrot:

    ; Select buddhabrot
    cmp   rbx , 0x103
    jne   no_buddhabrot
    cmp   [threadstatus],byte 2
    jne   still
    mov   [set],byte 255
    mov   [mb1+1],byte ' '
    mov   [mb2+1],byte '>'
    mov   [viewselect],byte 1
    call  clear_display
    call  draw_window
    call  remove_mouse_event
    mov   [threadstatus],byte 0
    ; Calculate in thread
    mov   rax , 51
    mov   rbx , 1
    mov   rcx , buddhabrot
    mov   rdx , 0x3efff0
    int   0x60
    jmp   still
  no_buddhabrot:

    ; Select palette
    cmp   rbx , 0x108
    jne   nopal0
    mov   [pa1+1],byte '>'
    mov   [pa2+1],byte ' '
    mov   [paletteselect],byte 0
    call  calculate
    call  display_result
    jmp   still
  nopal0:
    cmp   rbx , 0x109
    jne   nopal1
    mov   [pa1+1],byte ' '
    mov   [pa2+1],byte '>'
    mov   [paletteselect],byte 1
    call  calculate
    call  display_result
    jmp   still
  nopal1:

    ; Select bailout
    cmp   rbx , 0x10C
    jne   noba0
    mov   [bailouttype],byte 0
    mov   [ba1+1],byte '>'
    mov   [ba2+1],byte ' '
    call  setbailout
    call  calculate
    call  display_result
    jmp   still
  noba0:
    cmp   rbx , 0x10D
    jne   noba1
    mov   [bailouttype],byte 1
    mov   [ba1+1],byte ' '
    mov   [ba2+1],byte '>'
    call  setbailout
    call  calculate
    call  display_result
    jmp   still
  noba1:

    jmp   still


check_buddhabrot:

    cmp   [threadstatus],byte 2
    je    still
    call  display_result
    ; Thread finished ?
    cmp   [threadstatus],byte 1
    jne   still
    mov   [threadstatus],byte 2
    jmp   still


display_result:

    push  rax rbx rcx rdx r8 r9 r10

    cmp   [window_dimensions+24],dword 50
    jbe   nodr
    cmp   [window_dimensions+24],dword 1500
    jae   nodr

    mov   rax , 7
    mov   rbx ,  5 shl 32 + IMG_SIZE
    mov   rcx , 38 shl 32
    add   rcx , [window_dimensions+24]
    sub   rcx , 38+5
    mov   rdx , 0x000003ff000003ff
    and   rcx , rdx
    mov   rdx , image
    mov   r8  , 0
    mov   r9  , 0x01000000
    mov   r10 , 4
    int   0x60

  nodr:

    pop   r10 r9 r8 rdx rcx rbx rax

    ret


generate_palette:

    push  rax rbx rcx rdx

    mov   rcx , 0
  gp1:
    cmp   rcx , 128
    jae   gp2
    mov   rax , rcx
    shl   rax , 1
    jmp   gp3
  gp2:
    mov   rax , 255
    sub   rax , rcx
    shl   rax , 1
  gp3:
    imul  rax , 0x000102
    and   rax , 0x007fff
    mov   [palette+ecx*4],eax
    add   rcx , 1
    cmp   rcx , 255
    jbe   gp1

    pop   rdx rcx rbx rax

    ret



add_mouse_event:

    push  rax rbx
    mov   rax , 40
    mov   rbx , 100111b
    int   0x60
    pop   rbx rax
    ret


remove_mouse_event:

    push  rax rbx
    mov   rax , 40
    mov   rbx , 000111b
    int   0x60
    pop   rbx rax

    ret



clear_display:

    push  rax rcx rdi

    mov   rdi , image
    mov   rcx , SIZE*SIZE*4
    mov   rax , 0
    cld
    rep   stosb

    pop   rdi rcx rax

    ret


draw_window:

    mov   rax , 12                           ; Beginning of window draw
    mov   rbx , 1
    int   0x60

    mov   rax , 0                            ; Draw window
    mov   rbx , 30 shl 32 + SIZE+10          ; X start & size
    mov   rcx , 00 shl 32 + SIZE+38+5        ; Y start & size
    mov   rdx , 0x0000000000000000           ; Type    & border color
    mov   r8  , 0x0000000000000001           ; Flags (set as 1)
    mov   r9  , window_label                 ; 0 or label - asciiz
    mov   r10 , menu_struct                  ; 0 or pointer to menu struct
    int   0x60

    ; Window dimensions
    mov   rax , 111
    mov   rbx , 1
    int   0x60
    mov   rcx , rax
    mov   rax , 9
    mov   rbx , 2
    mov   rdx , window_dimensions
    mov   r8  , 768
    int   0x60

    ; System font
    mov   rax , 141
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    cmp   [viewselect],byte 0
    jne   nomousezoom
    mov   rax , [cpucount]
    add   rax , 48
    mov   [string_mouse+7],al
    mov   rax , 4
    mov   rbx , string_mouse
    mov   rcx , 364
    mov   rdx , 27
    mov   rsi , 0
    mov   r9  , 1
    int   0x60
  nomousezoom:

    call  display_result

    mov   rax , 12                           ; End of window draw
    mov   rbx , 2
    int   0x60

    ret



;-------------------------------------------------------------------------------
;               MANDELBROT CODE
;-------------------------------------------------------------------------------


;-------------------------------------------------------------------------------
; NAME:         logss
; IN:           xmm0.x      function argument
; OUT:          xmm0.x      function result
;-------------------------------------------------------------------------------
align 16
logss:
                maxss       xmm0,[g_min_norm_pos]
                movss       xmm1,[g_1_0]
                movd        edx,xmm0
                andps       xmm0,dqword [g_inv_mant_mask]
                orps        xmm0,xmm1
                movaps      xmm4,xmm0
                subss       xmm0,xmm1
                addss       xmm4,xmm1
                shr         edx,23
                rcpss       xmm4,xmm4
                mulss       xmm0,xmm4
                addss       xmm0,xmm0
                movaps      xmm2,xmm0
                mulss       xmm0,xmm0
                sub         edx,0x7f
                movss       xmm4,[g_log_p0]
                movss       xmm6,[g_log_q0]
                mulss       xmm4,xmm0
                movss       xmm5,[g_log_p1]
                mulss       xmm6,xmm0
                movss       xmm7,[g_log_q1]
                addss       xmm4,xmm5
                addss       xmm6,xmm7
                movss       xmm5,[g_log_p2]
                mulss       xmm4,xmm0
                movss       xmm7,[g_log_q2]
                mulss       xmm6,xmm0
                addss       xmm4,xmm5
                movss       xmm5,[g_log_c0]
                addss       xmm6,xmm7
                cvtsi2ss    xmm1,edx
                mulss       xmm0,xmm4
                rcpss       xmm6,xmm6
                mulss       xmm0,xmm6
                mulss       xmm0,xmm2
                mulss       xmm1,xmm5
                addss       xmm0,xmm2
                addss       xmm0,xmm1
                ret
;-------------------------------------------------------------------------------
; NAME:         mandelbrot
; DESC:         Program main function.
;-------------------------------------------------------------------------------
align 16
mandelbrot:
                mov         rbp , rsp
                sub         rbp , threadstack+1024
                shr         rbp , 10
              .mandelbrotnew:
                ;
                ; Wait for parameters
                ;
              .waitthreadcommand:
                cmp         [threadrunning+rbp*8],dword 2
                je          .stopthread
                cmp         [threadrunning+rbp*8],dword 1
                je          .mandelexec
                mov         rax , 105
                mov         rbx , 1
                int         0x60
                jmp         .waitthreadcommand
             .mandelexec:
                ;
                ; Calculate
                ;
                ; image location
                mov         rbx , [threadimage+rbp*8] ; target memory
                ; begin loops
                mov         r13 , [threadys+rbp*8]    ; .LoopY index
.LoopY:
                xor         r12d,r12d                 ; .LoopX index
.LoopX:
                ; compute c
                cvtsi2ss    xmm0,r12d
                cvtsi2ss    xmm1,r13d
                shufps      xmm0,xmm1,00000000b
                shufps      xmm0,xmm0,00001000b
                divps       xmm0,dqword [g_size]
                subps       xmm0,dqword [g_0_5]
                addps       xmm0,xmm0
                movaps      xmm13,xmm0
                divps       xmm13,dqword [g_zoom]

                addps       xmm13,dqword [g_center]   ; c = xmm13

                ; z = (0.0,0.0) dz = (1.0,0.0)
                xorps       xmm14,xmm14               ; z = xmm14
                xorps       xmm15,xmm15
                movss       xmm15,[g_1_0]             ; dz = xmm15
                mov         ecx,[g_bailout]
.LoopBailout:
                ; dz = 2.0 * z * dz + (1.0,0.0)
                movaps      xmm0,xmm14
                movaps      xmm1,xmm15
                shufps      xmm0,xmm0,01000100b
                shufps      xmm1,xmm1,00010100b
                mulps       xmm0,xmm1
                xorps       xmm0,dqword [g_inv_y_sign]
                movaps      xmm1,xmm0
                shufps      xmm0,xmm0,00001000b
                shufps      xmm1,xmm1,00001101b
                addps       xmm0,xmm1
                addps       xmm0,xmm0
                addss       xmm0,[g_1_0]
                movaps      xmm15,xmm0
                ; z = z * z + c
                movaps      xmm0,xmm14
                movaps      xmm1,xmm0
                shufps      xmm0,xmm0,00000100b
                shufps      xmm1,xmm1,01010100b
                mulps       xmm0,xmm1
                xorps       xmm0,dqword [g_inv_y_sign]
                movaps      xmm1,xmm0
                shufps      xmm0,xmm0,00001000b
                shufps      xmm1,xmm1,00001101b
                addps       xmm0,xmm1
                addps       xmm0,xmm13
                movaps      xmm14,xmm0
                ; compute dot(z,z)
                mulps       xmm0,xmm0
                movaps      xmm1,xmm0
                shufps      xmm1,xmm1,01010101b
                addps       xmm0,xmm1
                ; if dot(z,z) > g_z_max break .LoopBailout
                ucomiss     xmm0,[g_z_max]
                ja          .NotInSet
                sub         ecx,1
                jnz         .LoopBailout
                xorps       xmm0,xmm0   ; distance is zero
                jmp         .InSet
.NotInSet:
                movaps      xmm8,xmm0
                call        logss
                movaps      xmm9,xmm0
                movaps      xmm1,xmm15
                mulps       xmm1,xmm1
                movaps      xmm2,xmm1
                shufps      xmm2,xmm2,01010101b
                addps       xmm1,xmm2   ; dot(dz,dz)
                divps       xmm8,xmm1   ; dot(z,z) / dot(dz,dz)
                sqrtps      xmm0,xmm8
                mulps       xmm0,dqword [g_0_5]
                mulps       xmm0,xmm9
                mulps       xmm0,dqword [g_zoom]

                sqrtps      xmm0,xmm0
                sqrtps      xmm0,xmm0
                shufps      xmm0,xmm0,00000000b
                mulps       xmm0,dqword [g_brightness]
.InSet:
                ; convert from [0.0,1.0] to [0,255]
                mulps       xmm0,dqword [g_255_0]
                cvttps2dq   xmm0,xmm0
                movd        eax , xmm0
                cmp         [paletteselect],byte 1
                je          .paletterainbow
                and         eax , 0xff
                mov         eax , [palette+eax*4]
                mov         [rbx],eax
                jmp         .palettedone
              .paletterainbow:
                mov         [rbx],al
                pshufd      xmm1,xmm0,00000001b
                movd        eax,xmm1
                rol         al , 1
                mov         [rbx+1],al
                pshufd      xmm1,xmm0,00000010b
                movd        eax,xmm1
                rol         al , 2
                mov         [rbx+2],al
                mov         byte [rbx+3],255
              .palettedone:
                ; advance pixel pointer
                add         rbx,4
                ; continue .LoopX
                inc         r12d
                cmp         r12d,SIZE
                jne         .LoopX
                ; continue .LoopY
                inc         r13d
                cmp         r13d,[threadye+rbp*8]
                jne         .LoopY

                mov         [threadrunning+rbp*8],dword 0
                jmp         .mandelbrotnew
              .stopthread:
                mov         rax , 512
                int         0x60


;-------------------------------------------------------------------------------
;
;-------------------------------------------------------------------------------


;-------------------------------------------------------------------------------
;               BUDDHABROT CODE
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
; NAME:         XORWOW
; DESC:         Pseudo random number generator.
; OUT:          eax         [0;2^32-1]
;-------------------------------------------------------------------------------
macro           XORWOW      {
                mov         edx,[gb_xorwow_x]    ; edx = x
                shr         edx,2               ; edx = x >> 2
                xor         edx,[gb_xorwow_x]    ; t = x ^ (x >> 2)
                mov         eax,[gb_xorwow_y]    ; eax = y
                mov         [gb_xorwow_x],eax    ; x = y
                mov         eax,[gb_xorwow_z]    ; eax = z
                mov         [gb_xorwow_y],eax    ; y = z
                mov         eax,[gb_xorwow_w]    ; eax = w
                mov         [gb_xorwow_z],eax    ; z = w
                mov         eax,[gb_xorwow_v]    ; eax = v
                mov         [gb_xorwow_w],eax    ; w = v
                mov         edi,eax             ; edi = v
                shl         edi,4               ; edi = v << 4
                xor         edi,eax             ; edi = (v ^ (v << 4))
                mov         eax,edx             ; eax = t
                shl         eax,1               ; eax = t << 1
                xor         eax,edx             ; eax = (t ^ (t << 1))
                xor         eax,edi             ; eax = (v ^ (v << 4)) ^ (t ^ (t << 1))
                mov         [gb_xorwow_v],eax    ; v = eax
                add         [gb_xorwow_d],362437 ; d += 362437
                mov         eax,[gb_xorwow_d]    ; eax = d
                add         eax,[gb_xorwow_v]    ; eax = d + v
}
;-------------------------------------------------------------------------------
; NAME:         RANDOM
; DESC:         Returns pseudo random number in the range [-0.5;0.5).
; OUT:          xmm0.x      [-0.5;0.5)
;-------------------------------------------------------------------------------
macro           RANDOM {
                XORWOW
                cvtsi2ss    xmm0,eax
                mulss       xmm0,[gb_rand_scale]
}
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
; NAME:         GenerateSequence
; IN:           xmm0.x      re (c0.x)
; IN:           xmm1.x      im (c0.y)
; IN:           edi         array size
; IN/OUT:       esi         pointer to the allocated array
; OUT:          eax         generated sequence size
;-------------------------------------------------------------------------------
align 16
GenerateSequence:
                xor         eax,eax     ; eax is index loop
                xorps       xmm4,xmm4   ; xmm4 is c.x
                xorps       xmm5,xmm5   ; xmm5 is c.y
.Loop:
                ; cn.x = c.x * c.x - c.y * c.y + c0.x
                movaps      xmm2,xmm4
                movaps      xmm3,xmm5
                mulss       xmm2,xmm4
                mulss       xmm3,xmm5
                subss       xmm2,xmm3
                addss       xmm2,xmm0
                movaps      xmm6,xmm2   ; xmm6 is cn.x
                ; cn.y = 2.0 * c.x * c.y + c0.y
                movaps      xmm7,xmm4
                mulss       xmm7,xmm5
                addss       xmm7,xmm7
                addss       xmm7,xmm1   ; xmm7 is cn.y
                ; store cn
                movd        dword [esi+eax*8],xmm6
                movd        dword [esi+eax*8+4],xmm7
                ; if (cn.x * cn.x + cn.y * cn.y > 10.0) return eax;
                movaps      xmm2,xmm6
                movaps      xmm3,xmm7
                mulss       xmm2,xmm6
                mulss       xmm3,xmm7
                addss       xmm2,xmm3
                ucomiss     xmm2,[gb_max_dist]
                ja          .EndLoop
                movaps      xmm4,xmm6   ; c.x = cn.x
                movaps      xmm5,xmm7   ; c.y = cn.y
                ; continue loop
                inc         eax
                cmp         eax,edi
                jb          .Loop
                ; return 0
                xor         eax,eax
.EndLoop:
                ret
;-------------------------------------------------------------------------------
; NAME:         buddhabrot
; DESC:         Program main function.
;-------------------------------------------------------------------------------
align 16
buddhabrot:
                ; mem for the sequence
                lea         r10d,[sequence]
                ; mem for the image
                lea         r9d,[image]
                ; begin loops
                mov         r13 , 0
.LoopIterations:
                mov         r12 , 0
.LoopOneMillion:
                RANDOM
                mulss       xmm0,[gb_range]
                movaps      xmm1,xmm0
                RANDOM
                mulss       xmm0,[gb_range]
                mov         edi,SEQ_SIZE
                mov         esi,r10d ; [seq_ptr]
                call        GenerateSequence  ; eax = n sequence size
                test        eax,eax
                jz          .LoopSequenceEnd
                xor         ecx,ecx           ; ecx = i = 0 loop counter
                movss       xmm2,[gb_IMG_size]
                movaps      xmm3,xmm2
                mulss       xmm3,[gb_0_5]      ; xmm3 = (gb_IMG_size)/2
                movss       xmm4,[gb_zoom]
                mulss       xmm4,xmm2         ; xmm4 = gb_zoom * gb_IMG_size
                movss       xmm5,[gb_offsetx]  ; xmm5 = gb_offsetx
                movss       xmm6,[gb_offsety]  ; xmm6 = gb_offsety
.LoopSequence:
                cmp         ecx,eax           ; i < n
                je          .LoopSequenceEnd
                movd        xmm0,[sequence+ecx*8]   ; load re
                movd        xmm1,[sequence+ecx*8+4] ; load im
                addss       xmm0,xmm5         ; xmm0 = re+gb_offsetx
                addss       xmm1,xmm6         ; xmm1 = im+gb_offsety
                mulss       xmm0,xmm4         ; xmm0 = (re+gb_offsetx)*gb_IMG_size*gb_zoom
                mulss       xmm1,xmm4         ; xmm1 = (im+gb_offsety)*gb_IMG_size*gb_zoom
                addss       xmm0,xmm3         ; xmm0 = (re+gb_offsetx)*gb_IMG_size*gb_zoom+gb_IMG_size/2
                addss       xmm1,xmm3         ; xmm1 = (im+gb_offsety)*gb_IMG_size*gb_zoom+gb_IMG_size/2
                cvtss2si    edi,xmm0          ; edi = x = int(xmm0.x)
                cvtss2si    esi,xmm1          ; esi = y = int(xmm1.x)
                cmp         edi,0
                jl          @f
                cmp         edi,IMG_SIZE
                jge         @f
                cmp         esi,0
                jl          @f
                cmp         esi,IMG_SIZE
                jge         @f
                imul        esi,esi,IMG_SIZE
                add         esi,edi
                add         dword [image+esi*4],1
@@:
                inc         ecx
                jmp         .LoopSequence
.LoopSequenceEnd:
                ; continue .LoopOneMillion
                add         r12 , 1
                cmp         r12 , 1000000
                jb          .LoopOneMillion

                ; continue .LoopIterations
                add         r13 , 1
                cmp         r13 , ITERATIONS
                jb          .LoopIterations

                ; find max value
                mov         r12 , 0
                xor         eax,eax      ; eax = i = loop counter
.LoopMax:
                push        rcx
                mov         ecx, r12d
                cmp         dword [image+eax*4],ecx
                cmova       ecx , dword [image+eax*4]
                mov         r12d, ecx
                pop         rcx
                inc         eax
                cmp         eax,IMG_SIZE*IMG_SIZE
                jb          .LoopMax
                ; find min value
                mov         r13d,r12d   ; r13d = min_val = max_val
                xor         eax,eax     ; eax = i = loop counter
.LoopMin:
                push        rcx
                mov         ecx, r13d

                cmp         dword [image+eax*4],ecx
                cmovb       ecx,dword [image+eax*4]
                mov         r13d, ecx
                pop         rcx
                inc         eax
                cmp         eax,IMG_SIZE*IMG_SIZE
                jb          .LoopMin

                ; write image pixels

                cvtsi2ss    xmm0, r12       ; load max_value
                cvtsi2ss    xmm1, r13       ; load min_value
                movaps      xmm2,xmm0
                subss       xmm2,xmm1       ; xmm2 = r = max_value - min_value
                xor         ecx,ecx
.LoopWrite:
                mov         eax,[image+ecx*4] ; eax = image_value
                sub         eax, r13d       ; eax = image_value - min_value
                cvtsi2ss    xmm0,eax        ; xmm0 = float(image_value - min_value)
                addss       xmm0,xmm0       ; xmm0 = 2.0f * float(image_value - min_value)
                divss       xmm0,xmm2       ; xmm0 = 2.0f * float(image_value - min_value) / r
                minss       xmm0,[gb_1_0]    ; clamp to 1.0
                maxss       xmm0,[gb_0_0]    ; clamp to 0.0
                mulss       xmm0,[gb_255_0]  ; convert to 0 - 255
                cvtss2si    eax,xmm0
                ; write pixel data
                mov         [image+ecx*4],eax
                inc         ecx
                cmp         ecx,IMG_SIZE*IMG_SIZE
                jb          .LoopWrite

                ; Terminate thread
                mov         [threadstatus],byte 1
                mov         rax , 512
                int         0x60


;-------------------------------------------------------------------------------
;
;-------------------------------------------------------------------------------

; Data area

window_label:  db    'MANDELBROT',0
string_mouse:  db    'CPU(s):X   ZOOM WITH MOUSE',0
threadstatus:  dq    0x2 ; 0/1/2 - running/halting/halted
viewselect:    dq    0x0 ; 0/1 - mandelbrot/buddhabrot
paletteselect: dq    0x0 ; 0/1 - blue/rainbow
cpucount:      dq    0x0 ; cpu count
imageystart:   dq    0x0 ; y axis calc start
zoomlevel:     dq    7   ;
bailouttype:   dq    0   ; static/progressive

menu_struct:                ; Menu Struct

     dq   0                 ; Version
     dq   0x100             ; Start value of ID to return ( ID + Line )
                            ; Returned when menu closes and
                            ; user made no selections.

     db   0,'VIEW',0          ; ID = 0x100 + 1
mb1: db   1,'> Mandelbrot',0  ; ID = 0x100 + 2
mb2: db   1,'  Buddhabrot',0  ; ID = 0x100 + 3
     db   1,'-',0             ; ID = 0x100 + 4
     db   1,'Quit',0          ; ID = 0x100 + 5
                              ;
set: db   0,'SETUP',0         ;
                              ;
     db   1,'  PALETTE ',0    ;
pa1: db   1,'> Blue',0        ;
pa2: db   1,'  Rainbow',0     ;
                              ;
     db   1,'-',0             ;
                              ;
     db   1,'  BAILOUT ',0    ;
ba1: db   1,'> Static',0      ;
ba2: db   1,'  Progressive',0 ;
                              ;
     db   255                 ; End of Menu Struct


;-------------------------------------------------------------------------------
;               Mandelbrot data
;-------------------------------------------------------------------------------

align 4
g_min_norm_pos  dd          0x00800000
g_log_p0        dd          -0.789580278884799154124
g_log_p1        dd          16.3866645699558079767
g_log_p2        dd          -64.1409952958715622951
g_log_q0        dd          -35.6722798256324312549
g_log_q1        dd          312.093766372244180303
g_log_q2        dd          -769.691943550460008604
g_log_c0        dd          0.693147180559945
g_z_max         dd          100.0

g_bailout       dd          100

align 16
SIZE=520
g_size          dd          4 dup 520.0
g_center        dd          -0.5,0.0 ,0.0,0.0
g_zoom          dd          4 dup 0.4
g_brightness    dd          4 dup 1.2

g_0_0           dd          4 dup 0.0
g_0_5           dd          4 dup 0.5
g_1_0           dd          4 dup 1.0
g_255_0         dd          4 dup 255.0 ; 255.0
g_inv_mant_mask dd          4 dup (not 0x7f800000)
g_inv_y_sign    dd          0x0,0x80000000,0x0,0x0
;-------------------------------------------------------------------------------


;-------------------------------------------------------------------------------
;                Buddhabrot data
;-------------------------------------------------------------------------------
align 4
gb_xorwow_x      dd          123456789
gb_xorwow_y      dd          362436069
gb_xorwow_z      dd          521288629
gb_xorwow_w      dd          88675123
gb_xorwow_v      dd          5783321
gb_xorwow_d      dd          6615241
gb_rand_scale    dd          2.3283064e-10 ; 1.0 / 2^32

IMG_SIZE=520
SEQ_SIZE=50
ITERATIONS=100
gb_IMG_size      dd          520.0
gb_offsetx       dd          0.5
gb_offsety       dd          0.0
gb_zoom          dd          0.4

gb_max_dist      dd          10.0
gb_range         dd          4.2
gb_0_5           dd          0.5
gb_0_0           dd          0.0
gb_1_0           dd          1.0
gb_255_0         dd          255.0

;-------------------------------------------------------------------------------

threadys:
   rb          8*10
threadye:
   rb          8*10
threadimage:
   rb          8*10
threadstack:
   rb          1024*10
threadrunning:
   rb          10*8
window_dimensions:
   rb          1024
palette:
   rb          260*4
sequence:
   rb          SEQ_SIZE*8
image:
   rb          IMG_SIZE*IMG_SIZE*4

;-------------------------------------------------------------------------------

image_end:

