#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <errno.h>
#include <math.h>




/////////////////////////////////////////////////////////////////////////////
// timing constants

#define TIMER3_RATE (1000000.0 / 30.72)



/////////////////////////////////////////////////////////////////////////////
// frequency constants

//#define AMIGA_CLOCK_CONSTANT 3579545.0 // ntsc
#define AMIGA_CLOCK_CONSTANT 3546895.0 // pal

#define RF5C164_SAMPLE_RATE (12500000.0 / 384.0)
#define RF5C164_FD_DIVIDER 2048.0

// amiga_freq = AMIGA_CLOCK_CONSTANT / period
// rf5c164_freq = (fd / RF5C164_FD_DIVIDER) * RF5C164_SAMPLE_RATE

// amiga_period = AMIGA_CLOCK_CONSTANT / freq
// fd = (freq / RF5C164_SAMPLE_RATE) * RF5C164_FD_DIVIDER

// getting fd from amiga period:
// fd = ((AMIGA_CLOCK_CONSTANT / amiga_period) / RF5C164_SAMPLE_RATE) * RF5C164_FD_DIVIDER
// fd = this constant / amiga period
// 223,151.3382912
#define AMIGA2RF5C164_MAGIC_CONSTANT (AMIGA_CLOCK_CONSTANT / RF5C164_SAMPLE_RATE * RF5C164_FD_DIVIDER)
// amount of fractional bits we can fit into a 32 bit version of this number
#define AMIGA2RF5C164_MAGIC_CONSTANT_FRAC_BITS 14







///////////////////////////////////////////////////////////////////////////
// main

int main(int argc, char * argv[]) {
	if (argc != 2) {
		puts("args: out-file");
		return EXIT_FAILURE;
	}
	const char * out_name = argv[1];
	
	
	////////////////////////////////////////////
	// open output
	FILE * f = fopen(out_name,"w");
	if (!f) {
		printf("%s: %s\n", out_name, strerror(errno));
		return EXIT_FAILURE;
	}
	
	
	////////////////////////////////////////////
	// write amiga period -> sega cd magic constant
	// 68k divides this by amiga period
	// there is one entry for every possible arp note offset
	fprintf(f, "mpl_fd_magic_constant_tbl: dc.l ");
	for (unsigned n = 0; n < 16; n++) {
		if (n)
			fputc(',', f);
		fprintf(f, "%u", (unsigned)round(AMIGA2RF5C164_MAGIC_CONSTANT * exp2(n / 12.0)));
	}
	fputc('\n',f);
	
	
	/////////////////////////////////////////////
	// write finetune multiplier table
	// period * finetune table[finetune] = finetuned period
	fprintf(f, "mpl_finetune_tbl: dc.w ");
	for (unsigned fti = 0; fti < 0x10; fti++) {
		int ft = fti < 8 ? -fti : (0x10-fti);
		if (fti)
			fputc(',', f);
		double ftm = exp2(ft / (12.0 * 8.0));
		fprintf(f, "%u", (unsigned)round(ftm * (double)(1<<15)));
	}
	fputc('\n',f);
	
	
	/////////////////////////////////////////////
	// write tempo -> timer table
	// each entry is the timer3 reload value, then the amount of irqs between ticks
	// we do include the lower 0x20 entries, even though they are inaccessible by most mods
	// they MIGHT be used by an ultimate soundtracker module's tempo byte
	// (actually this is a little off for UST tempo values, but not enough to care)
	fprintf(f, "mpl_tempo_tbl: dc.b 0,0"); // avoid division by zero errors (also stop timer3)
	for (unsigned bpm = 1; bpm < 256; bpm++) {
		// in hz, 4 rows per beat, 6 ticks per row, 60 seconds per minute
		unsigned tick_rate = (bpm * 4 * 6) / 60;
		
		// best possible timer rate (if it were 16-bit, but it's only 8-bit)
		unsigned ideal_timer = round(TIMER3_RATE / tick_rate);
		
		// divide timer until we are in range
		unsigned timer = ideal_timer;
		unsigned irqs = 2; // is this really right..?
		while (timer > 255) {
			timer /= 2;
			irqs++;
		}
		
		fprintf(f, ", %u,%u", timer, irqs);
	}
	fputc('\n', f);
	
	
	/////////////////////////////////////////////
	// done
	fclose(f);
}



