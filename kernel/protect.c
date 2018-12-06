#include "type.h"
#include "protect.h"
#include "fs.h"
#include "proc.h"
#include "const.h"
#include "tty.h"
#include "console.h"
#include "proto.h"
#include "global.h"

/*
异常处理函数
*/
void divide_error();
void single_step_exception();
void nmi();
void breakpoint_exception();
void overflow();
void bounds_check();
void inval_opcode();
void copr_not_available();
void double_fault();
void copr_seg_overrun();
void inval_tss();
void segment_not_present();
void stack_exception();
void general_protection(); 
void page_fault();
void copr_error();

/*
中断处理函数
*/
void hwint00();
void hwint01();
void hwint02();
void hwint03();
void hwint04();
void hwint05();
void hwint06();
void hwint07();
void hwint08();
void hwint09();
void hwint10();
void hwint11();
void hwint12();
void hwint13();
void hwint14();
void hwint15();


PUBLIC void exception_handler(int vec_no,int err_code,int eip,int cs,int eflags){
	int i;
	int text_color = 0x74;				//灰底红字

	char *err_msg[]={
		"#DE Divide Error",
		"#DB RESERVED",
		"--  NMI Interrupt",
	    "#BP Breakpoint",
		"#OF Overflow",
		"#BR BOUND Range Exceeded",
		"#UD Invalid Opcode (Undefined Opcode)",
		"#NM Device Not Available (No Math Coprocessor)",
		"#DF Double Fault",
	    "--  Coprocessor Segment Overrun (reserved)",
		"#TS Invalid TSS",
		"#NP Segment Not Present",
		"#SS Stack-Segment Fault",
		"#GP General Protection",
		"#PF Page Fault",
		"--  (Intel reserved. Do not use.)",
		"#MF x87 FPU Floating-Point Error (Math Fault)",
		"#AC Alignment Check",
		"#MC Machine Check",
		"#XF SIMD Floating-Point Exception"
	};

	disp_pos = 0;
	for(i=0 ;i<80*5 ;i++)						//清空前5行
		disp_str(" ");
	disp_pos = 0;

	disp_color_str("Exception--> ", text_color);
	disp_color_str(err_msg[vec_no],text_color);

	disp_color_str("\n\n",text_color);
	disp_color_str("EFLAGS: ",text_color);
	disp_int(eflags);
	disp_color_str("CS: ",text_color);
	disp_int(cs);
	disp_color_str("EIP: ",text_color);
	disp_int(eip);

	if(err_code != 0xffffffff){
		disp_color_str("Error code: ",text_color);
		disp_int(err_code);
	}

}

/*
//门描述符
typedef struct s_gate
{
	u16	offset_low;	/* Offset Low */
//	u16	selector;	/* Selector */
//	u8	dcount;		/* 该字段只在调用门描述符中有效。如果在利用
//				   调用门调用子程序时引起特权级的转换和堆栈
//				   的改变，需要将外层堆栈中的参数复制到内层
//				   堆栈。该双字计数字段就是用于说明这种情况
//				   发生时，要复制的双字参数的数量。*/
//	u8	attr;		/* P(1) DPL(2) DT(1) TYPE(4) */
//	u16	offset_high;	/* Offset High */
//}Gate;
//*/
/*
	初始化中断描述符
*/
PRIVATE void init_idt_desc(u8 vector,u8 desc_type,int_handler handler,u8 privilege){
	Gate * p_gate = &idt[vector];
	u32 offset = (u32)handler;
	p_gate->offset_low = offset & 0xffff;
	p_gate->selector = 0x18;
	p_gate->dcount = 0;
	p_gate->attr = desc_type | (privilege<<5);
	p_gate->offset_high = (offset>>16) & 0xffff;
}

/*
	初始化全局（局部）描述符
*/
PRIVATE void init_descriptor(Descriptor* desc, u32 base, u32 limit,u16 attribute){
	desc->limit_low = limit & 0xffff;
	desc->base_low = base & 0xffff;
	desc->base_mid = (base>>16) & 0xff;
	desc->attr1 = attribute & 0xff;
	desc->limit_high_attr2 = ((limit>>16)&0xf) | (attribute >> 8) & 0xf0;
	desc->base_high = (base >> 24) & 0xff;
}

PUBLIC u32 seg2phys(u16 seg){
	Descriptor* p_desc = &gdt[seg>>3];
	return (p_desc->base_high<<24 | p_desc->base_mid << 16 | p_desc->base_low);
}


PUBLIC void init_prot(){
	init_8259A();

//初始化中断门
	init_idt_desc(INT_VECTOR_DIVIDE, DA_386IGATE, divide_error, PRIVILEGE_KERNEL);
	init_idt_desc(INT_VECTOR_DEBUG,DA_386IGATE,single_step_exception,PRIVILEGE_KERNEL);
	init_idt_desc(INT_VECTOR_NMI,DA_386IGATE,nmi,PRIVILEGE_KERNEL);
	init_idt_desc(INT_VECTOR_BREAKPOINT,DA_386IGATE,breakpoint_exception,PRIVILEGE_USER);
	init_idt_desc(INT_VECTOR_OVERFLOW,DA_386IGATE,overflow,PRIVILEGE_USER);
	init_idt_desc(INT_VECTOR_BOUNDS,DA_386IGATE,bounds_check,PRIVILEGE_KERNEL);
	init_idt_desc(INT_VECTOR_INVAL_OP,DA_386IGATE,inval_opcode,PRIVILEGE_KERNEL);
	init_idt_desc(INT_VECTOR_COPROC_NOT,DA_386IGATE,copr_not_available,PRIVILEGE_KERNEL);
	init_idt_desc(INT_VECTOR_DOUBLE_FAULT,DA_386IGATE,double_fault,PRIVILEGE_KERNEL);
	init_idt_desc(INT_VECTOR_COPROC_SEG,DA_386IGATE,copr_seg_overrun,PRIVILEGE_KERNEL);
	init_idt_desc(INT_VECTOR_INVAL_TSS,DA_386IGATE,inval_tss,PRIVILEGE_KERNEL);
	init_idt_desc(INT_VECTOR_SEG_NOT,DA_386IGATE,segment_not_present,PRIVILEGE_KERNEL);
	init_idt_desc(INT_VECTOR_STACK_FAULT,DA_386IGATE,stack_exception,PRIVILEGE_KERNEL);
	init_idt_desc(INT_VECTOR_PROTECTION,DA_386IGATE,general_protection,PRIVILEGE_KERNEL);
	init_idt_desc(INT_VECTOR_PAGE_FAULT,DA_386IGATE,page_fault,PRIVILEGE_KERNEL);
	init_idt_desc(INT_VECTOR_COPROC_ERR,DA_386IGATE,copr_error,PRIVILEGE_KERNEL);

	//硬件中断
	init_idt_desc(IRQ0 + 0,DA_386IGATE,hwint00,PRIVILEGE_KERNEL);
	init_idt_desc(IRQ0 + 1,DA_386IGATE,hwint01,PRIVILEGE_KERNEL);
	init_idt_desc(IRQ0 + 2,DA_386IGATE,hwint02,PRIVILEGE_KERNEL);
	init_idt_desc(IRQ0 + 3,DA_386IGATE,hwint03,PRIVILEGE_KERNEL);
	init_idt_desc(IRQ0 + 4,DA_386IGATE,hwint04,PRIVILEGE_KERNEL);
	init_idt_desc(IRQ0 + 5,DA_386IGATE,hwint05,PRIVILEGE_KERNEL);
	init_idt_desc(IRQ0 + 6,DA_386IGATE,hwint06,PRIVILEGE_KERNEL);
	init_idt_desc(IRQ0 + 7,DA_386IGATE,hwint07,PRIVILEGE_KERNEL);
	init_idt_desc(IRQ8 + 0,DA_386IGATE,hwint08,PRIVILEGE_KERNEL);
	init_idt_desc(IRQ8 + 1,DA_386IGATE,hwint09,PRIVILEGE_KERNEL);
	init_idt_desc(IRQ8 + 2,DA_386IGATE,hwint10,PRIVILEGE_KERNEL);
	init_idt_desc(IRQ8 + 3,DA_386IGATE,hwint11,PRIVILEGE_KERNEL);
	init_idt_desc(IRQ8 + 4,DA_386IGATE,hwint12,PRIVILEGE_KERNEL);
	init_idt_desc(IRQ8 + 5,DA_386IGATE,hwint13,PRIVILEGE_KERNEL);
	init_idt_desc(IRQ8 + 6,DA_386IGATE,hwint14,PRIVILEGE_KERNEL);
	init_idt_desc(IRQ8 + 7,DA_386IGATE,hwint15,PRIVILEGE_KERNEL);
	init_idt_desc(INT_VECTOR_SYS_CALL,DA_386IGATE,sys_call,PRIVILEGE_USER);			//系统调用

	memset(&tss, 0, sizeof(tss));
	tss.ss0 = SELECTOR_KERNEL_DS;
	init_descriptor(&gdt[INDEX_TSS],vir2phys(seg2phys(SELECTOR_KERNEL_DS),&tss),sizeof(tss)-1,DA_386TSS);
	tss.iobase = sizeof(tss);

	int i;
	PROCESS* p_proc = proc_table;
	u16 selector_ldt = SELECTOR_LDT_FIRST >> 3;						//SELECTOR_LDT_FIRST / 8
	for(i=0; i<NR_TASKS + NR_PROCS; i++){
		init_descriptor(&gdt[selector_ldt],
						vir2phys(seg2phys(SELECTOR_KERNEL_DS), proc_table[i].ldts),
						LDT_SIZE * sizeof(Descriptor) - 1,
						DA_LDT);
		p_proc++;
		selector_ldt++;
	}
	

}

/*
显示硬件中断号
*/
PUBLIC spurious_irq(int irq){
	disp_str("spurious_irq: ");
	disp_int(irq);
	disp_str("\n");
}