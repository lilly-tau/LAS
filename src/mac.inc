macro strdef name*, dat&
	label name
	dd @f-$-4
	db dat
	@@:
end macro

macro enter
	push rbp
	mov rbp, rsp
end macro
