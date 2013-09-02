;------------------------------------------------------------------------------------
;
;   Equalizer
;
;------------------------------------------------------------------------------------

;------------------------------------------------------------------------------------
; IN:  r15 - wave position
; OUT: [r15+]

apply_equalizer:

                      push   rax rbx rcx rdx rsi rdi r8 r9 r10 r11 r12 r13 r14 r15 rbp

                      mov    rax , 150                        ;work memory init
                      mov    rbx , 1
                      mov    rcx , memm
                      mov    rdx , 0x100000*6
                      int    0x60

                      push   r15                              ;copy source
                      mov    rsi , r15
                      mov    rdi , inwav
                      mov    rcx , asize+65536
                      cld
                      rep    movsb

                      mov    rcx , fftcvif                    ;create empty FFTCV interface for coeffs calculation
                      mov    rdx , FFTCV_LENGTH_32BANDS
                      ;fftcv_init
                      mov    rax , 150
                      mov    rbx , 31
                      int    0x60

                      test   rax , rax
                      mov    [errcode], rax
                      jnz    .end

                      mov    rcx , [fftcvif]                  ;calculate 32-band equalizer coefficients
                      mov    rdx , FFTCV_EQ_32BANDS
                      mov    r8  , 0
                      mov    r9  , gaintable
                      mov    r10 , phasetable
                      ;fftcv_calc_coeffs
                      mov    rax , 150
                      mov    rbx , 33
                      int    0x60

                      test   rax , rax
                      mov    [errcode], rax
                      jnz    .end

                      mov    rdi , fftcvifaces                ;init fftcvifaces list (see documentation on this)
                      mov    rax , [fftcvif]
                      mov    ecx , 48
                      rep    stosq

                      mov    rcx , fmchiface                  ;init multi-ch interface
                      mov    rdx , FFTCV_LENGTH_32BANDS
                      mov    r8  , (SC_FORMAT_16B_ST shl 32)  +  SC_FORMAT_16B_ST  ;format can be obtained by "wfc" too
                      ;fftcv_init_mch
                      mov    rax , 150
                      mov    rbx , 41
                      int    0x60

                      test   rax , rax
                      mov    [errcode], rax
                      jnz    .end

                      mov    rcx , [fmchiface]                ;set coeffs multi-ch
                      mov    rdx , fftcvifaces
                      ;fftcv_set_coeffs_mch
                      mov    rax , 150
                      mov    rbx , 44
                      int    0x60

                      test   rax , rax
                      mov    [errcode], rax
                      jnz    .end

                      mov    rdx , inwav                      ;init in/out buffer and size
                      mov    r8  , buffer
                      mov    r9  , (asize+65536)/2/2
                      mov    rcx , [fmchiface]                ;process
                      ;fftcv_process_mch
                      mov    rax , 150
                      mov    rbx , 43
                      int    0x60

                      mov    ecx , SC_FORMAT_16B_ST           ;update output position
                      and    ecx , 15                         ;bits 3-0 is the sample type or "size"
                      imul   rax , rcx
                      mov    ecx , SC_FORMAT_16B_ST           ;bits 15-8 is the number of channels
                      shr    ecx , 8
                      and    ecx , 255                        ;(see "scextern.inc")
                      imul   rax , rcx
                      add    r8  , rax

                      mov    rcx , [fmchiface]                ;get trailing delay
                      mov    r9  , FFTCV_TRAILING_DELAY
                      ;fftcv_process_mch
                      mov    rax , 150
                      mov    rbx , 43
                      int    0x60

                      mov    ecx , SC_FORMAT_16B_ST           ;update output position
                      and    ecx , 15                         ;bits 3-0 is the sample type or "size"
                      imul   rax , rcx
                      mov    ecx , SC_FORMAT_16B_ST           ;bits 15-8 is the number of channels
                      shr    ecx , 8
                      and    ecx , 255                        ;(see "scextern.inc")
                      imul   rax , rcx
                      add    r8  , rax

                      mov    rcx , [fmchiface]                ;deinit iface
                      ;fftcv_deinit_mch
                      mov    rax , 150
                      mov    rbx , 42
                      int    0x60

                      mov    rcx , [fftcvif]                  ;deinit iface
                      ;fftcv_deinit
                      mov    rax , 150
                      mov    rbx , 32
                      int    0x60

                    .end:

                      pop    r15                              ;copy result
                      mov    rsi , buffer+16384
                      mov    rdi , r15
                      mov    rcx , asize
                      cld
                      rep    movsb

                      pop    rbp r15 r14 r13 r12 r11 r10 r9 r8 rdi rsi rdx rcx rbx rax

                      ret

align 4

gaintable:      times 32 dd 1.0

phasetable:     times 32 dd 00.0

;------------------------------------------------------------------------------------

