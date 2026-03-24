segment readable


symbols db "~!@#$%^&*()_+`-={}[]|\;':<>,.?/", 0x22
SYMBOL_COUNT = $ - symbols

segment readable writeable

isimmediate db 0x00

input:
.length dd 0x00
.content rb PAGE_SIZE
.pointer dd 0x00

identifier:
.length dd 0x00
.content rb PAGE_SIZE

writebuf dq ?

line dd ?

udef_macros.length dd ? ; only allowing 4GB of macros seems fine
udef_macros.capacity dd ?
udef_macros dq 0x00 ; should be mmapped

virtual at 0
LAS_MACRO:
	.name	dq 0x00
	.ptr	dq 0x00
	.flags	dq 0x00
	.next   dq 0x00
sizeof.LAS_MACRO = $
end virtual

latest dq las_macros.null
las_macros:
.null:
.null.name	dq .names.null
.null.ptr	dq MAC_null
.null.flags	dq LAS_EMBEDDED
.null.next	dq .def
.def:
.def.name	dq .names.def
.def.ptr	dq MAC_define
.def.flags	dq LAS_EMBEDDED
.def.next	dq 0x00
.names:
	strdef .names.def, "\"
	strdef .names.null, "null"

struc io_stack
label .
.ptr		dq 0
.top		dd 0
.capacity	dd 0
end struc

virtual at 0
IO_OBJ:
.index		dd 0x00
.capacity	dd 0x00
.buffer		dq 0x00
sizeof.IO_OBJ = $
end virtual
virtual at 0
IO_STACK io_stack
end virtual

input_stack io_stack
output_stack io_stack

