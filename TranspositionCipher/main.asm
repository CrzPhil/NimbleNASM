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
rankMap resb  255,
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
  
  ; Pushing and popping because I can't remember/don't know if edi has a low register
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

_end:
	mov	eax, userout
	call	sprintLF
	call	quit


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
