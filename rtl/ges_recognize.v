module  ges_recognize
(
	input	wire			sys_clk		,
	input	wire			sys_rst_n	,
	
	output	wire			scl			,
	output	reg				led_up		,
	output	reg				led_down	,
	output	reg				led_left	,
	output	reg				led_right	,
	output	wire			beep		,
	output		    [5:0]	sel			,
	output 		    [7:0]	dig			,

	inout	wire			sda
);

wire	[5:0]	cfg_num		;
wire	[15:0]	cfg_data	;
wire			i2c_start	;
wire			i2c_clk		;
wire	[2:0]	step		;
wire			cfg_start	;
wire	[7:0]	po_data		;
wire	[3:0]	cnt_num		;		//分为
wire    [3:0]	cnt_unit	;


always@(posedge sys_clk or negedge sys_rst_n)
	if(sys_rst_n == 1'b0)
		begin
			led_up		<=  1'b0  ;
			led_down    <=  1'b0  ;
			led_left    <=  1'b0  ;
			led_right   <=  1'b0  ;
		end
	else  if(po_data == 8'h1)
		begin
			led_up		<=  1'b1  ;
			led_down    <=  1'b0  ;
			led_left    <=  1'b0  ;
			led_right   <=  1'b0  ;		
		end
	else  if(po_data == 8'h2)
		begin
			led_up		<=  1'b0  ;
			led_down    <=  1'b1  ;
			led_left    <=  1'b0  ;
			led_right   <=  1'b0  ;		
		end
	else  if(po_data == 8'h4)
		begin
			led_up		<=  1'b0  ;
			led_down    <=  1'b0  ;
			led_left    <=  1'b1  ;
			led_right   <=  1'b0  ;		
		end
	else  if(po_data == 8'h8)
		begin
			led_up		<=  1'b0  ;
			led_down    <=  1'b0  ;
			led_left    <=  1'b0  ;
			led_right   <=  1'b1  ;		
		end
	else
		begin
			led_up		<=  1'b0  ;
			led_down    <=  1'b0  ;
			led_left    <=  1'b0  ;
			led_right   <=  1'b0  ;
		end		

i2c_ctrl u_i2c_ctrl(
    .sys_clk    ( sys_clk    ),
    .sys_rst_n  ( sys_rst_n  ),
    .cfg_num    ( cfg_num    ),
    .cfg_data   ( cfg_data   ),
    .i2c_start  ( i2c_start  ),
    .scl        ( scl        ),
    .i2c_clk    ( i2c_clk    ),
    .step       ( step       ),
    .cfg_start  ( cfg_start  ),
    .po_data    ( po_data    ),
    .sda 		( sda        )
);  


cfg_ctrl  cfg_ctrl_inst
(
	.i2c_clk	(i2c_clk	),
	.sys_rst_n	(sys_rst_n	),
	.step		(step		),
	.cfg_start	(cfg_start	),
	.cfg_num	(cfg_num	),
	.cfg_data	(cfg_data	),
	.i2c_start	(i2c_start	)
);

seg_dynamic u_seg_dynamic(
    .sys_clk    ( sys_clk    ),
    .sys_rst_n  ( sys_rst_n  ),
    .cnt_num    ( cnt_num    ),
    .cnt_unit   ( cnt_unit   ),
    .sel        ( sel        ),
    .dig        ( dig        )
);





beep u_beep(
    .sys_clk    ( sys_clk    ),
    .sys_rst_n  ( sys_rst_n  ),
    .cnt_num    ( cnt_num    ),
    .cnt_unit   ( cnt_unit   ),
    .beep       ( beep       )
);


endmodule