;--------------------------------------------
;*** Fisheye Raycasting Engine Etc. V.0.4 ***
;--------------------------------------------
;
;For the MenuetOs Operating System.
;Assembler-Source for FASM for MenuetOs.
;
;By Dieter Marfurt
;
;--------------------------------------------
;
;Format of texture include files:
;
;dd 0x00RRGGBB,0x00RRGGBB....
;
;for 64*64 pixels.
;
;Have fun!
;
;dietermarfurt@angelfire.com
;
;--------------------------------------------

; Fisheye Raycasting Engine Etc. FREE3D for MENUETOS by Dieter Marfurt
; Version 0.4 (requires some texture-files to compile (see Data Section))
; dietermarfurt@angelfire.com - www.melog.ch/mos_pub/
; Don't hit me - I'm an ASM-Newbie... since years :)
;
; Compile with FASM for Menuet
; Menuet 64 bit port by Ville Turjanmaa
; For include files, see http://www.menuetos.org/applics.html

wallimg1 equ (wallimgs+12288*0)
wallimg4 equ (wallimgs+12288*1)
wallimg6 equ (wallimgs+12288*2)
wallimg7 equ (wallimgs+12288*3)

game_x_size      equ 640
game_y_size      equ 480
game_y_size_half equ (game_y_size/2)
game_x_size_half equ (game_x_size/2)
game_y_sub       equ ((480-game_y_size)/2)

use64

org    0x0

    db    'MENUET64'              ; Header identifier
    dq    0x01                    ; Version
    dq    START                   ; Start of code
    dq    I_END                   ; Size of image
    dq    0x200000                ; Memory for app
    dq    stack_position          ; Rsp
    dq    0x00                    ; Prm
    dq    0x00                    ; Icon


START:                          ; start of execution

    call  load_image

    mov   rax , 26              ; Get system info
    mov   rbx , 3               ; 3 boot info, resolution
    mov   rcx , boot_info_base
    mov   rdx , 128
    int   0x60

    call  img2dd

    call draw_window            ; at first, draw the window
    call draw_stuff

gamestart:

    ;******* MOUSE CHECK *******

    mov rax,37
    mov rbx,1     ; check mouseposition
    int 0x60

    mov rbx,rax
    shr rax,32
    and rax,0x0000FFFF  ; mousex
    and rbx,0x0000FFFF  ; mousey

    cmp eax,5  ; mouse out of window ?
    jb check_refresh  ; it will prevent an app-crash
    cmp ebx,22
    jb check_refresh
    cmp eax, game_x_size+10
    jg check_refresh
    cmp ebx,game_y_size+25
    jg check_refresh

    cmp eax,game_x_size_half -5 ; navigating?
    jb m_left
    cmp eax,game_x_size_half +5 ;
    jg m_right
continue:
    cmp ebx,game_y_size_half -20 ;
    jb s_up
    cmp ebx,game_y_size_half +20 ;
    jg s_down

    ;******* END OF MOUSE CHECK *******

check_refresh:

    mov  rax,11 ; ask no wait for full speed
    int  0x60

    test eax,1                  ; window redraw request ?
    jnz  red2
    test eax,2                  ; key in buffer ?
    jnz  key2
    test eax,4                  ; button in buffer ?
    jnz  button2

    mov edi,[mouseya] ; check flag if a refresh has to be done
    cmp edi,1
    jne gamestart
    mov [mouseya],dword 0
    call draw_stuff

    jmp gamestart

    ;END OF MAINLOOP

red2:

    call draw_window
    call draw_stuff
    jmp  gamestart

key2:

    mov  rax,2
    int  0x60

    jmp  finish

    ;cmp  al,1
    ;je   gamestart ; keybuffer empty
    ;cmp ah,27    ; esc=End App
    ;je  finish
    ;cmp  ah,178  ; up
    ;je   s_up
    ;cmp  ah,177  ; down
    ;je   s_down
    ;cmp  ah,176  ; left
    ;je   s_left
    ;cmp  ah,179  ; right
    ;je   s_right
    ;jmp gamestart ; was any other key

s_up:             ; walk forward (key or mouse)

    mov eax,[vpx]
    mov ebx,[vpy]

    mov ecx,[vheading]
    imul ecx,4
    add ecx,sinus
    mov edi,[ecx]

    mov edx,[vheading]
    imul edx,4
    add edx,sinus
    add edx,3600
    cmp edx,eosinus ;cosinus taken from (sinus plus 900) mod 3600
    jb ok200
    sub edx,14400 ; game_y_size*30
    ok200:
    mov esi,[edx]

    ;sal esi,1  ; edit walking speed here
    ;sal edi,1

    add eax,edi ; newPx
    add ebx,esi ; newPy
    mov edi,eax ; newPx / ffff
    mov esi,ebx ; newPy / ffff
    sar edi,16
    sar esi,16
    mov ecx,esi
    sal ecx,5 ; equal *32
    add ecx,edi
    add ecx,grid
    cmp [ecx],byte 0  ; collision check
    jne cannotwalk0
    mov [vpx],eax
    mov [vpy],ebx
    mov [mouseya],dword 1 ; set refresh flag
cannotwalk0:
    jmp check_refresh

s_down:                    ; walk backward

    mov eax,[vpx]
    mov ebx,[vpy]

    mov ecx,[vheading]
    imul ecx,4
    add ecx,sinus
    mov edi,[ecx]

    mov edx,[vheading]
    imul edx,4
    add edx,sinus
    add edx,3600
    cmp edx,eosinus ;cosinus taken from (sinus plus 900) mod 3600
    jb ok201
    sub edx,14400 ; game_y_size*30
  ok201:

    mov esi,[edx]

    ;sal esi,1  ; edit walking speed here
    ;sal edi,1

    sub eax,edi ; newPx
    sub ebx,esi ; newPy
    mov edi,eax ; newPx / ffff
    mov esi,ebx ; newPy / ffff
    sar edi,16
    sar esi,16
    mov ecx,esi
    sal ecx,5
    add ecx,edi
    add ecx,grid
    cmp [ecx],byte 0
    jne cannotwalk1
    mov [vpx],eax
    mov [vpy],ebx
    mov [mouseya],dword 1
cannotwalk1:
    jmp check_refresh

s_left:                                   ; turn left (key)
    mov edi,[vheading]  ; heading
    add edi,100 ; 50
    cmp edi,3600
    jb ok_heading0
    sub edi,3600
    ok_heading0:
    mov [vheading],edi
    mov [mouseya],dword 1
    jmp check_refresh

s_right:                                  ; turn right
    mov edi,[vheading]
    sub edi,100 ; 50
    cmp edi,-1
    jg ok_heading1
    add edi,3600
    ok_heading1:
    mov [vheading],edi
    mov [mouseya],dword 1
    jmp check_refresh

m_left:                                   ; turn left (mouse)
    mov edi,[vheading]  ; heading
    mov ecx,game_x_size_half-5
    sub ecx,eax
    sar ecx,2
    add edi,ecx
    cmp edi,3600
    jb ok_heading2
    sub edi,3600
    ok_heading2:
    mov [vheading],edi
    mov [mouseya],dword 1
    jmp continue    ; allow both: walk and rotate

m_right:                                  ; turn right
    mov edi,[vheading]
    sub eax,game_x_size_half+5
    sar eax,2
    sub edi,eax
    cmp edi,-1
    jg ok_heading3
    add edi,3600
    ok_heading3:
    mov [vheading],edi
    mov [mouseya],dword 1
    jmp continue

  button2:                       ; button

    mov  rax,17                  ; get id
    int  0x60

  finish:

    mov  rax,512                 ; close this program
    int  0x60


draw_window:

    mov   rax , 0xC
    mov   rbx , 0x1
    int   0x60

    mov   rax , 0x0
    mov   rbx , 100*0x100000000 + game_x_size +10
    mov   rcx , 100*0x100000000 + game_y_size +28
    mov   rdx , 0x0000000000FFFFFF
    mov   r8  , 0x0000000000000001
    mov   r9  , window_label
    mov   r10 , 0
    int   0x60

    mov   rax , 0xC
    mov   rbx , 0x2
    int   0x60

    ret

; COMPUTE 3D-VIEW

draw_stuff:

    mov [step1],dword 1
    ;mov [step64],dword 64
    mov esi,[vheading]
    add esi,game_x_size_half
    mov [va],esi
    mov eax,[vheading]
    sub eax,game_x_size_half
    mov [vacompare],eax

;------------------------------------ CAST 640 PIXEL COLUMNS ---------------
; FOR A=320+heading to -319+heading step -1 (a is stored in [va])
;---------------------------------------------------------------------------
;    mov edx,5

    mov [vx1],dword 0  ;5  ;edx        ; init x1 ... pixelcolumn
for_a:
    mov edx,[vx1]
    mov [vx1b],edx
    sub [vx1b],dword game_x_size_half
    mov edx,[va] ; a2
    cmp edx,-1   ; a2 is a mod 3600
    jg ok1
    add edx,3600
ok1:
    cmp edx,3600
    jb ok2
    sub edx,3600
ok2:

    ; get stepx and stepy
    mov ecx,edx
    imul ecx,4
    add ecx,sinus     ; pointer to stepx
    mov esi,[ecx]
    sar esi,4         ; accuracy
    mov [vstepx],esi  ; store stepx

    mov esi,edx
    imul esi,4
    add esi,sinus  ; pointer to stepy
    add esi,3600
    cmp esi,eosinus ;cosinus taken from ((sinus plus 900) mod 3600)
    jb ok202
    sub esi,14400 ; game_y_size*30
    ok202:

    mov ecx,[esi]
    sar ecx,4
    mov [vstepy],ecx ; store stepy

    mov eax,[vpx]    ; get Camera Position
    mov ebx,[vpy]
    mov [vxx],eax    ; init caster position
    mov [vyy],ebx

    mov edi,0        ; init L (number of raycsting-steps)
    mov [step1],dword 1  ; init Caster stepwidth for L

    ;raycast a pixel column.................................
raycast:
    add edi,[step1]  ; count caster steps

    ;jmp nodouble ; use this to prevent blinking/wobbling textures: much slower!

    cmp edi,32
    je double
    cmp edi,512
    je double
    cmp edi,1024
    je double
    jmp nodouble

    double:
    mov edx,[step1]
    sal edx,1
    mov [step1],edx

    mov edx,[vstepx]
    sal edx,1
    mov [vstepx],edx

    mov edx,[vstepy]
    sal edx,1
    mov [vstepy],edx

nodouble:

    mov eax,32000 ; 3600 ; determine Floors Height based on distance
    mov edx,0
    mov ebx,edi

    div ebx
    mov esi,eax
    mov [vdd],esi
    mov edx,260
    sub edx,esi
    mov [vh],edx

    cmp edx,22
    jb no_nu_pixel
    cmp edx,259
    jg no_nu_pixel ; draw only new pixels
    cmp edx,[h_old]
    je no_nu_pixel

    mov eax,[vxx] ; calc floor pixel
    mov ebx,[vyy]

    and eax,0x0000FFFF
    and ebx,0x0000FFFF

    shr eax,10
    shr ebx,10    ; pixel coords inside Texture x,y 64*64
    mov [xfrac],eax
    mov [yfrac],ebx

    ; plot floor pixel
    mov [vl],edi    ; save L
    mov [ytemp],esi ; remember L bzw. H

    mov edi,[yfrac] ; get pixel color of this floor pixel
    sal edi,8
    mov esi,[xfrac]
    sal esi,2
    add edi,esi
    add edi,wall ; in fact its floor, just using the wall texture :)
    mov edx,[edi]
    mov [remesi],esi

    ;calculate pixel adress

    mov esi,[ytemp]
    add esi,game_y_size_half
    imul esi,game_x_size*3

    add esi,[vx1]
    add esi,[vx1]
    add esi,[vx1]

    add esi,[vx1]
    add esi,[vx1]
    add esi,[vx1]

    add esi,gameimage

    cmp esi,gameimage+game_x_size*3*game_y_size
    jg foff0
    cmp esi,gameimage
    jb foff0
    ; now we have the adress of the floor-pixel color in edi
    ; and the adress of the pixel in the image in esi

    mov edx,[edi]
    ;custom distance DARKEN Floor

    mov eax,[vdd]

    ;jmp nodark0 ; use this to deactivate darkening floor (a bit faster)

    cmp eax,80
    jg nodark0
    ;                split rgb

    mov [blue],edx
    and [blue],dword 255

    shr edx,8
    mov [green],edx
    and [green],dword 255

    shr edx,8
    mov [red],edx
    and [red],dword 255

    mov eax,81    ; darkness parameter
    sub eax,[vdd]
    sal eax,1

    ;reduce rgb
    sub [red],eax
    cmp [red], dword 0
    jg notblack10
    mov [red],dword 0
    notblack10:

    sub [green],eax
    cmp [green],dword 0
    jg notblack20
    mov [green],dword 0
    notblack20:

    mov edx,[blue]
    sub [blue],eax
    cmp [blue],dword 0
    jg notblack30
    mov [blue],dword 0
    notblack30:

    shl dword [red],16  ; reassemble rgb
    shl dword [green],8
    mov edx,[red]
    or edx,[green]
    or edx,[blue]

nodark0:
    ;eo custom darken floor

    mov eax,edx
    mov [esi],eax   ;actually draw the floor pixel
    mov [esi+3],eax ;?

    ;paint "forgotten" pixels

    mov edx,[lasty]
    sub edx,game_x_size*3
    cmp esi,edx
    je foff0
    mov [esi+game_x_size*3],eax
    mov [esi+game_x_size*3+3],eax

    sub edx,game_x_size*3
    cmp esi,edx
    je foff0
    mov [edx+game_x_size*3],eax
    mov [edx+game_x_size*3+3],eax

    sub edx,game_x_size*3
    cmp esi,edx
    je foff0
    mov [edx+game_x_size*3],eax
    mov [edx+game_x_size*3+3],eax

foff0:

    mov [lasty],esi
    ;end of draw floor pixel

    mov esi,[remesi]
    mov edi,[vl] ; restore L

no_nu_pixel:

    mov esi,[vh]
    mov [h_old],esi

    mov eax,[vxx]
    mov ebx,[vyy]

    add eax,[vstepx]  ; casting...
    add ebx,[vstepy]

    mov [vxx],eax
    mov [vyy],ebx

    sar eax,16
    sar ebx,16

    mov [vpxi],eax    ; casters position in Map Grid
    mov [vpyi],ebx

    mov edx,ebx
    ;imul edx,32
    shl edx,5
    add edx,grid
    add edx,eax
    cmp [edx],byte 0   ; raycaster reached a wall? (0=no)
    jne getout
    cmp edi,10000        ; limit view range
    jb raycast

    ;................................................

getout:

    mov eax,[edx]      ; store Grid Wall Value for Texture Selection
    mov [vk],eax

    call blur  ; deactivate this (blurs the near floor) : a bit faster

    ;simply copy floor to ceil pixel column here
    ;jmp nocopy ; use this for test purposes

    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push rbp

    mov eax,gameimage+game_x_size*3*game_y_size_half
    mov ebx,gameimage+game_x_size*3*game_y_size_half

copyfloor:

    sub eax,game_x_size*3
    add ebx,game_x_size*3

    mov ecx,0

    add ecx,[vx1]
    add ecx,[vx1]
    add ecx,[vx1]

    add ecx,[vx1] ;
    add ecx,[vx1]
    add ecx,[vx1]

    mov edx,ecx
    add ecx,eax
    add edx,ebx

    mov esi,[edx]
    mov [ecx],esi

    mov [ecx+3],esi  ;

    cmp eax,gameimage
    jg copyfloor

    pop rbp
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax

    ;end of copy floor to ceil
    ;nocopy:
    ;draw this pixelrows wall

    mov [vl],edi

    mov edi,260 -game_y_sub
    sub edi,[vdd]
    cmp edi,0
    jg ok3
    xor edi,edi
    ok3:
    mov [vbottom],edi  ; end wall ceil (or window top)

    mov esi,262 -game_y_sub
    add esi,[vdd]  ; start wall floor

    xor edi,edi

    ;somethin is wrong with xfrac,so recalc...

    mov eax,[vxx]
    and eax,0x0000FFFF
    shr eax,10
    mov [xfrac],eax

    mov eax,[vyy]
    and eax,0x0000FFFF
    shr eax,10
    mov [yfrac],eax

  pixelrow:

    ;find each pixels color:

    add edi,64
    sub esi,1
    cmp esi, 502 -game_y_sub ; dont calc offscreen-pixels
    jg speedup

    xor edx,edx
    mov eax, edi
    mov ebx,[vdd]
    add ebx,[vdd]
    div ebx
    and eax,63
    mov [ytemp],eax   ; get y of texture for wall

    mov eax,[xfrac]
    add eax,[yfrac]

    and eax,63
    mov [xtemp],eax   ; get x of texture for wall

    ; now prepare to plot that wall-pixel...
    mov [remedi],edi

    mov edi,[ytemp]
    sal edi,8
    mov edx,[xtemp]
    sal edx,2
    add edi,edx

    mov eax,[vk] ; determine which texture should be used
    and eax,255

    cmp eax,1
    jne checkmore1
    add edi,ceil
    jmp foundtex
    checkmore1:

    cmp eax,2
    jne checkmore2
    add edi,wall
    jmp foundtex
    checkmore2:

    cmp eax,3
    jne checkmore3
    add edi,wall2
    jmp foundtex
    checkmore3:

    cmp eax,4
    jne checkmore4
    add edi,wall3
    jmp foundtex
    checkmore4:

    cmp eax,5
    jne checkmore5
    add edi,wall4
    jmp foundtex
    checkmore5:

    cmp eax,6
    jne checkmore6
    add edi,wall5
    jmp foundtex
    checkmore6:

    cmp eax,7
    jne checkmore7
    add edi,wall6
    jmp foundtex
    checkmore7:

    cmp eax,8
    jne checkmore8
    add edi,wall7
    jmp foundtex
    checkmore8:

  foundtex:

    mov edx,[edi]    ; get pixel color inside texture

    ;pseudoshade south-west

    jmp east ; activate this for southwest pseudoshade : a bit slower + blink-bug
    mov edi,[yfrac]
    mov [pseudo],dword 0 ; store flag for custom distance darkening
    cmp edi,[xfrac]
    jge east
    and edx,0x00FEFEFE
    shr edx,1
    mov [pseudo],dword 1
  east:

    call dark_distance ; deactivate wall distance darkening: a bit faster

    ;DRAW WALL PIXEL
    mov eax,esi
    sub eax,22
    imul eax,game_x_size*3
    add eax,[vx1]
    add eax,[vx1]
    add eax,[vx1]
    add eax,[vx1]  ; ?
    add eax,[vx1]
    add eax,[vx1]

    add eax,gameimage

    cmp eax,gameimage+game_x_size*3*game_y_size
    jg dont_draw
    cmp eax,gameimage
    jb dont_draw

    mov [eax],edx ; actually set the pixel in the image

    mov [eax+3],edx ;

    ;eo draw wall pixel

dont_draw:

    mov edi,[remedi]
  speedup:
    cmp esi,[vbottom]  ; end of this column?
    jg pixelrow

    mov edi,[vl]  ; restoring
    mov eax,[vx1] ; inc X1
    add eax,1
    mov [vx1],eax

    ;*** NEXT A ***
    mov esi,[va]
    sub esi,2 ;
    mov [va],esi
    cmp esi,[vacompare]
    jg for_a
    ;*** EO NEXT A ***

    ; putimage!

    call frame_delay

    mov rax, 7
    mov rbx, 5 *0x100000000 + game_x_size
    mov rcx, 24*0x100000000 + game_y_size-1

    cmp [boot_info_base+4*8],dword 640
    jne no640
    mov rbx, 0 *0x100000000 + game_x_size
    mov rcx, 0 *0x100000000 + game_y_size
  no640:

    mov rdx, gameimage+game_x_size*3
    mov r8 , 0
    mov r9 , 0x1000000
    mov r10, 3
    int 0x60

    ret


frame_delay:

  frd:

    mov   rax , 26
    mov   rbx , 1
    mov   rcx , sysdata
    mov   rdx , 1000
    int   0x60

    mov   rax , [sysdata+48*8]
    cmp   rax , [frame_delay_next]
    jae   noframedelay

    mov   rax , 105
    mov   rbx , 1
    int   0x60

    jmp   frd

  noframedelay:

    mov   r10 , [frame_delay_next]
    add   r10 , 1000/50 ;50fps

    mov   rax , 26
    mov   rbx , 1
    mov   rcx , sysdata
    mov   rdx , 1000
    int   0x60
    cmp   r10 , [sysdata+48*8]
    jae   fdnfine
    mov   r10 , [sysdata+48*8]
  fdnfine:

    mov   [frame_delay_next],r10

    ret


frame_delay_next: dq 0x0


blur:

    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push rbp

    mov eax,0x080000+360*game_x_size*3

copyfloor2:

    add eax,game_x_size*3
    mov ebx,eax
    add ebx,[vx1]
    add ebx,[vx1]
    add ebx,[vx1]

    mov ecx,[ebx-15]
    and ecx,0x00FEFEFE
    shr ecx,1
    mov edx,[ebx-12]
    and edx,0x00FEFEFE
    shr edx,1
    add edx,ecx
    and edx,0x00FEFEFE
    shr edx,1

     mov ecx,[ebx-9]
     and ecx,0x00FEFEFE
     shr ecx,1
     add edx,ecx

      and edx,0x00FEFEFE
      shr edx,1

      mov ecx,[ebx-6]
      and ecx,0x00FEFEFE
      shr ecx,1
      add edx,ecx

       and edx,0x00FEFEFE
       shr edx,1

       mov ecx,[ebx-3]
       and ecx,0x00FEFEFE
       shr ecx,1
       add edx,ecx

        and edx,0x00FEFEFE
        shr edx,1

        mov ecx,[ebx]
        and ecx,0x00FEFEFE
        shr ecx,1
        add edx,ecx

    mov [ebx],edx

    cmp eax,gameimage+game_y_size*game_x_size*3 ; 478
    jb copyfloor2

    pop rbp
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax

    ret

img2dd:

    mov   rsi , wallimg1
    mov   rdi , wall
    call  wall3to4
    mov   rsi , wallimg4
    mov   rdi , wall4
    call  wall3to4
    mov   rsi , wallimg6
    mov   rdi , wall6
    call  wall3to4
    mov   rsi , wallimg7
    mov   rdi , wall7
    call  wall3to4

    mov   rsi , sinusquarter-4
    mov   rdi , sinusquarter
  newsinuscopy:
    mov   eax , [rsi]
    mov   [rdi],eax
    add   rdi , 4
    sub   rsi , 4
    cmp   rsi , sinus
    ja    newsinuscopy

    mov   rsi , sinus
    mov   rdi , sinushalf
  newsinuscopy2:
    mov   eax , 0
    mov   ebx , [rsi]
    sub   eax , ebx
    mov   [rdi],eax
    add   rsi , 4
    add   rdi , 4
    cmp   rdi , eosinus
    jb    newsinuscopy2

    ret

wall3to4:

    mov   rcx , 64*64

   newwall3to4:

    mov   eax , [rsi]
    and   eax , 0x00ffffff
    mov   [rdi],eax

    add   rsi , 3
    add   rdi , 4

    loop  newwall3to4

    ret

    ; ******* Darken by Distance *******

dark_distance:

    ; color must be in edx, wall height in [vdd]

    mov eax,[vdd]
    cmp eax,50
    jg nodark
    ;                split rgb

    mov [blue],edx
    and [blue],dword 255

    shr edx,8
    mov [green],edx
    and [green],dword 255

    shr edx,8
    mov [red],edx
    and [red],dword 255

    mov eax,51    ; darkness parameter
    sub eax,[vdd]
    cmp [pseudo],dword 1
    je isdarkside
    sal eax,2

  isdarkside:

    ; reduce rgb
    sub [red],eax
    cmp [red], dword 0
    jg notblack10b
    mov [red],dword 0
    notblack10b:

    sub [green],eax
    cmp [green],dword 0
    jg notblack20b
    mov [green],dword 0
    notblack20b:

    mov edx,[blue]
    sub [blue],eax
    cmp [blue],dword 0
    jg notblack30b
    mov [blue],dword 0
    notblack30b:

    shl dword [red],16 ; reassemble rgb
    shl dword [green],8
    mov edx,[red]
    or edx,[green]
    or edx,[blue]
    mov eax,edx

  nodark:

    ret


load_image:

    mov   rax , 256
    mov   rbx , runjpeg
    mov   rcx , param
    int   0x60
    push  rbx ; pid

    ; IPC area

    mov   rax , 0
    mov   [wallimgs-32],rax
    mov   rax , 16
    mov   [wallimgs-24],rax

    ; Define IPC

    mov   rax , 60
    mov   rbx , 1
    mov   rcx , wallimgs-32
    mov   rdx , 70*300*3
    int   0x60

    ; My PID

    mov   rax , 111
    mov   rbx , 1
    int   0x60
    mov   [jpgfile-8],rax

    mov   r12 , 0

    pop   rcx ; pid

  sendtry:

    mov   rax , 5
    mov   rbx , 1
    int   0x60

    ; Send picture from 1 MB

    mov   rax , 60
    mov   rbx , 2
    ; rcx = pid
    mov   rdx , jpgfile-8
    mov   r8  , 15000
    int   0x60

    inc   r12
    cmp   r12 , 100*30
    ja    notransformation

    cmp   rax , 0
    jne   sendtry

    ; Wait for picture

    mov   [wallimgs+64*256*3-3],dword 123123
    mov   rdi , 0

  waitmore:

    inc   rdi
    cmp   rdi , 100*60*2 ; 2 minute timeout
    ja    notransformation

    mov   rax , 5
    mov   rbx , 1
    int   0x60

    cmp   [wallimgs+64*256*3-3],dword 123123
    je    waitmore

    mov   rax , 5
    mov   rbx , 1
    int   0x60

  notransformation:

    ret


; Data area

;ceil=ceil
;wall=wall floor
;2 corner stone
;3 leaf mosaic
;4 closed window
;5 greek mosaic
;6 old street stones
;7 maya wall

grid:  ; 32*32 Blocks, Map: 0 = Air, 1 to 8 = Wall
db 2,5,2,5,2,5,2,5,2,5,2,5,5,5,5,5,5,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8
db 5,0,0,0,5,0,0,0,0,0,0,3,0,0,0,0,5,0,0,0,0,0,0,0,0,0,0,0,0,0,8,8
db 5,0,0,0,0,0,0,0,0,0,0,5,0,0,0,0,5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8
db 5,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,5,0,0,0,0,3,3,3,3,0,0,0,0,0,0,8
db 5,0,5,2,3,4,5,6,7,8,2,5,3,3,3,0,5,0,2,5,2,3,0,0,0,0,0,0,0,0,0,8
db 5,0,0,0,0,0,0,0,0,0,2,3,0,0,0,0,5,0,0,0,0,3,0,0,0,0,0,0,0,0,0,8
db 5,0,0,0,5,0,0,4,0,0,0,5,0,0,0,0,5,0,0,0,0,3,3,0,3,3,0,0,0,0,0,8
db 5,5,0,5,5,5,5,4,5,0,5,3,0,0,0,0,5,2,5,2,0,3,0,0,0,3,0,0,0,0,0,8
db 5,0,0,0,5,0,0,0,0,0,0,5,0,3,3,3,5,0,0,0,0,3,0,0,0,3,0,0,0,0,0,8
db 5,0,0,0,5,0,0,5,0,0,0,0,0,0,0,0,5,0,0,0,0,0,0,0,0,3,0,0,0,0,0,8
db 5,0,0,0,0,0,0,5,0,0,0,5,0,0,0,0,5,0,0,0,0,3,0,0,0,0,0,0,0,0,0,8
db 5,4,4,4,4,4,4,4,4,4,4,3,0,0,0,0,0,0,0,0,0,3,0,0,0,0,0,0,0,0,8,8
db 2,2,2,2,2,2,8,8,8,8,8,8,8,8,8,0,0,0,6,6,0,7,7,7,7,7,7,7,7,7,8,8
db 5,0,0,0,5,0,0,0,0,0,0,3,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,5
db 5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,6,0,2,2,2,2,0,0,0,0,3,3,3,3,3,5
db 5,0,0,0,5,0,0,5,0,0,0,0,0,0,0,0,6,0,0,0,0,2,0,0,0,0,3,0,0,0,0,5
db 5,0,2,3,2,3,2,3,2,3,2,5,0,0,0,0,6,0,2,2,0,2,0,0,0,0,3,0,5,5,0,5
db 5,0,0,0,0,0,0,4,0,0,0,3,0,0,0,0,6,0,0,2,0,2,0,2,0,0,3,0,0,0,0,5
db 5,0,0,0,5,0,0,4,0,0,0,5,0,0,0,0,6,0,0,2,2,2,0,2,0,0,3,3,3,3,0,5
db 5,5,0,5,5,5,5,4,5,0,5,3,7,7,7,0,6,0,0,0,0,0,0,2,0,0,0,0,0,3,0,5
db 5,0,0,0,5,0,0,0,0,0,0,5,0,0,0,0,6,0,0,0,0,2,2,2,0,0,0,0,0,3,0,5
db 5,0,0,0,5,0,0,5,0,0,0,3,0,0,0,0,6,0,0,0,0,2,0,0,0,0,0,0,0,0,0,5
db 5,0,0,0,0,0,0,5,0,0,0,5,0,0,0,0,6,0,5,5,0,2,0,0,4,4,0,4,4,0,0,5
db 5,4,5,4,5,4,5,4,5,4,5,3,0,0,0,0,6,0,0,5,0,2,0,0,0,4,0,4,0,0,0,5
db 5,0,0,0,0,0,0,4,0,0,0,3,0,3,3,3,6,0,0,5,0,5,0,0,4,4,0,4,4,0,0,5
db 5,0,0,0,5,0,0,4,0,0,0,5,0,0,0,0,6,0,0,5,0,5,0,4,4,0,0,0,4,4,0,5
db 5,5,0,5,5,5,5,4,5,0,5,3,0,0,0,0,6,0,0,5,0,5,0,4,0,0,0,0,0,4,0,5
db 5,0,0,0,5,0,0,0,0,0,0,5,0,0,0,0,6,0,0,5,0,5,0,4,0,0,0,0,0,4,0,5
db 5,0,0,0,5,0,0,5,0,0,0,3,0,0,0,0,6,5,5,5,0,5,0,4,4,0,0,0,4,4,0,5
db 5,0,0,0,0,0,0,5,0,0,0,0,0,0,5,5,0,0,0,0,0,5,0,0,4,4,4,4,4,0,0,5
db 5,4,5,4,5,4,5,4,5,4,5,3,0,0,0,0,0,0,0,0,0,5,0,0,0,0,0,0,0,0,0,5
db 2,5,2,5,2,5,2,5,2,5,2,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5


col1:  dd 0
vxx:   dd 0 ; misc raycaster vars:
vyy:   dd 0
vl:    dd 0
vpx:   dd 0x001CFFFF ; initial player position * 0xFFFF
vpy:   dd 0x0003FFFF
vstepx: dd 0
vstepy: dd 0
vxxint: dd 0
vyyint: dd 0
vk:   dd 0
va:   dd 0
va2:  dd 0
vdd:  dd 0
vx1:  dd 0
vx1b: dd 0
vh:   dd 0
vdt:  dd 0
vheading:  dd 0 ; initial heading: 0 to 3599
vacompare: dd 0
vpxi:      dd 0
vpyi:      dd 0
wtolong:   dw 0,0

xtemp: dd 0
ytemp: dd 0
xfrac: dd 0
yfrac: dd 0
h_old: dd 0
vbottom: dd 0
mouseya: dd 0
remeax: dd 0
remebx: dd 0
remecx: dd 0
remedx: dd 0
remedi: dd 0
remesi: dd 0
red:    dd 0
green:  dd 0
blue:   dd 0
pseudo: dd 0
step1:  dd 0
step64: dd 0
lasty:  dd 0

window_label: db  'FISHEYE RAYCASTING',0

runjpeg:  db   '/FD/1/JPEGVIEW',0
param:    db   'PARAM',0
          dq   0,0,0,0,0   ;;
jpgfile:  file 'wall.jpg'  ;;

boot_info_base: times 128 db 0

sinus:
dd 0,11,23,34,46,57,69,80,92,103
dd 114,126,137,149,160,172,183,194,206,217
dd 229,240,252,263,274,286,297,309,320,332
dd 343,354,366,377,389,400,411,423,434,446
dd 457,469,480,491,503,514,526,537,548,560
dd 571,583,594,605,617,628,640,651,662,674
dd 685,696,708,719,731,742,753,765,776,787
dd 799,810,821,833,844,855,867,878,889,901
dd 912,923,935,946,957,969,980,991,1003,1014
dd 1025,1036,1048,1059,1070,1082,1093,1104,1115,1127
dd 1138,1149,1161,1172,1183,1194,1206,1217,1228,1239
dd 1250,1262,1273,1284,1295,1307,1318,1329,1340,1351
dd 1363,1374,1385,1396,1407,1418,1430,1441,1452,1463
dd 1474,1485,1496,1508,1519,1530,1541,1552,1563,1574
dd 1585,1597,1608,1619,1630,1641,1652,1663,1674,1685
dd 1696,1707,1718,1729,1740,1751,1762,1773,1784,1795
dd 1806,1817,1828,1839,1850,1861,1872,1883,1894,1905
dd 1916,1927,1938,1949,1960,1971,1982,1992,2003,2014
dd 2025,2036,2047,2058,2069,2079,2090,2101,2112,2123
dd 2134,2144,2155,2166,2177,2188,2198,2209,2220,2231
dd 2241,2252,2263,2274,2284,2295,2306,2316,2327,2338
dd 2349,2359,2370,2381,2391,2402,2413,2423,2434,2444
dd 2455,2466,2476,2487,2497,2508,2518,2529,2540,2550
dd 2561,2571,2582,2592,2603,2613,2624,2634,2645,2655
dd 2666,2676,2686,2697,2707,2718,2728,2738,2749,2759
dd 2770,2780,2790,2801,2811,2821,2832,2842,2852,2863
dd 2873,2883,2893,2904,2914,2924,2934,2945,2955,2965
dd 2975,2985,2996,3006,3016,3026,3036,3046,3056,3067
dd 3077,3087,3097,3107,3117,3127,3137,3147,3157,3167
dd 3177,3187,3197,3207,3217,3227,3237,3247,3257,3267
dd 3277,3287,3297,3306,3316,3326,3336,3346,3356,3365
dd 3375,3385,3395,3405,3414,3424,3434,3444,3453,3463
dd 3473,3483,3492,3502,3512,3521,3531,3540,3550,3560
dd 3569,3579,3588,3598,3608,3617,3627,3636,3646,3655
dd 3665,3674,3684,3693,3703,3712,3721,3731,3740,3750
dd 3759,3768,3778,3787,3796,3806,3815,3824,3834,3843
dd 3852,3861,3871,3880,3889,3898,3907,3917,3926,3935
dd 3944,3953,3962,3971,3980,3990,3999,4008,4017,4026
dd 4035,4044,4053,4062,4071,4080,4089,4098,4106,4115
dd 4124,4133,4142,4151,4160,4169,4177,4186,4195,4204
dd 4213,4221,4230,4239,4247,4256,4265,4274,4282,4291
dd 4299,4308,4317,4325,4334,4342,4351,4360,4368,4377
dd 4385,4394,4402,4411,4419,4427,4436,4444,4453,4461
dd 4469,4478,4486,4495,4503,4511,4519,4528,4536,4544
dd 4552,4561,4569,4577,4585,4593,4602,4610,4618,4626
dd 4634,4642,4650,4658,4666,4674,4682,4690,4698,4706
dd 4714,4722,4730,4738,4746,4754,4762,4769,4777,4785
dd 4793,4801,4808,4816,4824,4832,4839,4847,4855,4863
dd 4870,4878,4885,4893,4901,4908,4916,4923,4931,4938
dd 4946,4953,4961,4968,4976,4983,4991,4998,5006,5013
dd 5020,5028,5035,5042,5050,5057,5064,5071,5079,5086
dd 5093,5100,5107,5115,5122,5129,5136,5143,5150,5157
dd 5164,5171,5178,5185,5192,5199,5206,5213,5220,5227
dd 5234,5241,5248,5254,5261,5268,5275,5282,5288,5295
dd 5302,5309,5315,5322,5329,5335,5342,5349,5355,5362
dd 5368,5375,5381,5388,5394,5401,5407,5414,5420,5427
dd 5433,5439,5446,5452,5459,5465,5471,5477,5484,5490
dd 5496,5502,5509,5515,5521,5527,5533,5539,5546,5552
dd 5558,5564,5570,5576,5582,5588,5594,5600,5606,5612
dd 5617,5623,5629,5635,5641,5647,5652,5658,5664,5670
dd 5675,5681,5687,5693,5698,5704,5709,5715,5721,5726
dd 5732,5737,5743,5748,5754,5759,5765,5770,5776,5781
dd 5786,5792,5797,5802,5808,5813,5818,5824,5829,5834
dd 5839,5844,5850,5855,5860,5865,5870,5875,5880,5885
dd 5890,5895,5900,5905,5910,5915,5920,5925,5930,5935
dd 5939,5944,5949,5954,5959,5963,5968,5973,5978,5982
dd 5987,5992,5996,6001,6005,6010,6015,6019,6024,6028
dd 6033,6037,6041,6046,6050,6055,6059,6063,6068,6072
dd 6076,6081,6085,6089,6093,6097,6102,6106,6110,6114
dd 6118,6122,6126,6130,6134,6138,6142,6146,6150,6154
dd 6158,6162,6166,6170,6174,6178,6181,6185,6189,6193
dd 6196,6200,6204,6208,6211,6215,6218,6222,6226,6229
dd 6233,6236,6240,6243,6247,6250,6254,6257,6260,6264
dd 6267,6270,6274,6277,6280,6284,6287,6290,6293,6296
dd 6300,6303,6306,6309,6312,6315,6318,6321,6324,6327
dd 6330,6333,6336,6339,6342,6345,6348,6350,6353,6356
dd 6359,6362,6364,6367,6370,6372,6375,6378,6380,6383
dd 6386,6388,6391,6393,6396,6398,6401,6403,6405,6408
dd 6410,6413,6415,6417,6420,6422,6424,6426,6429,6431
dd 6433,6435,6437,6440,6442,6444,6446,6448,6450,6452
dd 6454,6456,6458,6460,6462,6464,6466,6467,6469,6471
dd 6473,6475,6476,6478,6480,6482,6483,6485,6486,6488
dd 6490,6491,6493,6494,6496,6497,6499,6500,6502,6503
dd 6505,6506,6507,6509,6510,6511,6513,6514,6515,6516
dd 6518,6519,6520,6521,6522,6523,6524,6525,6527,6528
dd 6529,6530,6531,6531,6532,6533,6534,6535,6536,6537
dd 6538,6538,6539,6540,6541,6541,6542,6543,6543,6544
dd 6545,6545,6546,6546,6547,6547,6548,6548,6549,6549
dd 6550,6550,6550,6551,6551,6551,6552,6552,6552,6552
dd 6553,6553,6553,6553,6553,6553,6553,6553,6553,6553
dd 6554

sinusquarter:  times ($-sinus-2*4) db ?
sinushalf:     times ($-sinus) db ?

eosinus:

   dq ?,?,?,?,?,?,?,? ;;
wallimgs:             ;;
   times 100000 db ?  ;;

ceil:
wall:
   times 64*64 dd ?
wall3:
wall4:
   times 64*64 dd ?
wall2:
wall5:
wall6:
   times 64*64 dd ?
wall7:
   times 64*64 dd ?

   times 200   dq ?

stack_position:

         times 100  db ?
sysdata: times 2000 db ?

gameimage:

I_END:

