;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Menuet64 mail (c) V.Turjanmaa
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use64

    org   0x0

    db    'MENUET64'              ; Header identifier
    dq    0x01                    ; Version
    dq    START                   ; Start of code
    dq    I_END                   ; Size of image
    dq    0xA00000                ; Memory for app
    dq    0x1ffff0                ; Rsp
    dq    0x00                    ; Prm
    dq    0x00                    ; Icon

; image_end - from & subject - 80 step
; 0xd0000   - email fetch server message
; 0xe0000   - server messages ok/err
; 0xf0000   - tmp header read - (was tmp mail read) - tmp topwindow check
; 0x100000  - was email (not in use now)
; 0x170000  - Folders, 80 step
; 0x180000  - write email - 80 step
; 0x1ffff0  - stack
; 0x200000  - decoded email by wanted_part
; 0x600000  - all of mail
; 0xA00000  - image end

;[input_pos]- where sender and subject are read - starts at image_end
;[mail_start]- first mail to be read
;[selected_mail]-selected mail 1

selected_color equ 0xd8d8d8
border_color   equ 0xf4f4f4

include 'dns.inc'
include 'textbox.inc'

START:

    call  clear_and_setup

    call  get_config

    call  draw_window       ; At first, draw the window

still:

    cmp   [stillret],byte 1
    jne   nostillret
    ret
  nostillret:

    call  status
    mov   rsi , disconnected
    cmp   [sst],byte 4
    jne   cncd
    mov   rsi , connected
  cncd:
    call  show_status

    mov   rax , 37
    mov   rbx , 2
    int   0x60
    cmp   rax , 0
    jne   nofetchcheck
    cmp   [sst],byte 4
    jne   nofetchcheck
    inc   qword [scrollchange]
    cmp   dword [scrollchange],dword 50
    jb    nofetchcheck
    call  check_fetch
  nofetchcheck:

    cmp   [ipc_memory+16],byte 0
    je    noipc
    call  ipc_message
    jmp   still
  noipc:

    mov   rax , 23          ; Wait here for event
    mov   rbx , 1
    int   0x60

    test  rax , 0x1         ; Window redraw
    jnz   window_event
    test  rax , 0x2         ; Keyboard press
    jnz   key_event
    test  rax , 0x4         ; Button press
    jnz   button_event

    cmp   [screen],byte 1
    jne   nomousecheck
    call  check_mouse
  nomousecheck:

    jmp   still


check_mouse:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Mouse selections
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    cmp   [sst],byte 4
    jne   cml9

    mov   rax , 37
    mov   rbx , 2
    int   0x60

    cmp   rax , 0
    je    cml9

    ; check that window is at top

    mov   rax , 26
    mov   rbx , 1
    mov   rcx , 0xf0000
    mov   rdx , 1024
    int   0x60

    mov   r10 , [0xf0000+15*8]

    mov   rax , 26
    mov   rbx , 2
    mov   rcx , 0xf0000
    mov   rdx , 1024
    int   0x60

    imul  r10 , 8
    mov   r10 , [0xf0000+r10]

    mov   rax , 111
    mov   rbx , 1
    int   0x60

    cmp   rax , r10
    jne   cml9

    ;

    mov   rax , 37
    mov   rbx , 1
    int   0x60

    mov   rbx , rax
    shr   rax , 32
    and   rbx , 0xffff

    ; Check attach select

    push  rax rbx rcx rdx

    cmp   rbx , 438
    jb    noattachselect
    cmp   rbx , 438+12
    ja    noattachselect
    cmp   rax , 106
    jb    noattachselect

    mov   rcx , 0
  newidposcheck:
    mov   rdx , [multipart_pos+rcx*8]
    cmp   rdx , 0
    je    nothisid

    imul  rdx , 6
    add   rdx , 106
    cmp   rax , rdx
    jb    idposfound

  nothisid:
    inc   rcx
    cmp   rcx , [multipart_ids]
    jbe   newidposcheck
    jmp   noidposfound

  idposfound:

    mov   [save_part],rcx

    call  wait_for_mouse_up

    mov   [save_open],dword 0 ;save
    mov   [parameter],byte 'S';save
    call  dialog_open

  noidposfound:

  noattachselect:

    pop   rdx rcx rbx rax

    ;

    cmp   rbx , 88
    jb    cml9
    cmp   rbx , 88+12*10-2
    ja    cml9
    cmp   rax , 18
    jb    cml9
    cmp   rax , 500
    ja    cml9

    mov   rcx , rax

    sub   rbx , 88
    mov   rax , rbx
    xor   rdx , rdx
    mov   rbx , 12
    div   rbx

    cmp   rcx , 145
    ja    mail_change

    cmp   rcx , 105
    ja    cml92

    cmp   [selected_protocol],byte 1
    jne   cml91

    add   rax , [scroll11value]
    sub   rax , 400000
    inc   rax

    cmp   rax , [folders]
    ja    cml91

    mov   [selected_folder],rax
    push  rax
    call  draw_mail_folders
    pop   rax
    dec   rax
    imul  rax , 80
    add   rax , 0x170000
    mov   rdi , imap_select+12
    ; End marker
    mov   cl , ' '
    cmp   [rax],byte '"'
    jne   clfine
    mov   cl , '"'
    dec   rax
  clfine:
    inc   rax
  newmove3:
    mov   bl , [rax]
    mov   [rdi],bl
    inc   rax
    inc   rdi
    cmp   [rax], cl
    je    endmarkerfound
    cmp   [rax], byte 13
    jbe   endmarkerfound
    jmp   newmove3
  endmarkerfound:
    cmp   cl , '"'
    jne   noaddend
    mov   [rdi],byte '"'
    inc   rdi
  noaddend:
    mov   [rdi],byte 13
    inc   rdi
    mov   [rdi],byte 10
    inc   rdi
    mov   [rdi],byte 0

    call  select_folder

    mov   rdi , image_end
    mov   rcx , 0xd0000-image_end
    mov   rax , 0
    cld
    rep   stosb

    mov   [scroll1value],dword 100000
    mov   [mail_start],dword 1
    call  scroll1

    jmp   cml91

  mail_change:

    add   rax , [mail_start]
    mov   [selected_mail], rax

    call  draw_subjects
    call  wait_for_mouse_up

    cmp   [sst],byte 4
    jne   cml9

    call  fetch_selected_mail

   cml9:

    ret

  cml91:

    call  wait_for_mouse_up

  cml92:

    ret



ipc_message:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Dialogs
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; Wait for the dialog to close window

    mov   rax , 5
    mov   rbx , 50
    int   0x60
    call  draw_window
    call  draw_window

    cmp   [save_open],byte 0
    jne   nofilesave
    push  qword [wanted_part]
    mov   rcx , [save_part]
    mov   [wanted_part],rcx
    call  get_save_content
    pop   qword [wanted_part]
    mov   [ipc_memory+8],dword 16
    mov   [ipc_memory+16],byte 0
    call  decode_email
    call  check_scroll_size

    ret

  nofilesave:

    cmp   [save_open],byte 1
    jne   nofileopen
    inc   dword [readfilepos]
    mov   rdi , [readfilepos]
    dec   rdi
    imul  rdi , 128
    add   rdi , readfile1
    mov   rsi , ipc_memory+16
    mov   rcx , 100
    cld
    rep   movsb
    mov   [ipc_memory+8],dword 16
    mov   [ipc_memory+16],byte 0
    call  draw_window

    ret

  nofileopen:

    ret



clear_and_setup:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Start setup
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; Font

    mov   rax , 141
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    ; Clear and setup data area

    mov   rdi , I_END
    mov   rcx , image_end - I_END
    mov   rax , 0
    cld
    rep   stosb

    mov   [string_b],dword '--'
    mov   [ipc_memory+0],dword 0
    mov   [ipc_memory+8],dword 16
    mov   rax , 'Attachme'
    mov   [string_send_attachments+0],rax
    mov   rax , 'nt(s): '
    mov   [string_send_attachments+8],rax
    mov   rax , 'Attachme'
    mov   [string_attachments+0],rax
    mov   rax , 'nt(s): -'
    mov   [string_attachments+8],rax
    mov   rax , 'User '
    mov   [user],rax
    mov   rax , 'Pass '
    mov   [pass],rax

    mov   [textbox1+0], word 0
    mov   [textbox1+8], word 100
    mov   [textbox1+16],word 220
    mov   [textbox1+24],word 130-20
    mov   [textbox1+32],word 1001
    mov   [textbox1+40],word 0

    mov   [textbox2+0], word 0
    mov   [textbox2+8], word 100
    mov   [textbox2+16],word 220
    mov   [textbox2+24],word 150-20
    mov   [textbox2+32],word 1002
    mov   [textbox2+40],word 0

    mov   [textbox3+0], word 0
    mov   [textbox3+8], word 100
    mov   [textbox3+16],word 220
    mov   [textbox3+24],word 170-20
    mov   [textbox3+32],word 1003
    mov   [textbox3+40],word 0
    mov   rax , '********'
    mov   [textbox3+48],rax

    mov   [textbox4+0], word 0
    mov   [textbox4+8], word 100
    mov   [textbox4+16],word 220
    mov   [textbox4+24],word 250-40
    mov   [textbox4+32],word 1004
    mov   [textbox4+40],word 0

    mov   [textbox5+0], word 0
    mov   [textbox5+8], word 100
    mov   [textbox5+16],word 220
    mov   [textbox5+24],word 270-40
    mov   [textbox5+32],word 1005
    mov   [textbox5+40],word 0

    mov   [textbox11+0], word 0
    mov   [textbox11+8], word 80
    mov   [textbox11+16],word 220
    mov   [textbox11+24],word 94+20-4
    mov   [textbox11+32],word 1011
    mov   [textbox11+40],word 0

    mov   [textbox12+0], word 0
    mov   [textbox12+8], word 80
    mov   [textbox12+16],word 220
    mov   [textbox12+24],word 114+20-4
    mov   [textbox12+32],word 1012
    mov   [textbox12+40],word 0

    ; Inbox by default

    mov   rax , 'INBOX'
    mov   [0x170000+1],rax
    mov   [folders],dword 1
    mov   [selected_folder],dword 1

    ; Clear email write area

    mov   rdi , 0x180000
  newclear:
    push  rdi
    mov   rcx , 78
    mov   rax , 32
    cld
    rep   stosb
    mov   rax , 0
    stosb
    stosb
    pop   rdi
    add   rdi , 80
    cmp   rdi , 0x180000 + 80*140
    jb    newclear

    ret


dialog_open:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Open dialog
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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

    ; Define IPC memory

    mov   rax , 60         ; ipc
    mov   rbx , 1          ; define memory area
    mov   rcx , ipc_memory ; memory area pointer
    mov   rdx , 100        ; size of area
    int   0x60

    ret


wait_for_mouse_up:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Wait for mouse buttons up
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   cml2:

    mov   rax , 5
    mov   rbx , 1
    int   0x60

    mov   rax , 37
    mov   rbx , 2
    int   0x60

    cmp   rax , 0
    jne   cml2

    ret


get_config:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Get defaults
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; POP ip

    mov   rax , 112
    mov   rbx , 1
    mov   rcx , pops
    mov   rdx , 99
    mov   r8  , ips1
    int   0x60
    call  get_len

    ; SMTP server

    mov   rax , 112
    mov   rbx , 1
    mov   rcx , smtps
    mov   rdx , 99
    mov   r8  , ips2
    int   0x60
    call  get_len

    ; user

    mov   rax , 112
    mov   rbx , 1
    mov   rcx , users
    mov   rdx , 99
    mov   r8  , config_user
    int   0x60
    call  get_len

    ; account

    mov   rax , 112
    mov   rbx , 1
    mov   rcx , accounts
    mov   rdx , 99
    mov   r8  , config_account
    int   0x60
    call  get_len

    ret


get_len:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Get string length
;
;   In : r8     - pointer to string
;   Out: [r8-8] - length of string
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    push  rcx

    push  r8

    mov   rcx , 0
  newlens:
    cmp   [r8],byte 32
    jb    lenfound
    inc   r8
    inc   rcx
    jmp   newlens
  lenfound:

    pop   r8

    mov   [r8-8],rcx

    pop   rcx

    ret



get_config_user_pass:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Get user and password
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rsi , config_user
    mov   rdi , user+5
  gcl0:
    mov   al , [rsi]
    cmp   al , 0
    je    gcl1
    mov   [rdi],al
    inc   rdi
    inc   rsi
    jmp   gcl0
  gcl1:
    mov   [rdi],byte 13
    mov   [rdi+1],byte 10
    mov   [rdi+2],byte 0

    mov   rsi , config_pass
    mov   rdi , pass + 5
  gcl2:
    mov   al , [rsi]
    cmp   al , 0
    je    gcl3
    mov   [rdi] , al
    inc   rdi
    inc   rsi
    jmp   gcl2
  gcl3:
    mov   [rdi],byte 13
    mov   [rdi+1],byte 10
    mov   [rdi+2],byte 0

    ret


window_event:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Window event
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    call  draw_window
    jmp   still



key_event:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Key event
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rax , 2  ; Read the key
    int   0x60

    cmp   [screen],byte 2
    je    write_email

    cmp   rbx , 0
    jne   still
    ;
    cmp   [screen],byte 1
    jne   nokeys19

    cmp   cl , '1'
    jne   nowpart1
    mov   [email_start_pos],dword 0x600000
    call  check_scroll_size
    call  draw_email
    jmp   still
  nowpart1:

    cmp   cl , '2'
    jb    nowpart
    cmp   cl , '9'
    ja    nowpart
    mov   [email_start_pos],dword 0x200000
    sub   cl , '2'-1
    mov   [wanted_part],cl
    call  decode_email
    call  check_scroll_size
    call  draw_email
    jmp   still
  nowpart:

  nokeys19:

    ;

    jmp   still



write_email:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Write an email
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    char_space equ ' '

    test  rbx , 1
    jnz   nodown

    mov   r8 , 'PgUp    '
    cmp   rcx , r8
    jne   no_pageup
    mov   rcx , 21
    mov   rdx , 0
    mov   r8  , 300000
  pageud:
    cmp   [scroll3value],r8
    je    pagetop
    mov   rax , [scroll3value]
    sub   rax , rcx
    mov   [scroll3value],rax
    cmp   r8  , 300000
    jne   pgd
    cmp   rax , r8
    jae   pagetopdr
    mov   [scroll3value],r8
    jmp   pagetopdr
  pgd:
    cmp   rax , r8
    jbe   pagetopdr
    mov   [scroll3value],r8
    jmp   pagetopdr
  pagetop:
    mov   [writex],dword 0
    mov   [writey],rdx
  pagetopdr:
    call  scroll3
    call  write_email_draw
    jmp   still
  no_pageup:
    mov   r8 , 'PgDown  '
    cmp   rcx , r8
    jne   no_pagedown
    mov   rcx , -21
    mov   rdx , 21
    mov   r8 , 300000+100-24
    jmp   pageud
  no_pagedown:

    mov   r8 , 'Delete  '
    cmp   rcx , r8
    jne   no_delete_key
  delete_key:
    mov   rax , 0 ; check from beginning of line
    call  any_letters_on_line
    cmp   rax , 0
    jne   no_delete_line2
    call  delete_line
    jmp   still
  no_delete_line2:
    mov   rax , [writex] ; check from cursor
    call  any_letters_on_line
    cmp   rax , 0
    je    move_to_line
    call  move_letters
    call  write_email_draw
    jmp   still
  move_to_line:

    push  qword [writex] qword [writey]
    mov   rax,0
    inc   dword [writey]
    call  any_letters_on_line
    pop   qword [writey] qword [writex]

    cmp   rax , 1
    je    movetoline
    push  qword [writex] qword [writey]
    mov   [writex],dword 0
    inc   dword [writey]
    call  delete_line
    pop   qword [writey] qword [writex]
    call  write_email_draw
    jmp   still
  movetoline:

    mov   rax , [writey]
    add   rax , [scroll3value]
    sub   rax , 300000
    imul  rax , 80
    add   rax , 0x180000
    mov   rsi , rax
    add   rax , [writex]
    mov   rdi , rax
    add   rsi , 80
    push  rsi
    mov   rcx , 79
    sub   rcx , [writex]
    cld
    rep   movsb
    pop   rdi
    mov   rax , 32
    mov   rcx , 79
    cld
    rep   stosb

    push  qword [writex] qword [writey]
    mov   [writex],dword 0
    inc   dword [writey]
    call  delete_line
    pop   qword [writey] qword [writex]

    call  write_email_draw
    jmp   still
  no_delete_key:

    mov   r8 , 'Backspc '
    cmp   rcx , r8
    jne   nobspc2
    cmp   [writex],dword 0
    jne   no_delete_line

    cmp   [writey],dword 0
    je    still

    dec   dword [writey]
    mov   rax , 0 ; check from beginning of line
    call  any_letters_on_line
    inc   dword [writey]
    cmp   rax , 0
    je    contdel
    dec   dword [writey]
    call  end_of_line

    jmp   delete_key

    jmp   still

  contdel:
    dec   dword [writey]

    call  delete_line

    jmp   still
  no_delete_line:

    dec   qword [writex]
    call  move_letters
    call  write_email_draw

    jmp   still

  delete_line:

    mov   rax , [writey]
    add   rax , [scroll3value]
    sub   rax , 300000
    imul  rax , 80
    add   rax , 0x180000

    mov   rdi , rax
    mov   rsi , rdi
    add   rsi , 80
    mov   rcx , 80*300
    cld
    rep   movsb

    call  write_email_draw

  retstill:

    ret

  any_letters_on_line:

    mov   rbx , rax

    mov   rax , [writey]
    add   rax , [scroll3value]
    sub   rax , 300000
    imul  rax , 80
    add   rax , 0x180000
    add   rax , rbx
    ;
    mov   rcx , 79
    sub   rcx , rbx
    ;
    mov   rbx , rax
    add   rbx , rcx

  newlinech:

    cmp   [rax],byte ' '
    ja    yesletter
    inc   rax
    cmp   rax , rbx
    jbe   newlinech

    mov   rax , 0
    ret

  yesletter:
    mov   rax , 1
    ret


  move_letters:

    mov   rax , [writey]
    add   rax , [scroll3value]
    sub   rax , 300000
    imul  rax , 80
    add   rax , 0x180000
    mov   rdx , rax
    add   rax , [writex]

    mov   rdi , rax
    mov   rsi , rdi
    inc   rsi
    mov   rcx , 79
    sub   rcx , [writex]
    cld
    rep   movsb

    mov   [rdx+79],byte 0

    ret

  nobspc2:

    mov   r8 , 'Enter   '
    cmp   rcx , r8
    jne   noent
    cmp   [writey],dword 21
    jb    noel2
    cmp   [scroll3value],dword 300000+100-24
    jge   still
    call  move_text_down
    inc   qword [scroll3value]
    call  scroll3
    call  write_email_draw
    jmp   still
  noel2:

    call  move_text_down
    inc   qword [writey]

    call  write_email_draw

    jmp   still

  move_text_down:

    mov   rax , [writey]
    add   rax , [scroll3value]
    sub   rax , 300000
    imul  rax , 80
    add   rax , 0x180000

    push  rax

    mov   rdi , rax
    add   rdi , 80
    mov   rsi , rdi
    sub   rsi , 80
    add   rdi , 200*80
    add   rsi , 200*80
    mov   rcx , 200*80
    std
    rep   movsb
    cld

    pop   rdi

    ; Copy residual to new line

    mov   rsi , rdi
    add   rsi , [writex]
    push  rsi
    add   rdi , 80
    ; Clear line first
    push  rax rcx rdi
    mov   rax , char_space
    mov   rcx , 79
    cld
    rep   stosb
    pop   rdi rcx rax
    ;
    mov   rcx , 79
    sub   rcx , [writex]
    cld
    rep   movsb

    pop   rdi

    ; Clear end of line

    mov   rax , char_space
    mov   rcx , 79
    sub   rcx , [writex]
    cld
    rep   stosb
    mov   rax , 0
    stosb

    ; Reset X

    mov   [writex],dword 0

    ret

  noent:

    mov   r8 , 'Up-A    '
    cmp   rcx , r8
    jne   noup
    cmp   dword [writey],dword 0
    je    up2
    dec   qword [writey]
    call  write_email_draw
    jmp   still
  up2:
    cmp   [scroll3value],dword 300000
    je    still
    dec   dword [scroll3value]
    call  scroll3
    call  write_email_draw
    jmp   still
  noup:
    mov   r8 , 'Down-A  '
    cmp   rcx , r8
    jne   nodown2
    cmp   dword [writey],dword 21
    je    down2
    inc   qword [writey]
    call  write_email_draw
    jmp   still
  down2:
    cmp   [scroll3value],dword 300000+100-24
    je    still
    inc   dword [scroll3value]
    call  scroll3
    call  write_email_draw
  nodown2:
    mov   r8 , 'Right-A '
    cmp   rcx , r8
    jne   noright
    cmp   dword [writex],dword 78
    je    still
    inc   qword [writex]
    call  write_email_draw
    jmp   still
  noright:
    mov   r8 , 'Left-A  '
    cmp   rcx , r8
    jne   noleft
    cmp   dword [writex],dword 0
    je    still
    dec   qword [writex]
    call  write_email_draw
    jmp   still
  noleft:

    mov   r8 , 'Home    '
    cmp   rcx , r8
    jne   no_home
    mov   [writex],dword 0
    call  write_email_draw
    jmp   still
  no_home:

    mov   r8 , 'End     '
    cmp   rcx , r8
    jne   no_end

    call  end_of_line
    jmp   still

  end_of_line:

    mov   [writex],dword 80

  newenddec:

    dec   dword [writex]
    cmp   [writex],dword 0
    je    endfound

    mov   rax , [writey]
    add   rax , [scroll3value]
    sub   rax , 300000
    imul  rax , 80
    add   rax , [writex]
    add   rax , 0x180000

    cmp   [rax-1],byte 32
    jbe   newenddec

  endfound:

    call  write_email_draw
    ret

  no_end:

  nodown:

    cmp   rbx , 0
    jne   wreml1

    and   rcx , 0xff
    cmp   rcx , 128   ; 7bit email
    jae   wreml1

    mov   rax , [writey]
    add   rax , [scroll3value]
    sub   rax , 300000
    imul  rax , 80
    add   rax , [writex]
    add   rax , 0x180000

    push  rcx
    mov   rsi , rax
    mov   rdi , rax
    inc   rdi
    mov   rcx , 78
    sub   rcx , [writex]
    add   rsi , rcx
    add   rdi , rcx
    dec   rsi
    dec   rdi
    std
    rep   movsb
    cld
    pop   rcx

    mov   [rax],cl

    cmp   [writex],dword 78
    jae   nowritexi
    inc   qword [writex]
  nowritexi:

    mov   rax , [writey]
    mov   [drawline],rax

    cmp   [stillret],byte 1
    je    nowrem
    call  write_email_draw
  nowrem:
    mov   [drawline],dword 999999

  wreml1:

    jmp   still



write_email_draw:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Draw email
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rax , 4
    mov   rbx , [scroll3value]
    sub   rbx , 300000
    imul  rbx , 80
    add   rbx , 0x180000
    mov   rcx , 20
    mov   rdx , 170-12+10-1
    mov   rsi , 0x000000
    mov   r9  , 1
    mov   r10 , 0
  wedl1:

    cmp   r10 , [drawline]
    je    dodrawline
    cmp   [drawline],dword 999999
    jb    nodrawline
  dodrawline:

    push  rax rbx rcx rdx
    mov   rax , 13
    mov   rbx , 17 * 0x100000000 + 6*82+1
    mov   rcx , rdx
    sub   rcx , 1
    shl   rcx , 32
    add   rcx , 12
    mov   rdx , 0xffffff
    int   0x60
    pop   rdx rcx rbx rax
    int   0x60

  nodrawline:

    inc   r10

    add   rbx , 80
    add   rdx , 12
    cmp   rdx , 158 + 10-1 + 12*22
    jb    wedl1

    mov   rax , 38
    mov   rbx , [writex]
    imul  rbx , 6
    add   rbx , 20
    mov   rdx , rbx
    mov   rcx , [writey]
    imul  rcx , 12
    add   rcx , 170-12-2+10
    mov   r8  , rcx
    add   r8  , 10
    mov   r9  , 0x000000
    int   0x60

    ret


connect:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Connect to server
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    call  get_config_user_pass

    mov   [mail_start], dword 1
    mov   [selected_mail], dword 1

    mov   [scroll1value],dword 100000
    mov   [scroll2value],dword 200000

    mov   rdi , 0x100000
    mov   rax , 0
    mov   rcx , 80*100
    cld
    rep   stosb
    call  draw_email

    mov   rdi , image_end
    mov   rax , 0
    mov   rcx , 80 * 6000
    cld
    rep   stosb
    call  draw_subjects

    mov   rsi , opening
    call  show_status

    mov   rsi , ips1
    mov   rdi , pop_ip
    call  get_ip

    cmp   [pop_ip],dword 0
    je    fsl9

    cmp   [selected_protocol],byte 1
    je    open_imap

    mov   rax , 53
    mov   rbx , 5
    mov   rcx , [localport]
    inc   dword [localport]
    mov   rdx , 110
    mov   rsi , [pop_ip]
    mov   rdi , 1
    int   0x60
    mov   [socket],rax

    mov   r15 , 0
  new_status_wait:
    inc   r15
    cmp   r15 , 20
    jae   fsl9
    mov   rax , 5
    mov   rbx , 10
    int   0x60
    push  r15
    call  status
    pop   r15
    cmp   [sst],byte 4
    jne   new_status_wait

    mov   [okpos],dword 0x100000
    call  wait_for_ok
    call  draw_email

    ; User

    mov   rsi , user
    call  send
    mov   [okpos],dword 0x100000+80
    call  wait_for_ok
    call  draw_email
    cmp   [0x100000+80],byte '+'
    jne   fsl9

    ; Password

    mov   rsi , pass
    call  send
    mov   [okpos],dword 0x100000+160
    call  wait_for_ok
    call  draw_email
    cmp   [0x100000+160],byte '+'
    jne   fsl9

    ; Stat

    mov   [okpos],dword 0x100000+240
    mov   rsi , stat_command
    call  send
    call  wait_for_ok
    call  draw_email
    cmp   [0x100000+240],byte '+'
    jne   fsl9

    mov   rsi , 0x100000+240
  news:
    inc   rsi
    cmp   [rsi],byte ' '
    jne   news

    mov   rax , 0
  news2:
    inc   rsi
    cmp   [rsi], byte '0'
    jb    news3
    cmp   [rsi], byte '9'
    ja    news3
    imul  rax , 10
    movzx rbx , byte [rsi]
    sub   rbx , 48
    add   rax , rbx
    jmp   news2
  news3:

    mov   [emails],rax

    call  scroll1

    mov   rdi , 0x170000
    mov   rcx , 80*40
    mov   rax , 0
    cld
    rep   stosb

    mov   rax , 'INBOX'
    mov   [0x170000+1],rax
    mov   [folders],dword 1
    mov   [selected_folder],dword 1

    call  draw_mail_folders

    ret

  fsl9:

    call  disconnect

    ret

  open_imap:

    ;
    ; Open IMAP connection
    ;

    mov   rax , 53
    mov   rbx , 5
    mov   rcx , [localport]
    inc   dword [localport]
    mov   rdx , 143
    mov   rsi , [pop_ip]
    mov   rdi , 1
    int   0x60
    mov   [socket],rax

    mov   r15 , 0
  imap_new_status_wait:
    inc   r15
    cmp   r15 , 20
    jae   fsl9
    mov   rax , 5
    mov   rbx , 10
    int   0x60
    push  r15
    call  status
    pop   r15
    cmp   [sst],byte 4
    jne   imap_new_status_wait

    mov   [okpos],dword 0x100000
    call  wait_for_ok
    call  draw_email

    ; User & password

    mov   rsi , imap_user_password
    call  send
    mov   rsi , config_user
    call  send
    mov   rsi , imap_user_password_space
    call  send
    mov   rsi , config_pass
    call  send
    mov   rsi , imap_user_password_crlf
    call  send
    mov   [okpos],dword 0x100000+80
    call  wait_for_ok
    call  draw_email
    mov   rax , '1234 OK '
    cmp   [0x100000+80],rax
    jne   imap_fail

    ; Read folders

    mov   rsi , imap_folders
    call  send
    mov   [input_pos],dword 0xf0000
    call  read_input_header

    mov   [folders],dword 0

    ; Move folder names to data area 0x170000+

    mov   rsi , 0xf0000 + 79
    mov   rdi , 0x170000

  newfolder:

    push  rsi

    ; Search for end of line

  newsearch:
    cmp   rsi , 0xf0000
    jbe   imap_fail_folder
    cmp   [rsi],dword '1236'
    je    imap_fail_folder
    dec   rsi
    cmp   [rsi],byte ' '
    jbe   newsearch

    mov   r14 , rsi
    mov   al , ' '
    cmp   [r14],byte '"'
    jne   alfine2
    mov   al , '"'
  alfine2:

  newsearch2:
    cmp   rsi , 0xf0000
    jbe   imap_fail_folder
    cmp   [rsi],dword '1236'
    je    imap_fail_folder
    dec   rsi
    cmp   [rsi],al
    jne   newsearch2

    push  rdi
    mov   rcx , r14
    sub   rcx , rsi
    and   rcx , 0xff
    inc   rcx
    cld
    rep   movsb
    pop   rdi

    pop   rsi

    inc   dword [folders]

    mov   rcx , 80
  newrsiadd:
    inc   rsi
    cmp   [rsi],dword '1236'
    je    imap_fail_folder
    loop  newrsiadd

    add   rdi , 80

    cmp   rdi , 0x170000 + 30*80
    jb    newfolder

  imap_fail_folder:

    ; call  draw_mail_folders

    ; Select folder

    call  select_folder

    ; Search for folder INBOX to mark [selected_folder]

    mov   [selected_folder],dword 0
    mov   rdi , 0x170000+1
    mov   rcx , 80
  newfsearch:
    inc   dword [selected_folder]
    cmp   [rdi],dword 'INBO'
    je    folder_found
    add   rdi , 80
    loop  newfsearch
    mov   [selected_folder],dword 1
  folder_found:

    call  draw_mail_folders

    call  scroll1
    call  scroll11

    ret

  imap_fail:

    mov   rax , 5
    mov   rbx , 100
    int   0x60

    call  disconnect

    ret



select_folder:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Select mail folder
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; Select INBOX folder

    mov   rsi , imap_select
    call  send
    mov   [okpos],dword 0xf0000
    call  wait_for_ok
    call  draw_email

    ; Read amount of emails

    mov   rsi , 0xf0000
  imap_news:
    inc   rsi
    cmp   [rsi],byte ' '
    jne   imap_news

    mov   rax , 0
  imap_news2:
    inc   rsi
    cmp   [rsi], byte '0'
    jb    imap_news3
    cmp   [rsi], byte '9'
    ja    imap_news3
    imul  rax , 10
    movzx rbx , byte [rsi]
    sub   rbx , 48
    add   rax , rbx
    jmp   imap_news2
  imap_news3:
    mov   [emails],rax
    call  status

    ; Read rest of the folder info

    mov   rcx , 30
  read_more_info:
    dec   rcx
    jz    info_read
    mov   rsi , [okpos]
    sub   rsi , 80
    mov   rax , '1235 OK '
    cmp   [rsi],rax
    je    info_read
    push  rcx
    call  wait_for_ok
    pop   rcx
    jmp   read_more_info
  info_read:

    ret



print_inbox_state:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Display email count
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rax , 4
    mov   rbx , inbox
    mov   rcx , 350
    mov   rdx , 60+3
    mov   r9  , 1
    mov   rsi , 0x000000
    int   0x60

    mov   rax , 47
    mov   rbx , 5*65536
    mov   rcx , [emails]
    mov   rdx , (410-3*6)*65536+60+3
    mov   rsi , 0x000000
    int   0x40

    ret



show_status:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Show status string
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    cmp  rsi , [stat]
    je   stl1

    mov  [stat],rsi

    mov  rax , 13
    mov  rbx , 350 * 0x100000000 + 6*20
    mov  rcx , 50  * 0x100000000 + 22
    mov  rdx , border_color
    int  0x60

    mov  rax , 4
    mov  rbx , rsi
    mov  rcx , 350
    mov  rdx , 53
    mov  r9  , 1
    mov  rsi , 0x000000
    int  0x60

    call print_inbox_state

  stl1:

    ret



fetch_subjects:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   POP3 - Get email subjects
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   [mailerror],byte 0

    cmp   [selected_protocol],byte 1
    je    fetch_subjects_imap

    mov   rsi , reading_subjects
    call  show_status

    mov   rax , [mail_start]
    dec   rax
    imul  rax , 80
    add   rax , image_end
    mov   [headerpos],rax

    mov   rcx , 10
    mov   r11 , 0

  newheader:

    push  r11
    push  rcx

    mov   rax , r11
    add   rax , [mail_start]

    cmp   rax , [emails]
    ja    no_success

    mov   rdi , top+4
    call  numtostring

    mov   rsi , top
    call  send

    mov   [input_pos],dword 0xf0000
    call  read_input_header
    call  get_sender
    call  get_subject

  no_success:

    pop   rcx
    pop   r11

    cmp   [mailerror],byte 1
    je    error

    inc   r11

    loop  newheader

  error:

    call  draw_subjects

    ret



fetch_subjects_imap:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   IMAP - Get email subjects
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rsi , reading_subjects
    call  show_status

    mov   rax , [mail_start]
    dec   rax
    imul  rax , 80
    add   rax , image_end
    mov   [headerpos],rax

    mov   rcx , 10
    mov   r11 , 0

  imap_newheader:

    push  r11
    push  rcx

    mov   rax , r11
    add   rax , [mail_start]

    cmp   rax , [emails]
    ja    imap_no_success

    mov   rdi , imap_top+11
    call  numtostring
    mov   rsi , imap_top
    call  send

    mov   [input_pos],dword 0xf0000
    call  read_input_header
    call  get_sender
    call  get_subject

  imap_no_success:

    pop   rcx
    pop   r11

    inc   r11

    loop  imap_newheader

    call  draw_subjects

    ret



fetch_selected_mail:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   POP3 - Fetch user selected mail
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    cmp   [selected_protocol],byte 1
    je    fetch_selected_mail_imap

    mov   rsi , reading_email
    call  show_status

    mov   rdi , 0x600000
    mov   rcx , 0x400000
    mov   rax , 0
    cld
    rep   stosb

    mov   rax , [selected_mail]
    cmp   rax , [emails]
    ja    fsml8
    mov   rdi , top2+4
    call  numtostring

    mov   rsi , top2
    call  send

    mov   [input_pos],dword 0x600000
    mov   [endmarker],byte '.'
    call  read_input_header
    mov   [endmarker],byte '.'

    mov   [scroll2value],dword 200000

    call  decode_email
    call  check_scroll_size
    call  draw_email

  fsml8:

    ret



fetch_selected_mail_imap:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   IMAP - Fetch user selected mail
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rsi , reading_email
    call  show_status

    mov   rdi , 0x600000
    mov   rcx , 0x400000
    mov   rax , 0
    cld
    rep   stosb

    mov   rax , [selected_mail]
    cmp   rax , [emails]
    ja    imap_fsml8

    ; Read header

    push  rax
    mov   rdi , imap_top+11
    call  numtostring
    mov   rsi , imap_top
    call  send
    mov   [input_pos],dword 0x600000
    mov   [endmarker],byte 254
    call  read_input_header
    mov   [endmarker],byte '.'
    ; Clear response
    mov   rdi , 0x600000
    mov   rcx , 79
    mov   rax , 32
    cld
    rep   stosb
    sub   [input_pos],dword 80
    mov   rax , [input_pos]
    cmp   [rax-80+1],dword 'FLAG'
    jne   noflagclear
    sub   [input_pos],dword 80
  noflagclear:
    pop   rax

    ; Read email

    push  qword [input_pos]
    mov   rdi , imap_top2+11
    call  numtostring
    mov   rsi , imap_top2
    call  send
    mov   [endmarker],byte 254
    call  read_input_header
    mov   [endmarker],byte '.'
    ; Clear response
    pop   rdi
    mov   rsi , rdi
    add   rsi , 80
    mov   rcx , [input_pos]
    add   rcx , 160
    sub   rcx , rdi
    cld
    rep   movsb
    mov   rax , [input_pos]
    sub   rax , 160
    mov   [rax],dword '    '
    mov   [rax+4],dword '    '
    mov   [rax+8],dword '    '
    cmp   [rax-80+1],dword 'FLAG'
    jne   noflagclear2
    mov   rdi , rax
    sub   rdi , 80
    mov   rcx , 79
    mov   rax , 32
    cld
    rep   stosb
  noflagclear2:

    mov   [scroll2value],dword 200000

    call  decode_email
    call  check_scroll_size
    call  draw_email

  imap_fsml8:

    ret



decode_email:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Decode fetched email data
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; Clear display area

    mov   rdi , 0x200000
    mov   rcx , 0x400000
    mov   rax , 0
    cld
    rep   stosb

    ; Change display address

    mov   [email_start_pos],dword 0x200000

    ; Reset multipart id count

    mov   [multipart_ids],dword 1

    mov   rdi , multipart_pos
    mov   rcx , 90*8
    mov   rax , 0
    cld
    rep   stosb

    ; Reset information string

    mov   [string_files],dword '-'

    ;
    ; header - Content-Type
    ;

    mov   rax , 'plain'   ; text/plain
    mov   [mailtype],rax

    mov   r15 , 0x600000
    mov   rsi , string_content_type
    call  get_email_parameter

    cmp   rdi , 0
    je    yestextplain

    ;
    ; header - Content-Type: text/plain or quoted-printable
    ;

    mov   rax , 'oted-pri' ; quoted-printable
    call  tolower10
    cmp   [rdi+2],rax
    je    yestextplain_quoted

    mov   eax , 'text' ; text/plain , text/html
    cmp   [rdi],eax
    jne   notextplain

  yestextplain_quoted:

    mov   eax , [rdi+5]  ; plain/html
    mov   [mailtype],eax

    mov   r15 , 0x600000
    mov   rsi , string_content_transfer_encoding
    call  get_email_parameter
    mov   rsi , 0x600000
    cmp   [rdi+2],dword 'se64'
    je    dobase64enc

  yestextplain:

    mov   rsi , 0x600000
    mov   r12 , 1000
  newbesx:
    dec   r12
    jz    newbes2x
    add   rsi , 80
    cmp   [rsi],dword 0
    jne   newbesx
  newbes2x:

    mov   rdi , 0x200000
  newmovechar:
    mov   cl  , [rsi]
    mov   [rdi], cl
    inc   rsi
    inc   rdi
    cmp   rdi , 0x280000
    jbe   newmovechar
  nomoremove:

    call  check_for_special_characters

    mov   [scroll2value],dword 200000

    mov   [bodysize],dword 65536

    ret

  notextplain:

    ;
    ; header - Content-Type: multipart
    ;

    mov   rax , 'multipar'
    call  tolower8
    cmp   [rdi],rax
    jne   nomultipart

    ;
    ; boundary:
    ;

    mov   r15 , 0x600000
    mov   rsi , string_boundary
    call  get_email_parameter

    cmp   rdi , 0
    je    nomultipart

    dec   rdi
  addrdi2:
    inc   rdi
    cmp   [rdi],byte '"'
    je    addrdi2
    cmp   [rdi],byte "'"
    je    addrdi2

    mov   rax , string_b+2
  newclmove:
    mov   cl  , [rdi]
    cmp   cl  , '"'
    je    nocladd
    cmp   cl  , "'"
    je    nocladd
    cmp   cl  , 32
    jbe   nocladd
    mov   [rax],cl

    inc   rdi
    inc   rax

    jmp   newclmove

  nocladd:

    mov   [rax],dword 0

    ; Search wanted part of multipart

    mov   rsi , string_b
    mov   r15 , 0x600000

    mov   [multipart_ids],dword 0

    mov   [attpos],dword 0

    mov   r14 , 0
    mov   rax , 0x200000
  newwantedpart:
    push  rax rsi r14 r15
    call  get_email_parameter
    pop   r15 r14 rsi rax
    ;
    cmp   rdi , 0
    je    domultipart
    ;
    inc   dword [multipart_ids]
    ;
    call  add_include_file_information
    ;
    inc   r14
    cmp   r14 , [wanted_part]
    jbe   nonewwantedpart
    mov   r15 , [linestart]
    add   r15 , 80
    jmp   newwantedpart
  nonewwantedpart:
    mov   rax , [linestart]
    mov   r15 , [linestart]
    add   r15 , 80
    jmp   newwantedpart

  domultipart:

    mov   [part1start],rax

    ; Remove last comma

    mov   rax , [attpos]
    cmp   rax , 0
    je    noremove

    mov   [string_files+rax-2],dword '  '

  noremove:

    ;
    ; Content-Type: text/?  or quoted-printable
    ;

  innertext:

    mov   r15 , [part1start]
    mov   rsi , string_content_type
    call  get_email_parameter

    mov   rsi , [linestart]
    mov   rax , 'oted-pri'   ; quoted-printable
    call  tolower10
    cmp   [rdi+2],rax
    je    yestextplain2

    mov   rsi , [linestart]
    mov   eax , 'text'       ; text/plain , text/html
    cmp   [rdi],eax
    jne   notextplain2

  yestextplain2:

    mov   eax , [rdi+5]  ; plain/html
    mov   [mailtype],eax

    push  rsi
    mov   r15 , [part1start]
    mov   rsi , string_content_transfer_encoding
    call  get_email_parameter
    pop   rsi

    cmp   [rdi+2],dword 'se64'
    jne   nobase64

    mov   rsi , [part1start]

  dobase64enc:

    mov   r12 , 1000
  newbesxxz:
    dec   r12
    jz    newbes2xxz
    add   rsi , 80
    cmp   [rsi],dword 0
    jne   newbesxxz
  newbes2xxz:

    add   rsi , 80
    mov   rdi , 0x200000

    call  fdobase64

    call  check_for_special_characters

    mov   [scroll2value],dword 200000

    ret

  nobase64:

    mov   r12 , 1000
  newbesxx:
    dec   r12
    jz    newbes2xx
    add   rsi , 80
    cmp   [rsi],dword 0
    jne   newbesxx
  newbes2xx:

    mov   rax , [string_b]
    mov   rdi , 0x200000
  newmovecharx:
    cmp   [rsi],rax
    je    nomoremovex

    mov   cl  , [rsi]
    mov   [rdi], cl

    inc   rsi
    inc   rdi
    cmp   rdi , 0x280000
    jbe   newmovecharx
  nomoremovex:

    call  check_for_special_characters

    mov   [scroll2value],dword 200000

    mov   [bodysize],dword 65536

    ret

  notextplain2:

    ;
    ; Content-Type: multipart
    ;

    call   tolower4
    cmp   [rdi],dword 'mult'
    jne    noinnermultipart

    ; This type of message is usually for txt+html+include file(s)
    ; Scan to the first txt file

    mov   r15 , [part1start]
    mov   rsi , string_boundary
    call  get_email_parameter
    cmp   rdi , 0
    je    noinnermultipart

    dec   rdi
  addrdi2x:
    inc   rdi
    cmp   [rdi],byte '"'
    je    addrdi2x
    cmp   [rdi],byte "'"
    je    addrdi2x

    mov   rax , string_b2+2
  newclmovex:
    mov   cl  , [rdi]
    cmp   cl  , '"'
    je    nocladdx
    cmp   cl  , "'"
    je    nocladdx
    cmp   cl  , 32
    jbe   nocladdx
    mov   [rax],cl

    inc   rdi
    inc   rax

    jmp   newclmovex

  nocladdx:

    mov   [rax],dword 0

    ; Search wanted part of multipart

    mov   rsi , string_b2
    mov   r15 , 0x600000
    call  get_email_parameter

    cmp   rdi , 0
    je    noinnermultipart

    mov   rax , [linestart]
    mov   [part1start],rax

    ; Part found - interprete as txt

    jmp   innertext

  noinnermultipart:


    ;
    ; Content-Type: image or application
    ;

    mov   eax , 'appl'
    call  tolower4
    cmp   [rdi],eax
    je    yesapplication

    mov   eax , 'imag'
    call  tolower4
    cmp   [rdi],eax
    jne   noimage

  yesapplication:

    mov   eax , [rdi+5]  ; plain/html
    mov   [mailtype],eax

    mov   r15 , [part1start]
    mov   rsi , string_content_transfer_encoding
    call  get_email_parameter

    cmp   [rdi+2],dword 'se64'
    jne   noimage

    mov   rsi , [part1start]
    mov   r12 , 1000
  newbesxxzz:
    dec   r12
    jz    newbes2xxzz
    add   rsi , 80
    cmp   [rsi],dword 0
    jne   newbesxxzz
  newbes2xxzz:

    ; Show header

    cmp   [decodeimage],byte 1
    je    decimage

    mov   rcx , rsi
    sub   rcx , [part1start]
    mov   rsi , [part1start]
    mov   rdi , 0x200000
    add   rsi , 80
    add   rdi , 80
    cld
    rep   movsb

    mov   [scroll2value],dword 200000

    ret

  decimage:

    ; Decode image/application data

    add   rsi , 80
    mov   rdi , 0x200000

    call  fdobase64

    mov   [scroll2value],dword 200000

    ret

  noimage:

    ; Unknown

    mov   rsi , [part1start]
    add   rsi , 80
    mov   rdi , 0x200000
    mov   rcx , 80*10
    cld
    rep   movsb

    mov   [scroll2value],dword 200000

    mov   [bodysize],dword 65536

    ret

  nomultipart:

    ;
    ; header - Content-Type: (no text or multipart)
    ;
    ; unknown email type, display all as text
    ;

    jmp   yestextplain



add_include_file_information:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Add file name to information string
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    push  rax rbx rcx rdx r8 r9 r10 r11 r12 r13 r14 r15 rsi rdi rbp
    push  qword [linestart]

    ; Search att boundary
    mov   r15 , [linestart]
    add   r15 , 80
    push  r15
    mov   rsi , string_b
    call  get_email_parameter
    mov   r14 , rdi
    pop   r15
    ; Content-Disposition
    mov   rsi , string_content_disposition
    push  r14 r15
    call  get_email_parameter
    pop   r15 r14
    cmp   rdi , r14
    ja    noadddescr
    cmp   [rdi],byte 'a' ; attachment
    je    yesadddescr
    cmp   [rdi],byte 'A' ; Attachment
    je    yesadddescr
    ; Content-Type
    push  r14 r15
    mov   rsi , string_content_type
    call  get_email_parameter
    pop   r15 r14
    ; Accept image/* and application/*
    call  tolower4
    cmp   [rdi],dword 'imag'
    je    yesadddescr
    cmp   [rdi],dword 'appl'
    je    yesadddescr
    jmp   noadddescr
  yesadddescr:
    push  r15
    mov   rsi , string_content_descriptor
    call  get_email_parameter
    pop   r15
    cmp   rdi , 0
    jne   founddescr
    ; If not descriptor -> Use content-type
    push  r15
    mov   rsi , string_content_type
    call  get_email_parameter
    pop   r15
    ; If not content-type -> skip
    cmp   rdi , 0
    je    noadddescr
  founddescr:
  mored:
    mov   bl , [rdi]
    cmp   [rdi],dword 0
    je    nomored
    cmp   [rdi],byte ';'
    je    nomored
    cmp   [rdi],dword '    '
    je    nomored
    mov   rax , [attpos]
    mov   [string_files+rax],bl
    add   [attpos],dword 1
    inc   rdi
    jmp   mored
  nomored:
    mov   rax , [attpos]
    mov   [string_files+rax],dword ', '
    add   [attpos],dword 2
    mov   rbx , [multipart_ids]
    mov   [multipart_pos+rbx*8],rax
  noadddescr:

    pop   qword [linestart]
    pop   rbp rdi rsi r15 r14 r13 r12 r11 r10 r9 r8 rdx rcx rbx rax

    ret

  tolower4:
    push  rax rdi
    mov   rax , 4
    jmp   tl10l
  tolower8:
    push  rax rdi
    mov   rax , 8
    jmp   tl10l
  tolower10:
    push  rax rdi
    mov   rax , 10
  tl10l:
    cmp   [rdi],byte ';'
    je    tol02
    cmp   [rdi],dword '    '
    je    tol02
    ;
    cmp   [rdi],byte 'A'
    jb    nolow
    cmp   [rdi],byte 'Z'
    ja    nolow
    add   [rdi],byte 32
  nolow:
    ;
    inc   rdi
    dec   rax
    jnz   tl10l
  tol02:
    pop   rdi rax

    ret


check_for_special_characters:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Check for special html characters
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    push  rax rbx rcx rdx rsi rdi

    mov   rsi , 0x200000

  cfscl1:

    cmp   [rsi],dword '&nbs'
    jne   nonbsp
    mov   [rsi+0],dword '    '
    mov   [rsi+4], word '  '
  nonbsp:

    cmp   [rsi],dword '&quo'
    jne   noquot
    mov   [rsi+0],dword '    '
    mov   [rsi+4], word '  '
  noquot:

    call  convert_unicode

    inc   rsi
    cmp   rsi , 0x200000+0x100000
    jbe   cfscl1

    call  check_for_mailtype

    pop   rdi rsi rdx rcx rbx rax

    ret



convert_unicode:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Convert unicode
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    push  rax rbx

    cmp   [rsi],byte '='
    jne   cfscl2
    ; Use unicode (approximation)
    mov   bh , [rsi+1]
    cmp   bh , 'A'
    jb    c102
    sub   bh , 'A'
    add   bh , 10+'0'
  c102:
    sub   bh , '0'
    ;
    mov   bl , [rsi+2]
    cmp   bl , 'A'
    jb    c10
    sub   bl , 'A'
    add   bl , 10+'0'
  c10:
    sub   bl , '0'
    shl   bh , 4
    add   bl , bh
    and   rbx , 0xff
    mov   al , [unichar+rbx]
    ;
    mov   [rsi],  byte al
    mov   [rsi+1],byte 255 ; ' '
    mov   [rsi+2],byte 255 ; ' '
  cfscl2:

    pop   rbx rax

    ret



check_for_mailtype:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Check mail type
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    cmp   [mailtype],byte 'H'
    je    yeshtmlmail
    cmp   [mailtype],byte 'h'
    jne   nohtmlmail
  yeshtmlmail:
    call  htmlmail
    ret

  nohtmlmail:
    call  plainmail
    ret


htmlmail:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   HTML mail
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rsi , 0x200000
    mov   rdi , 0x300000
    mov   rcx , 0x100000
    cld
    rep   movsb

    mov   rdi , 0x200000
    mov   [b64t],rdi

    push  rdi
    mov   rcx , 0x100000
    mov   rax , 0
    cld
    rep   stosb
    pop   rdi

    mov   rsi , 0x300000
  newbodysearch:
    cmp   [rsi],dword '<BOD'
    je    bodyfound
    cmp   [rsi],dword '<Bod'
    je    bodyfound
    cmp   [rsi],dword '<bod'
    je    bodyfound
    inc   rsi
    cmp   rsi , 0x300000+0x100000
    jb    newbodysearch
    mov   rsi , 0x300000
  bodyfound:

  html1:

    cmp   [rsi],byte 13
    je    html2

    cmp   [rsi],byte 13
    jb    html7
    cmp   [rsi],byte 255
    jae   html7

    cmp   [rsi],dword '<tab'
    je    dohbr
    cmp   [rsi],dword '<TAB'
    je    dohbr
    cmp   [rsi],dword '</tr'
    je    dohbr
    cmp   [rsi],dword '</TR'
    je    dohbr
    cmp   [rsi],dword '<div'
    je    dohbr
    cmp   [rsi],dword '<DIV'
    je    dohbr
    cmp   [rsi],dword '<br>'
    je    dohbr2
    cmp   [rsi],dword '<BR>'
    je    dohbr2
    jmp   nohbr
  dohbr:
    cmp   [addbyte],byte 13 ; no double
    je    newsea
  dohbr2:
    mov   [addbyte],byte 13
    push  qword [addbyte]
    call  add_to_stream
    pop   qword [addbyte]
  newsea:
    add   rsi , 1
    cmp   rsi , 0x300000+0x100000
    jae   nohbr
    cmp   [rsi] , byte '>'
    jne   newsea
    add   rsi , 1
    jmp   html1
  nohbr:

    movzx rax , byte [rsi]
    cmp   rax , '<'
    jne   html2

  html3:

    add   rsi , 1

    cmp   rsi , 0x300000+0x100000
    jae   html2

    movzx rax , byte [rsi]
    cmp   rax , '>'
    jne   html3

    add   rsi , 1
    jmp   html1

  html2:

    mov   al , [rsi]
    cmp   al , 13
    jne   noret2
    mov   al , ' '
  noret2:
    cmp   al , ' '
    jne   nospacecheck
    cmp   [addbyte],byte ' '
    je    nodoublespace
    cmp   [addbyte],byte 13 ; no space to beginning of line
    je    nodoublespace
  nospacecheck:
    mov   [addbyte],al
    push  qword [addbyte]
    call  add_to_stream
    pop   qword [addbyte]
  nodoublespace:

  html7:

    inc   rsi
    cmp   rsi , 0x300000+0x100000
    jbe   html1

    ; Clear
    mov   rdi , 0x300000
    mov   rcx , 0x100000
    xor   rax , rax
    cld
    rep   stosb

    ret



plainmail:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Plain text mail
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rsi , 0x200000
    mov   rdi , 0x300000
    mov   rcx , 0x100000
    cld
    rep   movsb

    mov   rdi , 0x200000
    mov   [b64t],rdi

    push  rdi
    mov   rcx , 0x100000
    mov   rax , 0
    cld
    rep   stosb
    pop   rdi

    mov   rsi , 0x300000
    jmp   noaddlf

  plain1:

    mov   rax , rsi
    sub   rax , 0x300000
    xor   rdx , rdx
    mov   rbx , 80
    div   rbx
    cmp   rdx , 0
    jne   noaddlf
    mov   [addbyte],byte 13
    call  add_to_stream
  noaddlf:

    cmp   [rsi],byte 255
    jae   plain2
    mov   al , [rsi]
    mov   [addbyte],al
    call  add_to_stream
  plain2:

    inc   rsi
    cmp   rsi , 0x300000+0x100000
    jbe   plain1

    ; Clear
    mov   rdi , 0x300000
    mov   rcx , 0x100000
    xor   rax , rax
    cld
    rep   stosb

    ret



fdobase64:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Decode Base64
;
;   In: rsi,rdi
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   [b64t],rdi

    mov   r10 , 0 ; bits done in byte at [rdi]

  dobase64:

  newal:

    cmp   [rsi],word '--'
    je    base64_end

    cmp   rsi , 0x600000+0x3f0000
    jae   base64_end
    cmp   rdi , 0x200000+0x3f0000
    jae   base64_end

    ; ABCDEFGHIJKLMNOPQRSTUVWXYZ
    ; abcdefghijklmnopqrstuvwxyz
    ; 0123456789+/
    ; =

    mov   al , [rsi]
    ;
    cmp   al , 13
    ja    no13x
    inc   rsi
    jmp   newal
  no13x:
    ;
    cmp   al , '='
    jne   noex
    inc   rsi
    jmp   newal
  noex:
    ;
    cmp   al , 32
    jne   noex2
    inc   rsi
    jmp   newal
  noex2:

    ;
    cmp   al , '+'
    jne   nopl
    mov   al , 62
    jmp   aldone
  nopl:
    ;
    cmp   al , '/'
    jne   nodiv
    mov   al , 63
    jmp   aldone
  nodiv:
    ; 0-9
    cmp   al , '9'
    ja    nona
    sub   al , '0'
    add   al , 26+26
    jmp   aldone
  nona:
    cmp   al , 'Z'
    ja    nofa
    sub   al , 'A'
    jmp   aldone
  nofa:
    cmp   al , 'z'
    ja    nosa
    sub   al , 'a'
    add   al , 26
    jmp   aldone
  nosa:

  aldone:

    cmp   r10 , 0
    jne   nofirstbits
    shl   al  , 2
    mov   [addbyte],al
    mov   r10 , 6
    jmp   bitsdone
  nofirstbits:
    cmp   r10 , 6
    jne   nofirstbits2
    mov   bl , al
    shr   bl , 4
    add   [addbyte],bl
    call  add_to_stream
    and   al , 1111b
    shl   al , 4
    mov   [addbyte],al
    mov   r10 , 4
    jmp   bitsdone
  nofirstbits2:
    cmp   r10 , 4
    jne   nofirstbits3
    mov   bl , al
    shr   bl , 2
    add   [addbyte],bl
    call  add_to_stream
    and   al , 11b
    shl   al , 6
    mov   [addbyte],al
    mov   r10 , 2
    jmp   bitsdone
  nofirstbits3:
    cmp   r10 , 2
    jne   nofirstbits4
    add   [addbyte],al
    call  add_to_stream
    mov   r10 , 0
    jmp   bitsdone
  nofirstbits4:

  bitsdone:

    inc   rsi

    jmp   dobase64

  base64_end:

    mov   rax , rdi
    sub   rax , [b64t]
    mov   [bodysize],rax

    ret



add_to_stream:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Add byte to stream
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    push  rax rbx rcx rdx

    mov   al , [addbyte]

    cmp   [decodeimage],byte 1
    je    ignlf

    cmp   al , 13
    jne   nobase64lf

    push  rax rbx rcx rdx
    sub   rdi , [b64t]
    mov   rax , rdi
    xor   rdx , rdx
    mov   rbx , 80
    div   rbx
    imul  rax , 80
    add   rax , 80
    mov   rdi , rax
    add   rdi , [b64t]
    pop   rdx rcx rbx rax

    jmp   nothischar

  nobase64lf:

    cmp   al , 16
    jb    nothischar
    cmp   al , 255 ; 127
    jae   nothischar

  ignlf:

    mov   [rdi],al
    inc   rdi

  nothischar:

    mov   [addbyte],byte 0

    pop   rdx rcx rbx rax

    ret



get_email_parameter:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Get email parameter
;
;   In: r15,rsi
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   r8  , r15
    mov   rax , r8

    mov   [linestart],r8

    mov   rcx , rsi

  dopcheck:

    cmp   rax , 0x600000+0x400000 ; 80*500
    jae   notfound

    mov   bl  , [rax]
    mov   dl  , [rcx]

    ; Both to lower case

    cmp   bl  , 'A'
    jb    nobllow
    cmp   bl  , 'Z'
    ja    nobllow
    add   bl , 32
  nobllow:
    cmp   dl  , 'A'
    jb    nodllow
    cmp   dl  , 'Z'
    ja    nodllow
    add   dl , 32
  nodllow:

    cmp   dl  , 0
    je    pfound

    cmp   bl  , dl
    jne   nextpcheck

    inc   rax
    inc   rcx

    jmp   dopcheck

  nextpcheck:

    mov   rcx , rsi

    cmp   [rcx], byte 'b'
    jne   noboundary
    add   r8  , 1
    jmp   bdone
  noboundary:
    add   r8  , 80
  bdone:
    ;
    mov   rax , r8
    ;
    push  rax rbx rcx rdx
    xor   rdx , rdx
    sub   rax , 0x600000
    mov   rbx , 80
    div   rbx
    imul  rax , 80
    add   rax , 0x600000
    mov   [linestart],rax
    pop   rdx rcx rbx rax
    ;
    jmp   dopcheck

  pfound:

    mov   rdi , rax
    dec   rdi
  incrdi:
    inc   rdi
    cmp   [rdi],byte ' ' ; include line changes
    jbe   incrdi

    ret

  notfound:

    mov   rdi , 0
    ret



disconnect:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   POP3 - Disconnect from server
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    cmp   [selected_protocol],byte 1
    je    disconnect_imap

    call  status

    cmp   [sst],byte 0
    je    dcl1

    mov   rsi , disconnecting
    call  show_status

    mov   rsi , quit
    call  send

    mov   rax , 5
    mov   rbx , 100
    int   0x60

    mov   rax , 53
    mov   rbx , 8
    mov   rcx , [socket]
    int   0x60

    mov   rax , 5
    mov   rbx , 300
    int   0x60

    call  status

    mov   rsi , disconnected
    cmp   [sst],byte 4
    jne   cncd3
    mov   rsi , connected
  cncd3:
    call  show_status


  dcl1:

    ret


disconnect_imap:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   IMAP - Disconnect from server
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    call  status

    cmp   [sst],byte 0
    je    imap_dcl1

    mov   rsi , disconnecting
    call  show_status

    mov   rsi , quit_imap
    call  send

    mov   rax , 5
    mov   rbx , 100
    int   0x60

    mov   rax , 53
    mov   rbx , 8
    mov   rcx , [socket]
    int   0x60

    mov   rax , 5
    mov   rbx , 300
    int   0x60

    call  status

    mov   rsi , disconnected
    cmp   [sst],byte 4
    jne   imap_cncd3
    mov   rsi , connected
  imap_cncd3:
    call  show_status

  imap_dcl1:

    ret



send:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Send string to server
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    call  empty_buffer

    mov   rdx , rsi
    dec   rdx
  sel1:
    inc   rdx
    cmp  [rdx],byte 0
    jne   sel1
    sub   rdx , rsi

    mov   rax , 53
    mov   rbx , 7
    mov   rcx , [socket]
    int   0x60

    ret


numtostring:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Convert num to string
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    add   rdi , 3
    mov   rcx , 4

  ntsl1:

    xor   rdx , rdx
    mov   rbx , 10
    div   rbx
    add   dl , 48
    mov   [rdi],dl

    dec   rdi

    loop  ntsl1

    ret


wait_for_ok:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Wait for CR/LF
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rdi , [okpos]
    add   [okpos],dword 80

    mov   r15 , 0

  wfol0:

    inc   r15
    cmp   r15 , 2000
    je    wfol1

    mov   rax , 5
    mov   rbx , 1
    int   0x60

  wfol11:

    mov   rax , 53
    mov   rbx , 2
    mov   rcx , [socket]
    int   0x60

    cmp   rax , 0
    je    wfol0

    mov   rax , 53
    mov   rbx , 3
    mov   rcx , [socket]
    int   0x60

    mov   [rdi],bl
    inc   rdi

    cmp   bl , 10
    je    wfol1

    jmp   wfol11

  wfol1:

    ret


read_data_block:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Read data from server
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    cmp   [blocksize],dword 0
    jne   getblockbyte

    push  rdx
    mov   rax , 53
    mov   rbx , 13
    mov   ecx , [socket]
    mov   rdx , tcpipblock
    int   0x60
    pop   rdx

    mov   [blocksize],rax
    mov   [blockpos],dword tcpipblock

    cmp   rax , 0
    je    noreadblockbyte

  getblockbyte:

    mov   rbx , [blockpos]
    mov   bl  , [rbx]
    and   rbx , 0xff

    inc   dword [blockpos]
    dec   dword [blocksize]

    mov   rax , [blocksize]

  noreadblockbyte:

    ret



empty_buffer:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Clear buffer
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rax , 53
    mov   rbx , 2
    mov   rcx , [socket]
    int   0x60

    cmp   rax , 0
    je    ebl1

    mov   rax , 53
    mov   rbx , 3
    mov   rcx , [socket]
    int   0x60

    jmp   empty_buffer

  ebl1:

    ret


display_progress:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Dsiplay progress information
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    push   rax rbx rcx rdx rsi rdi
    push   rax
    cmp    [printtext],byte 1
    jne    nodrtb
    mov    [printtext],byte 0
    mov    rax , 13
    mov    rbx , 460 shl 32 + 7*6
    mov    rcx , 050 shl 32 + 15
    mov    rdx , border_color
    int    0x60
  nodrtb:
    pop    rax
    cmp    rax , 1
    jne    nodpl1
    mov    [printtext],byte 1
    mov    rcx , rdi
    sub    rcx , [stpos]
    mov    rax , 47
    mov    rbx , 7*65536
    mov    rdx , 460 shl 32 + 53
    mov    rsi , 0x000000
    int    0x60
  nodpl1:
    mov    [printcounter],dword 0
    pop    rdi rsi rdx rcx rbx rax

    ret



read_input_header:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Read incoming data headers
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rdi , [input_pos]
    mov   [stpos],rdi

    push  rdi
    mov   rax , 0
    mov   rcx , 50*80
    cld
    rep   stosb
    pop   rdi

    mov   r10 , 0 ; timeout counter
    mov   r12 , 0 ;

    mov   [printcounter],dword 0

  ril1:

    mov   [input_pos],rdi

    inc   dword [printcounter]
    cmp   [printcounter],dword 1000
    jne   noprd
    mov   rax , 1
    call  display_progress
  noprd:
    mov   rax , 11
    int   0x60
    test  rax , 1
    jz    nowdn
    push  rdi r10 r12
    call  draw_window
    pop   r12 r10 rdi
  nowdn:

    mov   rax , 105
    mov   rbx , 1
    int   0x60

    inc   r10
    cmp   r10 , 1000*10 ; timeout 10 sec / header
    je    ril2

  ril11:

    cmp   [blocksize],dword 0
    jne   blnz1

    mov   rax , 53
    mov   rbx , 2
    mov   rcx , [socket]
    int   0x60

    cmp   rax , 0
    je    ril1

  blnz1:

    mov   r10 , 0

    call  read_data_block

    ; Error - pop3

    mov   rax , [stpos]
    cmp   [rax],dword '-ERR'
    je    errorread

    ; End of header - imap

    mov   rax , '1236 OK '
    cmp   [rdi-9],rax
    je    endreatched

    ; End of header - pop3

    cmp   r12 , 1
    jne   nobeginning
    mov   al , [endmarker]
    cmp   [rdi-1],al
    jne   nobeginning
    cmp   bl , 13
    ja    nobeginning
  endreatched:
    mov   r14 , 200
  newrest:
    call  read_data_block
    dec   r14
    jnz   newrest
    jmp   ril2
  nobeginning:

    cmp   bl , 10
    jne   nolinedown
    mov   r12 , 0
    jmp   ril11
  nolinedown:

    ; Add linefeed

    cmp   bl , 13
    jne   nolf
    cmp   r12 , 80
    je    nolf
    ;
    cmp   [rdi-1],byte '='
    jne   noremovee
    mov   [rdi-1],byte ' '
  noremovee:
    ;
    sub   rdi , [stpos] ; 0xf0000
    add   rdi , 80
    mov   rax , rdi
    xor   rdx , rdx
    mov   rbx , 80
    div   rbx
    imul  rax , 80
    mov   rdi , rax
    add   rdi , [stpos] ; 0xf0000
    mov   r12 , 0
    jmp   ril11
  nolf:

    ; Add letter

    cmp   bl , 20
    jb    ril31
    mov   [rdi],byte bl
    ; cmp   r12 , 79
    ; jae   ril3
    inc   rdi
    inc   r12
    jmp   ril31
  ril3:
    cmp   [lflf],byte 1 ; lf only for letter part
    jne   ril31
    mov   r12 , 0
    inc   rdi
  ril31:

    jmp   ril11

  ril2:

    ; Add linefeed

    sub   rdi , [stpos] ; 0xf0000
    add   rdi , 80
    mov   rax , rdi
    xor   rdx , rdx
    mov   rbx , 80
    div   rbx
    imul  rax , 80
    mov   rdi , rax
    add   rdi , [stpos] ; 0xf0000
    mov   [input_pos],rdi

    mov   rax , 0
    call  display_progress

    ret

  errorread:

    mov   [mailerror],byte 1

    ret



get_sender:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Find sender from data
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rdi , [headerpos]
    mov   rcx , 79
    mov   rax , 32
    cld
    rep   stosb
    mov   al , 0
    stosb

    mov   rsi , 0xf0000 - 80
    mov   rax , 'From'

  gsel1:

    add   rsi , 80

    cmp   rsi , 0xf0000 + 80*100
    ja    gsel2

    cmp   [esi],eax
    jne   gsel1

    add   rsi , 6

    cmp   [rsi],byte '"'
    jne   noquote
    inc   rsi
  noquote:

    cmp   [rsi],word '=?'
    jne   nosenddec
    mov   rcx , 3
    mov   rax , rsi
    add   rax , 80
  newqse:
    inc   rsi
    cmp   rsi , rax
    ja    nosenddec
    cmp   [rsi],byte '?'
    jne   newqse
    loop  newqse
    inc   rsi
  nosenddec:

    mov   rdi , [headerpos]
    add   rdi , 7
    mov   r10 , rsi
  gsel4:
    call  convert_unicode
    mov   al , [rsi]
    cmp   al , 255
    je    gsel7
    cmp   al , '_'
    jne   nospace2
    mov   al , ' '
  nospace2:
    cmp   al , '?'
    je    gsel5
    cmp   rsi , r10
    je    nobc
    cmp   al , '<'
    je    gsel5
  nobc:
    cmp   al , 31
    jb    gsel5
    cmp   al , '"'
    je    gsel5
    mov   [rdi], al
    inc   rdi
  gsel7:
    inc   rsi
    mov   rax , [headerpos]
    add   rax , 25 ; 29
    cmp   rdi , rax
    jae   gsel5
    jmp   gsel4
  gsel5:

    mov   rsi , [headerpos]
  zcheck:
    cmp   [rsi],byte 0
    jne   noz
    mov   [rsi],byte 32
  noz:
    inc   rsi
    mov   rdi , [headerpos]
    add   rdi , 50
    cmp   rsi , rdi
    jb    zcheck

    ; call  draw_subjects

  gsel2:

    ret


get_subject:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Find subject from data
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rsi , 0xf0000 - 80
    mov   rax , 'Subject:'

  gsl1:

    add   rsi , 80

    cmp   rsi , 0xf0000 + 80*100
    ja    gsl2

    cmp  [rsi], rax
    jne   gsl1

    add   rsi , 9

    cmp   [rsi],word '=?'
    jne   nosubjdec
    mov   rcx , 3
    mov   rax , rsi
    add   rax , 80
  newqsu:
    inc   rsi
    cmp   rsi , rax
    ja    gsl2
    cmp   [rsi],byte '?'
    jne   newqsu
    loop  newqsu
    inc   rsi
  nosubjdec:

    mov   rdi , [headerpos]
    add   rdi , 27 ; 32
    mov   rcx , 47
  newsubjc:
    call  convert_unicode
    mov   al , [rsi]
    cmp   al , 255
    je    subjskip
    cmp   al , '_'
    jne   nospace3
    mov   al , ' '
  nospace3:
    cmp   al , '?'
    je    subjend
    mov   [rdi], al
    inc   rdi
  subjskip:
    inc   rsi
    loop  newsubjc
  subjend:

    ; call  draw_subjects

  gsl2:

    add   [headerpos],dword 80

    ret


status:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Get connection state
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rax , 53
    mov   rbx , 6
    mov   rcx , [socket]
    int   0x60

    mov   [sst],rax

    ret



button_event:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Button event
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rax , 0x11
    int   0x60

    ; rax = status
    ; rbx = button id

    cmp   rbx , 950
    jne   nodopen
    cmp   [readfilepos],dword 4
    jae   still
    mov   [save_open],dword 1  ;open
    mov   [parameter],byte '[' ;open
    call  dialog_open
    jmp   still
  nodopen:
    cmp   rbx , 951
    jne   nodclear
    cmp   [readfilepos],dword 0
    je    still
    dec   dword [readfilepos]
    call  draw_window
    jmp   still
  nodclear:

    cmp   rbx , 901
    jne   nosdec
    cmp   [wanted_part],dword 1
    jbe   still
    dec   byte [wanted_part]
    call  decode_email
    call  check_scroll_size
    call  draw_email
    jmp   still
  nosdec:
    cmp   rbx , 902
    jne   nosinc
    mov   rax , [multipart_ids]
    ;; dec   rax
    cmp   [wanted_part],rax
    jae   still
    inc   byte [wanted_part]
    call  decode_email
    call  check_scroll_size
    call  draw_email
    jmp   still
  nosinc:
    cmp   rbx , 903
    jne   nosave
    call  get_save_content
    jmp   still

  get_save_content:

    mov   [decodeimage],byte 1
    call  decode_email

    mov   rax , 58
    mov   rbx , 2
    mov   rcx , 0
    mov   rdx , 0x010000
    mov   r8  , 0x200000
    mov   r9  , filesave
    int   0x60
    mov   rax , 58
    mov   rbx , 1
    mov   rcx , 0
    mov   rdx , [bodysize]
    mov   r8  , 0x200000
    mov   r9  , filesave
    int   0x60

    mov   [decodeimage],byte 0
    call  decode_email
    call  check_scroll_size

    ret

  nosave:

    cmp   rbx , 1101
    jne   nopop3select
    cmp   [selected_protocol],byte 0
    je    still
    call  disconnect
    mov   [selected_protocol],byte 0
    call  draw_protocol_buttons
    jmp   still
  nopop3select:
    cmp   rbx , 1102
    jne   noimapselect
    cmp   [selected_protocol],byte 1
    je    still
    call  disconnect
    mov   [selected_protocol],byte 1
    call  draw_protocol_buttons
    jmp   still
  noimapselect:
    cmp   rbx , 1001
    jne   notextboxentry1
    call  disconnect
    mov   r14 , textbox1
    call  read_textbox
    jmp   still
  notextboxentry1:
    cmp   rbx , 1002
    jne   notextboxentry2
    call  disconnect
    mov   r14 , textbox2
    call  read_textbox
    jmp   still
  notextboxentry2:
    cmp   rbx , 1003
    jne   notextboxentry3
    call  disconnect
    mov   [textbox3+5*8],dword 0
    mov   [textbox3+6*8],dword 0
    mov   r14 , textbox3
    call  read_textbox
    mov   rsi , textbox3+6*8
    mov   rdi , config_pass
    mov   rcx , 50
    cld
    rep   movsb
    mov   [textbox3+5*8],dword 0
    mov   rax , '********'
    mov   [textbox3+6*8],rax
    mov   rax , 0
    mov   [textbox3+7*8],rax
    mov   r14 , textbox3
    call  draw_textbox
    jmp   still
  notextboxentry3:
    cmp   rbx , 1004
    jne   notextboxentry4
    call  disconnect
    mov   r14 , textbox4
    call  read_textbox
    jmp   still
  notextboxentry4:
    cmp   rbx , 1005
    jne   notextboxentry5
    call  disconnect
    mov   r14 , textbox5
    call  read_textbox
    jmp   still
  notextboxentry5:
    cmp   rbx , 1011
    jne   notextboxentry11
    call  disconnect
    mov   r14 , textbox11
    call  read_textbox
    jmp   still
  notextboxentry11:
    cmp   rbx , 1012
    jne   notextboxentry12
    call  disconnect
    mov   r14 , textbox12
    call  read_textbox
    jmp   still
  notextboxentry12:

    cmp   rbx , 0x10000001
    jne   no_application_terminate_button
    call  disconnect
    mov   rax , 0x200
    int   0x60
  no_application_terminate_button:

    cmp   rbx , 0x106
    jne   no_application_terminate_menu
    call  disconnect
    mov   rax , 0x200
    int   0x60
  no_application_terminate_menu:

    ;
    ; Copy text
    ;

    cmp   rbx , 0x108
    jne   nocopy

    ;
    ; Copy email write -text
    ;

    cmp   [screen],byte 2
    jne   nocopywrite

    ; Search last character position

    mov   rax , 115
    mov   rsi , rax
    sub   rsi , 1
    imul  rsi , 80
    add   rsi , 0x180000
  searchreatched2:
    mov   rbx , rsi
    mov   rdi , rsi
    add   rdi , 80
  newrss2:
    cmp   [rsi],byte 32
    ja    reatchedfound2
    inc   rsi
    cmp   rsi , rdi
    jb    newrss2
    mov   rsi , rbx
    sub   rsi , 80
    dec   rax
    cmp   rax , 1
    ja    searchreatched2
  reatchedfound2:
    mov   [reatchedline],rax

    ; Copy

    mov   rsi , 0x180000
    mov   rdi , 0
    mov   r14 , 0

  newcopy:

    mov   rax , rsi
    add   rax , 79
  newls:
    cmp   [rax],byte ' '
    ja    lastfoundl
    dec   rax
    cmp   rax , rsi
    jae   newls
  lastfoundl:

    inc   rax

    push  qword [rax]
    push  rax
    mov   [rax],word 13+256*10
    mov   r10 , rsi
    mov   r11 , rax
    sub   r11 , rsi
    add   r11 , 2
    mov   rax , 142
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , r14
    add   rdx , r11
    mov   r8  , 0
    mov   r9  , r14
    int   0x60
    add   r14 , r11
    pop   rax
    pop   qword [rax]

    add   rsi , 80
    inc   rdi

    cmp   rdi , [reatchedline]
    jbe   newcopy

    jmp   still

  nocopywrite:

    ;
    ; Copy email read -text
    ;

    cmp   [screen],byte 1
    jne   nocopyread

    cmp   [emails],dword 0
    je    still

    mov   rbx , [email_start_pos]
    mov   r14 , 0
    mov   rdi , 0
    mov   r15 , [scroll_size]
    sub   r15 , 8

  del1x:

    push  rbx

    mov   rsi , rbx
    mov   rax , rbx
    add   rax , 80

    push  qword [rax]
    push  rax
    mov   [rax],word 13+256*10
    mov   r10 , rsi
    mov   r11 , rax
    sub   r11 , rsi
    add   r11 , 2
    mov   rax , 142
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , r14
    add   rdx , r11
    mov   r8  , 0
    mov   r9  , r14
    int   0x60
    add   r14 , r11
    pop   rax
    pop   qword [rax]
    pop   rbx

    add   rbx , 80

    inc   rdi
    cmp   rdi , r15
    jbe   del1x

    jmp   still

  nocopyread:

    jmp   still

  nocopy:

    ;
    ; Paste
    ;

    cmp   rbx , 0x109
    jne   nopaste
    cmp   [screen],byte 2
    jne   still
    mov   r10 , 0
  newletter:
    mov   rax , 142
    mov   rbx , 2
    mov   rcx , r10
    mov   rdx , str_ret
    mov   r8  , 1
    int   0x60
    cmp   rax , 1
    jne   still
    cmp   rbx , 0
    je    still
    mov   r11 , rbx
    movzx rcx , byte [str_ret]
    cmp   rcx , 10
    jbe   noaddpaste
    mov   rdx , 'Enter   '
    cmp   rcx , 13
    cmove rcx , rdx
    mov   rbx , 0
    push  rcx r10 r11
    mov   [stillret],byte 1
    call  write_email
    mov   [stillret],byte 0
    pop   r11 r10 rcx
    cmp   rcx , 'Ente'
    jne   nopdelay
    mov   rax , 5
    mov   rbx , 10
    int   0x60
  nopdelay:
  noaddpaste:
    inc   r10
    cmp   r10 , r11
    jb    newletter
    call  write_email_draw
    jmp   still
  str_ret:  db 'x',0
  stillret: dq 0x0
  nopaste:

    cmp   rbx , 400000
    jb    no_scroll11
    cmp   rbx , 499999
    ja    no_scroll11
    mov   [scroll11value],rbx
    call  scroll11
    call  draw_mail_folders
    jmp   still
  no_scroll11:

    cmp   rbx , 300000
    jb    no_scroll3
    cmp   rbx , 399999
    ja    no_scroll3
    mov   [scroll3value],rbx
    call  scroll3
    call  write_email_draw
    jmp   still
  no_scroll3:

    cmp   rbx , 200000
    jb    no_scroll2
    cmp   rbx , 299999
    ja    no_scroll2
    mov   [scroll2value],rbx
    call  scroll2
    call  draw_email
    jmp   still
  no_scroll2:

    cmp   rbx , 100000
    jb    no_scroll1
    cmp   rbx , 199999
    ja    no_scroll1
    mov   [scroll1value],rbx
    sub   rbx , 100000
    imul  rbx , 10
    inc   rbx
    mov   [mail_start],rbx
    call  scroll1
    call  draw_subjects
    jmp   still
  no_scroll1:

    cmp   rbx , 11
    jb    noscreenstate
    cmp   rbx , 15
    ja    noscreenstate
    sub   rbx , 10
    cmp   rbx , [screen]
    je    still
    mov   [screen],rbx
    call  draw_window

    jmp   still
  noscreenstate:

    cmp   rbx , 18
    jne   nodisc
    call  disconnect
    jmp   still
  nodisc:

    cmp   rbx , 19
    jne   norec
    cmp   [sst],byte 4
    je    norec
    mov   [email_start_pos],dword 0x100000
    mov   rdi , 0x200000
    mov   rcx , 0x400000
    mov   rax , 0
    cld
    rep   stosb
    mov   rdi , 0x600000
    mov   rcx , 0x400000
    mov   rax , 0
    cld
    rep   stosb
    mov   [screen],dword 1
    call  draw_window
    call  connect
    jmp   still
  norec:

    cmp   rbx , 51
    jne   no_send_button

    call  send_email

  no_send_button:

    jmp   still



send_email:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Send email
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rsi , sending
    call  show_user

    ; Disconnect inbox

    call  disconnect

    mov   rax , 5
    mov   rbx , 50
    int   0x60

    call  status
    mov   rsi , disconnected
    call  show_status

    mov   rsi , ips2
    mov   rdi , smtp_ip
    call  get_ip

    cmp   [smtp_ip],dword 0
    je    smtpipfail

    ; Open socket

    mov   rax , 53
    mov   rbx , 5
    mov   rcx , [localport]
    inc   dword [localport]
    mov   rdx , 25
    mov   rsi , [smtp_ip]
    mov   rdi , 1
    int   0x60
    mov   [send_socket],rax

    mov   rax , 5
    mov   rbx , 100
    int   0x60

    ; Helo mycomputer

    mov   rsi , helo
    call  send_email_data
    call  wait_for_send_result
    cmp   [result],dword '250 '
    jne   sel99

    mov   rsi , header
    call  show_user

    ; Mail from:< >

    mov   rsi , mail_from
    call  send_email_data
    mov   rsi , config_account
    call  send_email_data
    mov   rsi , close_add
    call  send_email_data
    call  wait_for_send_result
    cmp   [result],dword '250 '
    jne   sel99

    ; Rcpt to:< >

    mov   rsi , rcpt_to
    call  send_email_data
    mov   rsi , config_sendto
    call  send_email_data
    mov   rsi , close_add
    call  send_email_data
    call  wait_for_send_result
    cmp   [result],dword '250 '
    jne   sel99

    ; Data

    mov   rsi , data_send
    call  send_email_data
    call  wait_for_send_result
    cmp   [result],dword '354 '
    jne   sel99

    mov   rsi , body
    call  show_user

    ; Subject:

    mov   rsi , data_subject
    call  send_email_data
    mov   rsi , config_subject
    call  send_email_data
    mov   rsi , send_lf
    call  send_email_data

    mov   rax , 5
    mov   rbx , 20
    int   0x60

    ; To:

    mov   rsi , data_to
    call  send_email_data
    mov   rsi , config_sendto
    call  send_email_data
    mov   rsi , send_lf
    call  send_email_data

    ; Switch to multipart ?

    cmp   [readfilepos],dword 0
    je    nomultipartsend
    mov   [send_delay],dword 1
    call  send_multipart
    mov   [send_delay],dword 5
    jmp   closec
  nomultipartsend:

    ; lf

    mov   rsi , send_lf
    call  send_email_data
    mov   rsi , send_lf
    call  send_email_data

    mov   rax , 5
    mov   rbx , 20
    int   0x60

    ; Send Email body

    call  send_email_body

  closec:

    ; '.'

    mov   rsi , data_end
    call  send_email_data
    call  wait_for_send_result
    cmp   [result],dword '250 '
    jne   sel99

  succ:

    ; Quit

    mov   rsi , send_quit
    call  send_email_data

    ; Success

    mov   rax , 5
    mov   rbx , 20
    int   0x60

    call  close_send_socket

    mov   rsi , success
    call  show_user

    ret

  sel99:

    ; Fail

    mov   rsi , send_quit
    call  send_email_data

    mov   rax , 5
    mov   rbx , 20
    int   0x60

    call  close_send_socket

  smtpipfail:

    mov   rsi , fail
    call  show_user

    ret


find_line_end:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Search for line end
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  flel0:
    cmp   [r10-1],byte 32
    ja    flel1
    dec   r10
    jmp   flel0
  flel1:

    ret


send_email_body:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Send mail body content
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; Search last character position

    mov   rax , 115
    mov   rsi , rax
    sub   rsi , 2
    imul  rsi , 80
    add   rsi , 0x180000
  searchreatched:
    mov   rbx , rsi
    mov   rdi , rsi
    add   rdi , 80
  newrss:
    cmp   [rsi],byte 32
    ja    reatchedfound
    inc   rsi
    cmp   rsi , rdi
    jb    newrss
    mov   rsi , rbx
    sub   rsi , 80
    dec   rax
    cmp   rax , 1
    ja    searchreatched
  reatchedfound:
    mov   [reatchedline],rax

    ; Email body

    mov   rdi , 0x180000
    mov   rax , 0
  sendnewline2:
    push  rax
    push  rdi
    mov   rsi , rdi
    ;
    mov   r10 , rsi
    add   r10 , 80
    call  find_line_end
    cmp   r10 , rsi
    jbe   zerolenline
    push  qword [r10]
    push  r10
    mov   [r10],byte 0
    call  send_email_data
    pop   r10
    pop   qword [r10]
  zerolenline:
    ;
    mov   rax , 5
    mov   rbx , 10
    int   0x60
    mov   rsi , send_lf
    call  send_email_data
    pop   rdi
    pop   rax
    add   rdi , 80
    inc   rax
    cmp   rax , 110
    ja    nomorelines2
    cmp   rax , [reatchedline]
    jbe   sendnewline2
  nomorelines2:

    ret


send_multipart:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Send mail body and included files
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rsi , sendmd01
    call  send_email_data

    ; Send Email body

    call  send_email_body

    ; Add include files

    mov   [currentreadfilepos],dword 0

  add_new_include_file:

    mov   rbp , [currentreadfilepos]
    cmp   rbp , [readfilepos]
    jae   includefilesdone

    inc   dword [currentreadfilepos]

    ; Send header

    mov   rsi , sendmd02
    call  send_email_data
    mov   rsi , [currentreadfilepos]
    dec   rsi
    imul  rsi , 8
    mov   rsi , [readfile1typepointer+rsi]
    call  send_email_data
    mov   rsi , sendmd021
    call  send_email_data
    mov   rsi , [currentreadfilepos]
    dec   rsi
    imul  rsi , 64
    add   rsi , readfile1name
    call  send_email_data
    mov   rsi , sendmd022
    call  send_email_data
    mov   rsi , [currentreadfilepos]
    dec   rsi
    imul  rsi , 64
    add   rsi , readfile1name
    call  send_email_data
    mov   rsi , sendmd023
    call  send_email_data
    mov   rsi , [currentreadfilepos]
    dec   rsi
    imul  rsi , 64
    add   rsi , readfile1name
    call  send_email_data
    mov   rsi , sendmd024
    call  send_email_data

    ; Send file

    mov   rdi , 0x600000
    mov   rcx , 0x400000
    mov   rax , 0
    cld
    rep   stosb

    mov   rax , 58
    mov   rbx , 0
    mov   rcx , 0
    mov   rdx , 0x3ff000/512
    mov   r8  , 0x600000
    mov   r9  , [currentreadfilepos]
    dec   r9
    imul  r9  , 128
    add   r9  , readfile1
    int   0x60

    mov   r15 , rbx
    cmp   r15 , 0x3ff000
    jbe   r15fine
    mov   r15 , 0x3ff000
  r15fine:
    mov   rsi , 0x600000
    mov   r14 , 0
    mov   rdi , filesendrow

  newmakerow:

    movzx rax , byte [rsi]
    shr   al  , 2
    mov   bl  , [base64char+rax]
    mov   [rdi],bl
    inc   rdi

    movzx rax , byte [rsi]
    and   al  , 11b
    shl   al  , 4
    movzx rbx , byte [rsi+1]
    shr   bl  , 4
    add   al  , bl
    mov   bl  , [base64char+rax]
    mov   [rdi],bl
    inc   rdi

    inc   rsi
    inc   r14
    cmp   r14 , r15
    jae   filesent

    movzx rax , byte [rsi]
    and   al  , 1111b
    shl   al  , 2
    movzx rbx , byte [rsi+1]
    shr   bl  , 6
    add   al  , bl
    mov   bl  , [base64char+rax]
    mov   [rdi],bl
    inc   rdi

    inc   rsi
    inc   r14
    cmp   r14 , r15
    jae   filesent

    movzx rax , byte [rsi]
    and   al  , 111111b
    mov   bl  , [base64char+rax]
    mov   [rdi],bl
    inc   rdi

    inc   rsi
    inc   r14
    cmp   r14 , r15
    jae   filesent

    cmp   rdi , filesendrow+60
    jb    newmakerow

    mov   [rdi],dword 13+10*256

    push  rsi rdi r14 r15
    mov   rsi , filesendrow
    call  send_email_data
    pop   r15 r14 rdi rsi

    ; Display progress

    push  rax rbx rcx rdx rsi
    inc   dword [progresstick]
    test  [progresstick],dword 63
    jnz   noshowprogress
    mov   rax , r14
    imul  rax , 99
    mov   rbx , r15
    xor   rdx , rdx
    div   rbx
    mov   rbx , 10
    xor   rdx , rdx
    div   rbx
    add   al , 48
    add   dl , 48
    mov   [string_progress+16],al
    mov   [string_progress+17],dl
    mov   al , [currentreadfilepos]
    add   al , 48
    mov   [string_progress+13],al
    mov   rsi , string_progress
    call  show_user
  noshowprogress:
    pop   rsi rdx rcx rbx rax

    mov   rdi , filesendrow

    jmp   newmakerow

  filesent:

    mov   [rdi],dword 13+10*256
    push  rsi rdi r14 r15
    mov   rsi , filesendrow
    call  send_email_data
    pop   r15 r14 rdi rsi

    jmp   add_new_include_file

  includefilesdone:

    mov   rdi , 0x600000
    mov   rcx , 0x400000
    mov   rax , 0
    cld
    rep   stosb

    mov   rsi , sendmd03
    call  send_email_data

    ret


close_send_socket:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Close email send connection
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rax , 53
    mov   rbx , 8
    mov   rcx , [send_socket]
    int   0x60

    ret


send_email_data:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Send email data
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rax , '        '
    mov   [result],rax

    ; check socket_state

    mov   rax , 53
    mov   rbx , 6
    mov   rcx , [send_socket]
    int   0x60

    cmp   rax , 4
    jne   skipsend

    ; read all data from socket

  read_more_data:

    mov   rax , 53
    mov   rbx , 2
    mov   rcx , [send_socket]
    int   0x60

    cmp   rax , 0
    je    no_data_in_buffer

    mov   rax , 53
    mov   rbx , 3
    mov   rcx , [send_socket]
    int   0x60

    jmp   read_more_data

  no_data_in_buffer:

    ; send data

    mov   rdx , rsi
    dec   rdx
  sdsl1:
    inc   rdx
    cmp   [rdx],byte 0
    jne   sdsl1
    sub   rdx , rsi

    and   rdx , 0x1ff
    cmp   rdx , 0
    je    skipsend

    mov   rax , 53
    mov   rbx , 7
    mov   rcx , [send_socket]
    int   0x60

    ; rsi = pointer to asciiz

    ;; call  show_user

  skipsend:

    mov   rax , 5
    mov   rbx , [send_delay]
    int   0x60

    ret



wait_for_send_result:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Wait for send result
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; read sockets first 4 bytes to result+ until 13,10

    mov   rdi , 0
    mov   r15 , 0

  wait_for_data:

    mov   rax , 5
    mov   rbx , 1
    int   0x60

    ; Timeout 10 seconds

    inc   r15
    cmp   r15 , 200
    jae   nomoredata

  wfdl1:

    mov   rax , 53
    mov   rbx , 2
    mov   rcx , [send_socket]
    int   0x60

    cmp   rax , 0
    je    wait_for_data

    mov   r15 , 0

    mov   rax , 53
    mov   rbx , 3
    mov   rcx , [send_socket]
    int   0x60

    cmp   rdi , 4
    jae   nodatabuf
    mov   [result+rdi],bl
    inc   rdi
  nodatabuf:

    cmp   bl , 10
    je    nomoredata

    jmp   wfdl1

  nomoredata:

    ret


show_user:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Display user
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    push  rax rbx rcx rdx rsi r9

    mov   rax , 13
    mov   rbx , 355 * 0x100000000 + 6*26
    mov   rcx , 094 * 0x100000000 + 12
    mov   rdx , 0xffffff
    int   0x60

    mov   rax , 4
    mov   rbx , rsi
    mov   rcx , 355
    mov   rdx , 094
    mov   rsi , 0x000000
    mov   r9  , 1
    int   0x60

    pop   r9 rsi rdx rcx rbx rax

    ret


draw_window:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Draw window
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rax , 0xC                          ; Beginning of window draw
    mov   rbx , 0x1
    int   0x60

    mov   rax , 141
    mov   rbx , 3
    int   0x60
    and   rax , 0xff
    mov   [fontsize],rax

    mov   rax , 0x0                          ; Draw window
    mov   rbx , 0x0000007000000000+60+6*80   ; x start & size
    mov   rcx , 0x00000030000001C3 +12       ; y start & size
    mov   rdx , border_color                 ; type    & border color
    mov   r8  , 0x0000000000000001           ; draw flags
    mov   r9  , window_label                 ; 0 or label - asciiz
    mov   r10 , menu_struct                  ; 0 or pointer to menu struct
    int   0x60

    mov   rax , 8
    mov   rbx , 15 * 0x100000000 + 60
    mov   rcx , 50 * 0x100000000 + 19
    mov   rdx , 11
    mov   r8  , 0
    mov   r9  , inbox_text
    int   0x60
    mov   rbx , 75 * 0x100000000 + 60
    inc   rdx
    mov   r9  , send_text
    int   0x60
    mov   rbx , 135 * 0x100000000 + 60
    inc   rdx
    mov   r9  , settings_text
    int   0x60

    mov   rsi , [stat]
    mov   [stat], dword 1
    call  show_status

    cmp   [screen],byte 1
    jne   noscreen1
    call  inbox_screen
  noscreen1:

    cmp   [screen],byte 2
    jne   noscreen2
    call  send_screen
  noscreen2:

    cmp   [screen],byte 3
    jne   noscreen3
    call  setup_screen
  noscreen3:

    mov   rax , 0xc
    mov   rbx , 2
    int   0x60

    ret


inbox_screen:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Display inbox text and controls
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    call  scroll1
    call  scroll11
    call  scroll2

    call  draw_subjects
    call  draw_email
    call  draw_mail_folders

    ret


draw_email_controls:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Display email controls
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    emcx  equ  250
    emcy  equ  210

    mov   rax , 13
    mov   rbx , 20 shl 32 + 500
    mov   rcx , 439 shl 32 + 12
    mov   rdx , border_color
    int   0x60

    mov   rax , 4
    mov   rbx , string_attachments
    mov   rcx , 20
    mov   rdx , 440
    mov   r9  , 1
    mov   rsi , 0x808080
    int   0x60

    ret



send_screen:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Email write window
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rbx , 16
    mov   rcx , 86
    mov   rdx , 522
    mov   r8  , 138+15+1
    call  rectangle2

    mov   rbx , 16
    mov   rcx , 153+10
    mov   rdx , 522
    mov   r8  , 433
    call  rectangle2

    mov   rax , 4
    mov   rbx , send_text_address
    mov   rcx , 25
    mov   rdx , 95+4 - 4
    mov   rsi , 0x000000
    mov   r9  , 1
  sendl1:
    int   0x60
    add   rdx , 20
    add   rbx , 30
    cmp   [rbx],byte 'x'
    jne   sendl1

    mov   rax , 4
    mov   rcx , 24+6*10;6*2
    mov   rdx , 99-4;20*2
    mov   rbx , config_account
    mov   r9  , 1
    mov   rsi , 0x000000
    int   0x60

    call  write_email_draw

    mov   rax , 38
    mov   rbx , 315
    mov   rcx , 86
    mov   rdx , 315
    mov   r8  , 138+15+1
    mov   r9  , 0x000000
    int   0x60

    mov   rax , 8
    mov   rbx , (344+3+3) * 0x100000000 + 149-6-6
    mov   rcx , (103+5+1) * 0x100000000 + 19
    mov   rdx , 51
    mov   r8  , 0
    mov   r9  , ready_for_send
    int   0x60

    call  scroll3

    mov   r14 , textbox11
    call  draw_textbox
    mov   r14 , textbox12
    call  draw_textbox

    mov   rax , 8
    mov   rbx , 453 * 0x100000000 + 35
    mov   rcx , 438 * 0x100000000 + 13
    mov   rdx , 951
    mov   r8  , 0
    mov   r9  , string_clear_files
    int   0x60

    mov   rax , 8
    mov   rbx , 488 * 0x100000000 + 35
    mov   rcx , 438 * 0x100000000 + 13
    mov   rdx , 950
    mov   r8  , 0
    mov   r9  , string_include_file
    int   0x60

    ; Get included send files

    mov   rax , 0
    mov   [sendattachments],dword '-'

    mov   rdi , sendattachments

  getincf:

    cmp   rax , [readfilepos]
    jae   nogetincf

    ; default type: octet stream

    mov   r12 , rax
    imul  r12 , 8
    add   r12 , readfile1typepointer
    mov   [r12],dword type_octet_stream

    mov   rsi , rax
    imul  rsi , 128
    add   rsi , readfile1
    dec   rsi

  newrsi:
    inc   rsi
    cmp   [rsi],byte 0
    jne   newrsi
    mov   rcx , rsi
  newrsi2:
    dec   rsi
    cmp   [rsi],byte 'a'
    jb    notoup
    cmp   [rsi],byte 'z'
    ja    notoup
    sub   [rsi],dword 32
  notoup:
    ;
    ;
    cmp   [rsi],dword '.ZIP'
    jne   nozip
    mov   [r12],dword type_zip
  nozip:
    cmp   [rsi],dword '.GIF'
    jne   nogif
    mov   [r12],dword type_gif
  nogif:
    cmp   [rsi],dword '.JPG'
    jne   nojpg
    mov   [r12],dword type_jpg
  nojpg:
    cmp   [rsi],dword '.PNG'
    jne   nopng
    mov   [r12],dword type_png
  nopng:
    cmp   [rsi],dword '.BMP'
    jne   nobmp
    mov   [r12],dword type_bmp
  nobmp:
    ;
    ;
    cmp   [rsi],byte '/'
    jne   newrsi2
    inc   rsi
    sub   rcx , rsi
    ; Save name
    push  rcx rsi rdi
    mov   rdi , rax
    imul  rdi , 64
    add   rdi , readfile1name
    cld
    rep   movsb
    mov   [rdi],dword 0
    pop   rdi rsi rcx
    ; save name to att..
    cld
    rep   movsb

    mov   [rdi],word ', '
    add   rdi , 2

    inc   rax

    jmp   getincf

  nogetincf:

    cmp   [rdi-2],byte ','
    jne   noincf
    mov   [rdi-2],dword 0
  noincf:

    mov   rax , 4
    mov   rbx , string_send_attachments
    mov   rcx , 20
    mov   rdx , 440
    mov   r9  , 1
    mov   rsi , 0x808080
    int   0x60

    ret



rectangle2:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Draw rectangle
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rax , 38
    mov   r9  , 0

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
    push  r8
    mov   r8  , rcx
    int   0x60
    pop   r8

    push  rcx
    push  rbx
    mov   rbx , rbx
    inc   rbx
    shl   rbx , 32
    mov   bx  , dx
    pop   rax
    inc   rax
    sub   bx , ax
    mov   rcx , rcx
    inc   rcx
    shl   rcx , 32
    mov   cx  , r8w
    pop   rax
    inc   rax
    sub   cx , ax
    mov   rdx , 0xffffff
    mov   rax , 13
    int   0x60

    ret


setup_screen:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Setup window
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rbx , 16
    mov   rcx , 86
    mov   rdx , 522
    mov   r8  , 433+11
    call  rectangle2

    ; Text

    mov   rax , 4
    mov   rbx , setup_text
    mov   rcx , 25
    mov   rdx , 95
    mov   r9  , 1
    mov   rsi , 0x000000
  setl1:
    cmp   [rbx],byte '.'
    jne   nolineskip
    add   rdx , 20
    inc   rbx
    jmp   skipline
  nolineskip:
    cmp   [rbx],byte ','
    jne   nolineh
    add   rdx , 6
    inc   rbx
    jmp   skipline
  nolineh:
    int   0x60
    add   rbx , 79
    add   rdx , 20
  skipline:
    cmp   [rbx],byte 'x'
    jne   setl1

    ; Textbox

    mov   r14 , textbox1
    call  draw_textbox
    mov   r14 , textbox2
    call  draw_textbox

    mov   r14 , textbox3
    call  draw_textbox
    mov   r14 , textbox4
    call  draw_textbox
    mov   r14 , textbox5
    call  draw_textbox

    call  draw_protocol_buttons

    ; Disconnect from inbox button

    mov   rax , 8
    mov   rbx , 22 * 0x100000000 + 150
    mov   rcx , (310-32) * 0x100000000 + 21
    mov   rdx , 18
    mov   r8  , 0
    mov   r9  , string_disconnect
    int   0x60

    ; Connect to inbox button

    mov   rax , 8
    mov   rbx , (22+150) * 0x100000000 + 150
    ;;mov   rcx , 310 * 0x100000000 + 21
    mov   rdx , 19
    mov   r8  , 0
    mov   r9  , string_connect
    int   0x60

    ret



draw_protocol_buttons:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Display protocol buttons
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   [string_protocol_pop3+1],byte 'X'
    mov   [string_protocol_imap+1],byte ' '
    cmp   [selected_protocol],byte 1
    jne   no_imap_protocol
    mov   [string_protocol_pop3+1],byte ' '
    mov   [string_protocol_imap+1],byte 'X'
  no_imap_protocol:

    mov   rax , 8
    mov   rbx , 370 * 0x100000000 + 82
    mov   rcx , 110 * 0x100000000 + 20
    mov   rdx , 1101
    mov   r8  , 0
    mov   r9  , string_protocol_pop3
    int   0x60
    mov   rcx , 130 * 0x100000000 + 20
    inc   rdx
    mov   r9  , string_protocol_imap
    int   0x60

    ret



check_fetch:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Display subject fetch state
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rax , [mail_start]
    dec   rax
    imul  rax , 80
    add   rax , image_end+78
    cmp   [rax],byte 0
    jne   nofetch
    ; print loading
    push  rax
    call  fetch_subjects
    call  draw_subjects
    pop   rax
    mov   [rax],byte 1
  nofetch:

    ret


draw_subjects:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Draw email subjects
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    subjx equ 128

    ; Number

    mov   rcx , [mail_start]
    mov   r14 , 0
    mov   rdx , (26+subjx) * 65536+90
    mov   rsi , 0x000000

  dsl2:

    mov   rax , 47
    mov   rbx , 4*65536

    push  r10
    push  rax rbx rcx rdx
    mov   r12 , rcx
    mov   rax , 13
    mov   rbx , (17+subjx)*0x100000000+81*6+7-subjx
    mov   rcx , rdx
    and   rcx , 0xffff
    sub   rcx , 3
    shl   rcx , 32
    add   rcx , 1+2
    mov   rdx , 0xffffff
    mov   rsi , 0x000000
    mov   r10 , 12
    cmp   r12 , [selected_mail]
    jne   nosel
    mov   rdx , selected_color
  nosel:
    int   0x60

    mov   r12 , 0x100000000
    add   rcx , r12
    dec   r10
    jnz   nosel

    pop   rdx rcx rbx rax
    pop   r10

    int   0x40
    add   rdx , 12
    inc   rcx
    inc   r14
    cmp   r14 , 10
    jb    dsl2

    ; Subject

    mov   rax , 4
    mov   rbx , [mail_start]
    dec   rbx
    imul  rbx , 80
    add   rbx , image_end ; ?
    mov   rcx , 20+subjx
    mov   rdx , 90
    mov   r9  , 1
    mov   r12 , [mail_start]
    mov   r15 , 10
  dsl1:
    mov   rsi , 0x000000

    ; Cut the subject length

    mov   [rbx+59],byte 0

    int   0x60
    add   rdx , 12
    add   rbx , 80
    inc   r12
    dec   r15
    jnz   dsl1

    ret



draw_email:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Display email
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    call  draw_email_controls

    mov   rax , 13
    mov   rbx , 17*0x100000000 + 6*82+1
    mov   rcx , 230
    sub   rcx , 2
    shl   rcx , 32
    add   rcx , 3
    mov   rdx , 0xffffff
    int   0x60

    mov   rax , 4
    mov   rbx , [scroll2value]
    sub   rbx , 200000
    imul  rbx , 80
    add   rbx , [email_start_pos] ; 0x100000
    mov   rcx , 20
    mov   rdx , 230
    mov   r9  , 1
    mov   rsi , 0x000000
    mov   r15 , 17
  del1:
    mov   r14b , [rbx+80]
    mov   [rbx+80],byte 0
    push  rax rbx rcx rdx
    mov   rax , 13
    mov   rbx , 17*0x100000000 + 6*82+1
    mov   rcx , rdx
    sub   rcx , 1
    shl   rcx , 32
    add   rcx , [fontsize]
    add   rcx , 3
    mov   rdx , 0xffffff
    int   0x60
    pop   rdx rcx rbx rax
    int   0x60
    mov   [rbx+80],r14b
    add   rdx , [fontsize]
    add   rdx , 3
    add   rbx , 80
    cmp   rdx , 422
    jbe   del1

    mov   rax , 13
    mov   rbx , 17*0x100000000 + 6*82+1
    dec   rdx
    mov   rcx , rdx
    shl   rcx , 32
    mov   r8  , 433
    sub   r8  , rdx
    add   rcx , r8
    cmp   cx , 0
    je    nobr
    cmp   cx , 20
    ja    nobr
    mov   rdx , 0xffffff
    int   0x60
  nobr:

    ret


scroll1:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Scroll
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rax , [emails]
    cmp   rax , 0
    je    scl1
    dec   rax
  scl1:
    xor   rdx , rdx
    mov   rbx , 10
    div   rbx
    inc   rax
    mov   rdx , rax

    mov   rax , 113
    mov   rbx , 1
    mov   rcx , 100000
    mov   r8  , [scroll1value]
    mov   r9  , 510
    mov   r10 , 87
    mov   r11 , 12*10+1
    int   0x60

    mov   [scrollchange],dword 0

    mov   rcx , r10
    dec   rcx
    mov   r8  , rcx
    mov   rax , 38
    mov   rbx , 16+subjx
    mov   rdx , 510+12
    mov   r9  , 0x000000
    int   0x60
    push  rcx
    add   rcx , r11
    add   rcx , 2
    mov   r8  , rcx
    int   0x60
    mov   rdx , rbx
    pop   rcx
    int   0x60

    ret


check_scroll_size:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Count scroll size
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    push  rax rbx rcx rdx rdi

    mov   rdi , [email_start_pos]
    add   rdi , 0x200000

  newsi:

    cmp   [rdi],byte ' '
    ja    sifound

    dec   rdi
    cmp   rdi , [email_start_pos]
    ja    newsi

  sifound:

    add   rdi , 100

    sub   rdi , [email_start_pos]
    mov   rax , rdi
    xor   rdx , rdx
    mov   rbx , 80
    div   rbx

    add   rax , 10
    mov   [scroll_size],rax

    pop   rdi rdx rcx rbx rax

    call  scroll2

    ret



scroll2:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Scroll
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rdx , [scroll_size]

    mov   rax , 113
    mov   rbx , 1
    mov   rcx , 200000
    mov   r8  , [scroll2value]
    mov   r9  , 510
    mov   r10 , 227
    mov   r11 , 205
    int   0x60

    call  rectangle

    ret


scroll3:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Scroll
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rax , 113
    mov   rbx , 1
    mov   rcx , 300000
    mov   rdx , 100-23
    mov   r8  , [scroll3value]
    mov   r9  , 510
    mov   r10 , 154+10
    mov   r11 , 278-10
    int   0x60

    ret


scroll11:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Scroll
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rax , 113
    mov   rbx , 1
    mov   rcx , 400000
    mov   rdx , [folders]
    cmp   rdx , 20
    jae   rdxok
    mov   rdx , 20
  rdxok:
    mov   r8  , [scroll11value]
    mov   r9  , 114
    mov   r10 , 87
    mov   r11 , 121
    int   0x60

    mov   rcx , r10
    dec   rcx
    mov   r8  , rcx
    mov   rax , 38
    mov   rbx , 16
    mov   rdx , 126 ; 510+12
    mov   r9  , 0x000000
    int   0x60
    push  rcx
    add   rcx , r11
    add   rcx , 2
    mov   r8  , rcx
    int   0x60
    mov   rdx , rbx
    pop   rcx
    int   0x60

    ret


draw_mail_folders:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Draw mail folders
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   r15 , 0
    mov   rbx , [scroll11value]
    sub   rbx , 400000
    imul  rbx , 80
    add   rbx , 0x170000+1
    mov   rcx , 22
    mov   rdx , 90
    mov   r9  , 1
    mov   rsi , 0x000000
  drawfolder:
    push  rax rbx rcx rdx r14 r15
    mov   rax , 13
    mov   rbx , rcx
    sub   rbx , 5
    mov   rcx , rdx
    sub   rcx , 3
    shl   rbx , 32
    add   rbx , 16*6+1
    shl   rcx , 32
    add   rcx , 12+2
    add   r15 , [scroll11value]
    sub   r15 , 400000
    inc   r15
    mov   rdx , 0xffffff
    cmp   r15 , [selected_folder]
    jne   no_selected_folder
    mov   rdx , selected_color
  no_selected_folder:
    int   0x60
    pop   r15 r14 rdx rcx rbx rax
    mov   rax , 4
    push  qword [rbx]
    push  qword [rbx+8]
    push  qword [rbx+16]
    ; Remove '"'
    mov   r13 , rbx
    mov   r14 , 15
  newqs:
    cmp   [r13],byte '"'
    jne   noq
    mov   [r13],byte ' '
  noq:
    inc   r13
    dec   r14
    jnz   newqs
    ; Cut length
    mov   [rbx+13],byte 0
    int   0x60
    pop   qword [rbx+16]
    pop   qword [rbx+8]
    pop   qword [rbx]
    add   rbx , 80
    add   rdx , 12
    inc   r15
    cmp   r15 , 10
    jb    drawfolder

    ret



rectangle:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Display rectangle
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rcx , r10
    dec   rcx
    mov   r8  , rcx
    mov   rax , 38
    mov   rbx , 16
    mov   rdx , 510+12
    mov   r9  , 0x000000
    int   0x60
    push  rcx
    add   rcx , r11
    add   rcx , 2
    mov   r8  , rcx
    int   0x60
    mov   rdx , rbx
    pop   rcx
    int   0x60

    ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Data area
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


window_label:

    db    'MAIL',0        ; Window label

inbox_text:

    db    'INBOX',0

send_text:

    db    'SEND',0

settings_text:

    db    'SETUP',0

string_connect:

    db    'CONNECT INBOX',0

string_disconnect:

    db    'DISCONNECT INBOX',0


string_protocol_imap:

    db    '[ ] IMAP',0

string_protocol_pop3:

    db    '[X] POP3',0

scroll1value:

    dq    100000

scroll2value:

    dq    200000

scroll3value:

    dq    300000

scroll11value:

    dq    400000

screen:

    dq    1 ; 2

selected_protocol:

    dq    0  ; 0=POP3, 1=IMAP

smtp_ip:

    db    192,168,0,97
    dd    0

send_text_address:

    db    'Sender:                      ',0
    db    'Send to:                     ',0
    db    'Subject:                     ',0
    db    'x'


setup_text:

    db    'Incoming                               '
    db    '                                       ',0
    db    'Server:                                '
    db    '                                       ',0
    db    'Username:                              '
    db    '                                       ',0
    db    'Password:        ********              '
    db    '                                       ',0
    db    '                                       '
    db    '                                       ',0
    db    'Outgoing                               '
    db    '                                       ',0
    db    'SMTP server:                           '
    db    '                                       ',0
    db    'Account:                               '
    db    '                                       ',0
    db    '....,'
    db    'Click attachment name to save incoming '
    db    'file.                                  ',0
    db    'View incoming email part information wi'
    db    'th keys <1-9>.                         ',0
    db    '..Default setup values, except password, '
    db    'in Config.mnt.                         ',0

    db    'x'

menu_struct:               ; Menu Struct

    dq   0                 ; Version

    dq   0x100             ; Start value of ID to return ( ID + Line )

                           ; Returned when menu closes and
                           ; user made no selections.

    db   0,'FILE',0        ; ID = 0x100 + 1
    db   1,'New',0         ; ID = 0x100 + 2
    db   1,'Open..',0      ; ID = 0x100 + 3
    db   1,'Save..',0      ; ID = 0x100 + 4
    db   1,'-',0           ; ID = 0x100 + 5
    db   1,'Quit',0        ; ID = 0x100 + 6

    db   0,'EDIT',0        ; ID = 0x100 + 1
    db   1,'Copy',0        ; ID = 0x100 + 8
    db   1,'Paste',0       ; ID = 0x100 + 9


    db   255               ; End of Menu Struct


pops:     db 'email_pop_server  ',0
users:    db 'email_pop_user    ',0
smtps:    db 'email_smtp_server ',0
accounts: db 'email_smtp_user   ',0

unichar:

    db    0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
    db    '                '
    db    ' !"#$%&',"'()*+,-./"
    db    '0123456789:;<=>?'
    db    '@ABCDEFGHIJKLMNO'
    db    'PQRSTUVWXYZ[\]^_'
    db    '`abcdefghijklmno'
    db    'pqrstuvwxyz{|}~ '
    db    '                '
    db    '                '
    db    '                '
    db    '                '
    db    'AAAA',201,200,'ACEEEEIIII'
    db    'DNOOOO',202,'xOUUUUYBB'
    db    'aaaa',193,192,'aceeeeiiii'
    db    'onoooo',194,'/ouuuuyby'

writex: dq 0
writey: dq 0

mailerror: dq 0x0

reatchedline: dq 1

reading_email: db 'Reading email..',0

mail_start: dq 1

scroll_size:  dq  200

localport: dq 23543

opening db 'Opening..',0

inbox: db 'Mails:',0

emails: dq 0

stat_command: db 'stat',13,10,0

disconnected: db 'Disconnected',0

connected:    db 'Connected',0

stat:         dq  disconnected

folders: dq 0x0

selected_folder: dq 1

drawline:  dq  999999

reading_subjects: db 'Reading headers..',0

disconnecting: db 'Disconnecting..',0

okpos: dq 0xe0000

input_pos: dq image_end

endmarker: db '.'

headerpos: dq image_end

mailtype:  dq 0x0

sst:  dq 0

lf:   db 13,10,0

top:  db 'Top 4496 0',13,10,0
top2: db 'Top 4496 50000',13,10,0
retr: db 'Retr 4495',13,10,0

quit: db 'Quit',13,10,0

pop_ip: db 192,168,0,99
        dd 0

quit_imap: db '2220 logout',13,10,0

imap_user_password:

    db    '1234 LOGIN ',0

imap_user_password_space:

    db    ' ',0

imap_user_password_crlf:

    db    13,10,0

imap_select:

    db    '1235 SELECT INBOX',13,10,0
    times  128 db 0

imap_top:

    db    '1236 FETCH 0751 body[header]',13,10,0

imap_top2:

    db    '1236 FETCH 0751 body[text]',13,10,0

imap_folders:

    db    '1236 LIST "" "*"',13,10,0

socket: dq 0x0

sending: db 'Connecting..',0
success: db 'Success',0
fail:    db 'Fail',0

header:  db 'Sending header..',0
body:    db 'Sending body..',0

result:    dq 0

send_socket: dq 0

helo:      db 'Helo mycomputer',13,10,0

mail_from: db 'Mail from:<',0
rcpt_to:   db 'Rcpt to:<',0
close_add: db '>',13,10,0
data_send: db 'Data',13,10,0

data_subject: db 'Subject: ',0
data_to:      db 'To: ',0
data_end:     db 13,10,13,10,13,10,'.',13,10,0

send_lf:   db 13,10,0

send_quit: db 'quit',13,10,0

ready_for_send: db 'SEND MAIL',0

arrow: db '<',0

selected_mail: dq 1
scrollchange:  dq 0
wanted_part:   dq 1

string_content_transfer_encoding: db 'Content-Transfer-Encoding:',0
string_content_descriptor:  db 'Content-Description:',0
string_content_type:        db 'Content-Type:',0
string_content_disposition: db 'Content-Disposition:',0
string_boundary:            db 'boundary=',0

part1start:  dq 0x0
b64t:        dq 0x0

multipart_ids: dq 0x0

;string_original: db '<',0
;string_partx:    db '>',0
;string_saveas:   db 'SAVE..',0
;string_display_wanted:   db 'Content: '
;string_wanted:           db '00/01',0
;string_display_wanted2:  db 'Attachment(s): -',0

progresstick: dq 0x0

string_progress:  db  'Sending file X (xx%)',0

readfilepos: dq 0x0

currentreadfilepos: dq 0x0

base64char:

    db    'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    db    'abcdefghijklmnopqrstuvwxyz'
    db    '0123456789+/'

sendmd01:

    db    'MIME-Version: 1.0',13,10
    db    'Content-Type: multipart/mixed;',13,10
    db    ' boundary=-----B4O5U6N7D9876j689kem3o3985itmeri3e94u6xx',13,10
    db    13,10
    db    '-------B4O5U6N7D9876j689kem3o3985itmeri3e94u6xx',13,10
    db    'Content-Type: text/plain',13,10
    db    'Content-Transfer-Encoding: 7bit',13,10
    db    13,10
    db    0

sendmd02:

    db    13,10
    db    '-------B4O5U6N7D9876j689kem3o3985itmeri3e94u6xx',13,10
    db    'Content-Type: ' ; image/jpeg;',13,10
    db    0

sendmd021:

    db    ';',13,10,' name="' ;test.jpg"',13,10
    db    0

sendmd022:

    db    '"',13,10,'Content-Transfer-Encoding: base64',13,10
    db    'Content-Description: ' ; image file',13,10
    db    0

sendmd023:

    db    13,10,'Content-Disposition: attachment;',13,10
    db    ' filename="' ; test.jpg"',13,10
    db    0

sendmd024:

    db    '"',13,10
    db    13,10
    db    0

sendmd03:

    db    13,10
    db    '-------B4O5U6N7D9876j689kem3o3985itmeri3e94u6xx--',13,10
    db    13,10
    db    0

stpos:      dq 0x0
lflf:       dq 0x0
linestart:  dq 0x0

email_start_pos: dq 0x100000

decodeimage: dq 0x0
attpos:      dq 0x0
bodysize:    dq 65536
save_open:   dq 0x0
save_part:   dq 0x0

printcounter: dq 0x0
printtext:    dq 0x0

fontsize:    dq  9
send_delay:  dq  5
addbyte:     dq  0

blocksize:   dq 0
blockpos:    dq 0

file_search: db  '/FD/1/FBROWSER   ',0
parameter:   db  'S000000]',0

string_clear_files:  db '-',0
string_include_file: db '+',0

type_octet_stream:  db  'application/octet-stream',0
type_zip:           db  'application/zip',0
type_gif:           db  'image/gif',0
type_jpg:           db  'image/jpeg',0
type_png:           db  'image/png',0
type_bmp:           db  'image/bmp',0


I_END:

tcpipblock: times 68000 db ?

textbox1:

    dq    ? ; 0         ; Type
    dq    ? ; 100       ; X position
    dq    ? ; 220       ; X size
    dq    ? ; 130-20    ; Y position
    dq    ? ; 1001      ; Button ID
    dq    ? ; 0         ; Current text length
ips1:
    times 150 db ? ; 0  ; Text

textbox2:

    dq    ? ; 0         ;
    dq    ? ; 100       ;
    dq    ? ; 220       ;
    dq    ? ; 150-20    ;
    dq    ? ; 1002      ;
    dq    ? ; 0         ;
config_user:
    times 150 db ? ; 0  ;

textbox3:

    dq    ? ; 0         ;
    dq    ? ; 100       ;
    dq    ? ; 220       ;
    dq    ? ; 170-20    ;
    dq    ? ; 1003      ;
    dq    ? ; 0         ;
    times 8 db ?   ; db    '********'
    times 150 db ? ; 0  ;

config_pass: times 150 db ? ; 0


textbox4:

    dq    ? ; 0         ;
    dq    ? ; 100       ;
    dq    ? ; 220       ;
    dq    ? ; 250-40    ;
    dq    ? ; 1004      ;
    dq    ? ; 0         ;
ips2:
    times 150 db ? ; 0  ;

textbox5:

    dq    ? ; 0         ;
    dq    ? ; 100       ;
    dq    ? ; 220       ;
    dq    ? ; 270-40    ;
    dq    ? ; 1005      ;
    dq    ? ; 0         ;
config_account:
    times 150 db ? ; 0  ;


textbox11:

    dq    ? ; 0         ; Type
    dq    ? ; 80        ; X position
    dq    ? ; 220       ; X size
    dq    ? ; 94+20-4   ; Y position
    dq    ? ; 1011      ; Button ID
    dq    ? ; 0         ; Current text length
config_sendto:
    times 150 db ? ; 0  ; Text

textbox12:

    dq    ? ; 0         ;
    dq    ? ; 80        ;
    dq    ? ; 220       ;
    dq    ? ; 114+20-4  ;
    dq    ? ; 1012      ;
    dq    ? ; 0         ;
config_subject:
    times 150 db ? ; 0  ;


user: times 125 db ?  ; db 'User '
pass: times 125 db ?  ; db 'Pass '

estring:      times 100 db ?
config_real:  times 200 db ?
config_reply: times 200 db ?
filesendrow:  times 90  db ?

readfile1:  times 128 db ?
readfile2:  times 128 db ?
readfile3:  times 128 db ?
readfile4:  times 128 db ?

readfile1typepointer: dq ?
readfile2typepointer: dq ?
readfile3typepointer: dq ?
readfile4typepointer: dq ?

readfile1name: times 64 db ?
readfile2name: times 64 db ?
readfile3name: times 64 db ?
readfile4name: times 64 db ?

string_b2:
string_b: db  ?,? ; '--'
          times 256 db ?

ipc_memory:

    dq  ? ; 0      ;; lock - 0=unlocked , 1=locked
    dq  ? ; 16     ;; first free position from ipc_memory
                   ;;
filesave:          ;;
                   ;;
    times 100 db ? ;;

string_send_attachments: db ?,?,?,?,?,?,?,?,?,?,?,?,?,?,?
sendattachments:         times 260 db ?

string_attachments:      db ?,?,?,?,?,?,?,?,?,?,?,?,?,?,?
string_files:            times 260 db ?

multipart_pos: times 100 dq ?


image_end:

