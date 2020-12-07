all:

clean:

install: all
	mkdir -p ${DESTDIR}${PREFIX}/bin
	cp -f vimv ${DESTDIR}${PREFIX}/bin
	chmod 755 ${DESTDIR}${PREFIX}/bin/vimv

uninstall:
	rm -f ${DESTDIR}${PREFIX}/bin/vimv

.PHONY: all clean install uninstall
