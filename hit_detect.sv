`timescale 1ps / 1ps

/*
 * Determines when the ball is hitting a paddle and, if ball is hit, where the ball hit the paddle relative
 * to the paddle's center.
 
 * Note: hit_intersect is positive if hitting upper half of paddle, negative if hitting lower half of paddle
 *		paddle1_y_min: The minimum y-value of paddle 1
 *		paddle2_y_min: The minimum y-value of paddle 2
 *		ball_x_min: The minimum x-value of the ball
 *		ball_y_min: The minimum y-value of the ball
 *		paddle1_hit: Outputs true when the center of the ball intersects with paddle 1
 *		paddle2_hit: Outputs true when the center of the ball intersects with paddle 2
 *		hit_intersect: Indicates the y-intercept of the ball relative to the paddle's center when the ball hits
 *							either paddle.
 */
module hit_detect #(parameter PADDLE_HEIGHT = 70, PADDLE_WIDTH = 15, BALL_LEN = 15, SCREEN_WIDTH = 640) (paddle1_y_min, paddle2_y_min, ball_x_min, ball_y_min, paddle1_hit, paddle2_hit, hit_intersect);

	input logic [8:0] paddle1_y_min, paddle2_y_min, ball_y_min;
	input logic [9:0] ball_x_min;
	
	output logic paddle1_hit, paddle2_hit;
	output logic signed [9:0] hit_intersect;
	
	logic [8:0] ball_y_mid, paddle1_y_mid, paddle2_y_mid;
	assign ball_y_mid = ball_y_min + (BALL_LEN / 2);
	assign paddle1_y_mid = paddle1_y_min + (PADDLE_HEIGHT / 2);
	assign paddle2_y_mid = paddle2_y_min + (PADDLE_HEIGHT / 2);
	
	logic [9:0] ball_x_max;
	assign ball_x_max = ball_x_min + BALL_LEN;
	
	always_comb begin
		// Paddle 1 hit
		if (ball_x_min <= PADDLE_WIDTH && ball_y_mid >= paddle1_y_min && ball_y_mid <= paddle1_y_min + PADDLE_HEIGHT) begin
			paddle1_hit = 1'b1;
			paddle2_hit = 1'b0;
			hit_intersect = paddle1_y_mid - ball_y_mid;
		end
		
		// Paddle 2 hit
		else if (ball_x_max >= SCREEN_WIDTH - PADDLE_WIDTH && ball_y_mid >= paddle2_y_min && ball_y_mid <= paddle2_y_min + PADDLE_HEIGHT) begin
			paddle1_hit = 1'b0;
			paddle2_hit = 1'b1;
			hit_intersect = paddle2_y_mid - ball_y_mid;
		end
		
		// No hit
		else begin
			paddle1_hit = 1'b0;
			paddle2_hit = 1'b0;
			hit_intersect = 9'd0;
		end 
	end

endmodule  // hit_detect

module hit_detect_testbench ();

	logic paddle1_hit, paddle2_hit;
	logic signed [9:0] hit_intersect;
	logic [9:0] ball_x_min;
	logic [8:0] paddle1_y_min, paddle2_y_min, ball_y_min;
	
	parameter BALL_LEN = 15, PADDLE_HEIGHT = 70, PADDLE_WIDTH = 15, SCREEN_WIDTH = 640;
	hit_detect #(PADDLE_HEIGHT, PADDLE_WIDTH, BALL_LEN, SCREEN_WIDTH) dut
		(paddle1_y_min, paddle2_y_min, ball_x_min, ball_y_min, paddle1_hit, paddle2_hit, hit_intersect);

	integer j;
	initial begin
		/* Ball not hit */
		ball_x_min <= 150; ball_y_min <= 200; paddle1_y_min <=  50; paddle2_y_min <= 200; #100;
		ball_x_min <= 200; ball_y_min <= 150; paddle1_y_min <= 200; paddle2_y_min <=  50; #100;
		ball_x_min <= PADDLE_WIDTH; ball_y_min <= 200; paddle1_y_min <= 10; paddle2_y_min <= 200; #100;
		ball_x_min <= SCREEN_WIDTH - BALL_LEN; ball_y_min <= 200; paddle1_y_min <= 50; paddle2_y_min <= 50; #100;
		
		/* Ball hit paddle 1 */
		ball_x_min <= PADDLE_WIDTH; ball_y_min <= 200; paddle1_y_min <= 190; paddle2_y_min <= 200; #100;		
		
		/* Ball hit paddle 2 */
		ball_x_min <= SCREEN_WIDTH - BALL_LEN; ball_y_min <= 200; paddle1_y_min <= 50; paddle2_y_min <= 185; #100;		
		
		$stop;
	end  // initial

endmodule  // hit_detect_testbench
