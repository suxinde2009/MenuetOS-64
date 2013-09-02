;
;   Menuet64 HD boot 0.4
;
;   Bootloader is distributed with ABSOLUTELY NO WARRANTY.
;   See file /fd/1/license for details.
;   Youre free to modify this file for use with Menuet64.
;   Copyright 2005-2013 V.Turjanmaa
;
;   Instructions for Menuet 64 HD boot
;
;   00) This procedure is experimental. Backup HDs.
;   01) Menuet64 is able to boot from first partition of fat32 hd.
;   02) Create menuet system directory to hd root, eg 'MSYS'
;   03) Copy all files from M64 floppy to 'MSYS'
;   04) Copy kernel.mnt and config.mnt to root directory of hd, /hd/1/.
;   05) Set system_directory in /hd/1/config.mnt to "/HD/1/MSYS/"
;   06) Define hd parameters in /hd/1/config.mnt according to your hd.
;   07) You might want to disable floppy in /hd/1/config.mnt
;       by setting 'fd_1_enable' to zero.
;   08) Set hdbase and hdid in this file according to your hd.
;   09) Try the bootsector first with fd: set header in this file for fat12.
;   10) Compile this file and copy the binary to floppy's bootsector.
;   11) Boot your system from floppy, and all files should be
;       loaded from hd.
;   12) Retry the above instructions until applications etc. work fine.
;   13) You can use this configuration to quickly boot from hd with only
;       inserting the bootup floppy.
;   13) Modify the bytes in Fat32 _header_ in this file according to
;       your current harddisks fat32 header. The bytes must be modified, or
;       you'll end up with complete harddisk data loss, yes really.
;   14) Compile this file with a Fat32 header and copy the binary to HD.

partition_start_cluster  equ  data_area+0
fat_start_cluster        equ  data_area+4
root_start_block         equ  data_area+8
number_of_fats           equ  data_area+12
fat_size                 equ  data_area+16
block_start_cluster      equ  data_area+20
sectors_per_cluster      equ  data_area+24
in_cache                 equ  data_area+28

Debug                    equ  0
Fat12                    equ  1
Fat32                    equ  2

; SETUP
                         ; Load image from:
                         ;
hdbase   equ  0x1f0      ; 0x1f0 - primary device
                         ; 0x170 - secondary device
                         ;
hdid     equ  0x00       ; 0x00 - master hd
                         ; 0x10 - slave hd

                         ; Install bootsector to:
                         ;
Header   equ  Fat12      ; Fat12:
                         ; Floppy installation can be used as such.
                         ;
                         ; Fat32:
                         ; Harddisk installation requires modification
                         ; of the Fat32 header, or you'll lose all data
                         ; on the target partition.
                         ;
                         ; Debug:
                         ; No Header. Use for debugging with floppy only!
                         ; Messages at low left corner during boot:
                         ; 1 : bootsector loaded
                         ; 2 : file not found
                         ; 3 : file found - load starts
                         ; 4 : jump to kernel


                   jmp start_program
                   nop

if Header = Fat12

oemname            db 'MENUETOS'
bytespersector     dw 512
sectorspercluster  db 1
ressectors         dw 1
numcopiesfat       db 2
maxallocrootdir    dw 224
maxsectors         dw 2880 ;for 1.44 mbytes disk
mediadescriptor    db 0f0h ;fd = 2 sides 18 sectors
sectorsperfat      dw 9
sectorspertrack    dw 18
heads              dw 2
hiddensectors      dd 0
hugesectors        dd 0 ;if sectors > 65536
drivenumber        db 0
                   db 0
bootsignature      db 029h ;extended boot signature
volumeid           dd 0
volumelabel        db 'TEST       '
filesystemtype     db 'FAT12   '

end if


if Header = Fat32

Id                 db  'MSWIN4.1'   ; Modify header or all hd-data
BytesPerSector     dw  200h         ; will be lost
SectorsPerCluster  db  8
ReservedSector     dw  20h
NumberOfFATs       db  2
RootEntries        dw  0
TotalSectors       dw  0
MediaDescriptor    db  0F8h ; hd
SectorsPerFAT      dw  0
SectorsPerTrack    dw  63
Heads              dw  255
HiddenSectors      dd  63
BigTotalSectors    db  0xbf,0x64,0x9c,0x00
BigSectorsPerFat   db  0x10,0x27,0x00,0x00
ExtFlags           dw  0
FS_Version         dw  0
RootDirStrtClus    dd  2
FSInfoSec          dw  0x01         ; at 0x30
BkUpBootSec        dw  0x06
Reserved           dw  0,0,0,0,0,0
Drive              db  80h          ; at 0x40
HeadTemp           db  0
Signature          db  29h
SerialNumber       db  0x07,0x16,0x1a,0x39
VolumeLabel        db  'TEST       '
FileSystemID       db  'FAT32   '

end if

; 0x4000:0xfff0   - stack set at start
; 0x1000:0+       - kernel.mnt
; 0x5400:0+       - config.mnt

start_program:

  cli
  cld

  mov  ax,0x4000
  mov  ss,ax
  mov  sp,0xfff0

  push word 0x1000
  pop  es

  push cs
  pop  ds

if Header = Debug

  mov  ax,0xb800
  mov  gs,ax
  mov  [gs:80*24*2],byte '1'

end if

  xor  eax,eax
  call hd_read

  mov  eax,[es:0x1c6]
  mov  [partition_start_cluster],eax

  call hd_read

  mov  [in_cache],dword 0          ; clear fat cache

  mov   cx,word [es:0xe]          ; fat start cluster
  mov  [fat_start_cluster],cx

  mov  cl,byte [es:0x10]         ; number of fats
  mov  [number_of_fats],cl

  mov  ecx,[es:0x24]               ; fat size
  mov  [fat_size],ecx

  mov  eax,[number_of_fats]         ; block start cluster =
  imul eax,[fat_size]               ; number_of_fats*fat_size
  add  eax,[fat_start_cluster]      ; +fat_start_cluster
  mov  [block_start_cluster],eax

  mov   cl,byte [es:0xd]            ; sectors per cluster
  mov  [sectors_per_cluster],cl

  mov  bx , 0x1000
  mov  ebp , 'KERN'
  call read_file

  mov  bx , 0x5400 ; 0x8000 to 0x5400 (0.99.25)
  mov  ebp , 'CONF'
  call read_file

if Header = Fat12

    mov   dx , 0x3f2                  ; turn floppy motor off
    xor   al , al
    out   dx , al

end if

  jmp  0x1000:0000


read_file:

  mov  es , bx

  mov  eax , 0 ; cluster 2

new_file_cluster_search:

  push eax

  imul eax,[sectors_per_cluster]
  add  eax,[block_start_cluster]
  add  eax,[partition_start_cluster]

  mov  ecx,[sectors_per_cluster]

 new_file_search:

  call hd_read

  mov  esi,0
 .newn:
  cmp  [es:esi],ebp
  jne  .not_found
  cmp  [es:esi+8],word 'MN'
  jne  .not_found
  jmp  .found
 .not_found:
  add  esi,32
  cmp  esi,512
  jne  .newn

  inc  eax

  loop new_file_search

  pop  eax
  call find_next_cluster_from_fat

  cmp  eax,0xf000000
  jb   new_file_search

  if Header = Debug
     mov  [gs:80*24*2],byte '2'
  end if

  jmp  $

 .found:

  pop  eax

  if Header = Debug
   mov  [gs:80*24*2],byte '3'
  end if

  mov  ax,[es:esi+20]              ; first cluster of file data
  shl  eax,16
  mov  ax,[es:esi+26]

  sub  eax,2                       ; eax has the first cluster of file

new_cluster_of_file:

  push eax

  imul eax,[sectors_per_cluster]
  add  eax,[block_start_cluster]
  add  eax,[partition_start_cluster]

  mov  ecx,[sectors_per_cluster]
 newbr:
  call hd_read

  mov  dx,es
  add  dx,512 / 16
  mov  es,dx

  inc  eax

  loop newbr

  pop  eax
  call find_next_cluster_from_fat

  cmp  eax,0xf000000
  jb   new_cluster_of_file

  ret


find_next_cluster_from_fat:

  push es
  mov  bx,0x1000-512/16
  mov  es,bx

  add  eax,2
  shl  eax,2

  mov  ebx,eax
  shr  eax,9             ; cluster no

  add  eax,[fat_start_cluster]
  add  eax,[partition_start_cluster]

  cmp  eax,[in_cache]    ; check cache
  je   no_read
  call hd_read
  mov  [in_cache],eax
 no_read:

  and  ebx,511           ; in cluster
  mov  eax,[es:ebx]
  sub  eax,2

  pop  es

  ret



hd_read:      ; eax block to read

    pushad
    push  eax

  newhdread:

    mov   dx,hdbase
    inc   dx
    mov   al,0
    out   dx,al

    inc   dx
    mov   al,1
    out   dx,al

    inc   dx
    pop   ax
    out   dx,al

    inc   dx
    shr   ax,8
    out   dx,al

    inc   dx
    pop   ax
    out   dx,al

    inc   dx
    shr   ax,8
    and   al,1+2+4+8
    add   al,hdid
    add   al,128+64+32
    out   dx,al

    inc   dx
    mov   al,0x20
    out   dx,al

  .hdwait:

    in    al,dx
    test  al,128
    jnz   .hdwait

    mov   edi,0x0
    mov   ecx,256
    mov   dx,hdbase
    cld
    rep   insw

    popad

    ret

times ((0x1fe-$) and 0xff) db 00h

  db 55h,0aah ;boot signature

data_area:


