	include MD.I
	include MAINCPU.INC
	include gen.inc
	
	include main-sub-comms.asm
	
	include cd-access-constants.asm
	include mod-player-constants.asm
	
	
	;; vram addresses
BG_A_BASE = $c000
BG_B_BASE = $e000
WINDOW_BASE = $a000
SAT_BASE = $b000
HSCROLL_BASE = $bc00
	
	
	org $ffff0000
	incbin security-u.bin
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; initialization
	
reset
	
	lea main_flug,a0
	moveq #0,d0
	move.w d0,(a0)+ ;that also writes to sub_flug but doesn't matter
	move.l d0,(a0)+
	move.l d0,(a0)+
	move.l d0,(a0)+
	move.l #M_READY_VALUE,(a0)+
	
	move.w #$0100,z_brq ;kill z80
	move.w d0,z_res
	
	;;;;;;;;;;;; video initialization
	
	move.w d0,dma_list ;preinit dma list
	
	lea _vdpdata,a1
	lea 4(a1),a0
	move.w #$8134,(a0) ;disable display, enable dma
	
	move.l #$82008300|(BG_A_BASE>>13<<3<<16)|(WINDOW_BASE>>11<<1),(a0)
	move.l #$84008500|(BG_B_BASE>>13<<16)|(SAT_BASE>>9),(a0)
	move.w #$8d00|(HSCROLL_BASE>>10),(a0)
	
	;;;; make alternate copies of the system font
	
	;; copy to ram
	
	lea dma_data_buf,a5
	move.l #VRAM_READ,(a0)
	move.w #($1000/4)-1,d7
.font_to_ram_loop
	move.l (a1),(a5)+
	dbra d7,.font_to_ram_loop
	
	;; 
	
	move.l #VRAM_WRITE|($1000<<16),(a0)
	move.l #$11111111,d6
	
	;; inverted
	
	lea dma_data_buf,a5
	move.w #($1000/4)-1,d7
.font_1_loop
	move.l (a5)+,d0
	eor.l d6,d0
	move.l d0,(a1)
	dbra d7,.font_1_loop
	
	;; shifted
	
	lea dma_data_buf,a5
	move.w #($1000/4)-1,d7
.font_2_loop
	move.l (a5)+,d0
	add.l d6,d0
	move.l d0,(a1)
	dbra d7,.font_2_loop
	
	;; inverted/shifted
	
	lea dma_data_buf,a5
	move.w #($1000/4)-1,d7
.font_3_loop
	move.l (a5)+,d0
	eor.l d6,d0
	add.l d6,d0
	move.l d0,(a1)
	dbra d7,.font_3_loop
	
	;;;; clear rest of vram
	
	move.l #$8f019780,(a0) ;increment 1, fill mode dma
	move.l #$94c09300,(a0) ;length
	move.l #VRAM_DMA|1,(a0)
	move.w #0,(a1)
.vram_clear_wait
	btst.b #1,1(a0) ;wait until done
	bne .vram_clear_wait
	
	;;;; init palettes
	
	move.l #$8f029700|((palette_data&$fe0000)>>17),(a0) ;increment 2, hi-source
	move.l #$96009500|((palette_data&$1fe00)<<7)|((palette_data&$1fe)>>1),(a0) ;lo-source
	move.l #$94009340,(a0) ;length
	move.l #CRAM_DMA,(a0)
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; main
	
	move #$2700,sr
	
	move.w #$8164,(a0) ;enable display, disable dma
	
	move.w #JMP_CODE,_mlevel6
	move.l #vblank_irq,_mlevel6+2
	
	clr.b vblank_flag
	move.l #mode_load_dir,mode_ptr
	
	tst.w (a0)
	;move #$2000,sr
	
.loop
	stop #$2000
	bra .loop
	

	
	



vblank_irq
	tst.b vblank_flag
	bne .skip
	movem.l d0-d7/a0-a6,-(sp)
	addq.b #1,vblank_flag
	move #$2000,sr	
	
	;;;;;;;;;;;; handle video and dma-list
	
	lea _vdpdata,a1
	lea 4(a1),a0
	
	move.w #$8f02,(a0) ;increment 2
	
	move.l #VSRAM_WRITE,(a0) ;set scrolling
	move.l vscroll_a(pc),(a1)
	move.l #VRAM_WRITE|((HSCROLL_BASE&$c000)>>14)|((HSCROLL_BASE&$3fff)<<16),(a0)
	move.l hscroll_a(pc),(a1)
	
	moveq #0,d0
	move.w window_h(pc),d0
	lsl.l #8,d0
	lsr.w #8,d0
	or.l #$91009200,d0
	move.l d0,(a0)
	
	move.w #$8134,(a0) ;disable display, enable dma
	
	lea dma_list(pc),a6
.dma_list_loop
	moveq #0,d0 ;dma length
	move.w (a6)+,d0
	beq .dma_list_done
	lsl.l #8,d0
	lsr.w #8,d0
	or.l #$94009300,d0
	move.l d0,(a0)
	
	move.l (a6)+,d0 ;fill or 68k->vram?
	bmi .dma_list_vram_fill
	
	lsr.l #1,d0 ;source address (bytes->words)
	move.l d0,d1
	lsl.l #8,d0
	lsr.w #8,d0
	and.l #$00ff00ff,d0
	or.l #$96009500,d0
	move.l d0,(a0)
	move.w #$8f02,d1	;(and increment $02)
	swap d1
	and.w #$00ff,d1
	or.w #$9700,d1
	move.l d1,(a0)
	
	moveq #0,d0 ;dest address
	move.w (a6)+,d0
	lsl.l #2,d0
	lsr.w #2,d0
	swap d0
	or.l #VRAM_DMA,d0
	move.l d0,(a0) ;(now dma takes over)
	
	bra .dma_list_loop
	
	
.dma_list_vram_fill
	move.l #$8f019780,(a0) ;increment $01, fill mode dma
	
	lsl.l #2,d0 ;dest address
	lsr.w #2,d0
	swap d0
	and.l #$3fff0003,d0
	or.l #VRAM_DMA,d0
	move.l d0,(a0)
	
	move.w (a6)+,(a1) ;data
	
.dma_list_vram_fill_wait
	btst.b #1,1(a0) ;wait until done
	bne .dma_list_vram_fill_wait
	
	bra .dma_list_loop
	
.dma_list_done
	
	move.w #$8164,(a0) ;enable display, disable dma
	clr.w dma_list
	
	
	;;;;;;;;;;;; read joypad
	
	lea PORT1DATA,a0
	lea rawjoy(pc),a1
	move.b #$40,(a0)
	nop
	nop
	nop
	nop
	move.b (a0),d0
	move.b #$00,(a0)
	and.b #$3f,d0
	nop
	nop
	move.b (a0),d1
	
	lsl.b #2,d1
	and.b #$c0,d1
	or.b d1,d0
	not.b d0
	
	move.b (a1),d1
	move.b d0,(a1)
	
	not.b d1
	and.b d1,d0
	move.b d0,1(a1)
	
	
	
	;;;;;;;;;;;; execute mainroutine
	
mode_ptr=*+2
	jsr mode_load_dir.l
	
	subq.b #1,vblank_flag
	movem.l (sp)+,d0-d7/a0-a6
.skip
	tst.w _vdpdata+4
	rte
	
	
	
	
	
	;;;;;;;;; joypad
rawjoy
	dc.b $ff
joy
	dc.b $00
	
	
	
	
	;;;;;;;;; video settings
vblank_flag
	dc.b 0
	dc.b 0
	
hscroll_a
	dc.w 0
hscroll_b
	dc.w 0
	
vscroll_a
	dc.w 0
vscroll_b
	dc.w 0
	
window_h
	dc.b 0
window_v
	dc.b 0
	
	
	
	;;;;; dma transfer list
	;; for each entry:
	;;	word - transfer length (0 terminates)
	;;	long - source address (or dest address for vram fill if high bit set)
	;;	word - dest address (or data for vram fill)
dma_list
	ds.b $200
	
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;
	;; video routines
	;;
	;;
	;;
	;;
	
dma_clear_screen
	move.w #$5000,(a6)+
	move.l #WINDOW_BASE|(1<<31),(a6)+
	clr.w (a6)+
	
init_video_settings
	clr.l hscroll_a
	clr.l vscroll_a
	clr.w window_h
	rts
	
	
dma_centered_error_message
	add.w d0,d0
	move.w error_message_tbl(pc,d0.w),d0
	lea error_messages(pc,d0.w),a0
	
dma_centered_text
	;; get string length and copy to dma-data buffer
	movea.l a5,a1
	
	moveq #0,d0
	moveq #0,d1
.copy_loop
	move.b (a0)+,d0
	beq .copy_done
	move.w d0,(a5)+
	addq.w #1,d1
	bra .copy_loop
.copy_done
	
	;; add to dma list
	move.w d1,(a6)+
	move.l a1,(a6)+
	
	move.w #40,d0
	sub.w d1,d0
	bclr #0,d0
	add.w #BG_A_BASE+(14*64*2),d0
	move.w d0,(a6)+
	
	rts
	
	
	
	
	
	
error_message_tbl
	dw emsg_00-error_messages
	dw emsg_01-error_messages
	dw emsg_02-error_messages
	dw emsg_03-error_messages
	dw emsg_04-error_messages
	dw emsg_05-error_messages
	dw emsg_06-error_messages
	dw emsg_07-error_messages
	dw emsg_08-error_messages
	dw emsg_09-error_messages
	dw emsg_10-error_messages
	
error_messages
emsg_00	db "OK",0
emsg_01	db "Tray open",0
emsg_02	db "Read error",0
emsg_03	db "No valid directory",0
emsg_04	db "Directory too large",0
emsg_05	db "Too many files",0
emsg_06	db "No such file",0
emsg_07	db "No module",0
emsg_08	db "Bad module",0
emsg_09	db "Bad channel count",0
emsg_10	db "Too much sample data",0

	align 2
	
	
palette_data	incbin out/main-palette.bin
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;
	;; cpu communication routines
	;;
	;;
	;;
	;;
	
	
send_wait_command
	pea wait_command(pc)
	
	;;;;;;; send command, id in d0, param in d1
send_command
	lea command_0,a0 ;send info
	move.w d0,(a0)+
	move.w d1,(a0)+
	
	bset.b #COMM_REQ,main_flug ;signal request
	bset.b #DMNA,_memory ;give word-ram back
	rts
	
	
	
	;;;;;;;; wait for subcpu to finish a command, then acknowledge
wait_command
	lea main_flug,a0
	lea 1(a0),a1
	moveq #(1<<COMM_BUSY)|(1<<COMM_ACK),d1 ;mask
	moveq #(1<<COMM_ACK),d2 ;finish indicator
.loop
	move.b (a1),d0
	and.b d1,d0
	cmp.b d2,d0
	bne .loop
	
	;; ok, acknowledge
	move.b (a0),d0
	bclr #COMM_REQ,d0
	bset #COMM_ACK,d0
	move.b d0,(a0)
	
	move.w s_cmd_status,d0 ;get status
	
	;; wait until the sub-cpu knows
.wait_sub_cpu_ack_loop
	btst.b #COMM_ACK,(a1)
	bne .wait_sub_cpu_ack_loop
	
	;; ok, we're done
	bclr.b #COMM_ACK,(a0)
	rts
	
	
	
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;
	;; includes
	;;
	;;
	;;
	
	include main-cd-access.asm
	include main-mod-visualizer.asm
	
	
	
dma_data_buf
_end
	
	
	