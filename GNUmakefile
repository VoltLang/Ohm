include command.make


ifeq ($(DC),ldc2)
	DCDEBUG_FLAGS ?= -d-debug -unittest -g -gc
else ifeq ($(DC),gdc)
	DCDEBUG_FLAGS ?= -fdebug -g
else
	DCDEBUG_FLAGS ?= -debug -unittest -g -gc
endif


TARGET		=ohm$(EXE)

VOLTA		= src$(PATH_SEP)Volta
VOLTA_BIN	= $(VOLTA)$(PATH_SEP)rt$(PATH_SEP)libvrt-host.bc

LLVM_CONFIG	?= llvm-config
LLVM_LDFLAGS	?= $(shell $(LLVM_CONFIG) --libs core analysis bitwriter bitreader linker target x86codegen executionengine interpreter mcjit support) $(shell $(LLVM_CONFIG) --ldflags)
ifeq ($(shell echo "$(LLVM_CONFIG) --system-libs &> /dev/null && echo OK" | bash -t), OK)
	LLVM_LDFLAGS := $(LLVM_LDFLAGS) $(shell $(LLVM_CONFIG) --ldflags --system-libs)
else
	LLVM_LDFLAGS := $(LLVM_LDFLAGS) $(shell $(LLVM_CONFIG) --ldflags)
endif

PKG_CONFIG	?= pkg-config

DCFLAGS		+= -Isrc/ -Isrc/Volta/src/
DCFLAGS		+= $(DCDEBUG_FLAGS)
LDFLAGS		+= $(patsubst -%, $(LINKERFLAG)-%, $(LLVM_LDFLAGS)) $(LINKERFLAG)-ldl $(LINKERFLAG)-lstdc++ $(LINKERFLAG)-lffi $(LINKERFLAG)-lreadline

DSOURCES	= $(call getSource,src/ohm,d) src/main.d \
		  $(call getSource,src/lib/readline,d) $(call getSource,src/lib/llvm,d) \
		  $(call getSource,src/Volta/src/volt,d) $(call getSource,src/Volta/src/watt,d) $(call getSource,src/Volta/src/lib,d)
DOBJECTS	= $(patsubst %.d,$(DBUILD_PATH)/%$(EXT), $(DSOURCES))

CSOURCES	=
COBJECTS	= $(patsubst %.cpp,$(CBUILD_PATH)/%$(EXT), $(CSOURCES))


ifeq ($(OS),"Linux")
	LDFLAGS += $(LINKERFLAG)--no-as-needed $(patsubst -%, $(LINKERFLAG)-%, $(shell $(PKG_CONFIG) --libs bdw-gc))
endif


.PHONY: all init run clean clean-all


all: $(TARGET)

init: $(VOLTA)

run: $(TARGET) $(VOLTA_BIN)
	@.$(PATH_SEP)$(TARGET) --stdlib-file src/Volta/rt/libvrt-host.bc --stdlib-I src/Volta/rt/src $(ARGUMENTS)

gdb: $(TARGET) $(VOLTA_BIN)
	gdb --args .$(PATH_SEP)$(TARGET) --stdlib-file src/Volta/rt/libvrt-host.bc --stdlib-I src/Volta/rt/src $(ARGUMENTS)

clean:
	@echo "  RM     $(BUILD_PATH)"
	@$(RM) $(BUILD_PATH)
	@echo "  RM     $(TARGET)"
	@$(RM) $(TARGET)

clean-all: clean
	@echo "  CLEAN  Volta"
	@$(MAKE) -C $(VOLTA) --quiet clean


$(TARGET): $(COBJECTS) $(DOBJECTS)
	@echo "  LD     $(TARGET)"
	@$(DC) $(LDFLAGS) $(COBJECTS) $(DOBJECTS) $(OUTPUT)$(TARGET)


$(VOLTA):
	@echo "  CLONE  Volta"
	@git clone -b ohm https://github.com/VoltLang/Volta.git -q src/Volta

$(VOLTA_BIN):
	@echo "  BUILD  Volta"
	@cd src/Volta/ && $(MAKE) --quiet


# create object files
$(DBUILD_PATH)/%$(EXT) : %.d
	@echo "  DC     $<"
	@mkdir -p $(dir $@)
	@$(DC) $(DCFLAGS) $(DCFLAGS_IMPORT) $(ADDITIONAL_FLAGS) -c $< $(OUTPUT)$@

$(CBUILD_PATH)/%$(EXT) : %.c
	@echo "  CC     $<"
	@mkdir -p $(dir $@)
	@$(CC) $(CFLAGS) -c $< -o $@

$(CBUILD_PATH)/%$(EXT) : %.cpp
	@echo "  CC     $<"
	@mkdir -p $(dir $@)
	@$(CC) -std=c++0x $(CFLAGS) -c $< -o $@
