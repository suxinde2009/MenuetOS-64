;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   CPU usage for Menuet
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;1218 bytes original  => 956
; BUGS:
; #0 - only accurate to 2%
; #1 - TSC per second is for BSP only
; #2 - idle TSC per second is for BSP only
HISTORY_LEN = 200

; format binary as ""

use64

    db    'MENUET64'  ; Header identifier
    dq    0x01        ; Version
    dq    START       ; Start of code
    dq    IMG_END     ; Size of image
    dq    0x100000    ; Memory for app
    dq    0x100000    ; Rsp
    dq    0x00        ; Prm
    dq    0x00        ; Icon

START:

    mov   rax , 141
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    mov   rax , 140
    mov   rbx , 2
    int   0x60
    mov   [cpus],ebx

    mov   eax,100
    imul  ecx,[cpus],HISTORY_LEN
    mov   edi,cpu_usage
    rep   stosb

    call  read_cpu_usage
    call  drawwindow

    mov   ecx,100

still:

    mov   eax,11
    int   60h

    test  eax,1 ; Window redraw
    jnz   redraw
    test  eax,2 ; Keyboard press
    jnz   keypress
    test  eax,4 ; Button press
    jnz   buttonpress

    mov   eax,5
    movzx ebx,byte [speed]
    int   60h

    dec   ecx
    jnz   still

    call  read_cpu_usage
    call  draw_usage

    mov   ecx,100

    jmp   still

redraw:

    call  drawwindow

    jmp   still

keypress:

    push  rcx
    mov   eax,0x2
    int   60h
    pop   rcx

    jmp   still

buttonpress:

    push  rcx
    mov   eax,17
    int   60h
    pop   rcx

    ; rax = status
    ; rbx = button id

    cmp   ebx,0x10000001
    jne   L005
    mov   eax,0x200
    int   60h
  L005:

    mov   eax,speed
    cmp   ebx,0x102
    jne   @f
    mov   [upd1+1],byte '>'
    mov   [upd2+1],byte ' '
    mov   [upd3+1],byte ' '
    mov   byte[rax],1
  @@:
    cmp   ebx,0x103
    jne   @f
    mov   [upd1+1],byte ' '
    mov   [upd2+1],byte '>'
    mov   [upd3+1],byte ' '
    mov   byte[rax],2
  @@:
    cmp   ebx,0x104
    jne   @f
    mov   [upd1+1],byte ' '
    mov   [upd2+1],byte ' '
    mov   [upd3+1],byte '>'
    mov   byte[rax],4
  @@:

    cmp   ebx,0x106
    jne   @f
    mov   [prs1+1],byte '>'
    mov   [prs2+1],byte ' '
  @@:
    cmp   ebx,0x107
    jne   @f
    mov   [prs1+1],byte ' '
    mov   [prs2+1],byte '>'
  @@:

    cmp   ebx,0x109
    jne   @f
    mov   [tbr1+1],byte '>'
    mov   [tbr2+1],byte ' '
  @@:
    cmp   ebx,0x10a
    jne   @f
    mov   [tbr1+1],byte ' '
    mov   [tbr2+1],byte '>'
  @@:

    cmp   ebx,0x100
    jb    no_menu_selection
    cmp   ebx,0x110
    jg    no_menu_selection
    push  rcx
    call  draw_usage
    pop   rcx
    jmp   still
  no_menu_selection:

    jmp   still

drawwindow:

    push  rcx

    mov   eax,12
    mov   ebx,1
    int   60h

    xor   eax,eax
    mov   rbx, 11Dh shl 32 + HISTORY_LEN+10
    mov   ecx , [cpus]
    cmp   ecx , 3
    jb    noincwidth
    cmp   ecx , 4
    jbe   cpumaxfine
    mov   ecx , 4
  cpumaxfine:
    sub   rcx , 2
    imul  rcx , (HISTORY_LEN/2)
    add   bx , cx
  noincwidth:

    mov   rcx, 18h shl 32 +  92h
    mov   edx,0FFFFFFh
    mov   r8d,1
    mov   r9d,title
    mov   r10d,menu_struct
    int   60h

    mov   eax,111
    mov   ebx,1
    int   60h

    mov   ecx,eax
    mov   eax,9
    mov   ebx,2
    mov   edx,process_p
    mov   r8d,32
    int   60h
    sub   [process_p+16],10

    xor   edx,edx
    mov   ebx,[cpus]
    mov   eax,dword[process_p+16]
    div   ebx
    cmp   eax,HISTORY_LEN
    jc  @f
    mov   eax,HISTORY_LEN
  @@:
    mov   [width_cpu],eax

    call  draw_usage

    mov   eax,12
    mov   ebx,2
    int   60h

    pop   rcx
    ret


read_cpu_usage:

    cld
    imul  ecx,[cpus],HISTORY_LEN
    sub   ecx,1
    mov   esi,cpu_usage+1
    mov   edi,cpu_usage
    rep   movsb

    mov   eax,26; return system info
    mov   ebx,1 ;
    mov   ecx,sys_info; - where to return
    mov   edx,256; - bytes to return
    int   60h

    ; TSC/second/100
    ; BUG#1:

    mov   rax ,[sys_info+184] ; @184: TSC per second
    xor   edx,edx
    mov   ebx,100
    div   rbx
    mov   r15,rax

    ; idle TSC/second
    ; BUG#2:

    mov   rax ,[sys_info+168]
    xor   edx,edx
    div   r15 ;idle/TSC_per_sec

    mov   ecx,1
    imul  ebx,ecx,HISTORY_LEN
    mov   [cpu_usage+ebx-2],al
    mov   [cpu_usage+ebx-1],byte 100

    cmp   byte [cpus],byte 1
    jbe   counted

    mov   ecx, 2
  tsc:
    mov   eax,9
    mov   ebx,1
    mov   edx,prc_info
    mov   r8d,728
    int   60h

    xor   edx,edx
    mov   rax,[prc_info+720]
    mov   rbx,rax
    div   r15
    cmp   al,100
    jc  @f
    mov   al,100
  @@:
    imul  ebx,ecx,HISTORY_LEN
    mov   [cpu_usage+ebx-2],al
    mov   [cpu_usage+ebx-1],byte 100

    add   ecx , 1
    cmp   ecx , [cpus]
    jbe   tsc

  counted:

    ret


draw_usage:

    xor   r13,r13
  cpu_n:
    mov   ebx,r13d
    imul  ebx,[width_cpu]
    add   ebx,5
    add   r13,1

    push  rbx
    mov   eax,38
    mov   ebx,r13d
    imul  ebx,[width_cpu]
    add   ebx,5
    mov   edx,ebx
    mov   ecx,38  ;Y1
    mov   r8d,139 ;Y2
    mov   r9d,0CCCCCCh

    cmp   r13d , [cpus]
    je    novertical
    int   60h     ;Vertical line
  novertical:

    imul  r11d,r13d,HISTORY_LEN
    add   r11,cpu_usage
    lea   r12,[r11-1] ;cache graph end
    cmp   [tbr2+1],byte '>'
    jne   @f
    dec   r12
  @@:
    sub   r11d,[width_cpu] ;r11=cpu_usage+HISTORY_LEN*CPU#-w_cpu
    pop   rbx

    inc   r11
    inc   rbx

    ; Clear first vertical line

    push  rdx
    mov   rdx , rbx
    call  clear_to_white
    pop   rdx

    ; Place (x) to display prosentage

    mov   rbp , r11
    add   rbp , 20

    lea   edx,[rbx+1]
  newline:
    mov   ecx,39 ;Y1
    mov   r8d,ecx
    movzx r10, byte [r11]
    add   rcx,r10
    movzx r10, byte [r11+1]
    add   r8,r10
    xor   r9,r9
    push  rdx
    cmp   [tbr1+1],byte '>'
    jne   nobar
    dec   rdx
    mov   r8d, 139
  nobar:
    ; Clear vertical line
    push  rbx
    mov   rbx , rdx
    call  clear_to_white
    pop   rbx
    ;
    int   60h  ; draw one graph tick
    pop   rdx

    cmp   r11, rbp
    je    draw_prosentage
   return_prosentage:

    add   r11,1
    add   ebx,1
    add   edx,1
    cmp   r11,r12 ; read to the end of history
    jb  newline
    cmp   r13d,[cpus]
    jc  cpu_n

    mov   eax,38
    mov   ebx,5
    mov   ecx,140
    sub   edx,1 ; use tick-loop's side-effect
    mov   r8d,ecx
    mov   r9d,0CCCCCCh
    int   60h ; horizontal line below graph

    ret


draw_prosentage:

    push  rax rbx rcx rdx rsi

    mov   rcx , r13

    imul  ebx,ecx,HISTORY_LEN
    mov   al,[cpu_usage+ebx-2]
    and   eax,0xff

    push  rcx
    mov   ecx,100
    sub   ecx,eax
    cmp   ecx,99
    jbe   @f
    mov   ecx,99
  @@:
    mov   eax,47
    mov   ebx,2 shl 16 + 0 shl 8 + 0
    mov   edx,[rsp]
    sub   edx,1
    imul  edx,[width_cpu]
    add   edx,10
    shl   rdx,32
    add   rdx,43

    mov   esi,0CCCCCCh

    cmp   [prs1+1],byte '>'
    jne   @f
    push  rax rbx rcx rdx
    mov   rax , 13
    mov   rbx , rdx
    mov   rcx , rdx
    shr   rbx , 32
    sub   rbx , 2
    shl   rbx , 32
    add   rbx , 13+2
    sub   rcx , 2
    shl   rcx , 32
    add   rcx , 9+2
    mov   rdx , 0xffffff
    int   0x60
    pop   rdx rcx rbx rax
    int   60h
  @@:
    pop   rcx

    pop   rsi rdx rcx rbx rax

    jmp   return_prosentage


clear_to_white:

    push  rcx r8 r9
    mov   ecx , 38
    mov   r8d , 139
    mov   r9d , 0xffffff
    int   0x60
    pop   r9 r8 rcx

    ret


; Data area

title  db  'CPU USAGE',0
speed  db  1

menu_struct:

      dq   0               ; Menu Struct -version

      dq   0x100           ; Start value of ID to return ( ID + Line )

      db   0,'SETUP',0
upd1: db   1,'> Update 1s',0
upd2: db   1,'  Update 2s',0
upd3: db   1,'  Update 4s',0
      db   1,'-',0
prs1: db   1,'  Show percentage',0
prs2: db   1,'> Hide percentage',0
      db   1,'-',0
tbr1: db   1,'> Bar',0
tbr2: db   1,'  Line',0

      db   255 ; End of Menu

cpus       rd 1
width_cpu  rd 1
process_p  rq 16
sys_info:  rb 256
prc_info:  rb 728
cpu_usage  rb HISTORY_LEN*8 ; max 8 CPUs

IMG_END:

