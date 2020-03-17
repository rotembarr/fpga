interface dv_if #(parameter int unsigned DATA_WIDTH = 32) (input clk);

	logic [DATA_WIDTH - 1 : 0] 	data;
	logic 						valid;

	modport master (
		output data, 
		output valid
	);

	modport slave (
		input  data, 
		input  valid
	);
endinterface