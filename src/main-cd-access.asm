	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;
	;; loading modes
	;;
	;;
	;;
	;;
	
mode_load_dir
	moveq #CMD_M_LOAD_ROOT_DIRECTORY,d0
	bsr send_command
	
	lea dma_list,a6
	lea dma_data_buf&$ffffff,a5
	
	bsr dma_clear_screen
	
	lea fch_loading_dir_text(pc),a0
	bsr dma_centered_text
	
	clr.w (a6)
	
	move.l #mode_loading_dir,mode_ptr
	rts
	
mode_loading_dir
	bsr wait_command
	tst.w d0
	bne .error
	
	clr.l fch_current_file
	move.l #mode_file_chooser_init,mode_ptr
	rts
	
.error
	lea dma_list,a6
	lea dma_data_buf&$ffffff,a5
	
	bsr dma_clear_screen
	bsr dma_centered_error_message
	
	lea fch_loading_dir_retry_text(pc),a0
	bsr dma_centered_text
	add.w #(4*64*2),-2(a6)
	
	clr.w (a6)
	
	moveq #CMD_M_LOAD_ROOT_DIRECTORY,d0	;try again?
	bra send_command
	
	

	
	
mode_load_mod
	moveq #CMD_M_LOAD_MODULE,d0
	move.l fch_current_file(pc),d1
	bsr send_command
	
	lea dma_list,a6
	lea dma_data_buf&$ffffff,a5
	
	bsr dma_clear_screen
	
	lea fch_loading_mod_text(pc),a0
	bsr dma_centered_text
	
	clr.w (a6)
	
	move.l #mode_loading_mod,mode_ptr
	rts
	
mode_loading_mod
	bsr wait_command
	tst.w d0
	bne .error
	move.l #mode_mod_visualizer_restart,mode_ptr
	rts
	
.error
	lea dma_list,a6
	lea dma_data_buf&$ffffff,a5
	
	bsr dma_clear_screen
	bsr dma_centered_error_message
	
	lea fch_loading_mod_retry_text(pc),a0
	bsr dma_centered_text
	add.w #(4*64*2),-2(a6)
	
	clr.w (a6)
	
	move.l #mode_file_chooser_mod_error,mode_ptr
	rts
	
mode_file_chooser_mod_error
	move.b joy,d0
	and.b #$f0,d0
	beq .no
	move.l #mode_file_chooser_init,mode_ptr
.no
	rts
	
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;
	;; main mode
	;;
	;;
	
FCH_NAMETABLE_WIDTH = 64
FCH_NAMETABLE_WIDTH_SHIFT = 7
FCH_NAMETABLE_HEIGHT = 64
FCH_SCREEN_HEIGHT = 28

FCH_PADDING_Y = 1
FCH_FIRST_Y = 0
FCH_CENTER_Y = 14
FCH_HEIGHT = 28
	
	
	
mode_file_chooser_init
	bsr init_video_settings
	sf fch_render_mode
	move.l #mode_file_chooser,mode_ptr
	
mode_file_chooser
	btst.b #S_FLAG_CD_OK,s_flags ;if directory went invalid, reload it
	beq mode_load_dir
	
	lea fch_top_file(pc),a0
	lea 4(a0),a1 ;current file
	move.l (a1),d0
	move.l d0,d7 ;move the current file to d7 so we can un-highlight it in partial render
	move.l w_cda_dir_files,d1
	
	move.b joy(pc),d2
	
	;;??   ;;; TODO BACK TO MOD VISUALIZER WITH A
	
	;;;; cursor controls
	
	btst #0,d2
	beq .no_up
	subq.l #1,d0
.no_up
	btst #1,d2
	beq .no_down
	addq.l #1,d0
.no_down
	btst #2,d2
	beq .no_left
	subi.l #20,d0
.no_left
	btst #3,d2
	beq .no_right
	addi.l #20,d0
.no_right
	
	tst.l d0
	bpl .no_up_clamp
	moveq #0,d0
.no_up_clamp
	cmp.l d1,d0
	blo .no_down_clamp
	move.l d1,d0
	subq.l #1,d0
.no_down_clamp
	move.l d0,(a1)
	
	;;;; module start
	
	tst.b d2
	bmi .start
	btst #4,d2
	bne .start
	btst #5,d2
	beq .no_start
.start
	move.l #mode_load_mod,mode_ptr
.no_start
	
	;;;;;;;;; rendering
	
	lea dma_list,a6
	lea dma_data_buf&$ffffff,a5
	
	;; determine new screen top
	
	subi.l #FCH_CENTER_Y,d0
	
	cmp.l #-FCH_PADDING_Y,d0 ;lower bound
	bge .not_max_top
	move.l #-FCH_PADDING_Y,d0
.not_max_top
	
	move.l d1,d2 ;upper bound (max files - screen height in chars + padding, clamped to no lower than 0)
	subi.l #FCH_SCREEN_HEIGHT-FCH_PADDING_Y,d2
	bpl .normal_upper_bound
	moveq #0,d2
.normal_upper_bound
	cmp.l d2,d0
	ble .not_max_bottom
	move.l d2,d0
.not_max_bottom

	;; start rendering
	
	move.l (a0),d3 ;scroll distance
	sub.l d0,d3
	
	move.l d0,(a0)

	tst.b fch_render_mode ;if forcing full rerender, always do that
	beq fch_full_rerender
	
	cmp.l #-FCH_SCREEN_HEIGHT,d3 ;if scrolling further than the whole screen height, do full rerender
	ble fch_full_rerender
	cmp.l #FCH_SCREEN_HEIGHT,d3
	bge fch_full_rerender
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; partial rerender
	;; d0 new screen top, d1 max files on disc, d2 top upper bound, d3 scroll distance
	
fch_partial_rerender
	;; adjust vscroll (new value in d4.w)
	lea vscroll_a,a0
	neg.l d3
	move.w d3,d4
	asl.w #3,d4
	add.w (a0),d4
	move.w d4,(a0)
	asr.w #3,d4 ;convert v-scroll to chars, it makes later calculations more convenient
	
	;; un-highlight the previously selected file
	lea fch_current_file(pc),a0
	move.l (a0),d6
	cmp.l d6,d7 ;no change?
	beq .no_highlight
	
	cmp.l d1,d7 ;valid file id?
	bhs .no_unhighlight
	
	move.l d7,d5 ;on-screen?
	sub.l d0,d5
	cmp.l #FCH_SCREEN_HEIGHT,d5
	bhs .no_unhighlight
	
	move.w #40,(a6)+ ;transfer length
	move.l a5,(a6)+ ;source address
	
	add.w d4,d5 ;dest address
	and.w #FCH_NAMETABLE_HEIGHT-1,d5
	lsl.w #FCH_NAMETABLE_WIDTH_SHIFT,d5
	or.w #BG_A_BASE,d5
	move.w d5,(a6)+
	
	movem.l d0-d6,-(sp)
	move.l d7,d0
	bsr fch_render_file_row
	movem.l (sp)+,d0-d6
	
.no_unhighlight

	;; highlight the newly selected file
	cmp.l d1,d6 ;valid file id?
	bhs .no_highlight
	
	move.l d6,d5 ;on-screen?
	sub.l d0,d5
	cmp.l #FCH_SCREEN_HEIGHT,d5
	bhs .no_highlight
	
	move.w #40,(a6)+ ;transfer length
	move.l a5,(a6)+ ;source address
	
	add.w d4,d5 ;dest address
	and.w #FCH_NAMETABLE_HEIGHT-1,d5
	lsl.w #FCH_NAMETABLE_WIDTH_SHIFT,d5
	or.w #BG_A_BASE,d5
	move.w d5,(a6)+
	
	movem.l d0-d5,-(sp)
	move.l d6,d0
	bsr fch_render_file_row
	movem.l (sp)+,d0-d5
	
.no_highlight


	;;;;;;;;;;;;;;;; main rerender
	
	tst.l d3 ;scroll direction?
	beq .done
	bpl .scrolling_down
	
	;;;;; scroll up
.scrolling_up
	
	neg.l d3 ;get amount of rows to render
	
	move.l d0,d5 ;get amount of blanks (-top file id)
	beq .scrolling_up_main
	neg.l d5
	bmi .scrolling_up_main
	
	move.w #$8000,d6 ;get nametable base
	swap d6
	move.w d4,d6
	and.w #FCH_NAMETABLE_HEIGHT-1,d6
	lsl.w #FCH_NAMETABLE_WIDTH_SHIFT,d6
	or.w #BG_A_BASE,d6
	
	cmp.l d3,d5 ;clamp amount of blanks at the total rendered rows
	bls .scrolling_up_no_clamp_blanks
	move.l d3,d5	
.scrolling_up_no_clamp_blanks
	sub.l d5,d3 ;adjust amount of main rows
	add.l d5,d0 ;adjust first file id
	
	move.w d5,-(sp)
	lsl.w #FCH_NAMETABLE_WIDTH_SHIFT,d5 ;get fill size
	
	move.w d6,d7 ;get "second" fill size (due to overflow)
	add.w d5,d7
	sub.w #BG_A_BASE+(FCH_NAMETABLE_WIDTH*FCH_NAMETABLE_HEIGHT*2),d7
	beq .scrolling_up_no_second_fill
	bcs .scrolling_up_no_second_fill
	move.w d7,(a6)+
	move.l #BG_A_BASE|(1<<31),(a6)+
	clr.w (a6)+
	sub.w d7,d5
.scrolling_up_no_second_fill
	move.w d5,(a6)+
	move.l d6,(a6)+
	clr.w (a6)+
	
	move.w (sp)+,d5
	
.scrolling_up_done_blanks
	tst.l d3
	beq .done
	
.scrolling_up_main
	
	move.w d4,d6 ;get nametable base of main area
	tst.l d5
	bmi .scrolling_up_main_neg_blanks
	add.w d5,d6
.scrolling_up_main_neg_blanks
	and.w #FCH_NAMETABLE_HEIGHT-1,d6
	lsl.w #FCH_NAMETABLE_WIDTH_SHIFT,d6
	or.w #BG_A_BASE,d6
	
	bra .rerender_main
	
	
	;;;;; scroll down
.scrolling_down
	
	move.l d0,d5 ;get amount of blanks
	add.l #FCH_SCREEN_HEIGHT,d5
	sub.l d1,d5
	beq .scrolling_down_main
	bmi .scrolling_down_main
	
	cmp.l d3,d5 ;clamp amount of blanks at the total rendered rows
	bls .scrolling_down_no_clamp_blanks
	move.l d3,d5	
.scrolling_down_no_clamp_blanks
	sub.l d5,d3 ;adjust amount of main rows
	
	move.w #$8000,d6 ;get nametable base
	swap d6
	move.w d4,d6
	add.w #FCH_SCREEN_HEIGHT,d6
	sub.w d5,d6
	and.w #FCH_NAMETABLE_HEIGHT-1,d6
	lsl.w #FCH_NAMETABLE_WIDTH_SHIFT,d6
	or.w #BG_A_BASE,d6
	
	move.w d5,-(sp)
	lsl.w #FCH_NAMETABLE_WIDTH_SHIFT,d5 ;get fill size
	
	move.w d6,d7 ;get "second" fill size (due to overflow)
	add.w d5,d7
	sub.w #BG_A_BASE+(FCH_NAMETABLE_WIDTH*FCH_NAMETABLE_HEIGHT*2),d7
	beq .scrolling_down_no_second_fill
	bcs .scrolling_down_no_second_fill
	move.w d7,(a6)+
	move.l #BG_A_BASE|(1<<31),(a6)+
	clr.w (a6)+
	sub.w d7,d5
.scrolling_down_no_second_fill
	move.w d5,(a6)+
	move.l d6,(a6)+
	clr.w (a6)+
	
	move.w (sp)+,d5
	
	
.scrolling_down_done_blanks
	tst.l d3
	beq .done
	
.scrolling_down_main

	move.l #FCH_SCREEN_HEIGHT,d7
	sub.l d3,d7
	tst.l d5
	bmi .scrolling_down_main_neg_blanks
	sub.l d5,d7
.scrolling_down_main_neg_blanks
	add.l d7,d0 ;adjust first song
	
	moveq #0,d6
	move.w d4,d6
	add.w d7,d6
	and.w #FCH_NAMETABLE_HEIGHT-1,d6
	lsl.w #FCH_NAMETABLE_WIDTH_SHIFT,d6
	or.w #BG_A_BASE,d6
	
	
	
	;;;;;; render main rows
	; file id in d0, rows in d3, nametable base in d6
.rerender_main
	subq.w #1,d3
	
.rerender_main_loop
	move.w #40,(a6)+
	move.l a5,(a6)+
	move.w d6,(a6)+
	
	movem.l d0/d3/d6,-(sp)
	bsr fch_render_file_row
	movem.l (sp)+,d0/d3/d6
	
	addq.l #1,d0
	
	add.w #MVL_NAMETABLE_WIDTH*2,d6
	and.w #(MVL_NAMETABLE_WIDTH*MVL_NAMETABLE_HEIGHT*2)-1,d6
	or.w #BG_A_BASE,d6
	
	dbra d3,.rerender_main_loop
	
	
	
	;;;;; end dma-list
	
.done
	clr.w (a6)
	
.exit
	rts
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; full rerender
	
fch_full_rerender
	st fch_render_mode
	clr.w vscroll_a
	
	move.l #BG_A_BASE|(1<<31),d2 ;vram copy dest
	
	;;;;;; clear any top padding
	
	move.l d0,d3
	neg.l d3
	beq .no_clear_top
	bmi .no_clear_top
	
	move.w d3,d4 ;transfer length
	lsl.w #FCH_NAMETABLE_WIDTH_SHIFT,d4
	move.w d4,(a6)+
	
	move.l d2,(a6)+ ;dest address
	add.w d4,d2
	
	clr.w (a6)+ ;data
	
.no_clear_top

	;;;;;; main area
	
	tst.l d0 ;adjust the first shown file number to reflect the actual number
	bpl .no_adjust_file_id
	moveq #0,d0
.no_adjust_file_id

	;; get rows to render

	move.l d1,d4 ;get max files that could be rendered (total files - current top file)
	sub.l d0,d4
	
	moveq #FCH_SCREEN_HEIGHT,d5 ;don't render any more than the actual screen height
	cmp.l d5,d4
	ble .no_clamp_row_count
	move.l d5,d4
.no_clamp_row_count
	
	tst.l d3 ;minus any top padding
	bmi .no_top_padding
	sub.l d3,d4
.no_top_padding
	
	subq.l #1,d4 ;nothing to do?  (plus decrement the value for dbra)
	bmi .done
	
	;; do main rendering
	
.main_loop
	move.w #40,(a6)+ ;make dma list
	move.l a5,(a6)+
	move.w d2,(a6)+
	
	movem.l d0-d4,-(sp)
	bsr fch_render_file_row
	movem.l (sp)+,d0-d4
	
	addq.l #1,d0 ;next file
	addi.w #FCH_NAMETABLE_WIDTH*2,d2 ;advance screen row
	
	dbra d4,.main_loop
	
	;;;;;; bottom padding
	
	move.w #BG_A_BASE+(FCH_NAMETABLE_WIDTH*FCH_SCREEN_HEIGHT*2),d3 ;get fill length
	sub.w d2,d3
	beq .no_clear_bottom
	move.w d3,(a6)+
	move.l d2,(a6)+
	clr.w (a6)+
.no_clear_bottom

	;;;;;; end dma-list
	
.done
	clr.w (a6)
	
.exit
	rts
	
	
	
	
	
	
	;;;;;;
	;; dma-data pointer in a5, file-id in d0
	
fch_render_file_row
	;; get tilemap high-byte (highlight current file)
	moveq #0,d1
	cmp.l fch_current_file(pc),d0
	beq .is_current_row
	move.w #$4000,d1
.is_current_row
	
	;; get pointer to directory entry
	lea w_cda_dir_index,a0
	lsl.l #2,d0
	move.l (a0,d0.l),d0
	lea w_cda_directory,a0
	lea (a0,d0.l),a0
	
	;; determine amount of digits for file size
	move.l de_size(a0),d0
	lea fch_digits_tbl(pc),a1
	moveq #8*4,d2
.digits_loop
	cmp.l (a1,d2.w),d0
	bhs .digits_got
	subq.w #4,d2
	bpl .digits_loop
.digits_got
	addq.w #8,d2
	lsr.w #2,d2
	
	;; get filename and get length, not including version number
	lea de_name(a0),a1
	moveq #0,d3
	move.b -1(a1),d3
	moveq #';',d4
.fn_end_scan_loop
	subq.w #1,d3
	beq .fn_end_whole_name
	bmi .fn_end_whole_name
	cmp.b (a1,d3.w),d4
	beq .fn_got_length
	bra .fn_end_scan_loop
	
.fn_end_whole_name
	moveq #0,d3
	move.b -1(a1),d3
.fn_got_length
	
	;; write filename
	move.w d1,(a5)+
	
	move.w #40-2-2,d4 ;40-char screen, 2 chars of left/right padding, 2 chars separation
	sub.w d2,d4 ;minus however many filesize digits
	moveq #0,d5
.fn_write_loop
	clr.b d1
	cmp.w d3,d5
	bhs .fn_write_blank
	move.b (a1)+,d1
.fn_write_blank
	move.w d1,(a5)+
	addq.w #1,d5
	cmp.w d4,d5
	blo .fn_write_loop
	
	sf d1
	move.w d1,(a5)+
	move.w d1,(a5)+
	
	;; use digit count to find out the initial divisor index and therefore how many divisions we do
	;; we go from a divisor of 10^9 (10 digits) to 10^1 (=100, 3-4 digits) in increments of 2 digits
	lea fch_dec_str_tbl(pc),a2
	
	subq.w #3,d2 ;if the value is only 1 or 2 digits we do not need any divisions
	blo .fs_output_final
	lsr.w #1,d2 ;mask off lower bit (increments of 2 digits)
	lsl.w #3,d2 ;get index to table (1 shift to restore masked off bit, 2 shifts for long)
	
	;; write filesize
	
	sf d3	;"leading zero" flag
	lea fch_digits_tbl+4(pc),a1 ;skip the unused 10 entry
	
.fs_output_loop ;(dividend/quotient still in d0)
	moveq #0,d4 ;remainder
	moveq #31,d5 ;bit counter
	move.l (a1,d2.w),d6 ;divisor
	
.fs_div_loop
	add.l d0,d0
	addx.l d4,d4
	move.l d4,d7
	sub.l d6,d7
	blo .fs_div_no_fit
	move.l d7,d4
	addq.b #1,d0
.fs_div_no_fit
	dbra d5,.fs_div_loop
	
	bsr fch_write_dec_str
	
	move.l d4,d0 ;make remainder the new dividend
	
	subq.w #8,d2
	bpl .fs_output_loop
	
.fs_output_final
	tst.b d0 ;special exception for last 2 digits, we will write a single zero (if no digits were written earlier)
	bne .fs_output_final_normal
	tst.b d3
	bne .fs_output_final_normal
	move.b #'0',d1
	move.w d1,(a5)+
	bra .fs_output_done
.fs_output_final_normal
	bsr fch_write_dec_str
.fs_output_done
	
	;; done
	sf d1
	move.w d1,(a5)+
		
	rts
	
	
	
	
	;; writes a 2-digit value
	;; out pointer in a5, tilemap word in d1, "leading zero" flag in d3, value in d0, dec_str_tbl in a2
fch_write_dec_str
	move.l d0,d5
	add.b d5,d5
	
	; upper digit?
	cmp.b #10*2,d5
	bhs .upper_digit
	tst.b d3
	beq .no_upper_digit
.upper_digit
	st d3
	move.b 0(a2,d5.w),d1
	move.w d1,(a5)+
.no_upper_digit

	move.b 1(a2,d5.w),d1
	cmp.b #'0',d1
	bne .lower_digit
	tst.b d3
	beq .no_lower_digit
.lower_digit
	st d3
	move.w d1,(a5)+
.no_lower_digit
	
	rts
	
	
	
fch_digits_tbl
	dl 10
	dl 100
	dl 1000
	dl 10000
	dl 100000
	dl 1000000
	dl 10000000
	dl 100000000
	dl 1000000000
	
fch_dec_str_tbl	;this allows dividing by 100 instead of 10
	dw '00','01','02','03','04','05','06','07','08','09'
	dw '10','11','12','13','14','15','16','17','18','19'
	dw '20','21','22','23','24','25','26','27','28','29'
	dw '30','31','32','33','34','35','36','37','38','39'
	dw '40','41','42','43','44','45','46','47','48','49'
	dw '50','51','52','53','54','55','56','57','58','59'
	dw '60','61','62','63','64','65','66','67','68','69'
	dw '70','71','72','73','74','75','76','77','78','79'
	dw '80','81','82','83','84','85','86','87','88','89'
	dw '90','91','92','93','94','95','96','97','98','99'

	
	
fch_render_mode	db 0	;0 - full rerender, 1 - partial rerender
	db 0
	
fch_top_file	dl -FCH_PADDING_Y
fch_current_file	dl 0
	
	
fch_loading_dir_text	db "Loading directory...",0
fch_loading_mod_text	db "Loading module...",0

fch_loading_dir_retry_text	db "Please insert another disc",0
fch_loading_mod_retry_text	db "Press any button to return",0
	
	
	
	align 2
	
	
	
	