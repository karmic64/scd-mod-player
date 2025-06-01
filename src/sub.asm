	include CDBIOS.I
	include CDMAP.I
	
	include main-sub-comms.asm
	
	org $6000
_header
	dc.b "MAIN SPSAMP",0
	dc.w $0100,0
	dc.l 0
	dc.l _end-_header
	dc.l _start-_header
	dc.l 0
_start
	dc.w usercall0-_start
	dc.w usercall1-_start
	dc.w usercall2-_start
	dc.w 0
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; includes
	
	include sub-cd-access.asm
	include sub-mod-player.asm
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; initialization
	
usercall0
	bclr.b #MODE,_memory ;we always use 2m mode
	
	lea sub_flug,a0 ;init comm flags
	moveq #0,d0
	move.b d0,(a0)+
	lea status_0-sub_flug+1(a0),a0
	move.l d0,(a0)+
	move.l d0,(a0)+
	move.l d0,(a0)+
	move.l d0,(a0)+
	
	bsr mpl_reset
	
.wait_main_ready
	cmp.l #M_READY_VALUE,m_ready
	bne .wait_main_ready
	
	rts
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; main
	
usercall1
	
	
.wait_cmd_loop
	btst.b #COMM_REQ,main_flug ;main-cpu wants to execute a command?
	beq .wait_cmd_loop
	
	;; ok, time to execute!
	bset.b #COMM_BUSY,sub_flug
	move.w m_cmd,d0
	lsl.w #2,d0
	jsr .cmd_tbl(pc,d0.w)
	
	move.w d0,s_cmd_status ;set status
	bset.b #RET,_memory ;give word-ram back
	
	;; let maincpu know we're done
	lea sub_flug,a0
	move.b (a0),d0
	bclr #COMM_BUSY,d0
	bset #COMM_ACK,d0
	move.b d0,(a0)
	
	;; wait until maincpu knows
.wait_main_ack_loop
	btst.b #COMM_ACK,main_flug
	beq .wait_main_ack_loop
	
	;; ok, we're done here
	bclr.b #COMM_ACK,(a0)
	
	bra .wait_cmd_loop
	
	
	
	
	
.cmd_tbl
	bra.w cmd_m_load_root_directory
	bra.w cmd_m_load_module
	bra.w cmd_m_start_module
	bra.w cmd_m_get_module_info
	bra.w cmd_m_get_pattern
	
	
	
	
	
	;;;;; reload directory, if needed
	
cmd_m_load_root_directory
	jmp cda_read_root_directory
	
	
	
	
	
	
	
	;;;;; load a module from disc
cmd_m_load_module
	bsr mpl_reset
	clr.l mpl_ram+mpl_module_base_ptr
	
	lea _end,a0
	moveq #0,d0
	move.w command_2,d0
	bsr wait_dmna
	jsr cda_load_file
	tst.w d0
	bne .got_status
	
	lea _end,a0
	jmp mpl_load
.got_status
	rts
	
	
	
	;;;;; start module playback
cmd_m_start_module
	tst.l mpl_ram+mpl_module_base_ptr
	beq no_module
	jsr mpl_init
	moveq #ERR_OK,d0
	rts
	
no_module
	moveq #ERR_MPL_NO_MODULE,d0
	rts
	
	
	;;;;; load module info to word-ram
cmd_m_get_module_info
	lea mpl_ram,a6
	tst.l mpl_module_base_ptr(a6)
	beq no_module
	lea w_mpl_module_info,a5
	
	bsr wait_dmna
	
	;; song title
	movea.l mpl_song_title_ptr(a6),a0
	move.l (a0)+,(a5)+ ;4
	move.l (a0)+,(a5)+ ;8
	move.l (a0)+,(a5)+ ;12
	move.l (a0)+,(a5)+ ;16
	move.l (a0)+,(a5)+ ;20
	
	;; others
	move.b mpl_amt_channels(a6),(a5)+
	move.b mpl_amt_samples(a6),d5
	move.b d5,(a5)+
	
	;; samples
	moveq #0,d7
	moveq #MPL_MAX_SAMPLES,d6
	movea.l mpl_samples_ptr(a6),a0
	lea mpl_samples(a6),a1
	lea mpl_sample_size(a1),a1
.sample_loop
	cmp.b d7,d5
	bhs .sample_exists
	
	clr.l (a5)+ ;4
	clr.l (a5)+ ;8
	clr.l (a5)+ ;12
	clr.l (a5)+ ;16
	clr.l (a5)+ ;20
	clr.l (a5)+ ;22/size high word
	clr.w (a5)+ ;size low word
	bra .sample_next
	
.sample_exists
	
	move.l (a0)+,(a5)+ ;4
	move.l (a0)+,(a5)+ ;8
	move.l (a0)+,(a5)+ ;12
	move.l (a0)+,(a5)+ ;16
	move.l (a0)+,(a5)+ ;20
	move.w (a0)+,(a5)+ ;22
	
	move.l (a1),(a5)+ ;size
	
	lea mpl_mod_sample_SIZEOF-22(a0),a0
	lea mpl_sample_SIZEOF(a1),a1
	
.sample_next
	addq.b #1,d7
	cmp.b d6,d7
	blo .sample_loop
	
	;; orderlist
	movea.l mpl_orderlist_ptr(a6),a0
	move.w -2(a0),(a5)+ ;song length
	
	moveq #(MPL_ORDERLIST_SIZE/4)-1,d7
.orderlist_loop
	move.l (a0)+,(a5)+
	dbra d7,.orderlist_loop
	
	moveq #ERR_OK,d0
	rts
	
	
	
	
	;;;;; transfer a pattern to word-ram
cmd_m_get_pattern
	
	lea mpl_ram,a6
	tst.l mpl_module_base_ptr(a6)
	beq no_module
	
	move.w command_2,d0 ;which pattern do we want
	
	moveq #0,d1 ;amount of "cells" per pattern
	move.b mpl_amt_channels(a6),d1
	mulu.w #MPL_PATTERN_ROWS,d1
	
	movea.l mpl_patterns_ptr(a6),a0 ;pattern address
	mulu.w d1,d0
	lsl.l #2,d0
	add.l d0,a0
	
	;; now start copying!
	subq.w #1,d1
	lea w_mpl_pattern,a1
	bsr wait_dmna
.xfer_loop
	move.l (a0)+,(a1)+
	dbra d1,.xfer_loop
	
	moveq #ERR_OK,d0
	rts
	
	
	
	
	
	
	
	
	
	;;;; waits until the main-cpu gives us word-ram back
	
wait_dmna
	btst.b #DMNA,_memory
	beq wait_dmna
	rts
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; level-2 interrupt
	
usercall2
	move.w #CDBSTAT,d0
	jsr _cdbios
	
	btst.b #6,(a0) ;tray was opened?
	beq .tray_not_opened
	
	lea s_flags,a0 ;invalidate disk
	move.b (a0),d0
	and.b ~((1<<S_FLAG_CD_READ)|(1<<S_FLAG_CD_OK)),d0
	move.b d0,(a0)
	
.tray_not_opened
	rts
	
	
	
_end
	