CC = gcc
LIB = lastar.so
OBJS = lastar.o \
       AStar.o

LLIBS = -llua
CFLAGS = -c -fPIC -Wall -I../../skynet/3rd
LDFLAGS = --shared -L../../skynet/3rd/lua

all : $(LIB)

$(LIB): $(OBJS)
	$(CC) -o $@ $^ $(LLIBS) $(LDFLAGS) 

$(OBJS) : %.o : %.c
	$(CC) -o $@ $(CFLAGS) $<

clean : 
	rm -f $(OBJS) $(LIB)

.PHONY : clean

