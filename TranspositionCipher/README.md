# Transposition Cipher

## How it works

Just as with substitution ciphers, we require a key- or rather a keyword- with no repeated letters in it. The ciphertext is then padded and divided into n columns, one for each letter in the key. The columns are then rearranged into alphabetical order.

Taking the ciphertext `The quick brown fox jumps over the lazy dog` and the keyword `BAD` as an example yields the following columns:

```
B A D   ->  A B D

t h e       h t e 
q u i       u q i
c k b       k c b
r o w       o r w
n f o       f n o
x j u       j x u
m p s       p m s
o v e       v o e
r t h       t r h
e l a       l e a
z y d       y z d
o g X       g o X
```

The ciphertext is then produced by reading the columns left-to-right, throughout the rows:

```
hteuqikcborwfnojxupmsvoetrhleayzdgoX
```

Another method would be to just read the columns vertically and sequentially, which is actually considered more secure as the letters in a word are spread further apart. While my solution actually implements that step as you will see, I opted for the first implementation since it was a bit more difficult in terms of problem-solving.  

## Implementation in x86 assembly

Just like in the other projects, I have set aside a `functions.asm` file from my previous assembly projects, that contains an array of useful subroutines, such as printing strings; calculating string lengths; converting ASCII numbers to integers; etc. Nevertheless, I make an effort to contain the bulk of the program's logic inside the single main.asm file.  

### Program Flow

On a high level, the program works as follows:

1. Query the user for the plaintext.
2. Query the user for an alphabetical key (preferably no duplicate letters).
3. Strip the plaintext of spaces and pad it to be a multiple of the key length.
4. Split the plaintext into `n` columns.
5. Rearrange the columns alphabetically.
6. Read through the rows of the rearranged columns and save the ciphertext.

### Memory allocation

To begin with, I defined the necessary user prompts in the `.data` section.
 
```assembly
SECTION .data
prompt  db      "Text:  ", 0h
prompt2 db      "Secret:        ", 0h
prompt3 db      "Encrypt (e) or Decrypt (d): ", 0h
```

The next step is to set aside enough room for our variables. 

```assembly
SECTION .bss
userin          resd    255,
textlen         resb    8,
secret          resb    255,
secretlen       resb    8,
mode            resb    4,
blockspace      resq    255,
rankMap         resb    255,
userout         resd    255,
```

After printing out the prompts and using the same `stripToNull` subroutine as in the `Caesar` cipher's implementation, I proceed to calculate the padding for the plaintext, based on the key's length.

```assembly
_getPadding:
        xor     edx, edx
        div     ebx
        cmp     edx, 0h
        je      .applyPadding

        inc     ecx
        pop     eax
        inc     eax
        push    eax

        jmp     _getPadding

.applyPadding:
        cmp     ecx, 0h
        je      _split

        mov     eax, [textlen]

        mov     ebx, userin
        add     ebx, eax

.L1:
        cmp     ecx, 0h
        je      _split

        mov     dword [ebx], 0x58
        inc     ebx
        dec     ecx

        jmp     .L1
```

We iterate through the plaintext, appending `0x58` (or `X` characters) until its length is a multiple of the key's length. This is necessary in order to now split the text into columns:

```assembly
_split:
        mov     eax, userin
        call    slen
        mov     [textlen], eax

        xor     ecx, ecx                ; Block counter (aka letters in secret)
        xor     esi, esi                ; iterator for userin
        mov     ebx, userin
        xor     edi, edi                ; iterator for blockspace

.L1:
        cmp     ecx, [secretlen]
        je      _rearrange
        xor     esi, esi

.L2:
        xor     edx, edx
        push    esi
        sub     esi, ecx
        cmp     esi, 0xffffffff         ; happens when esi-ecx = -1
        je      .neg

        mov     eax, esi
        mov     esi, [secretlen]
        div     esi
        pop     esi

        cmp     edx, 0h
        jne     .nextLetter

        movzx   eax, byte [userin+esi]
        mov     [blockspace+edi], eax
        inc     edi

.nextLetter:
        inc     esi

        cmp     esi, [textlen]
        jne     .L2

        inc     ecx
        jmp     .L1

.neg:
        pop     esi
        jmp     .nextLetter
```

There's a lot going on here. First, we set up a counter in `ecx` that will keep track of the key's letters. Secondly, we store iterators in `esi` and `edi` for the plaintext and destination address, respectively. The two loops `L1` and `L2` are responsible for the actual splitting of the plaintext into columns. The output is stored in the `blockspace` address.  
Importantly, after this step, the columns of the plaintext are laid out next to one another inside `blockspace`. Essentially, it looks something like this:

```
Plaintext: Gotta love assembly
Key: CBA

len(strip(Plaintext)) = 17 
Padded Plaintext: GottaloveassemblyX

Columns: 

C B A
-----
G o t
t a l
o v e
a s s
e m b
l y X

Blockspace: GtoaeloavsmytlesbX
```

Now as stated in the introduction, leaving the columns vertically and rearranging them alphabetically, is actually considered cryptographically more secure, since the letters are actually further apart from each other. That means we could have stopped here, implemented the rearranging function, and called it a day, but I wanted to implement the cipher in its entirety, as the next couple steps come with their own sets of problems.  
That being said, the next step at this point is to rearrange the columns. To do so, we need to establish the key's letter's alphabetical order, and map that to the columns. For that purpose I wrote a subroutine called `createRankMap`.   


```assembly
_createRankMap:
  push  edx
  push  ecx
  push  ebx
  push  eax

  mov ecx, [secretlen]
  xor eax, eax    ; iterate through letters in key

.L1:
  cmp eax, ecx
  je  .end
  movzx edx, byte [secret+eax]
  xor ebx, ebx
  xor esi, esi

.L2:
  cmp ebx, ecx    ; if iterated through all letters (in second loop)
  je  .nextLetter
  movzx edi, byte [secret+ebx]

  inc ebx

  cmp edi, edx
  jb  .skip
  jmp .L2

.skip:
  inc esi
  jmp .L2

.nextLetter:
  mov [rankMap+eax], si
  inc eax
  jmp .L1

.end:
  pop eax
  pop ebx
  pop ecx
  pop edx
  ret
```

This subroutine iterates through the key's letters using two loops, with the effect of establishing that letter's index in an alphabetical order, which it stores in the `rankMap` address.   
For instance:

```
Key: CBA
RankMap: 210

Key: LAZY 
RankMap: 1032
```

So, while it does not actually rearrange the letters, it gives us their order, which we can use to shuffle the columns by adding proper increments.  
Under the `_rearrange` label, we now recycle the `userin` address, to hold the shuffled `blockspace` values. This actually has a convenient side-effect of essentially overwriting the plaintext, which is always good practice in cryptographic implementations (usually they are zero-d out in memory).

```assembly
_rearrange:
  call _createRankMap

  mov ebx, blockspace   ; input
  mov esi, userin       ; output
  
  ; Get column length in eax
  mov ecx, [secretlen]
  mov eax, [textlen]
  div ecx

  xor ecx, ecx  ; key iterator (and rankMap iterator)
  xor edx, edx  ; column iterator
  xor edi, edi  ; holds moved values
```

We first establish our variables. We calculate the column length and store it in `eax`. `ecx` is used to iterate through the key, as well as the `rankMap` indeces, so as to determine their position. `edx` is used to iterate through the columns in `blockspace`, and `edi` is responsible for moving the values.

```assembly
.L1:
  cmp edx, eax
  je  .nextcol

  movzx edi, byte [ebx+edx]
  push  eax
  push  ecx
  push  edx
  movzx ecx, byte [rankMap+ecx]
  mul ecx         ; col_len * rankMap[key_index]
  pop edx
  add eax, edx    ; add index position of letter

  push  edx
  mov edx, edi
  mov [esi+eax], dl ; move/copy letter to userin
  pop edx

  pop ecx
  pop eax         ; reset eax to col_len

  inc edx
  jmp .L1

.nextcol:
  inc ecx
  cmp ecx, [secretlen]
  je  _readsecret

  add ebx, edx    ; shift pointer to next column
  xor edx, edx    ; reset index
  jmp .L1
```

During rearranging, it is important that we use the registers' lower, 8-bit values, when moving the bytes. Otherwise, we get alignment issues that tormented me for a long time when figuring out this step. Even if I specified `movzx edi, byte [xyz]`, and then tried moving from `edi` to the target address in order to append to the previously moved byte, it would either overwrite it or create a gap to the next byte, which in hindsight is logical as we are moving the entire 32 bits, despite only the first 8 being used.  

After this step, the columns are still arranged vertically next to one another, but now their positions are alphabetically shuffled. Finally, the last step is to read the columns row-by-row to produce the ciphertext (again, it is actually considered more secure to read the columns vertically, so we could just print the ciphertext as it is now and call it a day).

```assembly
_readsecret:
  ; iterate through updated userin and save secret to userout
  ; Get column length in eax
  xor edx, edx
  mov ecx, [secretlen]
  mov eax, [textlen]
  div ecx

  xor ecx, ecx    ; column iterator (key length)
  xor edi, edi    ; column content iterator (column length)
  xor ebx, ebx

  mov esi, userout

.L1:
  cmp edi, eax
  je  _end

  xor ecx, ecx

.L2:
  cmp ecx, [secretlen]
  je  .nextLetter

  push  eax
  mul ecx
  mov ebx, eax
  add ebx, edi
  pop eax
  movzx edx, byte [userin+ebx]

  mov [esi], dl

  inc esi
  inc ecx
  jmp .L2

.nextLetter:
  inc edi
  jmp .L1
```

This step is trivial; we simply use two iterators, one that spans a column's length, and one that circles through all columns (key length). We then save the ciphertext, byte-by-byte, into `userout`, incrementing the iterator by the column's length `n` times, before moving on to the next letter (row) and repeating the process.

Finally, we print out the ciphertext and exit gracefully.

```assembly
_end:
        mov     eax, userout
        call    sprintLF
        call    quit
```

Example:

```
./main
Text:   The quick brown fox jumps over the lazy dog
Secret: CBA
Encrypt (e) or Decrypt (d): e
ehTiuqbkcworofnujxspmevohtraledyzXgo

./main
Text:   Messenger of fear in sight Dark deception kills the light
Secret: CHAOS
Encrypt (e) or Decrypt (d): e
sMeseengroeffarsinigDhtarekdceiptonlkilsethlitghXX
```
