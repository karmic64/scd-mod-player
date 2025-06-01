
MVL_NAMETABLE_WIDTH = 64
MVL_NAMETABLE_WIDTH_SHIFT = 7
MVL_NAMETABLE_HEIGHT = 64
MVL_SCREEN_HEIGHT = 28

MVL_PATTERN_SCROLL_OFFSET = 6
MVL_PATTERN_FIRST_Y = 0
MVL_PATTERN_CENTER_Y = 11
MVL_PATTERN_HEIGHT = 23

MVL_SONG_TITLE_Y = 1
MVL_ORDERLIST_Y = 3

MVL_EMPTY_NOTE_CHAR = '.'
MVL_UNKNOWN_NOTE_CHAR = '?'
MVL_EMPTY_SAMPLE_CHAR = '.'
MVL_EMPTY_EFFECT_CHAR = '.'

	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;
	;; main handler
	;;
	;;
	;;
	;;	
	
	
	
mode_mod_visualizer_restart
	moveq #CMD_M_GET_MODULE_INFO,d0
	bsr send_wait_command
	
	moveq #CMD_M_START_MODULE,d0
	bsr send_wait_command


mode_mod_visualizer_init
	lea dma_list,a6
	lea dma_data_buf&$ffffff,a5
	bsr dma_clear_screen
	
	st mvl_current_displayed_orderlist_pos
	st mvl_current_displayed_pattern
	move.w #MVL_PATTERN_SCROLL_OFFSET,window_h
	
	;;;;; render song title
	lea w_mpl_song_title,a0
	movea.l a5,a1
	
	moveq #0,d0
.song_title_loop
	move.b (a0)+,d1
	beq .done_song_title
	move.w d1,(a5)+
	addq.b #1,d0
	cmp.b #MPL_SONG_TITLE_SIZE,d0
	blo .song_title_loop
.done_song_title

	tst.b d0
	beq .blank_song_title
	move.w d0,(a6)+
	move.l a1,(a6)+
	
	move.w #40,d1
	sub.w d0,d1
	bclr #0,d1
	add.w #WINDOW_BASE+(MVL_SONG_TITLE_Y*MVL_NAMETABLE_WIDTH*2),d1
	move.w d1,(a6)+
	
.blank_song_title
	
	;;;;; start main mode
	
	move.l #mode_mod_visualizer,mode_ptr
	rts
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	
mode_mod_visualizer
	btst.b #6,joy ;return to menu with A
	beq .no_return
	move.l #mode_file_chooser_init,mode_ptr
.no_return
	
	
	lea dma_list,a6 ;building a dma list...
	lea dma_data_buf&$ffffff,a5
	
	bsr render_orderlist
	
	bsr render_pattern
	
	clr.w (a6) ;done everything, put the end on the dma-list
	
	rts
	
	
	
	
	
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;
	;; orderlist render
	;; dmalist in a6, dmadata in a5
	;;
	;;
	;;
	
render_orderlist
	;; don't render unless it actually changes
	lea mvl_current_displayed_orderlist_pos,a0
	
	moveq #0,d7
	move.b s_current_order,d7
	cmp.b (a0),d7
	beq .done
	move.b d7,(a0)
	
	move.w #40,(a6)+
	move.l a5,(a6)+
	move.w #WINDOW_BASE+(MVL_ORDERLIST_Y*MVL_NAMETABLE_WIDTH*2),(a6)+
	
	lea w_mpl_orderlist,a0
	moveq #0,d6
	move.b w_mpl_song_length-w_mpl_orderlist(a0),d6
	
	;; get the current "index"
	;; each orderlist position is 3 chars, first char is a space
	move.w d7,d0
	add.w d0,d0
	add.w d7,d0
	
	;; get the last possible "index"
	move.w d6,d1
	add.w d1,d1
	add.w d6,d1
	addq.w #1,d1 ;one char padding on the right
	
	;; center the orderlist.
	;; if the entire orderlist would fit on one screen, center the entire list
	;; otherwise center the current playback position
	cmp.w #40,d1
	bhi .center_index
	
.center_entire_orderlist
	
	move.w #-40,d0
	add.w d1,d0
	asr.w #1,d0
	
	bra .got_left_index
	
.center_index
	
	sub.w #20-2,d0
	bcc .no_wrap_left
	moveq #0,d0
.no_wrap_left
	sub.w #40,d1
	cmp.w d1,d0
	bls .no_wrap_right
	move.w d1,d0
.no_wrap_right
	
	
	;; main render-routine
.got_left_index
	lea mvl_nib_to_char_tbl,a1
	
	tst.w d0
	bpl .no_left_padding
	not.w d0
	move.w d0,d1
	addq.w #1,d1
.pad_loop
	clr.w (a5)+
	dbra d0,.pad_loop
	
	moveq #0,d0
	moveq #0,d2
	bra .loop
	
.no_left_padding
	moveq #0,d1 ;char counter in d1
	divu.w #3,d0 ;orderlist position in d0
	move.l d0,d2 ;char subindex in d2
	swap d2
	
.loop
	tst.b d2
	beq .blank
	cmp.w d6,d0
	bhs .blank
	
	moveq #0,d3
	move.b (a0,d0.w),d3
	cmp.b #2,d2
	beq .lo
	lsr.b #4,d3
.lo
	and.b #$0f,d3
	move.b (a1,d3.w),d3
	cmp.b d0,d7
	beq .nocur
	or.w #$4000,d3
.nocur
	move.w d3,(a5)+
	bra .next
	
.blank
	clr.w (a5)+
	
.next
	addq.w #1,d2
	cmp.w #3,d2
	blo .no_next_sub
	moveq #0,d2
	addq.w #1,d0
.no_next_sub
	
	addq.b #1,d1
	cmp.b #40,d1
	blo .loop
	
	
.done
	rts
	
	
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;
	;; pattern render
	;; dmalist in a6, dmadata in a5
	;;
	;;
	;;
	
render_pattern
	
	moveq #MPL_PATTERN_ROWS,d4 ;these constants must be preserved
	moveq #MVL_PATTERN_HEIGHT,d5
	moveq #MVL_PATTERN_CENTER_Y,d6
	
	;;;;;;;;; first check, do we need to rerender the whole thing,
	;;;; or are we just scrolling?
	move.w s_current_order,d7
	
	move.w d7,d0 ;get the current pattern id from orderlist
	lsr.w #8,d0
	lea w_mpl_orderlist,a0
	moveq #0,d1
	move.b (a0,d0),d1
	cmp.b mvl_current_displayed_pattern(pc),d1
	beq .no_rerender_pattern
	move.b d1,mvl_current_displayed_pattern
	
	moveq #CMD_M_GET_PATTERN,d0 ;tell the sub-cpu to start fetching pattern
	bsr send_command
	
.rerender_pattern
	move.w #-MVL_PATTERN_SCROLL_OFFSET*8,vscroll_a ;scroll back to top
	
	move.b d7,d0 ;get current top row
	sub.b d6,d0
	move.b d0,mvl_current_top_row
	bmi .rerender_pattern_top
	
	;;;; clear pattern bottom
.rerender_pattern_bottom
	add.b d4,d0 ;get first empty row
	
	move.b d5,d1 ;get amount of rows to clear
	sub.b d0,d1
	beq .rerender_pattern_main
	bmi .rerender_pattern_main
	
	ext.w d1 ;get fill length
	lsl.w #MVL_NAMETABLE_WIDTH_SHIFT,d1
	move.w d1,(a6)+
	
	ext.w d0 ;get dest
	lsl.w #MVL_NAMETABLE_WIDTH_SHIFT,d0
	add.w #BG_A_BASE+(MVL_PATTERN_FIRST_Y*MVL_NAMETABLE_WIDTH*2),d0
	move.w #$8000,(a6)+
	move.w d0,(a6)+
	
	clr.w (a6)+ ;fill with 0
	
	bra .rerender_pattern_main
	
	;;;; clear pattern top
.rerender_pattern_top
	neg.b d0 ;get fill length
	ext.w d0
	lsl.w #MVL_NAMETABLE_WIDTH_SHIFT,d0
	move.w d0,(a6)+
	
	move.l #(1<<31)|BG_A_BASE+(MVL_PATTERN_FIRST_Y*MVL_NAMETABLE_WIDTH*2),(a6)+
	
	clr.w (a6)+ ;fill with 0
	
	;;;; draw main pattern
.rerender_pattern_main
	
	btst.b #COMM_REQ,main_flug
	beq .no_wait_command
	bsr wait_command ;ok, now we need the sub-cpu to have finished
.no_wait_command
	
	move.b mvl_current_top_row(pc),d0
	
	move.b d0,d1 ;get first displayed pattern_row
	bpl .rerender_got_first_displayed_pattern_row
	moveq #0,d1
.rerender_got_first_displayed_pattern_row
	
	move.b d4,d2 ;get max possible displayed pattern rows
	sub.b d1,d2
	beq .done_pattern ;can't draw anything?
	bmi .done_pattern
	
	move.b d0,d3 ;get first screen row where a pattern displays
	neg.b d3
	bpl .rerender_got_first_displayed_screen_row
	moveq #0,d3
.rerender_got_first_displayed_screen_row
	
	move.b d5,d4 ;get max possible displayed screen rows
	sub.b d3,d4
	beq .done_pattern ;can't draw anything?
	bmi .done_pattern
	
	cmp.b d4,d2 ;ok, draw as much as we can
	bls .got_max_rerender_rows
	move.b d4,d2
.got_max_rerender_rows
	
	bra mvl_make_pattern_dma_list
	
	
	
	
	;;;;;;;;;; not rerendering, just see how much we need to scroll
	;; and draw the extra stuff
	
.no_rerender_pattern
	lea vscroll_a,a0
	
	move.b mvl_current_top_row(pc),d1 ;get current top row
	
	move.b d7,d0 ;get new top row
	sub.b d6,d0
	move.b d0,mvl_current_top_row
	
	move.b d0,d2 ;get the distance to scroll (should be positive if scrolling down)
	sub.b d1,d2
	beq .done_pattern ;no scrolling?
	bpl .scroll_pattern_down
	
	;;;;;; scroll up
.scroll_pattern_up
	cmp.b #-MVL_PATTERN_HEIGHT,d2 ;if scrolling further than the full size just rerender
	ble .rerender_pattern
	
	move.b d2,d3 ;update the vscroll
	ext.w d3
	asl.w #3,d3
	add.w (a0),d3
	move.w d3,(a0)
	asr.w #3,d3 ;save the screen row number
	add.w #MVL_PATTERN_SCROLL_OFFSET,d3
	
	neg.b d2 ;get rows to render
	
	;;; render top blank area
	move.b d0,d1 ;get amount of blank rows
	neg.b d1
	beq .scroll_pattern_up_no_blanks
	bmi .scroll_pattern_up_no_blanks
	
	cmp.b d2,d1
	bls .scroll_pattern_up_full_blanks
	move.b d2,d1
.scroll_pattern_up_full_blanks
	
	movem.w d1/d3,-(sp)
	
	ext.w d1 ;fill length
	lsl.w #MVL_NAMETABLE_WIDTH_SHIFT,d1
	move.w d1,(a6)+
	
	and.w #MVL_NAMETABLE_HEIGHT-1,d3 ;get vram destination
	lsl.w #MVL_NAMETABLE_WIDTH_SHIFT,d3
	add.w #BG_A_BASE+(MVL_PATTERN_FIRST_Y*MVL_NAMETABLE_WIDTH*2),d3
	move.w #$8000,(a6)+
	move.w d3,(a6)+
	
	clr.w (a6)+ ;fill with 0s
	
	movem.w (sp)+,d1/d3 ;restore blanked rows and current row
	sub.b d1,d2 ;account for the blanked rows
	beq .done_scroll_pattern
	add.b d1,d0 ;update current pattern row
	add.b d1,d3 ;update current screen row
	
.scroll_pattern_up_no_blanks
 
	;;; render pattern rows
	move.b d0,d1
	bsr mvl_make_pattern_dma_list
	
	bra .done_scroll_pattern
	
	;;;;;; scroll down
.scroll_pattern_down
	cmp.b #MVL_PATTERN_HEIGHT,d2 ;if scrolling further than the full size just rerender
	bge .rerender_pattern
	
	move.w (a0),d3 ;get the first screen row
	asr.w #3,d3
	add.w #MVL_PATTERN_SCROLL_OFFSET,d3
	add.b d5,d3
	
	move.b d2,d0 ;update vscroll
	ext.w d0
	asl.w #3,d0
	add.w d0,(a0)
	
	;;; render actual pattern part
	add.b d5,d1 ;get the first newly-rendered pattern row
	
	sub.b d1,d4 ;get the amount of pattern rows left to render
	beq .scroll_pattern_down_clear ;can't draw anything?
	bmi .scroll_pattern_down_clear
	
	move.w d2,-(sp) ;save scroll distance
	
	cmp.b d4,d2 ;more left than we are scrolling?
	bls .scroll_pattern_down_full
	move.b d4,d2
.scroll_pattern_down_full
	movem.w d2-d3,-(sp) ;save amount of rendered rows and first screen row
	
	bsr mvl_make_pattern_dma_list
	
	movem.w (sp)+,d0/d3 ;restore
	move.w (sp)+,d2
	sub.b d0,d2 ;account for rows we just rendered
	beq .done_scroll_pattern
	add.b d0,d3 ;and bump up the screen row number
	
.scroll_pattern_down_clear
	
	;;; render any blanks at the bottom
	ext.w d2 ;fill length
	lsl.w #MVL_NAMETABLE_WIDTH_SHIFT,d2
	move.w d2,(a6)+
	
	and.w #MVL_NAMETABLE_HEIGHT-1,d3 ;get vram destination
	lsl.w #MVL_NAMETABLE_WIDTH_SHIFT,d3
	add.w #BG_A_BASE+(MVL_PATTERN_FIRST_Y*MVL_NAMETABLE_WIDTH*2),d3
	move.w #$8000,(a6)+
	move.w d3,(a6)+
	
	clr.w (a6)+ ;fill with 0s
	
	
.done_scroll_pattern
	;;; done scrolling pattern, handle row highlighting
	move.b mvl_current_highlighted_row(pc),d1 ;unhighlight the current row...
	bsr mvl_update_pattern_row_dma_list
	move.b d7,d1 ;...and highlight the current one
	bsr mvl_update_pattern_row_dma_list
	
	
.done_pattern
	rts
	
	
	
	
	
	
mvl_current_displayed_pattern
	dc.b $ff
mvl_current_displayed_orderlist_pos
	dc.b $ff
mvl_current_top_row ;the top of the pattern display, not the top of the screen
	dc.b $ff ;relative to current vscroll - this CAN be negative!
mvl_current_highlighted_row
	dc.b 0
	
	
	
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; dmalist pointer in a6
	;; dma data buffer pointer in a5
	;; first row in d1
mvl_update_pattern_row_dma_list
	move.b mvl_current_top_row(pc),d2
	ext.w d2
	
	move.b d1,d3 ;get row relative to top
	ext.w d3
	sub.w d2,d3
	cmp.w #MVL_PATTERN_HEIGHT,d3
	bhs mvl_make_pattern_dma_list\.ret
	
	move.w vscroll_a,d2 ;get actual screen row number
	asr.w #3,d2
	add.w d2,d3
	add.w #MVL_PATTERN_SCROLL_OFFSET,d3
	
	moveq #1,d2
	;; fall through to below
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; dmalist pointer in a6
	;; dma data buffer pointer in a5
	;; first row in d1
	;; rows to render in d2
	;; first screen row number in d3
mvl_make_pattern_dma_list
	and.w #MVL_NAMETABLE_HEIGHT-1,d3 ;get screen base
	lsl.w #MVL_NAMETABLE_WIDTH_SHIFT,d3
	add.w #BG_A_BASE+(MVL_PATTERN_FIRST_Y*MVL_NAMETABLE_WIDTH*2)+2,d3
	
	lea w_mpl_pattern,a0 ;get pattern row base
	moveq #0,d4
	move.b w_mpl_amt_channels,d4
	moveq #0,d0
	move.b d1,d0
	mulu.w d4,d0
	lsl.l #2,d0
	add.l d0,a0
	
	;; finally we actually make the main pattern dmalist
	ext.w d2
	subq.w #1,d2
.rerender_pattern_row_loop
	movea.l a5,a4 ;save the current data buf position for later
	
	movem.l d1-d3,-(sp) ;do actual conversion
	bsr mvl_convert_pattern_row
	movem.l (sp)+,d1-d3
	
	move.l a5,d0 ;get written data length
	sub.l a4,d0
	lsr.l #1,d0
	move.w d0,(a6)+
	
	move.l a4,(a6)+ ;data pointer
	
	move.w d3,(a6)+ ;data destination
	add.w #MVL_NAMETABLE_WIDTH*2,d3
	and.w #(MVL_NAMETABLE_WIDTH*MVL_NAMETABLE_HEIGHT*2)-1,d3
	or.w #BG_A_BASE,d3
	
	addq.b #1,d1 ;step row number
	
	dbra d2,.rerender_pattern_row_loop
	
.ret
	rts
	
	
	
	
	
	;;;;;;;;;; converts a pattern row to textual display
	;; input pointer in a0, output pointer in a5
	;; row number in d1, currently playing row number in d7
mvl_convert_pattern_row
	move.w #$4000,d2 ;get tilemap high-byte (used to highlight current row)
	cmp.b d1,d7
	bne .not_current_row
	move.b d1,mvl_current_highlighted_row
	moveq #0,d2
.not_current_row
	
	;;;;; row number
	
	ext.w d1
	lsl.w #1,d1
	lea mvl_row_names_tbl(pc),a1
	move.b (a1,d1),d2
	move.w d2,(a5)+
	move.b 1(a1,d1),d2
	move.w d2,(a5)+
	
	;;;;;;;; channel loop
	
	lea mvl_nib_to_char_tbl(pc),a1
	lea mvl_note_names_tbl(pc),a2
	
	moveq #0,d0
	move.b w_mpl_amt_channels,d0
	subq.b #1,d0
	
.channel_loop
	move.b #' ',d2
	move.w d2,(a5)+
.first
	
	;;;; period/note
	move.w 0(a0),d3
	and.w #$0fff,d3
	beq .blank_note
	
	bclr #13,d2
	
	lea mvl_note_period_tbl(pc),a3
	
	moveq #1,d5 ;octave
.note_find_next_octave
	moveq #0,d4 ;note index
.note_find_loop
	cmp.w (a3)+,d3
	beq .normal_note
	addq.b #2,d4
	cmp.b #12*2,d4
	blo .note_find_loop
	addq.b #1,d5
	cmp.b #4,d5
	blo .note_find_next_octave
	
.unknown_note
	move.b #MVL_UNKNOWN_NOTE_CHAR,d2
	bra .note_repcopy
	
.normal_note
	move.b 0(a2,d4),d2
	move.w d2,(a5)+
	move.b 1(a2,d4),d2
	move.w d2,(a5)+
	move.b (a1,d5),d2
	move.w d2,(a5)+
	bra .done_note
	
.blank_note
	bset #13,d2
	move.b #MVL_EMPTY_NOTE_CHAR,d2
.note_repcopy
	move.w d2,(a5)+
	move.w d2,(a5)+
	move.w d2,(a5)+
	
.done_note
	
	
	;;;;;; sample
	moveq #0,d3
	moveq #0,d4
	move.b 0(a0),d3
	move.b 2(a0),d4
	and.b #$f0,d3
	lsr.b #4,d4
	or.b d4,d3
	beq .blank_sample
	
	bclr #13,d2
	
	lsr.b #4,d3
	move.b (a1,d3),d2
	move.w d2,(a5)+
	move.b (a1,d4),d2
	move.w d2,(a5)+
	
	bra .done_sample
	
.blank_sample
	bset #13,d2
	move.b #MVL_EMPTY_SAMPLE_CHAR,d2
	move.w d2,(a5)+
	move.w d2,(a5)+
	
.done_sample
	
	
	;;;;;;; effect
	move.w 2(a0),d3
	and.w #$0fff,d3
	beq .blank_effect
	
	bclr #13,d2
	
	move.w d3,d4
	lsr.w #4,d3
	move.w d3,d5
	lsr.w #4,d3
	move.b (a1,d3),d2
	move.w d2,(a5)+
	and.w #$f,d5
	move.b (a1,d5),d2
	move.w d2,(a5)+
	and.w #$f,d4
	move.b (a1,d4),d2
	move.w d2,(a5)+
	
	bra .done_effect
	
.blank_effect
	bset #13,d2
	move.b #MVL_EMPTY_EFFECT_CHAR,d2
	move.w d2,(a5)+
	move.w d2,(a5)+
	move.w d2,(a5)+
	
.done_effect
	
	
	
	addq.l #4,a0
	dbra d0,.channel_loop
	
	rts
	
	
	
	
	
	
mvl_note_period_tbl
	dc.w 856,808,762,720,678,640,604,570,538,508,480,453
	dc.w 428,404,381,360,339,320,302,285,269,254,240,226
	dc.w 214,202,190,180,170,160,151,143,135,127,120,113
	
mvl_note_names_tbl
	dc.w 'C-','C#','D-','D#','E-','F-','F#','G-','G#','A-','A#','B-'
	
	
mvl_nib_to_char_tbl	dc.b '0123456789ABCDEF'

mvl_row_names_tbl = fch_dec_str_tbl
	;dc.w '00','01','02','03','04','05','06','07','08','09'
	;dc.w '10','11','12','13','14','15','16','17','18','19'
	;dc.w '20','21','22','23','24','25','26','27','28','29'
	;dc.w '30','31','32','33','34','35','36','37','38','39'
	;dc.w '40','41','42','43','44','45','46','47','48','49'
	;dc.w '50','51','52','53','54','55','56','57','58','59'
	;dc.w '60','61','62','63'
	
	
	
	
	