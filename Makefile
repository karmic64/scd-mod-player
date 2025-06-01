ifdef COMSPEC
DOTEXE:=.exe
else
DOTEXE:=
endif

CFLAGS:=-Ofast -Wall -Wextra -Wpedantic
LDFLAGS:=-s
LDLIBS:=-lm

out/%$(DOTEXE): tool/%.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS) $(LDLIBS)


VASM:=vasmm68k_mot
VASM_FLAGS:=-m68000 -opt-speed -Isrc -Iinclude -Idata -Iout

# useless because vasm dies on includes it can't find, even when writing deps
#%.dep: %.asm
#	$(VASM) $(VASM_FLAGS) -depend=make -quiet -o $*.bin $< > $*.dep

out/%.bin: src/%.asm
	$(VASM) -Fbin $(VASM_FLAGS) -o $@ $<



.PHONY: default clean
default: out/a.iso
clean:
	$(RM) $(filter-out %.cue, $(wildcard out/*))



CD_FILES:=$(wildcard cd/*)


out/a.iso: out/system-area.bin cd $(CD_FILES) out/make-iso$(DOTEXE)
	out/make-iso --system-id MEGA_CD --volume-id SONIC_CD___ \
		--publisher-id 'SEGA ENTERPRISES' \
		--preparer-id 'SEGA ENTERPRISES' \
		--application-id 'SEGA ENTERPRISES' \
		--copyright CPY.TXT --abstract ABS.TXT --bibliographic BIB.TXT \
		--system-area $< -o $@ $(CD_FILES)

out/system-area.bin: out/main.bin out/sub.bin

out/main.bin: src/main.asm \
	src/main-sub-comms.asm \
	include/MD.I include/MAINCPU.INC include/gen.inc \
	data/security-j.bin data/security-u.bin data/security-e.bin \
	src/main-cd-access.asm src/cd-access-constants.asm \
	src/main-mod-visualizer.asm src/mod-player-constants.asm \
	out/main-palette.bin
out/sub.bin: src/sub.asm \
	src/main-sub-comms.asm \
	include/CDBIOS.I include/CDMAP.I \
	src/sub-cd-access.asm src/cd-access-constants.asm \
	src/sub-mod-player.asm src/mod-player-constants.asm \
	out/sub-mod-player-data.asm

out/main-palette.bin: out/make-palette$(DOTEXE)
	out/make-palette $@

out/sub-mod-player-data.asm: out/make-mod-player-data$(DOTEXE)
	out/make-mod-player-data $@





