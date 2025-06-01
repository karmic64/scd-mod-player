
	include cd-access-constants.asm
	
CDA_WAIT_COUNT = $ffff
CDA_RETRY_COUNT = 6


	;this routine EXITS EARLY if not
cda_is_directory_valid
	addq.l #4,sp
	
	btst.b #6,_cdstat
	bne cda_tray_open
	btst.b #S_FLAG_CD_OK,s_flags
	beq cda_no_valid_directory
	
	subq.l #4,sp
	rts




cda_tray_open:
	moveq #ERR_CDA_TRAY_OPEN,d0
	rts
cda_read_error:
	moveq #ERR_CDA_READ_ERROR,d0
	rts
cda_no_valid_directory:
	moveq #ERR_CDA_NO_VALID_DIRECTORY,d0
	rts
cda_directory_too_large:
	moveq #ERR_CDA_DIRECTORY_TOO_LARGE,d0
	rts
cda_too_many_files:
	moveq #ERR_CDA_TOO_MANY_FILES,d0
	rts
cda_no_such_file:
	moveq #ERR_CDA_NO_SUCH_FILE,d0
	rts


	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;
	;;
	;;
	
	
	;d0 - file id in directory
	;a0 - destination address
cda_load_file
	bsr cda_is_directory_valid
	
	cmp.l w_cda_dir_files,d0
	bhs cda_no_such_file
	
	lsl.l #2,d0
	lea w_cda_dir_index,a2
	move.l (a2,d0.l),d2
	
	lea w_cda_directory,a2
	move.l de_extent(a2,d2.l),d0
	move.l de_size(a2,d2.l),d1
	
	;; fall through...
	
	
	;d0 - start sector
	;d1 - bytes to read
cda_read_bytes
	move.l d1,d2
	moveq #CDA_SECTOR_SHIFT,d3
	lsr.l d3,d1
	and.w #CDA_SECTOR_MASK,d2
	beq .no_dir_size_up
	addq.l #1,d1
.no_dir_size_up
	
	;; fall through...
	
	;in:
	;d0 - start sector
	;d1 - sectors to read
	;a0 - data destination
	;a1 - header destination
cda_read_sectors:
	;save d6-d7/a2-a3, and set up a stack frame with d0-d1
	movem.l d0-d1/d6-d7/a2-a3,-(sp)
	movea.l a0,a2
	movea.l a1,a3
	
	move.b #SUBREAD,_cdcmode
	
.retry_reload
	move.w #CDA_RETRY_COUNT,d7
	bra .first_try
.retry
	subq.w #1,d7
	beq .read_error
.first_try
	movea.l sp,a0
	move.w #ROMREADN,d0
	jsr _cdbios
	
.loop_reload
	move.w #CDA_WAIT_COUNT,d6
	bra .first_loop
.loop
	subq.w #1,d6
	beq .read_error
.first_loop
	move.w #CDCSTAT,d0
	jsr _cdbios
	bcs .loop
	
	move.w #CDCREAD,d0
	jsr _cdbios
	bcs .retry
	
	movea.l a2,a0
	;movea.l a3,a1
	lea .header(pc),a1
	move.w #CDCTRN,d0
	jsr _cdbios
	bcs .retry
	movea.l a0,a2
	movea.l a1,a3
	
	move.w #CDCACK,d0
	jsr _cdbios
	
	move.w #CDA_RETRY_COUNT,d7
	addq.l #1,0(sp)
	subq.l #1,4(sp)
	bne .loop_reload
	
	movem.l (sp)+,d0-d1/d6-d7/a2-a3
	moveq #ERR_OK,d0
	rts
	
.read_error
	move.w #CDCSTOP,d0
	jsr _cdbios
	movem.l (sp)+,d0-d1/d6-d7/a2-a3
	bra cda_read_error
	
.header
	dc.l 0
	
	
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;
	;;
	;;
	;;
	;;
	;;
	
	;this routine will only reload the directory if disk was ejected
cda_read_root_directory
	lea s_flags,a2
	btst.b #S_FLAG_CD_OK,(a2) ;already loaded?
	bne .all_ok
	btst.b #S_FLAG_CD_READ,(a2) ;already known to be invalid?
	bne cda_no_valid_directory
	
	btst.b #6,_cdstat
	bne cda_tray_open
	
	bset.b #S_FLAG_CD_READ,(a2)
	lea w_cda_pvd,a6
	
	;;;;;;;;;;;;;;;;;;; try finding the primary volume descriptor
	
	moveq #16,d7 ;current sector
.look_pvd_loop
	movea.l a6,a0
	move.l d7,d0
	moveq #1,d1
	bsr cda_read_sectors
	addq.l #1,d7
	
	cmp.b #'C',vd_id(a6) ;make sure the "CD001" is valid
	bne cda_no_valid_directory
	cmp.l #'D001',vd_id+1(a6)
	bne cda_no_valid_directory
	
	cmp.b #$ff,vd_type(a6) ;already over?
	beq cda_no_valid_directory
	cmp.b #$01,vd_type(a6) ;found what we're looking for?
	bne .look_pvd_loop
	
	;;;;;;;;;;;;;;;;;; try loading the root directory
	
	lea w_cda_directory,a5
	move.l pvd_root+de_extent(a6),d0
	move.l pvd_root+de_size(a6),d1
	cmp.l #CDA_MAX_DIR_SIZE,d1
	bhi cda_directory_too_large
	move.l d1,d5
	movea.l a5,a0
	bsr cda_read_bytes
	tst.w d0
	bne .exit
	
	;;;;;;;;;;;;;;;;;; index dir files
	
	lea w_cda_dir_index,a4
	moveq #0,d7 ;current dir index
	moveq #0,d6 ;current number of files
	;d5 is still the directory size in bytes
	moveq #0,d0
.index_dir_loop
	cmp.l d5,d7 ;read all?
	bhs .index_dir_done
	
	lea (a5,d7.l),a0 ;get current record pointer
	
	move.b de_length(a0),d0 ;length is 0, assuming next entry can't fit in this sector
	beq .index_dir_next_sector
	
	btst.b #1,de_flags(a0) ;we don't care about directories
	bne .index_dir_next
	
	cmp.l #CDA_MAX_FILES,d6 ;too many files?
	bhi cda_too_many_files
	
	move.l d7,(a4)+ ;log this index
	addq.l #1,d6
	
.index_dir_next
	
	add.l d0,d7 ;normal length, advance
	bra .index_dir_loop
	
.index_dir_next_sector
	and.l #~CDA_SECTOR_MASK,d7
	add.l #CDA_SECTOR_SIZE,d7
	bra .index_dir_loop
	
.index_dir_done
	move.l d6,w_cda_dir_files
	
	bset.b #S_FLAG_CD_OK,s_flags
	
.all_ok
	moveq #ERR_OK,d0
.exit
	rts
	
	
	
	
	
	
	
	
	
	
	
	
	
	