format elf64 executable 3
entry _start
include 'const.inc'
include 'data.inc'
include 'struc.inc'
include 'mac.inc'

segment readable executable
include 'input.asm'
include 'sys.asm'

_start:
	call _readin
	mov rdi, input_stack
	call _io_init
	mov rdi, output_stack
	call _io_init

	mov rdi, PAGE_SIZE
	call _sys_malloc
	mov rdi, [output_stack.ptr]
	mov [rdi + IO_OBJ.buffer], rax
	mov [rdi + IO_OBJ.capacity], PAGE_SIZE
;; test _getchar
;.loop:
;	call _getchar
;	or al, al
;	jz .eloop
;	mov byte [writebuf], al
;	mov eax, 0x01
;	mov edi, 0x02
;	mov rsi, writebuf
;	mov edx, eax
;	syscall
;	jmp .loop
;.eloop:
;	int3
	mov [line], 0x00
	call main_loop
	cmp qword [udef_macros], 0x00
	jz .no_free_udef
		mov rdi, [udef_macros]
		call _sys_free
	.no_free_udef:

	mov rsi, [output_stack.ptr]
	mov edx, [rsi]
	mov rsi, [rsi + 0x08]
	mov rdi, 0x01
	mov rax, 0x01
	syscall

	mov rdi, [output_stack.ptr]
	call _sys_free
	mov rdi, [input_stack.ptr]
	call _sys_free

	xor eax, eax
	xor edi, edi
	mov al, 0x3C
	syscall

main_loop:
	call _skip_whitespace
	call _peek
	call _consume
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
	; if al is \ then we should do a macro check
	cmp al, ']'
	je .numdone
	cmp al, '\'
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
	cmp al, '\'
	jne .not_macro
		call _consume
		xor eax, eax
		dec eax
		call _macro
		jmp .continue
	.not_macro:
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

	mov rdi, rsi
	xchg eax, esi
	call _outs

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

_macro: ; if ax is FFFF _macro will return instead of jmp to mainloop
	; If the first character is a symbol, then that is the identifier,
	; otherwise the identifier is each alphabetic character which follows
	and rax, 0xFFFF
	push rax
	call _get_identifier
	push rax
.found_identifier:
; test identifier
;push rdi
;push rsi
;push rdx
;push rax
;.dbg:
;	mov rdi, 0x02
;	mov rsi, identifier
;	mov rdx, [rsp]
;	mov rax, 0x01
;	syscall	
;pop rax
;pop rdx
;pop rsi
;pop rdi

	; search through macros
	mov rbx, [latest]
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
	jz .list_exhausted
	jmp .macro_loop
.found_macro:
	test qword [rbx + LAS_MACRO.flags], LAS_UNFINISHED
	jnz .next
	push rbx
	mov rcx, [rsp + 0x08]
	mov rax, [rbx + LAS_MACRO.flags]
	test byte [isimmediate], 0xFF
	jz .not_immediate
		test [rbx + LAS_MACRO.flags], LAS_IMMEDIATE
		jnz .not_immediate
		pop rbx
		pop rdi
		jmp .return
	.not_immediate:
	test [rbx + LAS_MACRO.flags], LAS_EMBEDDED
	jnz .embed
	test [rbx + LAS_MACRO.flags], LAS_LIST
	jnz .list
	test [rbx + LAS_MACRO.flags], LAS_STRMACRO
	jnz .strmacro
.error:
	int3
.list_exhausted:
	pop rdi
	test [isimmediate], 0xFF
	jz .error
	jmp short .return
.embed:
	call [rbx + LAS_MACRO.ptr]
	pop rbx
	pop rax
	xor edi, edi
	test [rbx + LAS_MACRO.flags], LAS_IMMEDIATE
	jnz .return
	mov rdi, rax
	jmp .return
.list:
	mov rsi, [rbx + LAS_MACRO.ptr]
	lodsd
	mov rdi, rsi
	xchg eax, esi
	call _outs
	pop rbx
	pop rax
	xor edi, edi
	test [rbx + LAS_MACRO.flags], LAS_IMMEDIATE
	jnz .return
	mov rdi, rax
	jmp .return
.strmacro:
	mov rsi, [rbx + LAS_MACRO.ptr]
	lodsd
	xchg eax, edi
	xchg rdi, rsi
	mov rdx, input_stack
	call _io_append
	mov rsi, [input_stack.ptr]
	pop rbx
	pop rax
	xor edi, edi
	test [rbx + LAS_MACRO.flags], LAS_IMMEDIATE
	jnz .return
	mov rdi, rax
.return:
	pop rax
	inc ax
	jnz .jump_return
	mov al, dil
	ret
.jump_return:
	mov al, dil
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
	mov al, 0x00
	call _outc
	ret

MAC_immcall:
	call _skip_whitespace
	call _getchar
	cmp al, '\'
	jne .error

	mov al, [isimmediate]
	push rax

	mov byte [isimmediate], 0x00

	mov ax, 0xFFFF
	call _macro

	pop rax
	mov [isimmediate], al
	ret
.error:
	int3

MAC_define:
	; \\<identifier> [ <list> ]
	; \\<identifier> { <string> }
	call _add_macro
	mov rdi, [latest]
	mov [rax + LAS_MACRO.next], rdi
	mov [latest], rax
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
	mov [rsi + LAS_MACRO.name], rdi
	mov [rsi + LAS_MACRO.flags], LAS_UNFINISHED ; not embedded

;; debug macros
;	mov rbx, [latest]
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
;	int3

	call _skip_whitespace
	call _getchar

	cmp al, '*'
	jne .immediate_handled
	or [rsi + LAS_MACRO.flags], LAS_IMMEDIATE
	call _getchar
.immediate_handled:
	cmp al, '['
	je MACdef_byte_list
	cmp al, '{'
	je MACdef_strmacro
.error:
	int3

MACdef_byte_list:
	call _parse_byte_list
	mov rsi, [latest]
	mov [rsi + LAS_MACRO.ptr], rax
	or [rsi + LAS_MACRO.flags], LAS_LIST
	and [rsi + LAS_MACRO.flags], not LAS_UNFINISHED
	jmp main_loop
MACdef_strmacro:
	; &content	r12
	; length	r13
	; capacity	r14
	; nesting	r15
	push r12
	push r13
	push r14
	push r15

	mov edi, PAGE_SIZE
	call _sys_malloc

	mov r12, [latest]
	or [r12 + LAS_MACRO.flags], LAS_STRMACRO
	add r12, LAS_MACRO.ptr
	mov [r12], rax
	mov r13d, 0x04		; length
	mov r14d, PAGE_SIZE	; capacity
	mov r15d, 0x01
.loop:
	call _getchar
	or al, al
	jz .error
	cmp al, '`'
	jne .not_escaped
		call _getchar
		jmp .add_char
	.not_escaped:
	cmp al, '}'
	jne .not_close
		dec r15
		jz .end_loop
		jmp .add_char
	.not_close:
	cmp al, '{'
	jne .not_open
		inc r15
		jz .end_loop
		jmp .add_char
	.not_open:
	cmp al, '\'
	jne .not_macro
		mov al, [isimmediate]
		push rax
		mov byte [isimmediate], 0xFF
		xor eax, eax
		dec eax
		call _macro
		mov rdi, rax
		pop rax
		mov [isimmediate], al

		push rdi
		push identifier
		or rdi, rdi
		jz .no_identifier
			mov al, '\'
			jmp .idenaddchar
		.idenloop:
			mov rsi, [rsp]
			lodsb
			mov [rsp], rsi
			dec qword [rsp + 0x08]
			cmp qword [rsp + 0x08], -1
			je .no_identifier
		.idenaddchar:
			mov rdi, [r12]
			add rdi, r13
			stosb
			inc r13d

			cmp r13d, r14d
			jb .idenloop
			; we need to realloc rbx and do all that
			add r14d, PAGE_SIZE

			mov rdi, [r12]
			mov esi, r14d
			call _sys_realloc ; realloc buffer
			mov [r12], rax
			jmp .idenloop
		.no_identifier:
		pop rdi
		pop rdi

		jmp .loop
	.not_macro:
.add_char:
	mov rdi, [r12]
	add rdi, r13
	stosb
	inc r13d

	cmp r13d, r14d
	jb .loop
	; we need to realloc rbx and do all that
	add r14d, PAGE_SIZE

	mov rdi, [r12]
	mov esi, r14d
	call _sys_realloc ; realloc buffer
	mov [r12], rax
	jmp .loop
.end_loop:
;; test strmacro contents
;	mov rax, 0x01
;	mov rdi, 0x02
;	mov rsi, [r12]
;	mov edx, r13d
;	syscall

	mov rsi, [r12]
	sub r13d, 0x04
	mov dword [rsi], r13d
	pop r15
	pop r14
	pop r13
	pop r12
	mov rsi, [latest]
	and [rsi + LAS_MACRO.flags], not LAS_UNFINISHED
	jmp main_loop
.error:
	int3
	nop
