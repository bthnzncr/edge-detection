
module display_template (clk, rst, BTN_EAST, BTN_WEST, hs, vs, R, G, B, LED1, LED2);

//------------------------------------------------------------------------------
// IO ports
//------------------------------------------------------------------------------
// input
input clk;
input rst;
input BTN_EAST;
input BTN_WEST;
// output
output hs;
output vs;
output reg R;
output reg G;
output reg B;
output reg LED1;
output reg LED2;

//------------------------------------------------------------------------------
// VGA Controller
//------------------------------------------------------------------------------
// VGA display connections
wire [10:0] hcount;
wire [10:0] vcount;
wire blank;

// VGA controller instantiation
vga_controller_640_60 vga_cont (.clk(clk), 
				.rst(rst), 
				.HS(hs), 
				.VS(vs), 
				.hcount(hcount), 
				.vcount(vcount), 
				.blank(blank));

//------------------------------------------------------------------------------
// Input LENA image BRAM
//------------------------------------------------------------------------------
// Input Lena Image BRAM connections
wire [13:0] addr;  		// lena input BRAM read address
wire [7:0]  data_out;		// lena input BRAM pixel output
reg [13:0]  read_addr_in;	// lena input BRAM read address (for display)
reg [13:0]  read_addr_op; 	// lena input BRAM read address (for operation)

// Block RAM instantiation
lena_input lena_in(
	.addra(addr),
	.clka(clk),
	.douta(data_out));

//------------------------------------------------------------------------------
// Output Image BRAM
//------------------------------------------------------------------------------
// connections
reg wen_out;		// output BRAM write enable signal
reg [13:0] raddr_out;	// output BRAM read address
reg [13:0] waddr_out;	// output BRAM write address
reg [7:0]  wdata_out;	// output BRAM pixel input
wire[7:0]  rdata_out;	// output BRAM pixel output

// Block RAM instantiation
block_ram result(
.clk       (clk),
.write_en  (wen_out),
.read_addr (raddr_out),
.write_addr(waddr_out),
.write_data(wdata_out),
.data_out  (rdata_out)
);

//------------------------------------------------------------------------------
// operation starts here
//------------------------------------------------------------------------------
// states
parameter IDLE = 0;			// no button is pressed
parameter BTN1_PRESS = 1;		// BTN_WEST is pressed
parameter OP_FINISHED= 2;		// output image is generated and stored in output block ram
parameter BTN2_PRESS = 3;		// BTN_EAST is pressed

// all necessary wires/regs
reg [1:0] curr_state,next_state;	// state registers

reg [7:0] I00;
reg [7:0] I01;
reg [7:0] I02;
reg [7:0] I03;
reg [7:0] I04;
reg [7:0] I05;
reg [7:0] I06;
reg [7:0] I07;
reg [7:0] I08;				// pixels read from input BRAM

reg  signed [10:0] sobel_x;
reg  signed [10:0] sobel_y;

reg [6:0] row_addr,col_addr;		// row/col registers for address generation
reg [4:0] op_counter;			// operation counter for operation on each pixel

reg [7:0] sobel_pixel;		// sobel pixel

reg [6:0] address_row1;
reg [6:0] address_row2;
reg [6:0] address_row3;
reg [6:0] address_col1;
reg [6:0] address_col2;
reg [6:0] address_col3;
// state transition
always @(posedge clk or posedge rst) begin
	if(rst)
		curr_state <= 0;
	else
		curr_state <= next_state;
end

// state transition
always @ (*) begin
	case(curr_state)
	IDLE: begin
		if(BTN_WEST)
			next_state = BTN1_PRESS;
		else
			next_state = IDLE;
	end
	BTN1_PRESS: begin
		// if all pixel are finished one, go to OP_FINISHED state
		if((curr_state == BTN1_PRESS) && (row_addr == 127) && (col_addr == 127) && (op_counter == 19))
			next_state = OP_FINISHED;
		else
			next_state = BTN1_PRESS;
	end
	OP_FINISHED: begin
		if(BTN_EAST)
			next_state = BTN2_PRESS;
		else
			next_state = OP_FINISHED;
	end
	BTN2_PRESS: begin
		next_state = BTN2_PRESS;
	end
	default: begin
		next_state = IDLE;
	end
	endcase
end

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////// operation starts here
always @ (posedge clk or posedge rst) 
begin
	if (rst) 
	begin
		row_addr <= 0;
		col_addr <= 0;
		
		op_counter <= 0;
	end		
	else 
	begin
		if(curr_state == BTN1_PRESS) begin
			col_addr <= (op_counter == 20) ? (col_addr + 1) : col_addr; 							// if a pixel's operation is finished, go to next column
			row_addr <= ((op_counter == 20) && (col_addr == 127)) ? (row_addr + 1) : row_addr; 	// if all pixels in a row is finished, go to nex row
			
			// op_counter:
			// 0: generate read address for input image 
			// 1: save pixel read from input image into a register
			// 2-20: operate the the pixel
			
			// if counter is 20, set it to 0
			if(op_counter == 20)
				op_counter <= 0;
			else
				op_counter <= op_counter + 1;
		end
	end
end


// read pixels from input lena using its address
// op_counter:0-16 -> generate read address for input image 
always @ (*) 
begin
if((col_addr == 0) | (col_addr == 127)  | (row_addr == 0) | (row_addr == 127))

read_addr_op = 0;

else
  address_row1=row_addr-1;
  address_row2=row_addr;
   address_row3=row_addr+1;
   address_col1=col_addr-1;
  address_col2=col_addr;
  address_col3=col_addr+1;
 
	case(op_counter)
	5'd0: read_addr_op = {address_row1,address_col1};
	5'd2: read_addr_op = {address_row1,address_col2};
	5'd4: read_addr_op = {address_row1,address_col3};
	5'd6: read_addr_op = {address_row2,address_col1};
	5'd8: read_addr_op = {address_row2,address_col2};
	5'd10: read_addr_op ={address_row2,address_col3};
	5'd12: read_addr_op ={address_row3,address_col1};
	5'd14: read_addr_op ={address_row3,address_col2};
	5'd16: read_addr_op ={address_row3,address_col3};
	endcase
end

// op_counter:1 -> save pixel read from input image into a register
always @(posedge clk or posedge rst) 
begin
	if(rst) begin
		I00 <=0;
		I01 <=0;
		I02 <=0;
		I03 <=0;
		I04 <=0;
		I05 <=0;
		I06 <=0;
		I07 <=0;
		I08 <=0;
	end
	else begin
	if((col_addr != 0) && (col_addr != 127) && (row_addr != 0) && (row_addr != 127))
		begin
		case(op_counter)
		5'd1: I00 <= data_out;
		5'd3: I01 <= data_out;
		5'd5: I02 <= data_out;
		5'd7: I03 <= data_out;
		5'd9: I04 <= data_out;
		5'd11: I05 <= data_out;
		5'd13: I06 <= data_out;
		5'd15: I07 <= data_out;
		5'd17: I08 <= data_out;
		endcase
		end
	end
end

// op_counter:18 -> calculate the algorithm
always @(*)
begin
	if(op_counter == 18)
	begin
		if((col_addr == 0) | (col_addr == 127) |(row_addr == 0) | (row_addr == 127))
		begin
			sobel_pixel = 255;
		end	
		else
		begin
			sobel_x =
			(I02) -(I00)+
			((I05<<1)-(I03<<1))+
			((I08)-(I06));
			
			sobel_y =
			((I00)- (I06))+
			(I01<<1)-((I07) <<1)+
			(I02)-(I08);
			
		if (sobel_x < 0)
			sobel_x = -sobel_x;
		else 
			sobel_x = sobel_x;
			
		if (sobel_y < 0)
			sobel_y = -sobel_y;
		else 
		
			sobel_y = sobel_y;
		
		if ((sobel_x + sobel_y) >= 150)
		sobel_pixel = 0;
		else
		sobel_pixel = 255;
		end
end
	
	
end

// write data into output BRAM
always @ (posedge clk or posedge rst) 
begin
	if(rst) 
	begin
		wen_out   <= 0;
		waddr_out <= 0;
		wdata_out <= 0;
	end
	else 
	begin
		// if op_counter is 19, send the pixels into output BRAM with its address
		if((op_counter == 19) && (curr_state == BTN1_PRESS)) begin
			wen_out   <= 1;
			waddr_out <= {row_addr,col_addr};
			wdata_out <= sobel_pixel;
		end
		else begin
			wen_out   <= 0;
			waddr_out <= 0;
			wdata_out <= 0;
		end
	end
end
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// input BRAM address selection
// if the state is BTN1_PRESS; use read address of input image for operation; otherwise, use it for display
assign addr = (curr_state == BTN1_PRESS) ? read_addr_op : read_addr_in;

//------------------------------------------------------------------------------
// LEDs
//------------------------------------------------------------------------------
always @ (posedge clk or posedge rst) 
begin
	if(rst) begin
		LED1 <= 0;
		LED2 <= 0;
	end
	else begin
		// if current state is OP_FINISHED, turn on LED1
		if(curr_state == OP_FINISHED) begin
			LED1 <= 1;
			LED2 <= 0;		
		end
		// if BTN_EAST is pressed, turn on both LED1 and LED2
		else if(curr_state == BTN2_PRESS) begin
			LED1 <= 1;
			LED2 <= 1;
		end
		// otherwise, both LEDs should be OFF
		else begin
			LED1 <= 0;
			LED2 <= 0;
		end
	end
end

//------------------------------------------------------------------------------
// This always block generates read address and read pixel values from blockram
//------------------------------------------------------------------------------
// |            |   |             |
// |            |   |             |
// |            |   |             |
// | Input Img. |   | Output Img. |
// |            |   |             |
// |            |   |             |
// --------------   --------------
// 0           127 128           255
always @ (*)
begin
	// Read address generation for input (input image will be displayed at upper-left corner (128x128)
	if ((vcount < 10'd128) && (hcount < 10'd128))
		read_addr_in = {vcount[6:0], hcount[6:0]};
	else 
		read_addr_in = 14'd0; // Read address uses hcount and vcount from VGA controller as read address to locate currently displayed pixel
	
	// read address generation for output (output image will be displayed at next to input image (128x128)
	if ((vcount < 10'd128) && ((hcount >= 10'd128) && (hcount < 10'd256)))
		raddr_out = {vcount[6:0], hcount[6:0]};
	else
		raddr_out = 0;
	
	// Read pixel values 
	if (blank)
	begin	
		R = 1'b0;  // if blank, color outputs should be reset to 0 or black should be sent ot R,G,B ports
		G = 1'b0;  // if blank, color outputs should be reset to 0 or black should be sent ot R,G,B ports
		B = 1'b0;  // if blank, color outputs should be reset to 0 or black should be sent ot R,G,B ports
	end
	// if operation is finished or BTN2 is pressed, display input image
	else if ((vcount < 10'd128) && (hcount < 10'd128) && ((curr_state == OP_FINISHED) | (curr_state == BTN2_PRESS))) 
	begin
		R = data_out[7];  // pixel values are read here
		G = data_out[7];
		B = data_out[7];
	end
	// if BTN2 is pressed, display output image
	else if ((vcount < 10'd128) && ((hcount >= 10'd128) && (hcount < 10'd256)) && (curr_state == BTN2_PRESS)) begin
		R = rdata_out[7];  // pixel values are read here
		G = rdata_out[7];
		B = rdata_out[7];
	end
	else
	begin
		R = 1'b1; // outside of the image is white
		G = 1'b1; // outside of the image is white
		B = 1'b1; // outside of the image is white
	end
end

endmodule
