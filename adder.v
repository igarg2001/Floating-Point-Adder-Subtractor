/* 
* FLOATING POINT HALF-PRECISION ADDER-SUBTRACTOR (16-bit)
* USES 16-bit BARREL SHIFTER
* GROUP MEMBERS:
** JAGRIT LODHA : 2019A3PS0165P
** ISHAN GARG : 2019A7PS0034P
*/


//main module consisting of adder/subtractor logic
module hp_adder (hp_inA, hp_inB, hp_sum, Exceptions);
	input [15:0] hp_inA;
	input [15:0] hp_inB;
	output reg [15:0] hp_sum;
	output reg [1:0] Exceptions;
	
	reg [9:0] man_A, man_B;
	reg [4:0] exp_A, exp_B;
	reg 	  sign_A, sign_B;
	
	reg [5:0] exp_sum;
	reg sign_sum;
    reg [9:0] man_sum;
	
	reg [4:0] shift_amt;
	reg [9:0] man_big, man_small;
	
	
	reg [15:0] barrel_man_big, barrel_man_small;
	reg [15:0] temp_sum;
	wire [15:0] barrel_man_shifted;
	
	reg [1:0] check_operation;
	reg [1:0] check_rounding;
	reg [1:0] check_normalise;
	
	reg [13:0] round_sum;
	
	reg [3:0] i;
	reg flag;
	reg [3:0] pos_1;
	reg [3:0] normalise_amt;

	barrelLR s1 (barrel_man_small, shift_amt[3:0], barrel_man_shifted, 1'b1, 1'b0);
	
	always @(*) begin
		
		// Breaking up the half-precision number
		sign_A = hp_inA[15];
		exp_A = hp_inA[14:10];
		man_A = hp_inA[9:0];
		sign_B = hp_inB[15];
		exp_B = hp_inB[14:10];
		man_B = hp_inB[9:0];
		Exceptions = 2'bxx;
		
		// Checking for exceptions (NaN, Infinity, etc)
		
		// If any of the inputs is infinity, set Exceptions flag to 11
		if ( (exp_A==31 && man_A==10'b0) || (exp_B==31 && man_B==10'b0)) begin
			Exceptions = 2'b11;
			hp_sum = 16'bx;
			$display("Invalid Input - Atleast one of the inputs is infinity");
		end
		
		// If any of the inputs is NaN, set Exceptions flag to 11
		else if ( (exp_A==31 && man_A!=10'b0) || (exp_B==31 && man_B!=10'b0)) begin
			Exceptions = 2'b11;
			hp_sum = 16'bx;
			$display("Invalid Input - Atleast one of the inputs is NaN");
		end
		
		// If any of the inputs is a Denormalized number, set Exceptions flag to 11
		else if ( (exp_A==0 && man_A!=10'b0) || (exp_B==0 && man_B!=10'b0)) begin
			Exceptions = 2'b11;
			hp_sum = 16'bx;
			$display("Invalid Input - Atleast one of the inputs is a Denormalized number");
		end
		
		// If any of the inputs is zero, set output to the other input
		// This is just done to save execution time in certain cases
		else if (exp_A==0 && man_A==10'b0) begin
            $display("Valid Input - One of the inputs is Zero");
			Exceptions = 2'b00;
			hp_sum = hp_inB;
		end
		else if (exp_B==0 && man_B==10'b0) begin
            $display("Valid Input - One of the inputs is Zero");
			Exceptions = 2'b00;
			hp_sum = hp_inA;
		end
		
		// Now dealing with Floating point numbers
		else begin
		
			// To find out which input has the greater magnitude
			if ( (exp_A>exp_B) || (exp_A==exp_B && man_A>man_B)) begin
				
				exp_sum = {1'b0, exp_A};
				sign_sum = sign_A;
				man_big = man_A;
				man_small = man_B;
				shift_amt = exp_A - exp_B;
				// If the shift amount is more than 12, then the output is Input A
				// 12 bits = 10 bit Mantissa + 1 Guard bit + 1 Round bit
				if (shift_amt>12) begin
					hp_sum = hp_inA;
					Exceptions = 2'b00;
				end
			end
			
			else if ( (exp_B>exp_A) || (exp_B==exp_A && man_B>man_A)) begin
			
				exp_sum = {1'b0, exp_B};
				sign_sum = sign_B;
				shift_amt = exp_B - exp_A;
				man_big = man_B;
				man_small = man_A;
				// If the shift amount is more than 12, then the output is Input B
				// 12 bits = 10 bit Mantissa + 1 Guard bit + 1 Round bit
				if (shift_amt>12) begin
					// $display("If the shift amount is more than 12, then the output is Input B");
					hp_sum = hp_inB;
					Exceptions = 2'b00;
				end
			end
			
			// If both inputs have same magnitude but opposite sign, output = 0
			else if (sign_A ^ sign_B == 1'b1) begin
				
				hp_sum = 16'b0;
				Exceptions = 2'b00;
			end
			
			// Numbers are of same magnitude and sign
			else begin
				exp_sum = exp_A;
				sign_sum = sign_A;
				man_small = man_A;
				man_big = man_A;
				shift_amt = 5'b0;
			end
			
			// Now we have the sign bit of the output with us
			// We also have the amount of mantissa shift required

			/* We check this condition to save execution time, so that the 
			already calculated results do not have to go through the following computations*/
			if (Exceptions === 2'bxx) begin

				/*For both the following variables, the LSB 2 bits represent the Guard and Round bits
				The MSB 0 Bits are to cover the overflow cases
				The MSB side bit 1 is the implicit 1 as defined by IEEE Standnrds*/
				barrel_man_small = {3'b001, man_small, 2'b00};
				barrel_man_big = {3'b001, man_big, 2'b00};
				
				// Shifting of mantissa done here, as the barrel shifter module gets called at this point
				
				
				if (sign_A ^ sign_B == 1'b1)
					temp_sum = barrel_man_big - barrel_man_shifted; // Subtraction
				else
					temp_sum = barrel_man_big + barrel_man_shifted; // Addition

				/*check_operation = {sign_A, sign_B};
				case (check_operation)
					2'b00:
						temp_sum = barrel_man_big + barrel_man_shifted;
					2'b01:
						temp_sum = barrel_man_big - barrel_man_shifted;
					2'b10:
						temp_sum = barrel_man_shifted - barrel_man_big;
					2'b11:
						temp_sum = - barrel_man_big - barrel_man_shifted;
				endcase*/
				
				
				
				// Now Rounding Up of the mantissa sum is to be done
				check_rounding = temp_sum[1:0]; // The LSB bits are the Guard and Round bits
				case(check_rounding)
					2'b00: // Simple truncation
						round_sum = temp_sum[15:2];
					2'b01: // Simple truncation
						round_sum = temp_sum[15:2];
					2'b10: begin // The rounding even scheme is used here
						if (temp_sum[2] == 1'b0)
							round_sum = temp_sum[15:2];
						else
							round_sum = temp_sum[15:2] + 14'd1;
					end
					2'b11: // rounding up
						round_sum = temp_sum[15:2] + 14'd1;
				endcase
				
				// Now we will normalise the mantissa
				check_normalise = round_sum[11:10]; //The two bits to be checked for deciding whether to normalise or not
				case (check_normalise)
					2'b01: begin
						man_sum = round_sum[9:0]; //Normalization not needed
					end
					2'b10: begin
						man_sum = round_sum[10:1]; //Normalization of mantissa
						exp_sum = exp_sum + 5'd1; //Normalizing exponent by incrementing it
					end
					2'b11: begin
						man_sum = round_sum[10:1]; //Normalization of mantissa
						exp_sum = exp_sum + 5'd1; //Normalizing exponent by incrementing it
					end
					2'b00: begin
						man_sum = 10'b0; //Initialising all bits to 0
						flag = 1'b1; //Flag for terminating loop, acts as the break of C
						for (i = 0; i < 10; i = i + 1) begin //Finding out first occurrence of 1 in round_sum
							// $display("i = %d\n", i);
							if (flag==1 && round_sum[9-i]==1) begin
								pos_1 = 9-i; //Store position of first occurence of i
								flag = 1'b0; //Set flag to 0 for no further computation
							end
						end
						
						/*for (i=pos_1-1; i>=0; i=i-1) begin
							man_sum[8-i] = temp_sum[i];
						end
						for (i = 0; i < pos_1; i = i + 1) begin
							man_sum
						end*/
						for (i = 4'd0; i < pos_1; i = i + 4'd1) begin //Copy the contents of temp sum from the right of pos_1 to 0, to man_sum. 
							man_sum[9-i] = temp_sum[pos_1-4'd1-i]; 
						end
						normalise_amt = 10-pos_1; //No of bits to be normalised
						// man_sum[(pos_1-1):0] = temp_sum[(pos_1-1):0];
						// man_sum = man_sum << normalise_amt;
						exp_sum = exp_sum - normalise_amt; //Normalise exponent by normalise_amt no of bits
						// man_sum = {temp_sum[(pos_1-1)-:0]};
					end
				endcase
				
				// Checking for Underflow and Overflow
				//Exponent range : 1 to 30, unsigned and w/o subtracting bias. 
				if ($signed(exp_sum) < 1) begin //Underflow
					Exceptions = 2'b10;
					hp_sum = 16'bx;
				end
				else if (exp_sum > 30) begin //Overflow
					Exceptions = 2'b01;
					hp_sum = 16'bx;
				end
				else begin //Normal
					hp_sum = {sign_sum, exp_sum[4:0], man_sum};
					Exceptions = 2'b00;
				end
				
			end
		end
	end
endmodule

//testbench
module testbench_adder;
	reg [15:0] hp_inA, hp_inB;
	wire [15:0] hp_sum;
	wire [1:0] Exceptions;

	reg [4:0] count;

	hp_adder B1 (hp_inA, hp_inB, hp_sum, Exceptions);

	initial begin
		count = 5'd0;

		//1. A = 2, B = 3. Normal
		#0;
		hp_inA = 16'b0100000000000000;
		hp_inB = 16'b0100001000000000;
		count = count + 5'd1;

		//2. A = 2, B = 2. Normal, same sign and magnitude
		#10;
		hp_inA = 16'b0100000000000000;
		hp_inB = 16'b0100000000000000;
		count = count + 5'd1;

		//3. A=0, B=4.9. Normal, Addition by zero
		#10;
		hp_inA = 16'b0000000000000000;
		hp_inB = 16'b0100010011100110;
		count = count+5'd1;

		//4. A=+inf, B=4.9. Invalid Input, Addition by Infintiy
		#10;
		hp_inA = 16'b0111110000000000;
		hp_inB = 16'b0100010011100110;
		count = count+5'd1;
		
		//5. A=-inf, B=0.  Invalid Input, Addition by Infintiy
		#10;
		hp_inA = 16'b1111110000000000;
		hp_inB = 16'b0000000000000000;
		count = count+5'd1;

		//6. A=NaN, B=4.9.  Invalid Input, Addition by NaN
		#10;
		hp_inA = 16'b0111110100000100;
		hp_inB = 16'b0100010011100110;
		count = count+5'd1;

		//7. A=-NaN, B=0. Invalid Input, Addition by NaN
		#10;
		hp_inA = 16'b1111110100000100;
		hp_inB = 16'b0000000000000000;
		count = count+5'd1;

		//8. A=+Denormalized B=4.9. Invalid Input, Addition by subnormal number
		#10;
		hp_inA = 16'b0000000100011110;
		hp_inB = 16'b0100010011100110;
		count = count+5'd1;

		//9. A=-Denormalized B=0. Invalid Input, Addition by subnormal number
		#10;
		hp_inA = 16'b1000000100011110;
		hp_inB = 16'b0000000000000000;
		count = count+5'd1;

		//10. A = 2, B = -2, Same magnitude, opposite sign
		#10;
		hp_inA = 16'b0100000000000000;
		hp_inB = 16'b1100000000000000;
		count = count + 5'd1;

		//11. A = 2, B = -3, Normal subtraction
		#10;
		hp_inA = 16'b0100000000000000;
		hp_inB = 16'b1100001000000000;
		count = count + 5'd1;

		//12. A = 49152, B = 57344 Overflow
		#10;
		hp_inA = 16'b0111101000000000;
		hp_inB = 16'b0111101100000000;
		count = count + 5'd1;

		//13. A = -49152, B = -57344 Overflow
		#10;
		hp_inA = 16'b1111101000000000;
		hp_inB = 16'b1111101100000000;
		count = count + 5'd1;

		//14. A = -1.625 * 2^-14, B = 1.5 * 2^-14 Underflow
		#10;
		hp_inA = 16'b1000011010000000;
		hp_inB = 16'b0000011000000000;
		count = count + 5'd1;

		//15. A = 1.5 * 2^10, B = 1.25 * 2^7 3 exp shifts in beginning
		#10;
		hp_inA = 16'b0110011000000000;
		hp_inB = 16'b0101100100000000;
		count = count + 5'd1;

		//16. A = 1.663 * 2^6 B = 1.125 * 2^8 round up (0.017% error, possibly due to half-precision)
		#10;
		hp_inA = 16'b0101011010100110;
		hp_inB = 16'b0101110010000000;
		count = count + 5'd1;
		
		//17. A = -96 B = 26
		#10;
		hp_inA = 16'b1101011000000000;
		hp_inB = 16'b0100111010000000;
		count = count + 5'd1;

		//18.A = 1000 B = 26
		#10;
		hp_inA = 16'b0110001111010000;
		hp_inB = 16'b0100111010000000;
		count = count + 5'd1;

		//19. A = -1000 B = -1000
		#10;
		hp_inA = 16'b1110001111010000;
		hp_inB = 16'b1110001111010000;
		count = count + 5'd1;

		//20. A = 69 B = 420
		#10;
		hp_inA = 16'b0101010001010000;
		hp_inB = 16'b0101111010010000;
		count = count + 5'd1;

		//21. A = 3 B = -2.5
		#10;
		hp_inA = 16'b0100001000000000;
		hp_inB = 16'b1100000100000000;
		count = count + 5'd1;

		#10; $finish; 
	end
	initial begin
		$monitor("Test case = %d\nA = %b\nB = %b\nOutput = %b\nExceptions=%b\n", count, hp_inA, hp_inB, hp_sum, Exceptions);
	end
endmodule




//Support modules
module barrelLR(A,shift,op,direction,val);
	input [15:0]A;
	input direction;
	input [3:0]shift;
	output [15:0]op;
	input val;
	
	wire [15:0]w1,w2;
	MUX16_2x1_s M1(direction,A[15:0],w1);
	barrel b(w1,shift,w2,val);
	MUX16_2x1_s M2(direction,w2[15:0],op);

endmodule

module barrel(A,shift,op,val);
	input [0:15] A;
	input [3:0] shift;
	input val;
	output [0:15] op;

	wire [15:0] w,x,y;
	MUX2 a0_0(shift[0],val,A[0],w[0]);
	MUX2 a0_1(shift[0],A[0],A[1],w[1]);
	MUX2 a0_2(shift[0],A[1],A[2],w[2]);
	MUX2 a0_3(shift[0],A[2],A[3],w[3]);
	MUX2 a0_4(shift[0],A[3],A[4],w[4]);
	MUX2 a0_5(shift[0],A[4],A[5],w[5]);
	MUX2 a0_6(shift[0],A[5],A[6],w[6]);
	MUX2 a0_7(shift[0],A[6],A[7],w[7]);
	MUX2 a0_8(shift[0],A[7],A[8],w[8]);
	MUX2 a0_9(shift[0],A[8],A[9],w[9]);
	MUX2 a0_10(shift[0],A[9],A[10],w[10]);
	MUX2 a0_11(shift[0],A[10],A[11],w[11]);
	MUX2 a0_12(shift[0],A[11],A[12],w[12]);
	MUX2 a0_13(shift[0],A[12],A[13],w[13]);
	MUX2 a0_14(shift[0],A[13],A[14],w[14]);
	MUX2 a0_15(shift[0],A[14],A[15],w[15]);

	MUX2 a1_0(shift[1],val,w[0],x[0]);
	MUX2 a1_1(shift[1],val,w[1],x[1]);
	MUX2 a1_2(shift[1],w[0],w[2],x[2]);
	MUX2 a1_3(shift[1],w[1],w[3],x[3]);
	MUX2 a1_4(shift[1],w[2],w[4],x[4]);
	MUX2 a1_5(shift[1],w[3],w[5],x[5]);
	MUX2 a1_6(shift[1],w[4],w[6],x[6]);
	MUX2 a1_7(shift[1],w[5],w[7],x[7]);
	MUX2 a1_8(shift[1],w[6],w[8],x[8]);
	MUX2 a1_9(shift[1],w[7],w[9],x[9]);
	MUX2 a1_10(shift[1],w[8],w[10],x[10]);
	MUX2 a1_11(shift[1],w[9],w[11],x[11]);
	MUX2 a1_12(shift[1],w[10],w[12],x[12]);
	MUX2 a1_13(shift[1],w[11],w[13],x[13]);
	MUX2 a1_14(shift[1],w[12],w[14],x[14]);
	MUX2 a1_15(shift[1],w[13],w[15],x[15]);

	MUX2 a2_0(shift[2],val,x[0],y[0]);
	MUX2 a2_1(shift[2],val,x[1],y[1]);
	MUX2 a2_2(shift[2],val,x[2],y[2]);
	MUX2 a2_3(shift[2],val,x[3],y[3]);
	MUX2 a2_4(shift[2],x[0],x[4],y[4]);
	MUX2 a2_5(shift[2],x[1],x[5],y[5]);
	MUX2 a2_6(shift[2],x[2],x[6],y[6]);
	MUX2 a2_7(shift[2],x[3],x[7],y[7]);
	MUX2 a2_8(shift[2],x[4],x[8],y[8]);
	MUX2 a2_9(shift[2],x[5],x[9],y[9]);
	MUX2 a2_10(shift[2],x[6],x[10],y[10]);
	MUX2 a2_11(shift[2],x[7],x[11],y[11]);
	MUX2 a2_12(shift[2],x[8],x[12],y[12]);
	MUX2 a2_13(shift[2],x[9],x[13],y[13]);
	MUX2 a2_14(shift[2],x[10],x[14],y[14]);
	MUX2 a2_15(shift[2],x[11],x[15],y[15]);

	MUX2 a3_0(shift[3],val,y[0],op[0]);
	MUX2 a3_1(shift[3],val,y[1],op[1]);
	MUX2 a3_2(shift[3],val,y[2],op[2]);
	MUX2 a3_3(shift[3],val,y[3],op[3]);
	MUX2 a3_4(shift[3],val,y[4],op[4]);
	MUX2 a3_5(shift[3],val,y[5],op[5]);
	MUX2 a3_6(shift[3],val,y[6],op[6]);
	MUX2 a3_7(shift[3],val,y[7],op[7]);
	MUX2 a3_8(shift[3],y[0],y[8],op[8]);
	MUX2 a3_9(shift[3],y[1],y[9],op[9]);
	MUX2 a3_10(shift[3],y[2],y[10],op[10]);
	MUX2 a3_11(shift[3],y[3],y[11],op[11]);
	MUX2 a3_12(shift[3],y[4],y[12],op[12]);
	MUX2 a3_13(shift[3],y[5],y[13],op[13]);
	MUX2 a3_14(shift[3],y[6],y[14],op[14]);
	MUX2 a3_15(shift[3],y[7],y[15],op[15]);

endmodule

module MUX2(S,I1,I2,op);
	input S;
	input I1,I2;
	output op;
	assign op=I2&!S | I1&S ;
	// assign op=( I1 & (S0 & S1) | I2 & (S0 & !S1) | I3 & (!S0 & S1) | I4 & (!S0 & !S1) ;
endmodule
module MUX16_2x1_s(S,I1,op);
	input S;
	input [15:0]I1;
	output [15:0]op;
	MUX2 a0(S,I1[15],I1[0],op[15]);
	MUX2 a1(S,I1[14],I1[1],op[14]);
	MUX2 a2(S,I1[13],I1[2],op[13]);
	MUX2 a3(S,I1[12],I1[3],op[12]);
	MUX2 a4(S,I1[11],I1[4],op[11]);
	MUX2 a5(S,I1[10],I1[5],op[10]);
	MUX2 a6(S,I1[9],I1[6],op[9]);
	MUX2 a7(S,I1[8],I1[7],op[8]);
	MUX2 a8(S,I1[7],I1[8],op[7]);
	MUX2 a9(S,I1[6],I1[9],op[6]);
	MUX2 a10(S,I1[5],I1[10],op[5]);
	MUX2 a11(S,I1[4],I1[11],op[4]);
	MUX2 a12(S,I1[3],I1[12],op[3]);
	MUX2 a13(S,I1[2],I1[13],op[2]);
	MUX2 a14(S,I1[1],I1[14],op[1]);
	MUX2 a15(S,I1[0],I1[15],op[0]);
endmodule