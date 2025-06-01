#include <stdlib.h>
#include <stdio.h>
#include <math.h>

int main(int argc, char * argv[]) {
	if (argc != 2) {
		puts("usage: make-palette outfile");
		return EXIT_FAILURE;
	}
	
	FILE * f = fopen(argv[1], "wb");
	if (!f) {
		perror(NULL);
		return EXIT_FAILURE;
	}
	
	const unsigned char value_tbl[4] = {0x0f, 0x0c, 0x08, 0x05};
	
	for (unsigned ci = 0; ci < 0x40; ci++) {
		unsigned pi = (ci >> 4);
		unsigned pci = (ci & 0x0f);
		
		if (pci == 0 || pci == 2) {	// always black
			fputc(0, f);
			fputc(0, f);
		} else if (pci == 1) { // desaturated (grayscale)
			unsigned v = value_tbl[pi];
			fputc(v, f);
			fputc(v | (v<<4), f);
		} else { // color
			double value = value_tbl[pi] / 15.0;
			
			double hue = (pci - 3) / (16.0 - 3.0) * 6.0;
			double hue_if;
			double hue_f = modf(hue, &hue_if);
			int hue_i = hue_if;
			if (hue_i % 2)
				hue_f = 1.0 - hue_f;
			hue_f *= value;
			
			double r;
			double g;
			double b;
			switch (hue_i) {
				case 0:
					r = value;
					g = hue_f;
					b = 0.0;
					break;
				case 1:
					r = hue_f;
					g = value;
					b = 0.0;
					break;
				case 2:
					r = 0.0;
					g = value;
					b = hue_f;
					break;
				case 3:
					r = 0.0;
					g = hue_f;
					b = value;
					break;
				case 4:
					r = hue_f;
					g = 0.0;
					b = value;
					break;
				case 5:
					r = value;
					g = 0.0;
					b = hue_f;
					break;
			}
			
			unsigned ri = trunc(r * 15.999);
			unsigned gi = trunc(g * 15.999);
			unsigned bi = trunc(b * 15.999);
			
			fputc(bi, f);
			fputc(ri | (gi << 4), f);
		}
	}
	
	fclose(f);
	
	return EXIT_SUCCESS;
}