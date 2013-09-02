;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   64 bit Menuet Calendar
;
;   Compile with FASM 1.60 or above
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use64

    org   0x0

    db    'MENUET64'              ; Header identifier
    dq    0x01                    ; Version
    dq    START                   ; Start of code
    dq    image_end               ; Size of image
    dq    0x800000                ; Memory for app
    dq    0x1fff0                 ; Rsp
    dq    0x00                    ; Prm
    dq    0x00                    ; Icon

include 'textbox.inc'

xs equ 24
ys equ 16

cellstep equ 40
cellbase equ 0x20000

START:

    ; System font

    mov   rax , 141
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    call  load_file

    call  set_current_date_time

    call  draw_window       ; At first, draw the window

still:

    mov   rax , 23          ; Wait here for event
    mov   rbx , 1
    int   0x60

    test  rax , 0x1         ; Window redraw
    jnz   window_event
    test  rax , 0x2         ; Keyboard press
    jnz   key_event
    test  rax , 0x4         ; Button press
    jnz   button_event

    call  check_mouse

    jmp   still

window_event:

    call  draw_window
    jmp   still

key_event:

    mov   rax , 0x2        ; Read the key and ignore
    int   0x60

    jmp   still

button_event:

    mov   rax , 0x11
    int   0x60

    ; rax = status
    ; rbx = button id

    cmp   rbx , 0x10000001
    jne   no_application_terminate_button
    call  savefile
    mov   rax , 512
    int   0x60
  no_application_terminate_button:

    cmp   rbx , 0x102
    jne   no_application_terminate_menu
    call  savefile
    mov   rax , 512
    int   0x60
  no_application_terminate_menu:

    cmp   rbx , 1000
    jb    noscroll
    cmp   rbx , 1000+100
    ja    noscroll
    mov   [scroll_value],rbx
    call  draw_scroll
    call  display_times
    jmp   still
  noscroll:

    cmp   rbx , 2000
    jb    noscroll2
    cmp   rbx , 2999
    ja    noscroll2
    mov   [scroll_value_month],rbx
    call  draw_scroll_month
    call  display_date
    call  display_times
    jmp   still
  noscroll2:

    cmp   rbx , 5
    jne   noprevday
    cmp   [current_date],dword 1
    jne   noprevmonth
    cmp   [scroll_value_month],dword 2000
    jbe   still
    dec   qword [current_date]
    dec   qword [scroll_value_month]
    call  display_date
    mov   rax , [days_in_month]
    mov   [current_date],rax
    call  display_date
    call  draw_scroll_month
    call  display_times
    jmp   still
  noprevmonth:
    dec   qword [current_date]
    call  display_date
    call  display_times
    jmp   still
  noprevday:

    cmp   rbx , 6
    jne   nonextday
    mov   rax , [current_date]
    cmp   rax , [days_in_month]
    jb    nonextmonth
    cmp   [scroll_value_month],dword 2000+12*20-1 ; year 2025
    jae   still
    mov   [current_date],dword 1
    inc   qword [scroll_value_month]
    call  display_date
    call  draw_scroll_month
    call  display_times
    jmp   still
  nonextmonth:
    inc   qword [current_date]
    call  display_date
    call  display_times
    jmp   still
  nonextday:

    cmp   rbx , 50
    jb    notext
    cmp   rbx , 70
    ja    notext
    mov   r10 , rbx
    mov   [textbox1+4*8],rbx
    sub   rbx , 50
    imul  rbx , ys
    add   rbx , 50
    mov   [textbox1+3*8],rbx
    sub   r10 , 50
    call  load_value_from_table
    mov   [textbox1+5*8],r10
    push  r11
    mov   r14 , textbox1
    call  read_textbox
    pop   rdi
    mov   rsi , textbox1+6*8
    mov   rcx , 38
    cld
    rep   movsb

    call  savefile

    jmp   still
  notext:

    jmp   still


savefile:

    push  qword [scroll_value]
    push  qword [scroll_value_month]
    push  qword [current_date]

    mov   rdi , loaded_file+2
    mov   rax , 2000  ; month/year
    mov   rbx , 1     ; date
    mov   rcx , 1     ; time

  newload:

    mov   [scroll_value_month],rax
    mov   [current_date],rbx
    mov   [scroll_value],dword 1000
    mov   r10 , rcx

    push  rdi
    push  rax rbx rcx
    call  load_value_from_table
    pop   rcx rbx rax
    pop   rdi

    cmp   r10 , 0
    je    novaluefound

    push  rax rbx rcx

    inc   rbx
    inc   rcx

    mov   [rdi],rax
    mov   [rdi+4],bl
    mov   [rdi+5],cl

    add   rdi , 6

    push  rdi rcx
    mov   rsi , textbox1+6*8
    mov   rcx , r10
    cld
    rep   movsb
    pop   rcx rdi

    add   rdi , r10
    mov  [rdi], byte 0
    inc   rdi

    ;push  rax rbx
    ;mov   rax , 5
    ;mov   rbx , 100
    ;int   0x60
    ;pop   rbx rax

    pop   rcx rbx rax

  novaluefound:
    inc   rcx
    cmp   rcx , 24
    jbe   newload
    mov   rcx , 1
    inc   rbx
    cmp   rbx , 31
    jbe   newload
    mov   rbx , 1
    inc   rax
    cmp   rax , 2000 + 12*20
    jb    newload

    sub   rdi , loaded_file
    mov   [filesize],rdi

    ; Delete

    mov   rax , 58
    mov   rbx , 2
    mov   r9  , filename
    int   0x60

    ; Save

    mov   rax , 58
    mov   rbx , 1
    mov   rdx , [filesize]
    and   rdx , 0xffff
    mov   r8  , loaded_file
    mov   r9  , filename
    int   0x60

    pop   qword [current_date]
    pop   qword [scroll_value_month]
    pop   qword [scroll_value]

    call  load_value_from_table

    ret



load_file:

    mov   rax , 58
    mov   rbx , 0
    mov   rcx , 0
    mov   rdx , 0xfff
    mov   r8  , loaded_file
    mov   r9  , filename
    int   0x60

    mov   [filesize],rbx

    cmp   rbx , 2
    jbe   lfl1

    mov   rsi , loaded_file+2
    sub   rbx , 2

  newcell:

    movzx rax , byte [rsi+4+1] ; Time
    dec   rax
    imul  rax , cellstep
    movzx rbx , byte [rsi+4]   ; Date
    dec   rbx
    imul  rbx , 24*cellstep
    mov   ecx , [rsi]          ; Month/year
    sub   ecx , 2000
    imul  rcx , 32*24*cellstep
    add   rcx , rbx
    add   rcx , rax
    mov   rdi , rcx
    add   rdi , cellbase
    add   rsi , 6
  newcellmove:
    mov   al  , [rsi]
    mov   [rdi],al
    inc   rsi
    inc   rdi
    cmp   al , 0
    jne   newcellmove

    mov   rax , rsi
    sub   rax , loaded_file
    cmp   rax , [filesize]
    jb    newcell

  lfl1:

    ret


gridx equ 23
gridy equ 90
yc    equ 12


check_mouse:

    mov   rax , 37
    mov   rbx , 2
    int   0x60

    cmp   rax , 0
    je    cml1

    mov   rax , 37
    mov   rbx , 1
    int   0x60

    mov   rbx , rax
    shr   rax , 32
    and   rbx , 0xffffff

    sub   rax , gridx
    sub   rbx , gridy

    cmp   rax , xs*7-2
    ja    cml1
    cmp   rbx , ys*6-2
    ja    cml1

    xor   rdx , rdx
    mov   rcx , xs
    div   rcx

    push  rax
    mov   rax , rbx
    xor   rdx , rdx
    mov   rcx , ys
    div   rcx
    mov   rbx , rax
    pop   rax

    imul  rbx , 7
    add   rax , rbx

    inc   rax

    cmp   rax , [start_day_of_week]
    jbe   cml1

    sub   rax , [start_day_of_week]

    cmp   [current_date],rax
    je    cml0

    cmp   rax , [days_in_month]
    ja    cml0

    mov   [current_date],rax
    call  display_month_dates

    call  display_times

  cml0:

    mov   rax , 5
    mov   rbx , 2
    int   0x60

  cml1:

    ret


draw_window:

    mov   rax , 0xC                          ; Beginning of window draw
    mov   rbx , 0x1
    int   0x60

    mov   rax , 0x0                          ; Draw window
    mov   rbx , 0x0000005000000000+500       ; x start & size
    mov   rcx , 0x0000005000000000+68 +ys*yc      ; rt & size
    mov   rdx , 0x0000000000FFFFFF           ; type    & border color
    mov   r8  , 0x0000000000000001           ; draw flags
    mov   r9  , window_label                 ; 0 or label - asciiz
    mov   r10 , menu_struct                  ; 0 or pointer to menu struct
    int   0x60

    call  draw_date_grid
    call  draw_time_grid

    jmp   overdate


draw_date_grid:

    ; Date

    ;mov   rax , 13
    ;mov   rbx , gridx shl 32 + xs*7+1
    ;mov   rcx , gridy shl 32 + ys*6+1
    ;mov   rdx , 0xffffff
    ;int   0x60

    mov   rax , 38
    mov   rbx , gridx
    mov   rcx , gridy
    mov   rdx , gridx + xs*7
    mov   r8  , gridy
    mov   r9  , 0x000000
    mov   r10 , 7
  ngx:
    int   0x60
    add   rcx , ys
    add   r8  , ys
    dec   r10
    jnz   ngx

    mov   rax , 38
    mov   rbx , gridx
    mov   rcx , gridy
    mov   rdx , gridx
    mov   r8  , gridy + ys*6
    mov   r9  , 0x000000
    mov   r10 , 8
  ngy:
    int   0x60
    add   rbx , xs
    add   rdx , xs
    dec   r10
    jnz   ngy

    ret

draw_time_grid:

    ; Time

    mov   rax , 38
    mov   rbx , 210
    mov   rcx , 50
    mov   rdx , 210
    mov   r8  , 50+ys*yc
    mov   r9  , 0x000000
    int   0x60

    mov   rax , 38
    mov   rbx , 210
    mov   rcx , 50
    mov   rdx , 482-22
    mov   r8  , 50
    mov   r9  , 0x000000
    mov   r10 , yc+1
  newline2:
    int   0x60
    add   rcx , ys
    add   r8  , ys
    dec   r10
    jnz   newline2

    ret

  overdate:

    call  draw_scroll_month

    call  display_date

    call  display_times
    call  draw_scroll

    mov   rax , 8
    mov   rbx , (gridx-1) shl 32 + 85
    mov   rcx , 196 shl 32 + 16
    mov   rdx , 5
    mov   r8  , 0
    mov   r9  , button_text_1
    int   0x60
    mov   r9  , button_text_2
    mov   rbx , (gridx+84) shl 32 + 85
    inc   rdx
    int   0x60

    mov   rax , 0xc
    mov   rbx , 2
    int   0x60

    ret


get_days_in_month:

    ; in r14 = scroll_value_month or equal value ( 2000+ )
    ; out r15 = days in month

    push  rax rbx rdx

    mov   rax , r14
    sub   rax , 2000
    mov   rbx , 12
    xor   rdx , rdx
    div   rbx
    movzx r15 , byte [days+rdx]

    ; year / 4 -> 29 days in month

    cmp   r15 , 28
    jne   nofebruary

    mov   rax , r14
    sub   rax , 2000
    mov   rbx , 12
    xor   rdx , rdx
    div   rbx
    add   rax , 2    ; 2008,2012,2016,..
    xor   rdx , rdx
    mov   rbx , 4
    div   rbx
    cmp   rdx , 0
    jne   nodivfour
    mov   r15 , 29
  nodivfour:
  nofebruary:

    pop   rdx rbx rax

    ret


get_start_day:

    ; In rax = scroll_value_month or similar value ( 2000+ )

    ; out r10 = start day of week

    mov   r11 , 6 ; year 2006 starts from sunday
    cmp   rax , 2000
    je    gsdl1

    mov   r9  , 2000

  gsdl0:

    mov   r14 , r9
    call  get_days_in_month

    add   r11 , r15

    push  rax
    mov   rax , r11
    mov   rbx , 7
    xor   rdx , rdx
    div   rbx
    mov   r11 , rdx
    pop   rax

    inc   r9
    cmp   r9  , rax
    jb    gsdl0

  gsdl1:

    mov   r10 , r11

    ;mov   r10 , 1

    ret


set_current_date_time:

    ; Month and Date

    mov   rax , 3
    mov   rbx , 2
    int   0x60
    mov   rbx , rax
    and   rbx , 0xff
    sub   rbx , 6
    imul  rbx , 12
    add   rbx , 2000
    mov   rcx , rax
    shr   rcx , 8
    and   rcx , 0xff
    add   rbx , rcx
    dec   rbx
    mov   [scroll_value_month],rbx
    mov   rbx , rax
    shr   rbx , 16
    and   rbx , 0xff
    mov   [current_date],rbx

    ; Set Time

    mov   rax , 3
    mov   rbx , 1
    int   0x60
    and   rax , 0xff
    cmp   rax , 5
    ja    over5
    mov   rax , 5
  over5:
    sub   rax , 5
    cmp   rax , 12
    jbe   raxfine
    mov   rax , 12
  raxfine:
    add   rax , 1000
    mov   [scroll_value],rax

    ret


display_date:

    mov   rax , 13
    mov   rbx,gridx shl 32+ xs*7+1
    mov   rcx , 50 shl 32 + 17
    mov   rdx , 0xdedede
    int   0x60

    mov   rax , [scroll_value_month]
    sub   rax , 2000
    mov   rbx , 12
    xor   rdx , rdx
    div   rbx
    mov   rsi , rdx
    add   rax , 6
    xor   rdx , rdx
    mov   rbx , 10
    div   rbx
    add   rax , 48
    add   rdx , 48
    mov   [text+8],dl
    mov   [text+7],al

    imul  rsi , 10
    add   rsi , months
    mov   rdi , text+12
    mov   rcx , 10
    cld
    rep   movsb

    mov   rax , 0x4                          ; Display text
    mov   rbx , text
    mov   rcx , gridx+7
    mov   rdx , 55
    mov   rsi , 0x0
    mov   r9  , 0x1
    mov   r10 , 2
  ddl1:
    int   0x60
    add   rbx , 31
    add   rdx , 22
    dec   r10
    jnz   ddl1

    call  display_month_dates

    ret


display_month_dates:

    call  draw_date_grid

    mov   rax , [scroll_value_month]
    call  get_start_day
    ; r10 = start day of week

    mov   [start_day_of_week],r10

    mov   r14 , [scroll_value_month]
    call  get_days_in_month
    mov   r11 , r15; days in month

    mov   [days_in_month],r15

    mov   rax , [current_date]
    cmp   rax , r15
    jbe   current_date_fine
    mov   [current_date],r15
  current_date_fine:

    mov   r12 , 1  ; day counter

    mov   r14 , 0  ; grid position

  newday:

    mov   rax , r12
    mov   rbx , 10
    xor   rdx , rdx
    div   rbx
    add   rax , 48
    add   rdx , 48
    mov   [twodigits],al
    mov   [twodigits+1],dl

    mov   rax , r14
    xor   rdx , rdx
    mov   rbx , 7
    div   rbx

    cmp   rax , 6
    jae   nonewday

    mov   rcx , rdx
    mov   rdx , rax
    imul  rcx , xs
    add   rcx , gridx+2
    imul  rdx , ys
    add   rdx , gridy+2
    mov   r9  , 1
    mov   rsi , 0x000000
    ;cmp   r12 , [current_date]
    ;jne   no_current_date2
    ;mov   rsi , 0xffffff
    ;no_current_date2:

    mov   rax , 4
    mov   rbx , twodigits

    push  rax rbx rcx rdx
    mov   rax , 13
    mov   rbx , rcx
    mov   rcx , rdx
    shl   rbx , 32
    shl   rcx , 32
    add   rbx , xs-3
    add   rcx , ys-3
    mov   rdx , 0xffffff
    cmp   r14 , [start_day_of_week]
    jb    no_current_date
    cmp   r12 , [current_date]
    jne   no_current_date
    mov   rdx , 0xdedede
    ;mov   rsi , 0xffffff
    ;mov   rdx , 0x4070c0
    mov   edx , 0xc0d0e0
    mov   edx , 0xd6d6d6
  no_current_date:
    int   0x60
    pop   rdx rcx rbx rax
    add   rcx , 5
    add   rdx , 3

    cmp   r14 , [start_day_of_week]
    jb    nodaydisplay
    cmp   r12 , [days_in_month]
    ja    nodaydisplay
    int   0x60
  nodaydisplay:

    cmp   r14 , [start_day_of_week]
    jb    nodayinc
    inc   r12
  nodayinc:
    inc   r14
    jmp   newday

    ;cmp   r12 , r11
    ;jbe   newday

  nonewday:

    ret


display_times:

    mov   rax , 4
    mov   rbx , timestring
    mov   rcx , 218
    mov   rdx , 55
    mov   rsi , 0x000000
    mov   r9  , 1
    mov   r10 , 0

  newtime:

    push  rax rbx rdx
    mov   rax , r10
    add   rax , [scroll_value]
    sub   rax , 1000
    inc   rax ;
    xor   rdx , rdx
    mov   rbx , 10
    div   rbx
    add   rax , 48
    add   rdx , 48
    mov   [timestring],al
    mov   [timestring+1],dl
    pop   rdx rbx rax

    push  rax rbx rcx rdx
    mov   rax , 13
    mov   rbx , rcx
    mov   rcx , rdx
    dec   rcx
    shl   rbx , 32
    shl   rcx , 32
    add   rbx , 5*6
    add   rcx , 10+2
    mov   rdx , 0xffffff
    int   0x60
    pop   rdx rcx rbx rax

    int   0x60

    push  rax rbx rcx rdx r8 r9 r10
    mov   [textbox1+5*8],dword 0
    mov   [textbox1+6*8],dword 0
    ; Load value from table
    push  r10
    ;add   r10 , [scroll_value]
    ;sub   r10 , 1000
    call  load_value_from_table
    pop   r10
    jmp   over_load

  load_value_from_table:
    ; In : r10 = time (1+)
    ; Out: r10 = length : r11 = start position in table
    mov   rax , [scroll_value]
    sub   rax , 1000
    add   rax , r10 ; Time
    imul  rax , cellstep
    mov   rbx , [scroll_value_month] ; Month/year
    sub   rbx , 2000
    imul  rbx , cellstep*24*32
    mov   rcx , [current_date]
    imul  rcx , cellstep*24
    mov   rsi , rcx
    add   rsi , rbx
    add   rsi , rax
    add   rsi , cellbase
    mov   r11 , rsi
    mov   rdi , textbox1+6*8
    mov   rcx , 38
    cld
    rep   movsb
    mov   r10 , 0
    mov   rsi ,  textbox1+6*8
  newlengthsearch:
    cmp   [rsi],byte 0
    je    foundlength
    inc   rsi
    inc   r10
    jmp   newlengthsearch
  foundlength:
    ret

    ;

  over_load:
    mov   [textbox1+4*8],r10
    add   qword [textbox1+4*8],50
    imul  r10 , ys
    add   r10 , 50
    mov   [textbox1+3*8],r10
    mov   r14 , textbox1
    call  draw_textbox
    pop   r10 r9 r8 rdx rcx rbx rax

    add   rdx , ys

    inc   r10
    cmp   r10 , yc
    jb    newtime

    ret

draw_scroll:

    mov   rax , 113
    mov   rbx , 1
    mov   rcx , 1000
    mov   rdx , (24-yc)+1
    mov   r8  , [scroll_value]
    mov   r9  , 470
    mov   r10 , 50
    mov   r11 , ys*yc
    int   0x60

    ret


draw_scroll_month:

    mov   rax , 113
    mov   rbx , 2
    mov   rcx , 2000
    mov   rdx , xs * 10 ; *3
    mov   r8  , [scroll_value_month]
    mov   r9  , 222
    mov   r10 , gridx
    mov   r11 , xs * 7
    int   0x60

    ret

; Data area

window_label:

    db    'CALENDAR',0    ; Window label

text:

    db    '     2006 - December          ',0
    db    'Mo  Tu  We  Th  Fr  Sa  Su    ',0

months:

    db    'January   February  March     April     May       June      '
    db    'July      August    September October   November  December  '

timestring:

    db    '00:00',0

current_date:

    dq    0x1

scroll_value_month:  dq  2000
scroll_value:        dq  1007
twodigits:           db  '00',0
start_day_of_week:   dq  0x0
days_in_month:       dq  0x0

button_text_1:  db  'Previous',0
button_text_2:  db  'Next',0

filename:  db  '/fd/1/calr.dat',0

days:  db  31,28,31,30,31,30,31,31,30,31,30,31

menu_struct:               ; Menu Struct

    dq   0                 ; Version

    dq   0x100             ; Start value of ID to return ( ID + Line )

                           ; Returned when menu closes and
                           ; user made no selections.

    db   0,'FILE',0        ; ID = 0x100 + 1
    db   1,'Quit',0        ; ID = 0x100 + 2

    db   255               ; End of Menu Struct

textbox1:

    dq   0
    dq   254
    dq   6*36-3
    dq   50
    dq   11
    dq   0
    times 50 db 0

filesize: dq image_end - loaded_file

loaded_file:

    ;db   'CA'
    ;dd   2000 + 10  ; year+month
    ;db   26         ; day
    ;db   12         ; time
    ;db   'Hammaslaakari'
    ;db   0

image_end:

