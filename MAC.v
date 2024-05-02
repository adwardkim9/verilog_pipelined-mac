module pipeMAC (clk, reset_n, opA, opB, start, count, finish, out);
	input clk, reset_n;
	input start;
	input [4:0] count;
	input signed [7:0] opA, opB;
	
	output finish;
	output signed [15:0] out;

//Pipe Reg0 - MUL - Pipe Reg1 - ADD - Pipe Reg2 ->OUT

	reg	[4:0] creg;
	wire	Zero = (creg == 0);	// counter is zero
	wire	en = (creg != 0); // en when counter reg is not zero

	// State
	parameter IDLE = 2'b00;
	parameter MUL = 2'b01;
	parameter ADD = 2'b10;

	// Registers
	reg [1:0] present_state, next_state;
	reg signed [15:0] reg0, reg1, reg2;

	//Simple Counter-based CTRL
	// If start -> Set creg to count. If Zero -> Stop decrement.
	
	always @(posedge clk or negedge reset_n) begin
		if(!reset_b)
			present_state <= IDLE;
			reg0 <= 0;
			reg1 <= 0;
			reg2 <= 0;
		else
			present_state <= next_state;
	end

	case(present_state)
		IDLE: begin
			next_state <= MUL;
			reg0 <= {opA, opB};
		end
		MUL: begin
			next_state <= ADD;
			reg1 <= reg0[15:8] * reg0[7:0];
		end
		ADD: begin
			next_state <= IDLE;
			if(Zero)
				reg2 <= reg2;
			else
				reg2 <= reg2 + reg1;
		end
		default: 
	endcase

	//DATAPATH (Declare any additional regs/wires if required.)
	
	
	//Pipe Reg0
	

	//MUL


	//Pipe Reg1


	//ADD

	
	//Pipe Reg2



endmodule