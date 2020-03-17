// c = a + b. 
module signed_add 
#(
	parameter math_pack::signed_add_t 	G_MODE 		= math_pack::LOGIC,
	parameter int unsigned 				G_IN_WIDTH 	= 18
)
(
	input logic 						clk,    // Clock.
	input logic 						rst_n,  // Asynchronous reset active low.
	
	// Inputs.
	input signed [G_IN_WIDTH - 1 : 0] 	a,		// Input a.
	input signed [G_IN_WIDTH - 1 : 0] 	b, 		// Input b.
	
	// Output.
	output signed [G_IN_WIDTH : 0] 		c 		// Output c (The input bus + 1).
);

	assign c = {a[7],a} + {b[7],b};
endmodule