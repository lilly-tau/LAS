define PROT_READ	0x01
define PROT_WRITE	0x02
define PROT_EXEC	0x04

define MAP_SHARED	0x01
define MAP_PRIVATE	0x02
define MAP_FIXED	0x10
define MAP_ANONYMOUS	0x20

define MREMAP_MAYMOVE	0x01


define PAGE_SIZE	0x10000

define LAS_EMBEDDED	0x1	; Macro is written in assembly
define LAS_LIST		0x2	; Macro is a byte list '[]'
define LAS_STRMACRO	0x4	; Macro is a string macro '{}'
define LAS_IMMEDIATE	0x8	; Macro should be ran as soon as it is
				; encountered
define LAS_UNFINISHED	0x10	; Macro should not be run
