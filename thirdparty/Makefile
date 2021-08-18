# 
all: subdirs
.PHONY: all
# 
# # build all subdir
SUBDIR = ssb-dbgen stream
subdirs: ${SUBDIR}
.PHONY: subdirs ${SUBDIR}
${SUBDIR}:
	$(MAKE) -C $@

# install
install: 
	${MAKE} -C ssb-dbgen install
	${MAKE} -C stream install
.PHONY: install

# clean
clean:
	$(MAKE) -C ssb-dbgen clean
	$(MAKE) -C stream clean
.PHONY: clean
