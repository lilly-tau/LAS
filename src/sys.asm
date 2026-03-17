
_sys_malloc: ; (size_t) -> void*
	lea rsi, [rdi + 8]
	push rsi
	xor edi, edi
	mov edx, PROT_READ or PROT_WRITE
	mov r10, MAP_ANONYMOUS or MAP_PRIVATE
	xor r8d, r8d
	dec r8
	xor r9d, r9d
	xor eax, eax
	mov al, 0x09
	syscall
	pop [rax]
	add rax, 0x08
	ret

_sys_realloc: ; (void*, size_t) -> void*
	mov rdx, rsi
	add rdx, 0x08
	push rdx
	sub rdi, 0x08
	mov rsi, [rdi]
	mov r10, MREMAP_MAYMOVE
	xor r8d, r8d
	xor eax, eax
	mov al, 0x19
	syscall
	pop [rax]
	add rax, 0x08
	ret

_sys_free: ; (void*) -> void
	sub rdi, 0x08
	mov rsi, [rdi]
	xor eax, eax
	mov al, 0x0B
	syscall
	ret
