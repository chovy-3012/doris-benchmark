
INSTALL_DIR = ${CURDIR}/output
export INSTALL_DIR

all: subdirs
.PHONY: all

# build all subdir
SUBDIR = thirdparty resource
subdirs: ${SUBDIR}
.PHONY: subdirs ${SUBDIR}

${SUBDIR}:
	$(MAKE) -C $@

install: all
	mkdir -p ${INSTALL_DIR}
	for DIR in $(SUBDIR); do ${MAKE} -C $${DIR} install; done
	mkdir -p ${INSTALL_DIR}/bin
	cp bin/* ${INSTALL_DIR}/bin/
	mkdir -p ${INSTALL_DIR}/conf
	cp conf/* ${INSTALL_DIR}/conf/
	mkdir -p ${INSTALL_DIR}/lib
	cp -r src/ssb_test ${INSTALL_DIR}/lib

clean:
	for DIR in $(SUBDIR); do ${MAKE} -C $${DIR} clean; done

.PHONY: clean
