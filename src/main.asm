format elf64 executable 3
entry _start
include 'const.inc'
include 'data.inc'
include 'mac.inc'

segment readable executable
include 'input.asm'
include 'sys.asm'

_start:
; test _getchar
;.loop:
;	call _getchar
;	or al, al
;	jz .eloop
;	mov byte [writebuf], al
;	mov eax, 0x01
;	mov edi, eax
;	mov rsi, writebuf
;	mov edx, eax
;	syscall
;	jmp .loop
;.eloop:
	mov [line], 0x00
	call main_loop
	cmp qword [udef_macros], 0x00
	jz .no_free_udef
		mov rdi, [udef_macros]
		call _sys_free
	.no_free_udef:
	xor eax, eax
	xor edi, edi
	mov al, 0x3C
	syscall

main_loop:
	call _skip_whitespace
	call _getchar
	or al, al
	je .end_loop
	cmp al, '['
	je _open_bracket
	cmp al, ';'
	je _comment
	cmp al, '\'
	je _macro
.error:
	int3
.end_loop:
	ret

_parse_byte_list:	; (void) -> void*
	mov rdi, PAGE_SIZE
	call _sys_malloc
	push r13 ; r13 = capacity
	push r12 ; r12 = length
	push rax ; [rbp + 0x08] = ret
	enter
	xor r12, r12
	mov r13, PAGE_SIZE
.continue:

	push 0x0 ; chars
	push 0x0 ; number
	call _skip_whitespace
.numloop:
	call _peek
	; if al is a whitespace then the current number is done
	; if al is ] the bracket is done
	cmp al, ']'
	je .numdone
	cmp al, 0x09
	je .numdone
	cmp al, 0x0A
	je .numdone
	cmp al, 0x0D
	je .numdone
	cmp al, 0x20
	je .numdone
	call _consume
	pop rbx
	inc qword [rsp] ; increment number of digits
	shl ebx, 0x04
	sub al, 0x30
	jb .error
	cmp al, 0x0A
	jb .done
	sub al, 0x11
	jb .error
	and al, (not 0x20)
	cmp al, 0x1A
	ja .error
	add al, 0x0A
.done:
	and eax, 0xF
	or ebx, eax
	push rbx
	jmp .numloop
.numdone:

	pop [writebuf]
	pop rcx ; get number of digits from the stack
	shr ecx, 1 ; convert from digits to bytes
	push rcx
	or ecx, ecx
	jz .no_digits

	; ensure we can write the staged bytes into ret
	mov r11, rcx
	add r11, r12
	cmp r11, r13
	jb .no_realloc
		add r13, PAGE_SIZE
		mov rdi, [rbp + 0x08]
		mov rsi, r13
		call _sys_realloc
		mov [rbp + 0x08], rax
	.no_realloc:

	mov rsi, writebuf
	mov rdi, [rbp + 0x08]
	lea rdi, [rdi + r12 + 0x04]
	rep movsb
	pop rcx ; length
	add r12d, ecx
.no_digits:
	call _peek
	cmp al, ']'
	jne .continue
	call _consume
	leave
	pop rax
	mov dword [rax], r12d
	pop r12
	pop r13
	ret
.error:
	int3

_open_bracket:
	call _parse_byte_list
	push rax
	mov rsi, rax
	lodsd
	xchg eax, edx
	xor eax, eax
	inc eax
	mov edi, eax
	syscall
	pop rdi
	call _sys_free
	jmp main_loop

_comment:
	call _getchar
	or al, al
	je main_loop
	cmp al, 0x0A
	je main_loop
	jmp _comment

_macro:
	; If the first character is a symbol, then that is the identifier,
	; otherwise the identifier is each alphabetic character which follows
	push 0x01
	call _peek
	xor ecx, ecx
	mov cl, SYMBOL_COUNT
	mov rdi, symbols
	repne scasb
	je .symbol_identifier	; if AL is a symbol, then we have the whole
				; identifier
	call _get_identifier
	mov [rsp], rax ; length is on the stack
	jmp .found_identifier
.symbol_identifier:
	call _consume
	mov rdi, identifier
	stosb
.found_identifier:
	; search through macros
	mov rbx, las_macros.null
.macro_loop:
	mov ecx, [rsp]
	mov rsi, [rbx]
	lodsd
	cmp eax, ecx
	jne .next
	mov rdi, identifier
	repe cmpsb
	je .found_macro
.next:
	mov rbx, [rbx + LAS_MACRO.next]
	or rbx, rbx
	je .error
	jmp .macro_loop
.found_macro:
	pop rcx
	mov rax, [rbx + LAS_MACRO.flags]
	test [rbx + LAS_MACRO.flags], LAS_EMBEDDED
	jnz .embed
	test [rbx + LAS_MACRO.flags], LAS_LIST
	jnz .list
.error:
	int3
.embed:
	call [rbx + LAS_MACRO.ptr]
	jmp main_loop
.list:
	mov rsi, [rbx + LAS_MACRO.ptr]
	lodsd
	xchg eax, edx
	xor eax, eax
	inc eax
	mov edi, eax
	syscall
	jmp main_loop

_add_macro: ; (void) -> LAS_MACRO*
	cmp dword [udef_macros.capacity], 0
	jne .no_mmap
		mov edi, PAGE_SIZE
		call _sys_malloc
		mov qword [udef_macros], rax
		mov dword [udef_macros.capacity], PAGE_SIZE
		mov dword [udef_macros.length], 0x00
	.no_mmap:
	add dword [udef_macros.length], sizeof.LAS_MACRO
	mov ecx, dword [udef_macros.length]
	mov edx, dword [udef_macros.capacity]
	cmp ecx, edx
	jna .no_mremap
		add dword [udef_macros.capacity], PAGE_SIZE
		mov rdi, [udef_macros]
		mov esi, [udef_macros.capacity]
		call _sys_realloc
		mov qword [udef_macros], rax
	.no_mremap:
	; udef_macros + udef_macros.length - sizeof.LAS_MACRO = macro
	mov ecx, dword [udef_macros.length]
	mov rsi, [udef_macros]
	lea rax, [rsi + rcx - sizeof.LAS_MACRO]
	ret

MAC_null:
	mov byte [writebuf], 0x00
	xor eax, eax
	inc eax
	mov edi, eax
	mov edx, eax
	mov rsi, writebuf
	syscall
	ret

MAC_define:
	; \\<identifier> [ <list> ]
	call _add_macro
	mov rdi, [latest]
	mov [rdi], rax
	mov [latest], rax
	add qword [latest], LAS_MACRO.next
	call _get_identifier
	push rax ; name length
	mov rdi, rax
	add rdi, 0x04
	call _sys_malloc
	mov rcx, [rsp]
	push rax ; name buffer
	mov rsi, identifier
	lea rdi, [rax + 4]
	rep movsb
	pop rdi ; name buffer
	pop rax ; name length
	mov dword [rdi], eax
	mov rsi, [latest]
	sub rsi, LAS_MACRO.next
	mov [rsi + LAS_MACRO.name], rdi
	mov [rsi + LAS_MACRO.flags], 0x00 ; not embedded
	mov [rsi + LAS_MACRO.next], 0x00 ; fix the list

; debug macros
;	mov rbx, las_macros.null
;.dbg_loop:
;	mov rsi, [rbx + LAS_MACRO.name]
;	lodsd
;	xchg eax, edx
;	mov edi, 0x02
;	mov eax, 0x01
;	push rbx
;	syscall
;	pop rbx
;	mov rbx, [rbx + LAS_MACRO.next]
;	or rbx, rbx
;	jnz .dbg_loop

	call _skip_whitespace
	call _getchar

	cmp al, '['
	je .byte_list
.error:
	int3
.byte_list:
	call _parse_byte_list
	mov rsi, [latest]
	sub rsi, LAS_MACRO.next
	mov [rsi + LAS_MACRO.ptr], rax
	mov [rsi + LAS_MACRO.flags], LAS_LIST
	jmp main_loop
