%include	"functions.asm"

SECTION	.data
prompt	db	"Text:	", 0h
prompt2	db	"Secret:	", 0h
prompt3	db	"Encrypt (e) or Decrypt (d): ", 0h

SECTION	.bss
userin	resd	255,
textlen	resb	8,
secret	resb	255,
secretlen	resb	8,
mode	resb	4,
blockspace	resq	255,
userout	resd	255,

SECTION	.text
global	_start

_start:
	xor	eax, eax
	xor	ebx, ebx
	xor	ecx, ecx
	xor	edx, edx

_prompt:
	mov	eax, prompt
	call	sprint

	mov	edx, 255
	mov	ecx, userin
	mov	ebx, 0
	mov	eax, 3
	int	80h

	mov	eax, prompt2
	call	sprint

	mov	edx, 255
	mov	ecx, secret
	mov	ebx, 0
	mov	eax, 3
	int	80h

	mov	eax, prompt3
	call	sprint

	mov	edx, 4
	mov	ecx, mode
	mov	ebx, 0
	mov	eax, 3
	int	80h

_strip:
	mov	eax, userin
	call	stripToNull
	mov	eax, secret
	call	stripToNull
	mov	eax, mode
	call	stripToNull

	mov	eax, userin
	call	stripSpaces

_slens:
	mov	eax, secret
	call	slen
	mov	[secretlen], eax
	mov	ebx, [secretlen]
	mov	eax, userin
	call	slen
	mov	[textlen], eax
	push	eax
	xor	ecx, ecx

_getPadding:
	xor	edx, edx
	div	ebx
	cmp	edx, 0h
	je	.applyPadding	

	inc	ecx
	pop	eax
	inc	eax
	push	eax

	jmp	_getPadding

.applyPadding:
	cmp	ecx, 0h
	je	_split

	mov	eax, [textlen]

	mov	ebx, userin
	add	ebx, eax

.L1:
	cmp	ecx, 0h
	je	_split
	
	mov	dword [ebx], 0x58
	inc	ebx
	dec	ecx

	jmp	.L1

_split:
	mov	eax, userin
	call	slen
	mov	[textlen], eax

	xor	ecx, ecx		; Block counter (aka letters in secret)
	xor	esi, esi		; iterator for userin
	mov	ebx, userin
	xor	edi, edi		; iterator for blockspace

.L1:
	cmp	ecx, [secretlen]
	je	_rearrange
	xor	esi, esi

.L2:
	xor	edx, edx
	push	esi
	sub	esi, ecx
	cmp	esi, 0xffffffff		; happens when esi-ecx = -1 
	je	.neg

	mov	eax, esi
	mov	esi, [secretlen]
	div	esi
	pop	esi

	cmp	edx, 0h
	jne	.nextLetter

	movzx	eax, byte [userin+esi]
	mov	[blockspace+edi], eax
	inc	edi

.nextLetter:
	inc	esi

	cmp	esi, [textlen]
	jne	.L2

	inc	ecx
	jmp	.L1

.neg:
	pop	esi
	jmp	.nextLetter

_rearrange:

_end:
	call	quit
