INCLUDE = include
EBIN = ebin
SRC = src

.PHONY: all clean

all: berlioz ecsv
berlioz: $(SRC)/berlioz.erl
	mkdir -p $(EBIN)
	erlc -I $(INCLUDE) -pa $(EBIN) -o $(EBIN) $(<)

ecsv: $(SRC)/ecsv_parser.erl $(SRC)/ecsv.erl
		erlc -I $(INCLUDE) -pa $(EBIN) -o $(EBIN) $(SRC)/ecsv_parser.erl
		erlc -I $(INCLUDE) -pa $(EBIN) -o $(EBIN) $(SRC)/ecsv.erl

clean:
	rm -rf $(EBIN)/*.beam
	rm -rf erl_crash.dump
