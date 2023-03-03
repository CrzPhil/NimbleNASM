atoi:
	push	ebx
	push	ecx
	push	edx
	push	esi
	mov	esi, eax
	mov	eax, 0
	mov	ecx, 0

.multiplyLoop:
	xor	ebx, ebx
	mov	bl, [esi+ecx]
	cmp	bl, 48
	jl	.finished
	cmp	bl, 57
	jg	.finished

	sub	bl, 48
	add	eax, ebx
	mov	ebx, 10
	mul	ebx
	inc	ecx
	jmp	.multiplyLoop

.finished:
	cmp	ecx, 0
	je	.restore
	mov	ebx, 10
	div	ebx

.restore:
	pop	esi
	pop	edx
	pop	ecx
	pop	ebx
	ret

slen:
	push	ebx
	mov	ebx, eax

.nextchar:
	cmp	byte [eax], 0
	jz	.finished
	inc	eax
	jmp	.nextchar

.finished:
	sub	eax, ebx
	pop	ebx
	ret

sprint:
	push	edx
	push	ecx
	push	ebx
	push	eax
	call	slen

	mov	edx, eax
	pop	eax

	mov	ecx, eax
	mov	ebx, 1
	mov	eax, 4
	int	80h

	pop	ebx
	pop	ecx
	pop	edx
	ret


sprintLF:
	call	sprint

	push	eax
	mov	eax, 0Ah
	push	eax
	mov	eax, esp
	call	sprint
	pop	eax
	pop	eax
	ret


iprint:
	push	eax
	push	ecx
	push	edx
	push	esi
	mov	ecx, 0

.divideLoop:
	inc	ecx
	mov	edx, 0
	mov	esi, 10
	idiv	esi
	add	edx, 48
	push	edx
	cmp	eax, 0
	jnz	.divideLoop

.printLoop:
	dec	ecx
	mov	eax, esp
	call sprint
	pop	eax
	cmp	ecx, 0
	jnz	.printLoop

	pop	esi
	pop	edx
	pop	ecx
	pop	eax
	ret

iprintLF:
	call	iprint

	push	eax
	mov	eax, 0Ah
	push	eax
	mov	eax, esp
	call	sprint
	pop	eax
	pop	eax
	ret


; print a single char
cprint:
	push edx
	push ecx
	push ebx
	push eax

	mov	edx, 1	; length -> 1
	mov	ecx, eax
	mov	ebx, 1
	mov	eax, 4
	int	80h
	pop eax
	pop ebx
	pop ecx
	pop edx
	ret


; getFDwrite(filename) -> (write only) file descriptor in eax
getFDwrite:
	push	ecx
	push	ebx
	mov	ecx, 1
	mov	ebx, eax
	mov	eax, 5
	int	80h

	pop	ebx
	pop	ecx
	ret

; getFDread(filename) -> (read only) file descriptor in eax
getFDread:
	push	ecx
	push	ebx
	
	mov	ecx, 0
	mov	ebx, eax
	mov eax, 5
	int	80h

	pop	ebx
	pop	ecx
	ret

; getFDboth(filename) -> (r/w) file descriptor in eax
getFDboth:
	push	ecx
	push	ebx

	mov	ecx, 2
	mov	ebx, eax
	mov	eax, 5
	int	80h

	pop	ebx
	pop	ecx
	ret

; readFile(size, contentsmemory, filename) -> prints to console
readFile:
	push	edx
	push	ecx
	push	ebx
	push	eax

	add	esp, 20		; skip the saved registers
	mov	eax, [esp]		; filename -> eax
	sub esp, 20		; put esp back on top of stack

	call	getFDread

	add esp, 28		; point esp back to parameters	
	mov edx, [esp]		; Size to read (size of allocated memory will do)
	sub esp, 4
	mov ecx, [esp]		; Address of allocated memory (in .bss (?))
	mov ebx, eax		; File descriptor
	mov	eax, 3	; opcode
	int	80h

	sub esp, 24

	mov	eax, ebx
	call	closeFD

	pop	eax
	pop	ebx
	pop	ecx
	pop	edx
	ret


; closeFD(fileDescriptor) -> Void
closeFD:
	push	ebx

	mov	ebx, eax
	mov	eax, 6
	int	80h

	pop	ebx
	ret


; Remove \n or 0Ah from string
; strip(*source, *dest)
strip:

	push	esi
	push	edi
	push	eax

	add	esp, 20
	mov	esi, [esp]		; source addr
	sub	esp, 4
	mov	edi, [esp]		; dest addr
	sub esp, 16			; reset sp

.L1:

	cmp	byte [esi], 0Ah
	je	.finit
	mov	al, [esi]
	mov	[edi], al
	inc	esi
	inc	edi
	jmp	.L1

.finit:

	pop	eax
	pop	edi
	pop	esi
	ret

; Replace last \n with 0h
; Takes *text in eax as input
stripToNull:
	push	ebx
	mov	ebx, eax
	call	slen
	dec	eax
	mov	[ebx+eax], byte 0h
	pop	ebx
	ret

quit:
	mov	ebx, 0
	mov	eax, 1
	int	80h
	ret

