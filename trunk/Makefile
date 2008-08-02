all:

install:
	cp -f anna.pl /usr/local/bin/anna
	chmod a+x /usr/local/bin/anna
	cp -f anna.conf /etc/anna.conf
	chmod a+r /etc/anna.conf
	[ -d /usr/local/share/anna ] || mkdir /usr/local/share/anna
	cp -f anna.db /usr/local/share/anna/anna.db
	chmod a+r /usr/local/share/anna/anna.db

modules_install:
	cp -r modules/* /home/arkanoid/.anna/modules/

docs:
	/usr/bin/NaturalDocs -i . -o html api/ -p api/nd/ -do 
