;; communication protocol:
; main writes command/params to command_0..., sets MAIN_REQ
; sub sets SUB_BUSY, executes command, sets status bytes
; sub sets SUB_ACK, clears SUB_BUSY
; main clears MAIN_REQ, sets MAIN_ACK
; sub clears SUB_ACK
; main clears MAIN_ACK

;; main/sub flag bits
COMM_REQ = 0 ;cpu wants to execute a command
COMM_BUSY = 1 ;cpu is executing
COMM_ACK = 2 ;command is finished and acknowledged

;; main->sub commands
	clrso
CMD_M_LOAD_ROOT_DIRECTORY	so.b 1 ;reload directory from disc
CMD_M_LOAD_MODULE	so.b 1 ;load module w/directory index file no.
CMD_M_START_MODULE	so.b 1 ;start module playback
CMD_M_GET_MODULE_INFO	so.b 1 ;get info on loaded mod, incl. channels, orderlist, samples, etc.
CMD_M_GET_PATTERN	so.b 1 ;transfer a module pattern to word ram




;; word ram structs

	clrso ;sample info
w_mpl_sample_name	so.b 22
w_mpl_sample_size	so.l 1
w_mpl_sample_SIZEOF	so.b 0



;; word ram layout
;; this refers to different addresses depending on who included it
	setso word_ram
	
	;; directory
w_cda_pvd	so.b $800
w_cda_dir_index	so.l CDA_MAX_FILES
w_cda_directory	so.b CDA_MAX_DIR_SIZE
w_cda_dir_files	so.l 1

	
	;; module information transferred by CMD_GET_MODULE_INFO
w_mpl_module_info	so.b 0
w_mpl_song_title	so.b MPL_SONG_TITLE_SIZE
w_mpl_amt_channels	so.b 1
w_mpl_amt_samples	so.b 1
w_mpl_samples	so.b MPL_MAX_SAMPLES*w_mpl_sample_SIZEOF
w_mpl_song_length	so.b 1
	so.b 1
w_mpl_orderlist	so.b MPL_ORDERLIST_SIZE

	;; pattern transferred by CMD_GET_PATTERN
w_mpl_pattern	so.b MPL_MAX_CHANNELS*MPL_PATTERN_ROWS*MPL_ROW_SIZE


w_free	so.b 0




;; main-cpu status bytes
M_READY_VALUE = 'SNDE'
m_cmd = command_0 ;which command does maincpu want to execute
m_ready = command_12 ;set to special value when maincpu is done its bootup

;; sub-cpu status bytes
s_cmd_status = status_0 ;command return value
s_flags = status_2 ;misc flags
s_current_order = status_4 ;playback position
s_current_row = status_4+1


;; s_flags bits
S_FLAG_CD_READ = 0 ;the disc was read, either successfully or unsuccessfully (cleared on eject)
S_FLAG_CD_OK = 1 ;the currently inserted disc has a valid directory loaded to word ram



;; errors

	clrso
ERR_OK so.b 1

ERR_CDA_TRAY_OPEN	so.b 1
ERR_CDA_READ_ERROR	so.b 1
ERR_CDA_NO_VALID_DIRECTORY	so.b 1
ERR_CDA_DIRECTORY_TOO_LARGE	so.b 1
ERR_CDA_TOO_MANY_FILES	so.b 1
ERR_CDA_NO_SUCH_FILE	so.b 1

ERR_MPL_NO_MODULE	so.b 1
ERR_MPL_BAD_MODULE so.b 1
ERR_MPL_BAD_CHANNEL_COUNT so.b 1
ERR_MPL_TOO_MUCH_SAMPLE_DATA so.b 1


