%include "pm.inc"
	
PageDirBase0		equ		0					;页目录0从0开始
PageTblBase0		equ		0x1000				;页表0从4k开始
PageDirBase1		equ 	0x100000	 		;页目录1从0x100开始
PageTblBase1 		equ		0x101000   			;页表从0x101000开始
LinearAddrDemo		equ		0x401000
ProcFoo				equ		0x401000
ProcBar				equ		0x501000
ProcPagingDemo		equ		0x301000

	org 0x100
	jmp BEGIN 

;段描述符
[SECTION .gdt]
;								段基址			段界限					段属性
GDT:		Descriptor       	 0,             0,                      0					;空描述符
CODE32:		Descriptor	 		 0, 		    Code32Len - 1,          0x9a + 0x4000  		;32位代码段
CODE16:		Descriptor			 0,			 	0xffff,		 			0x98				;16位代码段
VIDEO:		Descriptor	  		 0xb8000,		0xffff,		 			0x93				;显存
DATA:		Descriptor	  		 0,			 	DataLen - 1,		 	0x92				;数据段
STACK:		Descriptor	  		 0,			 	TopOfStack,	 		    0x92 + 0x4000  		;32位栈段	
NORMAL:		Descriptor	    	 0,			 	0xffff,		 			0x92				;普通段
FLAT_RW:	Descriptor			 0,				0xfffff,				0x92 + 0x8000       ;读写数据段
FLAT_C:		Descriptor			 0,				0xfffff,				0x9a + 0x4000+0x8000

;GDT寄存器
GdtPtr		dw	$-GDT-1																		;GDT界限
			dd	0																			;GDT基地址(16位模式下低20位有效)

;段选择子
SelectorCode32		equ	 CODE32	-	GDT
SelectorCode16		equ	 CODE16 - 	GDT
SelectorVideo		equ	 VIDEO	-	GDT
SelectorStack		equ	 STACK  -	GDT
SelectorData		equ	 DATA	-	GDT
SelectorNormal		equ	 NORMAL	-	GDT
SelectorFlatRw		equ	 FLAT_RW - GDT
SelectorFlatC		equ	 FLAT_C - GDT


[SECTION .data]
ALIGN 32
[BITS 32]
SEG_DATA:
_szPMMessage:		db	"In Protect Mode now.", 0Ah, 0Ah, 0								;进入保护模式后显示此字符串
_szMemChkTitle:		db	"BaseAddrL BaseAddrH LengthLow LengthHigh   Type", 0Ah, 0			; 进入保护模式后显示此字符串
_szRAMSize			db	"RAM size:", 0
_szReturn			db	0Ah, 0																;换行符

_wSPValueInRealMode	dw  0
_dwMCRNumber:		dd	0																	;内存块数量
_dwDispPos:			dd	(80 * 6 + 0) * 2	; 屏幕第 6 行, 第 0 列。							;指向下一个显示位置
_dwMemSize:			dd	0		
_PageTableNumber	dd  0															
_ARDStruct:																					;返回结果的数据结构
	_dwBaseAddrLow:		dd	0																
	_dwBaseAddrHigh:	dd	0
	_dwLengthLow:		dd	0
	_dwLengthHigh:		dd	0
	_dwType:			dd	0

_MemChkBuf:	times	256	db	0																;存放int 15h返回结果


szPMMessage 		equ		_szPMMessage - $$
szMemChkTitle		equ		_szMemChkTitle - $$
szRAMSize 			equ		_szRAMSize - $$
szReturn 			equ		_szReturn - $$
dwMCRNumber 		equ		_dwMCRNumber - $$
dwDispPos 			equ     _dwDispPos - $$
dwMemSize 			equ		_dwMemSize - $$
ARDStruct 			equ		_ARDStruct - $$
	dwBaseAddrLow 	equ		_dwBaseAddrLow - $$
	dwBaseAddrHigh  equ		_dwBaseAddrHigh - $$
	dwLengthLow 	equ		_dwLengthLow - $$
	dwLengthHigh 	equ		_dwLengthHigh - $$
	dwType 			equ		_dwType - $$
MemChkBuf 			equ		_MemChkBuf - $$
PageTableNumber     equ     _PageTableNumber - $$

DataLen				equ		$ - SEG_DATA

;全局堆栈
[SECTION .stack]
ALIGN 32
[BITS 32]
SEG_STACK:
times 		512 	db 	0

TopOfStack			equ		$ - SEG_STACK - 1


[SECTION .s16]
[BITS 16]
BEGIN:
	mov ax,cs
	mov ds,ax
	mov es,ax
	mov gs,ax
	mov ss,ax
	mov sp,0x100
	mov [_wSPValueInRealMode],sp

;扫描内存信息
	mov ebx,0
	mov di,_MemChkBuf
.loop:
	mov ecx,20
	mov edx,0x534d4150
	mov eax,0xe820
	int 15h
	jc CHACK_FAIL						;CF=1存在错误
	add di,20
	inc dword [_dwMCRNumber]
	cmp ebx,0
	jne .loop
	jmp CHECK_OK						;最后一个地址范围描述符
CHACK_FAIL:
	MOV dword [_dwMCRNumber],0
CHECK_OK:
;设置32位代码段描述符
	xor eax,eax
	mov ax,cs
	shl eax,4
	add eax,SEG_CODE32											;计算32位代码段基地址
	mov word [CODE32+2],ax										;代码段基址1
	shr eax,16
	mov byte [CODE32+4],al										;代码段基址2
	mov byte [CODE32+7],ah										;代码段基址3

;设置16位代码段描述符
;	xor eax,eax
;	mov ax,cs
;	shl eax,4
;	add eax,SEG_CODE16
;	mov word [CODE16+2],ax
;	shr eax,16
;	mov byte [CODE16+4],al
;	mov byte [CODE16+7],ah

;设置数据段描述符
	xor eax,eax
	mov ax,ds
	shl eax,4
	add eax,SEG_DATA
	mov word [DATA+2],ax
	shr eax,16
	mov byte [DATA+4],al
	mov byte [DATA+7],ah

;设置栈段描述符
	xor eax,eax
	mov ax,ss
	shl eax,4
	add eax,SEG_STACK
	mov word [STACK+2],ax
	shr eax,16
	mov byte [STACK+4],al
	mov byte [STACK+7],ah

	;设置GDT寄存器	
	xor eax,eax
	mov ax,ds
	shl eax,4
	add eax,GDT
	mov dword [GdtPtr+2],eax
	
;加载GDT
	lgdt [GdtPtr]

;关中断
	cli

;打开A20地址线
	in al,92h
	or al,00000010b
	out 92h,al

;设置CR0寄存器
	mov eax,cr0
	or  eax,1
	mov cr0,eax

	jmp dword SelectorCode32:0

[SECTION .s32]
[BITS 32]
SEG_CODE32:
	mov ax,SelectorData								;装入段选择子
	mov ds,ax
	mov es,ax
	mov ax,SelectorStack
	mov ss,ax
	mov ax,SelectorVideo
	mov gs,ax
	mov esp,TopOfStack

	push szPMMessage
	call DispStr
	add esp,4

	push szMemChkTitle
	call DispStr
	add esp,4


	call DispMemSIze
;	call bar
	call PagingDemo

	jmp $



DispMemSIze:										;显示内存段信息
	push esi
	push ecx
	mov esi,MemChkBuf
	mov ecx,[dwMCRNumber]
.1:
	mov edx,5
	mov edi,ARDStruct
.2:
	push dword [esi]
	call DispInt
	pop eax
	mov dword [edi],eax
	add edi,4
	add esi,4
	dec edx
	jnz .2
	cmp dword [dwType],1
	jne .3
	mov eax,[dwBaseAddrLow]
	add eax,[dwLengthLow]
	cmp eax,[dwMemSize]
	jb .1
	mov [dwMemSize],eax
.3:
	call DispReturn
	dec ecx
	jnz .1
	push szRAMSize
	call DispStr
	add esp,4
	push dword [dwMemSize]
	call DispInt
	add esp,4


	pop ecx
	pop esi
	ret

SetupPaging:
	xor edx,edx
	mov eax,[dwMemSize]
	mov ebx,0x400000
	div ebx
	mov ecx,eax
	test ebx,ebx
	jz .1
	inc ecx
.1:
;	初始化页目录
	mov [PageTableNumber],ecx				;页表个数
	mov ax,SelectorFlatRw
	mov es,ax
	mov edi,PageDirBase0
	xor eax,eax
	mov eax,PageTblBase0
	or  eax,0x7
.2:
	stosd								
	add eax,4096
	loop .2
;初始化页表
	mov eax,[PageTableNumber]
	mov ebx,1024
	mul ebx
	mov ecx,eax
	mov edi,PageTblBase0
	xor eax,eax
	or eax,0x7
.3:
	stosd
	add eax,4096
	loop .3

	mov eax,PageDirBase0
	mov cr3,eax
	mov	eax, cr0
	or	eax, 80000000h
	mov	cr0, eax
.4:
;	nop
	ret

PagingDemo:
	mov ax,cs
	mov ds,ax
	mov ax,SelectorFlatRw
	mov es,ax

	push LenFoo
	push offsetFoo
	push ProcFoo
	call MemCpy
	add esp,12			;堆栈平衡


	push LenBar
	push offsetBar
	push ProcBar
	call MemCpy
	add esp,12		

	push LenPagingDemoProc
	push offsetPagingDemoProc
	push ProcPagingDemo
	call MemCpy
	add esp,12		

	mov ax,SelectorData
	mov ds,ax
	mov es,ax

	call SetupPaging
	call SelectorFlatC:ProcPagingDemo
	call PageSwitch
	call SelectorFlatC:ProcPagingDemo
	ret


foo:
offsetFoo		equ		foo - $$
	mov ah,0xc
	mov al,"F"
	mov [gs:((80*17+0)*2)],ax
	mov al,"o"
	mov [gs:((80*17+1)*2)],ax
	mov al,"o"
	mov [gs:((80*17+2)*2)],ax
	ret
LenFoo		equ		$ - foo

bar:
offsetBar		equ		bar - $$
	mov ah,0xc
	mov al,"B"
	mov [gs:((80*18+0)*2)],ax
	mov al,"a"
	mov [gs:((80*18+1)*2)],ax
	mov al,"r"
	mov [gs:((80*18+2)*2)],ax
	ret
LenBar		equ		$ - bar

PagingDemoProc:
offsetPagingDemoProc		equ		PagingDemoProc - $$
	mov eax,LinearAddrDemo
	call eax
	retf
LenPagingDemoProc		equ		$ - PagingDemoProc

PageSwitch:
	mov ecx,[PageTableNumber]
	mov ax,SelectorFlatRw
	mov es,ax
	mov edi,PageDirBase1
	xor eax,eax
	mov eax,PageTblBase1
	or  eax,0x7
.1:
	stosd
	add eax,4096
	loop .1

	mov eax,[PageTableNumber]
	xor edx,edx
	mov ebx,1024
	mul ebx
	mov ecx,eax

	mov edi,PageTblBase1
	xor eax,eax
	mov eax,0x7
.2:
	stosd
	add eax,4096
	loop .2

	mov eax,LinearAddrDemo
	shr eax,22					;取页表
	mov ebx,4096
	mul ebx						;页表地址
	mov ecx,eax
	mov eax,LinearAddrDemo
	shr eax,12
	and eax,0x3ff				;取页表偏移
	mov ebx,4
	mul ebx
	add eax,ecx
	add eax,PageTblBase1
	mov dword [es:eax],	ProcBar|0x7

	mov eax,PageDirBase1
	mov cr3,eax
;	jmp short .3
.3:
;	nop
	ret





	

%include "lib.inc"

Code32Len 		equ  $ - SEG_CODE32