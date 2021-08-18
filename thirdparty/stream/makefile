PROGS=stream
all:
	gcc -O3 -fopenmp -DSTREAM_ARRAY_SIZE=100000000 -DNTIMES=20 stream.c -o $(PROGS)

clean:
	@rm -f $(PROGS)

install: $(PROGS)
	cp $(PROGS) ${INSTALL_DIR}/bin/
