# Caesar Cipher

## How it works

The Caesar Cipher, or shift cipher, is one of the simplest forms of encryption. It is based on substitution, where each letter in the plaintext is replaced by a letter some **fixed** number of positions down the alphabet.

![img](https://upload.wikimedia.org/wikipedia/commons/thumb/4/4a/Caesar_cipher_left_shift_of_3.svg/800px-Caesar_cipher_left_shift_of_3.svg.png)

## Implementation in x86 assembly

To begin with, I have set aside a `functions.asm` file from my previous assembly projects, that contains an array of useful subroutines, such as printing strings; calculating string lengths; converting ASCII numbers to integers; etc. Nevertheless, I make an effort to contain the bulk of the program's logic inside the single `main.asm` file.

### Program Flow

The program will follow the following steps:

1. Prompt the user for a string and key
2. Prompt the user for whether to encrypt or decrypt the message.
3. Strip any whitespace from the string and convert the key to an integer.
4. Process the mode (encrypt or decrypt).
5. Loop through each character in the string and shift it according to the key and mode.
6. Output the result.

### Memory allocation

That being said, let us get to it. I start by defining a couple of necessary messages for the command line program, namely the prompts for the user. 

```assembly
SECTION .data
prompt  db  "Enter your text: ", 0h
prompt2 db  "Shift: ", 0h
prompt3 db  "Encryption (e) or Decryption (d): ", 0h
```

The next step is to allocate enough memory to hold some important variables during execution, which we do in the `.bss` section.

```assembly
SECTION .bss
userin  resd    255,
shift   resb    8,
mode    resb    1,
output  resd    255,
```

How much memory to allocate is a bit of a muddy decision; keeping in mind that the size of the ciphertext (`output`) cannot exceed the size of the plaintext (`userin`), I just opted for 255 dwords, or `1020` bytes. Since the `mode` is determined by a single letter, I only allocate (and read) one byte.  

### Setup

Having set aside enough memory for our variables, we now proceed to read the user's information. To do so we first print out the prompt, which is where the aforementioned `functions.asm` file comes in handy. All I have to do is `mov` the address of the string into `eax`, and call the `sprintLF` subroutine - **s**tring print `LineFeed`. 

```assembly
mov eax, prompt
call    sprintLF
```

Afterwards, we use the `SYS_READ` syscall to read the bytes into our memory space. The system call takes three arguments:  

1. `size_t count`   - Basically meaning "How many bytes shall I read?"
2. `char *buf`      - Basically meaning "Where shall I store the read bytes?"
3. `int fd`         - FD -> File Descriptor -> "Where shall I read the bytes from?" (`0` is `STDIN`)

With that in mind, this is what one such call looks like for the `plaintext`:

```assembly
mov edx, 1020       ; 1020 since we allocated 255 DWORDS 
mov ecx, userin     ; userin is the address of the memory we allocated for the plaintext
mov ebx, 0          ; 0 is STDIN, so we read directly from the command line
mov eax, 3          ; 3 refers to SYS_READ, which is triggered when we run the interrupt
int 80h             ; Interrupt triggering the syscall
```

We cannot just use the user's input without some preprocessing, since it will include at a newline character at the end of the string, which we neither want nor need. To get rid of it, I implemented a subroutine in the `functions` file called `stripToNull`. Quite simply, it calculates the length of the string, jumps to the end of it, and replaces the `\n` character with `0x00`. 

```assembly
stripToNull:
        push    ebx
        mov     ebx, eax
        call    slen
        dec     eax
        mov     [ebx+eax], byte 0h
        pop     ebx
        ret
```

Now that the strings are properly sanitised we proceed to convert the `shift` variable. When a user inputs 5, for instance, that `5` is interpreted as an ASCII character and is therefore stored as `0x35`. Since we will later use this value to quite literally increment the ASCII characters in the plaintext, we need to convert the five to its hexadecimal counterpart of `0x5`, which we do using the `atoi` - ASCII To Integer - subroutine.

Converting an ASCII string into an integer value is not a trivial task. Firstly, we take the address of the string and move it into `ESI` (originally known as the source register). We will then move along the string byte by byte (think of each byte as being a single digit or decimal placeholder). For each digit we will check if it's value is between 48-57 (ASCII values for the digits 0-9).

Once we have performed this check and determined that the byte can be converted to an integer, we will subtract 48 from the value – converting the ascii value to its decimal equivalent. We will then add this value to `EAX` (the general purpose register that will store our result). We will then multiple `EAX` by 10, as each byte represents a decimal placeholder, and continue the loop.

When all bytes have been converted, we need to do one last thing before we return the result. The last digit of any number represents a **single** unit (**not** a multiple of 10) so we have multiplied our result one too many times. We simple divide it by 10 once to correct this and then return. If no integer arguments were pass however, we skip this divide instruction.

```assembly
atoi:
    push    ebx             ; preserve ebx on the stack to be restored after function runs
    push    ecx             ; preserve ecx on the stack to be restored after function runs
    push    edx             ; preserve edx on the stack to be restored after function runs
    push    esi             ; preserve esi on the stack to be restored after function runs
    mov     esi, eax        ; move pointer in eax into esi (our number to convert)
    mov     eax, 0          ; initialise eax with decimal value 0
    mov     ecx, 0          ; initialise ecx with decimal value 0
 
.multiplyLoop:
    xor     ebx, ebx        ; resets both lower and uppper bytes of ebx to be 0
    mov     bl, [esi+ecx]   ; move a single byte into ebx register's lower half
    cmp     bl, 48          ; compare ebx register's lower half value against ascii value 48 (char value 0)
    jl      .finished       ; jump if less than to label finished
    cmp     bl, 57          ; compare ebx register's lower half value against ascii value 57 (char value 9)
    jg      .finished       ; jump if greater than to label finished
 
    sub     bl, 48          ; convert ebx register's lower half to decimal representation of ascii value
    add     eax, ebx        ; add ebx to our interger value in eax
    mov     ebx, 10         ; move decimal value 10 into ebx
    mul     ebx             ; multiply eax by ebx to get place value
    inc     ecx             ; increment ecx (our counter register)
    jmp     .multiplyLoop   ; continue multiply loop
 
.finished:
    cmp     ecx, 0          ; compare ecx register's value against decimal 0 (our counter register)
    je      .restore        ; jump if equal to 0 (no integer arguments were passed to atoi)
    mov     ebx, 10         ; move decimal value 10 into ebx
    div     ebx             ; divide eax by value in ebx (in this case 10)
 
.restore:
    pop     esi             ; restore esi from the value we pushed onto the stack at the start
    pop     edx             ; restore edx from the value we pushed onto the stack at the start
    pop     ecx             ; restore ecx from the value we pushed onto the stack at the start
    pop     ebx             ; restore ebx from the value we pushed onto the stack at the start
```

### Shifting Logic


Now that we have properly processed all of the user input, we proceed to the crux of the program, which is the actual encryption/shifting logic.

The way I designed the program is as follows:

1. Iterate through plaintext (`userin`)
2. Check whether the current character is a letter
3. Increment that letter by whatever the shift is
4. Append the shifted letter to `output`

The above logic takes place in the `_mainLoop` label. You will also notice that I iterate through the plaintext in **reverse** order, as shown in the segment before the aforementioned label:

```assembly
_preLoop:
    mov eax, userin
    call    slen        ; get length of plaintext
    mov ecx, eax        ; ecx is our iterator
```

I then use `dec` to decrement the iterator `ECX` after each loop. The reason behind this is endianness. Our program uses **little** endian, meaning hex values such as addresses and strings (such as the string we read by the user) are stored in reverse order (relative to us puny humans). 

To illustrate, if I were to save the string `Hello` somewhere in memory, the actual arrangement of the bytes would look as follows:

```assembly
; 0x48 - H
; 0x65 - e
; 0x6c - l
; 0x6c - l
; 0x6f - o
0x6f6c6c6548
```

You'll notice that the string therefore reads right-to-left, which I had to account for during debugging, where at some stages I was printing out each character to check whether it had shifted properly. The reverse iteration has therefore remained. 

Small tangent aside, we now reach the final steps of the program. During each iteration, we check whether the current character falls within the hex values `0x41`-`0x5A` (A-Z) or `0x61`-`0x7A` (a-z). If it does not fall into that range, we simply skip over it as we do not care to shift them. As for the characters that **do** fall into that range, we need to perform some modulus calculations on them before we actually perform the shift.

### Modulus

The most difficult part of an admittedly simple cipher is the part where `Z` wraps around to `A` again. To figure this out we make use of modulus arithmetic. Since there are 26 letters in the english alphabet, we can visualise the problem by assigning each letter a position from `1` to `26`, adding the shift to that position, and then taking that number modulus `26` to get the final position (value) of the letter. 

To illustrate:

```
Plaintext: Hello
Shift: 15

Letter - Position 
H - 8
e - 5
l - 12
l - 12
o - 15

( Position + Shift ) modulus 26 -> Letter
( 8 + 15 ) % 26 = 23 -> W
( 5 + 15 ) % 26 = 20 -> t
( 12 + 15 ) % 26 = 1 -> a
( 12 + 15 ) % 26 = 1 -> a
( 15 + 15 ) % 26 = 4 -> d

```

As one can see, as soon as a value surpasses `26` (or `Z`), it wraps back around to the position of `1` (`A`), just like the `l`'s did in the above example.  

While assembly does not have a modulus operand, the `div` instruction already implements all the functionality we need for this task. The `div` instruction always divides `EAX` by the value passed after it. Crucially, the **quotien** value is then stored in `EAX`, while the **remainder** of the operation is stored in `EDX`. Sound familiar? The remainder is exactly what the modulus operator yields us after a given calculation. 

With that in mind, we have the final part of the program's logic, namely the shifting of the letters:
```assembly
.shiftLarge:
        xor     edx, edx

        sub     eax, 0x41
        add     eax, [shift]
        mov     edi, 0x1A
        div     edi
        mov     eax, edx
        add     eax, 0x41
```

The first thing I do is subtract the letter stored in `EAX`, such that it falls into its position between 1-26, as explained above. The caveat is that I therefore had to implement two labels, one for shifting smaller case letters (by first subtracting `0x61`), and one for shifting the capital letters (by subtracting `0x41`). After the subtraction, we add the shift to the current hex value of the letter, and then divide it by `0x1A` (26). The remainder inside `EDX` then corresponds to the final position inside the alphabet, so we then add the originally subtracted `0x41` back to get the final ASCII representation of the letter. 

### Decryption

Fortunately, decryption in the Caesar cipher is based on the exact same logic as encryption. We only need to perform some arithmetic magic on the shift to inverse it, which is done in the `_processMode` label.

All we have to do to inverse the cipher when a given shift is provided, is take the value of the shift modulus 26, and subtract the resulting value from 26 to get the inverse shift:

```
Shift: 5
5 % 26 = 5
26 - 5 = 21
```

So, if we use our `Hello` example one last time, it would look as follows:

```
Shift: 5
H -> M
e -> j
l -> q
l -> q
o -> t

Shift 21:
M -> H
j -> e
q -> l
q -> l
t -> o
```

Clone the repo and verify it yourself :P 

And that is all she wrote.

## Closing remarks

I am sure there are still ways to optimise this, as well as obviously add some validation here and there, but this is more of a PoC rather than an ironclad program. This is the first cipher out of what I hope to be a series of increasingly complicated ciphers written in pure x86 assembly, so I hope you enjoyed it and maybe learned a thing or two.

Peace! 
