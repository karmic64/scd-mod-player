CDA_SECTOR_SIZE = $800
CDA_SECTOR_MASK = $7ff
CDA_SECTOR_SHIFT = 11

CDA_MAX_DIR_SIZE = $20000
CDA_MAX_DIR_SECTORS = CDA_MAX_DIR_SIZE/CDA_SECTOR_SIZE
CDA_MAX_FILES = CDA_MAX_DIR_SIZE/$30



	;;;;; directory entry struct
	clrso
de_length	so.b 1
de_extlen	so.b 1
	so.l 1
de_extent so.l 1
	so.l 1
de_size so.l 1
de_date so.b 7
de_flags so.b 1
de_unit_size so.b 1
de_interleave_gap so.b 1
	so.w 1
de_volume_seq_num so.w 1
de_name_length so.b 1
de_name so.b 0


	;;;;; volume descriptor struct
	clrso
vd_type	so.b 1
vd_id	so.b 5
vd_version	so.b 1
vd_SIZEOF	so.b 0
	
	
	;;;;; primary volume descriptor struct
	setso vd_SIZEOF
	so.b 1
pvd_system_id	so.b 32
pvd_volume_id	so.b 32
	so.b 8
	so.l 1
pvd_volume_size	so.l 1
	so.b 32
	so.w 1
pvd_volume_set_size	so.w 1
	so.w 1
pvd_volume_seq_num	so.w 1
	so.w 1
pvd_logical_block_size	so.w 1
	so.l 1
pvd_path_table_size	so.l 1
	so.l 1
	so.l 1
pvd_path_table_location	so.l 1
pvd_optional_path_table_location	so.l 1
pvd_root	so.b 34
pvd_volume_set_id	so.b 128
pvd_publisher_id	so.b 128
pvd_preparer_id	so.b 128
pvd_application_id	so.b 128
pvd_copyright	so.b 37
pvd_abstract	so.b 37
pvd_bibliographic	so.b 37
pvd_creation	so.b 17
pvd_modification	so.b 17
pvd_expiration	so.b 17
pvd_effective	so.b 17
pvd_fs_version	so.b 1
