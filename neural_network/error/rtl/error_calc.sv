module error_calc
#(
	parameter int unsigned G_ERROR_WIDTH 		= 18,
	parameter int unsigned G_WEIGHT_WIDTH 		= 18,
	parameter int unsigned G_NUM_OF_WEIGHTS		= 4,
	parameter int unsigned G_FIRST_WEIGHT_REQ	= 0
)
(
	// Clk & Rst.
	input 								clk, 			// Clock
	input 								rst_n, 			// Asynchronous reset active low

	// Restart.
	input logic 						recopy, 		// Start copy weights.
	output logic 						copy_done,  	// Copy proccess have finished.

	// Next layer weights.
	avalon_mm_if.master 				weights_req_arr_mm [G_NUM_OF_WEIGHTS - 1 : 0], // Next layer weights to be copied - signed values .

	// Error calculation lane.
	dv_if.slave 						errors_lp1_in_st, 	// All the next layer errors - signed values.
	output [G_ERROR_WIDTH - 1 : 0] 		error_l_out 		// Current neuron error - signed value.
);

	localparam int unsigned C_LAST_INDEX = (G_NUM_OF_WEIGHTS + G_FIRST_WEIGHT_REQ - 1) % G_NUM_OF_WEIGHTS;

	logic        												bram_we;
	logic [G_WEIGHT_WIDTH - 1 : 0] 								bram_din;
	logic [G_WEIGHT_WIDTH - 1 : 0] 								bram_dout;
	logic [log2up(G_NUM_OF_WEIGHTS) - 1 : 0] 					bram_addr;
	
	logic [G_NUM_OF_WEIGHTS - 1 : 0] 							w_req_r_sr; 		// 1 to 1 read req.
	logic [G_NUM_OF_WEIGHTS - 1 : 0] 							w_req_waitreq_v_arr;
	logic [G_NUM_OF_WEIGHTS - 1 : 0] 							w_req_rdv_v_arr;
	logic [G_WEIGHT_WIDTH - 1 : 0] [G_NUM_OF_WEIGHTS - 1 : 0] 	w_req_rd_v_arr;
	logic 														errors_lp1_in_valid_s;


	// Assign weights req to vector.
	genvar x;
	generate
		for (int x = 0; x < G_NUM_OF_WEIGHTS; x++) begin : proc_assign_arr
			assign w_req_waitreq_v_arr[x] 	= weights_req_arr_mm[x].waitreq;
			assign w_req_rdv_v_arr[x] 		= weights_req_arr_mm[x].read_data_valid;
			assign w_req_rd_v_arr[x]  		= weights_req_arr_mm[x].read_data;
		end
	endgenerate

	// When getting recopy, start asking (read) for weigths. 
	always_ff @(posedge clk or negedge rst_n) begin : proc_w_req
		if(~rst_n) begin
			bram_addr	<= {log2up(G_NUM_OF_WEIGHTS){1'b0}};
			w_req_r_sr	<= {G_NUM_OF_WEIGHTS{1'b0}};
			copy_done  	<= 1'b1;
		end else begin

			// Start over the coppy proccess.
			if (recopy) begin 
				copy_done <= 1'b0;
			end else begin 

				// End of the copy proccess.
				if (bram_we & (bram_addr == C_LAST_INDEX)) begin
					copy_done <= 1'b1;
				end
			end

			// Start over the coppy proccess.
			if (recopy) begin 
				w_req_r_sr[G_NUM_OF_WEIGHTS - 1 : 0] 	<= {G_NUM_OF_WEIGHTS{1'b0}};
				w_req_r_sr[G_FIRST_WEIGHT_REQ] 			<= 1'b1;
			end else begin 

				// End of the copy req proccess.
				if (weights_req_arr_mm[C_LAST_INDEX].read & ~weights_req_arr_mm[C_LAST_INDEX].waitreq) begin
					w_req_r_sr[G_NUM_OF_WEIGHTS - 1 : 0] <= {G_NUM_OF_WEIGHTS{1'b0}};
				end else begin 

					// Shift the req vector (when current reading recieved), so we ask the next weight.
					if (!(w_req_r_sr & ~w_req_waitreq_v_arr)) begin
						w_req_r_sr <= {w_req_r_sr[G_NUM_OF_WEIGHTS - 2 : 0], w_req_r_sr[G_NUM_OF_WEIGHTS - 1]};
					end

				end
			end


			// Start over the coppy proccess.
			if (recopy) begin 
				bram_addr <= G_FIRST_WEIGHT_REQ;
			end else begin 
				
				// After we are updating the last weights table, we are ready for error calc, so rst for the address is needed.
				if (bram_we & (bram_addr == C_LAST_INDEX)) begin
					bram_addr <= {log2up(G_NUM_OF_WEIGHTS){1'b0}};
				end else begin 

					// If any answer recieved, or we calc error for this weight - advance address.
					if (!w_req_rdv_v_arr || errors_lp1_in_st.valid) begin 
		
						// Wraparound.
						if(bram_addr == G_NUM_OF_WEIGHTS - 1) begin
							bram_addr <= {log2up(G_NUM_OF_WEIGHTS){1'b0}};
						end else begin 
							bram_addr <= bram_addr + 1;
						end
		
					end
				end
			end
		end
	end

	assign bram_we  = w_req_rdv_v_arr[bram_addr]; 	// Just mux on the input array.
	assign bram_din = w_req_rd_v_arr[bram_addr]; 	// Just mux on the input array.

	single_port_ram 
	#(
		.MEMORY_TYPE(ram_pack::BRAM),
		.READ_LATENCY(1),
		.DATA_WIDTH(G_WEIGHT_WIDTH),
		.ADDR_WIDTH(G_NUM_OF_WEIGHTS)
	)
	single_port_ram_inst
	(
		.clk(clk),
		.rst_n(rst_n),
		.ce(1'b1),
		.we(bram_we),
		.addr(bram_addr),
		.din(bram_din),
		.dout(bram_dout)
	);

	// Calc error after copying the weights.
	always_ff @(posedge clk or negedge rst_n) begin : proc_error_calc
		if(~rst_n) begin
			error_l_out	<= {G_ERROR_WIDTH{1'b0}};
		end else begin

			// Rst calculation.
			if (recopy) begin
				error_l_out <= {G_ERROR_WIDTH{1'b0}};
			end else begin
				// When mult is finished.
				if (errors_lp1_in_valid_s) begin 
					error_l_out <= error_l_out + w_mult_e; // Signed adder.
				end
			end
		end
	end


	// IRQs.
	// When getting a w answer in a wrong order.
	// When getting a w answer while calculating.
	// When overflowing calc.

endmodule