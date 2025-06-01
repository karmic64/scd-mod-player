
	include mod-player-constants.asm

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; structs
	;;
	;;
	;;
	;;
	;;
	;;
	
	
	clrso ;sample info struct within a mod file
mpl_mod_sample_name	so.b MPL_SAMPLE_NAME_SIZE
mpl_mod_sample_length	so.w 1
mpl_mod_sample_finetune	so.b 1
mpl_mod_sample_volume	so.b 1
mpl_mod_sample_loop_offset so.w 1
mpl_mod_sample_loop_length so.w 1
mpl_mod_sample_SIZEOF so.b 0


	clrso ;sample info for us
mpl_sample_ptr	so.l 1 ;in mod file
mpl_sample_size	so.l 1
mpl_sample_addr	so.w 1 ;in pcm ram
mpl_sample_loop_addr	so.w 1
mpl_sample_SIZEOF so.b 0


	clrso ;channel playback struct
mpl_chn_next_period	so.w 1 ;period in pattern- used when (re)triggering and as toneporta target
mpl_chn_period	so.w 1	;actual current period, affected by (tone)portamento
mpl_chn_arp_cnt	so.b 1	;incremented every tick, 0,1,2,0,1,2,0,etc...
mpl_chn_finetune	so.b 1
mpl_chn_toneporta	so.b 1
mpl_chn_toneporta_direction	so.b 1
mpl_chn_vibrato	so.b 1
mpl_chn_vibrato_pos	so.b 1
mpl_chn_vibrato_shape	so.b 1

mpl_chn_sample	so.b 1
mpl_chn_sample_offset	so.b 1
mpl_chn_delay	so.b 1 ;row-tick where the pattern data is read (usually 0 unless EDx effect)
mpl_chn_retrig_cnt	so.b 1	;retrigs note when counts down from 1->0 (then stays 0)

mpl_chn_volume	so.b 1
mpl_chn_panning	so.b 1
mpl_chn_tremolo so.b 1
mpl_chn_tremolo_pos	so.b 1
mpl_chn_tremolo_shape so.b 1

mpl_chn_effect	so.b 1
mpl_chn_effect_param	so.b 1

mpl_chn_SIZEOF	so.b 0
	
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;; global variable struct
	
	clrso
	
	;;;;;;;;;;; module info save
	
mpl_module_base_ptr	so.l 0
mpl_song_title_ptr	so.l 1 ;same as above...
mpl_samples_ptr	so.l 1
mpl_orderlist_ptr	so.l 1 ;songlength is (orderlist_ptr - 2).b
mpl_patterns_ptr	so.l 1 
mpl_sample_data_ptr	so.l 1 
	
mpl_amt_channels	so.b 1
mpl_amt_samples	so.b 1
	
mpl_samples	so.b mpl_sample_SIZEOF*MPL_MAX_SAMPLES
	
	
	;;;;;;;;;;;; playback state
	
mpl_playback_state	so.b 0

mpl_timer_irq_cnt	so.b 1
mpl_timer_irq_reload	so.b 1
	
mpl_speed_cnt	so.b 1
mpl_speed	so.b 1
	
mpl_current_order	so.b 1
mpl_current_row	so.b 1

mpl_current_row_ptr	so.l 1 ;pointer to current row in pattern data
	
mpl_position_jump_order	so.b 1 ;>songlength = no jump
mpl_position_jump_row	so.b 1 ;>=64 = no jump

mpl_delay_cnt	so.b 1 ;used for EEx
mpl_delaying	so.b 1

mpl_loop_row	so.b 1 ;used for E6x
mpl_loop_cnt	so.b 1 ;jumps left until we stop looping
	
mpl_channel_disable	so.b 1 ;same as pcm_ch
mpl_channel_on_flag	so.b 1
	
mpl_channels	so.b mpl_chn_SIZEOF*MPL_MAX_CHANNELS
	
mpl_SIZEOF	so.b 0
	
	


	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; reset routine
	;;
	;;
	;;
	;;
	;;
	;;
	;;
mpl_reset
	sf pcm_cont
	st pcm_ch
	
	bclr.b #IEN3,_intmask
	move.w #JMP_CODE,_level3
	move.l #mpl_timer_irq,_level3+2
	
	sf s_current_order
	sf s_current_row
	rts
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; reload routine
	;;module pointer in a0
	;;
	;;
	;;
	;;
	;;
	;;
	;;
	;;
mpl_load
	lea mpl_ram(pc),a6
	
	lea 20(a0),a1 ;sample info base pointer
	
	;;;;;;;;;;;;;;;;;;;; try getting module type from the signature
	lea $0438(a0),a2
	
	;;;;;;; old module?
	;; if any byte here is non-ascii we assume so
	moveq #$20,d0
	moveq #$7e,d1
	movea.l a2,a3
	moveq #3,d3
.chk_sig_exist_loop
	move.b (a3)+,d2
	cmp.b d0,d2
	blo .is_old_module
	cmp.b d1,d2
	bhi .is_old_module
	dbra d3,.chk_sig_exist_loop
	
	;;;;;;; not old module, try recognizing signature
	cmp.l #'M.K.',(a2) ;4-channel ids
	beq .is_4ch_31samp
	cmp.l #'M!K!',(a2)
	beq .is_4ch_31samp
	cmp.l #'FLT4',(a2)
	beq .is_4ch_31samp
	
	cmp.l #'OCTA',(a2) ;8-channel ids
	beq .is_8ch_31samp
	cmp.l #'CD81',(a2)
	beq .is_8ch_31samp
	;cmp.l #'FLT8',(a2) ;later! this one is fucked
	;beq .is_flt8
	
	;;;; no constants, try checking for ones with sample count numbers
	moveq #'0',d0 ;useful for later... (valid ascii number range)
	moveq #10,d1
	
	cmp.w #'CH',2(a2)
	beq .check_ch
	
	cmp.b #'C',1(a2)
	bne .no_check_chn
	cmp.w #'HN',2(a2)
	beq .check_chn
.no_check_chn
	
	cmp.w #'TD',(a2)
	bne .no_check_tdz
	cmp.b #'Z',(a2)
	beq .check_tdz
.no_check_tdz
	
.bad_module ;can't recognize header
	moveq #ERR_MPL_BAD_MODULE,d0
	rts
	
	
	;;;; sample count numbers
.check_ch
.get_2_digit_sample_count ;yyCH
	move.b (a2)+,d2
	sub.b d0,d2
	blo .bad_module
	cmp.b d1,d2
	bhs .bad_module
	move.b (a2)+,d3
	sub.b d0,d3
	blo .bad_module
	cmp.b d1,d3
	bhs .bad_module
	
	mulu.w d1,d2
	add.b d3,d2
	bra .got_channel_count
	
.check_tdz ;TDZx
	addq.l #3,a2
.check_chn ;xCHN
	move.b (a2)+,d2
	sub.b d0,d2
	blo .bad_module
	cmp.b d1,d2
	bhs .bad_module
	
.got_channel_count
	tst.b d2
	beq .bad_channel_count
	cmp.b #MPL_MAX_CHANNELS,d2
	bhi .bad_channel_count
	
	move.b d2,d0
	moveq #31,d1
	bra .got_module_type
	
.bad_channel_count ;channel count could be read, but out of range
	moveq #ERR_MPL_BAD_CHANNEL_COUNT,d0
	rts
	
.is_4ch_31samp
	moveq #4,d0
	moveq #31,d1
	bra .got_module_type
	
.is_8ch_31samp
	moveq #8,d0
	moveq #31,d1
	bra .got_module_type
	
	;;;;;;; no signature, old 4-channel 15-sample module
.is_old_module
.is_4ch_15samp
	moveq #4,d0
	moveq #15,d1
	
	;;;;;;;;;;;;;;;;;; got module type, set info
.got_module_type
	move.b d0,mpl_amt_channels(a6)
	move.b d1,mpl_amt_samples(a6)
	move.l a0,mpl_module_base_ptr(a6)
	move.l a1,mpl_samples_ptr(a6)
	
	lea $01d8(a0),a2
	cmp.b #15,d1
	beq .got_orderlist_ptr
	lea $03b8(a0),a2
.got_orderlist_ptr
	move.l a2,mpl_orderlist_ptr(a6)
	
	;;;;;;;;;;;;;;;;;; got orderlist ptr, get pattern count
	moveq #0,d2
	moveq #MPL_ORDERLIST_SIZE-1,d3
.orderlist_scan_loop
	move.b (a2)+,d4
	cmp.b d2,d4
	bls .not_higher_pattern
	move.b d4,d2
.not_higher_pattern
	dbra d3,.orderlist_scan_loop
	addq.w #1,d2
	
	;;;;;;;;;;;;;;;;; get patterns ptr
	cmp.b #15,d1
	beq .no_skip_m_k
	addq.l #4,a2
.no_skip_m_k
	move.l a2,mpl_patterns_ptr(a6)
	
	;;;;;;;;;;;;;;;;;; got pattern count, get sample data base
	;; (we also have the patterns pointer in a2)
	mulu.w d0,d2
	lsl.l #8,d2
	adda.l d2,a2
	move.l a2,mpl_sample_data_ptr(a6)
	
	
	
	
	
	
	
	
	
	;;;;;;;;;;;;;;;;;; set up our sample info structs
	;movea.l mpl_samples_ptr(a6),a1
	lea mpl_samples(a6),a2
	movea.l mpl_sample_data_ptr(a6),a3
	
	moveq #0,d2 ;current sample id
	moveq #0,d3 ;current sample addr
.sample_struct_setup_loop
	cmp.b d1,d2
	blo .sample_struct_setup_normal
	
.sample_struct_setup_blank
	clr.l (a2)+
	clr.l (a2)+
	clr.l (a2)+
	bra .sample_struct_setup_next
	
.sample_struct_setup_normal
	moveq #0,d4
	moveq #0,d5
	moveq #0,d6
	move.w mpl_mod_sample_length(a1),d4
	move.w mpl_mod_sample_loop_offset(a1),d5
	move.w mpl_mod_sample_loop_length(a1),d6
	lea mpl_mod_sample_SIZEOF(a1),a1
	
	tst.w d4 ;first check if there is any sample data at all
	beq .sample_struct_setup_blank
	cmp.l #$00010000,d3 ;are we past the end of pcm ram?
	bhs .too_much_sample_data ;yes, can't proceed
	move.l a3,(a2)+ ;ok, set sample data ptr
	
	cmp.w #1,d6 ;samples loop if their loop length is > 1 word
	bls .sample_struct_setup_no_loop
	
	;first do a sanity check for byte-loop points...
	;if loop_offset + loop_length > sample_size+16,
	;the loop offset is already in bytes
	;the 16 is for safety
	move.l d4,d0 ;(this overwrites the channel count but we don't care anymore)
	addq.l #8,d0
	addq.l #8,d0
	move.l d5,d7
	add.l d6,d7
	cmp.l d0,d7
	bhi .sample_struct_setup_loop_offset_in_bytes
	add.l d5,d5 ;loop offset to bytes
.sample_struct_setup_loop_offset_in_bytes
	add.l d4,d4 ;length to bytes
	add.l d6,d6 ;loop length to bytes
	
	;ok, now set up info
	add.l d5,d6 ;length (in looped samples, loop offset+len)
	move.l d6,(a2)+
	move.w d3,(a2)+ ;pcm addr
	move.l d3,d7 ;pcm loop
	add.l d5,d7
	move.w d7,(a2)+
	
	add.l d6,d3 ;next pcm-ram
	bra .sample_struct_setup_done
	
	
.sample_struct_setup_no_loop ;; no loop!
	
	add.l d4,d4 ;convert length to bytes
	move.l d4,(a2)+ ;length
	move.w d3,(a2)+ ;pcm addr
	add.l d4,d3 ;pcm loop (just point to the byte before stop-byte)
	subq.w #1,d3
	move.w d3,(a2)+
	addq.w #1,d3
	
.sample_struct_setup_done ;; done sample setup
	add.l d4,a3 ;step to next sample in data
	
	addq.l #1,d3 ;add one for stop-byte
	tst.b d3 ;if not page-aligned, align to next page
	beq .sample_struct_setup_next
	clr.b d3
	add.l #$100,d3
	
.sample_struct_setup_next
	addq.w #1,d2
	cmp.w #31,d2
	blo .sample_struct_setup_loop
	
	
	
	
	
	;;;;;;;;;;;;;;;;;;; upload sample data to the pcm ram
	
	lea mpl_samples(a6),a2
	lea pcm_cont,a3
	lea pcm_ram+1,a4
	
	moveq #MPL_MAX_SAMPLES-1,d0
.sample_upload_loop
	tst.l mpl_sample_ptr(a2)
	beq .sample_upload_next
	movea.l mpl_sample_ptr(a2),a5
	move.l mpl_sample_size(a2),d1
	move.w mpl_sample_addr(a2),d2
	
	moveq #12,d4 ;set up pcm bank
	move.w d2,d3
	lsr.w d4,d3
	move.b d3,(a3)
	
	and.w #$0fff,d2 ;set up pcm addr
	add.w d2,d2
	move.w #$2000,d4 ;end of pcm ram bank
	
	subq.w #1,d1
	moveq #$7f,d5
	moveq #$7e,d6
.sample_upload_byte_loop
	;mod-samples are signed 8-bit
	;these samples are magnitude-direction
	;bit 7: direction (1: add, 0: subtract)
	;bits 6-0: magnitude
	;so, turn $00-$7f into $80-$ff,
	;and turn $80-$ff into $7f-$00
	move.b (a5)+,d7
	
	cmp.b d7,d5 ;do not write premature $ff stop-bytes
	bne .sample_upload_no_clamp
	move.b d6,d7
.sample_upload_no_clamp
	
	bchg #7,d7 ;flip magnitude, and direction if needed
	beq .sample_upload_no_flip
	eor.b d5,d7
.sample_upload_no_flip
	move.b d7,(a4,d2)
	
	addq.w #2,d2 ;step pointer (and bank if needed)
	cmp.w d4,d2
	blo .sample_upload_byte_next
	moveq #0,d2
	addq.b #1,d3
	move.b d3,(a3)
.sample_upload_byte_next
	
	dbra d1,.sample_upload_byte_loop
	st (a4,d2) ;stop-byte
	
.sample_upload_next
	lea mpl_sample_SIZEOF(a2),a2
	dbra d0,.sample_upload_loop
	
	
	
	moveq #ERR_OK,d0
	rts
	
	
.too_much_sample_data
	moveq #ERR_MPL_TOO_MUCH_SAMPLE_DATA,d0
	rts
	
	
	
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; init routine
	;;
	;;
	;;
	;;
	;;
	
mpl_init
	bsr mpl_reset
	
	lea mpl_ram(pc),a6
	
	lea mpl_playback_state(a6),a0
	moveq #0,d0
	moveq #-1,d1
	moveq #1,d2
	moveq #MPL_DEFAULT_SPEED,d3
	moveq #MPL_DEFAULT_SPEED-1,d4
	moveq #MPL_PATTERN_ROWS-1,d5
	
	;;;;;;;;; global playback state
	lea mpl_tempo_tbl+(MPL_DEFAULT_TEMPO*2)(pc),a1
	move.b d2,(a0)+ ;timer irq cnt
	move.b (a1)+,_timerdata+1
	move.b (a1),(a0)+ ;timer irq cnt reload
	
	move.b d4,(a0)+ ;speed cnt
	move.b d3,(a0)+ ;speed
	
	move.b d1,(a0)+ ;current order
	move.b d5,(a0)+ ;current row
	
	move.l d0,(a0)+ ;current row ptr
	
	move.w d1,(a0)+ ;jump order/row
	
	move.w d0,(a0)+ ;EEx delay cnt/delaying flag
	
	move.w d0,(a0)+ ;E6x loop row/cnt
	
	move.b d1,pcm_ch ;channel disable
	move.w d1,(a0)+ ;^ / channel on flag
	
	;;;;;;;; channels
	lea mpl_initial_panning_tbl(pc),a1
	
	moveq #MPL_MAX_CHANNELS-1,d3
.channel_loop
	move.w d2,(a0)+ ;next period (1 avoids divide by 0 errors)
	move.w d2,(a0)+ ;period (1 avoids divide by 0 errors)
	move.l d0,(a0)+ ;arpcnt/finetune/toneporta/toneporta-direction
	move.l d0,(a0)+ ;vibrato/pos/shape/sample
	move.l d0,(a0)+ ;sample offset/delay/retrig/volume
	move.b (a1)+,(a0)+ ;panning
	move.b d0,(a0)+ ;tremolo
	move.l d0,(a0)+ ;tremolo pos/shape / effect
	
	dbra d3,.channel_loop
	
	
	
	
	bset.b #IEN3,_intmask
	rts
	
	
mpl_initial_panning_tbl
	dc.b $f7,$7f,$7f,$f7
	dc.b $f7,$7f,$7f,$f7 ;not sure about these last 4?
	
	
	
	
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; timer irq handler
	;;
	;;
	;;
	;;
	;;
	;;
	
mpl_timer_irq
	move.l a6,-(sp)
	lea mpl_ram(pc),a6
	subq.b #1,mpl_timer_irq_cnt(a6)
	bne .dont
	move.b mpl_timer_irq_reload(a6),mpl_timer_irq_cnt(a6)
	
	movem.l d0-d7/a0-a5,-(sp)
	bsr mpl_run_tick
	move.w mpl_current_order(a6),s_current_order
	movem.l (sp)+,d0-d7/a0-a5
	
.dont
	move.l (sp)+,a6
	rte
	
	
	
mpl_run_tick
	st mpl_channel_on_flag(a6)
	
	moveq #0,d6 ;this MUST stay throughout the entire routine
	move.b mpl_amt_channels(a6),d6
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; handle sequencer
	move.b mpl_speed_cnt(a6),d0 ;time for next row?
	addq.b #1,d0
	cmp.b mpl_speed(a6),d0
	blo .new_speed_cnt
	moveq #0,d0
	
	lea mpl_delay_cnt(a6),a0 ;EEx pattern delay active?
	tst.b (a0)
	beq .not_delaying_pattern
	st mpl_delaying(a6)
	subq.b #1,(a0)
	bra .new_speed_cnt
.not_delaying_pattern
	
	;;; stop any delaying channels
	sf mpl_delaying(a6)
	move.l d6,d7
	subq.w #1,d7
	lea mpl_channels(a6),a5
.stop_channel_delaying_loop
	clr.b mpl_chn_delay(a5)
	lea mpl_chn_SIZEOF(a5),a5
	dbra d7,.stop_channel_delaying_loop
	
	;;; load current position
	moveq #0,d1
	moveq #0,d2
	move.b mpl_current_row(a6),d1
	move.b mpl_current_order(a6),d2
	
	;;; do any jump effects, or proceed like normal?
	movea.l mpl_orderlist_ptr(a6),a1
	move.b mpl_position_jump_order(a6),d3
	move.b mpl_position_jump_row(a6),d4
	moveq #MPL_PATTERN_ROWS,d5
	cmp.b -2(a1),d3
	blo .do_position_jump
	cmp.b d5,d4
	bhs .next_row
	
	;;; no new order but valid row, update row and step to next pattern
.do_pattern_break
	st mpl_position_jump_row(a6)
	move.b d4,d1
.next_order
	addq.b #1,d2
	cmp.b -2(a1),d2
	blo .recalculate_row_ptr
	moveq #0,d2
	bra .recalculate_row_ptr
	
	;;; new order, go there and check for valid row
.do_position_jump
	st mpl_position_jump_order(a6)
	moveq #0,d1
	move.b d3,d2
	cmp.b d5,d4
	bhs .recalculate_row_ptr
	st mpl_position_jump_row(a6)
	move.b d4,d1
	bra .recalculate_row_ptr
	
	;;; normal, go to next row (and order if needed)
.next_row
	addq.b #1,d1
	cmp.b d5,d1
	blo .step_row_ptr
	moveq #0,d1
	bra .next_order
	
	;;; just advancing pattern, step the row pointer to the next row
.step_row_ptr
	move.l d6,d3
	lsl.b #2,d3
	add.l d3,mpl_current_row_ptr(a6)
	bra .new_current_row
	
	;;; some complicated jump happened, need to recalculate pattern row ptr
.recalculate_row_ptr
	moveq #0,d3 ;get current pattern number
	move.b (a1,d2),d3
	
	lsl.w #6,d3 ;get "overall" row number (pattern*PATTERN_SIZE + current_row)
	add.w d1,d3
	
	movea.l mpl_patterns_ptr(a6),a0 ;actual pointer
	mulu.w d6,d3
	lsl.l #2,d3
	add.l d3,a0
	move.l a0,mpl_current_row_ptr(a6)
	
.new_current_order
	move.b d2,mpl_current_order(a6)
.new_current_row
	move.b d1,mpl_current_row(a6)
.new_speed_cnt
	move.b d0,mpl_speed_cnt(a6)
	
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; main channel loop
	
	moveq #0,d7
	lea mpl_channels(a6),a5
	lea rf5c164,a4
.channel_loop	
	move.b d7,d0 ;set up write on the pcm chip
	or.b #$c0,d0
	move.b d0,pcm_cont-rf5c164(a4)
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; read pattern?
	
	move.b mpl_chn_delay(a5),d0
	cmp.b mpl_speed_cnt(a6),d0
	bne .channel_not_first_tick
	
	tst.b mpl_delaying(a6)
	bne .channel_not_first_tick
	
	movea.l mpl_current_row_ptr(a6),a0
	move.l d7,d0
	lsl.w #2,d0
	add.l d0,a0
	
	;;;;;; get effect
	move.w 2(a0),d0
	and.w #$fff,d0
	move.w d0,mpl_chn_effect(a5)
	move.w d0,d1 ;special case for delay EDx-if we're delaying, STOP reading right now
	and.w #$ff0,d1
	cmp.w #$ed0,d1
	bne .channel_pattern_no_delay
	and.b #$0f,d0
	beq .channel_pattern_no_delay
	move.b d0,mpl_chn_delay(a5)
	bra .channel_not_first_tick
.channel_pattern_no_delay
	
	;;;;;; get sample number
	moveq #0,d0
	move.b 0(a0),d0
	and.b #$f0,d0
	move.b 2(a0),d1
	lsr.b #4,d1
	or.b d1,d0
	beq .channel_pattern_no_sample
	
	subq.b #1,d0 ;we offset samples from 0...
	move.b d0,mpl_chn_sample(a5)
	
	movea.l mpl_samples_ptr(a6),a1 ;get sample infos
	move.l d0,d1
	mulu.w #mpl_mod_sample_SIZEOF,d1
	add.l d1,a1
	move.b mpl_mod_sample_volume(a1),mpl_chn_volume(a5)
	move.b mpl_mod_sample_finetune(a1),mpl_chn_finetune(a5)
	
	mulu.w #mpl_sample_SIZEOF,d0 ;set up sample on pcm chip
	lea mpl_samples(a6),a1
	add.l d0,a1
	
	move.b mpl_sample_addr(a1),d0 ;...addr
	cmp.b #9,mpl_chn_effect(a5) ;special case for sample offset 9xx
	bne .no_sample_offset
	move.b mpl_chn_effect_param(a5),d1
	beq .recall_sample_offset
	move.b d1,mpl_chn_sample_offset(a5)
	bra .got_sample_offset
.recall_sample_offset
	move.b mpl_chn_sample_offset(a5),d1
.got_sample_offset
	add.b d1,d0
.no_sample_offset
	move.b d0,pcm_st-rf5c164(a4)
	
	move.w mpl_sample_loop_addr(a1),d0 ;...loop addr
	rol.w #8,d0
	movep.w d0,pcm_lsl-rf5c164(a4)
	
.channel_pattern_no_sample
	
	
	;;;;;; special case for E5x, ensure finetune is set correctly
	;; before setting the next period
	cmp.b #$0e,mpl_chn_effect(a5)
	bne .channel_pattern_no_finetune
	move.b mpl_chn_effect_param(a5),d0
	move.b d0,d1
	and.b #$f0,d0
	cmp.b #$50,d0
	bne .channel_pattern_no_finetune
	and.b #$0f,d0
	move.b d0,mpl_chn_finetune(a5)
.channel_pattern_no_finetune
	
	
	;;;;;;; get period
	move.w 0(a0),d0
	and.w #$0fff,d0
	beq .channel_pattern_no_period
	
	moveq #0,d1 ;effect by finetune
	move.b mpl_chn_finetune(a5),d1
	add.b d1,d1
	lea mpl_finetune_tbl(pc),a1
	move.w (a1,d1),d1
	mulu.w d1,d0
	add.l d0,d0
	swap d0
	move.w d0,mpl_chn_next_period(a5)
	
	move.b #1,mpl_chn_retrig_cnt(a5)
.channel_pattern_no_period
	
	;;;;;; execute effect first tick
	bsr .eff_first_tick
	bra .channel_main
	
.channel_not_first_tick
	;;;;;; not first tick, execute effect main
	bsr .eff_main
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; done with pattern, do main channel stuff
.channel_main
	
	;;;;;;;;;;;;;;;;; need to retrig?
	lea mpl_chn_retrig_cnt(a5),a0
	tst.b (a0)
	beq .not_retrigging
	subq.b #1,(a0)
	bne .not_retrigging
	
	lea mpl_channel_disable(a6),a0 ;turn channel off and signal later keyon
	move.b (a0),d0
	bset d7,d0
	move.b d0,pcm_ch-rf5c164(a4)
	move.b d0,(a0)+
	bclr.b d7,(a0)
	
	move.w mpl_chn_next_period(a5),mpl_chn_period(a5) ;reset period
	
	btst.b #2,mpl_chn_vibrato_shape(a5) ;reset vibrato/tremolo phase, if needed
	bne .no_reset_vibrato_pos
	clr.b mpl_chn_vibrato_pos(a5)
.no_reset_vibrato_pos
	btst.b #2,mpl_chn_tremolo_shape(a5)
	bne .no_reset_tremolo_pos
	clr.b mpl_chn_tremolo_pos(a5)
.no_reset_tremolo_pos
	
	
.not_retrigging
	
	
	
	;;;;;;;;;;;;;;;;;;;; set volume (applying tremolo if using)
	;; this doesn't span the entire 8-bit volume range
	;; but is loud enough to my ears
	
	moveq #0,d0
	cmp.b #7,mpl_chn_effect(a5)
	bne .got_tremolo_delta
	lea mpl_chn_tremolo(a5),a0
	bsr mpl_get_waveform_delta
	asr.w #6,d0
.got_tremolo_delta
	
	moveq #0,d1
	move.b mpl_chn_volume(a5),d1
	add.w d1,d0
	bmi .clamp_volume_0
	move.w #$40,d1
	cmp.w d1,d0
	bls .got_final_volume
	move.w d1,d0
	bra .got_final_volume
.clamp_volume_0
	moveq #0,d0
.got_final_volume
	add.b d0,d0
	move.b d0,pcm_vol-rf5c164(a4)
	
	
	;;;;;;;;;;;;;;;;;;;;; set panning
	
	move.b mpl_chn_panning(a5),pcm_pan-rf5c164(a4)
	
	
	;;;;;;;;;;;;;;;;;;;;; set period (applying vibrato/arpeggio if using)
	
	
	;;;;;; get vibrato'ed period
	moveq #0,d0
	move.b mpl_chn_effect(a5),d1
	cmp.b #4,d1
	beq .get_vibrato_delta
	cmp.b #6,d1
	bne .got_vibrato_delta
.get_vibrato_delta
	lea mpl_chn_vibrato(a5),a0
	bsr mpl_get_waveform_delta
	asr.w #7,d0
.got_vibrato_delta
	add.w mpl_chn_period(a5),d0
	
	
	
	;;;;;;; get arpeggio'ed frequency
	moveq #0,d1
	tst.b mpl_chn_effect(a5)
	bne .not_arpeggio
	move.b mpl_chn_arp_cnt(a5),d2
	beq .not_arpeggio
	move.b mpl_chn_effect_param(a5),d1
	subq.b #1,d2
	bne .arpeggio_2
	lsr.b #4,d1
.arpeggio_2
	andi.b #$0f,d1
	lsl.b #2,d1
.not_arpeggio
	lea mpl_fd_magic_constant_tbl(pc),a0
	move.l (a0,d1),d1
	divu.w d0,d1
	
	;; round the frequency - some chiptunes are noticeably detuned if this is not done
	;; round up if remainder >= period/2
	lsr.w #1,d0
	move.l d1,d2
	swap d2
	cmp.w d0,d2
	blo .no_round_up_frequency
	addq.w #1,d1
.no_round_up_frequency
	rol.w #8,d1
	movep.w d1,pcm_fdl-rf5c164(a4)
	
	
	
	
	
.channel_done
	lea mpl_chn_SIZEOF(a5),a5
	addq.b #1,d7
	cmp.b d6,d7
	blo .channel_loop
	
	
	
	
	
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; key-on channels?
	
	lea mpl_channel_disable(a6),a0
	move.b (a0)+,d0
	and.b (a0),d0
	move.b d0,-(a0)
	move.b d0,pcm_ch-rf5c164(a4)
	
	
	rts
	
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; effect handlers
	;;
	;; all routines expect pointer to ram in a6,
	;; channel number in d7, channel struct in a5
	;; effect parameter in d0, cpu flags must be set accordingly
	
	;;;;;;;;;;;;;;;;;; first tick jumproutine
	
.eff_first_tick
	moveq #0,d1
	move.b mpl_chn_effect(a5),d1
	lsl.b #2,d1
	moveq #0,d0
	move.b mpl_chn_effect_param(a5),d0
	jmp .eff_first_tick_tbl(pc,d1.w)
.eff_first_tick_tbl
	bra.w .eff_arpeggio_first_tick	;0xx arpeggio
	bra.w .eff_null	;1xx portamento up
	bra.w .eff_null	;2xx portamento down
	bra.w .eff_toneporta_first_tick ;3xx toneportamento
	bra.w .eff_vibrato_first_tick ;4xx vibrato
	bra.w .eff_toneporta_first_tick_recall ;5xx toneportamento + volume slide
	bra.w .eff_null ;6xx vibrato + volume slide
	bra.w .eff_tremolo_first_tick ;7xx tremolo
	bra.w .eff_panning ;8xx panning
	bra.w .eff_sample_offset ;9xx sample offset
	bra.w .eff_null ;Axx volume slide
	bra.w .eff_position_jump ;Bxx position jump
	bra.w .eff_volume ;Cxx volume
	bra.w .eff_pattern_break ;Dxx pattern break
	bra.w .eff_e_first_tick ;Exy extended
	bra.w .eff_tempo ;Fxx speed/tempo
	
.eff_e_first_tick
	move.w d0,d1
	and.b #$f0,d1
	lsr.b #2,d1
	and.b #$0f,d0
	jmp .eff_e_first_tick_tbl(pc,d1.w)
.eff_e_first_tick_tbl
	bra.w .eff_null ;E0x set filter (we don't have one!)
	bra.w .eff_porta_up ;E1x fine portamento up
	bra.w .eff_porta_down ;E2x fine portamento down
	bra.w .eff_null ;E3x glissando (will never be supported)
	bra.w .eff_vibrato_shape ;E4x set vibrato waveform
	bra.w .eff_finetune	;E5x set finetune
	bra.w .eff_pattern_loop ;E6x pattern loop
	bra.w .eff_tremolo_shape ;E7x set tremolo shape
	bra.w .eff_coarse_panning ;E8x panning
	bra.w .eff_retrigger ;E9x retrigger
	bra.w .eff_volume_slide_up ;EAx fine volume slide up
	bra.w .eff_volume_slide_down ;EBx fine volume slide up
	bra.w .eff_note_cut ;ECx note cut
	bra.w .eff_null ;EDx note delay
	bra.w .eff_pattern_delay ;EEx pattern delay
	bra.w .eff_null ;EFx invert loop (will never be supported)
	
	
	
	
	;;;;;;;;;;;;;;;;;;; main jumproutine
	
.eff_main
	moveq #0,d1
	move.b mpl_chn_effect(a5),d1
	lsl.b #2,d1
	moveq #0,d0
	move.b mpl_chn_effect_param(a5),d0
	jmp .eff_main_tbl(pc,d1.w)
.eff_main_tbl
	bra.w .eff_arpeggio	;0xx arpeggio
	bra.w .eff_porta_up	;1xx portamento up
	bra.w .eff_porta_down	;2xx portamento down
	bra.w .eff_toneporta ;3xx toneportamento
	bra.w .eff_vibrato ;4xx vibrato
	bra.w .eff_toneporta_volume_slide ;5xx toneportamento + volume slide
	bra.w .eff_vibrato_volume_slide ;6xx vibrato + volume slide
	bra.w .eff_tremolo ;7xx tremolo
	bra.w .eff_null ;8xx panning
	bra.w .eff_null ;9xx sample offset
	bra.w .eff_volume_slide ;Axx volume slide
	bra.w .eff_null ;Bxx position jump
	bra.w .eff_null ;Cxx volume
	bra.w .eff_null ;Dxx pattern break
	bra.w .eff_e_main ;Exy extended
	bra.w .eff_null ;Fxx speed/tempo
	
.eff_e_main
	move.w d0,d1
	and.b #$f0,d1
	lsr.b #2,d1
	and.b #$0f,d0
	jmp .eff_e_main_tbl(pc,d1.w)
.eff_e_main_tbl
	bra.w .eff_null ;E0x set filter (we don't have one!)
	bra.w .eff_null ;E1x fine portamento up
	bra.w .eff_null ;E2x fine portamento down
	bra.w .eff_null ;E3x glissando (will never be supported)
	bra.w .eff_null ;E4x set vibrato waveform
	bra.w .eff_null	;E5x set finetune
	bra.w .eff_null ;E6x pattern loop
	bra.w .eff_null ;E7x set tremolo shape
	bra.w .eff_null ;E8x panning
	bra.w .eff_retrigger ;E9x retrigger
	bra.w .eff_null ;EAx fine volume slide up
	bra.w .eff_null ;EBx fine volume slide up
	bra.w .eff_note_cut ;ECx note cut
	bra.w .eff_null ;EDx note delay
	bra.w .eff_null ;EEx pattern delay
	bra.w .eff_null ;EFx invert loop (will never be supported)
	
	
	
	
	;;;;;;;;;;;;;;;;; arpeggio effect
	
.eff_arpeggio_first_tick
	clr.b mpl_chn_arp_cnt(a5)
.eff_null
	rts
	
.eff_arpeggio
	lea mpl_chn_arp_cnt(a5),a0
	move.b (a0),d0
	addq.b #1,d0
	cmp.b #3,d0
	blo .eff_no_arpeggio_wrap
	moveq #0,d0
.eff_no_arpeggio_wrap
	move.b d0,(a0)
	rts
	
	
	
	;;;;;;;;;;;;;;;;;;; (tone)portamento effects
	
.eff_toneporta_first_tick
	tst.b d0
	beq .eff_toneporta_first_tick_recall
.eff_toneporta_first_tick_no_recall
	move.b d0,mpl_chn_toneporta(a5)
	bra .eff_toneporta_first_tick_get_direction
.eff_toneporta_first_tick_recall
	move.b mpl_chn_toneporta(a5),d0
.eff_toneporta_first_tick_get_direction
	;if period >= next period, direction = 0, going up
	;if period < next period, direction = $ff, going down
	move.w mpl_chn_period(a5),d0
	cmp.w mpl_chn_next_period(a5),d0
	slo mpl_chn_toneporta_direction(a5)
	
	clr.b mpl_chn_retrig_cnt(a5) ;don't retrigger!
	rts
	
	
.eff_toneporta_volume_slide
	bsr .eff_volume_slide
.eff_toneporta
	lea mpl_chn_next_period(a5),a0
	move.w (a0)+,d2
	
	move.b mpl_chn_toneporta(a5),d0
	
	tst.b mpl_chn_toneporta_direction(a5)
	beq .eff_porta_up_got_limit
.eff_toneporta_down
	move.w (a0),d1
	add.w d0,d1
	bcs .eff_toneporta_down_clamp
	cmp.w d2,d1
	blo .eff_toneporta_down_no_clamp
.eff_toneporta_down_clamp
	move.w d2,d1
.eff_toneporta_down_no_clamp
	move.w d1,(a0)
	rts
	
	
	
	
.eff_porta_up
	move.w #MPL_MINIMUM_PERIOD,d2
	lea mpl_chn_period(a5),a0
.eff_porta_up_got_limit
	move.w (a0),d1
	sub.w d0,d1
	bcs .eff_porta_up_clamp
	cmp.w d2,d1
	bhs .eff_porta_up_no_clamp
.eff_porta_up_clamp
	move.w d2,d1
.eff_porta_up_no_clamp
	move.w d1,(a0)
	rts
	
.eff_porta_down
	lea mpl_chn_period(a5),a0
	add.w d0,(a0)
	bcc .eff_porta_down_no_clamp
	move.w #$ffff,(a0)
.eff_porta_down_no_clamp
	rts
	
	
	
	
	;;;;;;;;;;;;;;;;;;; vibrato/tremolo effects
	;; actual effecting of the period/volume is done before
	;; writing them to the pcm chip
	
.eff_vibrato_first_tick
	tst.b d0
	beq .eff_vibrato_first_tick_no_reset
	move.b d0,mpl_chn_vibrato(a5)
.eff_vibrato_first_tick_no_reset
	rts
	
.eff_tremolo_first_tick
	tst.b d0
	beq .eff_tremolo_first_tick_no_reset
	move.b d0,mpl_chn_tremolo(a5)
.eff_tremolo_first_tick_no_reset
	rts
	
	
	
.eff_vibrato_volume_slide
	bsr .eff_volume_slide
.eff_vibrato
	lea mpl_chn_vibrato(a5),a0
	bra .eff_waveform
.eff_tremolo
	lea mpl_chn_tremolo(a5),a0
.eff_waveform
	move.b (a0)+,d0
	and.b #$f0,d0
	lsr.b #4,d0
	add.b d0,(a0)
	rts
	
	
	
.eff_vibrato_shape
	move.b d0,mpl_chn_vibrato_shape(a5)
	rts
	
.eff_tremolo_shape
	move.b d0,mpl_chn_tremolo_shape(a5)
	rts
	
	
	
	;;;;;;;;;;;;;;;;;;; volume (slide) effects
	
.eff_volume
	lea mpl_chn_volume(a5),a0
	move.b d0,d1
	bra .eff_volume_slide_up_skip
	
.eff_volume_slide
	cmp.b #$10,d0
	bhs .eff_volume_slide_up_shr
	and.b #$0f,d0
.eff_volume_slide_down
	lea mpl_chn_volume(a5),a0
	move.b (a0),d1
	sub.b d0,d1
	bcc .eff_volume_slide_set
	moveq #0,d1
	move.b d1,(a0)
	rts
	
.eff_volume_slide_up_shr
	lsr.b #4,d0
.eff_volume_slide_up
	lea mpl_chn_volume(a5),a0
	move.b (a0),d1
	add.b d0,d1
.eff_volume_slide_up_skip
	moveq #MPL_MAX_VOLUME,d2
	cmp.b d2,d1
	bls .eff_volume_slide_set
	move.b d2,d1
.eff_volume_slide_set
	move.b d1,(a0)
	rts
	
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;; panning effects
	
.eff_coarse_panning:
	lsl.b #4,d0
	
.eff_panning:
	lea mpl_chn_panning(a5),a0
	tst.b d0
	bmi .eff_panning_right
.eff_panning_left
	add.b d0,d0
	and.b #$f0,d0
	or.b #$0f,d0
	move.b d0,(a0)
	rts
	
.eff_panning_right
	eor.b #$ff,d0
	lsr.b #3,d0
	and.b #$0f,d0
	or.b #$f0,d0
	move.b d0,(a0)
	rts
	
	
	
	
	
	
	;;;;;;;;;;;;;;;;;; control effects
	
	
	;; we already implement this in the sample write handler
	;; in the pattern reader, but we have this here too so a
	;; 9xx effect without a note still writes to the memory
.eff_sample_offset
	tst.b d0
	beq .eff_no_sample_offset
	move.b d0,mpl_chn_sample_offset(a5)
.eff_no_sample_offset
	rts
	
	
	
.eff_position_jump
	move.b d0,mpl_position_jump_order(a6)
	rts
	
.eff_pattern_break
	move.w d0,d1
	and.b #$f0,d1
	lsr.b #4,d1
	mulu.w #10,d1
	and.b #$0f,d0
	add.b d1,d0
	move.b d0,mpl_position_jump_row(a6)
	rts
	
	
	
.eff_tempo
	cmp.b #$20,d0
	blo .eff_speed
	add.w d0,d0
	lea mpl_tempo_tbl(pc),a0
	add.l d0,a0
	move.b (a0)+,_timerdata+1
	move.b (a0),d0
	lea mpl_timer_irq_cnt(a6),a0
	move.b d0,(a0)+
	move.b d0,(a0)
	rts
	
.eff_speed
	move.b d0,mpl_speed(a6)
	rts
	
	
	
	
	
	
	;;;;;;;;;;;;;;;;;;;; other extended effects
	
	
	
	;; already implemented in pattern reader after sample reading
	;; but before period write, but is again here so disconnected
	;; effects still work
.eff_finetune
	move.b d0,mpl_chn_finetune(a5)
	rts
	
	
	
.eff_pattern_loop
	tst.b d0
	beq .eff_reset_pattern_loop
	lea mpl_loop_cnt(a6),a0
	tst.b (a0)
	beq .eff_new_pattern_loop
	subq.b #1,(a0)
	bne .eff_do_pattern_loop
	rts
	
.eff_new_pattern_loop
	move.b d0,(a0)
.eff_do_pattern_loop
	move.b mpl_current_order(a6),mpl_position_jump_order(a6)
	move.b mpl_loop_row(a6),mpl_position_jump_row(a6)
	rts
	
.eff_reset_pattern_loop
	move.b mpl_current_row(a6),mpl_loop_row(a6)
	rts
	
	
	
	
.eff_retrigger
	lea mpl_chn_retrig_cnt(a5),a0
	tst.b (a0)
	bne .eff_no_retrigger
	move.b d0,(a0)
.eff_no_retrigger
	rts
	
	
	
	
.eff_note_cut
	cmp.b mpl_speed_cnt(a6),d0
	bne .eff_no_note_cut
	lea mpl_chn_volume(a5),a0
	clr.b (a0)+
	clr.b (a0)
.eff_no_note_cut
	rts
	
	
	
	
.eff_pattern_delay
	move.b d0,mpl_delay_cnt(a6)
	rts
	
	
	
	
	
	
	
	;; used for vibrato and tremolo
	; pointer to waveform struct in a0
	;	0(a0).b - lower nybble is depth
	;	1(a0).b - phase
	;	2(a0).b - shape
	; returns final delta in d0
	
mpl_get_waveform_delta
	moveq #0,d1
	move.b 2(a0),d1
	and.b #$03,d1
	add.b d1,d1
	
	moveq #0,d0
	jmp .wf_tbl(pc,d1.w)
	
.wf_tbl
	bra.s .sine
	bra.s .ramp
	bra.s .square
	bra.s .sine	;noise not implemented
	
.square
	st d0
	btst.b #5,1(a0)
	bne .got
	neg.w d0
	bra .got
	
.ramp
	move.b #255,d0
	move.b 1(a0),d1
	and.b #$3f,d1
	lsl.w #3,d1
	sub.b d1,d0
	bra .got
	
.sine
	move.b 1(a0),d0
	and.b #$1f,d0
	move.b .sine_tbl(pc,d0.w),d0
	btst.b #5,1(a0)
	beq .got
	neg.w d0
	
.got
	move.b 0(a0),d1
	and.b #$0f,d1
	muls.w d1,d0
	rts
	
	
.sine_tbl
	db 0,24,49,74,97,120,141,161
	db 180,197,212,224,235,244,250,253
	db 255,253,250,244,235,224,212,197
	db 180,161,141,120,97,74,49,24
	
	
	
	
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;
	
	include sub-mod-player-data.asm
	
	
	
mpl_ram
	ds.b mpl_SIZEOF