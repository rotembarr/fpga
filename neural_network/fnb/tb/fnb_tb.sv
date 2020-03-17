module fnb_tb ();

	logic clk;

	initial begin 
		clk = 1'b0;
	end

	always begin 
		# 5ns;
		clk = ~clk;
	end

endmodule