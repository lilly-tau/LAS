
_input_init: ; (void)
	; initialize the input stack
	mov dword [input_stack.top], 0x00
	mov dword [input_stack.capacity], PAGE_SIZE / sizeof.INPUT_OBJ
	mov edi, PAGE_SIZE
	call _sys_malloc
	mov qword [input_stack.ptr], rax
	mov rsi, rax
	ret
_input_append: ; (void *buffer, size_t capacity)
	push rdi
	push rsi
	mov eax, [input_stack.top]
	inc dword [input_stack.top]
	cmp eax, [input_stack.capacity]
	jb .no_realloc
		mov rdi, [input_stack.ptr]
		inc [input_stack.capacity]
		mov esi, [input_stack.capacity]
		mov eax, sizeof.INPUT_OBJ
		mul esi
		xchg eax, esi
		call _sys_realloc
		mov [input_stack.ptr], rax
	.no_realloc:
	pop rsi
	pop rdi
	mov eax, [input_stack.top]
	dec eax
	mov ecx, sizeof.INPUT_OBJ
	mul ecx
	mov rbx, [input_stack.ptr]
	add rbx, rax
	mov dword [rbx], 0x00
	mov dword [rbx + 0x04], esi
	mov qword [rbx + 0x08], rdi
	ret

_peek: ; (void) -> char
	; if top == 0 then input = stdin
.next_buffer:
	mov eax, [input_stack.top]
	or eax, eax
	jz .stdin
	dec eax

	or eax, eax
	jz .nodbg
.nodbg:
	mov ebx, sizeof.INPUT_OBJ
	mul ebx

	mov rsi, [input_stack.ptr]
	add rsi, rax
	mov ecx, [rsi]	; ecx = length
	mov eax, [rsi + 0x04]
	cmp ecx, eax
	jb .no_pop
		dec [input_stack.top]
		jmp short .next_buffer
	.no_pop:
	mov rax, [rsi + 0x08]	; rsi = buffer
	add rax, rcx
	mov al, [rax]
	ret
.stdin:
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
	push rax
	mov eax, [input_stack.top]
	or eax, eax
	jz .stdin
	dec eax

	mov ebx, sizeof.INPUT_OBJ
	mul ebx
	mov rsi, [input_stack.ptr]
	add rsi, rax
	inc dword [rsi]
	pop rax
	ret
.stdin:
	inc [input.pointer]
	pop rax
	ret
_getchar:
	call _peek
	push rax
	call _consume
	pop rax
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
