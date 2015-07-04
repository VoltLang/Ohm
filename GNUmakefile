include command.make

LLVM_CONFIG ?= llvm-config
LLVM_LDFLAGS = $(shell $(LLVM_CONFIG) --libs core analysis bitwriter bitreader linker target x86codegen executionengine interpreter mcjit) $(shell $(LLVM_CONFIG) --ldflags)

DCFLAGS_IMPORT	= -Isrc/ -Isrc/Volta/src/
DCFLAGS_LINK	= $(patsubst -%, $(LINKERFLAG)-%, $(LLVM_LDFLAGS)) $(LINKERFLAG)-ldl $(LINKERFLAG)-lstdc++ $(LINKERFLAG)-lffi

OBJDIRS		= $(DBUILD_PATH)/ohm $(DBUILD_PATH)/volt $(DBUILD_PATH)/src $(CBUILD_PATH)/src/c/linenoise

DSOURCES	= $(call getSource,src/ohm,d) src/main.d
DOBJECTS	= $(patsubst %.d,$(DBUILD_PATH)/%$(EXT), $(DSOURCES))

DSOURCES_OTHER 	= $(call getSource,src/Volta/src/volt,d) $(call getSource,src/Volta/src/lib,d) $(call getSource,src/lib,d)
DOBJECTS_OTHER 	= $(patsubst %.d,$(DBUILD_PATH_OTHER)/%$(EXT), $(DSOURCES_OTHER))

CSOURCES	= $(call getSource,src/c/linenoise,c)
COBJECTS	= $(patsubst %.c,$(CBUILD_PATH)/%$(EXT), $(CSOURCES))

DC_UPPER	= `echo $(DC) | tr a-z A-Z`
CC_UPPER	= `echo $(CC) | tr a-z A-Z`


ifeq ($(DC),ldc2)
	ADDITIONAL_FLAGS = -d-debug -unittest -g -gc
else ifeq ($(DC),gdc)
	ADDITIONAL_FLAGS = -fdebug -g
else
	ADDITIONAL_FLAGS = -debug -unittest -g -gc
endif


all: ohm

.PHONY: clean

ohm: buildDir $(COBJECTS) $(DOBJECTS) $(DOBJECTS_OTHER)
	@echo "    LD     ohm"
	@$(DC) $(DCFLAGS_LINK) $(LDCFLAGS) $(COBJECTS) $(DOBJECTS) $(DOBJECTS_OTHER) $(DCFLAGS) $(OUTPUT)ohm

# create object files
$(DBUILD_PATH)/%$(EXT) : %.d
	@echo "    $(DC_UPPER)    $<"
	@$(DC) $(DCFLAGS) $(LDCFLAGS) $(DCFLAGS_IMPORT) $(ADDITIONAL_FLAGS) -c $< $(OUTPUT)$@

$(DBUILD_PATH_OTHER)/%$(EXT) : %.d
	@echo "    $(DC_UPPER)    $<"
	@$(DC) $(DCFLAGS) $(LDCFLAGS) $(DCFLAGS_IMPORT) $(ADDITIONAL_FLAGS) -c $< $(OUTPUT)$@

$(CBUILD_PATH)/%$(EXT) : %.c
	@echo "    $(CC_UPPER)    $<"
	@$(CC) $(CFLAGS) -c $< -o $@

buildDir: $(OBJDIRS)

run: ohm
	@echo "    RUN    ohm"
	@./ohm

$(OBJDIRS) :
	@echo "    MKDIR  $@"
	@$(MKDIR) $@

clean:
	@echo "    RM     build/"
	@$(RM) build