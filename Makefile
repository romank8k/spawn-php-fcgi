CFLAGS = -std=c99 -O2 -g -Wall
OBJS = src/spawn-php-fcgi.o

TARGET = spawn-php-fcgi
SYSTEMD_SOCKET_FILE = spawn-php-fcgi@.socket
SYSTEMD_SERVICE_FILE = spawn-php-fcgi@.service

$(TARGET): $(OBJS)
	$(CC) -o $(TARGET) $(OBJS)

all: $(TARGET)

install:
	cp $(TARGET) /usr/local/bin/spawn-php-fcgi
	cp $(SYSTEMD_SOCKET_FILE) /etc/systemd/system/$(SYSTEMD_SOCKET_FILE)
	cp $(SYSTEMD_SERVICE_FILE) /etc/systemd/system/$(SYSTEMD_SERVICE_FILE)

clean:
	rm -f $(OBJS) $(TARGET)
