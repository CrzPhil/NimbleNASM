%include "functions.asm"

SECTION .data
key  db  "myfriendofmisery", 0h ; 16 bytes 
fname   db  "/tmp/encryptme.txt", 0h
blocksize db    32

SECTION .bss    
fcontent    resb    32
offset  resb    2
fstat   resb    32

SECTION .text
global main
main:
    mov ebp, esp; for correct debugging
    
    ; start at 0 offset
    mov eax, 0
    mov [offset], eax
    
    ; Get r/w FD for file
    mov eax, fname
    call getFDboth

    ; fstat for filesize
    mov ecx, fstat
    mov ebx, eax
    mov eax, 0x6c
    int 80h
    
    ; st_size is at fstat+20
    mov eax, [fstat+20]
    
    ; See how many times we need to iterate through blocks to 
    ; pass entire file
    xor edx, edx
    movzx ecx, byte [blocksize]
    div ecx
    
    ; if there is no remainder, then eax is our count
    cmp edx, 0
    je  .ready
    
    ; if there is a remainder, eax+1 is our count
    add eax, 1
    
.ready:
    ; edi will keep track of iterations
    mov edi, eax
    mov eax, ebx ; for continuity 
    
.outerloop:
    ; Move file offset
    mov edx, 0          ; SEEK_SET (curr += offset)
    movzx ecx, byte [offset]   ; bytes to move
    mov ebx, eax
    mov eax, 19
    int 80h
    
    ; Read contents
    movzx edx, byte [blocksize] ; bytes to read
    mov ecx, fcontent   ; address to read to
    ;mov ebx, eax        ; FD
    mov eax, 3          ; OPCODE
    int 80h             ; EAX will store the bytes read 
    
    ; iterator 
    mov esi, eax
    push    eax
    
    ; save FD
    push    ebx
    
.loop:
    sub esi, 1
    
    ; reset
    xor eax, eax
    xor edx, edx
    
    ; Encrypt
    movzx eax, byte [fcontent+esi]

    push eax
    ; get itr % [keysize (16)]
    xor edx, edx
    mov eax, esi
    mov ebx, 16
    div ebx
    
    pop eax
    
    movzx edx, byte [key+edx]
    xor eax, edx
    mov [fcontent+esi], al
    
    ; Check if we iterated through the entire block
    cmp esi, 0
    jne .loop
    
    
    ; Restore FD
    pop ebx
    mov eax, ebx
   
    
    ; Move ptr to start before writing
    mov edx, 0          ; SEEK_SET(beginning of file)
    movzx ecx, byte [offset]   ; bytes to move
    mov ebx, eax
    mov eax, 19
    int 80h
   
    ; bytes that were read/encrypted
    pop esi
      
    ; Write contents
    mov edx, esi
    mov ecx, fcontent
    ;mov ebx, eax ;FD
    mov eax, 4
    int 80h
    
    ; increment offset
    movzx eax, byte [offset]
    add eax, [blocksize]
    mov [offset], eax
    
    mov eax, ebx        ; FD

    ; outer loop guard
    sub edi, 1
    cmp edi, 0
    jne .outerloop
    
    ; Close FD
    mov eax, ebx        ; FD
    call closeFD
    
    ; print fcontent
    mov eax, fcontent
    call sprintLF
    
    xor eax, eax
    ret
