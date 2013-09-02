;------------------------------------------------------------------------------------
;
;   Spectrum analyzer
;
;------------------------------------------------------------------------------------


;------------------------------------------------------------------------------------
;TINY AND SIMPLE SPECTRUM ANALYZER EXAMPLE
;
;we convert n samples with "sc" from a multi-channel format
;and add the channels together step-by-step, finally the summed result
;is FFT transformed (analyzed) and returned as an image (xlen x ylen RGBA)
;
;IN:   rcx - *input wave       (headerless)                          uses: xmm0-xmm15
;      rdx - *output           (spectrum image)
;      r8  -  n  block size    (eg. 1024 must be power of two)
;      r9  -  input sc format  (eg. SC_FORMAT_16B_ST)
;      r10 -  (xlen << 32) + ylen
;
;OUT:  output


spa_process:

                      push   r15, r14, r13, r12, r11, r10, r9, r8, rdi, rsi, rdx, rcx, rax

                      ; process

                      xchg   rcx , rsi                     ;rsi - *input wav
                      xchg   rdx , rdi                     ;rdi - *output
                      xchg   r8  , r12                     ;r12 -  n  block size
                      xchg   r9  , r13                     ;r13 -  input sc format
                      xchg   r10 , r15                     ;r15 -  image dim

                      mov    rcx , spa_sciface             ;init sc
                      mov    rdx , r13                     ;we convert n samples to mono at a time
                      shr    rdx , 8
                      and    rdx , 255
                      imul   rdx , r12
                      mov    r8  , r12
                      ;sc_init
                      mov    rax , 150
                      mov    rbx , 21
                      int    0x60

                      test   rax , rax
                      jnz    .end

                      mov    rcx , [spa_sciface]           ;convert n samples to internal (float32)
                      mov    rdx , rsi
                      mov    r8  , 0
                      mov    r9  , r12
                      mov    r10 , r13
                      ;sc_to_internal
                      mov    rax , 150
                      mov    rbx , 23
                      int    0x60

                      push   rdi                           ;clear fftbuff1
                      mov    rdi , spa_fftbuff1
                      xor    eax , eax
                      mov    rcx , r12
                      rep stosd
                      pop    rdi

                      xor    r14 , r14                     ;r14 -
             .lp12:
                      mov    rcx , [spa_sciface]           ;reassign one channel

                      mov    rdx , 0
                      mov    r8  , 0
                      mov    r9  , r12
                      mov    r10 , r13
                      shl    r10 , 32
                      or     r10 , SC_FORMAT_M
                      push   r14
                      mov    r11 , rsp
                      ;sc_reassign
                      mov    rax , 150
                      mov    rbx , 24
                      int    0x60

                      add    rsp , 8

                      mov    rcx , [spa_sciface]      ;change precision to -1.0 .. 1.0
                      mov    rdx , 0
                      mov    r8  , r12
                      mov    r9  , r13
                      and    r9  , 0xff00 xor -1
                      or     r9  , 0x0100
                      shl    r9  , 32
                      or     r9  , SC_FORMAT_FLOAT32
                      ;sc_ch_precision
                      mov    rax , 150
                      mov    rbx , 26
                      int    0x60

                      mov    rcx , [spa_sciface]           ;get internal "output" buffer
                      push   0
                      mov    rdx , 0
                      mov    r8  , rsp
                      ;sc_get_buff
                      mov    rax , 150
                      mov    rbx , 27
                      int    0x60
                      pop    rax                           ;rax -  "output buffer"

                      mov    rdx , spa_fftbuff1            ;rdx -  fftbuff1

                      mov    rcx , r12
                      shr    rcx , 2
             .lp20:   movaps xmm0 , [rax]
                      addps  xmm0 , [rdx]
                      movaps [rdx], xmm0
                      add    rax , 16
                      add    rdx , 16
                      loop   .lp20

                      mov    rax , r13
                      shr    rax , 8
                      and    rax , 255
                      inc    r14
                      cmp    r14 , rax
                      jnz    .lp12

                      mov    rax , spa_fftbuff1            ;-> double and window
                      mov    rdx , spa_fftbuff2
                      xor    ecx , ecx
                      fninit
             .lp30:   push   rcx
                      fild   D [rsp]
                      push   r12
                      fidiv  D [rsp]
                      add    rsp , 16
                      fldpi
                      fadd   st0 , st0
                      fmulp  st1 , st0
                      fcos
                      fld1
                      fsubrp st1 , st0
                      fld1
                      fadd   st0 , st0
                      fdivp  st1 , st0
                      fmul   D [rax]
                      fstp   Q [rdx]
                      fldz
                      fstp   Q [rdx + 8]
                      add    rax , 4
                      add    rdx , 16
                      inc    rcx
                      cmp    rcx , r12
                      jnz    .lp30

                      bsr    rcx , r12                     ;forward FFT block
                      mov    rdx , spa_fftbuff2
                      mov    r8  , [spa_ffttab]
                      xor    r9  , r9

                      ;fft4
                      mov    rax , 150
                      mov    rbx , 13
                      int    0x60

                      xor    eax , eax                     ;-> single
                      inc    eax
                      cvtsi2sd xmm2 , eax
                      cvtsi2sd xmm3 , r12
                      divsd  xmm2 , xmm3
                      mov    rax , spa_fftbuff2
                      mov    rdx , spa_fftbuff1
                      mov    rcx , r12
                      shr    rcx , 1
             .lp34:   movapd xmm0 , [rax]
                      mulpd  xmm0 , xmm0
                      movhlps xmm1 , xmm0
                      addsd  xmm1 , xmm0
                      sqrtsd xmm1 , xmm1
                      mulsd  xmm1 , xmm2
                      cvtsd2ss xmm1 , xmm1
                      movss  [rdx], xmm1
                      add    rax , 16
                      add    rdx , 4
                      loop   .lp34

                      mov    rax , [spa_type]
                      call   qword [spa_type_functions+rax*8]

                      mov    rcx , r15                     ;create image
                      shr    rcx , 32
                      mov    rax , r12
                      shr    rax , 1
                      push   rax
                      push   rcx
                      fld1
                      fidiv  D [rsp]
                      fldz             ;f fadd
             .lp44:   fld    st0       ;f f fadd
                      fldl2t
                      fmulp  st1 , st0 ;x f fadd
                      fld1             ;1 x f fadd
                      fld    st1       ;x 1 x f fadd
                      fprem            ;rem(x) 1 x f fadd
                      f2xm1            ;2^rem(x)-1 1 x f fadd
                      faddp  st1 , st0 ;2^rem(x) x f fadd
                      fscale           ;2^x x f fadd
                      fxch
                      fcomp  st0       ;2^x f fadd
                      fld1
                      fsubp  st1 , st0 ;2^f-1 f fadd
                      push   9
                      fidiv  D [rsp]
                      fimul  D [rsp + 16]
                      fistp  Q [rsp]
                      fadd   st0 , st1 ;f+fadd fadd
                      pop    rax
                      fld    D [rbp + rax*4]
                      push   r15
                      fimul  D [rsp]
                      fistp  Q [rsp]
                      pop    rax

                      mov    rdx , r15
                      shr    rdx , 32
                      lea    r8d , [r15d-1]
                      imul   rdx , r8
                      lea    rdi , [rdi + rdx*4]
                      mov    rdx , r15
                      shr    rdx , 32
                      shl    edx , 2

                      mov    r9  , rcx
                      mov    ecx , r15d
             .lp46:   dec    eax
                      test   eax , eax
                      sets   r8b
                      and    r8  , 1
                      dec    r8
                      mov    [rdi], r8d
                      sub    rdi , rdx
                      loop   .lp46
                      add    rdi , rdx
                      mov    rcx , r9

                      add    rdi , 4
                      loop   .lp44
                      add    rsp , 16
                      fcompp

                      mov    rcx , [spa_sciface]           ;deinit sc
                      ;sc_deinit
                      mov    rax , 150
                      mov    rbx , 22
                      int    0x60
              .end:
                      xor    eax , eax
                      pop    rax, rcx, rdx, rsi, rdi, r8, r9, r10, r11, r12, r13, r14, r15
                      ret

spa_normal:

                      mov    rax , spa_fftbuff1            ;convert to dB scale
                      mov    rdx , spa_fftbuff0
                      mov    rcx , r12
                      shr    rcx , 1
                      fninit
                      mov    r8  , 2542376700000000.0
                      push   r8
                      push   75
             .lp40:   fldl2t
                      fchs
                      fld    D [rax]
                      fldz
                      fcomip st1
                      jnz    .sk40
                      fcomp  st0
                      fld    Q [rsp + 8]
                      jmp    .sk42
             .sk40:   fld1
                      fdivrp st1 , st0
             .sk42:   fyl2x
                      fidiv  D [rsp]
                      fld1
                      faddp  st1 , st0
                      fldz
                      fcomi  st0 , st1
                      fcmovb st0 , st1
                      fld1
                      fcomi  st0 , st2
                      fcmovnb st0 , st2
                      fadd   D [rdx]
                      fld1
                      fadd   st0 , st0
                      fdivp  st1 , st0
                      fstp   D [rdx]
                      fcompp
                      add    rax , 4
                      add    rdx , 4
                      loop   .lp40
                      add    rsp , 16

                      mov    rbp , spa_fftbuff0

                      ret

spa_fast:

                      mov    rax , spa_fftbuff1            ;convert to dB scale
                      mov    rcx , r12
                      shr    rcx , 1
                      fninit
                      push   75
             .lp40:   fldl2t
                      fchs
                      fld    D [rax]
                      fld1
                      fdivrp st1 , st0
                      fyl2x
                      fidiv  D [rsp]
                      fld1
                      faddp  st1 , st0
                      fldz
                      fcomi  st0 , st1
                      fcmovb st0 , st1
                      fld1
                      fcomi  st0 , st2
                      fcmovnb st0 , st2
                      fstp   D [rax]
                      fcompp
                      add    rax , 4
                      loop   .lp40
                      add    rsp , 8

                      mov    rbp , spa_fftbuff1

                      ret



;------------------------------------------------------------------------------------
;IN:   rcx -  n  block size    (eg. 1024)

spa_init:

                      push   rax rbx rcx

                      bsr    rcx , rcx
                      ;fft4_create
                      mov    rax , 150
                      mov    rbx , 11
                      int    0x60

                      mov    [spa_ffttab], rax

                      pop    rcx rbx rax

                      ret
;------------------------------------------------------------------------------------
spa_process_init:

                      push   rax rbx rcx rdx

                      mov    rax , 150        ; Work memory init
                      mov    rbx , 1
                      mov    rcx , memm+0x100000*7
                      mov    rdx , 0x100000*2
                      int    0x60

                      mov    rcx , 4096        ;init spectrum analyzer
                      call   spa_init

                      pop    rdx rcx rbx rax

                      ret
;------------------------------------------------------------------------------------
;IN:   -

spa_deinit:

                      push   rax rbx rcx

                      mov    rcx , [spa_ffttab]
                      ;fft4_destroy
                      mov    rax , 150
                      mov    rbx , 12
                      int    0x60

                      pop    rcx rbx rax

                      ret
;-----------------------------------------------------------------------------------
;IN:   r15 - wave position or zero

display_spectrum:

                      push  rax rbx rcx rdx r8 r9 r10 r15 rsi rdi

                      ;spectrum analyzer

                      mov    rcx , dispblock
                      add    rcx , 8192+4092+2048
                      mov    rdx , spectrumimage
                      mov    r8  , 4096
                      mov    r9  , SC_FORMAT_16B_ST
                      mov    r10 , (199 shl 32) + 56
                      call   spa_process

                      ;frames and image

                      mov    rbx , ( 21 shl 32) + 199
                      mov    rcx , (260 shl 32) + 56

                      push   rbx rcx
                      inc    rbx
                      mov    rax , 38
                      mov    rdx , rbx
                      shr    rbx , 32
                      dec    rbx
                      and    rdx , 0xffff
                      add    rdx , rbx
                      mov    r8  , rcx
                      shr    rcx , 32
                      and    r8  , 0xffff
                      add    r8  , rcx
                      mov    r9  , 0x000000
                      push   rbx
                      mov    rbx , rdx
                      int    0x60
                      pop    rbx
                      push   rdx
                      mov    rdx , rbx
                      int    0x60
                      pop    rdx
                      push   rcx
                      mov    rcx , r8
                      int    0x60
                      pop    rcx
                      push   r8
                      mov    r8 , rcx
                      int    0x60
                      pop    r8
                      pop    rcx rbx

                      mov    rax , 7
                      mov    rdx , spectrumimage
                      mov    r8  , 0
                      mov    r9  , 0x1000000
                      mov    r10 , 4
                      int    0x60

                      ;next block

                      cmp   r15 , 0
                      je    noblockcopy

                      mov   rsi , dispblock2
                      mov   rdi , dispblock
                      mov   rcx , (8192+8192)
                      cld
                      rep   movsb

                      mov   rsi , r15
                      mov   rdi , dispblock2
                      mov   rcx , (8192+8192)
                      cld
                      rep   movsb

                    noblockcopy:

                      pop   rdi rsi r15 r10 r9 r8 rdx rcx rbx rax

                      ret
;-----------------------------------------------------------------------------------

spa_type_functions:  dq  spa_normal, spa_fast

