module multiply 
#(
	parameter math_pack::multiply_t G_MODE 		= math_pack::DSP,
	parameter int unsigned 			G_A_WIDTH 	= 18,
	parameter int unsigned 			G_B_WIDTH 	= 18
) 
(
	input logic 						clk,    // Clock.
	input logic 						rst_n,  // Asynchronous reset active low.
	
	// Inputs.
	input logic [G_A_WIDTH - 1 : 0] 	a,		// Input a.
	input logic [G_B_WIDTH - 1 : 0] 	b, 		// Input b.
	
	// Output.
	output logic [G_B_WIDTH - 1 : 0] 	c 		// Output c.
);


	generate
		if (G_MODE == math_pack::DSP) begin : mult_dsp
			c = a * b;
		end else begin : mult_error
			assert;
		end
	endgenerate
endmodule