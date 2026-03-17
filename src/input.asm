_peek:
	mov ecx, [input.pointer]
	cmp ecx, [input.length]
	jae .readin
	cmp dword [input.length], 0
	je .readin
	jmp short .no_readin
	.readin:
		xor eax, eax
		xor edi, edi
		mov rsi, input.content
		mov edx, PAGE_SIZE
		syscall
		or al, al
		jnz .finish_readin
			ret
		.finish_readin:
		mov dword [input.length], eax
		xor ecx, ecx
	.no_readin:

	mov al, [rcx + input.content]
	cmp al, 0x0A
	jne .return
		inc [line]
	.return:
	ret
_consume:
	inc [input.pointer]
	ret
_getchar:
	call _peek
	call _consume
	ret

_skip_whitespace:
	jmp short .loop
.continue:
	call _consume
.loop:
	call _peek
	cmp al, 0x09
	je .continue
	cmp al, 0x0A
	je .continue
	cmp al, 0x0D
	je .continue
	cmp al, 0x20
	je .continue
	ret

_get_identifier:
	push 0x00
.ident_loop:
	call _peek
	cmp al, 0x41
	jb .found_identifier
	cmp al, 0x5B
	jb .next_char
	cmp al, 0x61
	jb .found_identifier
	cmp al, 0x7A
	ja .found_identifier
.next_char:
	mov rdi, identifier
	add rdi, [rsp]
	cmp dword [rsp], PAGE_SIZE
	jae .error
	stosb
	inc dword [rsp]
	call _consume
	call _peek
	jmp .ident_loop
.found_identifier:
	pop rax
	ret
.error:
	int3
