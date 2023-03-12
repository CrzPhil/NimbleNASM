%include	"functions.asm"

;
;	Caesar Cipher program in x86 Assembly using NASM (intel syntax)
;	

SECTION	.data
prompt	db	"Enter your text: ", 0h
prompt2	db	"Shift: ", 0h
prompt3	db	"Encryption (e) or Decryption (d): ", 0h


SECTION	.bss
userin	resd	255,
shift	resb	8,
mode	resb	1,
output	resd	255,

SECTION	.text
global	_start

_start:
	xor	eax, eax
	xor	ebx, ebx
	xor	ecx, ecx
	xor	edx, edx

_getMode:
	mov	eax, prompt
	call	sprintLF

	mov	edx, 1020 
	mov	ecx, userin
	mov	ebx, 0
	mov	eax, 3
	int	80h

	mov	eax, prompt2
	call	sprintLF

	mov	edx, 8
	mov	ecx, shift
	mov	ebx, 0
	mov	eax, 3
	int	80h

	mov	eax, prompt3
	call	sprintLF

	mov	edx, 1
	mov	ecx, mode
	mov	ebx, 0
	mov	eax, 3
	int	80h

_strip:
	mov	eax, userin
	call	stripToNull
	mov	eax, shift
	call	stripToNull

_convertShift:
	xor	eax, eax
	mov	eax, shift
	call	atoi
	mov	[shift], eax

_processMode:
	mov	eax, [mode]
	cmp	eax, 0x65		; -> 'e' -> Encryption
	je	_preLoop

	cmp	eax, 0x64		; -> 'd' -> Decryption
	jne	_end

	xor	edx, edx
	mov	ebx, 0x1A
	mov	eax, [shift]
	div	ebx
	mov	eax, 0x1A
	sub	eax, edx
	mov	[shift], eax

_preLoop:
	mov	eax, userin
	call	slen
	mov	ecx, eax

_mainLoop:
	dec	ecx

	movzx	eax, byte [userin+ecx]
	
	cmp	eax, 0x41
	jl	.append

	cmp	eax, 0x7A
	jg	.append

	cmp	eax, 0x5A
	jg	.checkSmall

	jmp	.shiftLarge

.checkSmall:
	cmp	eax, 0x61
	jl	.append

	xor	edx, edx

	sub	eax, 0x61
	add	eax, [shift]
	mov	edi, 0x1A
	div	edi
	mov	eax, edx
	add	eax, 0x61

	jmp	.append

.shiftLarge:
	xor	edx, edx

	sub	eax, 0x41
	add	eax, [shift]
	mov	edi, 0x1A
	div	edi
	mov	eax, edx
	add	eax, 0x41

.append:
	mov	[output+ecx], al

	cmp	ecx, 0h
	je	.endLoop

	jmp	_mainLoop

.endLoop:
	mov	eax, output
	call	sprintLF
	jmp	_end

_end:
	call	quit
