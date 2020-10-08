#define X86_CR0_PE	0x00000001
#define X86_CR0_WP	0x00010000
#define X86_CR4_PSE	0x00000010

#define MSR_MTRR_DEF_TYPE	0x000002ff
#define     MTRR_ENABLE		0x00000800

#define MSR_IA32_PERF_CTRL	0x00000199
#define MAX_PSTATE		23

#define INMATE_CS32	0x8
#define INMATE_DS32	0x18

	.code16
	.section ".boot.entry", "ax"

	.globl __reset_entry
__reset_entry:
	lgdtl %cs:gdt_ptr

	mov %cr0, %eax
	or $X86_CR0_PE, %eax
	mov %eax, %cr0

	ljmpl $INMATE_CS32, $start32

	.code32
	.section ".boot", "ax"
start32:
	mov %cr4, %eax
	or $X86_CR4_PSE, %eax
	mov %eax, %cr4

	mov $(X86_CR0_WP | X86_CR0_PE), %eax
	mov %eax, %cr0

	movl $MSR_MTRR_DEF_TYPE,%ecx
	rdmsr
	or $MTRR_ENABLE, %eax
	wrmsr

	movl $MSR_IA32_PERF_CTRL, %ecx
	rdmsr
	mov $MAX_PSTATE << 8, %eax
	wrmsr

	mov $INMATE_DS32, %eax
	mov %eax, %ds
	mov %eax, %es
	mov %eax, %ss

	mov $0x20000c, %ebx
	jmp *%ebx

        .align(16)
        .global loader_gdt
loader_gdt:
	.quad   0
	.quad   0x00cf9b000000ffff
	.quad   0x00af9b000000ffff
	.quad   0x00cf93000000ffff

	.globl gdt_ptr
gdt_ptr:
	.short  gdt_ptr - loader_gdt - 1
	.long   loader_gdt
