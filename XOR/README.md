# XOR in NASM

## Takeaways and lessons

It has been a while since I worked on this repo, so coming back to assembly after months of absence meant I had to revisit some chapters. The core learning of this project, which was easier to implement than I thought, was paying attention to `movzx`. A lot of the bug-fixing I had to go through was because I loaded my variables using `mov eax, [somevar]`, instead of `movzx eax, byte [somevar]`. By not zero-extending the value, I oftentimes had junk in the rest of `eax`, which caused spurious calculations and all sorts of crazy bugs. 

## How it works

This is a simple file encryption program, using a 16-byte key and a 32 byte block size (modifiable). The program will read from a file, one block at a time, XOR-ing it with the key and writing back into the file. It will repeat this process until the whole file is "encrypted" in this manner.

## Implementation

Just like in the other projects, I have set aside a `functions.asm` file from my previous assembly projects, that contains an array of useful subroutines, such as printing strings; calculating string lengths; converting ASCII numbers to integers; etc. Nevertheless, I make an effort to contain the bulk of the program's logic inside the single main.asm file.

### Program Flow

On a high level, the program works as follows:

1. Get a file descriptor for the target file
2. Determine the filesize 
3. Calculate number of iterations to pass the whole file
4. Read, encrypt, and write contents, one block at a time

Not too bad, right?

### Memory allocation

This time around there are only two hard-coded strings, namely the key (bad practice, but this is a NASM tutorial not a cryptography course) and the target file. Both of these could easily be ported to be command-line arguments, but I'll leave that for future work. 

```assembly
SECTION .data
key db "myfriendofmisery", 0h ; 16 bytes
fname db "/tmp/encryptme.txt", 0h
blocksize db 32
```

In the `.bss` section we need an area to write the file's blocks as we iterate them, such that we can XOR the bytes and re-write them. We also need to keep track of the offset, to remember which part of the file we are reading from and writing to. This could be done with the stack, but it's more readable this way. Finally, since we run `fstat` to determine the file size, we need a place to store the struct. 

```assembly
SECTION .bss
fcontent resb 32
offset resb 2
fstat resb 32
```

### Main

So, first we need to get a file descriptor (FD) for the file. Since we are both reading and writing, we will need to use the `open` syscall (opcode `0x05`). This is one of the subroutines found in `funtions.asm`, so we can just pass the memory address of the filepath to `eax` and call `getFDboth`. Then, we need to determine the file's size, so we know how many iterations it will take us to read and encrypt it, 32 bytes at a time (or, more precisely, `blocksize` bytes at a time).  

For that purpose, we use the `fstat` [syscall](https://man7.org/linux/man-pages/man2/fstat.2.html) (opcode `0x6c`), which returns the following struct:

```c
**#include <sys/stat.h>**

**struct stat {**
   **dev_t      st_dev;**      /* ID of device containing file */
   **ino_t      st_ino;**      /* Inode number */
   **mode_t     st_mode;**     /* File type and mode */
   **nlink_t    st_nlink;**    /* Number of hard links */
   **uid_t      st_uid;**      /* User ID of owner */
   **gid_t      st_gid;**      /* Group ID of owner */
   **dev_t      st_rdev;**     /* Device ID (if special file) */
   **off_t      st_size;**     /* Total size, in bytes */
   **blksize_t  st_blksize;**  /* Block size for filesystem I/O */
   **blkcnt_t   st_blocks;**   /* Number of 512 B blocks allocated */

   /* Since POSIX.1-2008, this structure supports nanosecond
	  precision for the following timestamp fields.
	  For the details before POSIX.1-2008, see VERSIONS. */

   **struct timespec  st_atim;**  /* Time of last access */
   **struct timespec  st_mtim;**  /* Time of last modification */
   **struct timespec  st_ctim;**  /* Time of last status change */

**#define st_atime  st_atim.tv_sec**  /* Backward compatibility */
**#define st_mtime  st_mtim.tv_sec**
**#define st_ctime  st_ctim.tv_sec**
**};**
```

We are only interested in `st_size`, which is found at a 20-byte offset: 

```assembly
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
```

Having found the size in bytes, we then use `div` to calculate the iterations needed for a full pass:

```assembly
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
```

This is just modulo arithmetic; if there is a remainder, we add one to the quotient in `EAX`. 

### Outer Loop

Our first loop consists of iterating through the file's blocks. To that effect, we need to keep track of which block (offset) we are currently processing. It also means we need a way to jump to certain locations within the file, which we can do with the [syscall](https://man7.org/linux/man-pages/man2/lseek.2.html) `lseek` (opcode `0x13`). 

```assembly
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
```

We first use `lseek` to move to a given offset within the file, and then we read the contents to `fcontent`. The syscall allows for three options, specified in the `EDX` register:

|              | Description                                                         | Value |
| ------------ | ------------------------------------------------------------------- | ----- |
| **SEEK_SET** | The file offset is set to _offset_ bytes.                           | 0     |
| **SEEK_CUR** | The file offset is set to its current location plus _offset_ bytes. | 1     |
| **SEEK_END** | The file offset is set to the size of the file plus *offset* bytes. | 2     |
In our case, since we are keeping track of the `offset` variable, we use `SEEK_SET`, specifying how many bytes to move from the **start** of the file.  

This approach of using a block size and jumping through the file with `lseek` has the benefit that we don't have to store the entire file in memory, but can encrypt it incrementally. 
### Inner Loop

After calling `sys_read` on the current block, `EAX` will hold the amount of bytes that were read. Normally, this will be equal to `[blocksize]`, unless we tried reading `[blocksize]` bytes but the file had fewer. As such, we can use `EAX` to make sure we only iterate through as many bytes as were read, making it a perfect candidate for our inner loop's guard condition.

```assembly
    ; Read contents
    movzx edx, byte [blocksize] ; bytes to read
    mov ecx, fcontent   ; address to read to
    ;mov ebx, eax        ; FD
    mov eax, 3          ; OPCODE
    int 80h             ; EAX will store the bytes read 
    
    ; iterator 
    mov esi, eax
    push    eax
```

We will decrement `ESI` in each iteration, as we cycle through the characters in the current block.

```assembly
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
```

The encryption, as stated, is just a letter-by-letter `XOR` operation. Since the key is 16 bytes, we also need a modulo operation inside this block, to make sure we cycle through the key properly. 

Given how we use `ESI` as an iterator, this means we are iterating the letters in reverse order, right-to-left. Once `ESI` is zero, we know we are done with this block and can proceed to write the encrypted block to the file.

To do so, we restore the FD that we pushed to the stack earlier, and then use `lseek` again to move to the proper location in the file.

```assembly
    ; Restore FD
    pop ebx
    mov eax, ebx
   
    
    ; Move ptr to start before writing
    mov edx, 0          ; SEEK_SET(beginning of file)
    movzx ecx, byte [offset]   ; bytes to move
    mov ebx, eax
    mov eax, 19
    int 80h
```

We then pop into `ESI`, which as we recall previously is the amount of bytes that were `read` from the file, and write that many bytes into the file.

```assembly
    ; bytes that were read/encrypted
    pop esi
      
    ; Write contents
    mov edx, esi
    mov ecx, fcontent
    ;mov ebx, eax ;FD
    mov eax, 4
    int 80h
```

Finally, we increment the offset by `[blocksize]` and then check if we have another iteration to run through or if we are done.

```assembly
    ; increment offset
    movzx eax, byte [offset]
    add eax, [blocksize]
    mov [offset], eax
    
    mov eax, ebx        ; FD

    ; outer loop guard
    sub edi, 1
    cmp edi, 0
    jne .outerloop
```

That is all there is to it- 146 lines of assembly and we have a fully-functional XOR encryptor, with variable block size. 
