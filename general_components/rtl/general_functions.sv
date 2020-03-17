`define max(a,b) {(a) > (b) ? (a) : (b)}
`define min(a,b) {(a) < (b) ? (a) : (b)}

function integer log2 (input integer value);
	reg [31:0] shifted;
	integer res;

	if (value < 2) begin 
		log2 = value;
	end
	else begin
		shifted = value-1;
		for (res=0; shifted>0; res=res+1) begin 
			shifted = shifted>>1;
		end
		log2 = res;
	end
endfunction
