segment readable

macro_names:
	strdef .def, "\"
	strdef .immcall, "*"
	strdef .null, "null"
	strdef .upurge, "purge"
	strdef .ppurge, "ppurge"
	strdef .mpush, "["
	strdef .mdrop, "."
	strdef .debug, "debug"
	strdef .wordsize, "wordsize"
	strdef .breakpoint, "breakpoint"
	strdef .mif, "mif"

symbols db "~!@#$%^&*()_+`-={}[]|\;':<>,.?/", 0x22
SYMBOL_COUNT = $ - symbols

segment readable writeable

isimmediate db 0x00

input buffer $, PAGE_SIZE
program_stack buffer 0x00, 0x00
word_size dd 0x04

report_identifier db 0x00
identifier:
.content rb PAGE_SIZE
.length dd 0x00

writebuf dq ?

line dd ?

udef_macros.length dd ? ; only allowing 4GB of macros seems fine
udef_macros.capacity dd ?
udef_macros dq 0x00 ; should be mmapped

latest dq las_macros.null
las_macros:
.null las_macro		macro_names.null, MAC_null, LAS_EMBEDDED, .immcall
.immcall las_macro	macro_names.immcall, MAC_immcall,\
			LAS_EMBEDDED or LAS_IMMEDIATE, .upurge
.upurge las_macro	macro_names.upurge, MAC_purge, LAS_EMBEDDED, .ppurge
.ppurge las_macro	macro_names.ppurge, MAC_ppurge, LAS_EMBEDDED, .mpush
.mpush las_macro	macro_names.mpush, MAC_push, LAS_EMBEDDED, .mdrop
.mdrop las_macro	macro_names.mdrop, MAC_drop, LAS_EMBEDDED, .mif
.mif las_macro		macro_names.mif, MAC_mif, LAS_EMBEDDED, .debug
.debug las_macro	macro_names.debug, MAC_debug, LAS_EMBEDDED, .breakpoint
.breakpoint las_macro	macro_names.breakpoint, MAC_breakpoint, LAS_EMBEDDED,\
			.wordsize
.wordsize las_macro	macro_names.wordsize, MAC_wordsize, LAS_EMBEDDED, .def
.def las_macro		macro_names.def, MAC_define, LAS_EMBEDDED, 0x00


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

