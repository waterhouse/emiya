section .data

section .text
global start
start:
	add rbx, rbx
	add rbx, 69
	add rbx, 69		;48 83 c3 45
	add rbx, 69

	add ebx, 45		;83 c3 2d
	add ebx, 45
	add bx, 25		;66 83 c3 19
	add bx, 25
	add bl, 15		;80 c3 0f
	add bl, 15

	ret