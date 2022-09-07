// FIFO Testbench

module fifo_tb();

	// Clock
	logic clk;
	logic rst_n;
	logic en;
	logic signed [63:0] d;
	logic signed [63:0] q;

	always #5 clk = ~clk; 

	integer errors;
	integer lind;

	bit signed [63:0] vals [7:0];

	fifo DUT(.clk(clk), .rst_n(rst_n), .en(en),
	        .d(d), .q(q));

	initial begin
		clk = 1'b0;
		rst_n = 1'b0;
		en = 1'b0;
		errors = 0;


		// Set stimulus values
		vals[0] = 64'd1;
		vals[1] = -64'd8;
		vals[2] = 64'd3;
		vals[3] = 64'd16457;
		vals[4] = 64'd89320567;
		vals[5] = 64'd58947128924718;
		vals[6] = -64'd123567; 
		vals[7] = 64'd55;

		// Load stimulti for our DUT
		@(posedge clk);
		rst_n = 1'b1;
		en = 1'b1;

		for(lind = 0; lind < 8; ++lind) begin
			d = vals[lind];

			// We should also check for the reset during each of
			// these
			#1 if(q !== 64'd0) begin
				errors++;
				$display("Error! Reset was not conducted properly. Expected: 0, Got: %d", q); 
			end

			@(posedge clk);
		end

		d = 64'd800;

		// At this point, we have 8 cycles of latency. The FIFO should
		// be full. Let's check each value to make sure we are getting
		// the right values.
		for(lind = 0; lind < 8; ++lind) begin

			#1 if(q !== vals[lind]) begin
				errors++;
				$display("Error, incorrect value recorded. Expected: %d, Got: %d", vals[lind], q);
			end

			if(lind != 7) begin
			       	@(posedge clk);
			end
		end
		
		// Disable enable
		en = 1'b0;

		@(posedge clk); // Test that the value will be stable if disable is eanbled.

		#1 if(q !== vals[7]) begin
			errors++;
			$display("Error. Failed retention (enable lock) test. Expected: %d, Got: %d", vals[7], q);
		end

		$display("Errors: %d", errors);

		if(!errors) begin
			$display("YAHOO!!! All tests passed.");
		end
		else begin
			$display("ARRRR!  Ye codes be blast! Aye, there be errors. Get debugging!");
		end

		$stop;

	end

endmodule
