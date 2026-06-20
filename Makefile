CC ?= cc
ERL ?= erl
ERLC ?= erlc

HOST_ARCH := $(shell uname -m)
HOST_OS := $(shell uname -s)

cc-option = $(shell printf 'int main(void){return 0;}\n' | $(CC) $(1) -x c -c -o /dev/null - >/dev/null 2>&1 && printf '%s' '$(1)')
native-flag = $(strip $(call cc-option,-mcpu=native))
ifeq ($(native-flag),)
native-flag = $(strip $(call cc-option,-march=native))
endif

ifeq ($(filter arm64 aarch64,$(HOST_ARCH)),)
AUTO_NEON64_CFLAGS :=
else
AUTO_NEON64_CFLAGS := $(native-flag)
ifeq ($(AUTO_NEON64_CFLAGS),)
AUTO_NEON64_CFLAGS := $(strip $(call cc-option,-march=armv8-a))
endif
endif

ifeq ($(filter armv7% armv6% arm,$(HOST_ARCH)),)
AUTO_NEON32_CFLAGS :=
else
AUTO_NEON32_CFLAGS := $(strip $(call cc-option,-mfpu=neon))
endif

ifneq ($(filter x86_64 amd64 i386 i686,$(HOST_ARCH)),)
AUTO_AVX512_CFLAGS := $(strip $(call cc-option,-mavx512vl -mavx512vbmi))
AUTO_AVX2_CFLAGS := $(strip $(call cc-option,-mavx2))
AUTO_AVX_CFLAGS := $(strip $(call cc-option,-mavx))
AUTO_SSE42_CFLAGS := $(strip $(call cc-option,-msse4.2))
AUTO_SSE41_CFLAGS := $(strip $(call cc-option,-msse4.1))
AUTO_SSSE3_CFLAGS := $(strip $(call cc-option,-mssse3))
else
AUTO_AVX512_CFLAGS :=
AUTO_AVX2_CFLAGS :=
AUTO_AVX_CFLAGS :=
AUTO_SSE42_CFLAGS :=
AUTO_SSE41_CFLAGS :=
AUTO_SSSE3_CFLAGS :=
endif

ifneq ($(origin B64_VERYFAST_NEON64_CFLAGS), undefined)
NEON64_CFLAGS := $(B64_VERYFAST_NEON64_CFLAGS)
else
NEON64_CFLAGS := $(AUTO_NEON64_CFLAGS)
endif
ifneq ($(origin B64_VERYFAST_NEON32_CFLAGS), undefined)
NEON32_CFLAGS := $(B64_VERYFAST_NEON32_CFLAGS)
else
NEON32_CFLAGS := $(AUTO_NEON32_CFLAGS)
endif
ifneq ($(origin B64_VERYFAST_AVX512_CFLAGS), undefined)
AVX512_CFLAGS := $(B64_VERYFAST_AVX512_CFLAGS)
else
AVX512_CFLAGS := $(AUTO_AVX512_CFLAGS)
endif
ifneq ($(origin B64_VERYFAST_AVX2_CFLAGS), undefined)
AVX2_CFLAGS := $(B64_VERYFAST_AVX2_CFLAGS)
else
AVX2_CFLAGS := $(AUTO_AVX2_CFLAGS)
endif
ifneq ($(origin B64_VERYFAST_AVX_CFLAGS), undefined)
AVX_CFLAGS := $(B64_VERYFAST_AVX_CFLAGS)
else
AVX_CFLAGS := $(AUTO_AVX_CFLAGS)
endif
ifneq ($(origin B64_VERYFAST_SSE42_CFLAGS), undefined)
SSE42_CFLAGS := $(B64_VERYFAST_SSE42_CFLAGS)
else
SSE42_CFLAGS := $(AUTO_SSE42_CFLAGS)
endif
ifneq ($(origin B64_VERYFAST_SSE41_CFLAGS), undefined)
SSE41_CFLAGS := $(B64_VERYFAST_SSE41_CFLAGS)
else
SSE41_CFLAGS := $(AUTO_SSE41_CFLAGS)
endif
ifneq ($(origin B64_VERYFAST_SSSE3_CFLAGS), undefined)
SSSE3_CFLAGS := $(B64_VERYFAST_SSSE3_CFLAGS)
else
SSSE3_CFLAGS := $(AUTO_SSSE3_CFLAGS)
endif

DEFAULT_DIRTY_THRESHOLD := 2097152U
ifneq ($(origin B64_VERYFAST_DIRTY_THRESHOLD), undefined)
DIRTY_THRESHOLD := $(B64_VERYFAST_DIRTY_THRESHOLD)
else
DIRTY_THRESHOLD := $(DEFAULT_DIRTY_THRESHOLD)
endif
DIRTY_THRESHOLD_CFLAGS := -DB64VERYFAST_DIRTY_THRESHOLD=$(DIRTY_THRESHOLD)

HAVE_AVX512 := $(if $(strip $(AVX512_CFLAGS)),1,0)
HAVE_AVX2 := $(if $(strip $(AVX2_CFLAGS)),1,0)
HAVE_NEON32 := $(if $(strip $(NEON32_CFLAGS)),1,0)
HAVE_NEON64 := $(if $(strip $(NEON64_CFLAGS)),1,0)
HAVE_SSSE3 := $(if $(strip $(SSSE3_CFLAGS)),1,0)
HAVE_SSE41 := $(if $(strip $(SSE41_CFLAGS)),1,0)
HAVE_SSE42 := $(if $(strip $(SSE42_CFLAGS)),1,0)
HAVE_AVX := $(if $(strip $(AVX_CFLAGS)),1,0)

ERL_INCLUDE ?= $(shell $(ERL) -noshell -eval 'io:format("~s", [filename:join([code:root_dir(), "erts-" ++ erlang:system_info(version), "include"])]), halt().')

CFLAGS += -std=c99 -O3 -Wall -Wextra -pedantic -DBASE64_STATIC_DEFINE -fPIC $(DIRTY_THRESHOLD_CFLAGS) $(B64_VERYFAST_CFLAGS)
NIF_CFLAGS += -Ic_src/aklomp/include -Ic_src/aklomp/lib -I$(ERL_INCLUDE)

ifeq ($(HOST_OS),Darwin)
SO_LDFLAGS ?= -bundle -undefined dynamic_lookup
else
SO_LDFLAGS ?= -shared
endif
SO_LDFLAGS += $(B64_VERYFAST_LDFLAGS)

AKLOMP_OBJS = \
  c_src/aklomp/lib/arch/avx512/codec.o \
  c_src/aklomp/lib/arch/avx2/codec.o \
  c_src/aklomp/lib/arch/generic/codec.o \
  c_src/aklomp/lib/arch/neon32/codec.o \
  c_src/aklomp/lib/arch/neon64/codec.o \
  c_src/aklomp/lib/arch/ssse3/codec.o \
  c_src/aklomp/lib/arch/sse41/codec.o \
  c_src/aklomp/lib/arch/sse42/codec.o \
  c_src/aklomp/lib/arch/avx/codec.o \
  c_src/aklomp/lib/lib.o \
  c_src/aklomp/lib/codec_choose.o \
  c_src/aklomp/lib/tables/tables.o

.PHONY: all clean print-config

all: priv/b64veryfast.so

print-config:
	@echo "HOST_ARCH=$(HOST_ARCH)"
	@echo "HOST_OS=$(HOST_OS)"
	@echo "NEON64_CFLAGS=$(NEON64_CFLAGS)"
	@echo "NEON32_CFLAGS=$(NEON32_CFLAGS)"
	@echo "AVX512_CFLAGS=$(AVX512_CFLAGS)"
	@echo "AVX2_CFLAGS=$(AVX2_CFLAGS)"
	@echo "AVX_CFLAGS=$(AVX_CFLAGS)"
	@echo "SSE42_CFLAGS=$(SSE42_CFLAGS)"
	@echo "SSE41_CFLAGS=$(SSE41_CFLAGS)"
	@echo "SSSE3_CFLAGS=$(SSSE3_CFLAGS)"
	@echo "DIRTY_THRESHOLD=$(DIRTY_THRESHOLD)"

priv/b64veryfast.so: c_src/b64veryfast.o $(AKLOMP_OBJS)
	mkdir -p priv
	$(CC) $(CFLAGS) $(SO_LDFLAGS) -o $@ $^

c_src/aklomp/lib/config.h:
	@echo "#define HAVE_AVX512 $(HAVE_AVX512)" > $@
	@echo "#define HAVE_AVX2   $(HAVE_AVX2)" >> $@
	@echo "#define HAVE_NEON32 $(HAVE_NEON32)" >> $@
	@echo "#define HAVE_NEON64 $(HAVE_NEON64)" >> $@
	@echo "#define HAVE_SSSE3  $(HAVE_SSSE3)" >> $@
	@echo "#define HAVE_SSE41  $(HAVE_SSE41)" >> $@
	@echo "#define HAVE_SSE42  $(HAVE_SSE42)" >> $@
	@echo "#define HAVE_AVX    $(HAVE_AVX)" >> $@

c_src/b64veryfast.o: CFLAGS += $(NIF_CFLAGS)
$(AKLOMP_OBJS): c_src/aklomp/lib/config.h
$(AKLOMP_OBJS): CFLAGS += -Ic_src/aklomp/lib
c_src/aklomp/lib/arch/avx512/codec.o: CFLAGS += $(AVX512_CFLAGS)
c_src/aklomp/lib/arch/avx2/codec.o: CFLAGS += $(AVX2_CFLAGS)
c_src/aklomp/lib/arch/neon32/codec.o: CFLAGS += $(NEON32_CFLAGS)
c_src/aklomp/lib/arch/neon64/codec.o: CFLAGS += $(NEON64_CFLAGS)
c_src/aklomp/lib/arch/ssse3/codec.o: CFLAGS += $(SSSE3_CFLAGS)
c_src/aklomp/lib/arch/sse41/codec.o: CFLAGS += $(SSE41_CFLAGS)
c_src/aklomp/lib/arch/sse42/codec.o: CFLAGS += $(SSE42_CFLAGS)
c_src/aklomp/lib/arch/avx/codec.o: CFLAGS += $(AVX_CFLAGS)

%.o: %.c
	$(CC) $(CFLAGS) -o $@ -c $<

clean:
	rm -rf priv
	rm -f c_src/b64veryfast.o c_src/aklomp/lib/config.h $(AKLOMP_OBJS)
