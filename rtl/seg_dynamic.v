module  seg_dynamic
(
	input	wire			sys_clk		,
	input	wire			sys_rst_n	,
	
	output 	reg		[3:0]	cnt_num		,		//分为
	output 	reg		[3:0]	cnt_unit	,		//秒位
	output	reg		[5:0]	sel			,
	output	reg		[7:0]	dig	 
);

localparam	CNT_DELAY_MAX  =  16'd50_000  ;
localparam	CNT_1S_MAX     =  26'd50_000_000  ;
localparam  NUM0 = 8'b1100_0000,//段码表
            NUM1 = 8'b1111_1001,
            NUM2 = 8'b1010_0100,
            NUM3 = 8'b1011_0000,
            NUM4 = 8'b1001_1001,
            NUM5 = 8'b1001_0010,
            NUM6 = 8'b1000_0010,
            NUM7 = 8'b1111_1000,
            NUM8 = 8'b1000_0000,
            NUM9 = 8'b1001_0000,
            NUMA = 8'b1000_1000,
            NUMB = 8'b1000_0011,
            NUMC = 8'b1100_0110,
            NUMD = 8'b1010_0001,
            NUME = 8'b1000_0110,
            NUMF = 8'b1000_1110;

reg		[15:0]	cnt_delay	;
reg		[2:0]	cnt_seg		;
reg		[25:0]	cnt_1s		;

always@(posedge sys_clk or negedge sys_rst_n)
	if(sys_rst_n == 1'b0)
		cnt_delay  <=  16'd0  ;
	else  if(cnt_delay == CNT_DELAY_MAX - 1'b1)
		cnt_delay  <=  16'd0  ;
	else
		cnt_delay  <=  cnt_delay + 1'b1  ;
		
always@(posedge sys_clk or negedge sys_rst_n)
	if(sys_rst_n == 1'b0)
		cnt_seg  <=  3'd0  ;
	else  if((cnt_seg == 3'd5)&&(cnt_delay == CNT_DELAY_MAX - 1'b1))
		cnt_seg  <=  3'd0  ;
	else  if(cnt_delay == CNT_DELAY_MAX - 1'b1)
		cnt_seg  <=  cnt_seg + 1'b1  ;
	else
		cnt_seg  <=  cnt_seg  ;


		
always@(posedge sys_clk or negedge sys_rst_n)
	if(sys_rst_n == 1'b0)		
		cnt_1s  <=  26'd0  ;
	else  if(cnt_1s == CNT_1S_MAX - 1'b1)
		cnt_1s  <=  26'd0  ;
	else
		cnt_1s  <=  cnt_1s + 1'b1 ;

always@(posedge sys_clk or negedge sys_rst_n)
	if(sys_rst_n == 1'b0)
		begin
		cnt_num  <=  4'd2  ;
		cnt_unit <=  4'd0  ;
		end 
	else if((cnt_num == 4'd10 )&&(cnt_unit <=  4'd10))
		begin
		cnt_num  <=  cnt_num  ;
		cnt_unit <=  cnt_unit ;
		end
	else  if((cnt_num == 4'd0)&&(cnt_unit == 4'd0)&&(cnt_1s == CNT_1S_MAX - 1'b1))
		begin
		cnt_num  <=  4'd10  ;
		cnt_unit <=  4'd10	;
		end
		
	else if((cnt_unit == 4'd0)&&(cnt_1s == CNT_1S_MAX - 1'b1))
		begin
		cnt_num <= cnt_num - 1'b1 ;
		cnt_unit <= 4'd9 ;
		end 	
	else  if(cnt_1s == CNT_1S_MAX - 1'b1)
		cnt_unit  <=  cnt_unit - 1'b1  ;
	
	else
		begin 
		cnt_num  <=  cnt_num  ;
		cnt_unit <=  cnt_unit ;
		end 


always@(posedge sys_clk or negedge sys_rst_n)
	if(sys_rst_n == 1'b0)
		begin
		sel  <=  6'b111_111  ;
		dig  <=  NUM0  ;
		end
	else  
		case(cnt_seg)
			3'd0	:	begin 
			sel  <=  6'b111_110  ;
			case(cnt_num)
				4'd0	:	dig  <=  NUM0  ;
				4'd1	:	dig  <=  NUM1  ;
				4'd2	:	dig  <=  NUM2  ;
				4'd3	:	dig  <=  NUM3  ;
				4'd4	:	dig  <=  NUM4  ;
				4'd5	:	dig  <=  NUM5  ;
				4'd6	:	dig  <=  NUM6  ;
				4'd7	:	dig  <=  NUM7  ;
				4'd8	:	dig  <=  NUM8  ;
				4'd9	:	dig  <=  NUM9  ;
				4'ha	:	dig  <=  NUMA  ;
				default	:	dig  <=  dig  ;
			endcase
			end
			3'd1	:	begin 
			sel  <=  6'b111_101  ;
			case(cnt_unit)
				4'd0	:	dig  <=  NUM0  ;
				4'd1	:	dig  <=  NUM1  ;
				4'd2	:	dig  <=  NUM2  ;
				4'd3	:	dig  <=  NUM3  ;
				4'd4	:	dig  <=  NUM4  ;
				4'd5	:	dig  <=  NUM5  ;
				4'd6	:	dig  <=  NUM6  ;
				4'd7	:	dig  <=  NUM7  ;
				4'd8	:	dig  <=  NUM8  ;
				4'd9	:	dig  <=  NUM9  ;
				4'ha	:	dig  <=  NUMA  ;
				default	:	dig  <=  dig  ;
			endcase
			end	
			default	:	sel  <=  sel  ;
		endcase	

endmodule