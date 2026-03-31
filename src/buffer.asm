_create_buffer: ; (buffer *ret, size_t capacity)
	push rdi
	push rdi
	mov edi, esi
	call _sys_malloc
	pop rdi			; Load pointer in rax to ret->ptr
	stosq
	pop rax			; Load length of allocation into ret->capacity
	stosd
	xor eax, eax		; Load zero into ret->length
	stosd
	ret
_push_buffer: ; (buffer *ret, void *alloc, size_t length)
	push rbp
	mov rbp, rsp
	push rdi	; rbp - 0x08
	push 0x00
	cmp edx, 0x08
	jb .length_set
		mov edx, 0x08
	.length_set:
	mov rdi, rsp
	mov ecx, edx
	rep movsb
	mov rdi, [rbp - 0x08]
	lea rsi, [rbp - 0x10]
	call _append_buffer
	pop rax
	mov rsp, rbp
	pop rbp
	ret

_append_buffer: ; (buffer *ret, void *alloc, size_t length)
	enter
	push r12
	push r13
	push r14
	push r15
	mov r12, rdi
	mov r13, rsi
	mov r14, rdx

	mov r15d, [r12 + BUFFER.length]
	add r15d, r14d
	; first check if we need to reallocate
	cmp r15d, [r12 + BUFFER.capacity]
	jb .no_realloc
	.realloc:
		add [r12 + BUFFER.capacity], PAGE_SIZE
		mov rdi, [r12 + BUFFER.ptr]
		mov esi, [r12 + BUFFER.capacity]
		call _sys_realloc
		mov [r12 + BUFFER.ptr], rax
		cmp r15d, [r12 + BUFFER.capacity]
		jnb .realloc
	.no_realloc:
	mov rdi, [r12 + BUFFER.ptr]
	mov esi, [r12 + BUFFER.length]
	add rdi, rsi
	mov rsi, r13
	mov ecx, r14d
	rep movsb
	mov [r12 + BUFFER.length], r15d

	pop r15
	pop r14
	pop r13
	pop r12
	leave
	ret
_pop_buffer: ; (buffer *, int) -> int Returns top N < 9 bytes in rax
	enter
	push rdi
	push rsi
	push 0x00
	cmp esi, 0x08
	jb .length_set_1
		mov esi, 0x08
	.length_set_1:
	cmp esi, [rdi + BUFFER.length]
	jb .length_set
		mov esi, [rdi + BUFFER.length]
	.length_set:

	or esi, esi
	jnz .continue
		pop rax
		pop rsi
		ret
	.continue:

	mov ecx, esi
	mov edx, [rdi + BUFFER.length]
	mov rsi, [rdi + BUFFER.ptr]
	add rsi, rdx
	sub rsi, rcx

	mov rdi, rsp
	rep movsb
	pop rax
	pop rsi
	pop rdi

	sub dword [rdi + BUFFER.length], edx
	leave
	ret
_destroy_buffer: ; (buffer *ret)
	mov rdi, [rdi + BUFFER.ptr]
	call _sys_free
	ret
