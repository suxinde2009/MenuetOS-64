;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   TV tuner control application
;
;   Based on C code:
;
;   Copyright (c) 2005-7 DiBcom (http://www.dibcom.fr/)
;   Copyright (c) 2005-9 DiBcom, SA et al
;   Copyright (c) 2004-6 Patrick Boettcher (patrick.boettcher@desy.de)
;
;   Assembly translation for Menuet:
;
;   Copyright (c) 2009-2010 Ville Turjanmaa (vmt@menuetos.net)
;
;   License: GNU General Public License, version 2.0
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use64

    org   0x0

    db    'MENUET64'              ; Header identifier
    dq    0x01                    ; Version
    dq    START                   ; Start of code
    dq    image_end               ; Size of image
    dq    0x100000*20             ; Memory for app
    dq    0xffff0                 ; Rsp
    dq    0x00                    ; Prm
    dq    0x00                    ; Icon


include "textbox.inc"


; possible bugs:
;
; -- spur protection
; -- update_lna
; -- power off with gpio / clockset
; -- agc.wbd_sel - state / agc ?
; -- state.timf / bwc.timf references


GPIO0     equ  0
GPIO1     equ  2
GPIO2     equ  3
GPIO3     equ  4
GPIO4     equ  5
GPIO5     equ  6
GPIO6     equ  8
GPIO7     equ 10
GPIO8     equ 11
GPIO9     equ 14
GPIO10    equ 15

GPIO_IN   equ  0
GPIO_OUT  equ  1

TRANSMISSION_MODE_2K   equ  1
TRANSMISSION_MODE_8K   equ  2
TRANSMISSION_MODE_AUTO equ  3
TRANSMISSION_MODE_4K   equ  4

GUARD_INTERVAL_1_32    equ  1
GUARD_INTERVAL_1_16    equ  2
GUARD_INTERVAL_1_8     equ  3
GUARD_INTERVAL_1_4     equ  4
GUARD_INTERVAL_AUTO    equ  5

QPSK      equ  1
QAM_16    equ  2
QAM_32    equ  3
QAM_64    equ  4
QAM_AUTO  equ  7

FEC_NONE  equ  0
FEC_1_2   equ  1
FEC_2_3   equ  2
FEC_3_4   equ  3
FEC_5_6   equ  4
FEC_7_8   equ  5
FEC_AUTO  equ  9

DIB7000P_GPIO_DEFAULT_DIRECTIONS  equ  0xffff
DIB7000P_GPIO_DEFAULT_VALUES      equ  0x0000
DIB7000P_GPIO_DEFAULT_PWM_POS     equ  0xffff

BAND_LBAND          equ   0x01
BAND_UHF            equ   0x02
BAND_VHF            equ   0x04
BAND_SBAND          equ   0x08
BAND_FM             equ   0x10

DIBX000_SLOW_ADC_ON  equ  0
DIBX000_SLOW_ADC_OFF equ  1
DIBX000_ADC_ON       equ  2
DIBX000_VBG_ENABLE   equ  4

OUTMODE_HIGH_Z       equ  0
OUTMODE_DIVERSITY    equ  4
OUTMODE_MPEG2_FIFO   equ  5

DIB7000P_POWER_ALL             equ  0
DIB7000P_POWER_INTERFACE_ONLY  equ  2
DEFAULT_DIB0070_I2C_ADDRESS    equ  0x60

DIB0070_P1D          equ  0
DIB0070_P1F          equ  1
DIB0070_P1G          equ  3
DIB0070S_P1A         equ  2

INVERSION_OFF        equ  0
INVERSION_AUTO       equ  2

HIERARCHY_NONE       equ  0
HIERARCHY_1          equ  1

generic_bulk_control_ep   equ  1
stream.probs.endpoint     equ  2

numr           equ 1000     ; packets
endpointsize   equ 512      ; ep size
datainsize     equ (8*512)  ; transfer size

ych                equ  (+10)
ycs                equ  (-10)

firmware_position  equ  0x020000
mplayer_position   equ  0x050000
datacache          equ  0x100000
sendcache          equ  0x100000*10

windowbgr          equ  0xf2f2f2
i2c_delay          equ  5


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


START:

    mov   rax , 141
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    ; Reserve device

    mov   rax , 130
    mov   rbx , 2
    mov   rcx , 1
    int   0x60
    cmp   rax , 0
    je    device_available
    mov   [status_text_pointer],dword string_status_not_available
    call  draw_window
    mov   rax , 5
    mov   rbx , 250
    int   0x60
    mov   rax , 512
    int   0x60
  device_available:

    ; Clear data area

    mov   rdi , datau_start
    mov   rcx , (datau_end-datau_start)/8+1
    mov   rax , 0
    cld
    rep   stosq

    ; Player not loaded

    mov   [mplayer_position+3*8],dword 0

    ; Get device status, no draw

    call  check_device_status

    ; Draw window

    call  draw_window

still:

    mov   rax , 123       ; Wait here for event
    mov   rbx , 1
    int   0x60

    test  rax , 0x1      ; Window redraw
    jnz   window_event
    test  rax , 0x2      ; Keyboard press
    jnz   key_event
    test  rax , 0x4      ; Button press
    jnz   button_event

    call  check_device_status

    cmp   [readsend],byte 1
    jne   noreadring

    call  dib0700_read_ep_ring

  noreadring:

    jmp   still




window_event:

    call  draw_window
    jmp   still


key_event:

    mov   rax , 0x2
    int   0x60

    cmp   rbx , 0
    jne   still

    cmp   cl , 'h'
    jne   nokeyh
    call  show_help
    jmp   still
  nokeyh:

    jmp   still


button_event:

    mov   rax , 0x11    ; Get data
    int   0x60

    ; rax = status
    ; rbx = button id

    cmp   rbx , 149
    jne   nob149
    cmp   [row0],dword 0
    je    nob149
    dec   dword [row0]
  setbandwidth:
    mov   r8  , 6000
    mov   r9  , 7000
    mov   r10 , 8000    ; mtv3, yle
    mov   r12 , '6'
    mov   r13 , '7'
    mov   r14 , '8'
    cmp   [row0],dword 2
    cmove rax , r10
    cmove rbx , r14
    cmp   [row0],dword 1
    cmove rax , r9
    cmove rbx , r13
    cmp   [row0],dword 0
    cmove rax , r8
    cmove rbx , r12
    mov   [current_bandwidth],rax
    mov   [string_text_59+20],bl
    call  draw_status
    jmp   still
  nob149:
    cmp   rbx , 150
    jne   nob150
    cmp   [row0],dword 2
    je    nob150
    inc   dword [row0]
    jmp   setbandwidth
  nob150:

    cmp   rbx , 151
    jne   nob151
    cmp   [row1],dword 0
    je    nob151
    dec   dword [row1]
  settrmode:
    mov   r8  , TRANSMISSION_MODE_2K
    mov   r9  , TRANSMISSION_MODE_8K
    mov   r10 , '2K'
    mov   r11 , '8K'
    cmp   [row1],dword 0
    cmove rax , r8
    cmove rbx , r10
    cmp   [row1],dword 1
    cmove rax , r9
    cmove rbx , r11
    mov   [ofdm.transmission_mode],rax
    mov   [string_text_6+20-1],bx
    call  draw_status
    jmp   still
  nob151:
    cmp   rbx , 152
    jne   nob152
    cmp   [row1],dword 1
    je    nob152
    inc   dword [row1]
    jmp   settrmode
  nob152:

    cmp   rbx , 153
    jne   nob153
    cmp   [row2],dword 0
    je    nob153
    dec   dword [row2]
  setguardinterval:
    mov   r8  , GUARD_INTERVAL_1_32
    mov   r9  , GUARD_INTERVAL_1_16
    mov   r10 , GUARD_INTERVAL_1_8
    mov   r11 , GUARD_INTERVAL_1_4
    mov   r12 , '1/32'
    mov   r13 , '1/16'
    mov   r14 , ' 1/8'
    mov   r15 , ' 1/4'
    cmp   [row2],dword 3
    cmove rax , r8
    cmove rbx , r12
    cmp   [row2],dword 2
    cmove rax , r9
    cmove rbx , r13
    cmp   [row2],dword 1
    cmove rax , r10
    cmove rbx , r14
    cmp   [row2],dword 0
    cmove rax , r11
    cmove rbx , r15
    mov   [ofdm.guard_interval],rax
    mov   [string_text_7+20-3],ebx
    call  draw_status
    jmp   still
  nob153:
    cmp   rbx , 154
    jne   nob154
    cmp   [row2],dword 3
    je    nob154
    inc   dword [row2]
    jmp   setguardinterval
  nob154:

    cmp   rbx , 155
    jne   nob155
    cmp   [row3],dword 0
    je    nob155
    dec   dword [row3]
  setconstellation:
    mov   r8  , QPSK
    mov   r9  , QAM_16
    mov   r10 , QAM_64    ; mtv3, yle
    mov   r12 , ':   QPSK'
    mov   r13 , ': QAM 16'
    mov   r14 , ': QAM 64'
    cmp   [row3],dword 2
    cmove rax , r10
    cmove rbx , r14
    cmp   [row3],dword 1
    cmove rax , r9
    cmove rbx , r13
    cmp   [row3],dword 0
    cmove rax , r8
    cmove rbx , r12
    mov   [ofdm.constellation],rax
    mov   [string_text_8+20-7],rbx
    call  draw_status
    jmp   still
  nob155:
    cmp   rbx , 156
    jne   nob156
    cmp   [row3],dword 2
    je    nob156
    inc   dword [row3]
    jmp   setconstellation
  nob156:


    cmp   rbx , 157
    jne   nob157
    cmp   [row4],dword 0
    je    nob157
    dec   dword [row4]
  setcoderate:
    mov   r8  , FEC_1_2
    mov   r9  , FEC_2_3   ; mtv3, yle
    mov   r10 , FEC_3_4
    mov   r11 , FEC_5_6
    mov   r12 , FEC_7_8
    cmp   [row4],dword 0
    cmove rax , r8
    cmp   [row4],dword 1
    cmove rax , r9
    cmp   [row4],dword 2
    cmove rax , r10
    cmp   [row4],dword 3
    cmove rax , r11
    cmp   [row4],dword 4
    cmove rax , r12

    mov   r8  , ' FEC 1/2'
    mov   r9  , ' FEC 2/3'   ; mtv3, yle
    mov   r10 , ' FEC 3/4'
    mov   r11 , ' FEC 5/6'
    mov   r12 , ' FEC 7/8'
    cmp   [row4],dword 0
    cmove rbx , r8
    cmp   [row4],dword 1
    cmove rbx , r9
    cmp   [row4],dword 2
    cmove rbx , r10
    cmp   [row4],dword 3
    cmove rbx , r11
    cmp   [row4],dword 4
    cmove rbx , r12

    mov   [ofdm.code_rate_HP],rax
    mov   [ofdm.code_rate_LP],rax

    mov   [string_text_9+20-7],rbx
    call  draw_status
    jmp   still
  nob157:
    cmp   rbx , 158
    jne   nob158
    cmp   [row4],dword 4
    je    nob158
    inc   dword [row4]
    jmp   setcoderate
  nob158:

    cmp   rbx , 51
    jne   no_textbox1
    mov   r14 , textbox1
    call  read_textbox
    mov   [firmware_loaded],byte 0
    jmp   still
  no_textbox1:

    cmp   rbx , 52
    jne   no_textbox2
    mov   r14 , textbox2
    call  read_textbox
    mov   [mplayer_position+3*8],dword 0
    jmp   still
  no_textbox2:

    cmp   rbx , 1000
    jb    no_scroll
    cmp   rbx , 1999
    ja    no_scroll
    mov  [vscroll_value], rbx
    sub   rbx , 1000
    add   rbx , 310
    mov  [device_frequency],rbx
    call  draw_scroll_1
    call  draw_status
    jmp   still
  no_scroll:

    cmp   rbx , 0x10000001  ; App terminate
    je    terminate_application

    cmp   rbx , 0x102       ; Help..
    jne   no_menu_help
    call  show_help
    jmp   still
  no_menu_help:

    cmp   rbx , 0x104       ; Menu terminate
    je    terminate_application

    cmp   rbx , 21          ; Off
    jne   no_stop

    mov   rax , 130
    mov   rbx , 1
    int   0x60
    cmp   rax , 0
    je    still

    call  stop_read
    call  sleep_device

    jmp   still
  no_stop:

    cmp   rbx , 20          ; Apply
    jne   no_apply

    mov   rax , 130
    mov   rbx , 1
    int   0x60
    cmp   rax , 0
    je    still

    call  direct_command
    jmp   still
  no_apply:

    jmp   still




terminate_application:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Read stop, unreserve device, terminate application
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rax , 130
    mov   rbx , 1
    int   0x60
    cmp   rax , 0
    je    nodevstop

    call  stop_read
    call  sleep_device

  nodevstop:

    mov   rax , 130
    mov   rbx , 3
    mov   rcx , 1
    int   0x60

    mov   rax , 512
    int   0x60



show_help:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Displays help text
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   [help_text],byte 1
    call  draw_window

  help_wait:
    mov   rax , 10
    int   0x60
    test  rax , 2
    jz    exit_help
    mov   rax , 2
    int   0x60
    cmp   cx , 'Es'
    je    no_help_wait
    cmp   cx , 'En'
    je    no_help_wait
    cmp   cl , ' '
    je    no_help_wait
    jmp   help_wait
  no_help_wait:

    mov   [help_text],byte 0
    call  draw_window

    ret

  exit_help:

    mov   [help_text],byte 0
    call  draw_window
    call  draw_window

    ret





stk7070p_frontend_attach_gpio:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   GPIO settings
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; Pinnacle pctv 72e (0) / hauppauge and others (1)

    mov   rax , 130
    mov   rbx , 5
    int   0x60
    mov   rcx , 1
    cmp   rbx , 0x02362304
    jne   nopctv72ed
    mov   rcx , 0
  nopctv72ed:

    mov   rax , GPIO6
    mov   rbx , GPIO_OUT
    call  dib0700_set_gpio
    mov   rax , 105
    mov   rbx , 11
    int   0x60

    mov   rax , GPIO9
    mov   rbx , GPIO_OUT
    mov   rcx , 1
    call  dib0700_set_gpio

    mov   rax , GPIO4
    mov   rbx , GPIO_OUT
    mov   rcx , 1
    call  dib0700_set_gpio

    mov   rax , GPIO7
    mov   rbx , GPIO_OUT
    mov   rcx , 1
    call  dib0700_set_gpio

    mov   rax , GPIO10
    mov   rbx , GPIO_OUT
    mov   rcx , 0
    call  dib0700_set_gpio

    call  dib0700_ctrl_clock

    mov   rax , 105
    mov   rbx , 11
    int   0x60

    mov   rax , GPIO10
    mov   rbx , GPIO_OUT
    mov   rcx , 1
    call  dib0700_set_gpio

    mov   rax , 105
    mov   rbx , 11
    int   0x60

    mov   rax , GPIO0
    mov   rbx , GPIO_OUT
    mov   rcx , 1
    call  dib0700_set_gpio

    ret




dib0070_tune:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Set device to channel frequency
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rax , [device_frequency]
    imul  rax , 1000

    ; Tuning table search

    mov   rsi , dib0070_tuning_table - 8*8
    cmp   [revision],dword DIB0070S_P1A
    jne   notables
    mov   rsi , dib0070s_tuning_table - 8*8
  notables:

  tuning_table_new:
    add   rsi , 8*8
    cmp   rax , [rsi]
    ja    tuning_table_new
    mov   [current_tune_table_index],rsi

    ; LNA search

    mov   rsi , dib0070_lna - 2*8

;;    cmp   [flip_chip],byte 1 ; if present - zero for now
;;    jne   noflipc
;;    mov   rsi , dib0070_lna_flip_chip - 2*8
;;  noflipc:

  tuning_lna_new:
    add   rsi , 2*8
    cmp   rax , [rsi]
    ja    tuning_lna_new
    mov   [lna_match],rsi

    ; lo4

    mov   rsi , [current_tune_table_index]
    mov   rax , [rsi+2*8] ; vco band
    shl   rax , 11
    mov   rbx , [rsi+3*8] ; hfdiv
    shl   rbx , 7
    or    rax , rbx
    mov   [lo4],rax

    ; 0x17:0x30

    mov   rcx , 0x0017      ; const
    mov   rdx , 0x0030
    mov   [i2c_addr],byte 0xC0
    call  dib0070_write_reg

    ; VCOF_khz

    mov   rax , [device_frequency]
    imul  rax , 1000
    shl   rax , 1
    mov   rsi , [current_tune_table_index]
    mov   rbx , [rsi+4*8]
    imul  rax , rbx
    mov   r15 , rax   ; VCOF_khz

    ; REFDIV=1 for now
    ; band_uhf

    mov   r10 , 1            ; REFDIV
    mov   r11 , [clock_khz]  ; FREF


    mov   rax , [device_frequency]
    imul  rax , 1000
    mov   rbx , r11
    shr   rbx , 1
    xor   rdx , rdx
    div   rbx
    mov   r12 , rax         ; FBDiv

    mov   rax , [device_frequency]
    imul  rax , 1000
    shl   rax , 1

    mov   rbx , r12
    imul  rbx , r11

    sub   rax , rbx
    mov   r13 , rax         ; Rest

    ; LPF = 100

    cmp   r13 , 100
    jae   nobelow1
    mov   r13 , 0
    jmp   belowdone
  nobelow1:
    cmp   r13 , 100*2
    jae   nobelow2
    mov   r13 , 100*2
    jmp   belowdone
  nobelow2:
    mov   rax , r11
    sub   rax , 100
    cmp   r13 , rax
    jbe   noabove1
    mov   r13 , 0
    inc   r12
    jmp   belowdone
  noabove1:
    mov   rax , r11
    sub   rax , 100*2
    cmp   r13 , rax
    jbe   noabove2
    mov   r13 , r11
    sub   r13 , 2*100
    jmp   belowdone
  noabove2:

  belowdone:

    imul  r13 , 6528

    mov   rax , r11
    xor   rdx , rdx
    mov   rbx , 10
    div   rbx

    ; rax = fref/10

    mov   rbx , rax
    xor   rdx , rdx
    mov   rax , r13
    div   rbx

    mov   r13 , rax

    mov   r14 , 1    ; Den
    cmp   r13 , 0
    je    noabovez
    or    [lo4],dword (1 shl 14) + (1 shl 12)
    mov   r14 , 255
  noabovez:


    mov   rcx , 0x0011 ; diff

    mov   rdx , r12


    mov   [i2c_addr],byte 0xC0
    call  dib0070_write_reg

    mov   rcx , 0x0012 ; diff
    mov   rdx , r14
    shl   rdx , 8
    or    rdx , r10


    mov   [i2c_addr],byte 0xC0
    call  dib0070_write_reg


    mov   rcx , 0x0013 ; diff

    mov   rdx , r13


    mov   [i2c_addr],byte 0xC0
    call  dib0070_write_reg

    cmp   [revision],dword DIB0070S_P1A
    jne   nolo5
    ; UHF
    mov   rax , 5
    mov   rbx , 4
    mov   rcx , 3
    mov   rdx , 1
    call  dib0070_set_ctrl_lo5
  nolo5:

    mov   rcx , 0x20
    mov   rdx , 0x0040 + 0x0020 + 0x0010 + 0x0008 + 0x0002 + 0x0001
    add   rdx , 0x4000 + 0x0800 ; check (same for all uhf?)
    call  dib0070_write_reg

    call  captrim


    mov   rcx , 0x000F           ;;;

    ; UHF
    mov   rdx , (1 shl 14) + (3 shl 12) + (6 shl 9) + (1 shl 7)
    mov   rsi , [current_tune_table_index]
    mov   rax , [rsi+6*8]
    or    rdx , rax

    mov   [i2c_addr],byte 0xC0
    call  dib0070_write_reg


    mov   rcx , 0x0006           ; const
    mov   rdx , 0x3FFF
    mov   [i2c_addr],byte 0xC0
    call  dib0070_write_reg

    mov   rcx , 0x0007           ;;;

    mov   rsi , [current_tune_table_index]
    mov   rax , [rsi+1*8]
    shl   rax , 11

    mov   rdx , rax

    or    rdx , (7 shl 8)

    mov   rsi , [lna_match]
    mov   rbx , [rsi+8]
    shl   rbx , 3

    or    rdx , rbx

    or    rdx , (3)

    mov   [i2c_addr],byte 0xC0
    call  dib0070_write_reg

    mov   rcx , 0x0008           ;;;

    mov   rsi , [lna_match]
    mov   rdx , [rsi+8]
    shl   rdx , 10
    or    rdx , (3 shl 7) + 127
    mov   [i2c_addr],byte 0xC0
    call  dib0070_write_reg

    mov   rcx , 0x000D           ; const
    mov   rdx , 0x0D80
    mov   [i2c_addr],byte 0xC0
    call  dib0070_write_reg
    mov   rcx , 0x0018           ; const
    mov   rdx , 0x07FF
    mov   [i2c_addr],byte 0xC0
    call  dib0070_write_reg
    mov   rcx , 0x0017           ; const
    mov   rdx , 0x0033
    mov   [i2c_addr],byte 0xC0
    call  dib0070_write_reg

    mov   [i2c_addr], byte 0x80
    mov   rax , [current_bandwidth] ;
    call  dib7000p_set_bandwidth

    ret



captrim:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Finalize frequency settings
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rcx , 0x000F          ; const
    mov   rdx , 0xed10
    mov   [i2c_addr],byte 0xC0
    call  dib0070_write_reg
    mov   rcx , 0x0017          ; const
    mov   rdx , 0x0034
    mov   [i2c_addr],byte 0xC0
    call  dib0070_write_reg
    mov   rcx , 0x0018          ; const
    mov   rdx , 0x0032
    mov   [i2c_addr],byte 0xC0
    call  dib0070_write_reg

    mov   r10 , [lo4]
    mov   r11 , [lo4]
    add   r11 , 0xff

    mov   r9  , 0x0020 ; stepping
    mov   r8  , 2      ; direction 0=down, 1=up

    mov   r15 , [lo4]
    add   r15 , 0xc0

    mov   [i2c_addr],byte 0xC0

  newtest:

    mov   rdx , r15

    mov   [lastset],rdx

    mov   rcx , 0x14
    mov   [i2c_addr],byte 0xC0
    call  dib0070_write_reg


    mov   rcx , 0x1900
    mov   [i2c_addr],byte 0xC0
    call  dib7000p_read_word

    ;
    ; dir -
    ;

    cmp   rdx , 400
    jae   nodirm

    cmp   r8 , 0
    je    samedir
    mov   r8 , 0
    cmp   r9 , 1
    je    samedir
    shr   r9 , 1
  samedir:

    add   r15 , r9

    cmp   r15 , r11
    jb    nodirm2
    cmp   r9  , 1
    je    donetest

    sub   r15 , r9
    shr   r9  , 1
    add   r15 , r9

  nodirm2:

    mov   r10 , [lastset]

  nodirm:

    ;
    ; dir +
    ;

    cmp   rdx , 400
    jb    nodirp

  dirplus:

    cmp   r8 , 1
    je    samedir2
    mov   r8 , 1
    cmp   r9 , 1
    jbe   samedir2
    shr   r9 , 1
  samedir2:

    sub   r15 , r9

    cmp   r15 , r10
    ja    nodirp2
    cmp   r9  , 1
    je    donetest

    add   r15 , r9
    shr   r9  , 1
    sub   r15 , r9

  nodirp2:

    mov   r11 , [lastset]

  nodirp:

    jmp   newtest

    mov   rax , 512
    int   0x60

  donetest:

    mov   rdx , [lastset]

    mov   rcx , 0x14
    mov   [i2c_addr],byte 0xC0
    call  dib0070_write_reg

    mov   rcx , 0x0018          ; const
    mov   rdx , 0x07ff
    mov   [i2c_addr],byte 0xC0
    call  dib0070_write_reg

    ret




stop_read:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Halt the read -thread
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    cmp   [readsend],byte 0
    je    nostrhalt
    cmp   [reading],byte 3
    je    nohaltwait

    cmp   [reading],byte 1
    jne   nostrhalt

    mov   [status_text_pointer],dword string_status_stopping
    call  draw_status

    mov   [reading],byte 2 ; halt possible thread

    mov   rcx , 0
  waitforhalt:
    mov   rax , 5
    mov   rbx , 10
    int   0x60
    inc   rcx
    cmp   rcx , 100
    ja    nohaltwait
    cmp   [reading],byte 3
    jne   waitforhalt
  nohaltwait:

    ; Needed for lost connection

    mov   [status_text_pointer],dword string_status_stopping

    ; Reserve device from read thread

    mov   rax , 130
    mov   rbx , 2
    mov   rcx , 1
    int   0x60

    mov   [readsend],byte 0 ; check this

  nostrhalt:

    ret



sleep_device:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Get device ready for program terminate
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    cmp   [reading],byte 0
    je    nostopd

    mov   rax , 5
    mov   rbx , 25
    int   0x60

    mov   rax , 0
    call  dib0700_streaming_control
    mov   rax , 0
    call  dib0700_streaming_control

    mov   rax , 5
    mov   rbx , 25
    int   0x60

    mov   rax , 1
    call  dib7070_tuner_sleep

    mov   rax , 5
    mov   rbx , 25
    int   0x60

    mov   [i2c_addr],byte 0x80
    mov   rax , OUTMODE_HIGH_Z
    call  dib7000p_set_output_mode

    mov   rax , DIB7000P_POWER_INTERFACE_ONLY
    call  dib7000p_set_power_mode

    mov   rax , 5
    mov   rbx , 25
    int   0x60

    ;
    ; Are other commands required to enter full sleep mode ??
    ;

    mov   [reading],byte 0   ; check this
    mov   [readsend],byte 0  ; and this

  nostopd:

    ret




direct_command:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Firmware / Attach / Tune
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    call  read_firmware_and_player

    ;
    ; (1/2) Connect
    ;

    call  stop_read

    ; receive - probs.endpoint
    mov   r11 , stream.probs.endpoint + 0x80
    call  usb_clear_halt

    ; send,generic
    mov   r11 , generic_bulk_control_ep
    call  usb_clear_halt
    ; rcv,generic
    mov   r11 , generic_bulk_control_ep + 0x80
    call  usb_clear_halt

    ;

    mov   [status_text_pointer],dword string_status_identify
    call  draw_status

    call  dib0700_identify_state

    ;
    ; Send firmware
    ;

    cmp   [cold],byte 0
    je    xnofirmwaresend

    mov   [status_text_pointer],dword string_status_firmware
    call  draw_status

    call  unpack_firmware
    call  start_firmware

    call  dib0700_identify_state

    cmp   [cold],byte 1
    jne   initsuccess

    ; Second try

    call  unpack_firmware
    call  start_firmware

    call  dib0700_identify_state

    cmp   [cold],byte 1
    jne   initsuccess

    ret

  xnofirmwaresend:
  initsuccess:

    ;

    mov   [status_text_pointer],dword string_status_tuning
    call  draw_status

    call  dib0700_probe
    call  dib0070_tune
    call  dib7000p_set_frontend

    ; No channel lock -> disable the device and return

    cmp   [lock_achieved],byte 1
    je    channel_found

    mov   [status_text_pointer],dword string_status_no_lock
    call  draw_status

    mov   rax , 5
    mov   rbx , 100
    int   0x60

    mov   [reading],byte 1
    call  sleep_device

    ret

  channel_found:

    mov   [i2c_addr],byte 0x80
    mov   rax , OUTMODE_MPEG2_FIFO
    call  dib7000p_set_output_mode

    ; Enable stream for a second

    mov   rax , 1
    call  dib0700_streaming_control
    mov   rax , 5
    mov   rbx , 100
    int   0x60
    mov   rax , 0
    call  dib0700_streaming_control
    mov   rax , 5
    mov   rbx , 100
    int   0x60

    mov   [status_text_pointer],dword string_status_clearing
    call  draw_status

    ; Clear cache

    mov   rdi , datacache
    mov   [datacache],dword '    '
    mov   rdx , 2    ; endpoint
    mov   rcx , 4096 ; datainsize
    mov   r8  , 512  ; endpointsize
    mov   r9  , numr ; number of packets
    call  usb_bulk_msg_in_12
    mov   rax , 5
    mov   rbx , 10
    int   0x60
    mov   rdi , datacache
    mov   rax , ' '
    mov   rcx , numr*4096
    cld
    rep   stosb

    ; Clear send cache

    mov   rax , 0
    mov   [sendcachepos],rax

    ; Start mplayer

    cmp   [mplayer_position+3*8],dword 0
    je    no_mplayer_found

    mov   rax , 257
    mov   rbx , mplayer_position
    mov   rcx , ipc_string
    int   0x60

    push  rax
    mov   [pid],rbx
    mov   rax , 5
    mov   rbx , 10
    int   0x60
    pop   rax
    cmp   rax , 0
    je    mplayer_found

  no_mplayer_found:

    mov   [pid],dword 0xffffff

    mov   [status_text_pointer],dword string_status_no_mplayer
    call  draw_status

    mov   rax , 5
    mov   rbx , 250
    int   0x60

  mplayer_found:

    ; Enable stream

    mov   rax , 1
    call  dib0700_streaming_control
    mov   rax , 5
    mov   rbx , 10
    int   0x60

    ; Start sending data to mplayer

    mov   [reading],byte 0  ; start thread
    mov   [readsend],byte 1

    mov   [status_text_pointer],dword string_status_broadcast
    call  draw_status

    ret



check_device_status:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Device connected / disconnected
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rax , 130
    mov   rbx , 1
    int   0x60

    mov   rcx , string_status_disconnected
    cmp   rax , 0
    je    devdc
    mov   rcx , string_status_connected
  devdc:

    mov   rbx , [status_text_pointer]

    cmp   rcx , string_status_disconnected
    je    mark_disconnect

    cmp   rbx , string_status_broadcast
    je    nostatc

  mark_disconnect:

    cmp   rcx , rbx
    je    nostatc
    mov   [status_text_pointer],rcx
    cmp   rbx , 0 ; No draw at start
    je    nostatdraw
    call  draw_status
  nostatdraw:
  nostatc:

    ret




dib7000p_get_frontend:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Get current settings
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   [i2c_addr],dword 0x80

    mov   rcx , 463
    call  dib7000p_read_word

    mov   [inversion],dword INVERSION_AUTO

    ; bandwidth 8000 khz for now - fixed

    mov   rax , rdx
    shr   rax , 8
    and   rax , 3

    mov   r8 , TRANSMISSION_MODE_2K
    mov   r9 , TRANSMISSION_MODE_8K   ; mtv3, yle
    mov   rbx , r9
    cmp   rax , 0
    cmove rbx , r8
    cmp   rax , 1
    cmove rbx , r9

    mov   [ofdm.transmission_mode],rbx

    mov   rax , rdx
    and   rax , 3

    mov   r8  , GUARD_INTERVAL_1_32
    mov   r9  , GUARD_INTERVAL_1_16
    mov   r10 , GUARD_INTERVAL_1_8    ; mtv3, yle
    mov   r11 , GUARD_INTERVAL_1_4

    mov   rbx , r9

    cmp   rax , 0
    cmove rbx , r8
    cmp   rax , 1
    cmove rbx , r9
    cmp   rax , 2
    cmove rbx , r10
    cmp   rax , 3
    cmove rbx , r11

    mov   [ofdm.guard_interval],rbx

    mov   rax , rdx
    shr   rax , 14
    and   rax , 3

    mov   r8  , QPSK
    mov   r9  , QAM_16
    mov   r10 , QAM_64    ; mtv3, yle

    mov   rbx , r10 ; default

    cmp   rax , 0
    cmove rbx , r8
    cmp   rax , 1
    cmove rbx , r9
    cmp   rax , 2
    cmove rbx , r10

    mov   [ofdm.constellation],rbx

    ; as long as the frontend_param structure is ...

    mov   [ofdm.hierarchy_information],word HIERARCHY_NONE

    mov   rax , rdx
    shr   rax , 5
    and   rax , 7

    mov   r8  , FEC_1_2
    mov   r9  , FEC_2_3   ; mtv3, yle
    mov   r10 , FEC_3_4
    mov   r11 , FEC_5_6
    mov   r12 , FEC_7_8

    mov   rbx , r12

    cmp   rax , 1
    cmove rbx , r8
    cmp   rax , 2
    cmove rbx , r9
    cmp   rax , 3
    cmove rbx , r10
    cmp   rax , 5
    cmove rbx , r11
    cmp   rax , 7
    cmove rbx , r12

    mov   [ofdm.code_rate_HP],rbx

    mov   rax , rdx
    shr   rax , 2
    and   rax , 7

    mov   r8  , FEC_1_2
    mov   r9  , FEC_2_3   ; mtv3, yle
    mov   r10 , FEC_3_4
    mov   r11 , FEC_5_6
    mov   r12 , FEC_7_8

    mov   rbx , r12

    cmp   rax , 1
    cmove rbx , r8
    cmp   rax , 2
    cmove rbx , r9
    cmp   rax , 3
    cmove rbx , r10
    cmp   rax , 5
    cmove rbx , r11
    cmp   rax , 7
    cmove rbx , r12

    mov   [ofdm.code_rate_LP],rbx

    ; native interleaver: (dib7000p_read_word(state,464) >> 5) & 1

    ret




dib7000p_set_frontend:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Set frontend values
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rax , OUTMODE_HIGH_Z
    call  dib7000p_set_output_mode

    ; maybe the parameter has been changed

    mov   rax , [buggy_sfn_workaround]
    mov   [sfn_workaround_active],rax

    ; if (fe->ops.tuner_ops.set_params)
    ;         fe->ops.tuner_ops.set_params(fe, fep)

    call  dib7070_set_param_override

    ; start up the AGC

    mov   [agc_state],dword 0

  new_agc_startup:

    call  dib7000p_agc_startup
    cmp   rax , 10000
    ja    agc_startup_done

    mov   rbx , rax
    mov   rax , 105
    inc   rbx
    int   0x60

    jmp   new_agc_startup

  agc_startup_done:

    ; No autosearch yet..

    call  dib7000p_tune

    mov   rax , [output_mode]
    call  dib7000p_set_output_mode


    ; ..

    ret


dib7000p_tune:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Device parameters
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rax , 0
    call  dib7000p_set_channel

    ; restart demod

    mov   rcx , 770
    mov   rdx , 0x4000
    call  dib7000p_write_word
    mov   rcx , 770
    mov   rdx , 0x0000
    call  dib7000p_write_word

    mov   rax , 105
    mov   rbx , 45+1
    int   0x60

    ; P_ctrl_inh_cor=0, P_ctrl_alpha_cor=4, P_ctrl_inh_isi=0
    ; P_ctrl_alpha_isi=3, P_ctrl_inh_cor4=1, P_ctrl_alpha_cor4=3

    mov   rax , (0 shl 14)+(4 shl 10)+(0 shl 9)+(3 shl 5)+(1 shl 4) + (0x3)

    cmp   [sfn_workaround_active],byte 1
    je    sfny
    jmp   sfnn
  sfny:
    or    rax , (1 shl 9)
    mov   rcx , 166
    mov   rdx , 0x4000
    push  rax
    call  dib7000p_write_word
    pop   rax
    jmp   sfndone
  sfnn:
    mov   rcx , 166
    mov   rdx , 0x0000
    push  rax
    call  dib7000p_write_word
    pop   rax
  sfndone:

    mov   rdx , rax
    mov   rcx , 29
    call  dib7000p_write_word

    cmp   [state.timf],dword 0
    jne   nowait200
    mov   rax , 105
    mov   rbx , 201
    int   0x60
  nowait200:

    ; offset loop parameters

    ; P_timf_alpha, P_corm_alpha=6, P_corm_thres=0x80

    mov   rax , (6 shl 8) + 0x80

    cmp   [ofdm.transmission_mode],dword TRANSMISSION_MODE_2K
    jne   nottmm2k
    or    rax , 7 shl 12
    jmp   tmmdone
  nottmm2k:
    cmp   [ofdm.transmission_mode],dword 255 ; 4k
    jne   nottmm4k
    or    rax , 8 shl 12
    jmp   tmmdone
  nottmm4k:
    or    rax , 9 shl 12 ; 8k and default
  tmmdone:

    mov   rcx , 26
    mov   rdx , rax
    call  dib7000p_write_word

    ; P_ctrl_freeze_pha_shift=0, P_ctrl_pha_off_max

    mov   rax , 0 shl 4

    cmp   [ofdm.transmission_mode],dword TRANSMISSION_MODE_2K
    jne   nottmm2k2
    or    rax , 0x6
    jmp   tmmdone2
  nottmm2k2:
    cmp   [ofdm.transmission_mode],dword 255 ; 4k
    jne   nottmm4k2
    or    rax , 0x7
    jmp   tmmdone2
  nottmm4k2:
    or    rax , 0x8 ; 8k and default
  tmmdone2:

    mov   rcx , 32
    mov   rdx , rax
    call  dib7000p_write_word

    ; P_ctrl_sfreq_inh=0, P_ctrl_sfreq_step

    mov   rax , 0 shl 4

    cmp   [ofdm.transmission_mode],dword TRANSMISSION_MODE_2K
    jne   nottmm2k3
    or    rax , 0x6
    jmp   tmmdone3
  nottmm2k3:
    cmp   [ofdm.transmission_mode],dword 255 ; 4k
    jne   nottmm4k3
    or    rax , 0x7
    jmp   tmmdone3
  nottmm4k3:
    or    rax , 0x8 ; 8k and default
  tmmdone3:

    mov   rcx , 33
    mov   rdx , rax
    call  dib7000p_write_word

    mov   rcx , 509
    call  dib7000p_read_word

    mov   rax , rdx ; tmp

    shr   rdx , 6
    and   rdx , 1

    inc   rdx
    and   rdx , 1

    cmp   rdx , 1
    jne   norestartfec

    mov   rcx , 771
    call  dib7000p_read_word
    mov   rax , rdx

    or    rdx , (1 shl 1)
    mov   rcx , 771
    push  rax
    call  dib7000p_write_word
    pop   rax

    mov   rdx , rax
    mov   rcx , 771
    call  dib7000p_write_word

    mov   rax , 105
    mov   rbx , 10+1
    int   0x60

    mov   rcx , 509
    call  dib7000p_read_word
    mov   rax , rdx ; tmp

  norestartfec:

    ; we achieved a lock - it's time to update the osc freq

    mov   [lock_achieved],byte 0

    shr   rax , 6
    and   rax , 1

    cmp   rax , 1
    jne   noupdatet
    call  dib7000p_update_timf

    mov   [status_text_pointer],dword string_status_lock
    call  draw_status

    mov   [lock_achieved],byte 1

  noupdatet:

    cmp   [spur_protect],byte 1
    jne   nospr
    mov   rax , [device_frequency]
    imul  rax , 1000
    mov   rbx , [current_bandwidth] ; BANDWIDTH_TO_KHZ
    call  dib7000p_spur_protect
  nospr:

    mov   rax , [current_bandwidth] ;
    call  dib7000p_set_bandwidth

    ret






dib7000p_update_timf:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Bandwidth settings
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ;;;   mov   [current_bandwidth],dword 8000

    mov   rcx , 427
    call  dib7000p_read_word

    mov   rax , rdx
    shl   rax , 16

    mov   rcx , 428
    call  dib7000p_read_word

    add   rax , rdx

    mov   r8  , rax ; r8 = timf

    imul  rax , 160
    xor   rdx , rdx
    mov   rbx , [current_bandwidth]
    div   rbx
    xor   rdx , rdx
    mov   rbx , 50
    div   rbx
    mov   [state.timf],rax

    mov   rdx , r8
    shr   rdx , 16
    and   rdx , 0xffff

    mov   rcx , 23
    call  dib7000p_write_word

    mov   rdx , r8
    and   rdx , 0xffff
    mov   rcx , 24
    call  dib7000p_write_word

    ret




dib7000p_spur_protect:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   In: rax - rf_khz - frequency / 1000
;       rbx - bw     - bandwidth - khz
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   [rf_khz],rax
    mov   [in_bandwidth],rbx

    ; xtal

    mov   rax , [bwc.xtal_hz]
    xor   rdx , rdx
    mov   rbx , 1000
    div   rbx
    mov   [xtal],rax

    ; f_rel

    ; DIV_ROUND_CLOSEST (rf_khz, xtal)

    mov   rax , [xtal]
    shr   rax , 1
    add   rax , [rf_khz]
    xor   rdx , rdx
    mov   rbx , [xtal]
    div   rbx
    ;
    imul  rax , [xtal]
    sub   rax , [rf_khz]
    mov   [f_rel],rax

    ; bw_khz

    mov   rax , [in_bandwidth]
    mov   [bw_khz],rax

    ; if f_rel < -bw_khz/2 ..
    ; not included

    mov   rax , [bw_khz]
    xor   rdx , rdx
    mov   rbx , 100
    div   rbx
    mov   [bw_khz],rax

    ; start write

    mov   rcx , 142
    mov   rdx , 0x0610
    call  dib7000p_write_word

    mov   r15 , 0 ; k

  newk:

    ; pha

    mov   rax , [f_rel]
    mov   r14 , r15
    inc   r14
    imul  rax , r14
    imul  rax , 112
    imul  rax , 80
    xor   rdx , rdx
    mov   rbx , [bw_khz]
    div   rbx
    xor   rdx , rdx
    mov   rbx , 1000
    div   rbx
    and   rax , 0x03ff
    mov   [pha],rax

    ; assume positive value

    mov   rax , 0
    mov   [coef_re_sign+r15*8],rax
    mov   [coef_im_sign+r15*8],rax

    ; pha==0

    cmp   [pha],dword 0
    jne   nopha0
    mov   [coef_re+r15*8],dword 256
    mov   [coef_im+r15*8],dword 0
    jmp   pha_done
  nopha0:

    ; pha<256

    cmp   [pha],dword 256
    jae   nopha256
    mov   rbx , 256
    mov   rax , [pha]
    and   rax , 0xff
    sub   rbx , rax
    movzx rax , byte [sine+rbx]
    mov   [coef_re+r15*8],rax
    ;
    mov   rax , [pha]
    and   rax , 0xff
    movzx rax , byte [sine+rax]
    mov   [coef_im+r15*8],rax
    jmp   pha_done
  nopha256:

    ; pha == 256

    cmp   [pha],dword 256
    jne   nopha256e
    mov   [coef_re+r15*8],dword 0
    mov   [coef_im+r15*8],dword 256
    jmp   pha_done
  nopha256e:

    ; pha < 512

    cmp   [pha],dword 512
    jae   nopha512
    mov   rax , [pha]
    and   rax , 0xff
    movzx rax , byte [sine+rax]
    mov   [coef_re+r15*8],rax
    mov   [coef_re_sign+r15*8],dword 1
    ;
    mov   rbx , 256
    mov   rax , [pha]
    and   rax , 0xff
    sub   rbx , rax
    movzx rax , byte [sine+rbx]
    mov   [coef_im+r15*8],rax
    jmp   pha_done
  nopha512:

    ; pha == 512

    cmp   [pha],dword 512
    jne   nopha512e
    mov   [coef_re+r15*8],dword 256
    mov   [coef_re_sign+r15*8],dword 1
    mov   [coef_im+r15*8],dword 0
    jmp   pha_done
  nopha512e:

    ; pha < 768

    cmp   [pha],dword 768
    jae   nopha768
    mov   rbx , 256
    mov   rax , [pha]
    and   rax , 0xff
    sub   rbx , rax
    movzx rax , byte [sine+rbx]
    mov   [coef_re+r15*8],rax
    mov   [coef_re_sign+r15*8],dword 1
    ;
    mov   rax , [pha]
    and   rax , 0xff
    movzx rax , byte [sine+rax]
    mov   [coef_im+r15*8],rax
    mov   [coef_im_sign+r15*8],dword 1
    jmp   pha_done
  nopha768:

    ; pha = 768

    cmp   [pha],dword 768
    jne   nopha768e
    mov   [coef_re+r15*8],dword 0
    mov   [coef_im+r15*8],dword 256
    mov   [coef_im_sign+r15*8],dword 1
    jmp   pha_done
  nopha768e:

    ; other cases

    mov   rax , [pha]
    and   rax , 0xff
    movzx rax , byte [sine+rax]
    mov   [coef_re+r15*8],rax
    ;
    mov   rbx , 256
    mov   rax , [pha]
    and   rax , 0xff
    sub   rbx , rax
    movzx rax , byte [sine+rbx]
    mov   [coef_im+r15*8],rax
    mov   [coef_im_sign+r15*8],dword 1

  pha_done:

    ;
    ; coef_re
    ;

    mov   rax , [coef_re+r15*8]
    mov   r10 , [coef_re_sign+r15*8]
    call  coef_calc
    mov   [coef_re+r15*8],rax
    mov   [coef_re_sign+r15*8],r10

    ;
    ; coef_im
    ;

    mov   rax , [coef_im+r15*8]
    mov   r10 , [coef_im_sign+r15*8]
    call  coef_calc
    mov   [coef_im+r15*8],rax
    mov   [coef_im_sign+r15*8],r10

    ;
    ; write data
    ;

    mov   rcx , 143
    mov   rdx , (0 shl 14)
    mov   rbx , r15
    shl   rbx , 10
    or    rdx , rbx
    mov   rbx , [coef_re+r15*8]
    and   rbx , 0x03ff
    or    rdx , rbx
    call  dib7000p_write_word

    mov   rcx , 144
    mov   rdx , [coef_im+r15*8]
    and   rdx , 0x03ff
    call  dib7000p_write_word

    mov   rcx , 143
    mov   rdx , (1 shl 14)
    mov   rbx , r15
    shl   rbx , 10
    or    rdx , rbx
    mov   rbx , [coef_re+r15*8]
    and   rbx , 0x03ff
    or    rdx , rbx
    call  dib7000p_write_word

    inc   r15
    cmp   r15 , 8
    jb    newk

    mov   rcx , 143
    mov   rdx , 0
    call  dib7000p_write_word

    ret



coef_calc:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;    In: rax = coef
;        r10 = sign
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ;
    ;  * notch
    ;

    imul  rax , [notch+r15*8]

    cmp   r15 , 7   ; last notch value negative -> change sign
    jne   nosignch
    inc   r10
    and   r10 , 1
  nosignch:

    ;
    ;  + 1 << 14
    ;

    cmp   r10 , 1 ; [coef_re_sign+r15*8],byte 1
    je    negadd

    ; sign remains positive

    mov   rbx , 1 shl 14
    add   rax , rbx
    jmp   adddone

  negadd:

    mov   rbx , 1 shl 14
    cmp   rbx , rax
    jae   subfine

    ; sign remains negative

    sub   rax , rbx
    mov   r10 , 1
    jmp   adddone

  subfine:

    ; sign changes to positive

    sub   rbx , rax
    mov   rax , rbx
    mov   r10 , 0

  adddone:

    ;
    ;  if..
    ;

    cmp   r10 , 1
    je    nonegcmp
    mov   rbx , 1 shl 24
    cmp   rax , rbx
    jb    coef_fine
    mov   rax , (1 shl 24) - 1
  coef_fine:
  nonegcmp:

    ;
    ;  / 1 << 15
    ;

    xor   rdx , rdx
    mov   rbx , 1 shl 15
    div   rbx

    ;
    ; negative -> (0x10000-value) - bug ?
    ;

    cmp   r10 , 1
    jne   nosignneg
    mov   rbx , 0x10000
    sub   rbx , rax
    mov   rax , rbx
  nosignneg:

    ret



dib7000p_set_channel:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   In: rax - seq
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   [seq],rax

    mov   rax , [current_bandwidth] ;
    call  dib7000p_set_bandwidth

    ; nfft, guard, qam, alpha

    mov   rax , 0 ; value

    cmp   [ofdm.transmission_mode], dword TRANSMISSION_MODE_2K
    jne   notm2k
    or    rax , 0 shl 7
    jmp   trmdone
  notm2k:
    cmp   [ofdm.transmission_mode], dword 255 ; 4k
    jne   notm4k
    or    rax , 2 shl 7
    jmp   trmdone
  notm4k:
    or    rax , 1 shl 7   ; 8K and default
  trmdone:

    cmp   [ofdm.guard_interval], dword GUARD_INTERVAL_1_32
    jne   noqi32
    or    rax , 0 shl 5
    jmp   qidone
  noqi32:
    cmp   [ofdm.guard_interval], dword GUARD_INTERVAL_1_16
    jne   noqi16
    or    rax , 1 shl 5
    jmp   qidone
  noqi16:
    cmp   [ofdm.guard_interval], dword GUARD_INTERVAL_1_4
    jne   noqi4
    or    rax , 3 shl 5
    jmp   qidone
  noqi4:
    or    rax , 2 shl 5 ; 8 and default
  qidone:

    cmp   [ofdm.constellation], dword QPSK
    jne   nocqpsk
    or    rax , 0 shl 3
    jmp   constellationdone
  nocqpsk:
    cmp   [ofdm.constellation], dword QAM_16
    jne   noq16
    or    rax , 1 shl 3
    jmp   constellationdone
  noq16:
    or    rax , 2 shl 3 ; QAM_64 and default
  constellationdone:

    ; HIERARCHY_1 - constant ?

    or    rax , 1

    mov   rdx , rax
    mov   rcx , 0
    call  dib7000p_write_word

    mov   rcx , 5
    mov   rdx , [seq]
    shl   rdx , 4
    or    rdx , 1
    call  dib7000p_write_word ; do not force tps, search list 0

    ; P_dintl_native, P_dintlv_inv, P_hrch, P_code_rate, P_select_hp

    mov   rax , 0

    ; if 1 != 0 ..

    or    rax , 1 shl 6

    cmp   [ofdm.hierarchy_information],dword 1 ; HIERARCHY_NONE at get_fr..
    jne   nohi1
    or    rax , 1 shl 4
  nohi1:

    ; if 1 == 1 ..

    or    rax , 1

    mov   rbx , [ofdm.code_rate_LP]
    cmp   [ofdm.hierarchy_information],dword 0
    jne   nohi0
    mov   rbx , [ofdm.code_rate_HP]
  nohi0:

    cmp   rbx , FEC_2_3
    jne   nofec23
    or    rax , 2 shl 1
    jmp   fecdone
  nofec23:
    cmp   rbx , FEC_3_4
    jne   nofec34
    or    rax , 3 shl 1
    jmp   fecdone
  nofec34:
    cmp   rbx , FEC_5_6
    jne   nofec56
    or    rax , 5 shl 1
    jmp   fecdone
  nofec56:
    cmp   rbx , FEC_7_8
    jne   nofec78
    or    rax , 7 shl 1
    jmp   fecdone
  nofec78:
    or    rax , 1 shl 1 ; FEC_1_2 and default
  fecdone:

    mov   rcx , 208
    mov   rdx , rax
    call  dib7000p_write_word

    ; offset loop parameters

    mov   rcx , 26
    mov   rdx , 0x6680 ; timf 6xxx
    call  dib7000p_write_word
    mov   rcx , 32
    mov   rdx , 0x0003 ; pha_off_max (xxx3)
    call  dib7000p_write_word
    mov   rcx , 29
    mov   rdx , 0x1273 ; isi
    call  dib7000p_write_word
    mov   rcx , 33
    mov   rdx , 0x0005 ; sfreq(xxx5)
    call  dib7000p_write_word

    ; P_dvsy_sync_wait

    cmp   [ofdm.transmission_mode],dword TRANSMISSION_MODE_8K
    jne   nootm8k
    mov   rax , 256
    jmp   otmmdone
  nootm8k:
    cmp   [ofdm.transmission_mode],dword 255
    jne   nootm4k
    mov   rax , 128
    jmp   otmmdone
  nootm4k:
    mov   rax , 64  ; 2K and default
  otmmdone:

    cmp   [ofdm.guard_interval],dword GUARD_INTERVAL_1_16
    jne   nogui116
    imul  rax , 2
    jmp   guidone
  nogui116:
    cmp   [ofdm.guard_interval],dword GUARD_INTERVAL_1_8
    jne   nogui18
    imul  rax , 4
    jmp   guidone
  nogui18:
    cmp   [ofdm.guard_interval],dword GUARD_INTERVAL_1_4
    jne   nogui14
    imul  rax , 8
    jmp   guidone
  nogui14:
    imul  rax , 1 ; 1_31 and default
  guidone:

    imul  rax , 3
    shr   rax , 1
    add   rax , 32

    mov   [div_sync_wait],rax   ; add 50% SFN margin + compensate for one
                                ; DVSY-fifo TODO

    ; deactivate the possibility of diversity reception if extended
    ; interleaver        - bug ?

    mov   [div_force_off],byte 0 ; tr_mode 8k
    cmp   [ofdm.transmission_mode],byte TRANSMISSION_MODE_8K
    je    yestr8
    mov   [div_force_off],byte 1 ; tr_mode 2k,..
  yestr8:
    mov   rax , [div_state]
    call  dib7000p_set_diversity_in

    ; channel estimation fine configuration

    cmp   [ofdm.constellation],dword QAM_64
    jne   nofc64
    mov   [est0],word 0x0148
    mov   [est1],word 0xfff0
    mov   [est2],word 0x00a4
    mov   [est3],word 0xfff8
    jmp   estdone
  nofc64:
    cmp   [ofdm.constellation],dword QAM_16
    jne   nofc16
    mov   [est0],word 0x023d
    mov   [est1],word 0xffdf
    mov   [est2],word 0x00a4
    mov   [est3],word 0xfff0
    jmp   estdone
  nofc16:

    mov   [est0],word 0x099a  ; default
    mov   [est1],word 0xffae
    mov   [est2],word 0x0333
    mov   [est3],word 0xfff8

  estdone:

    mov   rcx , 187
    mov   rdx , [est0]
    call  dib7000p_write_word
    mov   rcx , 188
    mov   rdx , [est1]
    call  dib7000p_write_word
    mov   rcx , 189
    mov   rdx , [est2]
    call  dib7000p_write_word
    mov   rcx , 190
    mov   rdx , [est3]
    call  dib7000p_write_word

    ret




dib7000p_set_diversity_in:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   In: rax - [div_state]
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    cmp   [div_force_off],dword 1
    jne   noforceoff
    mov   rax , 0 ; force off
  noforceoff:

    mov   [div_state],rax

    cmp   rax , 1
    jne   noseton
    mov   rcx , 204
    mov   rdx , 6
    call  dib7000p_write_word
    mov   rcx , 205
    mov   rdx , 16
    call  dib7000p_write_word
    ; P_dvsy_sync_mode = 0 , P_dvsy_sync_enable = 1, P_dvcb_comb_mode = 2
    mov   rcx , 207
    mov   rdx , [div_sync_wait]
    shl   rdx , 4
    or    rdx , (1 shl 2) + (2)
    call  dib7000p_write_word
    jmp   oodone
  noseton:
    mov   rcx , 204
    mov   rdx , 1
    call  dib7000p_write_word
    mov   rcx , 205
    mov   rdx , 0
    call  dib7000p_write_word
    mov   rcx , 207
    mov   rdx , 0
    call  dib7000p_write_word
  oodone:

    ret



dib7000p_agc_startup:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   AGC startup
;
;   Out: rax - delay or -1 for done
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rax , [agc_state]

    ; case 0

    cmp   rax , 0
    jne   noagcs0

    mov   rax , DIB7000P_POWER_ALL
    call  dib7000p_set_power_mode

    mov   rax , DIBX000_ADC_ON
    call  dib7000p_set_adc_state

    call  dib7000p_pll_clk_cfg

    mov   rax , BAND_UHF
    call  dib7000p_set_agc_config

    inc   dword [agc_state]

    mov   rax , 7

    ret

  noagcs0:

    ; case 1

    cmp   rax , 1
    jne   noagcs1

    ; AGC initialization

    ; no agc_control for 7070p

    mov   rdx , 32768
    mov   rcx , 78
    call  dib7000p_write_word

    ; perform_agc_softsplit = 0 for 7070p

    ; we are using the wbd - so slow agc startup
    ; force 0 split on wbd and restart agc

    mov   rdx , 0    ; 10101100000000b = 0x2b00
    mov   rax , [agc.wbd_sel]   ; state / agc ? bug ?
    shl   rax , 13
    or    rdx , rax
    mov   rax , [agc.wbd_alpha]
    shl   rax , 9
    or    rdx , rax
    mov   rax , 1 shl 8
    or    rdx , rax
    mov   rcx , 106
    call  dib7000p_write_word

    inc   dword [agc_state]

    call  dib7000p_restart_agc

    mov   rax , 5

    ret

  noagcs1:

    ; case 2

    cmp   rax , 2
    jne   noagcs2

    ; fast split search path after 5sec

    mov   rdx , [agc.setup]
    or    rdx , 1 shl 4
    mov   rcx , 75
    call  dib7000p_write_word  ; freeze AGC loop

    mov   rdx , [agc.wbd_sel]
    shl   rdx , 13
    or    rdx , 2 shl 9 + 0 ; fast split search 0.25 kHz
    mov   rcx , 106
    call  dib7000p_write_word

    inc   dword [agc_state]

    mov   rax , 14

    ret

  noagcs2:

    ; case 3

    cmp   rax , 3
    jne   noagcs3

    mov   rcx , 396
    call  dib7000p_read_word

    ; store the split value for next time

    mov   [agc_split],dl

    mov   rcx , 394
    call  dib7000p_read_word
    mov   rcx , 78
    call  dib7000p_write_word

    mov   rcx , 75
    mov   rdx , [agc.setup]
    call  dib7000p_write_word  ; std AGC loop

    mov   rdx , 0
    mov   rax , [agc.wbd_sel]
    shl   rax , 13
    or    rdx , rax
    mov   rax , [agc.wbd_alpha]
    shl   rax , 9
    or    rdx , rax
    mov   rax , [agc_split]
    and   rax , 0xff
    or    rdx , rax
    mov   rcx , 106
    call  dib7000p_write_word

    call  dib7000p_restart_agc

    inc   dword [agc_state]

    mov   rax , 5

    ret

  noagcs3:

    ; case 4

    cmp   rax , 4
    jne   noagcs4

    ; LNA startup
    ; wait AGC accurate lock time

    call  dib7000p_update_lna

    cmp   rax , 1 ; wait only AGC rough lock time
    jne   nor1
    mov   rax , 5
    ret
  nor1:

    cmp   rax , 0 ; nothing was done, go to the next state
    jne   nor0
    inc   dword [agc_state]
    mov   rax , -1
    ret
  nor0:

  noagcs4:

    ; case 5

    cmp   rax , 5
    jne   noagcs5

    ; no agc_control for 7070p

    inc   dword [agc_state]
    mov   rax , -1
    ret

  noagcs5:

    ; case default:

    ;

    mov   rax , -1

    ret





dib7000p_update_lna:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Out: rax = 0 / 1
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; bug - does 7070 need lna update ?

    mov   rax , 0
    ret

    mov   rcx , 394
    call  dib7000p_read_word
    ;cmp   rdx , 0
    ;je    retzero
    call  dib7000p_restart_agc
    inc   dword [agc_state] ; bug - where is this updated ?
    mov   rax , 1
    ret
  retzero:
    mov   rax , 0
    ret





dib7000p_restart_agc:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   AGC restart
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; P_restart_iqc & P_restart agc

    mov   rcx , 770
    mov   rdx , 1 shl 11 + 1 shl 9
    call  dib7000p_write_word

    mov   rcx , 770
    mov   rdx , 0x0000
    call  dib7000p_write_word

    ret



dib7000p_set_agc_config:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   In: rax - BAND
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   [current_band],rax

    ; agc_config_count=1 for 7070p

    ; all other bands supported extept BAND_FM

    cmp   rax , BAND_FM
    jne   band_supported

    mov   rax , 13
    mov   rbx , 100
    mov   rcx , 100
    mov   rdx , 0xff0000
    int   0x60
    mov   rax , 5
    mov   rbx , 300
    int   0x60
    mov   rax , 512
    int   0x60

  band_supported:

    mov   [agc],dword dib7070_agc_config
    mov   [current_agc],dword dib7070_agc_config

    ; AGC

    mov   rcx , 75
    mov   rdx , [agc.setup]
    call  dib7000p_write_word

    mov   rcx , 76
    mov   rdx , [agc.inv_gain]
    call  dib7000p_write_word

    mov   rcx , 77
    mov   rdx , [agc.time_stabiliz]
    call  dib7000p_write_word

    mov   rcx , 100
    mov   rdx , [agc.alpha_level]
    shl   rdx , 12
    or    rdx , [agc.thlock]
    call  dib7000p_write_word

    ; Demod AGC loop configuration

    mov   rcx , 101
    mov   rdx , [agc.alpha_mant]
    shl   rdx , 5
    or    rdx , [agc.alpha_exp]
    call  dib7000p_write_word

    mov   rcx , 102
    mov   rdx , [agc.beta_mant]
    shl   rdx , 6
    or    rdx , [agc.beta_exp]
    call  dib7000p_write_word

    ; AGC continued

    cmp   [state.wbd_ref],dword 0
    jne   wrfl1
    jmp   wrfl2
  wrfl1:
    ; if state.wbd_ref != 0
    mov   rdx , [agc.wbd_inv]
    shl   rdx , 12
    or    rdx , [state.wbd_ref]
    jmp   wbdfine
  wrfl2:
    ; if state.wbd_ref = 0
    mov   rdx , [agc.wbd_inv]
    shl   rdx , 12
    or    rdx , [agc.wbd_ref]
  wbdfine:

    mov   rcx , 105
    call  dib7000p_write_word

    xor   rdx , rdx
    mov   rax , [agc.wbd_sel]
    shl   rax , 13
    or    rdx , rax
    mov   rax , [agc.wbd_alpha]
    shl   rax , 9
    or    rdx , rax
    mov   rax , [agc.perform_agc_softsplit]
    shl   rax , 8
    or    rdx , rax
    mov   rcx , 106
    call  dib7000p_write_word

    mov   rdx , [agc.agc1_max]
    mov   rcx , 107
    call  dib7000p_write_word

    mov   rdx , [agc.agc1_min]
    mov   rcx , 108
    call  dib7000p_write_word

    mov   rdx , [agc.agc2_max]
    mov   rcx , 109
    call  dib7000p_write_word

    mov   rdx , [agc.agc2_min]
    mov   rcx , 110
    call  dib7000p_write_word

    mov   rdx , [agc.agc1_pt1]
    shl   rdx , 8
    or    rdx , [agc.agc1_pt2]
    mov   rcx , 111
    call  dib7000p_write_word

    mov   rdx , [agc.agc1_pt3]
    mov   rcx , 112
    call  dib7000p_write_word

    mov   rdx , [agc.agc1_slope1]
    shl   rdx , 8
    or    rdx , [agc.agc1_slope2]
    mov   rcx , 113
    call  dib7000p_write_word

    mov   rdx , [agc.agc2_pt1]
    shl   rdx , 8
    or    rdx , [agc.agc2_pt2]
    mov   rcx , 114
    call  dib7000p_write_word

    mov   rdx , [agc.agc2_slope1]
    shl   rdx , 8
    or    rdx , [agc.agc2_slope2]
    mov   rcx , 115
    call  dib7000p_write_word

    ret



dib7000p_pll_clk_cfg:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   PLL configuration
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rcx , 903
    call  dib7000p_read_word

    or    rdx , 1

    mov   rcx , 903
    call  dib7000p_write_word  ; pwr-up pll

    ;

    mov   rcx , 900
    call  dib7000p_read_word

    and   rdx , 0x7fff
    or    rdx , 1 shl 6

    mov   rcx , 900
    call  dib7000p_write_word  ; use high freq clock

    ret





dib0700_probe:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Probes and enables the device
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    call  dvb_usb_device_init

    call  dib0700_rc_setup

    ret



dvb_usb_device_init:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Initializes the device
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;    call  dib0700_identify_state
;    cmp   [cold],byte 0
;    je    nofirmwaresend
;    call  read_firmware
;    call  unpack_firmware
;    call  start_firmware
;    call  dib0700_identify_state
;    cmp   [cold],byte 1
;    je    initfailed
;  nofirmwaresend:

    ; info Pinnacle found in warm state

    call  usb_set_infdata

    call  dvb_usb_init

    ; info Pinnacle successfully initialized and connected.

    ret

;  initfailed:
;    ret



dib0700_identify_state:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Identifies the device state
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    call  dib0700_get_version

    cmp   [get_version_data_return],dword 0x0
    je    state_cold

    mov   [cold],byte 0

    ret

  state_cold:

    mov   [cold],byte 1

    ret




dvb_usb_remote_init:

    ; info "schedule remote query interval to xx msecs.

    ret




dvb_usb_adapter_frontend_init:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Frontend init
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; ops.init = dvb_usb_fe_wakeup - bug?
    ; ops.sleep = dvb_usb_fe_sleep - bug?


    call  props.frontend_attach

    call  dvb_register_frontend

    ; bug - sleep/wakeup definitions?

    call  props.tuner_attach

    ret


props.tuner_attach:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Tuner attach
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    call  dib7070p_tuner_attach

    ret




dib7070p_tuner_attach:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Tuner attach
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; ..

    ; tun_i2c = &msg->gated_tuner_i2c_adap
    ;
    ; call dib7000p_get_i2c_master
    ;   call dibx000_get_i2c_adapter
    ;     return i2c ( &mst->gated_tuner_i2c_adap )

    ; mov   [tun_i2c],dword gated_tuner_i2c_adap ; structure - needed later ?

    ; adap->id = 0

    call  dib7070p_dib0070_config_0

    call  dib0070_attach

    ; st->set_param_save = ..

    ; adap->fe->ops.tuner_ ..

    ; set_param_override a parameter set - not a function call
    ; bug ? call  dib7070_set_param_override

    ret


BAND_OF_FREQUENCY:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;    Returns band of frequency
;
;    In:  rax - khz
;
;    Out: rax - BAND_FM, BAND_VHF, BAND_UHF,
;               BAND_LBAND, BAND_SBAND
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    cmp   rax , 115000
    ja    nofm
    mov   rax , BAND_FM
    ret
  nofm:

    cmp   rax , 250000
    ja    novhf
    mov   rax , BAND_VHF
    ret
  novhf:

    cmp   rax , 863000
    ja    nouhf
    mov   rax , BAND_UHF
    ret
  nouhf:

    cmp   rax , 2000000
    ja    nolb
    mov   rax , BAND_LBAND
    ret
  nolb:

    mov   rax , BAND_SBAND

    ret



dib7070_set_param_override:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   WBD offset - use default
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;    mov   rax , [frequency]
;    xor   rdx , rdx
;    mov   rbx , 1000
;    div   rbx
;    call  BAND_OF_FREQUENCY
;    cmp   rax , BAND_VHF
;    jne   nofvhf
;    mov   rdx , 950
;    jmp   bdone
;  nofvhf:
;    ; BAND_UHF,DEFAULT
;    mov   rdx , 550
;  bdone:

    ; UHF
    mov   rdx , 550

    ; dib0070_wbd_offset

    ; wbd_gain - not defined ? bug ? -> use index 6

    mov   rax , [wbd_offset_3_3+0]

 ;   mov   rax , [wbd_offset_3_3+8]

    add   rdx , rax
    call  dib7000p_set_wbd_ref

    ; state->set_param_save

    ret


dib7000p_set_wbd_ref:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   In: rdx - value
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    cmp   rdx , 4095
    jbe   valuefine
    mov   rdx , 4095
  valuefine:

    mov   [state.wbd_ref],rdx

    push  rdx

    mov   rcx , 105
    call  dib7000p_read_word
    and   rdx , 0xf000

    pop   rax

    or    rdx , rax

    mov   rcx , 105
    call  dib7000p_write_word

    ret



dib0070_attach:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Device init
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; parameters

    call  dib0070_reset

    ; parameters

    ret





dib7070p_dib0070_config_0:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Default parameter values
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   [i2c_address],dword DEFAULT_DIB0070_I2C_ADDRESS
    mov   [reset],dword dib7070_tuner_reset
    mov   [sleep],dword dib7070_tuner_sleep
    mov   [clock_khz],dword 12000
    mov   [clock_pad_drive],dword 4
    mov   [charge_pump],dword 2

    ret




dib0070_write_reg:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   In:  rcx - register
;        rdx - value
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    push  rax rbx rcx rdx r8 r9 r10 r11 r12 r13 r14 r15 rsi rdi rbp

    mov   [dwg1+0],cl
    mov   [dwg1+1],dh
    mov   [dwg1+2],dl

    mov   ax , [i2c_address]
    mov   [addr], ax

    mov   rcx , 3        ; write - msg len 3
    mov   rsi , dwg1
    call  i2c_transfer

    pop   rbp rdi rsi r15 r14 r13 r12 r11 r10 r9 r8 rdx rcx rbx rax

    ret



dib0070_read_reg:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   In:  rcx - register
;
;   Out: rdx - value
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    push  rax rbx rcx r8 r9 r10 r11 r12 r13 r14 r15 rdi rsi rbp

    mov   ax , [i2c_address]
    mov   [addr], ax
    mov   [drg1],cl
    mov   rcx , 4
    mov   rsi , drg1
    call  i2c_transfer

    movzx rdx , word [buf_ret]
    xchg  dl  ,dh
    mov   [buf_ret],dx

    movzx rdx , word [buf_ret]

    pop   rbp rsi rdi r15 r14 r13 r12 r11 r10 r9 r8 rcx rbx rax

    ret




dib0070_reset:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Device init
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    call  HARD_RESET

    ; revision

    mov   [revision],dword DIB0070S_P1A
    mov   rcx , 0x22
    call  dib0070_read_reg
    shr   rdx , 9
    and   rdx , 1
    cmp   rdx , 1
    jne   norevread
    mov   rcx , 0x1f
    call  dib0070_read_reg
    shr   rdx , 8
    and   rdx , 0xff
    mov   [revision],rdx
  norevread:

    ; not for revision DIB0070_P1D / or P1A - tuning not tested

    cmp   [revision],dword DIB0070_P1D
    je    notrevisionfine
    cmp   [revision],dword DIB0070S_P1A
    je    notrevisionfine
    jmp   revisionfine
  notrevisionfine:
    mov   [status_text_pointer],dword string_status_no_support
    call  draw_status
    mov   rax , 5
    mov   rbx , 250
    int   0x60
    jmp   still
  revisionfine:

    ; write dib0070_p1f_defaults

    mov   rax , dib0070_p1f_defaults
    mov   r15 , dib0070_p1f_defaults_end
    call  dib0070_write_tab

    ; rdx = r

    cmp   [force_crystal_mode],dword 0
    je    nofc
    mov   rdx , [force_crystal_mode]
    jmp   crdone
  nofc:
    cmp   [clock_khz],dword 24000
    jb    noo24
    mov   rdx , 1
    jmp   crdone
  noo24:
    mov   rdx , 2
  crdone:

    mov   rcx , [osc_buffer_state]
    shl   rcx , 3

    or    rdx , rcx

    mov   rcx , 0x10
    call  dib0070_write_reg

    mov   rdx , [clock_pad_drive]
    and   rdx , 0xf
    shl   rdx , 5
    or    rdx , 1 shl 8

    mov   rcx , 0x1f
    call  dib0070_write_reg

    ; invert_iq - not in use

    cmp   [revision],dword DIB0070S_P1A
    jne   nop1a
    mov   rax , 2
    mov   rbx , 4
    mov   rcx , 3
    mov   rdx , 0
    call  dib0070_set_ctrl_lo5
    jmp   p1adone
  nop1a:
    mov   rax , 5
    mov   rbx , 4
    mov   rcx , [charge_pump]
    mov   rdx , [enable_third_order_filter]
    call  dib0070_set_ctrl_lo5
  p1adone:

    mov   rcx , 0x01
    mov   rdx , 54 shl 9
    or    rdx , 0xc8
    call  dib0070_write_reg

    call  dib0070_wbd_offset_calibration ; newstuff

    ret



dib0070_wbd_offset_calibration:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   WBD init
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   r15 , 6 ; gain
    call  dib0070_read_wbd_offset

    mov   rax , r10
    imul  rax , 8*18
    xor   rdx , rdx
    mov   rbx , 33
    div   rbx
    add   rax , 1
    shr   rax , 1
    mov   [wbd_offset_3_3+0],rax

    mov   r15 , 7 ; gain
    call  dib0070_read_wbd_offset

    mov   rax , r10
    imul  rax , 8*18
    xor   rdx , rdx
    mov   rbx , 33
    div   rbx
    add   rax , 1
    shr   rax , 1
    mov   [wbd_offset_3_3+8],rax

    ret





dib0070_read_wbd_offset:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   In: r15 - gain
;
;       r10 - offset
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rcx , 0x20
    call  dib0070_read_reg
    mov   r14 , rdx ; tuner_en

    mov   rcx , 0x18
    mov   rdx , 0x07ff
    call  dib0070_write_reg

    mov   rcx , 0x20
    mov   rdx , 0x0800+0x4000+0x0040+0x0020+0x0010+0x0008+0x0002+0x0001
    call  dib0070_write_reg

    mov   rcx , 0x0f
    mov   rdx , r15
    shl   rdx , 9
    or    rdx , (1 shl 14) + (2 shl 12) + (1 shl 8) + (1 shl 7) + (0)
    call  dib0070_write_reg

    mov   rax , 105
    mov   rbx , 9+1
    int   0x60

    mov   rcx , 0x19
    call  dib0070_read_reg
    mov   r10 , rdx ; out r10

    mov   rcx , 0x20
    mov   rdx , r14
    call  dib0070_write_reg

    ret




dib0070_set_ctrl_lo5:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   In: rax - vco_bias_trim
;       rbx - hf_div_trim
;       rcx - cp_current
;       rdx - third_order_filt
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    shl   rdx , 14
    shl   rcx , 6
    shl   rbx , 3

    ;; shl rax , 0

    or    rdx , rcx
    or    rdx , rbx
    or    rdx , rax

    ;; or  rdx , 0 shl 13

    or    rdx , 1 shl 12
    or    rdx , 3 shl 9

    mov   rcx , 0x15
    call  dib0070_write_reg

    ret



dib0070_write_tab:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   In: rax = pointer to default table
;       r15 = end of table
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  rdwtl0:

    movzx rbx , word [rax]    ; num of variables

    cmp   rbx , 0
    je    rdwtl2

    movzx rcx , word [rax+2]  ; start address

    add   rax , 4

    cmp   rax , r15 ; dib7000p_write_tab
    jb    rnohlt

    mov   rax , 512
    int   0x60

  rnohlt:

  rdwtl1:

    movzx rdx , word [rax]

    push  rax rbx rcx rdx
    call  dib0070_write_reg
    pop   rdx rcx rbx rax

    add   rcx , 1
    add   rax , 2

    dec   rbx
    jnz   rdwtl1

    jmp   rdwtl0

  rdwtl2:

    ret



HARD_RESET:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Wake up and reset the device
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rax , 0
    call  qword [sleep]

    mov   rax , 1
    call  qword [reset]

    mov   rax , 105
    mov   rbx , 11
    int   0x60

    mov   rax , 0
    call  qword [reset]

    mov   rax , 105
    mov   rbx , 11
    int   0x60

    ret



dib7070_tuner_reset:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;  In: rax = onoff
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rcx , rax
    inc   rcx
    and   rcx , 1
    mov   rax , 8
    mov   rbx , 0
    call  dib7000p_set_gpio

    ret



dib7070_tuner_sleep:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;  In: rax = onoff
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rcx , rax
    mov   rax , 9
    mov   rbx , 0
    call  dib7000p_set_gpio

    ret


dib7000p_set_gpio:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   In:   rax - gpio
;         rbx - dir
;         rcx - val
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   r8 , rax
    mov   r9 , rbx
    mov   r10, rcx

    call  dib7000p_cfg_gpio
    ret




dib7000p_cfg_gpio:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   In:   r8  - num
;         r9  - dir
;         r10 - val
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; dir

    mov   rcx , 1029
    call  dib7000p_read_word
    mov   [gpio_dir],rdx

    mov   rcx , r8
    mov   rax , 1
    shl   rax , cl
    not   rax

    mov   rdx , [gpio_dir]
    and   rdx , rax
    and   rdx , 0xffff
    mov   [gpio_dir],rdx

    and   r9 , 1
    shl   r9 , cl

    mov   rdx , [gpio_dir]
    or    rdx , r9
    mov   [gpio_dir],rdx

    mov   rcx , 1029
    call  dib7000p_write_word

    ; val

    mov   rcx , 1030
    call  dib7000p_read_word
    mov   [gpio_val],rdx

    mov   rcx , r8
    mov   rax , 1
    shl   rax , cl
    not   rax

    mov   rdx , [gpio_val]
    and   rdx , rax
    and   rdx , 0xffff
    mov   [gpio_val],rdx

    and   r10 , 1
    shl   r10 , cl

    mov   rdx , [gpio_val]
    or    rdx , r10
    mov   [gpio_val],rdx

    mov   rcx , 1030
    call  dib7000p_write_word


    ret




dvb_register_frontend:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Frontend register
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   [inversion],dword INVERSION_OFF  ; set at dvb_register_frontend

    call  dvb_register_device

    ret


dvb_register_device:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Device register
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


    ; dprintk "KERN_DEBUG DVB: register adapetr xx minor: xx ( xx )"

    ret




props.frontend_attach:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Frontend attach
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; ..

    call  stk7070p_frontend_attach

    ret


dvb_usb_adapter_dvb_init:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   DVB init
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    call   dvb_register_adapter

    mov    [demux.start_feed],dword dvb_usb_start_feed
    mov    [demux.stop_feed],dword dvb_usb_start_feed

    ; dvb_dmx_init
    ; dvb_dmxdev_init

    call  dvb_net_init

    mov   [adap.state],dword 0x001

    ret


dvb_usb_start_feed:

    ; continue if needed

    ret


dvb_usb_stop_feed:

    ; continue if needed

    ret


dvb_register_adapter:

    ; info "KERN_INFO DVB: registering new adapter ( )"

    ret


dvb_net_init:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Net init
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    call  dvb_register_device

    ret


dvb_usb_adapter_init:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Adapter init
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   [adap_id],dword 0 ; only one adapter

    ; "will pass the complete MPEG2 transport stream
    ;  to the software demuxer"

    mov   [adap_pid_filtering],dword 0
    mov   [adap_max_feed_count],dword 255

    call  dvb_usb_adapter_stream_init

    call  dvb_usb_adapter_dvb_init

    call  dvb_usb_adapter_frontend_init

    ; send,generic
    mov   r11 , generic_bulk_control_ep
    call  usb_clear_halt
    ; rcv,generic
    mov   r11 , generic_bulk_control_ep + 0x80
    call  usb_clear_halt

    ret



dvb_usb_adapter_stream_init:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Stream init
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; dvb_usb_data_complete ?

    call  usb_urb_init

    ret


usb_urb_init:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   URB init
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; receive - probs.endpoint
    mov   r11 , stream.probs.endpoint + 0x80
    call  usb_clear_halt

    call  usb_bulk_urb_init

    ret



usb_bulk_urb_init:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Bulk init
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    call  usb_allocate_stream_buffers

    call  usb_fill_bulk_urb

    ret


usb_fill_bulk_urb:

    ret


usb_allocate_stream_buffers:

    ret



usb_clear_halt:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   In: r11 - endpoint to clear (0x80+ = in 0+ = out)
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rcx , 0
    mov   rdx , 0
    mov   r8  , 0x01 ; usb_req_clear_feature
    mov   r9  , 0x02 ; usb_recip_endpoint
    mov   r10 , 0x00 ; usb_endpoint_halt
    mov   r11 , r11  ; endpoint to clear

    call  usb_control_msg_new

    call  usb_reset_endpoint

    ret


usb_reset_endpoint:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Device endpoint reset
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; dev,ep
    call  usb_hdc_reset_endpoint

    ret


usb_hdc_reset_endpoint:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Device endpoint reset
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    call  usb_settogle

    ret


usb_settogle:

    ret




usb_set_infdata:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Set infdata
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    call  dev_set_drvdata

    ret


dev_set_drvdata:

    ; dev->driver.data = data

    ret



dvb_usb_init:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   USB init
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; mutex_init
    ; mutex_init

    mov   [adap.state],dword 0

    mov   rax , 1 ; 0/1
    call  dvb_usb_device_power_ctrl

    call  dvb_usb_i2c_init

    call  dvb_usb_adapter_init

    call  dvb_usb_remote_init

    mov   rax , 0 ; 0/1
    call  dvb_usb_device_power_ctrl

    ret



dvb_usb_i2c_init:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   I2C init
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    call  i2c_set_adapdata

    call  i2c_add_adapter

    ret


i2c_set_adapdata:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Set adapdata
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    call  dev_set_drvdata

    ret


i2c_add_adapter:

    ret





dvb_usb_device_power_ctrl:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   In: rax - 0/1 off/on
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; No actual communication with the device ?

    cmp   rax , 1
    jne   nopp
    cmp   [powered],dword 0
    jne   nopp
    inc   dword [powered]
    call  power_ctrl ; rax
    ret
  nopp:

    cmp   rax , 0
    jne   nopm
    cmp   [powered],dword 1
    jne   nopm
    dec   dword [powered]
    call  power_ctrl ; rax
    ret
  nopm:

    ret

power_ctrl:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   In: rax - 0/1 - off/on
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; no actual communication ?

    ret





read_firmware_and_player:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Read firmware and player files
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    cmp   [firmware_loaded],byte 1
    je    noloadfm

    mov   rax , 58
    mov   rbx , 0
    mov   rcx , 0
    mov   rdx , -1
    mov   r8  , firmware_position
    mov   r9  , string_firmware_name
    int   0x60

    cmp   rbx , 100
    ja    firmware_found

    mov   [status_text_pointer],dword string_status_no_firmware
    call  draw_status

    mov   rax , 5
    mov   rbx , 250
    int   0x60

    jmp   still

  firmware_found:

    mov   [firmware_size],rbx

    mov   [firmware_loaded],byte 1

  noloadfm:

    cmp   [mplayer_position+3*8],dword 0
    jne   noloadmp

    ; Load mplayer to memory

    mov   rax , 58
    mov   rbx , 0
    mov   rcx , 0
    mov   rdx , -1
    mov   r8  , mplayer_position
    mov   r9  , filestart
    int   0x60

    mov   [mplayer_position+3*8],rbx

  noloadmp:

    ret





unpack_firmware:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Unpack and upload the firmware
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rdx , 160 shl 32 + 50
    mov   r10 , firmware_position

  fwl0:

    ; Next packet start

    movzx r11 , byte [r10]
    add   r11 , r10
    add   r11 , 5

    ; Convert and send

    call  get_hex_line
    call  send_firmware_packet

    ; Display hexline(s)

    mov   r14 , hex_line
  fwl1:
    mov   rax , 18 shl 32
    add   rdx , rax
    mov   rax , 47
    mov   rbx , 2*65536+ 1*256
    mov   rcx , [r14]
    mov   rsi , 0x000000
;    int   0x60
    inc   r14
    add   r10 , 1
    cmp   r10 , r11
    jb    fwl1
    add   dx , 10
    and   rdx , 0xffff
    mov   rax , 160 shl 32
    add   rdx , rax
    mov   rax , rdx
    and   rax , 0xffff
    cmp   rax , 500
    jb    nonewscr
    mov   rax , 5
    mov   rbx , 1
;    int   0x60
    push  r10 r11
;    call  draw_window
    pop   r11 r10
    mov   rdx , 160 shl 32 + 50
  nonewscr:

    ; Next packet

    mov   r12 , firmware_position
    add   r12 , [firmware_size]
    cmp   r10 , r12
    jb    fwl0

    ret



get_hex_line:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Out: Length, Address, Address, Type, Data.., Checkbyte
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    push  rax rbx rcx rsi rdi

    mov   rsi , r10
    mov   rdi , hex_line
    mov   rcx , r11
    sub   rcx , r10
    cld
    rep   movsb

    ; Address to big endian

    mov   al , [hex_line+1]
    mov   bl , [hex_line+2]

    mov   [hex_line+1], bl
    mov   [hex_line+2], al

    pop   rdi rsi rcx rbx rax

    ret



send_firmware_packet:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Upload the firmware segment to device
;
;   In: r10,r11  - current,next
;       hex_line - data
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    push  rax rbx rcx rdx rsi rdi

    mov   rcx , r11
    sub   rcx , r10 ; data length

    mov   rsi , hex_line

    call  usb_bulk_msg

    pop   rdi rsi rdx rcx rbx rax

    ret



start_firmware:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Start the uploaded firmware
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   [data_start_firmware+0],byte 0x08 ; REQUEST_JUMPRAM
    mov   [data_start_firmware+1],byte 0
    mov   [data_start_firmware+2],byte 0
    mov   [data_start_firmware+3],byte 0
    mov   [data_start_firmware+4],byte 0x70 ; address
    mov   [data_start_firmware+5],byte 0x00 ;
    mov   [data_start_firmware+6],byte 0x00 ;
    mov   [data_start_firmware+7],byte 0x00 ;

    mov   rsi , data_start_firmware
    mov   rcx , 8
    call  usb_bulk_msg

    ; 500 ms delay

    mov   rax , 105
    mov   rbx , 501
    int   0x60

    ret


usb_bulk_msg:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   In: rsi - data position
;       rcx - length
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    push  rax rbx rcx rdx rsi r8

    mov   rax , 130
    mov   rbx , 10
    mov   rcx , rcx  ; length
    mov   rdx , 1    ; endpoint
    mov   rsi , rsi  ; data
    mov   r8  , 512  ; endpoint size
    int   0x60

    pop   r8 rsi rdx rcx rbx rax

    ret



usb_bulk_msg_in:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   In: rdi - data position
;       rcx - length
;       rdx - endpoint
;       r8  - endpoint size
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    push  rax rbx rcx rdx rdi

    mov   rax , 130
    mov   rbx , 11
    mov   rcx , rcx  ; length
    mov   rdx , rdx  ; endpoint
    mov   rdi , rdi  ; data
    int   0x60

    mov   [usb_bulk_result],rax

    pop   rdi rdx rcx rbx rax

    ret



usb_bulk_msg_in_12:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   In: rdi - data position
;       rcx - length
;       rdx - endpoint
;       r8  - endpoint size
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    push  rax rbx rcx rdx rdi r9 r15

    mov   rax , 130
    mov   rbx , 12
    int   0x60

    mov   [usb_bulk_result],rax

    pop   r15 r9 rdi rdx rcx rbx rax

    ret






dib0700_get_version:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Returns hwversion, romversion, ramversion, fwtype.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    push  rax rbx rcx rdx r8 r9 r10 rsi rdi

    mov   [get_version_data_return],dword 0x0

    mov   r10 , 0x15                     ; REQUEST_GET_VERSION
    mov   r9  , get_version_data_return  ; rx data position
    mov   r8  , 16                       ; rx data length
    mov   rdx , 0           ; endpoint
    mov   rdi , 1           ; direction (1=in)
    mov   rcx , 0           ; value (word)
    mov   rsi , 0           ; index (word)
 ;   call  usb_control_msg

    ; Does the same as above call

    mov   rsi , data15
    mov   rcx , 2
    mov   r9  , get_version_data_return
    mov   r8  , 16
    mov   rdx , 0
    call  dib0700_ctrl_rd

;    ; Display result bytes
;
;    mov   rdx , 160 shl 32 + 520
;    mov   r14 , get_version_data_return
;  fwl11:
;    mov   rax , 18 shl 32
;    add   rdx , rax
;    mov   rax , 47
;    mov   rbx , 2*65536+ 1*256
;    mov   rcx , [r14]
;    mov   rsi , 0x000000
;    int   0x60
;    inc   r14
;    cmp   r14 , get_version_data_return+16
;    jb    fwl11

;    mov   rax , 5
;    mov   rbx , 50
;    int   0x60

    pop   rdi rsi r10 r9 r8 rdx rcx rbx rax

    ret



dib0700_rc_setup:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Enable remote controller receiver
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ret

    push  rax rbx rcx rdx r8 r9 r10 r11 r12 r13 r14 r15 rsi rdi

    mov   [data_enable_rc+0],byte 0x11     ; REQUEST_SET_RC
    mov   [data_enable_rc+1],byte 1        ; dvb_usb_dib0700_ir_proto
    mov   [data_enable_rc+2],byte 0        ; 0

    mov   rsi , data_enable_rc
    mov   rcx , 3
    call  dib0700_ctrl_wr

    pop   rdi rsi r15 r14 r13 r12 r11 r10 r9 r8 rdx rcx rbx rax

    ret



dib0700_rc_read:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Read remote controller data
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    push  rax rbx rcx rdx r8 r9 r10 r11 r12 r13 r14 r15 rsi rdi

    ; Read data from endpoint 1

    mov   rdi , data_rc_read
    mov   rcx , 6
    mov   rdx , 1
    mov   r8  , 512
    call  usb_bulk_msg_in

    ; Display result bytes

    mov   rdx , 100 shl 32 + 550
    mov   r14 , data_rc_read

  fwl12:

    mov   rax , 18 shl 32
    add   rdx , rax

    push  rax rbx rcx rdx
    mov   rax , 13
    mov   rbx , rdx
    mov   bx  , 12
    mov   rcx , rdx
    shl   rcx , 32
    mov   cx  , 10
    mov   rdx , 0xffffff
;    int   0x60
    pop   rdx rcx rbx rax

    mov   rax , 47
    mov   rbx , 2*65536+ 1*256
    mov   rcx , [r14]
    mov   rsi , 0x000000
;    int   0x60

    inc   r14
    cmp   r14 , data_rc_read+6
    jb    fwl12

    pop   rdi rsi r15 r14 r13 r12 r11 r10 r9 r8 rdx rcx rbx rax

    ret





dib0700_ctrl_clock:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Set the clock to 72 Mhz
;
;   In: rax - 72
;       rbx - clock_out_gp3
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rax , 72 ; for now
    mov   rbx , 1  ; for now

    cmp   rax , 72
    jne   dccl1

    mov   rdx , rbx

    mov   rax , 1
    mov   rbx , 0
    mov   rcx , 1
    mov   r8  , 2
    mov   r9  , 24
    mov   r10 , 0
    mov   r11 , 0x4c
    call  dib0700_set_clock

  dccl1:

    ret



dib0700_set_clock:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Set the clock
;
;   In: rax - en_pll
;       rbx - pll_scr
;       rcx - pll_range
;       rdx - clock_gpio3
;       r8  - pll_prediv
;       r9  - pll_loopdiv
;       r10 - free_div
;       r11 - dsuScaler
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    push  rax rbx rcx rdx r8 r9 r10 r11

    ; Form the packet

    mov   [data_set_clock+0],byte 0x0B ; REQUEST_SET_CLOCK

    shl   rax , 7
    shl   rbx , 6
    shl   rcx , 5
    shl   rdx , 4

    or    rax , rbx
    or    rax , rcx
    or    rax , rdx

    mov   [data_set_clock+1],al

    mov   [data_set_clock+3],r8b
    shr   r8 , 8
    mov   [data_set_clock+2],r8b

    mov   [data_set_clock+5],r9b
    shr   r9 , 8
    mov   [data_set_clock+4],r9b

    mov   [data_set_clock+7],r10b
    shr   r10 , 8
    mov   [data_set_clock+6],r10b

    mov   [data_set_clock+9],r11b
    shr   r11 , 8
    mov   [data_set_clock+8],r11b

    ; Send the packet

    mov   rsi , data_set_clock
    mov   rcx , 10
    call  dib0700_ctrl_wr

    pop   r11 r10 r9 r8 rdx rcx rbx rax

    ret




dib0700_streaming_control:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Turn stream on/off (adap->id 0)
;
;   In: rax = on/off (1/0)
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    push  rax rbx rcx rdx rsi rdi

    mov   [data_streaming_control+0],byte 0x0f ; REQUEST_ENABLE_VIDEO

    ; bit 4 = on/off (1/0)
    ; bit 0 = mpeg2-188 / analog (0/1)

    mov   rbx , rax
    shl   rbx , 4
    mov   [data_streaming_control+1],bl

    ; bit 4 = master mode on/off (1/0) (pinnacle pctv - ON)

    mov   bl , 1 shl 4

    ; bit 0 = Channel 1
    ; bit 1 = Channel 2

    ; adap->id 0

    mov   cl , al

    add   bl , cl
    mov   [data_streaming_control+2],bl

    mov   [data_streaming_control+3],byte 0

    mov   rsi , data_streaming_control
    mov   rcx , 4
    call  dib0700_ctrl_wr

    pop   rdi rsi rdx rcx rbx rax

    ret



dib0700_ctrl_wr:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   In: rsi - tx data position
;       rcx - tx length
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    push  rax rbx rcx rdx r8 r9 r10 r11 rsi rdi

    mov   r9  , rsi         ; tx data position
    mov   r8  , rcx         ; tx data length
    movzx r10 , byte [r9]   ; duplicates the t[0]
    mov   rdx , 0           ; endpoint
    mov   rdi , 0           ; direction (0=out)
    mov   rsi , 0           ; value (word)
    mov   rcx , 0           ; index (word)
    mov   r11 , 01000100b   ; out header
    call  usb_control_msg

    pop   rdi rsi r11 r10 r9 r8 rdx rcx rbx rax

    ret




dib0700_ctrl_rd:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   In: rsi - tx data position
;       rcx - tx length
;       r9  - rx data position
;       r8  - rx length
;       rdx - endpoint
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    push  rax rbx rcx rdx r8 r9 r10 r11 r14 r15 rsi rdi

    mov   rdx , rdx         ; endpoint
    movzx r10 , byte [rsi]  ; duplicates the t[0]
    mov   rdi , 1           ; direction (1=in)

    mov   r14 , rcx         ; save length
    mov   r15 , rsi         ; save pos

    ; value = ( (tx_length-2) << 8 ) I tx[1]

    mov   rsi , r14
    sub   rsi , 2

    cmp   [r15+1],byte 0xc0  ; 0x1900
    jne   nosss
    sub   rsi , 1
  nosss:

    shl   rsi , 8
    movzx rax , byte [r15+1]
    add   rsi , rax

    ; index

    mov   rcx , 0
    cmp   r14 , 2
    jbe   noleng2
    mov   cl  , [r15+2]
    shl   rcx , 8
  noleng2:
    cmp   r14 , 3
    jbe   noleng3
    mov   cl  , [r15+3]
  noleng3:

    mov   r9  , r9          ; rx data position
    mov   r8  , r8          ; rx data length
    mov   r11 , 11000000b   ; in header
    call  usb_control_msg

    pop   rdi rsi r15 r14 r11 r10 r9 r8 rdx rcx rbx rax

    ret





dib0700_i2c_xfer_legacy:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   In: rsi - pointer to message
;       rcx - type of message
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; Write+Read - len 2+2

    cmp   rcx , 2
    jne   noxfr

    ; Read

    mov   [xbuf+0],byte 0x02    ; REQUEST_I2C_READ

    mov   al , [addr]
    shl   al , 1
    cmp   al , 0xc0
    je    noadd
    add   al , 1
  noadd:
    mov   [xbuf+1],al           ; byte (addr shl 1) + 1

    mov   al , [rsi+0]
    mov   [xbuf+2],al
    mov   al , [rsi+1]
    mov   [xbuf+3],al

    mov   rsi , xbuf
    mov   rcx , 2+2
    mov   r9  , buf_ret
    mov   r8  , 2
    mov   rdx , 0
    call  dib0700_ctrl_rd

    movzx rdx , word [buf_ret]

    ret

  noxfr:

    cmp   rcx , 1   ; msg len 4
    jne   noxfr_wr

    mov   [xbuf+0],byte 0x03    ; REQUEST_I2C_WRITE

    mov   al , [addr]
    shl   al , 1

    mov   [xbuf+1],al           ; byte addr shl 1

    mov   al , [rsi+0]
    mov   [xbuf+2],al
    mov   al , [rsi+1]
    mov   [xbuf+3],al
    mov   al , [rsi+2]
    mov   [xbuf+4],al
    mov   al , [rsi+3]
    mov   [xbuf+5],al

    mov   rsi , xbuf
    mov   rcx , 4+2
    call  dib0700_ctrl_wr

    ret

  noxfr_wr:

    cmp   rcx , 3    ; msg len 3
    jne   noxfr_wr3

    mov   [xbuf+0],byte 0x03    ; REQUEST_I2C_WRITE

    mov   al , [addr]
    shl   al , 1

    mov   [xbuf+1],al           ; byte addr shl 1

    mov   al , [rsi+0]
    mov   [xbuf+2],al
    mov   al , [rsi+1]
    mov   [xbuf+3],al
    mov   al , [rsi+2]
    mov   [xbuf+4],al

    mov   rsi , xbuf
    mov   rcx , 3+2
    call  dib0700_ctrl_wr

    ret

  noxfr_wr3:

    ; Write+Read - len 1+2

    cmp   rcx , 4
    jne   noxfr4

    ; Read

    mov   [xbuf+0],byte 0x02    ; REQUEST_I2C_READ

    mov   al , [addr]
    shl   al , 1
    add   al , 1
    mov   [xbuf+1],al           ; byte (addr shl 1) + 1

    mov   al , [rsi+0]
    mov   [xbuf+2],al

    mov   rsi , xbuf
    mov   rcx , 1+2
    mov   r9  , buf_ret
    mov   r8  , 2
    mov   rdx , 0
    call  dib0700_ctrl_rd

    movzx rdx , word [buf_ret]

    ret

  noxfr4:

    ret



i2c_transfer:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Select communication type
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    call  dib0700_i2c_xfer_legacy

    mov   rax , 105
    mov   rbx , i2c_delay
    int   0x60

    ret



dib7000p_read_word:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   In: rcx = Register
;
;   Out:rdx = Value
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    push  rax rbx rcx r8 r9 r10 r11 r12 r13 r14 r15 rsi rdi rbp

    mov   dword [buf_ret],dword 0

    mov   [rwmsg+0],ch
    mov   [rwmsg+1],cl

    mov   ax , [i2c_addr]
    shr   ax , 1
    mov   [addr], ax

    mov   rcx , 2
    mov   rsi , rwmsg
    call  i2c_transfer    ; call dib0700_i2c_xfer_legacy
                          ; _legacy ok with 0x12 addr
                          ; _new isnt

    movzx rdx , word [buf_ret]
    xchg  dl  ,dh
    mov   [buf_ret],dx

    and   rdx , 0xffff

    pop   rbp rdi rsi r15 r14 r13 r12 r11 r10 r9 r8 rcx rbx rax

    ret




dib7000p_write_word:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   In: rcx = Register
;       rdx = Value
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    push  rax rbx rcx r8 r9 r10 r11 r12 r13 r14 r15 rsi rdi rbp

    mov   [wwmsg+0],ch
    mov   [wwmsg+1],cl
    mov   [wwmsg+2],dh
    mov   [wwmsg+3],dl

    mov   ax , [i2c_addr]
    shr   ax , 1
    mov   [addr], ax

    mov   rcx , 1
    mov   rsi , wwmsg
    call  i2c_transfer

    pop   rbp rdi rsi r15 r14 r13 r12 r11 r10 r9 r8 rcx rbx rax

    ret







dib0700_set_gpio:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Set GPIO
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   [gpio_buf+0],byte 0x0C   ; REQUEST_SET_GPIO
    mov   [gpio_buf+1],byte al     ; GPIO

    and   bl , 1
    shl   bl , 7
    and   cl , 1
    shl   cl , 6
    or    bl , cl

    mov   [gpio_buf+2],byte bl     ; gpio_dir / gpio_val

    mov   rsi , gpio_buf
    mov   rcx , 3
    call  dib0700_ctrl_wr

    ret




stk7070p_frontend_attach:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Frontend init
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; Pinnacle pctv 72e (0) / hauppauge and others (1)

    mov   rax , 130
    mov   rbx , 5
    int   0x60
    mov   rcx , 1
    cmp   rbx , 0x02362304
    jne   nopctv72e
    mov   rcx , 0
  nopctv72e:

    mov   rax , GPIO6
    mov   rbx , GPIO_OUT
    call  dib0700_set_gpio
    mov   rax , 105
    mov   rbx , 11
    int   0x60

    mov   rax , GPIO9
    mov   rbx , GPIO_OUT
    mov   rcx , 1
    call  dib0700_set_gpio

    mov   rax , GPIO4
    mov   rbx , GPIO_OUT
    mov   rcx , 1
    call  dib0700_set_gpio

    mov   rax , GPIO7
    mov   rbx , GPIO_OUT
    mov   rcx , 1
    call  dib0700_set_gpio

    mov   rax , GPIO10
    mov   rbx , GPIO_OUT
    mov   rcx , 0
    call  dib0700_set_gpio

    call  dib0700_ctrl_clock

    mov   rax , 105
    mov   rbx , 11
    int   0x60

    mov   rax , GPIO10
    mov   rbx , GPIO_OUT
    mov   rcx , 1
    call  dib0700_set_gpio

    mov   rax , 105
    mov   rbx , 11
    int   0x60

    mov   rax , GPIO0
    mov   rbx , GPIO_OUT
    mov   rcx , 1
    call  dib0700_set_gpio

    ;

    call  dib7070p_dib7000p_config

    ; enumerate

    call  dib7000p_i2c_enumeration

    ; dib7000p_attach  ( close gate ? )

    call  dib7000p_attach

    ; dvb_attach - no functions ?

    ret



dib7070p_dib7000p_config:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Default configuration variables
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   [output_mpeg2_in_188_bytes],dword 1

    mov   [agc_config_count],dword 1

    ; agc

    ; bw = dib7070_bw_config_12_mhz - done

    mov   [tuner_is_baseband],dword 1

    mov   [spur_protect],dword 1

    mov   [gpio_dir],dword DIB7000P_GPIO_DEFAULT_DIRECTIONS
    mov   [gpio_val],dword DIB7000P_GPIO_DEFAULT_VALUES

    mov   [gpio_pwm_pos],dword DIB7000P_GPIO_DEFAULT_PWM_POS

    mov   [hostbus_diversity],dword 1

    ret


dib7000p_attach:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Device init
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; output_mode = outmode_mpeg2_fifo

    mov   [output_mode],dword OUTMODE_MPEG2_FIFO

;    call  draw_window
;    call  dib7000p_identify
;    mov   rax , 5
;    mov   rbx , 100
;    int   0x60

    call  dibx000_init_i2c_master

    call  dib7000p_demod_reset

;    call  draw_window

    ret




dibx000_init_i2c_master:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   I2C init
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   [base_reg], dword 1024 ; device_rev=DIB7000P

    call  dibx000_i2c_gated_tuner_algo

    call  i2c_adapter_init

    mov   rax , 0x60
    mov   rbx , 1
    call  dibx000_i2c_gate_ctrl

    ret   ; newstuff

    mov   ax , [i2c_addr]
    shr   ax , 1
    mov   [addr], ax
    mov   rsi , gbuf
    mov   rcx , 1
    call  i2c_transfer

    ret


dibx000_i2c_gated_tuner_algo:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Default setting
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   [master_xfer],dword dibx000_i2c_gated_tuner_xfer

    ret




dibx000_i2c_gated_tuner_xfer:

    ; bug - is this used ?

    ret



i2c_adapter_init:

    ; No functions ?

    ret


dibx000_i2c_gate_ctrl:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   In : rax = addr
;        rbx = onoff
;
;   Out: gbuf[0..3]
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rcx , 0x0401    ; newstuff
    mov   rdx , 0xC000
    mov   [i2c_addr],byte 0x80
    call  dib7000p_write_word

    ret

    ; rcx = val

    cmp  rbx , 1
    jne  no_on
    mov  rcx , rax    ; bit 7 = use master or not, if 0, the gate is open
    shl  rcx , 8
    jmp  onoffdone
  no_on:
    mov  rcx , 1 shl 7
  onoffdone:

    ; if mst->device_rev > DIB7000  - yes - DIB7000P > DIB7000 (11>2)

    shl  rcx , 1 ; val <<= 1 ?

    mov  rdx , [base_reg] ; what is base_reg ? - bug?
    add  rdx , 1
    mov  r8  , rdx
    shr  r8  , 8
    mov  [gbuf+0] , r8b
    mov  r8  , rdx
    mov  [gbuf+1] , r8b

    mov  r8 , rcx
    shr  r8 , 8
    mov  [gbuf+2] , r8b
    mov  [gbuf+3] , cl

    ret




dib7000p_demod_reset:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Demodulator reset
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rax , DIB7000P_POWER_ALL
    call  dib7000p_set_power_mode

    mov   rax , DIBX000_VBG_ENABLE
    call  dib7000p_set_adc_state

    ; restart all parts

    mov   rcx , 770
    mov   rdx , 0xffff
    call  dib7000p_write_word
    mov   rcx , 771
    mov   rdx , 0xffff
    call  dib7000p_write_word
    mov   rcx , 772
    mov   rdx , 0x001f
    call  dib7000p_write_word
    mov   rcx , 898
    mov   rdx , 0x0003
    call  dib7000p_write_word

    ; except i2c, stio, gpio - control interfaces

    mov   rcx , 1280
    mov   rdx , 0x01fc - 11100000b  ; (1 shl 7) - (1 shl 6) - (1 shl 5)
    call  dib7000p_write_word

    mov   rcx , 770
    mov   rdx , 0x0000
    call  dib7000p_write_word
    mov   rcx , 771
    mov   rdx , 0x0000
    call  dib7000p_write_word
    mov   rcx , 772
    mov   rdx , 0x0000
    call  dib7000p_write_word
    mov   rcx , 898
    mov   rdx , 0x0000
    call  dib7000p_write_word
    mov   rcx , 1280
    mov   rdx , 0x0000
    call  dib7000p_write_word

    ; default
    call  dib7000p_reset_pll

    call  dib7000p_reset_gpio

    mov   rax , OUTMODE_HIGH_Z
    call  dib7000p_set_output_mode

    ; unforce divstr regardless whether i2c enumeration was done or not

    mov   rcx , 1285
    call  dib7000p_read_word
    and   rdx , 1111111111111101b
    mov   rcx , 1285
    call  dib7000p_write_word

    mov   rax , [current_bandwidth] ;
    call  dib7000p_set_bandwidth

    mov   rax , DIBX000_SLOW_ADC_ON
    call  dib7000p_set_adc_state

    call  dib7000p_sad_calib

    mov   rax , DIBX000_SLOW_ADC_OFF
    call  dib7000p_set_adc_state

    cmp   [tuner_is_baseband],byte 1
    jne   notibb
    mov   rdx , 0x0755
    mov   rcx , 36
    call  dib7000p_write_word
    jmp   tidone
  notibb:
    mov   rdx , 0x1f55
    mov   rcx , 36
    call  dib7000p_write_word
  tidone:

    mov   rax , dib7000p_defaults
    mov   r15 , dib7000p_defaults_end
    call  dib7000p_write_tab

    mov   rax , DIB7000P_POWER_INTERFACE_ONLY
    call  dib7000p_set_power_mode

    ret





dib7000p_write_tab:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   In: rax = pointer to default table
;       r15 = end of table
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  dwtl0:

    movzx rbx , word [rax]    ; num of variables

    cmp   rbx , 0
    je    dwtl2

    movzx rcx , word [rax+2]  ; start address

    add   rax , 4

    cmp   rax , r15 ; dib7000p_write_tab
    jb    nohlt

    mov   rax , 512
    int   0x60

  nohlt:

  dwtl1:

    movzx rdx , word [rax]

    push  rax rbx rcx rdx
    call  dib7000p_write_word
    pop   rdx rcx rbx rax

    add   rcx , 1
    add   rax , 2

    dec   rbx
    jnz   dwtl1

    jmp   dwtl0

  dwtl2:

    ret



dib7000p_sad_calib:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   SAD init
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rdx , 0
    mov   rcx , 73
    call  dib7000p_write_word

    mov   rdx , 776  ; 0.625*3.3 / 4096
    mov   rcx , 74
    call  dib7000p_write_word

    ; do the calibration

    mov   rdx , 1
    mov   rcx , 73
    call  dib7000p_write_word

    mov   rdx , 0
    mov   rcx , 73
    call  dib7000p_write_word

    ;

    mov   rax , 105  ; msleep(1)
    mov   rbx , 2
    int   0x60

    ret




dib7000p_set_bandwidth:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   In: rax = bandwidth khz
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


    mov   [current_bandwidth],rax

;    mov   rcx , 0 ; timf     ; newstuff
;    mov   rbx , 0
;    cmp   [state.timf],rbx
;    jne   nostz

    mov   rcx , [bwc.timf]

;    jmp   timfd              ; newstuff
;  nostz:
;    mov   rcx , [state.timf]
;  timfd:

    xor   rdx , rdx   ; bw / 50
    mov   rbx , 50
    div   rbx

    imul  rcx , rax   ; timf * (bw/50)

    mov   rax , rcx   ; / 160
    xor   rdx , rdx
    mov   rbx , 160
    div   rbx

    push  rax
    mov   rdx , rax
    shr   rdx , 16
    and   rdx , 0xffff
    mov   rcx , 23
    call  dib7000p_write_word
    pop   rax

    and   rax , 0xffff
    mov   rdx , rax
    mov   rcx , 24
    call  dib7000p_write_word

    ret




dib7000p_reset_gpio:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   GPIO reset
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   [gpio_dir],dword DIB7000P_GPIO_DEFAULT_DIRECTIONS
    mov   [gpio_val],dword DIB7000P_GPIO_DEFAULT_VALUES

    ; reset the GPIOs

    mov   rdx , [gpio_dir]
    mov   rcx , 1029
    call  dib7000p_write_word

    mov   rdx , [gpio_val]
    mov   rcx , 1030
    call  dib7000p_write_word

    ; TODO 1031 is P_gpio_od

    mov   rdx , [gpio_pwm_pos]
    mov   rcx , 1032
    call  dib7000p_write_word

    mov   rdx , [pwm_freq_div]  ; bug - is this defined ?
    mov   rcx , 1037
    call  dib7000p_write_word

    ret




dib7000p_reset_pll:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   PLL reset
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


    ; force PLL bypass

    ; clk_cfg0

    mov   rdx , 1 shl 15
    mov   rcx , [bwc.pll_ratio]
    and   rcx , 0x3f
    shl   rcx , 9
    or    rdx , rcx
    mov   rcx , [bwc.modulo]
    shl   rcx , 7
    or    rdx , rcx
    mov   rcx , [bwc.ADClkSrc]
    shl   rcx , 6
    or    rdx , rcx
    mov   rcx , [bwc.IO_CLK_en_core]
    shl   rcx , 5
    or    rdx , rcx
    mov   rcx , [bwc.bypclk_div]
    shl   rcx , 2
    or    rdx , rcx
    mov   rcx , [bwc.enable_refdiv]
    shl   rcx , 1
    or    rdx , rcx

    push  rdx

    mov   rcx , 900
    call  dib7000p_write_word

    ; P_pll_cfg

    mov   rdx , [bwc.pll_prediv]
    shl   rdx , 5
    mov   rcx , [bwc.pll_ratio]
    shr   rcx , 6
    and   rcx , 0x3
    shl   rcx , 3
    or    rdx , rcx
    mov   rcx , [bwc.pll_range]
    shl   rcx , 1
    or    rdx , rcx
    mov   rcx , [bwc.pll_reset]
    or    rdx , rcx

    mov   rcx , 903
    call  dib7000p_write_word

    pop   rdx
    and   rdx , 0x7fff

    mov   rcx , [bwc.pll_bypass]
    shl   rcx , 15
    or    rdx , rcx

    mov   rcx , 900
    call  dib7000p_write_word

    ;

    mov   rdx , [bwc.internal]
    imul  rdx , 1000
    shr   rdx , 16
    and   rdx , 0xffff
    mov   rcx , 18
    call  dib7000p_write_word

    mov   rdx , [bwc.internal]
    imul  rdx , 1000
    and   rdx , 0xffff
    mov   rcx , 19
    call  dib7000p_write_word

    mov   rdx , [bwc.ifreq]
    shr   rdx , 16
    and   rdx , 0xffff
    mov   rcx , 21
    call  dib7000p_write_word

    mov   rdx , [bwc.ifreq]
    and   rdx , 0xffff
    mov   rcx , 22
    call  dib7000p_write_word

    ;

    mov   rdx , [bwc.sad_cfg]
    mov   rcx , 72
    call  dib7000p_write_word

    ret






dib7000p_set_adc_state:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   In: rax = state
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    push  rax

    mov   rcx , 908
    call  dib7000p_read_word
    mov   [reg_908],rdx

    mov   rcx , 909
    call  dib7000p_read_word
    mov   [reg_909],rdx

    pop   rax

    cmp   rax , DIBX000_SLOW_ADC_ON
    jne   nodsao
    mov   rdx , [reg_909]
    or    rdx , 11b
    mov   [reg_909],rdx
    mov   rcx , 909
    call  dib7000p_write_word
    mov   rdx , [reg_909]
    and   rdx , 1111111111111101b
    mov   [reg_909],rdx
    jmp   dsasl1
  nodsao:

    cmp   rax , DIBX000_SLOW_ADC_OFF
    jne   nodsaoff
    mov   rdx , [reg_909]
    or    rdx , 11b
    mov   [reg_909], rdx
    jmp   dsasl1
  nodsaoff:

    cmp   rax , DIBX000_ADC_ON
    jne   nodao
    and   [reg_908],word 0x0fff
    and   [reg_909],word 0x0003
    jmp   dsasl1
  nodao:

    cmp   rax , DIBX000_VBG_ENABLE
    jne   nodvgbe
    and   [reg_908],word 0111111111111111b   ; (av) (1<<15)
    jmp   dsasl1
  nodvgbe:

  dsasl1:

    mov   rcx , 908
    mov   rdx , [reg_908]
    call  dib7000p_write_word

    mov   rcx , 909
    mov   rdx , [reg_909]
    call  dib7000p_write_word

    ret






dib7000p_set_power_mode:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;  In: rax = power mode
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    push  rax

    ; by default everything is powered off

    mov   [reg_774],word 0xffff
    mov   [reg_775],word 0xffff
    mov   [reg_776],word 0x0007
    mov   [reg_899],word 0x0003
    mov   rcx , 1280
    call  dib7000p_read_word
    and   rdx , 0x01ff
    or    rdx , 0xfe00
    mov   [reg_1280],rdx

    pop   rax

    cmp   rax , DIB7000P_POWER_ALL
    jne   nodpa
    mov   [reg_774] ,word 0x0000
    mov   [reg_775] ,word 0x0000
    mov   [reg_776] ,word 0x0000
    mov   [reg_899] ,word 0x0000
    and   [reg_1280],word 0x01ff
    jmp   powerd
  nodpa:

    ; Just leave power on the control-interfaces: GPIO and (I2C or SDIO)
    ; TODO: power up either SDIO or I2C

    cmp   rax , DIB7000P_POWER_INTERFACE_ONLY
    jne   nodpio
    and   [reg_1280],word 1000101111111111b
    jmp   powerd
  nodpio:

    ;

  powerd:

    mov   rcx , 774
    mov   rdx , [reg_774]
    call  dib7000p_write_word
    mov   rcx , 775
    mov   rdx , [reg_775]
    call  dib7000p_write_word
    mov   rcx , 776
    mov   rdx , [reg_776]
    call  dib7000p_write_word
    mov   rcx , 899
    mov   rdx , [reg_899]
    call  dib7000p_write_word
    mov   rcx , 1280
    mov   rdx , [reg_1280]
    call  dib7000p_write_word

    ret




dib7000p_i2c_enumeration:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   I2C enumeration
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;    call  draw_window

    ; New address

    new_addr equ (0x40 shl 1)

;    mov   rax , new_addr ; 0x40 shl 1
;    mov   [i2c_addr],rax
;    call  dib7000p_identify
;
;    cmp   rdx , 0x01b3
;    je    idsuccess
;
;    call  draw_window
;
;    ; Default address
;
;    mov   rax , 18
;    mov   [i2c_addr],rax
;    call  dib7000p_identify
;
;  idsuccess:

    ; We come from full init

    mov   rax , 18
    mov   [i2c_addr],rax

    ; Start diversity to pull_down div_str - just for i2c-enumeration

    mov   rax , OUTMODE_DIVERSITY
    call  dib7000p_set_output_mode

    ; set new i2c address and force divstart

    mov   rcx , 1285
    mov   rdx , (new_addr shl 2) + 0x02
    call  dib7000p_write_word

    ; IC initialized (to i2c_address: new_addr)

    mov   rax , 0x40 shl 1
    mov   [i2c_addr],rax

    ; unforce divstr
    mov   rcx , 1285
    mov   rdx , [i2c_addr]
    shl   rdx , 2
    call  dib7000p_write_word

    ; deactivate div - it was just for i2c-enumeration

    mov   rax , OUTMODE_HIGH_Z
    call  dib7000p_set_output_mode

    ret


dib7000p_set_output_mode:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   In: rax - mode
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    push  rax

    mov   [outreg],dword 0
    mov   [fifo_threshold],dword 1792

    mov   rcx , 235
    call  dib7000p_read_word
    and   rdx , 0x0010
    or    rdx , 1 shl 1
    mov   [smo_mode],rdx

    pop   rax

    cmp   rax , OUTMODE_DIVERSITY
    jne   noomd
    mov   [outreg],dword (1 shl 10) + (4 shl 6) ; for 7070p
  noomd:

    cmp   rax , OUTMODE_MPEG2_FIFO      ;; e.g. USB feeding
    jne   noommf
    or    [smo_mode],dword (3 shl 1)
    mov   [fifo_threshold],dword 512
    mov   [outreg],dword (1 shl 10) + (5 shl 6)
  noommf:

    cmp   rax , OUTMODE_HIGH_Z
    jne   noomhz
    mov   [outreg],dword 0
  noomhz:

    ; output_mpeg2_in_188_bytes ; for 7070p

    or    [smo_mode],dword (1 shl 5)

    mov   rcx , 235
    mov   rdx , [smo_mode]
    call  dib7000p_write_word

    mov   rcx , 236
    mov   rdx , [fifo_threshold]
    call  dib7000p_write_word       ; synchronous fread

    mov   rcx , 1286
    mov   rdx , [outreg]
    call  dib7000p_write_word       ; P_Div_active

    ret





dib7000p_identify:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Identify device
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rcx , 768
    call  dib7000p_read_word
    push  rdx
    mov   rcx , 769
    call  dib7000p_read_word
    pop   rdx

    ret


usb_control_msg:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   In: rsi - value (word)
;       rcx - index (word)
;       rdi - direction (0=out,1=in)
;       r9  - tx/rx data position
;       r8  - tx/rx length
;       rdx - endpoint
;       r10 - second byte
;       r11 - first byte
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    push  rax rbx rcx rdx

    mov   rax , 130
    mov   rbx , 15
    int   0x60

    mov   [usb_control_result],rax

    mov   rax , 105
    mov   rbx , i2c_delay
    int   0x60

    pop   rdx rcx rbx rax

    ret


usb_control_msg_new:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   For endpoint clearing (atleast)
;
;   In: rcx - 0/1 - out/in
;       rdx - endpoint num
;       r8  - usb_clear_feature
;       r9  - usb_recip_endpoint
;       r10 - usb_endpoint_halt
;       r11 - endp
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    push  rax rbx

    mov   rax , 130
    mov   rbx , 20
    int   0x60

    mov   [usb_control_result],rax

    pop   rbx rax

    ret





print:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   For debugging
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ret

    push  rax rbx rcx rdx
    mov   rcx , rax
    shl   rcx , 32
    add   rcx , 10
    mov   rax , 13
    mov   rbx , 40 shl 32 + 8*8
    mov   rdx , windowbgr
    int   0x60
    pop   rdx rcx rbx rax

    mov   rdx , 40 shl 32
    add   rdx , rax
    mov   rax , 47
    mov   rbx , 8*65536 + 256
    mov   rcx , rcx
    mov   rsi , 0x000000
    int   0x60

    ret



copytosendcache:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Copy data to decoder
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    push  rsi

    ; Delay for setting up new descriptors

    mov   rax , 5
    mov   rbx , 15
    int   0x60

    ; Check copy destionation

    cmp   [sendcachepos],dword 8192000-(numr/2)*4096
    jbe   noscset
    mov   [sendcachepos],dword 8192000-(numr/2)*4096
  noscset:

    ; Copy data to sendcache

    mov   rdi , [sendcachepos]
    add   rdi , sendcache
    mov   rcx , (numr/2)*4096
    cld
    rep   movsb
    ;
    add   [sendcachepos],dword (numr/2)*4096

    ; Send 8192000 to player

    cmp   [sendcachepos],dword 8192000
    jb    nosendtoplayer

    mov   [sendcachepos],dword 0

    mov   rax , 60
    mov   rbx , 2
    mov   rcx , [pid]
    mov   rdx , sendcache
    mov   r8  , 4096*numr*2
    int   0x60

  nosendtoplayer:

    pop   rdi

    ; Clear receiver area

    mov   rcx , 4096*numr/2/8
    mov   rax , '        '
    cld
    rep   stosq

    ret




dib0700_read_ep_ring:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Start data read / send data to player
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ;
    ; Send data
    ;

    cmp   [readsend],byte 1
    jne   nodatasend

    ;
    ; Buffer 1
    ;
    cmp   [datacache+(numr/2)*4096],dword '    '
    je    nonewdata
    cmp   [datacache+(numr/2-1)*4096],dword '    '
    je    nonewdata

    ; Copy datacache -> sendcache

    mov   rsi , datacache
    call  copytosendcache

    ; Set repeat - not for halt

    cmp   [reading],byte 2
    je    nosetrepeat
    mov   rax , 'REPEAT'
    mov   [datacache],rax
  nosetrepeat:

  nonewdata:

    ;
    ; Buffer 2
    ;
    cmp   [datacache+0*4096],dword '    '
    je    nonewdata2
    cmp   [datacache+(numr-1)*4096],dword '    '
    je    nonewdata2

    ; Copy datacache -> sendcache

    mov   rsi , datacache+(numr/2)*4096
    call  copytosendcache

  nonewdata2:

    ;

  nodatasend:


    ;
    ; Start read thread
    ;

    cmp   [reading],byte 0
    jne   no_start_read

    ; Free the device to thread

    mov   rax , 130
    mov   rbx , 3
    mov   rcx , 1
    int   0x60

    ; Start data read thread

    mov   [reading],byte 1
    mov   [sr15],dword 2 ; ep

    mov   rax , 51
    mov   rbx , 1
    mov   rcx , read_thread
    mov   rdx , 0x100000-0x1000
    int   0x60

  no_start_read:

    ret



read_thread:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Thread for setting up descriptors
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; Reserve device

    mov   rax , 130
    mov   rbx , 2
    mov   rcx , 1
    int   0x60

    ; Data read thread

    mov   rdi , datacache
    mov   [rdi],dword '    '   ; no repeat
    mov   rdx , [sr15]         ; endpoint
    mov   rcx , datainsize     ; data in size
    mov   r8  , endpointsize   ; endpoint size
    mov   r9  , numr           ; number of packets to read
    call  usb_bulk_msg_in_12

    ; Free device

    mov   rax , 130
    mov   rbx , 3
    mov   rcx , 1
    int   0x60

    mov   [reading],byte 3

    mov   rax , 512
    int   0x60




draw_window:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Draw application window
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rax , 0xC
    mov   rbx , 0x1
    int   0x60

    ; Draw window

    mov   rax , 0
    ;; mov   rbx , (232-44) shl 32 + 165+55
    ;; mov   rcx , 43 shl 32 + 330-ych+55+40+12

    mov   rbx , 137 shl 32 + 165+55
    mov   rcx , 39 shl 32 + 330-ych+55+40+12

    mov   rdx , windowbgr
    mov   r8  , 0x1
    mov   r9  , window_label
    mov   r10 , menu_struct
    int   0x60

    ; Main screen

    cmp   [help_text],byte 0
    jne   no_screen_1

    ; Info text

    mov   rax , 4
    mov   rbx , string_info_1
    mov   rcx , 31
    mov   rdx , 50
    mov   rsi , 0x000000
    mov   r9  , 1
    int   0x60
    mov   rax , 4
    mov   rbx , string_info_2
    add   rdx , 14
    int   0x60

    ; Apply

    mov   rax , 8
    mov   rbx ,  30 * 0x100000000 + 78
    mov   rcx , (330-ych+40+15) * 0x100000000 + 20
    mov   rdx , 20
    mov   r8  , 0
    mov   r9  , button_text
    int   0x60

    ; Off

    mov   rax , 8
    mov   rbx , 108 * 0x100000000 + 78
    mov   rcx , (330-ych+40+15) * 0x100000000 + 20
    mov   rdx , 21
    mov   r8  , 0
    mov   r9  , button_text_2
    int   0x60

    ; Status text

    mov   rax , 4
    mov   rbx , string_text
    mov   rcx , 31
    mov   rdx , (80-ycs)
    mov   rsi , 0x000000
    mov   r9  , 1
    int   0x60

    ; Frequency text

    mov   rax , 4
    mov   rbx , string_text_2
    mov   rcx , 31
    mov   rdx , (144-ych)
    mov   rsi , 0x000000
    mov   r9  , 1
    int   0x60

    call  draw_scroll_1

    ; Adjust buttons

    mov   rcx , (160+31-ych) * 0x100000000 + 13
    mov   rdx , 151-2
  newadjust:
    mov   rax , 8
    mov   rbx , 162  * 0x100000000 + 11
    mov   r8  , 0
    mov   r9  , button_text_7
    int   0x60
    inc   rdx
    mov   rax , 8
    mov   rbx , 173  * 0x100000000 + 11
    mov   r8  , 0
    mov   r9  , button_text_8
    int   0x60
    inc   rdx
    mov   rax , 15 shl 32
    add   rcx , rax
    cmp   rdx , 151+4*2
    jb    newadjust

    ; Firmware text

    mov   rax , 4
    mov   rbx , string_text_4
    mov   rcx , 31
    mov   rdx , (248-25-ych+40+15)
    mov   rsi , 0x000000
    mov   r9  , 1
    int   0x60

    mov   r14 , textbox1
    call  draw_textbox

    ; Mplayer text

    mov   rax , 4
    mov   rbx , string_text_5
    mov   rcx , 31
    mov   rdx , (297-25-ych+40+15)
    mov   rsi , 0x000000
    mov   r9  , 1
    int   0x60

    mov   r14 , textbox2
    call  draw_textbox

    call  draw_status

  no_screen_1:

    ; Help text screen

    cmp   [help_text],byte 1
    jne   no_screen_2

    ; Info text

    mov   rax , 4
    mov   rbx , string_help
    mov   rcx , 31-2
    mov   rdx , 60+3-4
    mov   rsi , 0x000000
    mov   r9  , 1
  newline:
    int   0x60
    add   rdx , 12
    add   rbx , 40
    cmp   [rbx],byte 'x'
    jne   newline

  no_screen_2:

    mov   rax , 0xc
    mov   rbx , 2
    int   0x60

    ret



draw_status:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Draw device status
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; Device status

    mov   rax , 13
    mov   rbx , 31 shl 32 + 6*25
    mov   rcx , (95-ycs-1) shl 32 + 10+2
    mov   rdx , windowbgr
    int   0x60

    mov   rax , 4
    mov   rbx , [status_text_pointer]
    mov   rcx , 31
    mov   rdx , (95-ycs)
    mov   rsi , 0x000000
    mov   r9  , 1
    int   0x60

    ; Frequency

    mov   rax , 13
    mov   rbx , 097 shl 32 + 17
    mov   rcx , (144-ych-1) shl 32 + 7+2
    mov   rdx , windowbgr
    int   0x60

    mov   rax , 47
    mov   rbx , 3*65536
    mov   rcx , [device_frequency]
    mov   rdx , 97 shl 32 + (144-ych)
    mov   rsi , 0x000000
    int   0x60

    ; Setup texts

    mov   rax , 4
    mov   rbx , string_text_59
    mov   rcx , 31
    mov   rdx , (194-ych)
    mov   rsi , 0x000000
    mov   r9  , 1
    call  clear_border
    int   0x60
    mov   rbx , string_text_6
    add   rdx , 15
    call  clear_border
    int   0x60
    mov   rbx , string_text_7
    add   rdx , 15
    call  clear_border
    int   0x60
    mov   rbx , string_text_8
    add   rdx , 15
    call  clear_border
    int   0x60
    mov   rbx , string_text_9
    add   rdx , 15
    call  clear_border
    int   0x60

    ret


clear_border:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Clear variable border
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    push  rax rbx rcx rdx
    mov   rbx , rcx
    mov   rcx , rdx
    dec   rcx
    shl   rbx , 32
    shl   rcx , 32
    add   rbx , 21*6
    add   rcx , 10+2
    mov   rdx , windowbgr
    mov   rax , 13
    int   0x60
    pop   rdx rcx rbx rax

    ret



draw_scroll_1:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Frequency scroll
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; Vertical scroll

    mov   rax ,  113
    mov   rbx ,  2
    mov   rcx ,  1000
    mov   rdx ,  536
    mov   r8  , [vscroll_value]
    mov   r9  ,  160-ych
    mov   r10 ,  30
    mov   r11 ,  103+52
    int   0x60

    ret



;
; Initialized data
;

string_text:     db    'Device status: ',0
string_text_2:   db    'Frequency: 570Mhz',0
string_text_4:   db    'Firmware:',0
string_text_5:   db    'Player:',0

string_text_59:  db    'Bandwidth (mhz):    8',0
string_text_6:   db    'Transmission mode: 8K',0
string_text_7:   db    'Guard interval:   1/8',0
string_text_8:   db    'Constellation: QAM 64',0
string_text_9:   db    'Code rate:    FEC 2/3',0

window_label:    db    'TUNER',0
button_text:     db    'APPLY',0
button_text_2:   db    'OFF',0
button_text_6:   db    '6',0
button_text_7:   db    '-',0
button_text_8:   db    '+',0

vscroll_value:   dq    1260
vscroll_value_2: dq    2002

sendcachepos:    dq    0x0

menu_struct:               ; Menu Struct

    dq   0                 ; Version
    dq   0x100             ; Start value of ID to return ( ID + Line )
                           ; Returned when menu closes and
                           ; user made no selections.
    db   0,'FILE',0        ; ID = 0x100 + 1
    db   1,'Help..',0      ; ID = 0x100 + 2
    db   1,'-',0           ; ID = 0x100 + 5
    db   1,'Quit',0        ; ID = 0x100 + 6
    db   255               ; End of Menu Struct
    db   0,'HELP',0        ; ID = 0x100 + 7
    db   1,'Contents..',0  ; ID = 0x100 + 8
    db   1,'About..',0     ; ID = 0x100 + 9
    db   255               ; End of Menu Struct

textbox1:
    dq    0
    dq    30
    dq    155
    dq    234-25+30-ych+40+15
    dq    51
    dq    13
string_firmware_name:
    db    '/fd/1/d120.fw'
    times 50 db 0

textbox2:
    dq    0
    dq    30
    dq    155
    dq    283-25+30-ych+40+15
    dq    52
    dq    13
filestart:
    db    '/fd/1/mplayer'
    times 50 db 0


ipc_string:  db  'IPC',0

string_status_disconnected:  db  'Disconnected',0
string_status_connected:     db  'Connected',0
status_text_pointer:         dq   0x0

string_status_no_mplayer:    db  'Player not found',0
string_status_no_firmware:   db  'Firmware not found',0
string_status_identify:      db  'Identifying..',0
string_status_firmware:      db  'Firmware..',0
string_status_tuning:        db  'Tuning..',0
string_status_stopping:      db  'Stopping..',0
string_status_lock:          db  'Channel found',0
string_status_no_lock:       db  'Channel not found',0
string_status_clearing:      db  'Clearing buffer..',0
string_status_broadcast      db  'Receiving..',0
string_status_not_available: db  'Device in use, closing.',0
string_status_no_support:    db  'No P1A(S)/P1D support.',0


row0:  dq  0x2
row1:  dq  0x1
row2:  dq  0x1
row3:  dq  0x2
row4:  dq  0x1

lock_achieved:      dq  0x0
data_loaded:        dq  0x0
readsend:           dq  0x0
device_frequency:   dq  570
device_bandwidth:   dq  8
firmware_size:      dq  0x0
usb_control_result: dq  0x0
usb_bulk_result:    dq  0x0
pid:                dq  0x0
data15:             db  0x15,0

; bandwidth_config
; values from dib7070_bw_config_12_mhz

bwc.internal       dq  60000
bwc.sampling       dq  15000
bwc.pll_prediv     dq  1
bwc.pll_ratio      dq  20
bwc.pll_range      dq  3
bwc.pll_reset      dq  1
bwc.pll_bypass     dq  0
bwc.enable_refdiv  dq  0
bwc.bypclk_div     dq  0
bwc.IO_CLK_en_core dq  1
bwc.ADClkSrc       dq  1
bwc.modulo         dq  2
bwc.sad_cfg        dq  3 shl 14 + 1 shl 12 + 524
bwc.ifreq          dq  0
bwc.timf           dq  20452225
bwc.xtal_hz        dq  12000000

; dib7000p state

i2c_addr:           dq  0x0
state.wbd_ref:      dq  0x0
current_band:       dq  0x0
current_bandwidth:  dq  8000 ; khz
state.timf:         dq  0x0
div_force_off:      dq  0x1  ; set
div_state:          dq  0x1  ; set
div_sync_wait:      dq  0x0
agc_state:          dq  0x0
;gpio_dir:          dq  0x0
;gpio_val:          dq  0x0
sfn_workaround_active: dq 0x0

; dib7000p config

output_mpeg2_in_188_bytes: dq 0x0
hostbus_diversity:         dq 0x0
tuner_is_baseband:         dq 0x0
agc_config_count:          dq 0x0
gpio_dir:                  dq 0x0
gpio_val:                  dq 0x0
gpio_pwm_pos:              dq 0x0
pwm_freq_div:              dq 0x0
quartz_direct:             dq 0x0
spur_protect:              dq 0x0
output_mode:               dq 0x0

; dib0070_config

i2c_address:               dq 0x60
; tuner pins
; controlled externally
reset:                     dq 0x0
sleep:                     dq 0x0
; offset in khz
freq_offset_khz_uhf:       dq 0x0
freq_offset_khz_vhf:       dq 0x0
osc_buffer_state:          dq 0x0 ; 0=normal,1=tri-state
clock_khz:                 dq 12000
clock_pad_drive:           dq 0x0
invert_iq:                 dq 0x0 ; invert Q - in case I or Q is inverted
                                  ; on the board
force_crystal_mode:        dq 0x0 ; if == 0 -> decision is made in
                                  ; the driver default: <24 -> 2, >=24 -> 1
flip_chip:      dq 0x0
enable_third_order_filter: dq 0x0 ; not set for 7xxx
charge_pump:    dq 0x0
inversion:      dq INVERSION_AUTO ; set at get_frontend
                 ; INVERSION_OFF  ; set at dvb_register_frontend


dvb_frontend_parameters:

frequency:    dq 570000000 ; (absolute) frequency in Hz for
                           ; QAM/PFDM/ATSC (mtv3)
                           ; intermediate frequency in
                           ; KHz for QPSK

addr:  dq  0x0 ; 0x40

; ofdm parameters

ofdm.transmission_mode:      dq  TRANSMISSION_MODE_8K ;
ofdm.guard_interval:         dq  GUARD_INTERVAL_1_8   ;
ofdm.constellation:          dq  QAM_64               ;
ofdm.code_rate_LP:           dq  FEC_2_3              ;
ofdm.code_rate_HP:           dq  FEC_2_3              ;

ofdm.hierarchy_information:  dq  HIERARCHY_NONE       ; set at get_frontend

est0:   dq 0x0
est1:   dq 0x0
est2:   dq 0x0
est3:   dq 0x0

xtal:   dq 0x0
rf_khz: dq 0x0
bw_khz: dq 0x0
f_rel:  dq 0x0

pha:    dq 0x0
seq:    dq 0x0
testin: dq 0x0,0x0

buggy_sfn_workaround: dq 0x0

in_frequency: dq 0x0
in_bandwidth: dq 0x0

notch:

    dq    16143, 14402, 12238, 9713, 6902, 3888, 759, 2392

    ; actual values, including negative (not used)
    ;
    ; dq 16143, 14402, 12238, 9713, 6902, 3888, 759, -2392

sine:

    db    0, 2, 3, 5, 6, 8, 9, 11, 13, 14, 16, 17, 19, 20, 22
    db    24, 25, 27, 28, 30, 31, 33, 34, 36, 38, 39, 41, 42, 44, 45, 47, 48, 50, 51
    db    53, 55, 56, 58, 59, 61, 62, 64, 65, 67, 68, 70, 71, 73, 74, 76, 77, 79, 80
    db    82, 83, 85, 86, 88, 89, 91, 92, 94, 95, 97, 98, 99, 101, 102, 104, 105
    db    107, 108, 109, 111, 112, 114, 115, 117, 118, 119, 121, 122, 123, 125, 126
    db    128, 129, 130, 132, 133, 134, 136, 137, 138, 140, 141, 142, 144, 145, 146
    db    147, 149, 150, 151, 152, 154, 155, 156, 157, 159, 160, 161, 162, 164, 165
    db    166, 167, 168, 170, 171, 172, 173, 174, 175, 177, 178, 179, 180, 181, 182
    db    183, 184, 185, 186, 188, 189, 190, 191, 192, 193, 194, 195, 196, 197, 198
    db    199, 200, 201, 202, 203, 204, 205, 206, 207, 207, 208, 209, 210, 211, 212
    db    213, 214, 215, 215, 216, 217, 218, 219, 220, 220, 221, 222, 223, 224, 224
    db    225, 226, 227, 227, 228, 229, 229, 230, 231, 231, 232, 233, 233, 234, 235
    db    235, 236, 237, 237, 238, 238, 239, 239, 240, 241, 241, 242, 242, 243, 243
    db    244, 244, 245, 245, 245, 246, 246, 247, 247, 248, 248, 248, 249, 249, 249
    db    250, 250, 250, 251, 251, 251, 252, 252, 252, 252, 253, 253, 253, 253, 254
    db    254, 254, 254, 254, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255
    db    255, 255, 255, 255, 255, 255

base_reg: dq 0x0

bus_mode:  dq  0x0  ; 0=eeprom,1=frontend bus
gen_mode:  dq  0x0  ; 0=master i2c,1=gpio i2c
en_start:  dq  0x0
en_stop:   dq  0x0

firmware_loaded:  dq  0x0

revision:       dq  0x0
wbd_offs:       dq  0x0
wbd_ff_offset:  dq  0x0
tun_i2c:        dq  0x0
cold:           dq  0x0

agc:            dq  0x0 ; pointer to agc configuration
current_agc:    dq  0x0 ; - " -

agc_split:      dq  0x0

;; DIB7070 generic

dib7070_agc_config:

agc.band_caps:     dw    BAND_UHF + BAND_VHF + BAND_LBAND + BAND_SBAND

;;  P_agc_use_sd_mod1=0, P_agc_use_sd_mod2=0, P_agc_freq_pwm_div=5, P_agc_inv_pwm1=0, P_agc_inv_pwm2=0,
;;  P_agc_inh_dc_rv_est=0, P_agc_time_est=3, P_agc_freeze=0, P_agc_nb_est=5, P_agc_write=0 */

;;  setup

agc.setup:  dq (0 shl 15)+(0 shl 14)+(5 shl 11)+(0 shl 10)+(0 shl 9)+(0 shl 8)+(3 shl 5)+(0 shl 4)+(5 shl 1)+(0 shl 0)

agc.inv_gain       dq    600  ;; inv_gain
agc.time_stabiliz  dq    10   ;; time_stabiliz

agc.alpha_level  dq    0      ;; alpha_level
agc.thlock       dq    118    ;; thlock

agc.wbd_inv      dq    0      ;; wbd_inv
agc.wbd_ref      dq    3530   ;; wbd_ref
agc.wbd_sel      dq    1      ;; wbd_sel
agc.wbd_alpha    dq    5      ;; wbd_alpha

agc.agc1_max     dq    65535  ;; agc1_max
agc.agc1_min     dq        0  ;; agc1_min

agc.agc2_max     dq    65535  ;; agc2_max
agc.agc2_min     dq    0      ;; agc2_min

agc.agc1_pt1     dq    0      ;; agc1_pt1
agc.agc1_pt2     dq    40     ;; agc1_pt2
agc.agc1_pt3     dq    183    ;; agc1_pt3
agc.agc1_slope1  dq    206    ;; agc1_slope1
agc.agc1_slope2  dq    255    ;; agc1_slope2
agc.agc2_pt1     dq    72     ;; agc2_pt1
agc.agc2_pt2     dq    152    ;; agc2_pt2
agc.agc2_slope1  dq    88     ;; agc2_slope1
agc.agc2_slope2  dq    90     ;; agc2_slope2

agc.alpha_mant    dq    17    ;; alpha_mant
agc.alpha_exp     dq    27    ;; alpha_exp
agc.beta_mant     dq    23    ;; beta_mant
agc.beta_exp      dq    51    ;; beta_exp

agc.perform_agc_softsplit:  dq  0

dib0070_p1f_defaults:

     dw    7, 0x02
     dw            0x0008
     dw            0x0000
     dw            0x0000
     dw            0x0000
     dw            0x0000
     dw            0x0002
     dw            0x0100

     dw    3, 0x0d
     dw            0x0d80
     dw            0x0001
     dw            0x0000

     dw    4, 0x11
     dw            0x0000
     dw            0x0103
     dw            0x0000
     dw            0x0000

     dw    3, 0x16
     dw            0x0004 + 0x0040
     dw            0x0030
     dw            0x07ff

     dw    6, 0x1b
     dw            0x4112
     dw            0xff00
     dw            0xc07f
     dw            0x0000
     dw            0x0180
     dw            0x4000+0x0800+0x0040+0x0020+0x0010+0x0008+0x0002+0x0001

     dw    0

dib0070_p1f_defaults_end:


dib7000p_defaults:

    ;; auto search configuration

    dw    3, 2
    dw            0x0004
    dw            0x1000
    dw            0x0814 ;; Equal Lock

    dw    12, 6
    dw            0x001b
    dw            0x7740
    dw            0x005b
    dw            0x8d80
    dw            0x01c9
    dw            0xc380
    dw            0x0000
    dw            0x0080
    dw            0x0000
    dw            0x0090
    dw            0x0001
    dw            0xd4c0

    dw    1, 26
    dw            0x6680 ;; P_timf_alpha=6, P_corm_alpha=6, P_corm_thres=128 default: 6,4,26

    ;; set ADC level to -16 */

    dw    11, 79
    dw            (1 shl 13) - 825 - 117
    dw            (1 shl 13) - 837 - 117
    dw            (1 shl 13) - 811 - 117
    dw            (1 shl 13) - 766 - 117
    dw            (1 shl 13) - 737 - 117
    dw            (1 shl 13) - 693 - 117
    dw            (1 shl 13) - 648 - 117
    dw            (1 shl 13) - 619 - 117
    dw            (1 shl 13) - 575 - 117
    dw            (1 shl 13) - 531 - 117
    dw            (1 shl 13) - 501 - 117

    dw    1, 142
    dw            0x0410 ;; P_palf_filter_on=1, P_palf_filter_freeze=0, P_palf_alpha_regul=16

    ;; disable power smoothing

    dw    8, 145
    dw            0
    dw            0
    dw            0
    dw            0
    dw            0
    dw            0
    dw            0
    dw            0

    dw    1, 154
    dw            1 shl 13 ;; P_fft_freq_dir=1, P_fft_nb_to_cut=0

    dw    1, 168
    dw            0x0ccd ;; P_pha3_thres, default 0x3000

    ;;    1, 169
    ;;            0x0010 ;; P_cti_use_cpe=0, P_cti_use_prog=0, P_cti_win_len=16, default: 0x0010

    dw    1, 183
    dw            0x200f ;; P_cspu_regul=512, P_cspu_win_cut=15, default: 0x2005

    dw    5, 187
    dw            0x023d ;; P_adp_regul_cnt=573, default: 410
    dw            0x00a4 ;; P_adp_noise_cnt=
    dw            0x00a4 ;; P_adp_regul_ext
    dw            0x7ff0 ;; P_adp_noise_ext
    dw            0x3ccc ;; P_adp_fil

    dw    1, 198
    dw            0x800 ;; P_equal_thres_wgn

    dw    1, 222
    dw            0x0010 ;; P_fec_ber_rs_len=2

    dw    1, 235
    dw            0x0062 ;; P_smo_mode, P_smo_rs_discard, P_smo_fifo_flush, P_smo_pid_parse, P_smo_error_discard

    dw    2, 901
    dw            0x0006 ;; P_clk_cfg1
    dw            (3 shl 10) + (1 shl 6) ;; P_divclksel=3 P_divbitsel=1

    dw    1, 905
    dw            0x2c8e ;; Tuner IO bank: max drive (14mA) + divout pads max drive

    dw    0

dib7000p_defaults_end:


decc:            dq  0x0
prev_print:      dq  0x0

outreg:          dq  0x0
fifo_threshold:  dq  0x0
smo_mode:        dq  0x0

reg_774:  dq  0x0
reg_775:  dq  0x0
reg_776:  dq  0x0
reg_899:  dq  0x0
reg_1280: dq  0x0

reg_908:  dq  0x0
reg_909:  dq  0x0

reading:  dq  0x0
sr15:     dq  0x0

readbuffer:  dq 0x100000
master_xfer: dq 0x0
powered:     dq 0x0
adap.state:  dq 0x0
state:       dq 0x0

adap_id: dq 0 ; only one adapter
adap_pid_filtering:  dq 0x0
adap_max_feed_count: dq 0x0

demux.start_feed: dq 0x0
demux.stop_feed:  dq 0x0

wbd_offset_3_3: dq 0x0,0x0 ;

help_text: dq 0x0
lastset:   dq 0x0



dib0070_tuning_table: ; frequency limited (310 - 845)

    dq    250000 , 1, 0, 6, 12, 2, 1, 0x8000 + 0x1000
    dq    569999 , 2, 1, 5,  6, 2, 2, 0x4000 + 0x0800
    dq    699999 , 2, 0, 1,  4, 2, 2, 0x4000 + 0x0800
    dq    863999 , 2, 1, 1,  4, 2, 2, 0x4000 + 0x0800

dib0070s_tuning_table:

    dq    570000 , 2, 1, 3,  6, 6, 2, 0x4000 + 0x0800
    dq    700000 , 2, 0, 2,  4, 2, 2, 0x4000 + 0x0800
    dq    863999 , 2, 1, 2,  4, 2, 2, 0x4000 + 0x0800


dib0070_lna:

    dq    250000 , 3
    dq    550000 , 2
    dq    650000 , 3
    dq    750000 , 5
    dq    850000 , 6
    dq    864000 , 7

;dib0070_lna_flip_chip:
;
;    dq    250000 , 3
;    dq    550000 , 0
;    dq    590000 , 1
;    dq    666000 , 3
;    dq    864000 , 5




current_tune_table_index: dq 0x0
lna_match: dq 0x0

lo4:     dq 0x0
p1900:   dq 100

string_info_1: db 'TV/Radio control application.',0
string_info_2: db "Press 'H' for details.",0


string_help:

    db    'Supported dvb-t tuners:                ',0
    db    '                                       ',0
    db    'Artec T14BR DVB-T                      ',0
    db    'Elgato EyeTV DTT                       ',0
    db    'Hauppauge Nova-T Stick                 ',0
    db    'Pinnacle PCTV 72e                      ',0
    db    '                                       ',0
    db    'Same chipsets as above,                ',0
    db    'not tested:                            ',0
    db    '                                       ',0
    db    'ASUS MyCinema U3100 Mini               ',0
    db    'Elgato EyeTV Dtt Dlx PD378S            ',0
    db    'Hauppauge Nova-T MyTV.t                ',0
    db    'Pinnacle PCTV 73e                      ',0
    db    'Pinnacle PCTV DVB-T Fl.St.             ',0
    db    'Yuan PD378S                            ',0
    db    '                                       ',0
    db    'Firmware:                              ',0
    db    'DiBcom firmware v1.10/1.20             ',0
    db    '                                       ',0
    db    'Player:                                ',0
    db    'Media player 0.30 or above             ',0
    db    '                                       ',0
    db    'Player is started after                ',0
    db    'the tuner finds a channel.             ',0
    db    '                                       ',0
    db    'More device details at:                ',0
    db    'www.menuetos.net/hwc.txt               ',0
    db    '                                       ',0
    db    'x'




;
; Uninitialized data
;

datau_start:

buf:      times 256 db ?
buf_ret:  times 256 db ?

gpio_buf: times  20  db ?
wwmsg:    times  20  db ?
rwmsg:    times  20  db ?
drg1:     times  20  db ?
drg2:     times  20  db ?
dwg1:     times  20  db ?
coef_re:  times 10 dq ?
coef_im:  times 10 dq ?

coef_re_sign: times 10 dq ?
coef_im_sign: times 10 dq ?

gbuf: times 20 db ?
xbuf: times 20 db ?

data_streaming_control:  times  20  db ?
data_set_clock:          times  30  db ?
data_start_firmware:     times  10  db ?
data_rc_read:            times  10  db ?
data_enable_rc:          times  10  db ?
get_version_data_return: times  32  db ?

hex_line:                times 300   db ?
data_ep_read:            times 40000 db ?

datau_end:

image_end:

