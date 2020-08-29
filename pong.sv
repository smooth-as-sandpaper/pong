/*
 * Top-level module for Pong project.
 *		HEX0-5: On-board HEX display outputs
 *		LEDR0-9: On-board LED display outputs
 *		SW0-9: On-board switch inputs
 *		CLOCK*_50: 50 MHz clock inputs
 *		VGA_*: VGA signals for outputting to monitor
 *		FPGA_*: FPGA signals used for A/V configuration
 *		AUD_*: Audio signals used for outputting to audio output
 *		PS2_*: PS2 signals used for keyboard input
 */
module pong (HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, LEDR, SW,
					 CLOCK_50, VGA_R, VGA_G, VGA_B, VGA_BLANK_N, VGA_CLK, VGA_HS, VGA_SYNC_N, VGA_VS,
					 CLOCK2_50, FPGA_I2C_SCLK, FPGA_I2C_SDAT, AUD_XCK, AUD_DACLRCK, AUD_ADCLRCK, AUD_BCLK, 
					 AUD_ADCDAT, AUD_DACDAT, PS2_DAT, PS2_CLK);
	
	output logic [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
	output logic [9:0] LEDR;
	input logic [9:0] SW;
	
	output logic FPGA_I2C_SCLK;
	inout  FPGA_I2C_SDAT;
	output logic AUD_XCK;
	input  logic AUD_DACLRCK, AUD_ADCLRCK, AUD_BCLK;
	input  logic AUD_ADCDAT;
	output logic AUD_DACDAT;

	input CLOCK_50, CLOCK2_50;
	output [7:0] VGA_R;
	output [7:0] VGA_G;
	output [7:0] VGA_B;
	output VGA_BLANK_N;
	output VGA_CLK;
	output VGA_HS;
	output VGA_SYNC_N;
	output VGA_VS;
	input  PS2_DAT;
	input  PS2_CLK;
	
	logic game_over;
	
	/*** CLOCK DIVIDER ***/
	logic paddle_clk = 1'b0;
	logic ball_clk = 1'b0;
	logic color_picker_clk = 1'b0;
	integer i = 0, j = 0, k = 0;
	always_ff @(posedge CLOCK_50) begin
		if (i == 75000) begin
			paddle_clk <= ~paddle_clk;
			i <= 0;
		end else
			i <= i + 1;
			
		if (j == 200000) begin
			ball_clk <= ~ball_clk;
			j <= 0;
		end else
			j <= j + 1;
			
		if (k == 3500000) begin
			color_picker_clk <= ~color_picker_clk;
			k <= 0;
		end else
			k <= k + 1;
	end
	/*********************/

	/*** VGA ***/
	logic reset, start;
	logic [9:0] x;
	logic [8:0] y;
	logic [7:0] r, g, b;
	
	parameter SCREEN_WIDTH = 640;
	parameter SCREEN_HEIGHT = 480;
	
	video_driver #(.WIDTH(SCREEN_WIDTH), .HEIGHT(SCREEN_HEIGHT))
		v1 (.CLOCK_50, .reset, .x, .y, .r, .g, .b,
			 .VGA_R, .VGA_G, .VGA_B, .VGA_BLANK_N,
			 .VGA_CLK, .VGA_HS, .VGA_SYNC_N, .VGA_VS);
	/***********/
			 
	/*** KEYBOARD ***/
	assign reset = SW[9];
	assign start = SW[0] && !game_over;

	logic valid, makeBreak;
	logic [7:0] outCode;
	keyboard_press_driver k1 (.CLOCK_50, .valid, .makeBreak, .outCode, .PS2_DAT, .PS2_CLK, .reset);
	/****************/
	
	/*** PADDLES ***/
	parameter PADDLE_WIDTH = 15;
	parameter PADDLE_HEIGHT = 90;
	parameter y0 = (SCREEN_HEIGHT - PADDLE_HEIGHT) / 2;
			
	logic w_key, s_key, up_arrow_key, down_arrow_key;
	
	logic [8:0] paddle1_y_min, paddle1_y_max, paddle2_y_min, paddle2_y_max;
	paddle #(y0, PADDLE_HEIGHT, SCREEN_HEIGHT) p1 (.clk(paddle_clk), .reset, .start, .move_up(w_key), .move_down(s_key), .y_min(paddle1_y_min));
	paddle #(y0, PADDLE_HEIGHT, SCREEN_HEIGHT) p2 (.clk(paddle_clk), .reset, .start, .move_up(up_arrow_key), .move_down(down_arrow_key), .y_min(paddle2_y_min));
	
	assign paddle1_y_max = paddle1_y_min + PADDLE_HEIGHT;
	assign paddle2_y_max = paddle2_y_min + PADDLE_HEIGHT;
	/***************/
	
	/*** BALL ***/
	parameter BALL_LEN = 15;
	parameter MAX_BOUNCE_ANGLE = 65;
	parameter BALL_SPEED = 7;
	
	logic [9:0] ball_x_min;
	logic [8:0] ball_y_min;
	logic signed [9:0] hit_intersect;
	logic paddle1_hit, paddle2_hit, boundary_hit;
	logic round_over;
	
	ball #(BALL_LEN, MAX_BOUNCE_ANGLE, BALL_SPEED, PADDLE_HEIGHT, SCREEN_WIDTH, SCREEN_HEIGHT) bal 
		(.clk(ball_clk), .CLOCK_50, .reset(reset || round_over), .start, .x_min(ball_x_min), .y_min(ball_y_min), .paddle1_hit, .paddle2_hit, .hit_intersect, .boundary_hit);
	/************/
	
	/*** HIT DETECTION ***/
	hit_detect #(PADDLE_HEIGHT, PADDLE_WIDTH, BALL_LEN, SCREEN_WIDTH) hd (.paddle1_y_min, .paddle2_y_min, .ball_x_min, .ball_y_min, .paddle1_hit, .paddle2_hit, .hit_intersect);
	/*********************/
	
	/*** SCORE DETECTION ***/
	logic p1_scored, p2_scored;
	assign round_over = p1_scored || p2_scored;
	
	score_detect #(PADDLE_WIDTH, PADDLE_HEIGHT, BALL_SPEED, BALL_LEN, SCREEN_WIDTH) sd (.clk(ball_clk), .paddle1_y_min, .paddle2_y_min, .ball_x_min, .ball_y_min, .p1_scored, .p2_scored);
	/***********************/
	
	/*** SCOREKEEPING ***/
	integer p1_score = 0, p2_score = 0;
	
	scoreboard sb (.clk(ball_clk), .reset, .p1_scored, .p2_scored, .p1_score, .p2_score);
	/********************/
	
	/*** GAME OVER MONITORING ***/
	logic p1_win, p2_win;
	assign game_over = p1_win || p2_win;
	parameter SCORE_LIMIT = 5;
	
	game_over #(SCORE_LIMIT) go (.*);
	/****************************/
	
	/*** Define colors ***/
	
	// Colors are 24 bits (8 red bits + 8 green bits + 8 blue bits)
	logic [23:0] p1_color, p2_color, ball_color, boundary_color, background_color;
	
	logic [23:0] color_array[0:7] =
		'{ { 24'hFF_00_00 }, { 24'hFF_99_33 }, { 24'h00_88_00 }, { 24'h00_FF_00 }, { 24'h00_FF_FF }, { 24'h00_99_99 }, { 24'h00_00_FF }, { 24'hB2_66_FF } };
	// 			red					orange			green (d)			green (l)				cyan					teal					blue					purple
	
	logic [2:0] p1_color_idx = 0, p2_color_idx = 3;
	
	assign p1_color 			= color_array[p1_color_idx];
	assign p2_color 			= color_array[p2_color_idx];
	assign ball_color			= 24'hFF_FF_FF;  // white
	
	always_ff @(posedge color_picker_clk) begin
		// F1 key (P1 color -> previous color)
		if (makeBreak && outCode == 8'h05)
			p1_color_idx <= p1_color_idx - 1;
		else if (!makeBreak && outCode == 8'h05)
			p1_color_idx <= p1_color_idx;
		
		// F2 key (P1 color -> next color)
		if (makeBreak && outCode == 8'h06)
			p1_color_idx <= p1_color_idx + 1;
		else if (!makeBreak && outCode == 8'h06)
			p1_color_idx <= p1_color_idx;
		
		// Home key (P2 color -> previous color)
		if (makeBreak && outCode == 8'h6C)
			p2_color_idx <= p2_color_idx - 1;
		else if (!makeBreak && outCode == 8'h6C) 
			p2_color_idx <= p2_color_idx;
				
		// End key (P2 color -> next color)
		if (makeBreak && outCode == 8'h69)
			p2_color_idx <= p2_color_idx + 1;
		else if (!makeBreak && outCode == 8'h69)
			p2_color_idx <= p2_color_idx;
	end
	/****************************/	
	
	/*** Draw on screen ***/
	always_ff @(posedge CLOCK_50) begin
		if (game_over) begin
			/*** Color screen in winner's color ***/
			if (p1_win)
				{ r, g, b } <= p1_color;
			else
				{ r, g, b } <= p2_color;
			/**************************************/
		end
		
		else begin
			/*** Check user input ***/
			if (makeBreak && outCode == 8'h1D)
				w_key <= 1'b1;
			else if (!makeBreak && outCode == 8'h1D)
				w_key <= 1'b0;
			else
				w_key <= w_key;
				
			if (makeBreak && outCode == 8'h1B)
				s_key <= 1'b1;
			else if (!makeBreak && outCode == 8'h1B)
				s_key <= 1'b0;
			else
				s_key <= s_key;

			if (makeBreak && outCode == 8'h75)
				up_arrow_key <= 1'b1;
			else if (!makeBreak && outCode == 8'h75)
				up_arrow_key <= 1'b0;
			else
				up_arrow_key <= up_arrow_key;
				
			if (makeBreak && outCode == 8'h72)
				down_arrow_key <= 1'b1;
			else if (!makeBreak && outCode == 8'h72)
				down_arrow_key <= 1'b0;
			else
				down_arrow_key <= down_arrow_key;
			/************************/
		
			/*** Draw paddles ***/
			if (x < PADDLE_WIDTH && y > paddle1_y_min && y < paddle1_y_max)
				{ r, g, b } <= p1_color;
			else if (x > SCREEN_WIDTH - PADDLE_WIDTH && y > paddle2_y_min && y < paddle2_y_max)
				{ r, g, b } <= p2_color;
			/********************/
			
			/*** Draw ball ***/
			else if (x >= ball_x_min && x <= ball_x_min + BALL_LEN && y >= ball_y_min && y <= ball_y_min + BALL_LEN)
				{ r, g, b } <= ball_color;
			/*****************/
			
			/*** Draw boundary ***/
			else if (x < 5 || ((y < 5 || y > SCREEN_HEIGHT - 5) && x <= SCREEN_WIDTH / 2) || (x <= (SCREEN_WIDTH / 2) && x > (SCREEN_WIDTH / 2) - 5))
				{ r, g, b } <= 24'h7F_00_FF;  // UW purple
		
			else if (x >= SCREEN_WIDTH - 5 || ((y < 5 || y > SCREEN_HEIGHT - 5) && x > SCREEN_WIDTH / 2) || (x > SCREEN_WIDTH / 2 && x <= SCREEN_WIDTH / 2 + 5))
				{ r, g, b } <= 24'hE0C070; 	// UW gold
			/*********************/
			
			/*** Draw background ***/
			else
				{ r, g, b } <= 24'h00_00_00;
			/***********************/
		end
	end
	/**********************/
	
	/*** Configure on-board outputs ***/
	seg7 p1s1 (.bcd(p1_score / 10), .leds(HEX5));
	seg7 p1s2 (.bcd(p1_score % 10), .leds(HEX4));
	
	seg7 p2s1 (.bcd(p2_score / 10), .leds(HEX1));
	seg7 p2s2 (.bcd(p2_score % 10), .leds(HEX0));

	assign LEDR[9] = p1_scored;
	assign LEDR[0] = p2_scored;
	
	assign HEX3 = '1;
	assign HEX2 = '1;
	/**********************************/
	
	/*** AUDIO ***/
	logic write_ready, write, read_ready, read;
	logic signed [23:0] writedata_left, writedata_right, readdata_left, readdata_right, rd_l, rd_r, sound, sound_p1, sound_p2, sound_boundary;
	
	integer lasting_hit = 0;  // sound cycles counter
	logic hit_enable;			  // enables sound when high
	
	parameter NUM_SOUND_CYCLES = 3000000;
	parameter T_CC_P1 			=  285714; // (1/freq(F3)) * 50,000,000
	parameter T_CC_P2 			=  143266; // 			 F4
	parameter T_CC_BOUNDARY 	=   71633; // 			 F5
	integer T1 = 0, T2 = 0, T3 = 0;
	
	logic signed [23:0] amplitude;
	assign amplitude = 24'h0FFFFF;
		
	always_ff @(posedge CLOCK_50) begin
		/*** Paddle 1 sound - F3 ***/
		if (T1 == T_CC_P1/2) begin
			sound_p1 <= amplitude;
			T1 <= T1 + 1;
		end else if (T1 == T_CC_P1) begin
			sound_p1 <= ~amplitude + 1;
			T1 <= 0;
		end else begin
			sound_p1 <= sound_p1;
			T1 <= T1 + 1;
		end
		/***************************/
		
		/*** Paddle 2 sound - F4 ***/
		if (T2 == T_CC_P2/2) begin
			sound_p2 <= amplitude;
			T2 <= T2 + 1;
		end else if (T2 == T_CC_P2) begin
			sound_p2 <= ~amplitude + 1;
			T2 <= 0;
		end else begin
			sound_p2 <= sound_p2;
			T2 <= T2 + 1;
		end
		/***************************/
		
		/*** Boundary sound - F5 ***/
		if (T3 == T_CC_BOUNDARY/2) begin
			sound_boundary <= amplitude;
			T3 <= T3 + 1;
		end else if (T3 == T_CC_P2) begin
			sound_boundary <= ~amplitude + 1;
			T3 <= 0;
		end else begin
			sound_boundary <= sound_boundary;
			T3 <= T3 + 1;
		end
		/***************************/
		
		/*** Enable sound for NUM_SOUND_CYCLES cycles ***/
		if (paddle1_hit || paddle2_hit || boundary_hit) begin
			hit_enable <= 1;
			lasting_hit <= 0;
		end else if (lasting_hit == NUM_SOUND_CYCLES) begin
			hit_enable <= 0;
			lasting_hit <= 0;
		end else if (hit_enable) begin		
			hit_enable <= hit_enable;
			lasting_hit <= lasting_hit + 1;
		end else begin
			hit_enable <= 0;
			lasting_hit <= 0;
		end
		/************************************************/
		
		/*** Configure sound based on most recent event ***/
		if (paddle1_hit)
			sound <= sound_p1;
		else if (paddle2_hit)
			sound <= sound_p2;
		else if (boundary_hit)
			sound <= sound_boundary;
		else
			sound <= sound;
		/**************************************************/
	end
	
	assign writedata_left  = hit_enable ? sound : 24'd0; 
	assign writedata_right = hit_enable ? sound : 24'd0;
	assign write = write_ready;
	
	clock_generator my_clock_gen(
		CLOCK2_50,
		reset,
		AUD_XCK
	);

	audio_and_video_config cfg(
		CLOCK_50,
		reset,
		FPGA_I2C_SDAT,
		FPGA_I2C_SCLK
	);

	audio_codec codec(
		CLOCK_50,
		reset,
		read,	
		write,
		writedata_left, 
		writedata_right,
		AUD_ADCDAT,
		AUD_BCLK,
		AUD_ADCLRCK,
		AUD_DACLRCK,
		read_ready, write_ready,
		readdata_left, readdata_right,
		AUD_DACDAT
	);
	/*************/
	
endmodule  // pong
