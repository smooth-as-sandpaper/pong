`timescale 1ps / 1ps

/*
 * Determines whether a game has finished based on a given score limit and current scores.
 * Score limit must be a positive integer.
 *		p1_score: paddle 1's current score
 *		p2_score: paddle 2's current score
 *		p1_win: true iff paddle 1 reached score limit
 *		p2_win: true iff paddle 2 reached score limit
 */
module game_over #(parameter SCORE_LIMIT = 15) (p1_score, p2_score, p1_win, p2_win);

	input integer p1_score, p2_score;
	output logic p1_win, p2_win;
	
	always_comb
		if (p1_score == SCORE_LIMIT)
			{ p1_win, p2_win } = 2'b10;
		else if (p2_score == SCORE_LIMIT)
			{ p1_win, p2_win } = 2'b01;
		else
			{ p1_win, p2_win } = 2'b00;

endmodule  // game_over

module game_over_testbench ();

	integer p1_score, p2_score;
	logic p1_win, p2_win;
	
	parameter SCORE_LIMIT = 15;
	
	game_over #(SCORE_LIMIT) dut (.*);
	
	initial begin
		// No winner
		p1_score <= 0; p2_score <= 0; 	#100;
		p1_score <= 10; p2_score <= 10;	#100;
		p1_score <= 14; p2_score <= 0;	#100;
		
		// Paddle 1 win
		p1_score <= 15; p2_score <= 0; 	#100;
		
		// Paddle 2 win
		p1_score <= 0; p2_score <= 15;	#100;
		
		$stop;
	end

endmodule  // game_over_testbench