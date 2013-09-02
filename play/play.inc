;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Wave player
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

frsize  equ  64
icolor  equ  0xd0d0d0
asize   equ  (4*512*frsize)
eqy     equ  328

main:

    ; Init spa

    call  spa_process_init

    ; Default audio wave for spa

    call  reset_spa_wave

    ; System font

    mov   rax , 141
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    ; Define Drag n Drop

    mov   rax , 121
    mov   rbx , 1
    mov   rcx , dragndrop
    mov   rdx , 100
    int   0x60

    ; Define IPC memory

    mov   rax , 60           ; ipc
    mov   rbx , 1            ; define memory area
    mov   rcx , ipc_memory   ; memory area pointer
    mov   rdx , 100          ; size of area
    int   0x60

    call  draw_window       ; At first, draw the window

    call  copy_eq

still:

    mov   rsp , stacktop-16

    call  check_mouse_eq

    mov   rax , 23          ; Wait here for event
    mov   rbx , 1
    int   0x60

    test  rax , 0x1         ; Window redraw
    jnz   window_event
    test  rax , 0x2         ; Keyboard press
    jnz   key_event
    test  rax , 0x4         ; Button press
    jnz   button_event

    call  check_ipc
    call  check_dragndrop
    call  check_mouse

    jmp   still


check_mouse:

    mov   rax , 37
    mov   rbx , 2
    int   0x60

    cmp   rax , 0
    je    nomousedown

    mov   rax , 37
    mov   rbx , 1
    int   0x60

    mov   rbx , rax
    shr   rax , 32
    and   rbx , 0xffffff

    cmp   rax , 22
    jb    nomousedown
    cmp   rax , 206
    ja    nomousedown
    cmp   rbx , 153
    jb    nomousedown
    cmp   rbx , 246
    ja    nomousedown

    sub   rbx , 153
    mov   rax , rbx
    xor   rdx , rdx
    mov   rbx , 12
    div   rbx
    add   rax , [sc2]
    sub   rax , 2000

    cmp   rax , [playlistpointer]
    je    nomousedown

    mov   [playlistpointer],rax

    call  draw_playlist

    mov   [readblock],dword 0
    mov   [sc],dword 1000
    call  draw_scroll
    call  update_playinfo

    mov   rax , 5
    mov   rbx , 1
    int   0x60

  nomousedown:

    ret


reset_spa_wave:

    push  rax rcx rdi

    mov   rdi , dispblock
    mov   rcx , 16000*2
    mov   rax , 0
    cld
    rep   stosb

    mov   rdi , dispblock
    mov   rax , 0
  newdbinit:
    mov   [rdi],ax
    mov   [rdi+2],ax
    add   rax , 8
    add   rdi , 4
    cmp   rdi , dispblock+16000
    jb    newdbinit

    mov   [spa_type],byte 1

    pop   rdi rcx rax

    ret



check_mouse_eq:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Playlist and equalizer
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; EQ visible ?

    cmp   [vist+12],dword 'Yes '
    jne   noeqmouse

    ; Window active ?

    mov   rax , 111
    mov   rbx , 2
    int   0x60
    cmp   rax , 0
    jne   no_window_active

    ; Mouse buttons

    mov   rax , 37
    mov   rbx , 2
    int   0x60

    cmp   rax , 0
    je    nomousedowneq

    mov   rax , 37
    mov   rbx , 1
    int   0x60

    mov   rbx , rax
    shr   rax , 32
    and   rbx , 0xffffff

    cmp   [prevmx],rax
    jne   continuemouse

    cmp   [prevmy],rbx
    jne   continuemouse

  no_window_active:
  nomousedowneq:
  noeqmouse:

    ret

  continuemouse:

    mov   [prevmx],rax
    mov   [prevmy],rbx

    cmp   rax , 22+3
    jb    nomousedown_eq
    cmp   rax , 22+3 + 6*32
    ja    nomousedown_eq
    cmp   rbx , eqy-7
    jb    nomousedown_eq
    cmp   rbx , eqy+44+9
    ja    nomousedown_eq

    sub   rbx , 2

    cmp   rbx , eqy
    jae   conteq1
    mov   rbx , eqy
  conteq1:
    cmp   rbx , eqy+44
    jbe   conteq2
    mov   rbx , eqy+44
  conteq2:

    sub   rbx , eqy
    mov   ecx , ebx

    sub   rax , 22+3
    mov   rbx , 6
    xor   rdx , rdx
    div   rbx
    cmp   rax , 31
    jbe   eqxfine
    mov   rax , 31
  eqxfine:

    mov   [eq_values+rax*4],ecx

    call  copy_eq

    call  draw_eq_area

    ret

  nomousedown_eq:

    ret




copy_eq:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Copy EQ parameters to gaintable
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; Convert to player values

    mov   rsi , eq_values
    mov   rdi , gaintable

  neweqt:

    mov   ebx , 0x00000000
    mov   eax , [rsi]
    cmp   eax , 44
    je    zerovalue
    mov   rbx , 48
    sub   rbx , rax
    add   rbx , 100
    shl   rbx , 20-1
    add   ebx , 0x3b800000
  zerovalue:

    mov   [rdi],ebx

    add   rsi , 4
    add   rdi , 4

    cmp   rsi , eq_values + 32*4
    jb    neweqt

    ret





draw_eq_area:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Draws EQ area and values
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    push  rax rbx rcx rdx rsi r9 r10

    cmp   [vist+12],dword 'Yes '
    jne   novisibleeq

    ; Area

    mov   rax , 38
    mov   rbx , 20
    mov   rcx , eqy-2
    mov   rdx , 220
    mov   r8  , eqy+49
    mov   r9  , 0x000000
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
    mov   r8 , rcx
    int   0x60
    pop   r8

    ; Values

    mov   rsi , eq_values
    mov   rbx , (22+3) shl 32 + 5

  neweqdraw:

    mov   rax , 13

    mov   ecx , [rsi]

    mov   rdx , 48
    sub   rdx , rcx
    mov   rcx , rdx

    mov   rax , eqy+48
    sub   rax , rcx
    mov   rcx , rax
    shl   rcx , 32
    add   rcx , rdx

    ; white

    push  rax rbx rcx rdx
    mov   rcx , 48
    sub   rcx , rdx
    mov   rdx , rcx
    mov   rcx , (eqy) shl 32
    add   rcx , rdx
    mov   rax , 13
    mov   rbx , rbx
    mov   rdx , 0xf2f2f2
    int   0x60
    pop   rdx rcx rbx rax

    ; control

    mov   rax , 13
    mov   cx , 4
    mov   rdx , 0x787878
    int   0x60
    push  rbx rcx
    mov   rax , 1 shl 32 -2
    add   rbx , rax
    add   rcx , rax
    mov   rax , 13
    mov   rdx , 0xffffff
    int   0x60
    pop   rcx rbx

    ; white

    push  rax rbx rcx rdx
    mov   rdx , 4 shl 32
    add   rcx , rdx
    mov   rax , rcx
    shr   rax , 32
    mov   rdx , eqy + 48
    sub   rdx , rax
    mov   cx , dx
    mov   rax , 13
    mov   rdx , 0xf2f2f2
    int   0x60
    pop   rdx rcx rbx rax

    mov   r10 , 6 shl 32
    add   rbx , r10

    add   rsi , 4
    cmp   rsi , eq_values+4*32
    jb    neweqdraw

  novisibleeq:

    pop   r10 r9 rsi rdx rcx rbx rax

    ret



add_to_playlist:

    push  rcx rsi rdi

    cmp   [entriesinplaylist],dword 20
    jae   atpl1

    mov   rsi , [entriesinplaylist]
    imul  rsi , 128
    add   rsi , playlist
    mov   rdi , rsi
    add   rdi , 128
    add   rsi , 10*128
    add   rdi , 10*128
;   std
;   rep   movsb

    mov   rdi , [entriesinplaylist]
    imul  rdi , 128
    add   rdi , playlist
    mov   rsi , wavname
    mov   rcx , 127
    cld
    rep   movsb

    inc   qword [entriesinplaylist]

  atpl1:

    cmp   [drawall],byte 1
    jne   nodrw
    call  draw_window
    jmp   drdone
  nodrw:
    call  draw_playlist
  drdone:

    pop   rdi rsi rcx

    ret


check_dragndrop:

    cmp   [dragndrop], byte 0
    je    nodnd

    mov   rsi , dragndrop
    mov   rdi , wavname
    mov   rcx , 200
    cld
    rep   movsb
    mov   [dragndrop], byte 0

    call  check_file
    cmp   [filehz],word 0
    je    nodnd

    mov   [drawall],byte 0
    call  add_to_playlist

  nodnd:

    ret


check_ipc:

    cmp   [name], byte 0
    je    noipc
    mov   rsi , name
    mov   rdi , wavname
    mov   rcx , 200
    cld
    rep   movsb

    mov   [name], byte 0
    mov   [ipc_memory+8],dword 16

    call  check_file
    cmp   [filehz],word 0
    je    noipc

    mov   [drawall],byte 1
    call  add_to_playlist

  noipc:

    ret


check_output_device:

    ; Device available

    mov   rax , 117
    mov   rbx , 1
    int   0x60
    cmp   rax , 0
    jne   not_supported_output

    ; Output format

    mov   rax , 117
    mov   rbx , 7
    mov   rcx , 0
    int   0x60

    mov   rdx , 0xffffffffff shl 24
    mov   rcx , rbx
    and   rcx , rdx
    mov   rdx , 0x4000010210 shl 24
    cmp   rcx , rdx ; buffer 16384 : sign extended lsb : 2 channel : 16bit/ch
    jne   not_supported_output

    mov  [cardhz],bx
    call  draw_info
    ret

  not_supported_output:

    mov  [cardhz],dword 0
    call  draw_info
    ret


window_event:

    call  draw_window

    jmp   still

key_event:

    call  read_key

    jmp   still

read_key:

    mov   rax , 0x2        ; Read the key and ignore
    int   0x60

    cmp   cl , '1'
    jne   nokey1
    mov   [spa_type_sel],byte 0
  nokey1:
    cmp   cl , '2'
    jne   nokey2
    mov   [spa_type_sel],byte 1
  nokey2:
    cmp   [spst+12],word 'On'
    jne   nosettype
    mov   bl , [spa_type_sel]
    mov   [spa_type],bl
  nosettype:

    ret

spa_type_sel: dq 0x0

check_file:

    mov   [readblock],dword 0
    mov   [blockstoread],dword 1
    mov   [readtarget],dword wave

    mov   [wave],dword 0

    call  readfile

    mov   eax , [wave]
    cmp   eax , 'RIFF'
    jne   notsupported

    mov   al, [wave+32] ; Bytes per sample
    cmp   al, 4
    jne   notsupported

    mov   al, [wave+22] ; Channels
    cmp   al, 2
    jne   notsupported
    mov   bx, [wave+24] ; Hz

    mov   [filehz],bx

    call  update_filelength
    call  draw_location
    call  draw_scroll
    call  draw_info

    ret

notsupported:

    mov   rax , 5
    mov   rbx , 50
    int   0x60

    call  draw_window

    mov   rax , 13
    mov   rbx , 20 * 0x100000000 + 200
    mov   rcx , 50 * 0x100000000 +  40
    mov   rdx , 0x000000
    int   0x60

    mov   rax , 4
    mov   rbx , notsupportedtext
    mov   rcx , 33
    mov   rdx , 65
    mov   r9  , 1
    mov   rsi , 0xffffff
    int   0x60

    mov   rax , 5
    mov   rbx , 300
    int   0x60

    mov   [filelength],dword 0
    mov   [filehz],dword 0

    call  draw_info
    call  draw_location
    call  draw_scroll

    ret


notsupportedtext:

    db    'Not a 16 bit stereo WAV file.',0


playsong:

    mov   [buffer0start],dword 0
    mov   [buffer0last],dword 0

    mov   rdi , buffer0
    mov   rcx , 4*512*frsize
    mov   rax , 0
    cld
    rep   stosb
    mov   rdi , buffer1
    mov   rcx , 4*512*frsize
    mov   rax , 0
    cld
    rep   stosb
    mov   rdi , wave
    mov   rcx , 0xf0000-8
    mov   rax , 0
    cld
    rep   stosb
    mov   rdi , cblock
    mov   rcx , 0x10000-8
    mov   rax , 0
    cld
    rep   stosb

    call  get_song

    call  check_file
    cmp   [filehz],dword 0
    je    playsongret

    call  check_output_device

    cmp   [filehz],dword 0
    je    playsongret
    cmp   [cardhz],dword 0
    je    playsongret

    mov   rax , [sc]
    sub   rax , 1000
    imul  rax , [filehz]  ; * 44100 * 4 / 512
    imul  rax , 4
    shr   rax , 9
    inc   rax
    mov   [readblock],rax
    mov   [blockstoread],dword frsize
    mov   [readtarget],dword wave
    call  readfile
    add   [readblock],dword frsize
    add   [readtarget],dword frsize*512
    call  readfile
    add   [readblock],dword frsize
    add   [readtarget],dword frsize*512

    mov   r15 , wave

    mov   rdx , 0
    call  calculate_block

    mov   rdx , 1
    call  calculate_block

    mov   rax , 117
    mov   rbx , 3
    int   0x60

  waitmore1:
    call  delay
    call  getindex
    cmp   rbx , 0
    je    waitmore1

    mov   rdx , 0
    call  calculate_block

  waitmore2:
    call  delay
    call  getindex
    cmp   rbx , 1
    je    waitmore2

    mov   rdx , 1
    call  calculate_block

    mov   rax , [filesize]
    shr   rax , 9
    cmp   eax , [readblock]
    jb    stop_end

    mov   rax , 11
    int   0x60
    test  rax , 4
    jnz   stop
    cmp   [dragndrop], byte 0
    jne   stop
    test  rax , 2
    jz    noreadkey
    call  read_key
  noreadkey:

    jmp   waitmore1

  stop_end:

    mov   [sc],dword 1000
    call  draw_info
    call  draw_scroll

  stop:

    ; Stop play

    mov   rax , 117
    mov   rbx , 5
    int   0x60

    ; Free device

    mov   rax , 117
    mov   rbx , 255
    int   0x60

    mov   rax , 11
    int   0x60
    cmp   rax , 0
    jne   playsongret

    ; Get next song

    mov   rax , 5
    mov   rbx , 100
    int   0x60

    jmp   playsong

  playsongret:

    dec   qword [playlistpointer]

    call  draw_playlist

    ret

get_song:

    push  rcx rsi rdi

    mov   rax , [entriesinplaylist]
    cmp   [playlistpointer],rax
    jb    noabove
    mov   [playlistpointer],dword 0
  noabove:

    mov   rsi , [playlistpointer]
    imul  rsi , 128
    add   rsi , playlist
    mov   rdi , wavname
    mov   rcx , 110
    cld
    rep   movsb

    mov   rax , [playlistpointer]
    add   rax , 2000
    sub   rax , 8
    cmp   rax , [sc2]
    jb    gsl1
    inc   rax
    mov   [sc2],rax
    call  draw_scroll_playlist
  gsl1:

    mov   rax , [playlistpointer]
    add   rax , 2000
    cmp   rax , [sc2]
    jae   gsl2
    mov   [sc2],rax
    call  draw_scroll_playlist
  gsl2:

    call  draw_playlist

    inc   qword [playlistpointer]

    pop   rdi rsi rcx

    ret


draw_scroll_playlist:

    mov   rax , 113
    mov   rbx , 1
    mov   rcx , 2000
    mov   rdx , 20-7
    mov   r8  , [sc2]
    mov   r9  , 208
    mov   r10 , 151
    mov   r11 , 96
    int   0x60

    ret



draw_playlist:

    push  rax rbx rcx rdx rsi r9 r10

    mov   rax , 38
    mov   rbx , 20
    mov   rcx , 150
    mov   rdx , 220
    mov   r8  , 248
    mov   r9  , 0x000000
  ; push  rbx
  ; mov   rbx , rdx
  ; int   0x60
  ; pop   rbx
    push  rdx
    mov   rdx , rbx
    int   0x60
    pop   rdx
    push  rcx
    mov   rcx , r8
    int   0x60
    pop   rcx
    push  r8
    mov   r8 , rcx
    int   0x60
    pop   r8

    mov   rax , 4
    mov   rbx , [sc2]
    sub   rbx , 2000
    imul  rbx , 128
    add   rbx , playlist
    mov   rcx , 24
    mov   rdx , 154
    mov   rsi , 0x000000
    mov   r9  , 1
    mov   r10 , 0
  dpl1:
    push  rax rbx rcx rdx
    mov   rax , 13
    mov   rbx , rcx
    mov   rcx , rdx
    dec   rbx
    shl   rbx , 32
    sub   rcx , 2
    shl   rcx , 32
    add   rbx , 6*30+3
    add   rcx , 11
    mov   rdx , 0xffffff
    mov   rax , [sc2]
    sub   rax , 2000
    add   rax , r10
    cmp   rax , [playlistpointer]
    jne   nocurrentselected
    mov   rdx , 0xe0e0e0
  nocurrentselected:
    mov   rax , 13
    int   0x60
    pop   rdx rcx rbx rax
    push  qword [rbx+30]
    mov   [rbx+30],byte 0
    int   0x60
    pop   qword [rbx+30]
    inc   r10
    add   rdx , 12
    add   rbx , 128
    cmp   rdx , 12*8+154
    jb    dpl1

    pop   r10 r9 rsi rdx rcx rbx rax

    ret



calculate_block:

    push  rdx

    cmp   [spst+12],dword 'Off '
    je    nodisplayspectrum
    cmp   [vist+12],dword 'Yes '
    jne   nodisplayspectrum
    call  display_spectrum
  nodisplayspectrum:

    mov   rdi , cblock
    mov   rcx , 0

  newbyte:

    mov   rax , rcx
    imul  rax , [filehz]
    imul  rax , 4
    xor   rdx , rdx
    mov   r8  , [cardhz]
    div   r8
    and   rax , 0xfffffc
    add   rax , r15
    mov   r12 , rax   ; position

    mov   rax , rcx
    imul  rax , [filehz]
    xor   rdx , rdx
    mov   r8  , [cardhz]
    div   r8
    mov   r10 , rdx   ; save remainer

    ; Convert right channel

    mov   rax , [r12]
    mov   rbx , [r12+4]
    add   rax , 32768
    add   rbx , 32768
    and   rax , 0xffff
    and   rbx , 0xffff
    cmp   rbx , rax
    jb    nosub
    sub   rbx , rax
    mov   rax , rbx
    imul  rax , r10
    xor   rdx , rdx
    div   qword [cardhz]
    movzx rbx , word [r12]
    add   rax , rbx
    mov   [rdi],ax
    jmp   transf_done
  nosub:
    sub   rax , rbx
    imul  rax , r10
    xor   rdx , rdx
    div   qword  [cardhz]
    movzx rbx , word [r12]
    sub   rbx , rax
    mov   [rdi],bx
  transf_done:

    ; Convert left channel

    mov   rax , [r12+2]
    mov   rbx , [r12+6]
    add   rax , 32768
    add   rbx , 32768
    and   rax , 0xffff
    and   rbx , 0xffff
    cmp   rbx , rax
    jb    nosub2
    sub   rbx , rax
    mov   rax , rbx
    imul  rax , r10
    xor   rdx , rdx
    div   qword [cardhz]
    movzx rbx , word [r12+2]
    add   rax , rbx
    mov   [rdi+2],ax
    jmp   transf_done2
  nosub2:
    sub   rax , rbx
    imul  rax , r10
    xor   rdx , rdx
    div   qword [cardhz]
    movzx rbx , word [r12+2]
    sub   rbx , rax
    mov   [rdi+2],bx
  transf_done2:

    add   rdi , 4
    inc   rcx
    cmp   rcx , 4096
    jbe   newbyte      ; equal to advance to beginning of next block move

    mov   r15 , r12

    ;

    mov   rax , 117
    mov   rbx , 2
    mov   rcx , cblock
    pop   rdx
    int   0x60

    ; Check buffer

  check_buffer:

    mov   rax , wave
    add   rax , 512*frsize
    cmp   rax , r15
    ja    bufferfine

    mov   [blockstoread],dword frsize
    call  readfile
    add   qword [readblock],frsize

    mov   rsi , r15
    mov   rdi , rsi
    sub   rdi , 512*frsize
    mov   rcx , 0x80000
    cld
    rep   movsb

    sub   r15 , 512*frsize

    jmp   check_buffer

  bufferfine:

    ret


update_playinfo:

    mov   rax , [readblock]
    mov   rbx , [filehz]    ; 44100 * 4 / 512
    cmp   rbx , 0
    je    noupdate
    imul  rbx , 4
    shr   rbx , 9
    xor   rdx , rdx
    div   rbx
    add   rax , 1000
    cmp   rax , [sc]
    je    noupdate
    mov   [sc], rax
    call  draw_scroll
    call  draw_location
  noupdate:

    ret

delay:

    mov   rax , 11
    int   0x60
    cmp   rax , 1
    jne   delayl1
    dec   qword [playlistpointer]
    call  draw_window
    inc   qword [playlistpointer]
  delayl1:

    call  update_playinfo

    call  check_mouse_eq

    mov   rax , 105
    mov   rbx , 1
    int   0x60

    ret

getindex:

    mov   rax , 117
    mov   rbx , 4
    int   0x60

    ret

readfile:

    cmp   [eqst+12],dword 'On  '
    jne   noapplyeq

    cmp   [readblock],dword 1
    ja    readfrombuffer

  noapplyeq:

    mov   rax , 58
    mov   rbx , 0
    mov   rcx , [readblock]
    mov   rdx , [blockstoread]
    mov   r8  , [readtarget]
    mov   r9  , wavname
    int   0x60

    mov   [filesize],rbx

    ret

  readfrombuffer:

    mov   rax , [readblock]
    sub   rax , [buffer0start]
    cmp   rax , frsize*4
    jb    buffercopyfine
    mov   rax , 0
  buffercopyfine:
    imul  rax , 512
    mov   rsi , rax
    add   rsi , buffer0
    mov   rdi , [readtarget]
    mov   rcx , [blockstoread]
    imul  rcx , 512
    cld
    rep   movsb

    mov   rax , [readblock]
    cmp   rax , [buffer0last]
    jb    nochb

    mov   rsi , buffer1
    mov   rdi , buffer0
    mov   rcx , frsize*512*4
    cld
    rep   movsb

    call  start_buffer1_read

    mov   rax , [readblock]
    add   rax , frsize
    mov   [buffer0start],rax
    mov   rbx , 3*frsize
    add   rax , rbx
    mov   [buffer0last],rax

  nochb:

    ret



start_buffer1_read:

    cmp   [readinprogress],byte 1
    jne   doread
    mov   rax , 5
    mov   rbx , 1
    int   0x60
    jmp   start_buffer1_read
  doread:

    mov   rax , [readblock]
    add   rax , frsize
    mov   [stabl],rax

    mov   [readinprogress],byte 1

    mov   rax , 51
    mov   rbx , 1
    mov   rcx , readbuf
    mov   rdx , readbufstack
    int   0x60

    ret



readbuf:

    mov   rax , 58
    mov   rbx , 0
    mov   rcx , [stabl]
    mov   rdx , frsize*4
    mov   r8  , buffer1
    mov   r9  , wavname
    int   0x60

    mov   r15 , buffer1
    call  apply_equalizer

    mov   [readinprogress],byte 0

    mov   rax , 512
    int   0x60




update_filelength:

    mov   rax , [filesize]
    mov   rbx , [filehz]  ; 44100 * 4
    imul  rbx , 4
    xor   rdx , rdx
    div   rbx
    mov   [filelength],rax

    ret



button_event:

    mov   rax , 0x11
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

    cmp   rbx , 0x103
    jne   nokeys
    mov   rax , 13
    mov   rbx , 21 shl 32 + 187
    mov   rcx , 151 shl 32 + 97
    mov   rdx , 0xfafafa
    int   0x60
    mov   rax , 4
    mov   rbx , string_keys
    mov   rcx , 21 + 5
    mov   rdx , 151 + 5
    mov   rsi , 0x000000
    mov   r9  , 1
    int   0x60
    mov   rax , 10
    int   0x60
    mov   rax , 13
    mov   rbx , 21 shl 32 + 187
    mov   rcx , 151 shl 32 + 97
    mov   rdx , 0xffffff
    int   0x60
    call  draw_playlist
    jmp   still
  string_keys: db 'Keys 1/2 - Spectrum type',0
  nokeys:

    cmp   rbx , 0x105+2
    jne   nospm
    mov   eax , 'Off '
    mov   [spa_type],byte 1
    cmp   [spst+12],dword 'Off '
    jne   sptoslow
    mov   [spa_type],byte 0
    mov   eax , 'On  '
  sptoslow:
    mov   [spst+12],eax

    cmp   eax , 'Off '
    jne   noresetspa
    call  reset_spa_wave
    push  r15
    mov   r15 , 0
    call  display_spectrum
    pop   r15
  noresetspa:

    jmp   still
  nospm:

    cmp   rbx , 0x105+3
    jne   noeqm
    mov   eax , 'Off '
    cmp   [eqst+12],dword 'On  '
    je    eqtooff
    mov   eax , 'On  '
  eqtooff:
    mov   [eqst+12],eax
    jmp   still
  noeqm:

    cmp   rbx , 0x105+4
    jne   novim
    mov   eax , 'No  '
    cmp   [vist+12],dword 'Yes '
    je    vitooff
    mov   eax , 'Yes '
  vitooff:
    mov   [vist+12],eax

    mov   rbx , -1
    mov   rcx , -1
    mov   rdx , -1
    mov   r8  , 337+60
    cmp   eax , 'Yes '
    je    visible
    mov   r8  , 267
  visible:

    mov   rax , 67
    int   0x60

    jmp   still
  novim:

    cmp   rbx , 1000
    jb    no_scroll
    cmp   rbx , 1999
    ja    no_scroll
    mov   [sc],rbx
    call  draw_scroll
    call  draw_location
    jmp   still
  no_scroll:

    cmp   rbx , 2000
    jb    no_scroll2
    cmp   rbx , 2000+200
    ja    no_scroll2
    mov   [sc2],rbx
    call  draw_scroll_playlist
    call  draw_playlist
    jmp   still
  no_scroll2:

    cmp   rbx , 1
    jne   no_play
    call  playsong
    jmp   still
  no_play:

    cmp   rbx , 0x102
    je    yesfileload
    cmp   rbx , 3
    je    yesfileload
    jmp   no_file_load
  yesfileload:

    ; Get my PID

    mov   rax , 111
    mov   rbx , 1
    int   0x60

    mov   rdi , parameter + 6
  newdec:
    mov   rbx , 10
    xor   rdx , rdx
    div   rbx
    add   rdx , 48
    mov  [rdi], dl
    dec   rdi
    cmp   rdi , parameter + 1
    jg    newdec

    ; Start fbrowser

    mov   rax , 256
    mov   rbx , file_search
    mov   rcx , parameter
    int   0x60

    jmp   still

  no_file_load:

    jmp   still


draw_location:

    mov   rax , 13
    mov   rbx ,120 * 0x100000000 + 100
    mov   rcx , 50 * 0x100000000 + 40
    mov   rdx , 0x000000
    int   0x60

    ; Seconds

    mov   rax , [sc]
    sub   rax , 1000
    inc   rax
    xor   rdx , rdx
    mov   rbx , 10
    div   rbx
    push  rax
    mov   r8  , rdx
    mov   r13 , 140+25
    mov   r14 , 65
    call  cdnumber
    pop   rax
    xor   rdx , rdx
    mov   rbx , 10
    div   rbx
    mov   r8  , rax
    mov   r13 , 116+25
    mov   r14 , 65
    push  rdx
    call  cdnumber
    pop   r8
    mov   r13 , 128+25
    mov   r14 , 65
    call  cdnumber

    ret

cdnumber:

    shl   r13 , 32
    shl   r14 , 32

    imul  r8  , 7
    add   r8  , lines
    mov   r9  , coord
    mov   r10 , 7
  newline2:
    cmp  [r8], byte 1
    jne   nonewline
    mov   rax , 13
    mov   rbx , [r9]
    mov   rcx , [r9+8]
    mov   rdx , 0xffffff
    add   rbx , r13
    add   rcx , r14
    int   0x60
  nonewline:
    inc   r8
    add   r9 , 16
    dec   r10
    jnz   newline2

    ret



draw_window:

    mov   rax , 0xC                          ; Beginning of window draw
    mov   rbx , 0x1
    int   0x60

    mov   rax , 0x0                          ; Draw window
    mov   rbx , 0x0000010800000000 + 240     ; x start &amp; size
    mov   rcx , 0x0000004000000000 + 337+60  ; y start &amp; size
    mov   rdx , 0x0000000000FFFFFF           ; type    &amp; border color
    mov   r8  , 0x0000000000000001           ; draw flags
    mov   r9  , window_label                 ; 0 or label - asciiz
    mov   r10 , menu_struct                  ; 0 or pointer to menu struct
    int   0x60

    mov   rax , 8
    mov   rbx , 20 * 0x100000000 + 67
    mov   rcx , 120* 0x100000000 + 20
    push  rax rbx
    mov   rax , 141
    mov   rbx , 3
    int   0x60
    cmp   ax , 10
    jbe   yfine
    inc   rcx
  yfine:
    pop   rbx rax
    mov   rdx , 1
    mov   r8  , 0
    mov   r9  , button1
    int   0x60

    mov   rax , 8
    mov   rbx , 87 * 0x100000000 + 67
    mov   rdx , 2
    mov   r8  , 0
    mov   r9  , button2
    int   0x60

    mov   rax , 8
    mov   rbx , 154* 0x100000000 + 67
    mov   rdx , 3
    mov   r8  , 0
    mov   r9  , button3
    int   0x60

    call  draw_playlist
    call  draw_scroll_playlist

    call  draw_scroll
    call  draw_location
    call  draw_info

    cmp   [vist+12],dword 'Yes '
    jne   nodisplayspectrummw
    push  r15
    mov   r15 , 0
    call  display_spectrum
    pop   r15
  nodisplayspectrummw:

    call  draw_eq_area

    mov   rax , 12
    mov   rbx , 3
    int   0x60

    cmp   [drawall],byte 0
    je    noredrawcheck
    cmp   eax , 2000
    ja    noredrawcheck
    ; Window was drawn only partially, new try
    mov   rax , 5
    mov   rbx , 1
    int   0x60
    jmp   draw_window
  noredrawcheck:
    mov   [drawall],byte 0

    ret




draw_info:

    mov   rax , 13
    mov   rbx , 20 * 0x100000000 + 100
    mov   rcx , 50 * 0x100000000 +  40
    mov   rdx , 0x000000
    int   0x60

    mov   rax , 4
    mov   rbx , text
    mov   rcx , 42
    mov   rdx , 61
    mov   r9  , 1
    mov   rsi , icolor
    int   0x60
    add   rbx , 6
    mov   rdx , 72
    int   0x60

    mov   rax , 47
    mov   rbx , 5*65536
    mov   rcx , [filehz]
    mov   rdx , 82*65536+61
    mov   rsi , icolor
    mov   rdi , 0
    int   0x40

    mov   rax , 47
    mov   rbx , 5*65536
    mov   rcx , [cardhz]
    mov   rdx , 82*65536+72
    mov   rsi , icolor
    mov   rdi , 0
    int   0x40

    ret


draw_scroll:

    mov   rax , 113
    mov   rbx , 2
    mov   rcx , 1000
    mov   rdx , [filelength]
    mov   r8  , [sc]
    mov   r9  , 100
    mov   r10 , 20
    mov   r11 , 200
    int   0x60

    ret


; Data area

window_label:  db  'WAVE PLAYER',0
button1:       db  'PLAY',0
button2:       db  'STOP',0
button3:       db  'FILE',0

sc:          dq  1000
filelength:  dq  0x0
filehz:      dq  0x0
cardhz:      dq  0x0

text:  db  'File:',0,'Card:',0

menu_struct:               ; Menu Struct

    dq   0                 ; Version
    dq   0x100             ; Start value of ID to return ( ID + Line )
                           ; Returned when menu closes and
                           ; user made no selections.
    db   0,'FILE',0        ; ID = 0x100 + 1
    db   1,'Open..',0
    db   1,'Keys..',0
    db   1,'-',0
    db   1,'Quit',0        ; ID = 0x100 + 2

        db   0,'SETUP',0
spst:   db   1,'Spectrum:  Off      ',0
eqst:   db   1,'Equalizer: Off      ',0

    db   255               ; End of Menu Struct

vist:   db   1,'Visible:   Yes  ',0

drawall: dq 0x0

lines:  db  1,1,1,0,1,1,1
        db  0,0,1,0,0,1,0
        db  1,0,1,1,1,0,1
        db  1,0,1,1,0,1,1
        db  0,1,1,1,0,1,0
        db  1,1,0,1,0,1,1
        db  1,1,0,1,1,1,1
        db  1,0,1,0,0,1,0
        db  1,1,1,1,1,1,1
        db  1,1,1,1,0,1,1

coord:  dq  1  * 0x100000000 + 8
        dq  0  * 0x100000000 + 1
        dq  0  * 0x100000000 + 1
        dq  1  * 0x100000000 + 4
        dq  9  * 0x100000000 + 1
        dq  1  * 0x100000000 + 4
        dq  1  * 0x100000000 + 8
        dq  5  * 0x100000000 + 1
        dq  0  * 0x100000000 + 1
        dq  6  * 0x100000000 + 4
        dq  9  * 0x100000000 + 1
        dq  6  * 0x100000000 + 4
        dq  1  * 0x100000000 + 8
        dq  10 * 0x100000000 + 1

readblock:     dq 0x1
blockstoread:  dq 0x1
readtarget:    dq wave
filesize:      dq 0x0

stabl:              dq  0x0
readinprogress:     dq  0x0
playlistpointer:    dq  0x0
sc2:                dq  2000
entriesinplaylist:  dq  0x0
buffer0start:       dq  0x0
buffer0last: dq 3*frsize

prevmx: dq 0x0
prevmy: dq 0x0

eq_values: times 40 dd 15 ; 0-44

file_search: db '/FD/1/FBROWSER   ',0
parameter:   db '[000000]',0

ipc_memory:

    dq  0x0    ; lock - 0=unlocked , 1=locked
    dq  16     ; first free position from ipc_memory

    ; received IPC messages
  name:
    times 256 db 0

