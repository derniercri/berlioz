INCLUDE = include
EBIN = ebin
SRC = src

.PHONY: all clean

all: berlioz
berlioz: $(SRC)/berlioz.erl
	mkdir -p $(EBIN)
	erlc -I $(INCLUDE) -pa $(EBIN) -o $(EBIN) $(<)

clean:
	rm -rf $(EBIN)/*.beam
	rm -rf erl_crash.dump
