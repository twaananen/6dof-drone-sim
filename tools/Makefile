CC = gcc
CFLAGS = -Wall -Wextra -O2
TARGET = linux_gamepad_helper

.PHONY: all clean

all: $(TARGET)

$(TARGET): linux_gamepad_helper.c
	$(CC) $(CFLAGS) -o $@ $<

clean:
	rm -f $(TARGET)
