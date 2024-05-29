/*****************************************
    testbench.v

    Project 1
    
    Team XX : 
        2024000000    Kim Mina
        2024000001    Lee Minho
*****************************************/

module testbench;

    reg             CLK, RSTN;

    /// CLOCK Generator ///
    parameter   PERIOD = 10.0;
    parameter   HPERIOD = PERIOD/2.0;

    initial CLK <= 1'b0;
    always #(HPERIOD) CLK <= ~CLK;

	// Include other Input signals if needed.
	// Do not modify the given I/O signals for the top module stated below.
	//Additional required signals: weight/input enable signals (enW_i, enI_i)

	// N, T variables
	parameter N = 5; //N = 1~5
	parameter T = 10; // Any values (but set to 1~10)
	
	//Input
	reg    [5*8-1:0]    Weight_i;
	reg    [5*8-1:0]    In_i;


	//Output - Cannot be modified.
	wire    [5*8-1:0]    OUT_o;		//Column output
	wire				 VAL_o;		//Column Output Valid signal 
	wire 			 	 OV_o;		//Overflow


	//Top module instantiation: Include I/O signals and change the port name if needed.
	MatMul	#(N,T) MatMul	(
		.CLK		(CLK),
		.RSTN		(RSTN),
		.Weight_i	(Weight_i),
		.In_i		(In_i),
		
		.OUT_o		(OUT_o),
		.VAL_o		(VAL_o),
		.OV_o		(OV_o)
	);

	

	// --------------------------------------------
	// Load Weight (5 X N) and Input (N X T) test matrices.
	// --------------------------------------------
	// Caution : Assumption : input files have hex data like below. 
	//			 Weight     : (1,1) (1,2) ... (1,N)
	//          (N= 1~5)      (2,1) (2,2) ... (2,N)
	//                        (3,1) (3,2) ... (3,N)
	//                        (4,1) (4,2) ... (4,N)
	//                        (5,1) (5,2) ... (5,N)
	//
	//		  In_transpose  : (1,1) (1,2) ... (1,N)
	//          (N= 1~5)      (2,1) (2,2) ... (2,N)
	//          (T=No limit)  (3,1) (3,2) ... (3,N)
	//                         ...   ...  ...  ...
	//                        (T,1) (T,1) ... (T,N)
	
	reg		[5*8-1:0]    weight [0:4];
	reg		[5*8-1:0]    in_transpose [0:T-1];
	
	//Do not change the hex file name.
	initial begin
		$readmemh("weight.hex", weight);
		$readmemh("in_transpose.hex", in_transpose);
	end

	integer i;

	initial begin
		RSTN <= 1'b0;
		#(10*PERIOD) RSTN <= 1'b1;
		#(10*PERIOD) RSTN <= 1'b0;
		
		////////////////////////////////////////////////////
		//Write your own testbench to test your module.
		//Do not manually insert input data (Weight, In) in this space.
		//Input data should only be inserted by wiring from the hex file mentioned above.
		////////////////////////////////////////////////////

		//Signal Initialization
		Weight_i <= 40'b0;
		In_i <= 40'b0;

		
		//Weight insertion
		for (i=0; i<5; i+=1) begin
			#(1*PERIOD) Weight_i <= weight[i];
		end
		#(1*PERIOD) Weight_i <= 40'b0;

		//'In' insertion column by column (N data stored in a single vector in 'in_transpose')
		for (i=0; i<T; i=i+1) begin
			#(1*PERIOD) In_i <= in_transpose[i];
		end
		#(1*PERIOD) In_i <= 40'b0;		

		#(100*PERIOD);
		$finish();
	end

	/// Waveform Dump ///
	initial begin
		$display("Dump variables..");
		$dumpfile("./prj1.vcd");
		$dumpvars(0, testbench);
	end

endmodule

