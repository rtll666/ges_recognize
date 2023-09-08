module  beep
(
	input	wire			sys_clk		,
	input	wire			sys_rst_n	,

    input	  		[3:0]	cnt_num		,
	input	 		[3:0]	cnt_unit	,

	output	reg				beep	
);

localparam	CNT_1S_MAX  =  26'd50_000_000  ;
localparam	CNT_DO_MAX	=  17'd95420  ,
			CNT_RE_MAX	=  17'd85034  ,
			CNT_MI_MAX	=  17'd75757  ,			
			CNT_FA_MAX	=  17'd71633  ,
			CNT_SO_MAX	=  17'd63775  ,					
			CNT_LA_MAX	=  17'd56818  ,
			CNT_XI_MAX	=  17'd50607  ;			
			

reg		[25:0]	cnt_1s	;
reg		[2:0]	num	    ;//第几个音节
reg		[16:0]	cnt_fre	;

always@(posedge sys_clk or negedge sys_rst_n)
	if(sys_rst_n == 1'b0)	
	begin
		num <= 3'd0   ;
	end
	else  if((cnt_num == 34'ha)&&(cnt_unit== 4'ha))
	begin
		num <= 3'd1   ;
	end
	else
		num <= 3'd0	  ;

always@(posedge sys_clk or negedge sys_rst_n)
	if(sys_rst_n == 1'b0)
    begin
        cnt_fre  <=  17'd0  ;
        beep  <=  1'b0  ;
    end
	else  if((num == 3'd0)&&(cnt_fre >= CNT_DO_MAX - 1'b1))
	begin
    	cnt_fre  <=  17'd0  ;
        beep  <=  1'b0  ;
    end
	else  if((num == 3'd1)&&(cnt_fre >= CNT_RE_MAX - 1'b1))
	begin
    	cnt_fre  <=  17'd0  ;
        beep  <=  ~beep  ;
    end
	else  if((num == 3'd2)&&(cnt_fre >= CNT_MI_MAX - 1'b1))
	begin
    	cnt_fre  <=  17'd0  ;
        beep  <=  ~beep  ;
    end
	else
    begin
       	cnt_fre  <=  cnt_fre + 1'b1  ;
        beep  <=  beep  ; 
    end
	

endmodule