module pipeMAC (clk, reset_n, opA, opB, start, count, finish, out);
   input clk, reset_n;
   input start;
   input [4:0] count;
   input signed [7:0] opA, opB;
   
   output finish;
   output signed [15:0] out;

   //Pipe Reg0 - MUL - Pipe Reg1 - ADD - Pipe Reg2 ->OUT

   reg   [4:0] creg;
   wire   Zero = (creg == 0);   // counter is zero
   wire   en = (creg != 0); // en when counter reg is not zero
   
   
   //Simple Counter-based CTRL
   // If start -> Set creg to count. If Zero -> Stop decrement.
   always @(posedge clk or negedge reset_n) begin
      if (!reset_n)
         creg <= 0;
      else if (start)
         creg <= count;
      else if (Zero)
         creg <= 0;
      else
         creg <= creg - 1;
   end
      

   //DATAPATH (Declare any additional regs/wires if required.)
   reg signed [7:0] A_reg0, B_reg0;
   reg signed [15:0] AxB_reg1, ABplusC_reg2;
    reg en_reg0, en_reg1, en_reg2;
    wire signed [15:0] mul, acc;
   
   always @(posedge clk or negedge reset_n) begin
      if (!reset_n) begin
         en_reg0 <= 0;
         en_reg1 <= 0;
         en_reg2 <= 0;
      end
      else begin
         en_reg0 <= en;
         en_reg1 <= en_reg0;
         en_reg2 <= en_reg1;
      end
   end
   
   //Pipe Reg0
   always @(posedge clk or negedge reset_n) begin
      if (!reset_n) begin
         A_reg0 <= 0;
         B_reg0 <= 0;
      end
      else if (en) begin
         A_reg0 <= opA;
         B_reg0 <= opB;
      end
      else begin
         A_reg0 <= 0;
         B_reg0 <= 0;
      end
   //else 없으면 어케됨   
   end

   //MUL
   assign mul = A_reg0 * B_reg0;
   
   //Pipe Reg1
   always @(posedge clk or negedge reset_n) begin
      if (!reset_n) begin
         AxB_reg1 <= 0;
      end
      else if (en_reg0) begin
         AxB_reg1 <= mul;
      end
      else begin
         AxB_reg1 <= 0;
      end
   end

   //ADD
   assign acc = AxB_reg1 + ABplusC_reg2;
   
   //Pipe Reg2
   always @(posedge clk or negedge reset_n) begin
      if (!reset_n) begin
         ABplusC_reg2 <= 0;
      end
      else if (en_reg1) begin
         ABplusC_reg2 <= acc;
      end
   end
   
   assign out = ABplusC_reg2;
   assign finish = {en_reg2, en_reg1, en_reg0} == 3'b100;
   

endmodule