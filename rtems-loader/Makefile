all: rtems-loader.bin

rtems-loader.bin: rtems-loader-linked.o
	objcopy -O binary $^ $@

rtems-loader-linked.o: rtems-loader.o
	ld -z max-page-size=0x200000 --gc-sections -m elf_i386 -T linker.lds $^ -o $@

rtems-loader.o: rtems-loader.S
	gcc -m32 -c -o $@ $^

clean:
	rm -f *.o *.bin
