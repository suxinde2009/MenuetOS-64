;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Panel application
;
;   Original 32 bit version by Mike Hibbett
;
;   Graphics by Andrew Youlle
;
;   2006 June-30  64 bit conversion by Ville Turjanmaa
;   2007 June-10  Downward position by Ville Turjanmaa
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

mainstack equ 0x1f0000
memsize   equ 0x400000

use64

               org    0x0

               db     'MENUET64'        ; 8 byte id
               dq     0x01              ; header version
               dq     START             ; start of code
               dq     I_END             ; size of image
               dq     memsize           ; memory for app
               dq     mainstack         ; rsp
               dq     0x0,0x0           ; I_Param,I_Icon

; I_END       - OSWORKAREA
;               PANEL_AREA
;               PANEL_IMAGE
;               BMP_1
;               BMP_SCL
;               BMP_SCC
;               BMP_SCR
;               BMP_BC
;               RUNNINGAPPS
; 0x1f0000    - main stack
;
; pr          - 0x200000
; pr+0x20000  - app image
; pr+0x80000  - preview shape
; 0x3f0000    - preview stack


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Window preview thread
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

pr equ 0x200000

windowx equ (160+14)
windowy equ (120+14)

scalex equ 160
scaley equ 120


previewSTART:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Start preview
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; Init

    call  previewINIT

    ; Shape

    mov   rax , 50
    mov   rbx , 0
    mov   rcx , pr+0x80000
    int   0x60

    ; Read window data

    call  previewread_application_window

    ; Draw window

    call  previewdraw_window

previewstill:

    mov   rcx , 50

  wait_event:

    mov   rax , 23
    mov   rbx , 2
    int   0x60

    cmp   rax , 0
    jne   do_event2

    call  previewcheck_mouse

    mov   rax , 111
    mov   rbx , 2
    int   0x60
    cmp   rax , 0
    je    no_stop_preview
    mov   [preview_clear],byte 1
    jmp   stop_preview
  preview_clear: dq 0
  no_stop_preview:

    loop  wait_event

  do_event2:

    test  rax , 0x1         ; Window redraw
    jnz   previewwindow_event
    test  rax , 0x2         ; Keyboard press
    jnz   previewkey_event
    test  rax , 0x4         ; Button press
    jnz   previewbutton_event

    mov   rax , 125
    mov   rbx , 3
    int   0x60
    cmp   rax , 0
    je    previewstill

    call  previewread_application_window

    call  previewdraw_application_window

    jmp   previewstill


previewwindow_event:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Preview window event
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    call  previewdraw_window

    jmp   previewstill


previewkey_event:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Preview key event
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rax , 0x2        ; Read the key and ignore
    int   0x60

    cmp   ecx , 'Esc '
    je    stop_preview

    jmp   previewstill



stop_preview:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Preview stop application
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   [preview_running],dword 0

    mov   rax , 5
    mov   rbx , 5
    int   0x60

    mov   [preview_clear],byte 0

    mov   rax , 512
    int   0x60



previewbutton_event:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Preview button event
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rax , 0x11
    int   0x60

    jmp   previewstill



previewINIT:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Init preview
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rax , 2
    mov   rcx , windowx * windowy
    mov   rdi , pr+0x80000
    cld
    rep   stosb

    mov   rbx , 8

  news:

    mov   rax , 1
    mov   rcx , scalex
    mov   rdi , rbx
    imul  rdi , windowx
    add   rdi , 7
    add   rdi , pr+0x80000
    cld
    rep   stosb

    add   rbx , 1
    cmp   rbx , windowy-8
    jbe   news

    ; Soft corners - topleft

    mov   [pr+0x80000]          ,dword 0
    mov   [pr+0x80000+1]        ,dword 0
    mov   [pr+0x80000+windowx]  , word 0
    mov   [pr+0x80000+windowx+1], word 0
    mov   [pr+0x80000+windowx*2], word 0
    mov   [pr+0x80000+windowx*3], byte 0
    mov   [pr+0x80000+windowx*4], byte 0

    ; Soft corners - topright

    mov   [windowx-4+pr+0x80000]          ,dword 0
    mov   [windowx-5+pr+0x80000]          ,dword 0
    mov   [windowx-2+pr+0x80000+windowx]  , word 0
    mov   [windowx-3+pr+0x80000+windowx]  , word 0
    mov   [windowx-2+pr+0x80000+windowx*2], word 0
    mov   [windowx-1+pr+0x80000+windowx*3], byte 0
    mov   [windowx-1+pr+0x80000+windowx*4], byte 0

    ; Soft corners - bottomleft

    mov   [windowx*(windowy-1)+pr+0x80000]  ,dword 0
    mov   [windowx*(windowy-1)+1+pr+0x80000],dword 0
    mov   [windowx*(windowy-2)+pr+0x80000]  , word 0
    mov   [windowx*(windowy-2)+1+pr+0x80000], word 0
    mov   [windowx*(windowy-3)+pr+0x80000]  , word 0
    mov   [windowx*(windowy-4)+pr+0x80000]  , byte 0
    mov   [windowx*(windowy-5)+pr+0x80000]  , byte 0

    ; Soft corners - bottomright

    mov   [windowx*(windowy)+pr+0x80000-5]  ,dword 0
    mov   [windowx*(windowy)+pr+0x80000-4]  ,dword 0
    mov   [windowx*(windowy-1)+pr+0x80000-2], word 0
    mov   [windowx*(windowy-1)+pr+0x80000-3], word 0
    mov   [windowx*(windowy-2)+pr+0x80000-2], word 0
    mov   [windowx*(windowy-3)+pr+0x80000-1], byte 0
    mov   [windowx*(windowy-4)+pr+0x80000-1], byte 0

    ret


previewcheck_mouse:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Check mouse
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rax , 37
    mov   rbx , 2
    int   0x60

    cmp   rax , 0
    je    prel2

    mov   rax , 37
    mov   rbx , 1
    int   0x60

    mov   rbx , rax
    shr   rax , 32
    and   rbx , 0xffffff

    cmp   rax , windowx
    ja    prel2
    cmp   rbx , windowy
    ja    prel2

  prel1:

    mov   rax , 5
    mov   rbx , 10
    int   0x60

    mov   rax , 37
    mov   rbx , 2
    int   0x60

    cmp   rax , 0
    jne   prel1

    mov   rbx , 2
    cmp   [preview_running],dword 0x1000000
    jb    prel3
    mov   rbx , 3
  prel3:

    mov   rax , 124
    mov   rcx , [preview_running]
    and   rcx , 0xffff
    int   0x60

    mov   rax , 5
    mov   rbx , 20
    int   0x60

    mov   [prev_start],dword 0

    jmp   stop_preview

  prel2:

    ret


previewdraw_window:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Display preview window
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rax , 0xC                          ; Beginning of window draw
    mov   rbx , 0x1
    int   0x60

    mov   rax , 0x0
    mov   rbx , [previewx]
    sub   rbx , windowx/2
    shl   rbx , 32
    add   rbx , windowx
    mov   rcx , [previewy]
    shl   rcx , 32
    add   rcx , windowy
    mov   rdx , 0x0000000100FFFFFF
    bts   rdx , 63
    mov   r8  , 0x0000000000000001
    mov   r9  , 0
    mov   r10 , 0
    int   0x60

    mov   rax , 13
    mov   rbx , 0 shl 32 + 200
    mov   rcx , 0 shl 32 + 200
    mov   rdx , 0xa0a0a0
    int   0x60

    call  previewdraw_application_window

    call  previewdraw_frames

    mov   rax , 0xC                          ; End of window draw
    mov   rbx , 0x2
    int   0x60

    ret


previewdraw_frames:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Display preview window frames
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rax , 38
    mov   rbx , 0
    mov   rcx , 0
    mov   rdx , windowx-1
    mov   r8  , windowy-1
    mov   r9  , 0xf0f0f0
    push  rdx
    mov   rdx , rbx
    int   0x60
    pop   rdx
    push  rbx
    mov   rbx , rdx
    int   0x60
    pop   rbx
    push  rcx
    mov   rcx , r8
    int   0x60
    pop   rcx
    mov   r8 , rcx
    int   0x60

    ; Pixels - topleft

    mov   rax , 1
    mov   rbx , 4
    mov   rcx , 1
    mov   rdx , r9
    int   0x60
    dec   rbx
    int   0x60
    dec   rbx
    inc   rcx
    int   0x60
    dec   rbx
    inc   rcx
    int   0x60
    inc   rcx
    int   0x60

    ; Pixels - topright

    mov   rax , 1
    mov   rbx , windowx-5
    mov   rcx , 1
    mov   rdx , r9
    int   0x60
    inc   rbx
    int   0x60
    inc   rbx
    inc   rcx
    int   0x60
    inc   rbx
    inc   rcx
    int   0x60
    inc   rcx
    int   0x60

    ; Pixels - bottomleft

    mov   rax , 1
    mov   rbx , 4
    mov   rcx , windowy-2
    mov   rdx , r9
    int   0x60
    dec   rbx
    int   0x60
    dec   rbx
    dec   rcx
    int   0x60
    dec   rbx
    dec   rcx
    int   0x60
    dec   rcx
    int   0x60

    ; Pixels - bottomright

    mov   rax , 1
    mov   rbx , windowx-5
    mov   rcx , windowy-2
    mov   rdx , r9
    int   0x60
    inc   rbx
    int   0x60
    inc   rbx
    dec   rcx
    int   0x60
    inc   rbx
    dec   rcx
    int   0x60
    dec   rcx
    int   0x60

    ret


previewread_application_window:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Read application window
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   r10 , [preview_running]
    and   r10 , 0xffff

    ; Get window X and Y size

    mov   rax , 9
    mov   rbx , 2
    mov   rcx , r10
    mov   rdx , pr
    mov   r8  , 1024
    int   0x60

    mov   rax , 0
    mov   rbx , 0

  newpix2:

    push  rax rbx

    ; X

    imul  rax , [pr+16]
    xor   rdx , rdx
    mov   rbx , scalex
    div   rbx
    mov   rdx , rax
    inc   rdx

    ; Y

    push  rdx
    mov   rax , [rsp+8]
    imul  rax , [pr+24]
    xor   rdx , rdx
    mov   rbx , scaley
    div   rbx
    mov   r8  , rax
    pop   rdx

    ; Get pixel

    mov   rax , 125
    mov   rbx , 4
    mov   rcx , r10
    int   0x60

    mov   rbx , [rsp+8]
    mov   rcx , [rsp]

    imul  rcx , scalex*3
    imul  rbx , 3
    add   rbx , rcx
    mov   [pr+0x20000+rbx],eax

    pop   rbx rax

    add   rax , 1
    cmp   rax , scalex
    jb    newpix2

    mov   rax , 0

    add   rbx , 1
    cmp   rbx , scaley
    jb    newpix2

    ret


previewdraw_application_window:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Display preview window image
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rax , 7
    mov   rbx , 7 shl 32 + scalex
    mov   rcx , 7 shl 32 + scaley
    mov   rdx , pr+0x20000
    mov   r8  , 0
    mov   r9  , 0x1000000
    mov   r10 , 3
    int   0x60

    mov   rax , 125
    mov   rbx , 3
    int   0x60
    cmp   rax , 0
    jne   enabled

    mov   rax , 4
    mov   rbx , enable_transparency
    mov   rcx , 31
    mov   rdx , 54
    mov   r9  , 1
    mov   rsi , 0xa0a0a0
    int   0x60
    mov   rbx , enable_transparency_2
    add   rdx , 14
    int   0x60

  enabled:

    ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Main menu
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


; Constants

OSWORKAREA          equ I_END       ; Place for OS work area, 16KB
BPP                 equ 3           ; Number of bytes per pixel
BMPHEADER           equ 18*3        ; Header part of bmp file
PANEL_DEPTH         equ 42          ; Number of rows in panel image
PANEL_MAX_WIDTH     equ (1920+80)   ; Maximum width of Panel image
PANEL_DEPTH_DOWN    equ 30          ; Number of rows when panel down

; This is also a temporary work area for building the free-form
; window data
PANEL_AREA          equ OSWORKAREA + 0x4000
; memory location of 'constructed' image prior to display
PANEL_IMAGE         equ PANEL_AREA + ( PANEL_DEPTH * PANEL_MAX_WIDTH )
; memory location of main bmp image read in from ram disk
BMP_1               equ PANEL_IMAGE + ( BPP * PANEL_DEPTH * PANEL_MAX_WIDTH )
BMP_1_WIDTH         equ 140         ; The width of the original image
BMP_1_DEPTH         equ PANEL_DEPTH ; The height of the panel image
BMP_SCL             equ 1024 + BMP_1 + BMPHEADER + (BPP * BMP_1_DEPTH \
                                                           * BMP_1_WIDTH)
BMP_SCL_WIDTH       equ 14         ; The width of the original image
BMP_SCL_DEPTH       equ 26         ; The height of the panel image
BMP_SCC             equ 1024 + BMP_SCL + BMPHEADER + (BPP * BMP_SCL_DEPTH \
                                                          * (BMP_SCL_WIDTH+3))
BMP_SCC_WIDTH       equ 6          ; The width of the original image
BMP_SCC_DEPTH       equ 26         ; The height of the panel image
BMP_SCR             equ 1024 + BMP_SCC + BMPHEADER + (BPP * BMP_SCC_DEPTH \
                                                          * (BMP_SCC_WIDTH+3))
BMP_SCR_WIDTH       equ 18         ; The width of the original image
BMP_SCR_DEPTH       equ 26         ; The height of the panel image
BMP_BC              equ 1024 + BMP_SCR + BMPHEADER + (BPP * BMP_SCR_DEPTH \
                                                          * (BMP_SCR_WIDTH+3))
BMP_BC_WIDTH        equ 47         ; The width of the original image
BMP_BC_DEPTH        equ 34         ; The height of the panel image
; Reserve 13 bytes for each entry - the 12 bytes of the appname plus 1 null
RUNNINGAPPS         equ 1024 + BMP_BC + BMPHEADER + (BPP * BMP_BC_DEPTH \
                                                           * (BMP_BC_WIDTH+3))
CLOCK_COLOUR        equ 0x000000
APP_INC             equ 32
APP_COLOUR          equ 0x00808080


check_position:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Check window position
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov     [CLOCK_Y],dword 6
    mov     [CLOCK_X],dword 155
    mov     [APP_Y],dword 6
    mov     [APP_X],dword 217
    mov     [wysize],dword PANEL_DEPTH

    cmp     [position],byte 1
    jne     noychange

    mov     [CLOCK_Y],dword 12
    mov     eax , [scrSizeX]
    sub     eax , 55
    mov     [CLOCK_X],eax
    mov     [APP_Y],dword 12
    mov     [APP_X],dword 160
    mov     [wysize],dword PANEL_DEPTH_DOWN

    mov     eax , [scrSizeY]
    sub     eax , 342  ; 258 for 600
    xor     rdx , rdx
    mov     rbx , 10
    div     rbx
    add     dl  , 48
    mov     [paramsdown+15],dl
    xor     rdx , rdx
    mov     rbx , 10
    div     rbx
    add     dl  , 48
    mov     [paramsdown+14],dl
    xor     rdx , rdx
    mov     rbx , 10
    div     rbx
    add     dl  , 48
    mov     [paramsdown+13],dl
    xor     rdx , rdx
    mov     rbx , 10
    div     rbx
    add     dl  , 48
    mov     [paramsdown+12],dl

  noychange:

    ret



START:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Function
;      START
;
;   Description
;       Entry point of the application
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; Clear memory

    mov   rdi , clearstart
    mov   rcx , memsize-clearstart-100
    mov   rax , 0
    cld
    rep   stosb

    ; System fonts

    mov   rax , 141
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    mov     rsp , mainstack

    ; IPC

    mov   rax , 60
    mov   rbx , 1
    mov   rcx , ipcarea
    mov   rdx , 20
    int   0x60

    ; Read config.mnt

    mov     rax , 112
    mov     rbx , 1
    mov     rcx , main_menu_position
    mov     rdx , 0
    mov     r8  , 0
    int     0x60
    and     bl , 1
    mov     [position],bl

    ; Get the screen resolution

    mov     eax,14
    int     0x40

    movzx   ebx, ax
    mov     [scrSizeY], ebx
    shr     eax, 16
    mov     [scrSizeX], eax

    ; Menu position
    call    check_position

    ; Read the Panel bitmaps
    call    readBitmaps

    ; Read the name strings of running apps
    call    readAppNames

    ; Create the panel image
    call    buildDefaultPanel

    ; Create the free-form window definition, and apply it
    call    setWindowForm

    ; Draw window
    call    draw_window

still:

    mov     r15 , 0
    mov     rsp , mainstack

still2:

    inc     qword [redraw]

    mov     rax, 23       ; Wait here for event
    mov     rbx, 2
    int     0x60

    test    eax,1         ; Redraw request
    jnz     red
    test    eax,2         ; Key in buffer
    jnz     key
    test    eax,4         ; Button in buffer
    jnz     button

    call    check_preview_clear

    push    r15
    call    check_mouse
    pop     r15

    cmp     [readapps],byte 1
    je      check_applications

    inc     r15
    cmp     r15 , 25
    jbe     still2

  check_applications:

    mov     [readapps],byte 0

    call    checkIPC

    ; Check for running apps

    call    readAppNames
    cmp     ebx , 0
    je      nodisplayapps
    call    buildDefaultPanel
    call    draw_window
    mov     [prevtime],dword 0
  nodisplayapps:

    ; Display the clock

    call    showTime

    jmp     still


check_preview_clear:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   If this is at top of window stack and preview is
;   not running -> clear start
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    cmp     [preview_clear],byte 1
    jne     noclear
    mov     rax , 111
    mov     rbx , 2
    int     0x60
    cmp     rax , 0
    je      noclear
    mov     [prev_start],dword 0
    mov     [preview_clear],byte 0
  noclear:

    ret


check_mouse:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Mouse event
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; Mouse moved ?

    mov     rax , 37
    mov     rbx , 1
    int     0x60
    cmp     ax  , 40
    ja      cml1
    cmp     rax , [mousexy]
    je      nomousemove
    mov     [mousexy],rax
    cmp     [mousemoved],dword 0
    jne     nommz
    mov     [redraw],dword 0
  nommz:
    inc     dword [mousemoved]
  nomousemove:

    ; Buttons pressed

    mov     rax , 37
    mov     rbx , 2
    int     0x60
    cmp     rax , 0
    je      cml1

    ; Top of windowing stack

    mov     rax , 26
    mov     rbx , 1
    mov     rcx , 0x100000
    mov     rdx , 64*8
    int     0x60
    mov     r15 , [0x100000+15*8]

    mov     rax , 26
    mov     rbx , 2
    mov     rcx , 0x100000
    mov     rdx , 64*8
    int     0x60

    mov     rax , 111
    mov     rbx , 1
    int     0x60

    cmp     rax , [0x100000+r15*8]
    jne     cml1

    ;
    ; Any application windows available ?
    ;
    cmp     [numDisplayApps],dword 0
    je      cml1

    ; Mouse position

    mov     rax , 37
    mov     rbx , 1
    int     0x60

    cmp     ax  , 22
    ja      cml1

    shr     rax , 32

    mov     rsi , app_pos-8
  cml2:
    add     rsi  , 8
    cmp     [rsi],dword 0
    je      cml1
    cmp     [rsi+8],dword 0
    je      cml1
    mov     rbx , [rsi]
    sub     rbx , 8
    cmp     rax , rbx
    jb      cml2
    mov     rbx , [rsi+8]
    sub     rbx , 26
    cmp     rax , rbx
    ja      cml2

    ; Start preview

    mov     rax , 37
    mov     rbx , 2
    int     0x60

    cmp     rax , 2
    je      start_preview

    mov     [prev_start],dword 0

    ; Wait for mouse up

  wait_mouse:

    mov     rax , 5
    mov     rbx , 2
    int     0x60

    mov     rax , 11
    int     0x60
    cmp     rax , 0
    jne     do_event

    mov     rax , 37
    mov     rbx , 2
    int     0x60
    cmp     rax , 0
    jne     wait_mouse

    jmp     no_event

  do_event:

    push    rsi
    call    draw_window
    pop     rsi

  no_event:

    sub     rsi , app_pos

    mov     rbx , 2
    cmp     [app_pid+rsi],dword 0x1000000
    jb      cml11
    mov     rbx , 1
    or      [app_pid+rsi],dword 0x8000000
  cml11:
    mov     rax , 124
    mov     rcx , [app_pid+rsi]
    and     rcx , 0xffffff
    int     0x60

    mov     rax , 5
    mov     rbx , 10
    int     0x60

    mov     [readapps],byte 1

  cml1:

    ret


checkIPC:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   IPC
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    cmp     [ipcarea+16],byte 0
    je      noipc

    mov     [ipcarea+8],dword 16

    mov     rax , 0
    cmp     [ipcarea+16],byte 'D'
    jne     nodown
    mov     rax , 1
  nodown:

    mov     [ipcarea+16],byte 0
    cmp     [position],al
    je      noipc
    jmp     change_position

  noipc:

    mov     [ipcarea+16],dword 0
    ret



red:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Window redraw
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov     eax,14
    int     0x40
    movzx   ebx, ax
    cmp     [scrSizeY], ebx
    jne     restart
    shr     eax, 16
    cmp     [scrSizeX], eax
    jne     restart

    call    draw_window

    jmp     still


restart:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Restart
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    call    closeMenus

    mov     rax , 5
    mov     rbx , 20
    int     0x60

    mov     rax , 256
    mov     rbx , start_boot
    mov     rcx , start_param
    int     0x60

    mov     rax , 512
    int     0x60


key:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Key event
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov     eax , 2
    int     0x40

    jmp     still


start_preview:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Start window preview
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov     rcx , 50

  stpl1:

    mov     rax , 5
    mov     rbx , 1
    int     0x60

    call    check_preview_clear

    cmp     [preview_running],dword 0
    je      startpreview

    mov     rax , 5
    mov     rbx , 1
    int     0x60

    call    check_preview_clear

    loop    stpl1

    ; Give preview one second to close, then start it.

  startpreview:

    mov     rax , 5
    mov     rbx , 8
    int     0x60

    ; Menu activated ?

    push    rsi
    mov     rax , 11
    int     0x60
    test    rax , 001b
    jz      noactivated
    call    draw_window
  noactivated:
    pop     rsi

    mov     eax , [rsi]
    add     eax , [rsi+8]
    sub     rax , 23
    shr     rax , 1
    mov     [previewx],rax
    mov     [previewy],dword 50
    cmp     [position],byte 0
    je      yesprevup
    mov     eax , [scrSizeY]
    sub     eax , 40
    sub     eax , 120+14
    mov     [previewy],rax
  yesprevup:

    sub     rsi , app_pos
    mov     rax , [app_pid+rsi]
    mov     [preview_running],rax

  waitmouse:

    mov     rax , 5
    mov     rbx , 1
    int     0x60

    call    check_preview_clear

    mov     rax , 37
    mov     rbx , 2
    int     0x60

    cmp     rax , 0
    jne     waitmouse

    mov     rax , [preview_running]
    cmp     rax , [prev_start]
    je      nostartpreview2

    push    rax
    call    check_previewpid
    pop     rax

    mov     [prev_start],rax

    mov     rax , 51
    mov     rbx , 1
    mov     rcx , previewSTART
    mov     rdx , 0x3ffff0
    int     0x60

    mov     [previewpid],rbx

  nostartpreview:

    jmp     still

  nostartpreview2:

    mov     rax , 5
    mov     rbx , 10
    int     0x60

    mov     [prev_start],dword 0
    mov     [preview_running],dword 0

    jmp     still




check_previewpid:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Check if previewpid has a process running
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    sub     rsp , 32

    mov     r15 , 0

  waitpreviewpid:

    mov     [rsp],dword 0xffffff

    mov     rax , 9
    mov     rbx , 2
    mov     rcx , [previewpid]
    mov     rdx , rsp
    mov     r8  , 16
    int     0x60

    cmp     [rsp],dword 0xffffff
    je      previewpidclear

    mov     rax , 5
    mov     rbx , 10
    int     0x60

    add     r15 , 1
    cmp     r15 , 10*10 ; 10 sec timeout
    jbe     waitpreviewpid

  previewpidclear:

    add     rsp , 32

    ret






button:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Button event
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov     rax , 17
    int     0x60

    cmp     rbx , 90
    jne     nocpustart
    mov     rax , 256
    mov     rbx , string_cpu
    mov     rcx , 0
    int     0x60
    jmp     still
  nocpustart:

    cmp     rbx , 100
    jne     nomenupositionchange

  change_position:

    call    closeMenus

    mov    rcx , 5 ; Wait and respond to window requests
  waitmove:
    push   rcx
    mov    rax , 5
    mov    rbx , 10
    int    0x60
    mov    rax , 11
    int    0x60
    test   rax , 1
    jz     nodrw
    call   draw_window
  nodrw:
    pop    rcx
    loop   waitmove

    inc     byte [position]
    and     [position],byte 1

    call    check_position

    mov     rcx , 0
    cmp     [position],byte 1
    jne     noposdown
    mov     ecx , [scrSizeY]
    sub     rcx , PANEL_DEPTH_DOWN
  noposdown:

    mov     rax , 67
    mov     rbx , 0
    mov     rdx , -1
    mov     r8  , [wysize]
    int     0x60

    mov     [runimanager],byte 1

    jmp     still

  newthread:

    call    check_position
    call    draw_window

    jmp     still

  nomenupositionchange:

    cmp     rbx , 11                ; button id=11 ?
    jne     nocalendar

    ; Is calendar already running ?

    mov     rcx , 1
  newcheck:
    mov     rax , 9
    mov     rbx , 1
    mov     rdx , 0xf0000
    mov     r8  , 1024
    int     0x60
    mov     rax , 'D/1/CALR'
    cmp     [0xf0000+288],byte 0
    jne     nocheckcalr
    cmp     [0xf0000+408+2],rax
    je      still
  nocheckcalr:
    inc     rcx
    cmp     rcx , 64
    jbe     newcheck

    ; No, start it.

    mov     rax , 256
    mov     rbx , calendar
    mov     rcx , 0
    int     0x60
    jmp     still
  nocalendar:

    ; Open menu

    cmp     rbx , 1
    jne     still

    call    closeMenus

    ; Did we actually close any?

    cmp     rax , 0
    jne     still   ; We closed some, so dont open

    mov     rax , 256
    mov     rbx , startfile2
    mov     rcx , paramsup
    cmp     [position],byte 1
    jne     noparamsdown
    mov     rcx , paramsdown
  noparamsdown:
    int     0x60

    mov     [childPID],ebx

    jmp     still



readAppNames:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Function
;      readAppNames
;
;   Description
;       Reads the names of the applications that are running
;       These will be displayed on the Panel bar.
;       Some running apps are ignored, eg menu, mmenu, icon
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; Readcount
    inc     dword [readcount]

    ; Get mypid
    mov     rax , 111
    mov     rbx , 1
    int     0x60
    mov     [mypid],rax

    ; Pixels for Window names
    mov     [menutimesize],dword 270

    ; Max namelength for Window title
    mov     [namelength],dword 11

  retry:

    ;
    ; Scan slots with labels
    ;
    mov     rbp , app_pid       ; pids
    xor     rdx , rdx           ; num of app/names to display
    mov     [labelcount],rdx    ;
    mov     rcx , 2             ; First slot to scan
    mov     rax , 0             ;
    mov     [lengthsum],rax     ; Displayed names length in pixels

  ran001:

    ;
    ; Save within loop
    ;
    mov     [looprcx],rcx

    ;
    ; Running process at this slot ?
    ;
    mov     [OSWORKAREA+288],dword 1
    mov     rax , 9
    mov     rbx , 1
    mov     rdx , OSWORKAREA
    mov     r8  , 1024
    int     0x60
    cmp     [OSWORKAREA+288],dword 0
    jne     ran002

    ;
    ; Multiple menus -> close this.
    ;
    cmp     [readcount],dword 5
    jbe     noclosemenu
    mov     rax , [OSWORKAREA+264]
    cmp     rax , [mypid]
    je      noclosemenu
    cmp     [OSWORKAREA+0],dword 0
    jne     noclosemenu
    cmp     [OSWORKAREA+16],dword 630
    jb      noclosemenu
    cmp     [OSWORKAREA+24],dword 100
    ja      noclosemenu
    mov     rax , '/1/MENU '
    cmp     [OSWORKAREA+408+3],rax
    je      closemenu
    mov     rax , '/1/menu '
    cmp     [OSWORKAREA+408+3],rax
    je      closemenu
    jmp     noclosemenu
  closemenu:
    call    closeMenus
    mov     rax , 5
    mov     rbx , 50
    int     0x60
    mov     rax , 512
    int     0x60
  noclosemenu:

    ;
    ; Does the process have window label defined ?
    ;
    cmp     [OSWORKAREA+360],dword 0
    je      nonewpid

    ;
    ; Save PID
    ;
    mov     r15 , [OSWORKAREA+264]
    ; Minimized window
    cmp     [OSWORKAREA+704],byte 1
    je      winmin
    add     r15 , 0x8000000
  winmin:
    and     r15 , 0xfffffff
    mov     [rbp],r15
    add     rbp , 8

    ; New application label
    add     [labelcount],dword 1

    ;
    ; Over max width (with size=1)
    ;
    mov     rax , 6
    add     rax , APP_INC
    add     [lengthsum],rax
    mov     r12d , [scrSizeX]
    sub     r12d , [menutimesize]
    cmp     [lengthsum],r12d
    jae     ran003

    ;
  nonewpid:

  ran002:

    mov     rcx , [looprcx]

    ; Scan upto 64

    inc     rcx
    cmp     rcx , 64
    jbe     ran001

  ran003:

    ; Found zero
    cmp     [labelcount],dword 0
    je      ranexit
    ; Found one
    cmp     [labelcount],dword 1
    je      noarrange

    ;
    ; Arrange
    ;
    mov     r8  , 0
  arrangepids:
    mov     rax , [labelcount]
    mov     rax , [app_pid+rax*8-8]
    mov     rcx , rax
    and     rcx , 0x7ffffff
    ;
    mov     rdx , 0
  findnextpid:
    mov     rbx , [app_pid+rdx*8]
    and     rbx , 0x7ffffff
    add     rdx , 1
    cmp     rdx , r8
    ja      addthis
    cmp     rcx , rbx
    ja      findnextpid
  addthis:
    ;
    lea     rsi , [app_pid+rdx*8-8]
    ;
    push    rsi
    add     rsi , 67*8
    mov     rdi , rsi
    add     rdi , 8
    mov     rcx , 68
    std
    rep     movsq
    cld
    pop     rsi
    ;
    mov     [rsi],rax
    ;
    add     r8 , 1
    cmp     r8 , [labelcount]
    jb      arrangepids

  noarrange:

    ;
    ; Scan window labels for PIDs
    ;
    mov     rbp , app_pid        ; Pids
    mov     rax , 0              ;
    mov     [lengthsum],rax      ; Displayed names length in pixels
    ; Clear app name area        ;
    mov     rdi , RUNNINGAPPS    ;
    mov     rcx , 13*64          ;
    mov     rax , 0              ;
    cld                          ;
    rep     stosb                ;
    mov     rdi , RUNNINGAPPS    ; Name strings pointer
                                 ;
    mov     rcx , 0              ; Pid slot count

  scan001:

    mov     [looprcx],rcx

    ;
    ; Get process window label
    ;
    mov     rax , 110
    mov     rbx , 1
    mov     rcx , [rbp]
    and     rcx , 0xffffff
    mov     rdx , OSWORKAREA
    mov     r8  , 30
    int     0x60

    ;
    ; Set window name length
    ;
    ; Mark end of name
    mov     rsi , OSWORKAREA
    add     rsi , [namelength]
    mov     [rsi],byte 0
    ; Get checksum if applications have changed
    mov     rsi , OSWORKAREA
    call    strLen
    cmp     rcx , 1
    jae     rcxfine1
    mov     rcx , 1
  rcxfine1:
    imul    rcx , 6
    add     rcx , APP_INC
    add     [lengthsum],rcx

    ; Copy name
    mov     rsi , OSWORKAREA
    and     rdi , 0xffffff
    mov     rcx , 12
    cld
    rep     movsb
    mov     [edi], byte 0
    inc     edi

    ; Over max width ?
    mov     r12d , [scrSizeX]
    sub     r12d , [menutimesize]
    cmp     [lengthsum],r12d
    jae     ranexit

    mov     rcx , [looprcx]
    add     rbp , 8

    ; Next PID

    inc     rcx
    cmp     rcx , [labelcount]
    jb      scan001

  ranexit:

    ; Do we have more windows we can display ?

    mov     [showactivateall],byte 0
    mov     r12d , [scrSizeX]
    sub     r12d , [menutimesize]
    cmp     [lengthsum],r12d
    jb      lenok2
    dec     dword [namelength]
    cmp     dword [namelength],dword 1
    jb      lenok
    jmp     retry
  lenok:
    mov     rax , [lengthsum]
    mov     [showmorebuttonx],rax
    mov     [showactivateall],byte 1
  lenok2:

    ; Set number of windows to display and
    ; rbx for change in application data

    mov     rbx , 0
    mov     edx , [labelcount]
    cmp     edx , [numDisplayApps]
    je      raex
    mov     rbx , 1
  raex:
    mov     [numDisplayApps], edx

    ; If panel up -> Redraw after
    ; mouse move + 5 seconds (if over panel)

    cmp     [redraw],dword 500/2
    jb      noredraw
    cmp     [mousemoved],dword 0
    je      noredraw
    mov     [mousemoved],dword 0
    mov     [redraw],dword 0
    cmp     [position],dword 0
    jne     noredraw
    mov     rbx , 1
  noredraw:

    ret


closeMenus:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Function
;      closeMenus
;
;   Description
;       searches the process table for MMENU apps, and closes them
;       returns eax = 1 if any closed, otehrwise eax = 0
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    cmp   [childPID],dword 0
    je    nochildclose

    mov   rax , 60
    mov   rbx , 2
    mov   ecx , [childPID]
    and   rcx , 0xfffffff
    mov   rdx , closeMenus ; just send some message
    mov   r8  , 4
    int   0x60

    mov   [childPID],dword 0

    mov   rax , 1
    ret

  nochildclose:

    mov   rax , 0
    ret



buildDefaultPanel:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Function
;      buildDefaultPanel
;
;   Description
;       Constructs the panel picture by copying in small bits of
;       the image from pre-loaded bmp files
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ;
    ; Main logo area
    ;
    mov     ecx, BMP_1_DEPTH
    mov     esi, BMP_1 + BMPHEADER
    mov     edi, PANEL_IMAGE
    cld
  fill1:
    push    rcx
    ; Copy the image..
    mov     ecx, BMP_1_WIDTH * BPP
    cld
    rep     movsb
    ; Now fill to right hand side of screen
    ; This copied not just the image, but the
    ; 'shape' of the image ( the black part )
    mov     ecx, [scrSizeX]
    sub     ecx, BMP_1_WIDTH
    mov     eax, [edi-3]
  fill2:
    mov     [edi], eax
    add     edi, 3
    loop    fill2
    pop     rcx
    loop    fill1

    ; Start pixel
    mov     edi, PANEL_IMAGE + (BMP_1_WIDTH * BPP)

    ;
    ; Time slot
    ;
    mov     ecx, 5
    call    drawSlot

    ;
    ; Name slots
    ;
    mov     ebx, [scrSizeX]     ; The length of each screen line, in bytes
    imul    ebx, BPP
    mov     edx, PANEL_IMAGE
    add     edx, ebx            ; The top righthand position
    mov     ecx, 0
    mov     esi, RUNNINGAPPS
  bdp000:

    cmp     ecx, [numDisplayApps]
    jae     bdp001                 ; Displaying all apps, so finish
    cmp     edi, edx
    ja      bdp001                 ; Run out of space to display

    push    rcx
    push    rdx
    push    rsi
    call    strLen
    and     rcx , 0x1f
    cmp     rcx , 1
    jae     rcxfine2
    mov     rcx , 1
  rcxfine2:
    call    drawSlot
    pop     rsi
    pop     rdx
    pop     rcx

    inc     ecx
    add     esi, 13

    jmp     bdp000

  bdp001:

    mov     [displayedApps], ecx

    ;
    ; Closing part of the big curve
    ;
    mov     ecx, BMP_BC_DEPTH
    mov     esi, BMP_BC + BMPHEADER
    mov     ebx, [scrSizeX]            ; Length of each screen line
    imul    ebx, BPP
    mov     edx, PANEL_IMAGE
    add     edx, ebx                   ; Top righthand pos
  fill6:
    push    rcx
    push    rdi
    ; Copy the image..
    push    rsi
    mov     ecx, BMP_BC_WIDTH * BPP
    cld
    rep     movsb

    mov     eax, [edi-3]
  fill6_1:
    mov     [edi], eax
    add     edi, 3
    cmp     edi, edx
    jb      fill6_1

    pop     rsi
    add     esi, ((BMP_BC_WIDTH * BPP) + 3) and 0xFFFC
    pop     rdi
    add     edi, ebx  ; Move down one line
    add     edx, ebx
    pop     rcx
    loop    fill6

    ret




strLen:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Function
;      strLen
;
;   Description
;       Returns the length of string at esi in ecx
;       string is 'terminated' by null or space
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    push    rsi

    dec     esi
    xor     ecx, ecx
  sl001:
    inc     esi
    cmp     [esi], byte 0
    je      slexit
    inc     ecx
    jmp     sl001
  slexit:
    pop     rsi

    ret



drawSlot:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Function
;      drawSlot
;
;   Description
;       Copies a time/appname slot into the panel image
;       location ( top line position ) pointed to by edi
;       width ( number of characters ) in ecx
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; Add in the small curve for the clock
    ; Note, we do funny maths here because the bmp image
    ; is stored with a multiple of 4 pixels per row

    push    rcx   ; save num characters

    mov     ecx, BMP_SCL_DEPTH
    mov     esi, BMP_SCL + BMPHEADER

    push    rdi
    mov     ebx, [scrSizeX] ; The length of each screen line, in bytes
    imul    ebx, BPP
  fill3:
    push    rcx
    push    rdi
    ; Copy the image..
    push    rsi
    mov     ecx, BMP_SCL_WIDTH * BPP
    cld
    rep     movsb
    pop     rsi
    add     esi, ((BMP_SCL_WIDTH * BPP) + 3) and 0xFFFC
    pop     rdi
    add     edi, ebx  ; Move down one line
    pop     rcx
    loop    fill3
    pop     rdi

    add     edi, BMP_SCL_WIDTH * BPP
    mov     ebx, [scrSizeX] ; The length of each screen line, in bytes
    imul    ebx, BPP
    pop     rcx
  fill4_1:
    push    rdi
    push    rcx

    mov     ecx, BMP_SCC_DEPTH
    mov     esi, BMP_SCC + BMPHEADER
  fill4:
    push    rcx
    push    rdi
    ; Copy the image..
    push    rsi
    mov     ecx, BMP_SCC_WIDTH * BPP
    cld
    rep     movsb
    pop     rsi
    add     esi, ((BMP_SCC_WIDTH) * BPP + 3) and 0xFFFC
    pop     rdi
    add     edi, ebx ; Move down one line
    pop     rcx
    loop    fill4

    pop     rcx
    pop     rdi
    add     edi, BMP_SCC_WIDTH * BPP
    loop    fill4_1

    ; Now the closing part of the small curve

    mov     ecx, BMP_SCR_DEPTH
    mov     esi, BMP_SCR + BMPHEADER
    mov     ebx, [scrSizeX] ; The length of each screen line, in bytes
    imul    ebx, BPP
    push    rdi
  fill5:
    push    rcx
    push    rdi
    ; Copy the image..
    push    rsi
    mov     ecx, BMP_SCR_WIDTH * BPP
    cld
    rep     movsb
    pop     rsi
    add     esi, ((BMP_SCR_WIDTH * BPP) + 3) and 0xFFFC
    pop     rdi
    add     edi, ebx  ; Move down one line
    pop     rcx
    loop    fill5
    pop     rdi
    add     edi, BMP_SCR_WIDTH * BPP

    ret



setWindowForm:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Function
;      setWindowForm
;
;   Description
;       Scans the panel image looking for the curved outline,
;       so it can generate a free-form outline window
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; Create the free-form pixel map;
    ; black is the 'ignore' colour
    mov     esi , 0
    mov     edx , [scrSizeX]
    imul    edx , PANEL_DEPTH
  newpix:
    mov     eax , [PANEL_IMAGE + esi*BPP]
    mov     bl  , 0
    and     eax , 0xffffff
    cmp     eax , 0x000000
    je      cred
    mov     bl  , 1
  cred:
    mov     [esi+ PANEL_AREA ],bl
    inc     esi
    cmp     esi , edx
    jbe     newpix

    ; Set the free-form window in the OS

    mov     eax , 50
    mov     ebx , 0
    mov     ecx , PANEL_AREA
    int     0x40
    ret



readBitmaps:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Function
;      readBitmaps
;
;   Description
;       Loads the picture elements used to construct
;       the panel image
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; Main panel button, plus curves
    mov     eax, 58
    mov     ebx, pbutton
    int     0x40
    mov     eax, 58
    mov     ebx, scc
    int     0x40
    mov     eax, 58
    mov     ebx, scl
    int     0x40
    mov     eax, 58
    mov     ebx, scr
    int     0x40
    mov     eax, 58
    mov     ebx, bc
    int     0x40
    ret


draw_logo_background:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Display logo
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ;
    ; Background
    ;
    push    rax rbx rcx rdx
    shl     rbx , 32
    shl     rcx , 32
    add     rbx , rdx
    add     rcx , r8
    mov     rax , 13
    mov     rdx , 0xe0e0e0
    int     0x60
    pop     rdx rcx rbx rax

    ;
    ; Surrounding white lines
    ;
    inc     rbx
    push    rax rbx rcx rdx r8 r9 r10
    sub     rbx , 1
    sub     rcx , 1
    add     rdx , 1
    add     r8  , 1
    add     rdx , rbx
    add     r8  , rcx
    mov     rax , 38
    mov     r9  , 0xffffff
    push    rbx
    mov     rbx  , rdx
    int     0x60
    pop     rbx
    push    rcx
    mov     rcx , r8
    int     0x60
    pop     rcx
    push    r8
    mov     r8  , rcx
    int     0x60
    pop     r8
    push    rdx
    mov     rdx , rbx
    int     0x60
    pop     rdx
    pop     r10 r9 r8 rdx rcx rbx rax

    ;
    ; Surrounding shadow lines
    ;
    dec     rbx
    dec     rcx
    push    rax rbx rcx rdx r8 r9 r10
    dec     rbx
    dec     rcx
    add     rdx , 1
    add     r8  , 1
    add     rdx , rbx
    add     r8  , rcx
    mov     rax , 38
    mov     r9  , 0xa0a0a0
    mov     r9  , 0x707070
    push    rbx
    mov     rbx  , rdx
    int     0x60
    pop     rbx
    push    rcx
    mov     rcx , r8
    int     0x60
    pop     rcx
    push    r8
    mov     r8  , rcx
    int     0x60
    pop     r8
    push    rdx
    mov     rdx , rbx
    int     0x60
    pop     rdx
    pop     r10 r9 r8 rdx rcx rbx rax

    ret


draw_window:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Draw window
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov     eax , 12
    mov     ebx , 1
    int     0x40

    ;
    ; Position down
    ;
    cmp     [position],byte 1
    jne     nopositiondown

    mov     rax , 0
    mov     ebx , [scrSizeX]
    mov     ecx , PANEL_DEPTH_DOWN
    mov     edx , [scrSizeY]
    sub     rdx , PANEL_DEPTH_DOWN
    shl     rdx , 32
    add     rcx , rdx
    mov     rdx , 1 shl 32 + 1 shl 63
    mov     r8  , 0
    mov     r9  , 0
    mov     r10 , 0
    int     0x60

    mov     rax , 38
    mov     rbx , 0
    mov     rcx , 0
    mov     edx , [scrSizeX]
    mov     r8  , rcx
    mov     r9  , 0x808080
    int     0x60
    inc     rcx
    inc     r8
    mov     r9  , 0xe8e8e8
    mov     r10 , PANEL_DEPTH_DOWN-1
  newline:
    int     0x60
    sub     r9  , 0x030303
    cmp     r10 , 22
    jb      nosubcolor
    sub     r9  , 0x010101
  nosubcolor:
    inc     rcx
    inc     r8
    dec     r10
    jnz     newline

    ; Menu button

    mov     rax , 8
    mov     rbx , 0 + BMP_1_WIDTH - 10
    mov     rcx , 0 + BMP_1_DEPTH - 5
    mov     rdx , 1
    mov     r8  , 1 shl 63 + 1 shl 61
    mov     r9  , 0
    int     0x60

    ; Clock button

    mov     rax , 8
    mov     ebx , [CLOCK_X]
    sub     ebx , 10
    shl     rbx , 32
    add     rbx , 50
    mov     rcx , 0 shl 32 + 21
    mov     rdx , 11
    mov     r8  , 1 shl 63 + 1 shl 61
    mov     r9  , 0
    int     0x60

    ; Menuet logo

    mov     rbx , 22
    mov     rcx , 6
    mov     rdx , 87
    mov     r8  , 19
    mov     r10 , 0
    call    draw_logo_background

    ; Brighten the image

    mov     rbx , 0x0202020202020202
    mov     rdi , PANEL_IMAGE
    mov     ecx , [scrSizeX]
    imul    rcx , 3*50
    add     rcx , rdi
  imageup:
    add     [rdi],rbx
    add     rdi , 8
    cmp     rdi , rcx
    jbe     imageup

    ; Display MenuetOS from image

    mov     rax , 7
    mov     rbx , 29 shl 32 + 73
    mov     rcx ,  9 shl 32 + 11
    mov     rdx , 13*3
    imul    edx , [scrSizeX]
    add     rdx , PANEL_IMAGE+3*30
    mov     r8d , [scrSizeX]
    sub     r8  , 73
    imul    r8  , 3
    mov     r9  , 0x1000000
    mov     r10 , 3
    int     0x60

    ; Tone down the image

    mov     rbx , 0x0202020202020202
    mov     rdi , PANEL_IMAGE
    mov     ecx , [scrSizeX]
    imul    rcx , 3*50
    add     rcx , rdi
  imagedown:
    sub     [rdi],rbx
    add     rdi , 8
    cmp     rdi , rcx
    jbe     imagedown

    mov     [prevtime],dword 9999
    call    showTime
    call    showApps

    ; Separator lines

    mov     ebx , [scrSizeX]
    sub     rbx , 82
    call    separator_line
    mov     rbx , 133
    call    separator_line

    ; Show activate all

    cmp     [showactivateall],byte 1
    jne     noshowactivateall2

    mov     rax , 8
    mov     rbx , [showmorebuttonx]
    add     rbx , 150
    shl     rbx , 32
    add     rbx , 9
    mov     rcx , 11 shl 32 + 9
    mov     rdx , 90
    mov     r8  , 0
    mov     r9  , 0
    int     0x60
    mov     rax , 4
    mov     rdx , rcx
    mov     rcx , rbx
    shr     rcx , 32
    shr     rdx , 32
    add     rcx , 2
    add     rdx , 1
    mov     rbx , string_star
    mov     rsi , 0x8C8C8C
    mov     r9  , 1
    int     0x60

  noshowactivateall2:

    jmp     windowdone

  nopositiondown:

    ;
    ; Position up
    ;
    mov     rax , 0
    mov     ebx , [scrSizeX]
    mov     ecx , PANEL_DEPTH
    and     rbx , 0xffffff
    and     rcx , 0xffffff
    mov     rdx , 1 shl 32 + 1 shl 63
    mov     r8  , 0
    mov     r9  , 0
    mov     r10 , 0
    int     0x60

    ; Display panel

    mov     rax , 7
    mov     ebx , [scrSizeX]
    mov     rcx , PANEL_DEPTH
    mov     rdx , PANEL_IMAGE
    mov     r8  , 0
    mov     r9  , 0x000000
    mov     r10 , 3
    int     0x60

    mov     [prevtime],dword 9999
    call    showTime
    call    showApps

    ; Show activate all

    cmp     [showactivateall],byte 1
    jne     noshowactivateall

    mov     rax , 8
    mov     rbx , [showmorebuttonx]
    add     rbx , 208
    shl     rbx , 32
    add     rbx , 9
    mov     rcx , 6 shl 32 + 9
    mov     rdx , 90
    mov     r8  , 0 ; 1 shl 63 + 1 shl 61
    mov     r9  , 0 ; string_star
    int     0x60
    mov     rax , 4
    mov     rdx , rcx
    mov     rcx , rbx
    shr     rcx , 32
    shr     rdx , 32
    add     rcx , 2
    add     rdx , 1
    mov     rbx , string_star
    mov     rsi , 0x8C8C8C
    mov     r9  , 1
    int     0x60

  noshowactivateall:

    mov     rax , 8
    mov     rbx , 0 + BMP_1_WIDTH - 10
    mov     rcx , 0 + BMP_1_DEPTH - 5
    mov     rdx , 1
    mov     r8  , 1 shl 63 + 1 shl 61
    mov     r9  , 0
    int     0x60

    mov     rax , 8
    mov     rbx , 145 shl 32 + 50
    mov     rcx , 0 shl 32 + 21
    mov     rdx , 11
    mov     r8  , 1 shl 63 + 1 shl 61
    mov     r9  , 0
    int     0x60

  windowdone:

    mov     eax , 12
    mov     ebx , 2
    int     0x40

    ret



separator_line:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Separator
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov     rax , 38
    mov     rcx , 1
    mov     rdx , rbx
    mov     r8  , PANEL_DEPTH_DOWN
    mov     r9  , 0x505050
    int     0x60
    inc     rbx
    inc     rdx
    mov     r9 , 0xf0f0f0
    int     0x60

    ret



showTime:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Function
;      showTime
;
;   Description
;       Updates the time on the panel
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; Get time

    mov     rax , 3
    mov     rbx , 1
    int     0x60

    ; Change in seconds

    push    rax
    mov     rbx , rax
    shr     rbx , 16
    and     rbx , 0xff
    cmp     rbx , [lastsecs]
    je      nosecchange
    mov     [lastsecs],rbx
    mov     rsi , 0x000000
    test    rbx , 1b
    jz      nowhite
    mov     rsi , 0xe0e0e0
  nowhite:
    mov     rax , 4
    mov     rbx , clockStrmiddle
    mov     rcx , [CLOCK_X]
    mov     rdx , [CLOCK_Y]
    add     rcx , 2*6
    mov     r9  , 1
    int     0x60
  nosecchange:
    pop     rax

    ; Change in hours or minutes

    and     rax , 0xffff
    cmp     [prevtime],rax
    je      noshowtime
    mov     [prevtime],rax

    ; Background

    cmp     [position],byte 1
    jne     noclockdown
    mov     rbx , [CLOCK_X]
    mov     rcx , [CLOCK_Y]
    sub     rbx , 3
    sub     rcx , 3
    mov     rdx , 6*5 +5
    mov     r8  , 10  +3
    mov     r10 , 0
    call    draw_background
    jmp     clockbgrdone
  noclockdown:

    mov     eax , 7
    mov     ebx , [CLOCK_X]
    imul    ebx , BPP
    add     ebx , PANEL_IMAGE
    mov     ecx , (BMP_SCC_WIDTH * 5 * 65536) + 1
    mov     edx , [CLOCK_X]
    imul    edx , 65536
    add     edx , dword [CLOCK_Y]
    mov     r10 , 8
  st001:
    push    rax rdx
    int     0x40
    pop     rdx rax
    inc     edx
    dec     r10
    jnz     st001

  clockbgrdone:

    ; Display time

    call    setTimeStr
    mov     rax , 4
    mov     rbx , clockStr
    mov     rcx , [CLOCK_X]
    mov     rdx , [CLOCK_Y]
    mov     r9  , 1
    mov     rsi , CLOCK_COLOUR
    int     0x60

  noshowtime:

    ret


draw_background:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Background
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ;
    ; Main gray area
    ;
    push    rax rbx rcx rdx r8 r9 r10
    shl     rbx , 32
    shl     rcx , 32
    add     rbx , rdx
    add     rcx , r8
    mov     rax , 13
    mov     rdx , 0xe0e0e0
    int     0x60
    pop     r10 r9 r8 rdx rcx rbx rax

    ;
    ; Surrounding lines
    ;
    push    rax rbx rcx rdx r8 r9 r10
    sub     rbx , 1
    sub     rcx , 1
    add     rdx , 1
    add     r8  , 1
    add     rdx , rbx
    add     r8  , rcx
    mov     rax , 38
    mov     r9  , 0xf0f0f0
    cmp     r10 , 1
    jne     nor101
    mov     r9  , 0x606060
  nor101:
    push    rbx
    mov     rbx  , rdx
    int     0x60
    pop     rbx
    push    rcx
    mov     rcx , r8
    int     0x60
    pop     rcx
    mov     r9  , 0x606060
    cmp     r10 , 1
    jne     nor1012
    mov     r9  , 0xffffff
  nor1012:
    push    r8
    mov     r8  , rcx
    int     0x60
    pop     r8
    push    rdx
    mov     rdx , rbx
    int     0x60
    pop     rdx
    pop     r10 r9 r8 rdx rcx rbx rax

    ret



showApps:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Function
;      showApps
;
;   Description
;       Writes the application names to the display
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ;
    ; Start values
    ;
    mov     r12 , app_pos
    mov     rsi , RUNNINGAPPS
    mov     ebx , [APP_X]
    imul    ebx , 65536
    add     ebx , dword [APP_Y]
    mov     ecx , [displayedApps]
    and     rcx , 0xfff
    cmp     ecx , 0
    jne     sa001
    ret

  sa001:

    push    rax rbx rcx rdx rsi rdi r12

    ;
    ; Name string length
    ;
    call    strLen
    cmp     rcx , 1
    jae     rcxfine3
    mov     rcx , 1
  rcxfine3:
    mov     edx, esi
    mov     esi, ecx

    ;
    ; Background
    ;
    cmp     [position],byte 1
    jne     noappbgr
    push    rax rbx rcx rdx r8
    imul    rcx , 6
    mov     rdx , rcx
    add     rdx , 9
    mov     rcx , rbx
    shr     rbx , 16
    sub     rbx , 5
    and     rcx , 0xffff
    sub     rcx , 4
    mov     r8  , 14
    dec     rbx
    dec     rcx
    add     rdx , 2
    add     r8  , 2
    call    draw_background
    pop     r8 rdx rcx rbx rax
  noappbgr:

    ;
    ; Name string
    ;
    push    rdx
    mov     rax , 4
    mov     rdx , rbx
    mov     rcx , rbx
    and     rdx , 0xffff
    shr     rcx , 16
    and     rcx , 0xffff
    mov     r9  , 1
    mov     rsi , 0x000000
    pop     rbx
    and     rbx , 0xffffff
    int     0x60

    pop     r12 rdi rsi rdx rcx rbx rax

    ;
    ; Save application X position
    ;
    push    rbx
    shr     rbx , 16
    mov     [r12],ebx
    add     r12 , 8
    pop     rbx

    ;
    ; Next X position
    ;
    push    rcx
    call    strLen
    cmp     rcx , 1
    jae     rcxfine4
    mov     rcx , 1
  rcxfine4:
    imul    ecx , 6
    add     ecx , APP_INC
    shl     ecx , 16
    add     ebx , ecx
    pop     rcx

    add     esi , 13
    dec     rcx
    jnz     sa001

    ;
    ; Last application X position
    ;
    shr     rbx , 16
    mov     [r12],ebx
    add     r12 , 8
    mov     [r12],dword 0

    ret



setTimeStr:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Function
;      setTimeStr
;
;   Description
;       Reads the time and places it in a string.
;       The : character is alternated every second
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov     rax , 3   ; Get time
    mov     rbx , 1
    int     0x60

    mov     rbx , rax
    and     rax , 0xff
    mov     rcx , 10
    xor     rdx , rdx
    div     rcx
    add     al , 48
    add     dl , 48
    mov     [clockStr],al
    mov     [clockStr+1],dl
    mov     rax , rbx
    shr     rax , 8
    and     rax , 0xff
    xor     rdx , rdx
    mov     rcx , 10
    div     rcx
    add     al , 48
    add     dl , 48
    mov     [clockStr+3],al
    mov     [clockStr+4],dl

    mov     [clockStr+2], byte ' '

    ret


;
; Data area
;

scrSizeX  dd  0  ; ResX
scrSizeY  dd  0  ; ResY

appname         db  'MMENU       '
numApps         dd  0  ; Number of running applications
numDisplayApps  dd  0
displayedApps   dd  0

clockStr          db  '12:34',0
prevtime:         dq  0x0
lastsecs:         dq  0x0
clockStrmiddle:   db  ':',0
string_star:      db  '+',0

previewpid:       dq  0xfffffff
showmorebuttonx:  dq  0x0
redraw:           dq  0x0
mousemoved:       dq  0x0
showactivateall:  dq  0x0

childPID          dd  0,0
namelength:       dq  0x0
lengthsum:        dq  0x0
menutimesize:     dq  0x0
prevappchecksum:  dq  123
max_pid:          dq  100
readcount:        dq  0x0
mypid:            dq  0x0
readapps:         dq  0x0

imanager:    db  '/fd/1/imanager',0
string_boot: db  'BOOT',0
runimanager: dq  0x0
prev_start:  dq  0x0
string_cpu:  db  '/FD/1/CAD',0

looprcx:        dq  0x0
labelcount:     dq  0x0
mouse_buttons:  dq  0x0
mouse_xy:       dq  0x0
mousexy:        dq  0x0
wysize:         dq  0x0

ipcarea:

    dq    0
    dq    16
    times 20 db 0

position:  dq   001 ; 0-Up, 1-Down
CLOCK_Y:   dq   006
CLOCK_X:   dq   155
APP_Y:     dq   006
APP_X:     dq   217

main_menu_position: db 'main_menu_position',0

enable_transparency:     db   'Enable transparency',0
enable_transparency_2:   db   'for window preview.',0

start_boot:   db  '/fd/1/launcher',0
start_param:  db  'DESKTOP',0

preview_running:  dq  0x0
previewx:         dq  0x0
previewy:         dq  0x0

pbutton:
    dd  0
    dd  0
    dd  -1                          ; Amount to load - all of it
    dd  BMP_1                       ; Place to store file data
    dd  OSWORKAREA                  ; os work area - 16KB
    db  '/rd/1/mpanel.bmp',0
scl:
    dd  0
    dd  0
    dd  -1                          ; Amount to load - all of it
    dd  BMP_SCL                     ; Place to store file data
    dd  OSWORKAREA                  ; os work area - 16KB
    db  '/rd/1/scl.bmp',0
scc:
    dd  0
    dd  0
    dd  -1                          ; Amount to load - all of it
    dd  BMP_SCC                     ; Place to store file data
    dd  OSWORKAREA                  ; os work area - 16KB
    db  '/rd/1/scc.bmp',0
scr:
    dd  0
    dd  0
    dd  -1                          ; Amount to load - all of it
    dd  BMP_SCR                     ; Place to store file data
    dd  OSWORKAREA                  ; os work area - 16KB
    db  '/rd/1/scr.bmp',0
bc:
    dd  0
    dd  0
    dd  -1                          ; Amount to load - all of it
    dd  BMP_BC                      ; Place to store file data
    dd  OSWORKAREA                  ; os work area - 16KB
    db  '/rd/1/bc.bmp',0

calendar:    db  '/FD/1/CALR',0
startfile2:  db  '/FD/1/MMENU',0
paramsup:    db  'MAINMENU 5 28',0
paramsdown:  db  'MAINMENU 04 0258',0

clearstart:

app_pos: times 256 dq ?
app_pid: times 256 dq ?

I_END:

