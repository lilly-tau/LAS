
_io_init: ; (void*)
	; initialize the input stack
	mov dword [rdi + IO_STACK.top], 0x00
	mov dword [rdi + IO_STACK.capacity], PAGE_SIZE / sizeof.IO_OBJ
	push rdi
	mov edi, PAGE_SIZE
	call _sys_malloc
	pop rdi
	mov qword [rdi + IO_STACK.ptr], rax
	mov rsi, rax
	ret
_io_append: ; (void *buffer, size_t capacity, io_stack*)
	push r12
	push rdi
	push rsi

	mov r12, rdx
	mov eax, [r12 + IO_STACK.top]
	inc dword [r12 + IO_STACK.top]
	cmp eax, [r12 + IO_STACK.capacity]
	jb .no_realloc
		mov rdi, [r12 + IO_STACK.ptr]
		inc [r12 + IO_STACK.capacity]
		mov esi, [r12 + IO_STACK.capacity]
		mov eax, sizeof.IO_OBJ
		mul esi
		xchg eax, esi
		call _sys_realloc
		mov [r12 + IO_STACK.ptr], rax
	.no_realloc:
	pop rsi
	pop rdi
	mov eax, [r12 + IO_STACK.top]
	dec eax
	mov ecx, sizeof.IO_OBJ
	mul ecx
	mov rbx, [r12 + IO_STACK.ptr]
	add rbx, rax
	mov dword [rbx + IO_OBJ.index], 0x00
	mov dword [rbx + IO_OBJ.capacity], esi
	mov qword [rbx + IO_OBJ.buffer], rdi
	pop r12
	ret

_outc: ; (char al) -> void
	mov edx, eax
	mov edi, [output_stack.top]
	mov eax, sizeof.IO_OBJ
	mul edi
	mov rsi, [output_stack.ptr]
	add rsi, rax
	mov ecx, [rsi + IO_OBJ.index]
	mov eax, [rsi + IO_OBJ.capacity]
	cmp ecx, eax
	jb .no_realloc
		push rcx
		push rdx
		push rsi
		add dword [rsi + IO_OBJ.capacity], PAGE_SIZE
		mov rdi, [rsi + IO_OBJ.buffer]
		mov esi, [rsi + IO_OBJ.capacity]
		call _sys_realloc
		pop rsi
		mov [rsi + 0x08], rax
		pop rax
		pop rcx
	.no_realloc:
	mov rdi, [rsi + IO_OBJ.buffer]
	add rdi, rcx
	stosb
	inc dword [rsi + IO_OBJ.index]
	ret
_outs: ; (void *str, size_t)
	push r12
	push r13
	mov r12, rdi
	mov r13, rsi

	mov edx, eax
	mov edi, [output_stack.top]
	mov eax, sizeof.IO_OBJ
	mul edi
	mov rsi, [output_stack.ptr]
	add rsi, rax
	add dword [rsi], r13d
	mov ecx, [rsi]
	mov eax, [rsi + 0x04]
	cmp ecx, eax
	jb .no_realloc
	.realloc:
		push rsi
		add dword [rsi + 0x04], PAGE_SIZE
		mov rdi, [rsi + 0x08]
		mov esi, [rsi + 0x04]
		call _sys_realloc
		pop rsi
		mov [rsi + 0x08], rax
		mov ecx, [rsi]
		mov eax, [rsi + 0x04]
		cmp ecx, eax
		jnb .realloc
		pop rsi
	.no_realloc:
	mov ecx, [rsi]
	mov rdi, [rsi + 0x08]
	add rdi, rcx
	mov rsi, r12
	mov ecx, r13d
	sub rdi, rcx
	rep movsb
	pop r13
	pop r12
	ret

_peek: ; (void) -> char
	; if top == 0 then input = stdin
.next_buffer:
	mov eax, [input_stack.top]
	or eax, eax
	jz .stdin
	dec eax

	mov ebx, sizeof.IO_OBJ
	mul ebx

	mov rsi, [input_stack.ptr]
	add rsi, rax
	mov ecx, [rsi + IO_OBJ.index]	; ecx = length
	mov eax, [rsi + IO_OBJ.capacity]
	cmp ecx, eax
	jb .no_pop
		mov rdi, [rsi + IO_OBJ.buffer]
		call _sys_free
		dec [input_stack.top]
		jmp short .next_buffer
	.no_pop:
	mov rax, [rsi + IO_OBJ.buffer]	; rsi = buffer
	add rax, rcx
	mov al, [rax]
	ret
.stdin:
	mov ecx, [input.length]
	cmp ecx, [input.capacity]
	jb .no_readin
		call _readin
		or al, al
		jnz .continue_readin
		ret
	.continue_readin:
		xor ecx, ecx
	.no_readin:

	mov al, [rcx + input.content]
	cmp al, 0x0A
	jne .return
	inc [line]
.return:
	ret

_readin:
	xor eax, eax
	xor edi, edi
	mov rsi, input.content
	mov edx, PAGE_SIZE
	syscall
	or al, al
	jnz .finish_readin
		ret
	.finish_readin:
	mov dword [input.capacity], eax
	ret

_consume:
	push rax
	mov eax, [input_stack.top]
	or eax, eax
	jz .stdin
	dec eax

	mov ebx, sizeof.IO_OBJ
	mul ebx
	mov rsi, [input_stack.ptr]
	add rsi, rax
	inc dword [rsi + IO_OBJ.index]
	pop rax
	ret
.stdin:
	inc [input.length]
	pop rax
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
	test [report_identifier], 0x01
	jz .no_reported
	mov [report_identifier], 0x00
	mov eax, [identifier.length]
	ret
.no_reported:
	push 0x01
	call _peek
	xor ecx, ecx
	mov cl, SYMBOL_COUNT
	mov rdi, symbols
	repne scasb
	jne .identifier
	call _consume
	mov rdi, identifier
	stosb
	pop rax
	ret
.identifier:
	dec qword [rsp]
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
