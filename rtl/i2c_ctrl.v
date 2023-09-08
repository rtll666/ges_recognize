module  i2c_ctrl
(
	input	wire			sys_clk		,	//系统时钟，频率50MHZ
	input	wire			sys_rst_n	,	//系统复位，低电平有效
	input	wire	[5:0]	cfg_num		,	//配置的寄存器个数
	input	wire	[15:0]	cfg_data	,	//高8位是配置的寄存器地址，低8位是向该地址写入的数据
	input	wire			i2c_start	,	//step = 4时IDLE状态跳转到START状态跳转信号
	
	output	wire			scl			,	//串行时钟信号
	output	reg				i2c_clk		,	//i2c驱动时钟，频率为1MHZ，便于产生SCL和SDA
	output	reg		[2:0]	step		,	//利用不同的值指示不同的操作步骤，以此控制不同的状态跳转
	output	reg				cfg_start	,	//由i2c_end寄存得到，cfg_start延迟i2c_end一个时钟周期
	output	reg		[7:0]	po_data		,	//采集到的手势数据输出
	
	inout	wire			sda				//串行数据信号
);

localparam	CNT_CLK_MAX  	=  5'd25   	;
localparam	CNT_WAIT_MAX 	=  10'd1000 ;
localparam	SLAVE_ID		=	7'h73	;
localparam	IDLE			=	4'd0	,
			START			=	4'd1	,
			SLAVE_ADDR		=	4'd2	,
			WAIT			=	4'd3	,
			STOP			=	4'd4	,
			ACK_1			=	4'd5	,
			DEVICE_ADDR		=	4'd6	,
			ACK_2			=	4'd7	,
			DATA			=	4'd8	,
			ACK_3			=	4'd9	,
			NACK			=	4'd10	;

reg		[4:0]	cnt_clk		;	//系统时钟计数器，最大值为25
reg		[9:0]	cnt_wait	;	//等待信号，等待1000us计数器
reg				skip_en_0	;	//唤醒操作跳转信号，只有当step为0时该跳转信号才拉高
reg				skip_en_1	;	//激活Bank0跳转信号，只有当step为1时该跳转信号才拉高
reg				skip_en_2	;	//读取0x00寄存器数据前半部分跳转信号，只有当step为2时该跳转信号才拉高
reg				skip_en_3	;	//读取0x00寄存器数据后半部分跳转信号，只有当step为3时该跳转信号才拉高
reg				skip_en_4	;	//配置寄存器组跳转信号，只有当step为4时该跳转信号才拉高
reg				skip_en_5	;	//读取0x43寄存器数据前半部分跳转信号，只有当step为5时该跳转信号才拉高
reg				skip_en_6	;	//读取0x43寄存器数据后半部分跳转信号，只有当step为6时该跳转信号才拉高
reg				error_en	;	//在DATA状态下未接收到0x20数据，该信号拉高
reg		[3:0]	n_state		;	//次态
reg		[3:0]	c_state		;	//现态
reg		[1:0]	cnt_i2c_clk	;	//i2c_clk时钟计数器，计数4个时钟就是一个SCL周期
reg		[2:0]	cnt_bit		;	//发送的bit数据计数器，计数最大是8
reg				i2c_scl		;	//这就是SCL信号，重定义i2c_scl是为了与i2c_sda保持同步
reg				i2c_sda		;	//当主机控制SDA时，产生的i2c_sda赋值给SDA，就是间接对SDA控制
wire			sda_en		;	//指示主机控制区域，该信号为高电平时，主机占用SDA总线
wire			sda_in		;	//直接将SDA赋值给sda_in，那么就可以采集从机向主机发送的数据，就是间接采集SDA上数据
reg				i2c_end		;	//在STOP状态最后一个时钟周期拉高
reg				ack_en		;	//响应有效信号
reg		[7:0]	rec_data	;	//读取的0x00寄存器数据寄存信号
reg		[7:0]	po_data_reg	;	//采集手势数据拼接寄存器
reg		[7:0]	slave_addr	;
reg		[7:0]	device_addr	;
reg		[7:0]	wr_data		;

assign  scl     =  i2c_scl  ;	//直接把产生的i2c_scl赋值给scl
//三态门
assign  sda_in  =  sda   ;  	//把sda数据赋值到sda_in上
assign  sda_en  =  ((c_state == ACK_1)||(c_state == ACK_2)||(c_state == ACK_3)||((c_state == DATA)&&(step == 3'd3))||((c_state == DATA)&&(step == 3'd6))) ? 1'b0 : 1'b1  ;		//为1时代表主机控制sda通信线
assign  sda     =  (sda_en == 1'b1) ? i2c_sda : 1'bz  ;	//当主机控制sda通信线时，将产生的i2c_sda信号赋值给sda；
														//主机不控制sda通信线时，置高阻态放弃对通信线的控制

always@(*)
	case(step)
		3'd0	:begin
					slave_addr 	= {SLAVE_ID,1'b0}  ;
					device_addr	= 8'h0  ;  //未使用
					wr_data		= 8'h0  ;  //未使用
				 end
		3'd1	:begin
					slave_addr 	= {SLAVE_ID,1'b0}  ;
					device_addr	= 8'hEF  ;  //Bank0地址
					wr_data     = 8'h0  ;  //写入0x00数据
				 end
		3'd2	:begin
					slave_addr  = {SLAVE_ID,1'b0}  ;
					device_addr = 8'h0  ;  //指定读取的0x00寄存器数据
					wr_data     = 8'h0  ;  //未使用
				 end
		3'd3	:begin
					slave_addr  = {SLAVE_ID,1'b1}  ;		
					device_addr = 8'h0  ;  //未使用
					wr_data     = 8'h0  ;  //未使用
				 end
		3'd4	:begin
					slave_addr  = {SLAVE_ID,1'b0}  ;		//cfg_data[23:16]
					device_addr = cfg_data[15:8]  ;	//传入待配置数据的高8位数据
					wr_data     = cfg_data[7:0]   ; //传入待配置数据的低8位数据
				 end
		3'd5	:begin
					slave_addr  = {SLAVE_ID,1'b0}  ;
					device_addr = 8'h43  ;  //指定读取的0x43寄存器数据
					wr_data     = 8'h0  ;  //未使用
				 end
		3'd6	:begin
					slave_addr  = {SLAVE_ID,1'b1}  ;		
					device_addr = 8'h0  ;  //未使用
					wr_data     = 8'h0  ;  //未使用
				 end		
		default	:begin
					slave_addr 	= 8'h0  ;
					device_addr = 8'h0  ;
					wr_data		= 8'h0  ;
				 end
	endcase
	
always@(posedge sys_clk or negedge sys_rst_n)
	if(sys_rst_n == 1'b0)
		cnt_clk  <=  5'd0  ;
	else  if(cnt_clk == CNT_CLK_MAX - 1'b1)
		cnt_clk  <=  5'd0  ;
	else
		cnt_clk  <=  cnt_clk + 1'b1  ;
		
always@(posedge sys_clk or negedge sys_rst_n)
	if(sys_rst_n == 1'b0)
		i2c_clk  <=  1'b0  ;
	else  if(cnt_clk == CNT_CLK_MAX - 1'b1)
		i2c_clk  <=  ~i2c_clk  ;
	else
		i2c_clk  <=  i2c_clk  ;
		
//状态机第一段
always@(posedge i2c_clk or negedge sys_rst_n)
	if(sys_rst_n == 1'b0)
		c_state  <=  IDLE  ;
	else
		c_state  <=  n_state  ;
		
//状态机第二段
always@(*)
	case(c_state)
		IDLE		:	if((skip_en_0 == 1'b1)||(skip_en_1 == 1'b1)||(skip_en_2 == 1'b1)||(skip_en_3 == 1'b1)||(skip_en_4 == 1'b1)||(skip_en_5 == 1'b1)||(skip_en_6 == 1'b1))
							n_state  =  START  ;
						else
							n_state  =  IDLE  ;
		START		:	if((skip_en_0 == 1'b1)||(skip_en_1 == 1'b1)||(skip_en_2 == 1'b1)||(skip_en_3 == 1'b1)||(skip_en_4 == 1'b1)||(skip_en_5 == 1'b1)||(skip_en_6 == 1'b1))
							n_state  =  SLAVE_ADDR  ;
						else
							n_state  =  START  ;
		SLAVE_ADDR	:	if(skip_en_0 == 1'b1)
							n_state  =  WAIT  ;
						else  if((skip_en_1 == 1'b1)||(skip_en_2 == 1'b1)||(skip_en_3 == 1'b1)||(skip_en_4 == 1'b1)||(skip_en_5 == 1'b1)||(skip_en_6 == 1'b1))
							n_state  =  ACK_1  ;
						else
							n_state  =  SLAVE_ADDR  ;
		ACK_1		:	if((skip_en_1 == 1'b1)||(skip_en_2 == 1'b1)||(skip_en_4 == 1'b1)||(skip_en_5 == 1'b1))
							n_state  =  DEVICE_ADDR  ;
						else  if((skip_en_3 == 1'b1)||(skip_en_6 == 1'b1))
							n_state  =  DATA  ;
						else
							n_state  =  ACK_1  ;
		DEVICE_ADDR	:	if((skip_en_1 == 1'b1)||(skip_en_2 == 1'b1)||(skip_en_4 == 1'b1)||(skip_en_5 == 1'b1))
							n_state  =  ACK_2  ;
						else
							n_state  =  DEVICE_ADDR  ;
		ACK_2		:	if((skip_en_1 == 1'b1)||(skip_en_4 == 1'b1))
							n_state  =  DATA  ;
						else  if((skip_en_2 == 1'b1)||(skip_en_5 == 1'b1))
							n_state  =  STOP  ;
						else
							n_state  =  ACK_2  ;
		DATA		:	if((skip_en_1 == 1'b1)||(skip_en_4 == 1'b1))
							n_state  =  ACK_3  ;
						else  if((skip_en_3 == 1'b1)||(skip_en_6 == 1'b1))
							n_state  =  NACK  ;
						else  if(error_en == 1'b1)
							n_state  =  IDLE  ;
						else
							n_state  =  DATA  ;
		ACK_3		:	if((skip_en_1 == 1'b1)||(skip_en_4 == 1'b1))
							n_state  =  STOP  ;
						else
							n_state  =  ACK_3  ;
		WAIT		:	if(skip_en_0 == 1'b1)
							n_state  =  STOP  ;
						else
							n_state  =  WAIT  ;
		NACK		:	if((skip_en_3 == 1'b1)||(skip_en_6 == 1'b1))
							n_state  =  STOP  ;
						else
							n_state  =  NACK  ;
		STOP		:	if((skip_en_0 == 1'b1)||(skip_en_1 == 1'b1)||(skip_en_2 == 1'b1)||(skip_en_3 == 1'b1)||(skip_en_4 == 1'b1)||(skip_en_5 == 1'b1)||(skip_en_6 == 1'b1))
							n_state  =  IDLE  ;
						else
							n_state  =  STOP  ;
		default		:	n_state  =  IDLE  ;
	endcase
	
//状态机第三段
always@(posedge i2c_clk or negedge sys_rst_n)
	if(sys_rst_n == 1'b0)
		begin
			cnt_wait	<=  10'd0  ;
			skip_en_0	<=  1'b0   ;
			skip_en_1   <=  1'b0   ;
			skip_en_2	<=  1'b0   ;
			skip_en_3   <=  1'b0   ;
			skip_en_4	<=  1'b0   ;
			skip_en_5	<=  1'b0   ;
			skip_en_6	<=  1'b0   ;
			error_en	<=  1'b0   ;
			cnt_i2c_clk	<=  2'd0   ;
			cnt_bit		<=  3'd0   ;
			i2c_end		<=  1'b0   ;
			step		<=  3'd0   ;
		end
	else
		case(c_state)
			IDLE		:begin
							if(cnt_wait == CNT_WAIT_MAX - 1'b1)
								cnt_wait  <=  10'd0  ;
							else
								cnt_wait  <=  cnt_wait + 1'b1  ;
							if((cnt_wait == CNT_WAIT_MAX - 2'd2)&&(step == 3'd0))
								skip_en_0  <=  1'b1  ;
							else
								skip_en_0  <=  1'b0  ;
							if((cnt_wait == CNT_WAIT_MAX - 2'd2)&&(step == 3'd1))
								skip_en_1  <=  1'b1  ;
							else
								skip_en_1  <=  1'b0  ;	
							if((cnt_wait == CNT_WAIT_MAX - 2'd2)&&(step == 3'd2))
								skip_en_2  <=  1'b1  ;
							else
								skip_en_2  <=  1'b0  ;
							if((cnt_wait == CNT_WAIT_MAX - 2'd2)&&(step == 3'd3))
								skip_en_3  <=  1'b1  ;
							else
								skip_en_3  <=  1'b0  ;
							if((i2c_start == 1'b1)&&(step == 3'd4))
								skip_en_4  <=  1'b1  ;
							else
								skip_en_4  <=  1'b0  ;
							if((cnt_wait == CNT_WAIT_MAX - 2'd2)&&(step == 3'd5))
								skip_en_5  <=  1'b1  ;
							else
								skip_en_5  <=  1'b0  ;	
							if((cnt_wait == CNT_WAIT_MAX - 2'd2)&&(step == 3'd6))
								skip_en_6  <=  1'b1  ;
							else
								skip_en_6  <=  1'b0  ;								
						 end
			START		:begin
							cnt_i2c_clk  <=  cnt_i2c_clk + 1'b1  ;
							if((cnt_i2c_clk == 2'd2)&&(step == 3'd0))
								skip_en_0  <=  1'b1  ;
							else
								skip_en_0  <=  1'b0  ;
							if((cnt_i2c_clk == 2'd2)&&(step == 3'd1))
								skip_en_1  <=  1'b1  ;
							else
								skip_en_1  <=  1'b0  ;	
							if((cnt_i2c_clk == 2'd2)&&(step == 3'd2))
								skip_en_2  <=  1'b1  ;
							else
								skip_en_2  <=  1'b0  ;	
							if((cnt_i2c_clk == 2'd2)&&(step == 3'd3))
								skip_en_3  <=  1'b1  ;
							else
								skip_en_3  <=  1'b0  ;	
							if((cnt_i2c_clk == 2'd2)&&(step == 3'd4))
								skip_en_4  <=  1'b1  ;
							else
								skip_en_4  <=  1'b0  ;
							if((cnt_i2c_clk == 2'd2)&&(step == 3'd5))
								skip_en_5  <=  1'b1  ;
							else
								skip_en_5  <=  1'b0  ;	
							if((cnt_i2c_clk == 2'd2)&&(step == 3'd6))
								skip_en_6  <=  1'b1  ;
							else
								skip_en_6  <=  1'b0  ;									
						 end
			SLAVE_ADDR	:begin	//1 byte = 8 bit
							cnt_i2c_clk  <=  cnt_i2c_clk + 1'b1  ;
							if(cnt_i2c_clk == 2'd3)
								cnt_bit  <=  cnt_bit + 1'b1  ;
							else
								cnt_bit  <=  cnt_bit  ;
							if((cnt_i2c_clk == 2'd2)&&(cnt_bit == 3'd7)&&(step == 3'd0))
								skip_en_0  <=  1'b1  ;
							else
								skip_en_0  <=  1'b0  ;
							if((cnt_i2c_clk == 2'd2)&&(cnt_bit == 3'd7)&&(step == 3'd1))
								skip_en_1  <=  1'b1  ;
							else
								skip_en_1  <=  1'b0  ;	
							if((cnt_i2c_clk == 2'd2)&&(cnt_bit == 3'd7)&&(step == 3'd2))
								skip_en_2  <=  1'b1  ;
							else
								skip_en_2  <=  1'b0  ;
							if((cnt_i2c_clk == 2'd2)&&(cnt_bit == 3'd7)&&(step == 3'd3))
								skip_en_3  <=  1'b1  ;
							else
								skip_en_3  <=  1'b0  ;
							if((cnt_i2c_clk == 2'd2)&&(cnt_bit == 3'd7)&&(step == 3'd4))
								skip_en_4  <=  1'b1  ;
							else
								skip_en_4  <=  1'b0  ;		
							if((cnt_i2c_clk == 2'd2)&&(cnt_bit == 3'd7)&&(step == 3'd5))
								skip_en_5  <=  1'b1  ;
							else
								skip_en_5  <=  1'b0  ;	
							if((cnt_i2c_clk == 2'd2)&&(cnt_bit == 3'd7)&&(step == 3'd6))
								skip_en_6  <=  1'b1  ;
							else
								skip_en_6  <=  1'b0  ;								
						 end
			ACK_1		:begin
							cnt_i2c_clk  <=  cnt_i2c_clk + 1'b1  ;
							if((cnt_i2c_clk == 2'd2)&&(step == 3'd1)&&(ack_en == 1'b1))
								skip_en_1  <=  1'b1  ;
							else
								skip_en_1  <=  1'b0  ;
							if((cnt_i2c_clk == 2'd2)&&(step == 3'd2)&&(ack_en == 1'b1))
								skip_en_2  <=  1'b1  ;
							else
								skip_en_2  <=  1'b0  ;	
							if((cnt_i2c_clk == 2'd2)&&(step == 3'd3)&&(ack_en == 1'b1))
								skip_en_3  <=  1'b1  ;
							else
								skip_en_3  <=  1'b0  ;	
							if((cnt_i2c_clk == 2'd2)&&(step == 3'd4)&&(ack_en == 1'b1))
								skip_en_4  <=  1'b1  ;
							else
								skip_en_4  <=  1'b0  ;	
							if((cnt_i2c_clk == 2'd2)&&(step == 3'd5)&&(ack_en == 1'b1))
								skip_en_5  <=  1'b1  ;
							else
								skip_en_5  <=  1'b0  ;	
							if((cnt_i2c_clk == 2'd2)&&(step == 3'd6)&&(ack_en == 1'b1))
								skip_en_6  <=  1'b1  ;
							else
								skip_en_6  <=  1'b0  ;								
						 end
			DEVICE_ADDR	:begin
							cnt_i2c_clk  <=  cnt_i2c_clk + 1'b1  ;
							if(cnt_i2c_clk == 2'd3)
								cnt_bit  <=  cnt_bit + 1'b1  ;
							else
								cnt_bit  <=  cnt_bit  ;			
							if((cnt_i2c_clk == 2'd2)&&(cnt_bit == 3'd7)&&(step == 3'd1))
								skip_en_1  <=  1'b1  ;
							else
								skip_en_1  <=  1'b0  ;	
							if((cnt_i2c_clk == 2'd2)&&(cnt_bit == 3'd7)&&(step == 3'd2))
								skip_en_2  <=  1'b1  ;
							else
								skip_en_2  <=  1'b0  ;	
							if((cnt_i2c_clk == 2'd2)&&(cnt_bit == 3'd7)&&(step == 3'd4))
								skip_en_4  <=  1'b1  ;
							else
								skip_en_4  <=  1'b0  ;	
							if((cnt_i2c_clk == 2'd2)&&(cnt_bit == 3'd7)&&(step == 3'd5))
								skip_en_5  <=  1'b1  ;
							else
								skip_en_5  <=  1'b0  ;									
						 end
			ACK_2		:begin
							cnt_i2c_clk  <=  cnt_i2c_clk + 1'b1  ;
							if((cnt_i2c_clk == 2'd2)&&(step == 3'd1)&&(ack_en == 1'b1))
								skip_en_1  <=  1'b1  ;
							else
								skip_en_1  <=  1'b0  ;	
							if((cnt_i2c_clk == 2'd2)&&(step == 3'd2)&&(ack_en == 1'b1))
								skip_en_2  <=  1'b1  ;
							else
								skip_en_2  <=  1'b0  ;	
							if((cnt_i2c_clk == 2'd2)&&(step == 3'd4)&&(ack_en == 1'b1))
								skip_en_4  <=  1'b1  ;
							else
								skip_en_4  <=  1'b0  ;	
							if((cnt_i2c_clk == 2'd2)&&(step == 3'd5)&&(ack_en == 1'b1))
								skip_en_5  <=  1'b1  ;
							else
								skip_en_5  <=  1'b0  ;									
						 end
			DATA		:begin
							cnt_i2c_clk  <=  cnt_i2c_clk + 1'b1  ;
							if(cnt_i2c_clk == 2'd3)
								cnt_bit  <=  cnt_bit + 1'b1  ;
							else
								cnt_bit  <=  cnt_bit  ;			
							if((cnt_i2c_clk == 2'd2)&&(cnt_bit == 3'd7)&&(step == 3'd1))
								skip_en_1  <=  1'b1  ;
							else
								skip_en_1  <=  1'b0  ;	
							if((cnt_i2c_clk == 2'd2)&&(cnt_bit == 3'd7)&&(rec_data == 8'h20)&&(step == 3'd3))
								skip_en_3  <=  1'b1  ;
							else
								skip_en_3 <=  1'b0  ;
							if((cnt_i2c_clk == 2'd2)&&(cnt_bit == 3'd7)&&(step == 3'd4))
								skip_en_4  <=  1'b1  ;
							else
								skip_en_4  <=  1'b0  ;
							if((cnt_i2c_clk == 2'd2)&&(cnt_bit == 3'd7)&&(step == 3'd6))
								skip_en_6  <=  1'b1  ;
							else
								skip_en_6 <=  1'b0  ;								
							if((cnt_i2c_clk == 2'd2)&&(cnt_bit == 3'd7)&&(rec_data != 8'h20)&&(step == 3'd3))
								begin
									error_en  <=  1'b1  ;
									step	  <=  3'd0  ;
								end
							else
								begin
									error_en  <=  1'b0  ;
									step      <=  step  ;
								end
						 end	
			ACK_3		:begin
							cnt_i2c_clk  <=  cnt_i2c_clk + 1'b1  ;
							if((cnt_i2c_clk == 2'd2)&&(step == 3'd1)&&(ack_en == 1'b1))
								skip_en_1  <=  1'b1  ;
							else
								skip_en_1  <=  1'b0  ;
							if((cnt_i2c_clk == 2'd2)&&(step == 3'd4)&&(ack_en == 1'b1))
								skip_en_4  <=  1'b1  ;
							else
								skip_en_4  <=  1'b0  ;								
						 end						 
			WAIT		:begin
							if(cnt_wait == CNT_WAIT_MAX - 1'b1)
								cnt_wait  <=  10'd0  ;
							else
								cnt_wait  <=  cnt_wait + 1'b1  ;
							if((cnt_wait == CNT_WAIT_MAX - 2'd2)&&(step == 3'd0))
								skip_en_0  <=  1'b1  ;
							else
								skip_en_0  <=  1'b0  ;
						 end
			NACK		:begin
							cnt_i2c_clk  <=  cnt_i2c_clk + 1'b1  ;
							if((cnt_i2c_clk == 2'd2)&&(step == 3'd3)&&(ack_en == 1'b1))
								skip_en_3  <=  1'b1  ;
							else
								skip_en_3  <=  1'b0  ;
							if((cnt_i2c_clk == 2'd2)&&(step == 3'd6)&&(ack_en == 1'b1))
								skip_en_6  <=  1'b1  ;
							else
								skip_en_6  <=  1'b0  ;								
						 end						 
			STOP		:begin
							cnt_i2c_clk  <=  cnt_i2c_clk + 1'b1  ;
							if(cnt_i2c_clk == 2'd2)
								i2c_end  <=  1'b1  ;
							else
								i2c_end  <=  1'b0  ;
							if((cnt_i2c_clk == 2'd2)&&(step == 3'd0))
								skip_en_0  <=  1'b1  ;
							else
								skip_en_0  <=  1'b0  ;	
							if((cnt_i2c_clk == 2'd2)&&(step == 3'd1))
								skip_en_1  <=  1'b1  ;
							else
								skip_en_1  <=  1'b0  ;	
							if((cnt_i2c_clk == 2'd2)&&(step == 3'd2))
								skip_en_2  <=  1'b1  ;
							else
								skip_en_2  <=  1'b0  ;
							if((cnt_i2c_clk == 2'd2)&&(step == 3'd3))
								skip_en_3  <=  1'b1  ;
							else
								skip_en_3  <=  1'b0  ;
							if((cnt_i2c_clk == 2'd2)&&(step == 3'd4))
								skip_en_4  <=  1'b1  ;
							else
								skip_en_4  <=  1'b0  ;	
							if((cnt_i2c_clk == 2'd2)&&(step == 3'd5))
								skip_en_5  <=  1'b1  ;
							else
								skip_en_5  <=  1'b0  ;
							if((cnt_i2c_clk == 2'd2)&&(step == 3'd6))
								skip_en_6  <=  1'b1  ;
							else
								skip_en_6  <=  1'b0  ;								
							if((i2c_end == 1'b1)&&(step == 3'd4)&&(cfg_num == 6'd51))
								step  <=  step + 1'b1  ;
							else  if((i2c_end == 1'b1)&&(step <= 3'd3))
								step  <=  step + 1'b1  ;
							else  if((i2c_end == 1'b1)&&(step == 3'd5))
								step  <=  step + 1'b1  ;
							else
								step  <=  step  ;
						 end
			default		:begin
							cnt_wait	<=  10'd0  ;
							skip_en_0	<=  1'b0   ;
							skip_en_1	<=  1'b0   ;
							skip_en_2	<=  1'b0   ;
							skip_en_3   <=  1'b0   ;
							skip_en_4	<=  1'b0   ;
							skip_en_5   <=  1'b0   ;
							skip_en_6   <=  1'b0   ;
							error_en	<=  1'b0   ;
							cnt_i2c_clk	<=  2'd0   ;
							cnt_bit		<=  3'd0   ;
							i2c_end		<=  1'b0   ;
							step		<=  3'd0   ;
						 end
		endcase
		
always@(posedge i2c_clk or negedge sys_rst_n)
	if(sys_rst_n == 1'b0)
		cfg_start  <=  1'b0  ;
	else
		cfg_start  <=  i2c_end  ;

//拼接操作必须要使用时序逻辑	
always@(posedge i2c_clk or negedge sys_rst_n)
	if(sys_rst_n == 1'b0)
		rec_data  <=  8'h0  ;
	else
		case(c_state)
			DATA	:	if((step == 3'd3)&&(cnt_i2c_clk == 2'd1))
							rec_data  <=  {rec_data[6:0],sda_in}  ;
						else
							rec_data  <=  rec_data  ;
			default	:	rec_data  <=  8'h0  ;
		endcase
		
always@(posedge i2c_clk or negedge sys_rst_n)
	if(sys_rst_n == 1'b0)
		po_data_reg  <=  8'h0  ;
	else
		case(c_state)
			DATA	:	if((step == 3'd6)&&(cnt_i2c_clk == 2'd1))
							po_data_reg  <=  {po_data_reg[6:0],sda_in}  ;
						else
							po_data_reg  <=  po_data_reg  ;
			default	:	po_data_reg  <=  po_data_reg  ;
		endcase
			
always@(posedge i2c_clk or negedge sys_rst_n)
	if(sys_rst_n == 1'b0)	
		po_data  <=  8'h0  ;
	else 
		case(c_state)
			DATA	:	if((step == 3'd6)&&(cnt_i2c_clk == 2'd3)&&(cnt_bit == 3'd7)&&(po_data_reg != 8'h0))
							po_data  <=  po_data_reg  ;
						else
							po_data  <=  po_data  ;
			default	:	po_data  <=  po_data  ;
		endcase
	
always@(*)
	case(c_state)
		ACK_1,ACK_2,ACK_3
					:	ack_en  =  ~sda_in  ;
		NACK		:	ack_en  =  i2c_sda  ;
		default		:	ack_en  =  1'b0  ;
	endcase
		
always@(*)
	case(c_state)
		IDLE		:	i2c_scl  =  1'b1  ;
		START		:	if(cnt_i2c_clk == 2'd3)
							i2c_scl  =  1'b0  ;
						else
							i2c_scl  =  1'b1  ;
		SLAVE_ADDR,ACK_1,DEVICE_ADDR,ACK_2,DATA,ACK_3,NACK
					:	if((cnt_i2c_clk == 2'd0)||(cnt_i2c_clk == 2'd3))
							i2c_scl  =  1'b0  ;
						else
							i2c_scl  =  1'b1  ;
		WAIT		:	i2c_scl  =  1'b0  ;
		STOP		:	if(cnt_i2c_clk == 2'd0)
							i2c_scl  =  1'b0  ;
						else
							i2c_scl  =  1'b1  ;
		default		:	i2c_scl  =  1'b1  ;
	endcase
	
always@(*)
	case(c_state)
		IDLE		:	i2c_sda  =  1'b1  ;
		START		:	if(cnt_i2c_clk == 2'd0)
							i2c_sda  =  1'b1  ;
						else
							i2c_sda  =  1'b0  ;
		SLAVE_ADDR	:	i2c_sda  =  slave_addr[7 - cnt_bit]  ;
		DEVICE_ADDR	:	i2c_sda  =  device_addr[7 - cnt_bit]  ;
		DATA		:	i2c_sda  =  wr_data[7 - cnt_bit]  ;
		ACK_1,ACK_2,ACK_3,NACK
					:	i2c_sda  =  1'b1  ;
		WAIT		:	i2c_sda  =  1'b0  ;
		STOP		:	if((cnt_i2c_clk == 2'd0)||(cnt_i2c_clk == 2'd1))
							i2c_sda  =  1'b0  ;
						else
							i2c_sda  =  1'b1  ;
		default		:	i2c_sda  =  1'b1  ;
	endcase

endmodule