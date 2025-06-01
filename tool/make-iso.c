#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <errno.h>
#include <sys/stat.h>
#include <time.h>
#include <getopt.h>


void fputc_times(int c, FILE * f, size_t n) {
	for (size_t i = 0; i < n; i++)
		fputc(c, f);
}



////////////////////////////////////////////////////////////////////////////
// cd-rom defines

#define CD_SECTOR_SIZE 0x800
#define CD_SYSTEM_AREA_SECTORS 16
#define CD_SYSTEM_AREA_SIZE (CD_SECTOR_SIZE * CD_SYSTEM_AREA_SECTORS)

// given an offset, get amount of bytes to align to next sector
size_t align_length(size_t offs) {
	size_t mod = offs % CD_SECTOR_SIZE;
	if (mod)
		return CD_SECTOR_SIZE - mod;
	return 0;
}

// given an offset, align to the next sector
size_t align(size_t offs) {
	return offs + align_length(offs);
}

// returns 1 if a size-byte block at offset offs would cross sector boundary
int crosses_sector(size_t offs, size_t size) {
	if (!size)
		return 0;
	
	size_t current = offs / CD_SECTOR_SIZE;
	size_t next = (offs + size - 1) / CD_SECTOR_SIZE;
	
	return current != next;
}




///////////////////////////////////////////////////////////////////////////
// iso-9660 basic data types

void fput16_little(unsigned v, FILE * f) {
	fputc(v>>0, f);
	fputc(v>>8, f);
}
void fput32_little(unsigned v, FILE * f) {
	fputc(v>>0, f);
	fputc(v>>8, f);
	fputc(v>>16, f);
	fputc(v>>24, f);
}

void fput16_big(unsigned v, FILE * f) {
	fputc(v>>8, f);
	fputc(v>>0, f);
}
void fput32_big(unsigned v, FILE * f) {
	fputc(v>>24, f);
	fputc(v>>16, f);
	fputc(v>>8, f);
	fputc(v>>0, f);
}

void fput16_both(unsigned v, FILE * f) {
	fput16_little(v,f);
	fput16_big(v,f);
}
void fput32_both(unsigned v, FILE * f) {
	fput32_little(v,f);
	fput32_big(v,f);
}

// having this makes it easy to reuse the same code to write
// the path table, which must exist twice for both endiannesses
enum {
	FMT_LITTLE,
	FMT_BIG,
	FMT_BOTH,
};
void fput16n(unsigned v, FILE * f, int fmt) {
	switch (fmt) {
		case FMT_LITTLE:
			fput16_little(v,f);
			break;
		case FMT_BIG:
			fput16_big(v,f);
			break;
		case FMT_BOTH:
			fput16_both(v,f);
			break;
	}
}
void fput32n(unsigned v, FILE * f, int fmt) {
	switch (fmt) {
		case FMT_LITTLE:
			fput32_little(v,f);
			break;
		case FMT_BIG:
			fput32_big(v,f);
			break;
		case FMT_BOTH:
			fput32_both(v,f);
			break;
	}
}


// note, no attempt is made to limit characters
void fputs_padded(const char * s, FILE * f, size_t max) {
	int over = s ? 0 : 1;
	for (size_t i = 0; i < max; i++) {
		if (!over && *s == '\0')
			over = 1;
		
		if (over)
			fputc(' ',f);
		else
			fputc(*(s++),f);
	}
}


void fput_dectime(const time_t * time, FILE * f) {
	if (time) {
		struct tm * tm = gmtime(time);
		fprintf(f, "%04d%02d%02d%02d%02d%02d"
			,tm->tm_year+1900
			,tm->tm_mon+1
			,tm->tm_mday
			,tm->tm_hour
			,tm->tm_min
			,tm->tm_sec
			);
	} else {
		fputc_times('0', f, 14);
	}
	fputc('0', f); // we do not support hundredths of a second
	fputc('0', f);
	fputc(0, f); // we do not support timezone offsets
}

void fput_dirtime(const time_t * time, FILE * f) {
	if (time) {
		struct tm * tm = gmtime(time);
		fputc(tm->tm_year, f);
		fputc(tm->tm_mon+1, f);
		fputc(tm->tm_mday, f);
		fputc(tm->tm_hour, f);
		fputc(tm->tm_min, f);
		fputc(tm->tm_sec, f);
	} else {
		fputc_times(0, f, 6);
	}
	fputc(0, f); // we do not support timezone offsets
}





/////////////////////////////////////////////////////////////////////////
// path table

#define PATH_TABLE_SIZE 10

void fput_path_table(FILE * f, int fmt, unsigned extent) {
	fputc(1, f); // identifier length
	fputc(0, f); // extended attribute record length
	fput32n(extent, f, fmt);
	fput16n(1, f, fmt); // index of parent directory
	fputc(0, f); // identifier
	fputc(0, f); // padding
}







//////////////////////////////////////////////////////////////////////////
// directory

#define DIR_RECORD_MAX_NAME_LEN (255-33)

typedef struct {
	const char * path; // if NULL, is a directory
	
	uint32_t size; // size in bytes
	time_t time; // recording time
	size_t name_len; // the name that will be written to disk
	char name[DIR_RECORD_MAX_NAME_LEN+1]; // +1 to allow null
} dir_record_t;

int dir_record_cmp(const void * a, const void * b) {
	const dir_record_t * aa = (const dir_record_t *)a;
	const dir_record_t * bb = (const dir_record_t *)b;
	
	return strcasecmp(aa->name, bb->name);
}

// gets size of a record, if it would be written to iso
size_t get_dir_record_size(const dir_record_t * rec) {
	size_t s = rec->name_len + 33;
	if (s % 2)
		s++;
	return s;
}


void fput_dir_record(const dir_record_t * rec, FILE * f, unsigned extent, unsigned volume_seq_num) {
	fputc(get_dir_record_size(rec), f);
	fputc(0, f); // extended attribute record length
	fput32_both(extent, f);
	fput32_both(rec->size, f);
	fput_dirtime(&rec->time, f);
	fputc(rec->path ? 0x00 : 0x02, f); // file flags (dir or not?)
	fputc(0, f); // interleave file unit size
	fputc(0, f); // interleave gap size
	fput16_both(volume_seq_num, f);
	fputc(rec->name_len, f);
	fwrite(rec->name, 1, rec->name_len % 2 ? rec->name_len : rec->name_len+1, f);
}







////////////////////////////////////////////////////////////////////////////
// main

enum {
	OPT_SYSTEM_AREA = 0,
	
	OPT_SYSTEM_ID,
	OPT_VOLUME_ID,
	OPT_VOLUME_SET_SIZE,
	OPT_VOLUME_SEQ_NUM,
	OPT_VOLUME_SET_ID,
	OPT_PUBLISHER_ID,
	OPT_PREPARER_ID,
	OPT_APPLICATION_ID,
	OPT_COPYRIGHT,
	OPT_ABSTRACT,
	OPT_BIBLIOGRAPHIC,
	
	OPT_OUTPUT_FILE = 'o',
};

const char short_opts[] = "o:";

const struct option long_opts[] = {
	{"system-area", required_argument, NULL, OPT_SYSTEM_AREA},
	
	{"system-id", required_argument, NULL, OPT_SYSTEM_ID},
	{"volume-id", required_argument, NULL, OPT_VOLUME_ID},
	{"volume-set-size", required_argument, NULL, OPT_VOLUME_SET_SIZE},
	{"volume-seq-num", required_argument, NULL, OPT_VOLUME_SEQ_NUM},
	{"volume-set-id", required_argument, NULL, OPT_VOLUME_SET_ID},
	{"publisher-id", required_argument, NULL, OPT_PUBLISHER_ID},
	{"preparer-id", required_argument, NULL, OPT_PREPARER_ID},
	{"application-id", required_argument, NULL, OPT_APPLICATION_ID},
	{"copyright", required_argument, NULL, OPT_COPYRIGHT},
	{"abstract", required_argument, NULL, OPT_ABSTRACT},
	{"bibliographic", required_argument, NULL, OPT_BIBLIOGRAPHIC},
	
	{0,0,0,0}
};

int main(int argc, char * argv[]) {
	time_t current_time = time(NULL);
	
	////////////////////////////////// parse command line
	const char * system_area_filename = NULL;
	
	const char * system_id = NULL;
	const char * volume_id = NULL;
	unsigned volume_set_size = 1;
	unsigned volume_seq_num = 1;
	const char * volume_set_id = NULL;
	const char * publisher_id = NULL;
	const char * preparer_id = NULL;
	const char * application_id = NULL;
	const char * copyright_filename = NULL;
	const char * abstract_filename = NULL;
	const char * bibliographic_filename = NULL;
	
	const char * out_filename = NULL;
	
	while (1) {
		int opt_index = 0;
		int c = getopt_long(argc, argv, short_opts, long_opts, &opt_index);
		if (c == -1)
			break;
		
		switch (c) {
			case OPT_SYSTEM_AREA:
				system_area_filename = optarg;
				break;
			
			case OPT_SYSTEM_ID:
				system_id = optarg;
				break;
			case OPT_VOLUME_ID:
				volume_id = optarg;
				break;
			case OPT_VOLUME_SET_SIZE:
				volume_set_size = strtoul(optarg, NULL, 0);
				break;
			case OPT_VOLUME_SEQ_NUM:
				volume_seq_num = strtoul(optarg, NULL, 0);
				break;
			case OPT_VOLUME_SET_ID:
				volume_set_id = optarg;
				break;
			case OPT_PUBLISHER_ID:
				publisher_id = optarg;
				break;
			case OPT_PREPARER_ID:
				preparer_id = optarg;
				break;
			case OPT_APPLICATION_ID:
				application_id = optarg;
				break;
			case OPT_COPYRIGHT:
				copyright_filename = optarg;
				break;
			case OPT_ABSTRACT:
				abstract_filename = optarg;
				break;
			case OPT_BIBLIOGRAPHIC:
				bibliographic_filename = optarg;
				break;
			
			case OPT_OUTPUT_FILE:
				out_filename = optarg;
				break;
			
			default:
				return EXIT_FAILURE;
		}
	}
	
	int first_file_arg = optind;
	int amt_file_args = argc - optind;
	
	
	
	
	
	
	////////////////////////////////// create directory entries
	
	size_t dir_record_cnt = amt_file_args + 2;
	dir_record_t * dir_records = malloc(sizeof(dir_record_t) * dir_record_cnt);
	
	////// set up the special "." and ".." entries
	
	dir_records[0].path = NULL;
	dir_records[0].size = 0;
	dir_records[0].time = current_time;
	dir_records[0].name_len = 1;
	dir_records[0].name[0] = '\0';
	dir_records[0].name[1] = '\0';
	
	dir_records[1].path = NULL;
	dir_records[1].size = 0;
	dir_records[1].time = current_time;
	dir_records[1].name_len = 1;
	dir_records[1].name[0] = '\1';
	dir_records[1].name[1] = '\0';
	
	////// make the actual file entries
	
	int fails = 0;
	for (int argi = first_file_arg; argi < argc; argi++) {
		unsigned diri = argi - first_file_arg + 2;
		
		const char * path = argv[argi];
		dir_record_t * rec = &dir_records[diri];
		
		struct stat st;
		if (stat(path, &st)) {
			printf("can't stat %s: %s\n", path, strerror(errno));
			fails++;
			continue;
		}
		if (!S_ISREG(st.st_mode)) {
			printf("%s is not a regular file\n", path);
			fails++;
			continue;
		}
		
		rec->path = path;
		rec->size = st.st_size;
		rec->time = st.st_mtime;
		
		size_t path_len = 0;
		const char * name = path;
		char c;
		while ((c = path[path_len]) != '\0') {
			path_len++;
			if (c == '/' || c == '\\') {
				name = &path[path_len];
			}
		}
		
		size_t name_len = (path+path_len) - name;
		if (!name_len) {
			printf("%s has no name\n", path);
			fails++;
			continue;
		}
		if (name_len > DIR_RECORD_MAX_NAME_LEN-2) {
			printf("%s has too long name\n", path);
			fails++;
			continue;
		}
		
		rec->name_len = name_len+2;
		memcpy(&rec->name[0], name, name_len);
		memcpy(&rec->name[name_len], ";1", 3);
	}
	if (fails)
		return EXIT_FAILURE;
	
	////// sort directory
	
	qsort(dir_records, dir_record_cnt, sizeof(*dir_records), dir_record_cmp);
	
	////// make a dry run through the directory to get its size on disk
	// while we're doing that, also get the total file data area size
	
	size_t file_area_size = 0;
	size_t dir_size = 0;
	for (size_t diri = 0; diri < dir_record_cnt; diri++) {
		dir_record_t * rec = &dir_records[diri];
		
		size_t size = get_dir_record_size(rec);
		if (crosses_sector(dir_size, size))
			dir_size = align(dir_size);
		dir_size += size;
		
		if (rec->path) {
			file_area_size = align(file_area_size + rec->size);
		}
	}
	dir_records[0].size = dir_size;
	dir_records[1].size = dir_size;
	
	
	
	
	
	////////////////////////////////// open output iso image
	
	int status = EXIT_SUCCESS;
	
	FILE * f = NULL;
	FILE * isof = fopen(out_filename, "wb");
	if (!isof) {
		printf("%s: %s\n", out_filename, strerror(errno));
		return EXIT_FAILURE;
	}
	
	
	////////////////////////////////// write system area
	
	if (system_area_filename) {
		f = fopen(system_area_filename, "rb");
		if (!f) {
			printf("%s: %s\n", out_filename, strerror(errno));
			status = EXIT_FAILURE;
			goto done;
		} else {
			for (size_t i = 0; i < CD_SYSTEM_AREA_SIZE; i++) {
				int c = fgetc(f);
				if (c == EOF) {
					if (ferror(f)) {
						printf("%s read: %s\n", out_filename, strerror(errno));
						status = EXIT_FAILURE;
						goto done;
					}
					break;
				}
				fputc(c, isof);
			}
			
			fclose(f);
			f = NULL;
		}
	}
	fseek(isof, CD_SYSTEM_AREA_SIZE, SEEK_SET);
	
	
	///////////////////////////////// write primary volume descriptor
	
	size_t dir_start = CD_SYSTEM_AREA_SIZE + (4*0x800);
	size_t file_area_start = dir_start + align(dir_size);
	size_t disc_size = file_area_start + align(file_area_size);
	
	fputc(0x01, isof); // type
	fwrite("CD001", 1, 5, isof);
	fputc(0x01, isof); // version
	fputc(0, isof); // unused
	
	fputs_padded(system_id, isof, 32);
	fputs_padded(volume_id, isof, 32);
	fputc_times(0, isof, 8);
	
	fput32_both(disc_size / CD_SECTOR_SIZE, isof);
	fputc_times(0, isof, 32);
	
	fput16_both(volume_set_size, isof);
	fput16_both(volume_seq_num, isof);
	
	fput16_both(CD_SECTOR_SIZE, isof);
	
	fput32_both(PATH_TABLE_SIZE, isof); // path table size
	fput32_little(CD_SYSTEM_AREA_SECTORS + 2, isof); // type-l path table LBA
	fput32_little(0, isof); // optional type-l path table LBA
	fput32_big(CD_SYSTEM_AREA_SECTORS + 3, isof); // type-m path table LBA
	fput32_big(0, isof); // optional type-m path table LBA
	
	fput_dir_record(&dir_records[0], isof, dir_start / CD_SECTOR_SIZE, volume_seq_num); // root directory record
	
	fputs_padded(volume_set_id, isof, 128);
	fputs_padded(publisher_id, isof, 128);
	fputs_padded(preparer_id, isof, 128);
	fputs_padded(application_id, isof, 128);
	
	fputs_padded(copyright_filename, isof, 37);
	fputs_padded(abstract_filename, isof, 37);
	fputs_padded(bibliographic_filename, isof, 37);
	
	fput_dectime(&current_time, isof); // creation time
	fput_dectime(&current_time, isof); // modification time
	fput_dectime(NULL, isof); // expiration time
	fput_dectime(NULL, isof); // effective time
	
	fputc(0x01, isof); // directory/path table version
	
	fseek(isof, align_length(ftell(isof)), SEEK_CUR);
	
	
	////////////////////////////////// write descriptor set terminator
	
	fputc(255, isof); // type
	fwrite("CD001", 1, 5, isof);
	fputc(0x01, isof); // version
	
	fseek(isof, align_length(ftell(isof)), SEEK_CUR);
	
	
	////////////////////////////////// write path tables
	
	fput_path_table(isof, FMT_LITTLE, CD_SYSTEM_AREA_SECTORS + 4);
	fseek(isof, align_length(ftell(isof)), SEEK_CUR);
	
	fput_path_table(isof, FMT_BIG, CD_SYSTEM_AREA_SECTORS + 4);
	fseek(isof, align_length(ftell(isof)), SEEK_CUR);
	
	
	////////////////////////////////// write directories
	
	size_t dir_offs = dir_start;
	size_t file_data_offs = file_area_start;
	
	for (size_t diri = 0; diri < dir_record_cnt; diri++) {
		dir_record_t * rec = &dir_records[diri];
		size_t size = get_dir_record_size(rec);
		
		if (crosses_sector(dir_offs, size)) {
			size_t alength = align_length(dir_offs);
			dir_offs += alength;
			fseek(isof, alength, SEEK_CUR);
		}
		
		fput_dir_record(rec, isof,
			(rec->path ? file_data_offs : dir_start) / CD_SECTOR_SIZE
			, volume_seq_num);
		dir_offs += size;
		
		if (rec->path) {
			file_data_offs = align(file_data_offs + rec->size);
		}
	}
	
	
	/////////////////////////////////// write files
	
	file_data_offs = file_area_start;
	
	for (size_t diri = 0; diri < dir_record_cnt; diri++) {
		fseek(isof, file_data_offs, SEEK_SET);
		
		dir_record_t * rec = &dir_records[diri];
		const char * path = rec->path;
		size_t size = rec->size;
		
		if (path) {
			f = fopen(path, "rb");
			if (!f) {
				printf("%s: %s\n", out_filename, strerror(errno));
				status = EXIT_FAILURE;
				goto done;
			}
			
			for (size_t i = 0; i < size; i++) {
				int c = fgetc(f);
				if (c == EOF) {
					if (ferror(f)) {
						printf("%s: %s\n", out_filename, strerror(errno));
					} else {
						printf("%s: premature EOF\n", out_filename);
					}
					
					status = EXIT_FAILURE;
					goto done;
				}
				fputc(c, isof);
			}
			
			fclose(f);
			f = NULL;
			
			file_data_offs = align(file_data_offs + size);
		}
	}
	
	
	////////////////////////////////// done	
	
	fputc_times(0, isof, disc_size-ftell(isof));
	
done:
	if (f)
		fclose(f);
	if (isof)
		fclose(isof);
	
	return status;
}

