obj-m += honor_deep_sleep_fix.o

KDIR ?= /lib/modules/$(shell uname -r)/build

all:
	make -C $(KDIR) M=$(PWD) modules

clean:
	make -C $(KDIR) M=$(PWD) clean

install:
	mkdir -p /lib/modules/$(shell uname -r)/extra
	cp honor_deep_sleep_fix.ko /lib/modules/$(shell uname -r)/extra/
	depmod -a
