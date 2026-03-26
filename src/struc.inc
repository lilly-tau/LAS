struc las_macro _name*, _ptr*, _flags*, _next*
label .
.name	dq	_name
.ptr	dq	_ptr
.flags	dq	_flags
.next	dq	_next
end struc
virtual at 0
LAS_MACRO las_macro ?, ?, ?, ?
sizeof.LAS_MACRO = $
end virtual

struc buffer _ptr*, _capacity*
label .
match =$, _ptr
.ptr		dq .content
.capacity	dd _capacity
.length		dd 0x00
.content	rb _capacity
else
.ptr		dq _ptr
.capacity	dd _capacity
.length		dd 0x00
end match
end struc
