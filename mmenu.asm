;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;  Menu application
;
;  original version; uses buttons.
;  suffers from needing a long keypress before submenu opens when
;  menu is overlapped
;
;  Also, should close other submenus (children!) when opening a new menu
;
;  Compile with FASM for Menuet
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Constants

OPTIONSFILE         equ I_END + 256 ; Place for Menu Options File (8KB)
MENUTABLE           equ OPTIONSFILE + 8192 ; Place for Menu Table, 8KB
OSWORKAREA          equ MENUTABLE + 8192   ; Place for OS work area, 16KB

BPP                 equ 3           ; Number of bytes per pixel
BMPHEADER           equ 18*3        ; Header part of bmp file

MENU_MAX_DEPTH      equ 1024        ; Maximum depth of menu image
MENU_WIDTH          equ (126+4)     ; Maximum width of Panel image

; This is also a temporary work area for building the free-form
; window data
MENU_AREA           equ OSWORKAREA + 0x4000

; memory location of 'constructed' image prior to display
MENU_IMAGE          equ MENU_AREA + ( MENU_MAX_DEPTH * MENU_WIDTH )

; memory location of main bmp image read in from ram disk
BMP_MT              equ MENU_IMAGE + ( BPP * MENU_MAX_DEPTH * MENU_WIDTH )
BMP_MT_WIDTH        equ MENU_WIDTH  ; The width of the original image
BMP_MT_DEPTH        equ 20          ; The height of the bitmap image
BMP_MTF_DEPTH       equ 5           ; The heigth of the submenu top image

BMP_MC              equ 1024 + BMP_MT + BMPHEADER + (BPP * BMP_MT_DEPTH \
                                                       * (BMP_MT_WIDTH+3))
BMP_MC_WIDTH        equ MENU_WIDTH ; The width of the original image
BMP_MC_DEPTH        equ 34         ; The height of the bitmap image

; MC.BMP replaced with MB.BMP in file descriptor (20pix difference in height)

BMP_MB              equ 1024 + BMP_MC + BMPHEADER + (BPP* (20+BMP_MC_DEPTH) \
                                                        * (BMP_MC_WIDTH+3))
BMP_MB_WIDTH        equ MENU_WIDTH ; The width of the original image
BMP_MB_DEPTH        equ 54         ; The height of the bitmap image

ICON_FILE           equ 1024 + BMP_MB + BMPHEADER + (BPP * BMP_MB_DEPTH \
                                                        * (BMP_MB_WIDTH+3))
textposx equ 51
iconposx equ 9

use64

    org   0x0

    db    'MENUET64'        ; 8 byte id
    dq    0x01              ; header version
    dq    START             ; start of code
    dq    I_END             ; size of image ; could be much less
    dq    0x200000          ; memory for app
    dq    0x1ffff0          ; rsp
    dq    I_Param-8,0       ; I_Param , I_Icon

adjusted_str  equ 0xa0000

;***************************************************************************
;   Function
;      START
;
;   Description
;       Entry point of the menu application
;
;***************************************************************************
START:

    ; System fonts
    mov   rax , 141
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    ; Look at the input params - Menuname and position
    call    parseParams

    ; Read Menu options from file
    call    readMenuOptions

    ; Read the bitmaps
    call    readBitmaps

    ; Copy bitmaps into menu image
    call    buildMenuImage

    ; Create the free-form window definition, and apply it
    call    setWindowForm

    call    renderIcons
    call    draw_window

    mov     rax,60                 ; IPC
    mov     rbx,1                  ; define receive area
    mov     rcx,received_messages  ; pointer to start
    mov     rdx,8                  ; size of area
    int     0x60
    mov     [received_messages+16],dword 0

still:

    mov     eax, 23                  ; wait here for event
    mov     ebx, 2
    int     0x40

    cmp     eax,1                   ; redraw request ?
    je      red
    cmp     eax,2                   ; key in buffer ?
    je      key
    cmp     eax,3                   ; button in buffer ?
    je      button

    cmp     [received_messages+16],byte 0
    jne     IPC

    jmp     still

closechild:

    ; Tell any child menus to close, then close myself

    cmp     [childPID], dword 0
    je      noSub

    mov     ecx, [childPID]
    and     rcx , 0xffffff

    mov     rax,60                 ; IPC
    mov     rbx,2                  ; send message
    mov     rdx, noSub             ; Send any data
    mov     r8 , 4
    int     0x60

  noSub:

    ret

IPC:

    call    closechild
    mov     eax, -1
    int     0x40
    jmp     still

red:                                ; redraw

    call    draw_window
    jmp     still

key:                                ; key

    mov     rax,2                   ; just read it and ignore
    int     0x60
    cmp     cl , 'E'
    je      IPC
    cmp     rbx , 0
    jne     still
    jmp     IPC

button:

    mov     eax,17                  ; get id
    int     0x40
    shr     eax,8                   ; Get button id

  dobutton:

    ; Application or Menu?
    mov     ebx, [MENUTABLE + eax + 4]
    cmp     [ebx], byte 'A'
    je      launchApp

    call    runMenu
    jmp     still

launchApp:

    call    runApp

    ; Give a small delay - simultaneous app open / close is a problem
    ; in the kernel
    mov     eax, 5
    mov     ebx, 50
    int     0x40

    jmp     still


;***************************************************************************
;   Function
;      closeMenus
;
;   Description
;       searches the process table for MMENU apps, and closes them
;
;***************************************************************************
closeMenus:

    call    closechild
    ret

runApp:

    ; Copy the filename across
    mov     esi, [MENUTABLE + eax + 12]
    mov     edi, tmpfn
    mov     ecx, 256
    cld
    rep     movsb

    mov     eax, 16
    mov     [tmpf], eax
    xor     eax, eax
    mov     [tmpf+4], eax
    mov     [tmpf+12], eax
    mov     eax, params
    mov     [tmpf+8], eax

    mov     [params], byte 0

    ; Mark file as asciiz

    mov   rsi , tmpfn
  fe1:
    inc   rsi
    cmp   [rsi],byte ' '
    ja    fe1
    mov   [rsi],byte 0

    ; Search for parameter

    mov   rcx , 0 ; no parameter as default
    inc   rsi
    cmp   [rsi],byte ' '
    jbe   noparameter
    cmp   [rsi],byte ','
    je    noparameter
    mov   rcx , rsi
    mov   rax , rsi
    add   rax , 256
  fe2:
    inc   rsi
    cmp   rsi , rax
    ja    fe3
    cmp   [rsi],byte ','
    je    fe3
    cmp   [rsi],byte ' '
    ja    fe2
  fe3:
    mov   [rsi],byte 0
  noparameter:

    ; run the app

    mov   rax , 256
    mov   rbx , tmpfn
    int   0x60

    ret

runMenu:

    ; If we are already running a menu, tell it to close

    push    rax
    call    closechild
    pop     rax

  rm00b:

    ; Write in newX/Y the starting postion for the new menu
    ; open menu nearby the button we pressed

    push    rax         ; Our button number

    shr     eax, 4
    imul    eax, 34 ; 34
    add     eax, [startY]
    add     eax, 28
    cmp     [startX],dword MENU_WIDTH-10
    jbe     noyup
    cmp     [menuType],byte 'D'
    je      noyup
    sub     eax , 12 +4
  noyup:
    mov     [newY], eax

  posdone:

    mov     eax, [startX]
    add     eax, MENU_WIDTH
    mov     [newX], eax
    pop     rax
    mov     esi, [MENUTABLE + eax + 12]
    mov     edi, params
    mov     ecx, 256
    cld
    rep     movsb

    ; Now write across the startx and starty positions
     mov     edi, params             ; Find the end of the first param
  rm00a:
    inc     edi
    cmp     [edi], byte 0
    jne     rm00a

    mov     [edi], byte ' '
    mov     ecx, 4
    add     edi, ecx
    mov     eax, [newX]
    mov     ebx, 10
  rm000:
    xor     edx, edx
    div     ebx
    add     dl, '0'
    mov     [edi], dl
    dec     edi
    loop    rm000

    add     edi, 5

    mov     [edi], byte ' '
    mov     ecx, 4
    add     edi, ecx
    mov     eax, [newY]
    mov     ebx, 10
  rm001:
    xor     edx, edx
    div     ebx
    add     dl, '0'
    mov     [edi], dl
    dec     edi
    loop    rm001

    mov     [edi+5], byte 0

    mov     rax,256
    mov     rbx,startfile2
    mov     rcx, params
    int     0x60

    mov     [childPID], ebx

    ret


;***************************************************************************
;   Function
;      parseParams
;
;   Description
;       Looks at the input parameters; Are we the main menu, and where are
;       we drawn?
;
;***************************************************************************
parseParams:
    mov     edi, I_Param

    ; set up Menu type variable
    mov      al, [edi]                   ; MAINMENU or SUBMENUxxx
    mov      [menuType], al

  pp001:
    inc     edi
    cmp     [edi], byte ' '
    jne     pp001
  pp002:
    inc     edi
    cmp     [edi], byte ' '
    je      pp001

  pp003:
    mov     eax, [startX]
    imul    eax, 10
    movzx   ebx, byte [edi]
    sub     bl, byte '0'
    add     eax, ebx
    mov     [startX], eax
    inc     edi
    cmp     [edi], byte '0'
    jae     pp003

    inc     edi

  pp004:
    mov     eax, [startY]
    imul    eax, 10
    movzx   ebx, byte [edi]
    sub     bl, byte '0'
    add     eax, ebx
    mov     [startY], eax
    inc     edi
    cmp     [edi], byte '0'
    jae     pp004

    ; Calculate main menu bar position

    mov     [position],byte 0
    mov     eax , [startX]
    sub     rax , 5
    mov     rbx , MENU_WIDTH
    xor     rdx , rdx
    div     rbx
    cmp     rdx , 0
    je      nomaindown
    mov     [position],byte 1
    mov     [menuType],byte 'D'
  nomaindown:

    ret



;***************************************************************************
;   Function
;      buildMenuImage
;
;   Description
;       Constructs the menu picture by copying in small bits of the image
;       from pre-loaded bmp files
;
;***************************************************************************
buildMenuImage:
    ; Note, we do funny maths here because the bmp image
    ; is stored with a multiple of 4 pixels per row

    xor     eax, eax
    mov     [menuDepth], eax

    mov     ecx, BMP_MT_DEPTH
    cmp     [menuType], byte 'M'
    je     @f
    mov     ecx, BMP_MTF_DEPTH
  @@:

    add     [menuDepth], ecx
    mov     esi, BMP_MT + BMPHEADER
    mov     edi, MENU_IMAGE
    cld
  fill1:
    push    rcx
    push    rsi
    mov     ecx, BMP_MT_WIDTH * BPP
    rep     movsb
    pop     rsi
    add     esi, ((BMP_MT_WIDTH * BPP) + 3) and 0xFFFC
    pop     rcx
    loop    fill1

    ; Add 1 centre bar for each option to be displayed
    mov     ecx, [numOptions]
    dec     ecx
    cmp     [position],byte 0
    je      noecxadd2
    add     ecx , 2
  noecxadd2:

  fill2_1:
    push    rcx

    mov     ecx, BMP_MC_DEPTH
    add     [menuDepth], ecx
    mov     esi, BMP_MC + BMPHEADER

  fill2:
    push    rcx
    push    rsi
    mov     ecx, BMP_MC_WIDTH * BPP
    rep     movsb
    pop     rsi
    add     esi, ((BMP_MC_WIDTH * BPP) + 3) and 0xFFFC
    pop     rcx
    loop    fill2
    pop     rcx
    loop    fill2_1

    cmp     [position],byte 1
    je      noending

    mov     ecx, BMP_MB_DEPTH
    add     [menuDepth], ecx
    mov     esi, BMP_MB + BMPHEADER

  fill3:
    push    rcx
    push    rsi
    mov     ecx, BMP_MB_WIDTH * BPP
    rep     movsb
    pop     rsi
    add     esi, ((BMP_MB_WIDTH * BPP) + 3) and 0xFFFC
    pop     rcx
    loop    fill3

  noending:

    ; Menu position down

    cmp     [position],byte 1
    jne     nomenudown2

    cmp     [params],dword 'SUBM'
    jne     nossub
    sub     [menuDepth],dword 13 + 14

    mov     eax , [menuDepth]
    sub     rax , 2
    imul    rax , 3*MENU_WIDTH
    mov     rcx , MENU_WIDTH*2
  graydown:
    mov     [MENU_IMAGE+rax],dword 0xd0d0d0
    add     rax , 3
    loop    graydown

  nossub:

    cmp     [params],dword 'MAIN'
    jne     nodsub

    sub     [menuDepth],dword 19 + 14

    mov     edx , [menuDepth]
    sub     edx , 312
    sub     [startY],edx

  nodsub:

    cmp     [params],dword 'MAIN'
    je      nomenudown21

    mov     edx , [menuDepth]
    mov     ecx , [startY]
    sub     ecx , edx
    add     ecx , 34 - 3 - 13

    ; Drop menu to match line
    cmp     ecx , 10000
    jb      startyfine
    cmp     [menuDepth],dword 400
    jb      startyfine
    add     ecx , BMP_MC_DEPTH
  startyfine:
    ;

    mov    [startY],ecx

  nomenudown21:
  nomenudown2:

    ret


;***************************************************************************
;   Function
;      setWindowForm
;
;   Description
;       Scans the panel image looking for the curved outline, so it can
;       generate a free-form outline window
;
;***************************************************************************
setWindowForm:

    ; Create the free-form pixel map;
    ; black is the 'ignore' colour

    mov     esi,0
    mov     edx, [menuDepth]
    imul    edx, MENU_WIDTH

  newpix:

    mov     eax,[ MENU_IMAGE + esi*BPP]
    mov     bl,0
    and     eax,0xffffff
    cmp     eax,0x000000
    je      cred
    mov     bl,1

  cred:

    mov     [esi+ MENU_AREA ],bl
    inc     esi
    cmp     esi,edx
    jbe     newpix

    ; Set the free-form window in the OS

    mov  eax,50
    mov  ebx,0
    mov  ecx,MENU_AREA
    int  0x40

    ret



;***************************************************************************
;   Function
;      readBitmaps
;
;   Description
;       Loads the picture elements used to construct the panel image
;
;***************************************************************************
readBitmaps:
    ; Main panel button, plus curves
    mov     eax, 58
    mov     ebx, mt
    cmp     [menuType], byte 'M'
    je     @f
    mov     ebx, mtf
  @@:
    int     0x40

    ; Load panel background
    mov   eax, 58
    mov   ebx, mc
    int   0x40
    ; Stretch the image to 34 lines
    mov   rsi, BMP_MC + BMPHEADER
    mov   rdi , rsi
    add   rdi , MENU_WIDTH*3+2
    mov   rcx , MENU_WIDTH*3*34
    cld
    rep   movsb

    ; Load panel ending image
    mov   eax, 58
    mov   ebx, mb
    int   0x40
    ; Stretch the image
    mov   rsi , BMP_MB+BMPHEADER+(54-25)*(3*MENU_WIDTH+2)
    mov   rdi , rsi
    add   rsi , 3*MENU_WIDTH+2
    mov   rcx , (54-25)*(3*MENU_WIDTH+2)
    std
    rep   movsb
    cld

    ret



;***************************************************************************
;   Function
;      readMenuOptions
;
;   Description
;       using the application input parameter I-Param ( which specifies
;       the name of the menu ), builds the list of menu options.
;       This list is used to determine the size of the menu and the
;       icons, text that appear on the menu.
;       This updates numOptions and optionsList
;       I hate reading text files :o)
;
;***************************************************************************
readMenuOptions:
    xor     eax, eax
    mov     [numOptions], eax           ; Start with a empty list

    mov     eax, 58
    mov     ebx, optionsf
    int     0x40

    cld
    mov     esi, OPTIONSFILE

    ; Skip through the file to our menu list, as defined by I_Params

  rmo000a:
    mov     edi, I_Param

  rmo000:
    inc     esi
    cmp     [esi-1], byte '['
    je      rmo001
    jmp     rmo000

  rmo001:
    cmpsb
    je      rmo001
    ; If the last character was ], we have a match
    cmp     [esi-1],byte ']'
    jne     rmo000a                     ; No? Then look for next
    cmp     [edi-1],byte '0'
    jae     rmo000a


    ; Build menu table list
    mov     edi, MENUTABLE
  rmoLoop:
    ; Found correct submenu.
    ; Skip any whitespace or comments, to get to first character of option
    call    skipWhite
    call    nextLine
    call    findParam
    cmp     [esi], byte '['             ; Have we come to the end of the list?
    je      rmoExit                     ; Yes, so we have finished

    ; Add menu item into the list
    inc     dword [numOptions]

    ; MENUTABLE is an array of menu options
    ; the format is
    ; dd pointer to menu text, asciiz
    ; dd pointer to option type string, asciiz
    ; dd pointer to menu icon string, ascii z
    ; dd pointer to appname or submenu name, asciiz

    virtual at edi
      mtext  dd ?
      mopt   dd ?
      micon  dd ?
      mname  dd ?
    end virtual

    mov     [mtext], esi                ; Mark start of text string

  rmo002:
    inc     esi
    cmp     [esi-1], byte ','
    jne     rmo002

    mov     [esi-1], byte 0             ; zero terminate ascii string
    call    skipWhite
    mov     [mopt], esi                ; Mark start of text string

  rmo003:
    inc     esi
    cmp     [esi-1], byte ','
    jne     rmo003

    mov     [esi-1], byte 0             ; zero terminate ascii string
    call    skipWhite
    mov     [micon], esi                ; Mark start of text string

  rmo004:
    inc     esi
    cmp     [esi-1], byte ','
    jne     rmo004

    mov     [esi-1], byte 0             ; zero terminate ascii string
    call    skipWhite
    mov     [mname], esi                ; Mark start of text string

    ; Finially, find the end of the line, and zero terminate it
  rmo005:
    inc     esi
    cmp     [esi], byte 0x0a
    je      rmo006
    cmp     [esi], byte 0x0d
    je      rmo006
    cmp     [esi], byte 0x09
    je      rmo006
    cmp     [esi], byte ' '
    je      rmo006
    jmp     rmo005

  rmo006:
    mov     [esi], byte 0             ; zero terminate ascii string

    add     edi, 16
    jmp     rmoLoop

  rmoExit:
    ret



;***************************************************************************
;   Function
;       skipWhite
;
;   Description
;       skips any tabs or spaces
;
;***************************************************************************
skipWhite:
    mov     al, [esi]
    cmp     al, ' '
    je      sw002                   ; skip space char
    cmp     al, 0x09
    je      sw002                   ; skip tab char
    ret

  sw002:
    inc     esi
    jmp     skipWhite



;***************************************************************************
;   Function
;       nextLine
;
;   Description
;       skips to the beginning of the next line
;
;***************************************************************************
nextLine:
    mov     al, [esi]
    cmp     al, 0x0a
    je      nl002           ; We have reached the end
    cmp     al, 0x0d
    je      nl002
    inc     esi
    jmp     nextLine

  nl002:                    ; Now skip the CR/LF bits
    inc     esi
    mov     al, [esi]
    cmp     al, 0x0a
    je      nl003
    cmp     al, 0x0d
    je      nl003
    ret                     ; Now at start of new line

  nl003:
    inc     esi
    ret                     ; Now at start of new line



;***************************************************************************
;   Function
;       findParam
;
;   Description
;       skips comments and blank lines until the next parameter if found
;       source is in esi; dont touch edi
;
;***************************************************************************
findParam:
    mov     al, [esi]               ; get file character

    ; is it a comment line?
    cmp     al, '#'
    jne     fp002

    call    nextLine                ; Move to next line
    jmp     findParam

  fp002:
    call    skipWhite               ; Move past any spaces

    ; Was it an empty line?
    mov     al, [esi]
    cmp     al, 0x0a
    je      fp003
    cmp     al, 0x0d
    je      fp003
    ret                             ; We have the parameter!

  fp003:
    ; It was an empty line; Read past the end of line marker
    ; and return to findParam for next line
    inc     esi
    mov     al, [esi]
    cmp     al, 0x0a
    je      fp004
    cmp     al, 0x0d
    je      fp004
    jmp     findParam

  fp004:
    inc     esi
    jmp     findParam



draw_window:

    mov     eax,12
    mov     ebx,1
    int     0x40

    ; Get configuration parameter
    mov     rax , 112
    mov     rbx , 2
    mov     rcx , string_main_menu_font
    mov     rdx , 0
    mov     r8  , 0xfffff
    int     0x60
    mov     [fonttype],rbx

    ; Draw window area

    mov     rax , 0
    mov     ebx , [startX]
    dec     rbx
    shl     rbx , 32
    add     rbx , MENU_WIDTH
    mov     ecx , [startY]
    shl     rcx , 32
    movzx   rdx , word [menuDepth]
    add     rcx , rdx
    mov     rdx , 1 shl 32 + 1 shl 63
    mov     r8  , 0
    mov     r9  , 0
    mov     r10 , 0
    int     0x60

    ; Define buttons

    mov     rcx, [numOptions]
    mov     rax, 8
    mov     rbx, 0 + MENU_WIDTH
    mov     rdx, 0x000000
    mov     r8 , 0x6688dd + 1 shl 61 + 1 shl 63
    mov     rdi, BMP_MT_DEPTH shl 32+ 34
    cmp     [menuType], byte 'M'
    je      dw001
    mov     rdi, BMP_MTF_DEPTH shl 32+ 34
  dw001:
    push    rax rbx rcx rdx rsi rdi
    mov     rcx,rdi
    mov     r9 , 0
    int     0x60
    pop     rdi rsi rdx rcx rbx rax
    mov     r10 , 34 shl 32
    add     rdi, r10
    add     rdx, 16
    loop    dw001

    ; Draw window image

    mov     rax , 7
    mov     rbx , MENU_WIDTH
    mov     rcx , [menuDepth]
    and     rcx , 0xffffff
    mov     rdx , MENU_IMAGE
    mov     r8  , 0
    mov     r9  , 0x000000
    mov     r10 , 3
    int     0x60

    ; Add text labels

    mov     ecx, [numOptions]
    mov     edi, MENUTABLE
    mov     eax, 4
    mov     ebx, textposx * 65536 + 32
    cmp     [menuType], byte 'M'
    je      dwText
    mov     ebx, textposx * 65536 + 20
  dwText:
    push    rax rbx rcx rdx rsi rdi
    mov     edx, [edi]
    call    strLen
    mov     rcx , rbx
    shr     rcx , 16
    mov     rdx , rbx
    and     rdx , 0xffff
    mov     rax , 4
    mov     rbx ,[rdi]
    and     rbx , 0xffffff
    mov     r9  , 1
    mov     rsi , 0x000000
    call    adjust_string
    mov     rbx , adjusted_str
    int     0x60
    pop     rdi rsi rdx rcx rbx rax
    add     ebx, 34
    add     edi, 16
    loop    dwText

    mov     eax,12
    mov     ebx,2
    int     0x40

    ret

adjust_string:

    push    r15
    push    rsi

    push    rdi rcx
    mov     rsi , rbx
    mov     rdi , adjusted_str
    mov     rcx , 50
    cld
    rep     movsb
    pop     rcx rdi

    cmp     [fonttype],dword 0
    je      nofadjust

    mov     rsi , adjusted_str

    cmp     [rsi],byte 0
    je      nofadjust

    mov     r15 , 0

    cmp     [fonttype],dword 1
    jne     noftype1
    inc     rsi
    cmp     [rsi],byte 0
    je      nofadjust
  noftype1:

  newadjust:

    cmp     [rsi],byte 0
    je      nofadjust
    cmp     r15 , 1
    je      noadj2
    cmp     [rsi],byte 'A'
    jb      noadj
    cmp     [rsi],byte 'Z'+3
    ja      noadj
    add     [rsi],byte 32
    jmp     noadj2
  noadj:
    ;cmp     [rsi],byte '.'
    ;je      noadj2
    cmp     [fonttype],byte 2
    je      noadj2
    mov     r15 , 2
  noadj2:
    cmp     r15 , 0
    je      nor15dec
    dec     r15
  nor15dec:
    inc     rsi
    jmp     newadjust

  nofadjust:

    pop     rsi
    pop     r15

    ret



;***************************************************************************
;   Function
;      strLen
;
;   Description
;       Optimised to work with drawText: Returns length of string
;       string pointed to by edx
;       result in esi
;       ecx used as temp variable
;
;***************************************************************************
strLen:

    mov     esi, edx
    dec     esi
  sl000:
    inc     esi
    cmp     [esi], byte 0
    jne     sl000
    sub     esi, edx

    ret


;***************************************************************************
;   Function
;      drawIcon
;
;   Description
;       Loads an icon file ( fname ) and renders it into the menu image
;       at the current position.
;       The icon must be 32x32, 24 bit colour. If it is a .ico file, It must
;       have an alpha channel, although it isn't used.
;
;       This is mike.dld's code, ripped from icon.asm
;
;       icon file name pointed to by esi
;       top left position to display icon in edi
;
;***************************************************************************
drawIcon:

    push    rdi

    ; Copy the filename across

    mov     edi, tmpfn
    mov     ecx, 256
    cld
    rep     movsb

    xor     eax, eax
    mov     [tmpf], eax
    mov     [tmpf+4], eax
    dec     eax
    mov     [tmpf+8], eax
    mov     eax, ICON_FILE
    mov     [tmpf+12], eax

    ; Read the .ico or .bmp file
    mov     eax, 58
    mov     ebx, tmpf
    int     0x40

    ; What type of image file is it?
    mov     [itype],0
    cmp     word[ICON_FILE],'BM'
    je      @f
    inc     [itype]
  @@:

    pop     rsi
    mov     ecx, esi

    ; esi points to menu image top left position
    ; We point to the end since the icon image is 'upside down'
    add     esi, (MENU_WIDTH * 32 * BPP)

    ; edi scans through icon image
    mov     edi,ICON_FILE+62 ; 6 - header, 16 - iconinfo, 40 - bitmapinfo
    cmp     [itype],0
    jne     @f
    mov     edi,ICON_FILE+54
  @@:
    xor     ebp,ebp

  l00:
    push    rcx

    virtual at edi
      r  db ?
      g  db ?
      b  db ?
      a  db ?
    end virtual

    virtual at esi+ebp
      ar db ?
      ag db ?
      ab db ?
    end virtual

    movzx   cx,[a]

    cmp     [itype],0
    jne     @f
    mov     eax,[edi]
    and     eax,0x00ffffff
    test    eax,eax
    jnz     @f
    mov     al,[ar]
    mov     [esi+ebp+0],al
    mov     al,[ag]
    mov     [esi+ebp+1],al
    mov     al,[ab]
    mov     [esi+ebp+2],al
    jmp     no_transp
  @@:

    xor     eax,eax
    mov     al,[r]
    cmp     [itype],0
    je      @f
    movzx   bx,[ar]
    sub     ax,bx
    mov     bx,cx
    imul    bx
    xor     edx,edx
    mov     bx,255
    div     bx
    movzx   ebx,[ar]
    add     eax,ebx
  @@:
    mov     [esi+ebp+0],al

    xor     eax,eax
    mov     al,[g]
    cmp     [itype],0
    je      @f
    movzx   bx,[ag]
    sub     ax,bx
    mov     bx,cx
    imul    bx
    xor     edx,edx
    mov     bx,255
    div     bx
    movzx   bx,[ag]
    add     eax,ebx
  @@:
    mov     [esi+ebp+1],al

    xor     eax,eax
    mov     al,[b]
    cmp     [itype],0
    je      @f
    movzx   bx,[ab]
    sub     ax,bx
    mov     bx,cx
    imul    bx
    xor     edx,edx
    mov     bx,255
    div     bx
    movzx   bx,[ab]
    add     eax,ebx
  @@:
    mov     [esi+ebp+2],al

  no_transp:
    pop     rcx
    add     edi,3
    add     edi,[itype]

    add     ebp,3
    cmp     ebp,32*3
    jl      l00

    xor     ebp,ebp

    sub     esi,MENU_WIDTH * BPP
    cmp     esi, ecx
    jg      l00

    ret



;***************************************************************************
;   Function
;      renderIcons
;
;   Description
;       Reads the icon images and renders them into the menu bitmap
;
;***************************************************************************
renderIcons:

    mov     ecx, [numOptions]
    mov     esi, MENUTABLE + 8 ; Offset to menu icon filename
    mov     edi, MENU_IMAGE + (iconposx + (BMP_MT_DEPTH * MENU_WIDTH)) * BPP
    cmp     [menuType], byte 'M'
    je     @f
    mov     edi, MENU_IMAGE + (iconposx + (BMP_MTF_DEPTH * MENU_WIDTH)) * BPP
  @@:

  ri001:
    push    rax rbx rcx rdx rsi rdi
    mov     esi, [esi]
    call    drawIcon
    pop     rdi rsi rdx rcx rbx rax
    add     esi, 16
    add     edi, 34 * MENU_WIDTH * BPP
    loop    ri001

    ret


;
; Data area
;

childPID    dd  0
fonttype:   dq  0
position:   dq  0    ; 0=up,1=down
lastButton  dd  -1
startX:     dd  0    ; Place to draw menu
startY:     dd  0
newX:       dd  0
newY:       dd  0
menuType:   db  0    ; 0 == main, 1 == sub
menuDepth:  dd  0    ; Real depth of menu
numOptions: dd  5    ; Number of menu options ( 5 is test )
itype       dd  0
appname     db  '            ' ;

received_messages:

    dq  0,16,0,0,0,0

string_main_menu_font:

    db 'main_menu_font         ',0

mtf:
    dd  0
    dd  0
    dd  -1                          ; Amount to load - all of it
    dd  BMP_MT                      ; Place to store file data
    dd  OSWORKAREA                  ; os work area - 16KB
    db  '/fd/1/mtf.bmp',0

mt:
    dd  0
    dd  0
    dd  -1                          ; Amount to load - all of it
    dd  BMP_MT                      ; Place to store file data
    dd  OSWORKAREA                  ; os work area - 16KB
    db  '/fd/1/mt.bmp',0

mc:
    dd  0
    dd  0
    dd  -1                          ; Amount to load - all of it
    dd  BMP_MC                      ; Place to store file data
    dd  OSWORKAREA                  ; os work area - 16KB
    db  '/fd/1/mb.bmp',0

mb:
    dd  0
    dd  0
    dd  -1                          ; Amount to load - all of it
    dd  BMP_MB + (54-25)*(3*MENU_WIDTH+2)  ; Place to store file data
    dd  OSWORKAREA                  ; os work area - 16KB
    db  '/fd/1/mb.bmp',0

optionsf:
    dd  0
    dd  0
    dd  -1                          ; Amount to load - all of it
    dd  OPTIONSFILE                 ; Place to store file data
    dd  OSWORKAREA                  ; os work area - 16KB
    db  '/fd/1/menu.mnt',0

tmpf:
    dd  0
    dd  0
    dd  -1                          ; Amount to load - all of it
    dd  ICON_FILE                   ; Place to store file data
    dd  OSWORKAREA                  ; os work area - 16KB
tmpfn:
    times 256 db 0                  ; space for the filename

startfile:
    dd  16                          ; Start file option
    dd  0                           ; Reserved, 0
    dd  params                      ; Parameters
    dd  0                           ; Reserved, 0
    dd  OSWORKAREA                  ; OS work area - 16KB
startfile2:
    db  '/FD/1/MMENU',0

dq 20     ; Length of parameter area
params:   ; Shared with I_Params
I_Param:  ; 256 bytes

db   'MAINMENU 9 28',0

I_END:

