/*
 * Detects when a player scores. A score occurs when any part of the ball passes the inside edge of the paddle.
 * If the ball passes the inside edge of paddle 2, then paddle 1 scores; the converse is true for a paddle 2 score.
 * The output will always be valid when PADDLE_WIDTH >= the speed of the ball.
 *		clk: The master clock
 *		paddle1_y_min: The minimum y-value of paddle 1
 *		paddle2_y_min: The minimum y-value of paddle 2
 *		ball_x_min: The minimum x-value of the ball
 *		ball_y_min: The minimum y-value of the ball
 *		p1_scored: Outputs true when paddle 1 scores
 *		p2_scored: Outputs true when paddle 2 scores
 */
module score_detect #(parameter PADDLE_WIDTH = 15, PADDLE_HEIGHT = 70, BALL_SPEED = 5, BALL_LEN = 15, SCREEN_WIDTH = 640) (clk, paddle1_y_min, paddle2_y_min, ball_x_min, ball_y_min, p1_scored, p2_scored);

	input logic clk;
	input logic [8:0] paddle1_y_min, paddle2_y_min, ball_y_min;
	input logic [9:0] ball_x_min;
	
	output logic p1_scored, p2_scored;
	
	logic [8:0] ball_y_mid;
	assign ball_y_mid = ball_y_min + (BALL_LEN / 2);
	
	logic [9:0] ball_x_max;
	assign ball_x_max = ball_x_min + BALL_LEN;
	
	logic [8:0] paddle1_y_max, paddle2_y_max;
	assign paddle1_y_max = paddle1_y_min + PADDLE_HEIGHT;
	assign paddle2_y_max = paddle2_y_min + PADDLE_HEIGHT;
	
	logic lock_scores;
	
	logic [9:0] ball_x_min_prev, ball_x_max_prev;
	
	always_ff @(posedge clk) begin
		
		// Normal; no score
		if (ball_x_min >= PADDLE_WIDTH && ball_x_max <= SCREEN_WIDTH - PADDLE_WIDTH) begin
			p1_scored <= 1'b0;
			p2_scored <= 1'b0;
			lock_scores <= 1'b0;
		end 
		
		// paddle 2 misses ball => P1 score
		else if (ball_x_max <= SCREEN_WIDTH && ball_x_max > SCREEN_WIDTH - PADDLE_WIDTH
				&& (ball_y_mid < paddle2_y_min || ball_y_mid > paddle2_y_min + PADDLE_HEIGHT) 
				&& !lock_scores) 
		begin
			p1_scored <= 1'b1;
			p2_scored <= 1'b0;
			lock_scores <= 1'b1;
		end
		
		// paddle 1 misses ball => P2 score
		else if (ball_x_min < PADDLE_WIDTH && ball_x_min >= 0 
				&& (ball_y_mid < paddle1_y_min || ball_y_mid > paddle1_y_min + PADDLE_HEIGHT) 
				&& !lock_scores)
		begin
			p1_scored <= 1'b0;
			p2_scored <= 1'b1;
			lock_scores <= 1'b1;
		end
		
		// Scores locked (already incremented)
		else begin
			p1_scored <= 1'b0;
			p2_scored <= 1'b0;
			lock_scores <= 1'b1;
		end
		
	end

endmodule  // score_detect

module score_detect_testbench ();

	parameter ClockDelay = 20;

	logic clk, p1_scored, p2_scored, lock_scores;
	logic [9:0] ball_x_min;
	logic [8:0] paddle1_y_min, paddle2_y_min, ball_y_min;

	initial begin
		clk <= 0;
		forever #(ClockDelay/2) clk <= ~clk;
	end  // initial
	
	parameter BALL_LEN = 15, BALL_SPEED = 5, PADDLE_HEIGHT = 70, PADDLE_WIDTH = 15, SCREEN_WIDTH = 640;
	score_detect #(PADDLE_WIDTH, PADDLE_HEIGHT, BALL_SPEED, BALL_LEN, SCREEN_WIDTH) dut (.*);

	integer j;
	initial begin
		/* No score */
		ball_x_min <= 150; ball_y_min <= 200; paddle1_y_min <=  50; paddle2_y_min <= 200; @(posedge clk);
		ball_x_min <= 200; ball_y_min <= 150; paddle1_y_min <= 200; paddle2_y_min <=  50; @(posedge clk);
		ball_x_min <= PADDLE_WIDTH + 1; ball_y_min <= 200; paddle1_y_min <= 10; paddle2_y_min <= 200; @(posedge clk);
		ball_x_min <= 100; ball_y_min <= 200; paddle1_y_min <= 50; paddle2_y_min <= 50; @(posedge clk);	
		
		/* P1 scores */
		ball_x_min <= SCREEN_WIDTH - BALL_LEN - 1; ball_y_min <= 200; paddle1_y_min <= 190; paddle2_y_min <= 50; @(posedge clk);
		ball_x_min <= SCREEN_WIDTH - BALL_LEN + 1; ball_y_min <= 200; paddle1_y_min <= 190; paddle2_y_min <= 50; @(posedge clk);
		
		/* Do not count score multiple times */
		@(posedge clk); @(posedge clk); @(posedge clk);
		
		/* Set game to normal playing state */
		ball_x_min <= 100; ball_y_min <= 100; paddle1_y_min <= 100; paddle2_y_min <= 100; @(posedge clk);
	
		/* P2 scores */
		ball_x_min <= PADDLE_WIDTH + 1; ball_y_min <= 100; paddle1_y_min <= 200; paddle2_y_min <= 100; @(posedge clk);
		ball_x_min <= PADDLE_WIDTH - 1; ball_y_min <= 100; paddle1_y_min <= 200 + BALL_LEN + 1; paddle2_y_min <= 250; @(posedge clk);		
		ball_x_min <= 100; ball_y_min <= 100; paddle1_y_min <= 100; paddle2_y_min <= 100; @(posedge clk);
		@(posedge clk);
		
		$stop;
	end  // initial

endmodule  // score_detect_testbench
