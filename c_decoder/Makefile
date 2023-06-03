# Install
BIN = 8086simulator
OBJ = $(SRC:.c=.o)
LIBS = 
CFLAGS = -Wall -Wextra -pedantic -D_DEFAULT_SOURCE
SRC = 8086simulator.c

# Use this for usual testing etc. 
.PHONY: dev
dev:
	@mkdir -p dev
	rm -f dev/$(BIN) $(OBJS)
	$(CC) $(SRC) $(CFLAGS) -fsanitize=address,undefined -o dev/$(BIN) $(LIBS)

# Debug does not use fsanitize as gdb does not like that(?)
.PHONY: debug
debug:
	@mkdir -p debug
	rm -f debug/$(BIN) $(OBJS)
	$(CC) $(SRC) $(CFLAGS) -g -o debug/$(BIN) $(LIBS)


# Release build TODO: check/add optimizing?
.PHONY: release
release: 
	@mkdir -p release
	rm -f release/$(BIN) $(OBJS)
	$(CC) $(SRC) $(CFLAGS) -O3 -o release/$(BIN) $(LIBS)

