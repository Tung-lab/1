/////////////////////////////////////////////////////////////////////////////
//Altera ATPP�������� ��о�Ƽ� Я�� ��Ȩͬѧ ��ͬ���� FPGA������ϵ��
//����Ӳ��ƽ̨�� Altera Cyclone IV FPGA 
//程序功能     定义ddr2起始地址  和终止地址  让ddr2循环读取数据，然后给FIFO输出
//突发长度为8                      一次突发1次     读取64bit*16个   共64个字节，然后等待下一次的读信号
//			
//原来突发长度为16   现在改成了32



//2022-5-28     改 ddr local_raad_req   和  local_ready没同步问题， 还有就是初始化长度问题，

///////////////////////===============硬件接口部分======黑鹰开发板============================////////不管
module cy4( ///////////////stm32  与  fpga 的接口
   input  wire		[15: 0]     STM32_DATA,
	input  wire		[3: 0]      STM32_address ,
	input  wire                STM32_CS,
	input  wire                STM32_CS1,         //B18
	
	input  wire                STM32_WR,     //y22
	output reg     [63:0]      fifo_output_pin,     //主输出S信号
	output wire    [63:0]      fifo_output_pin_not, //三态控制输出T信号
	output reg                 write_ddr_ok_flag,    //写数据到ddr完成标志位   
	
	
 //  output wire    [63:0]      fifo_ddr2,
/////////////////////////////////////
	
	
	input   local_clk_50m,
	input   reset_n,
	output  err,
	output  clk_100m ,
	output  clk_200m ,
	output  wire  ddr2_cs_n,        //片选信号  
	output  wire  ddr2_cke,          //时钟使能信号
	output  wire[12: 0]  ddr2_addr,     //地址
	output  wire[2 : 0]  ddr2_ba,       //块位置
	output  wire  ddr2_ras_n,           //行选同
	output  wire  ddr2_cas_n,          // 列选通
	output  wire  ddr2_we_n, 				//写选通
	inout   wire  ddr2_clk,               //CLK  差分时钟正
	inout   wire  ddr2_clk_n,					//CLK  差分时钟负
	output  wire[3 : 0]  ddr2_dm,        //数据写入屏蔽  拉高表示当前数据无效
	inout   wire[31: 0]  ddr2_dq,         //数据总线
	inout   wire[3 : 0]  ddr2_dqs,        //数据锁存时钟
	output	ddr2_odt                     //片内阻抗设置
	) ;
	

/////////////////////=======================================================================
//接口测试stm32  
(*preserve*) reg   [15:0]  fpga_cs    /*synthesis noprune*/;   //扩展的片选
(*preserve*) reg   [15:0]  fpga_data0 /*synthesis noprune*/;   //锁存数据0
(*preserve*) reg   [15:0]  fpga_data1 /*synthesis noprune*/;   //锁存数据0
(*preserve*) reg   [15:0]  fpga_data2 /*synthesis noprune*/;   //锁存数据0
(*preserve*) reg   [15:0]  fpga_data3 /*synthesis noprune*/;   //锁存数据0
(*preserve*) reg   [15:0]  fpga_data4 /*synthesis noprune*/;   //锁存数据0

(*preserve*) reg   [15:0]  fpga_data5 /*synthesis noprune*/;   //锁存数据0
(*preserve*) reg   [15:0]  fpga_data6 /*synthesis noprune*/;   //锁存数据0

(*preserve*) reg   [15:0]  fpga_data7 /*synthesis noprune*/;   //锁存数据0
(*preserve*) reg   [15:0]  fpga_data8 /*synthesis noprune*/;   //锁存数据0

(*preserve*) reg   [15:0]  fpga_data9 /*synthesis noprune*/;   //锁存数据0

(*preserve*) reg   [15:0]  fpga_data10 /*synthesis noprune*/;   //锁存数据0
(*preserve*) reg   [15:0]  fpga_data11 /*synthesis noprune*/;   //锁存数据0

(*preserve*) reg   [15:0]  fpga_data12 /*synthesis noprune*/;   //锁存数据0

(*preserve*) reg   [15:0]  fpga_data13 /*synthesis noprune*/;   //锁存数据0
(*preserve*) reg   [15:0]  fpga_data14 /*synthesis noprune*/;   //锁存数据0

(*preserve*) reg   [15:0]  fpga_data15 /*synthesis noprune*/;   //锁存数据0

(*preserve*) reg   [15:0]  fpga_data16 /*synthesis noprune*/;   //锁存数据0
(*preserve*) reg   [15:0]  fpga_data17 /*synthesis noprune*/;   //锁存数据0
(*preserve*) reg   [15:0]  fpga_data18 /*synthesis noprune*/;   //锁存数据0
(*preserve*) reg   [15:0]  fpga_data19 /*synthesis noprune*/;   //锁存数据0

(*preserve*) reg   [31:0]  fpga_data_deep32 /*synthesis noprune*/;   //锁存数据0
(*preserve*) reg   [31:0]  fpga_data_deep64 /*synthesis noprune*/;   //锁存数据0


(*preserve*) reg   [31:0]  fpga_data_deep32_inti /*synthesis noprune*/;   //锁存数据0
(*preserve*) reg   [31:0]  fpga_data_deep64_inti /*synthesis noprune*/;   //锁存数据0


reg    [31:0]         write_local_address;    //写入地址设置




reg    [63:0]      FPGA_santai_control;
reg    [63:0]      FPGA_santai_control_n;

//(*preserve*) reg   [31:0]  fpga_data_deep32_inti /*synthesis noprune*/;   //锁存数据0
//(*preserve*) reg   [31:0]  fpga_data_deep64_inti /*synthesis noprune*/;   //锁存数据0

always @(posedge local_clk_25m or negedge reset_n)
if(!reset_n)begin
	   fpga_data_deep32 <= 32'd1;
	   fpga_data_deep64 <= 32'd1;
		 //
		local_address_fine_0 <= 32'd0;
		local_address_fine_1 <= 32'd0;
		//
		local_address_fine_2 <= 32'd0;
	   local_address_fine_3 <= 32'd0;
		
		write_local_address <=  0  ;
end else begin 
	fpga_data_deep32 <= {fpga_data11[15:0],fpga_data10[15:0]}  ;   //  循环深度+初始段
	fpga_data_deep64 <= {fpga_data11[15:0],fpga_data10[15:0]}  ;   //  前后32路都一样
	
	
	local_address_fine_0 <= {fpga_data11[15:0],fpga_data10[15:0]} / 4;              //自动配置   
	local_address_fine_1 <= {fpga_data11[15:0],fpga_data10[15:0]} / 4 +25'h400000 ;
	local_address_fine_2 <= {fpga_data11[15:0],fpga_data10[15:0]} / 4 +25'h800000;
	local_address_fine_3 <= {fpga_data11[15:0],fpga_data10[15:0]} / 4 +25'h1000000;

	
	fpga_data_deep32_inti  <=   {fpga_data13[15:0],fpga_data12[15:0]};  //初始化深度   64路深度都是一样的
	fpga_data_deep64_inti  <=   {fpga_data13[15:0],fpga_data12[15:0]};  //初始化深度

	local_address_base_0   <=  fpga_data_deep32_inti / 4  ;
	local_address_base_1   <=  fpga_data_deep32_inti / 4   +25'h400000 ;
	local_address_base_2   <=  fpga_data_deep64_inti / 4   +25'h800000;
	local_address_base_3   <=  fpga_data_deep64_inti / 4   +25'h1000000  ;
	
	fifo0_31_deep_base   <=  fpga_data_deep32_inti  %  4;
	fifo32_63_deep_base  <=  fpga_data_deep64_inti  %  4;
	
	write_local_address  <=  {fpga_data8[15:0],fpga_data7[15:0]};    //写入的起始地址
	
	FPGA_santai_control_n  <={fpga_data19[15:0],fpga_data18[15:0],fpga_data17[15:0],fpga_data16[15:0]};
	FPGA_santai_control  <= FPGA_santai_control_n;
	
   if( FIFO_flag_rd == 4)       
	write_ddr_ok_flag  <= 1;
	 else
   write_ddr_ok_flag  <= 0;
end
	
	
	

 


//我需要：写入数据的长度一定是16的倍数应为突发长度定为了16（一个16位），两个主频（4个16位），四个地址（主要把ddr分为了4组，每组存16路的信号）（8个16位），
//    初始化深度（2个16位），循环深度（2个16位），开始信号(一个16位)

always @(posedge clk_200m or negedge reset_n)
if(~reset_n)begin
	fpga_data0 <= 0;              // 
	fpga_data1 <= 0;              //KAISH 
	fpga_data2 <= 0;             //用于控制写缓冲的FIFO的读写，由于他是  inputFIFO是锁存两个时钟输出数据
	fpga_data3 <= 0;             //用来写入数据
	fpga_data4 <= 0;             //用于写入input缓冲区的复位  
	fpga_data5 <= 0;            // 
	fpga_data6 <= 0;            //写数据时用来 所一次地址数据；
	fpga_data7 <= 0;				 //写入local_address地址低16位
	fpga_data8 <= 0;            //写入local_address地址高16位
	fpga_data9 <= 0;            //启动一次写信号请求
	fpga_data10 <= 0;           //低16地址位  初始化+循环深度
	fpga_data11 <= 0;           //高16地址位  初始化+循环深度
	fpga_data12 <= 0;           //低16地址位  初始化深度
	fpga_data13 <= 0;           //高16地址位  初始化深度
	fpga_data14 <= 4;           //主频1
	fpga_data15 <= 4;           //主频2
	///////////////////////////////三态信号
	fpga_data16 <= 0;           //1-16路三态控制信号   当三态是  T=1  ,S=0;
	fpga_data17 <= 0;           //17-32
	fpga_data18 <= 0;           //33-48
	fpga_data19 <= 0;           //49-64
	
end 
	else if(w_en0)
			fpga_data0 <=  STM32_DATA;
	else if(w_en1)
		   fpga_data1 <=  STM32_DATA;     //暂时用作   读开关状态
	else if(w_en2)
			fpga_data2 <=  STM32_DATA;
	else if(w_en3)
			fpga_data3 <=  STM32_DATA;//
	else if(w_en4)
	      fpga_data4 <=  STM32_DATA;  //  复位FIFO
	else if(w_en5)
			fpga_data5 <=  STM32_DATA;  //
	else if(w_en6)
		   fpga_data6 <=  STM32_DATA;//
	else if(w_en7)
		   fpga_data7 <=  STM32_DATA;//
	else if(w_en8)
		   fpga_data8 <=  STM32_DATA;//
	else if(w_en9)
			fpga_data9 <=  STM32_DATA;//  
	else if(w_en10)
			fpga_data10 <=  STM32_DATA;//
	else if(w_en11)
			fpga_data11 <=  STM32_DATA;//
	else if(w_en12)
			fpga_data12 <=  STM32_DATA;//
	else if(w_en13)
			fpga_data13 <=  STM32_DATA;//
	else if(w_en14)
			fpga_data14 <=  STM32_DATA;//
	else if(w_en15)
			fpga_data15 <=  STM32_DATA;//
	else if(w_en16)
			fpga_data16 <=  STM32_DATA;//
	else if(w_en17)
			fpga_data17 <=  STM32_DATA;//
	else if(w_en18)
			fpga_data18 <=  STM32_DATA;//
	else if(w_en19)
			fpga_data19 <=  STM32_DATA;//






///////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////
////////////////////////////////片选扩展

(*preserve*) wire w_en0  /*synthesis keep*/;
(*preserve*) wire w_en1  /*synthesis keep*/;
(*preserve*) wire w_en2  /*synthesis keep*/;
(*preserve*) wire w_en3  /*synthesis keep*/;
(*preserve*) wire w_en4  /*synthesis keep*/;
(*preserve*) wire w_en5  /*synthesis keep*/;
(*preserve*) wire w_en6  /*synthesis keep*/;
(*preserve*) wire w_en7  /*synthesis keep*/;
(*preserve*) wire w_en8  /*synthesis keep*/;
(*preserve*) wire w_en9  /*synthesis keep*/;
(*preserve*) wire w_en10  /*synthesis keep*/;
(*preserve*) wire w_en11  /*synthesis keep*/;
(*preserve*) wire w_en12  /*synthesis keep*/;
(*preserve*) wire w_en13  /*synthesis keep*/;
(*preserve*) wire w_en14  /*synthesis keep*/;
(*preserve*) wire w_en15  /*synthesis keep*/;


 dec   dec1(
	.data			(STM32_address),
	.enable		(~STM32_CS),					
	.eq00			(w_en0),                          
	.eq01			(w_en1),
	.eq02			(w_en2),
	.eq03			(w_en3),      
	.eq04 		(w_en4),
	.eq05  		(w_en5),
	.eq06  		(w_en6),
	.eq07  		(w_en7),
	.eq08  		(w_en8),
	.eq09  		(w_en9),     //写使能
	.eq0a  		(w_en10), 
	.eq0b  		(w_en11), 
	.eq0c  		(w_en12), 
	.eq0d  		(w_en13), 
	.eq0e  		(w_en14), 
	.eq0f  		(w_en15)
	);	
 dec   dec2(
	.data			(STM32_address),
	.enable		(~STM32_CS1),					
	.eq00			(w_en16),                          
	.eq01			(w_en17),
	.eq02			(w_en18),
	.eq03			(w_en19),      
	.eq04 		(),
	.eq05  		(),
	.eq06  		(),
	.eq07  		(),
	.eq08  		(),
	.eq09  		(),     //写使能
	.eq0a  		(), 
	.eq0b  		(), 
	.eq0c  		(), 
	.eq0d  		(), 
	.eq0e  		(), 
	.eq0f  		()
	);	



///////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////

//开辟一个1k空间的ram或者FIFO ，然后把这1k内容存入ddr2  返回一个完成标志位，继续下一个1k


///////////////////////////////////////////////////////////////////
//(*preserve*) wire     [63:0]   fifo_ddr2   /*synthesis keep*/;
FIFO_INPUT   FIFO_INPUT_16   
(
	.aclr    ((!reset_n)|(fpga_data4[0])),
	.data    (fpga_data3),            //  写入数据     16位   input
	.rdclk   ((phy_clk & local_write_req )|fpga_data2[0] ),          //这个需要和ddr 的时钟同步
	.rdreq   (1 & local_ready),                 //控制信号  控制FIFO写入到ddr  和ddr写请求同步
	.wrclk   (~w_en3),
	.wrreq   (1),
	.q			(fifo_ddr2)                //输出数据        output    64位
);
//
//always @(negedge phy_clk or negedge reset_n)
//	if(!reset_n) begin 
//   local_write_req_n<=0;
//	fifo_ddr2<=0;
//end else begin 
//	local_write_req_n<=local_write_req;
//	fifo_ddr2 <= fifo_ddr2_n;
//end 
///////////////////////////////////////////////////////////////////////////////////


//assign    fifo_output_pin_not  =  ~fifo_output_pin;
assign    fifo_output_pin_not = FPGA_santai_control;
wire         [63:0]      fifo_ddr2;
//wire       [63:0]      fifo_ddr2_n;
reg       local_write_req_n;





////////////////////========================================================================
//////==================以“mem_”为前缀的信号是和 DDR2 颗粒的物理连接的信号；以“local_”为前缀的
////////=====================信号为用户接口信号。关键信号说明如下

reg 	[24:0]	  local_address		 /*synthesis keep*/;          // 读地址   25位  32Mb*64      =  2Gb
wire 		        local_write_req	 /*synthesis keep*/;  		 //写请求  高有效
////////////////////////// 写数据的时候，整个过程中，必须保持local_write_req信号一直有效

wire 	[63:0]	  local_wdata		 /*synthesis keep*/;		     //写数据口  64位	
reg 	[7:0]	     local_be;   								 //读写数据字节使能标志信号。Local_be的每个位对应local_wdata或local_rdata的8bit数据是否有效。	
reg	[2:0]  	  local_size; 								 //突发长度

//////////////////////////////////////////////////////////////////////
wire		        local_ready		 /*synthesis keep*/;			 //高表示可以进行操作

/* 在遇到local_ready拉低的读操作，下列信号必须保持到local_ready拉高为止：
local_read_req;
local_size;
local_addr;
*/


		
reg            local_burstbegin 	 /*synthesis noprune*/;         //本地逻辑对DDR2 IP核的数据突发传输起始标志信号。
///////////////////////////////////////////////////多个数据传输时，该信号在 local_write_req或local_read_req信号拉高的第一个时钟周期时保持高电平，用于指示传输的起始

wire 	[63:0]	local_rdata		 	 /*synthesis keep*/;       //读数据口  64位
wire		      local_rdata_valid 		 /*synthesis keep*/;   //读数据有效位
wire		      local_refresh_ack;					    //刷新
wire			   local_init_done		  	 /*synthesis keep*/;  	//ddr2初始化完成标志
wire		      phy_clk      		     /*synthesis keep*/;		//用户操作时钟	
wire		      aux_full_rate_clk;   
wire		      aux_half_rate_clk;
wire           burst_finish;


////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////
//实验用的   用来做触发条件的
////////////////////////////////////////////////////////////////////
reg    [8:0] 	   cntt;
reg	 [15:0]     scnt; 
reg    [7:0]      times;	
reg    timer_wrreq;
/////////////////////////////////////////////////////////////////////////=========时钟计数   用来启动读写状态机	
always @(negedge phy_clk or negedge reset_n)
	if(!reset_n) begin 
	scnt <= 16'd0;
	//timer_wrreq <=0;
	end
	else if( fpga_data1[0] )             //先写进去再启动读
	begin
	//   timer_wrreq <= timer_wrreq_n;
		scnt <= scnt+1'b1;        //   时钟计数
	if(scnt==16'hffff)
		scnt  <= 16'h9fff; 
	end else scnt <= 0;
////////////////////////////////////////////////////////////////////
////////////////////////////==============================================
////////////////////////////==============================================	

wire timer_wrreq_n = (scnt == 11'h10)? 1'b1 : 1'b0/*synthesis keep*/;	//ding shi write    




always @(negedge clk_200m or negedge reset_n)
if(!reset_n) begin 
	timer_wrreq <=0;
end else 
   timer_wrreq <=		fpga_data9[0];


//wire timer16_rdreq = (scnt == 11'h200)/*synthesis keep*/;	//ding shi read   ddr2    改为定条件触发
 
//wire timer_ack = (scnt ==   11'h300)/*synthesis keep*/;	//ding shi read 

always @(posedge phy_clk or negedge reset_n)
	if(!reset_n) times <= 8'd0;
	else if(timer16_rdreq) times <= times+1'b1;       //用来计数读数据个数       读请求
	
////////////////////////////==============================================



parameter  SIDLE = 4'd0;       //初始化程序
parameter  SWRDB = 4'd1;		  	//写操作
parameter  SRDDB = 4'd2;			//读操作
parameter  SRDDB_1 = 4'd3;		//读1操作
parameter  SRDDB_2 = 4'd4;		//读1操作
parameter  SRDDB_3 = 4'd5;		//读1操作
 
parameter  SSTOP = 4'd6;			//停止	
parameter  await = 4'd7;			//等待读完成
	
(*preserve*)   reg[3:0] cstate;
					reg[8:0] num;


/*fifO 写
时钟选择标志位*/	
(*preserve*)  reg [7:0] FIFO_flag_rd /*synthesis noprune*/;  

reg  [6:0]  chang_add_flag;
///////////////////////////////////////////***************************   状态机   cstate=当前状态
always @(posedge phy_clk or negedge reset_n)     
	if(!reset_n) begin 
	cstate <= SIDLE;   
	FIFO_flag_rd   <= 8'd4;
	chang_add_flag <= 0;
	end 
	else begin
		case(cstate)    
			SIDLE: begin
				if(timer_wrreq)                  cstate <= SWRDB  ;
				else if(timer16_rdreq)     begin cstate <= SRDDB  ;  chang_add_flag[0] <= 1 ;  end
				else if(timer16_31_rdreq)  begin cstate <= SRDDB_1;  chang_add_flag[1] <= 1 ;  end
				else if(timer32_47_rdreq)  begin cstate <= SRDDB_2;  chang_add_flag[2] <= 1 ;  end
				else if(timer48_63_rdreq)  begin cstate <= SRDDB_3;  chang_add_flag[3] <= 1 ;  end
				else                             cstate <= SIDLE  ;
			end
			SWRDB: begin
			   FIFO_flag_rd <= 0;
				if((num == 9'd127) && local_ready) cstate <= SSTOP;   //表示当num==7时写8个数据  与  ready为零时暂停，写操作
				else cstate <= SWRDB;
			end
			SRDDB: begin

			   FIFO_flag_rd <= 0;                         //标志位 表示对第一个FIFO模块进行写  写完了再改变其状态
				if( local_read_req) begin 
				    cstate <= await;          //(numb_read == 5'd1) && numb_read表示 启动一次的 突发地址  完了之后等待读取完
					 chang_add_flag <= 0;
					 end
				else 
				begin 
				    chang_add_flag[4] <= 1;
				    chang_add_flag[5] <= chang_add_flag[4];
				    chang_add_flag[6] <= chang_add_flag[5];
				    cstate <= SRDDB;
				end 
			end
			//第 二 个 模 块 的 读使能
			SRDDB_1: begin
			   FIFO_flag_rd <= 1;
								if( local_read_req) begin 
				    cstate <= await;          //(numb_read == 5'd1) && numb_read表示 启动一次的 突发地址  完了之后等待读取完
					 chang_add_flag <= 0;
					 end
				else 
				begin 
				    chang_add_flag[4] <= 1;
				    chang_add_flag[5] <= chang_add_flag[4];
				    chang_add_flag[6] <= chang_add_flag[5];
				    cstate <= SRDDB_1;
				end 
			end
			//第 3 个 模 块 的 读使能
			SRDDB_2: begin
			   FIFO_flag_rd <= 2;
												if( local_read_req) begin 
				    cstate <= await;          //(numb_read == 5'd1) && numb_read表示 启动一次的 突发地址  完了之后等待读取完
					 chang_add_flag <= 0;
					 end
				else 
				begin 
				    chang_add_flag[4] <= 1;
				    chang_add_flag[5] <= chang_add_flag[4];
				    chang_add_flag[6] <= chang_add_flag[5];
				    cstate <= SRDDB_2;
				end 
			end
			//第 4 个 模 块 的 读使能
			SRDDB_3: begin
			   FIFO_flag_rd <= 3;
				if( local_read_req) begin 
				    cstate <= await;          //(numb_read == 5'd1) && numb_read表示 启动一次的 突发地址  完了之后等待读取完
					 chang_add_flag <= 0;
					 end
				else 
				begin 
				    chang_add_flag[4] <= 1;
				    chang_add_flag[5] <= chang_add_flag[4];
				    chang_add_flag[6] <= chang_add_flag[5];
				    cstate <= SRDDB_3;
				end 
			end
			///关键作用 启动一次读指令后等待读取完成，在重头检测   要做一个标志位读取完成标志
			 await : begin
			 chang_add_flag <= 0;
				if (read_numb == 31) cstate <= SSTOP ;      //记满16个数  表示一次 读循环
				else 
				begin 
				cstate <= await;
				end
			end
			////////////////////////////////////////
			SSTOP: 
			begin 
			chang_add_flag <= 0;
			FIFO_flag_rd   <= 4;
			cstate <= SIDLE;
			end 
			
			default: begin 
			cstate <= SIDLE;
			end
		endcase
		if((fpga_data4[0]))
		begin
	   	chang_add_flag <= 0;
			FIFO_flag_rd <= 4;
			cstate <= SIDLE; 
		end	
	end
	
	
reg  [63:0]   ram_rdat/*synthesis noprune*/;

//assign        local_wdata = (num)|(num<<16)|(num<<32)|(num<<48);
assign        local_wdata     = fifo_ddr2;
//reg	 [24:0]   local_address;
assign 		  local_write_req = (cstate == SWRDB)?1'b1 : 1'b0;	   //这么写有问题，但是刚好写的时候，不做其他事情，local_ready 一直为高电平，所以默认 写状态时，local_ready为高，而且每次写完都等写入完成在做下一步操作，
//assign        local_read_req =  ((cstate == SRDDB)|| (cstate == SRDDB_1))&& (local_ready);	//DDR2  的读请求控制位，但需要在此之前先给地址
//assign      local_read_req = (timer16_rdreq == local_ready);
wire   		  local_read_req	 /*synthesis keep*/;			 //读请求  高有效
reg           local_read_req_n;  
//always @(posedge phy_clk or negedge reset_n)     
//	if(!reset_n) 
//	local_read_req <= 0;  
//	else if(((cstate == SRDDB)|| (cstate == SRDDB_1)||(cstate == SRDDB_2)||(cstate == SRDDB_3)))
//   local_read_req <= 1 && local_ready;  
//	else 
//   local_read_req <= 0;  
	
	
//assign 	local_read_req  =(((SRDDB_3 == cstate)|| (SRDDB_2 == cstate)||(SRDDB_1 == cstate)||(SRDDB == cstate))&& (local_ready))?1:0;
assign 	local_read_req  =(chang_add_flag[6])? (local_ready):0;
		
	
/*




*/
////////////////////////////////////////////////////////xia ze ping 
reg    [7:0]  centt;
wire   [7:0] w_cent;
wire   [7:0] w_cent_z;     //整数部分

wire   [7:0] r_cent;


/* always@(posedge phy_clk)       //总数据个数来换算地址变化   突发长度为8
		if(!reset_n) centt <= 7'd0; */
	//	else if()


(*preserve*) assign   w_cent=num%32;
(*preserve*) assign   w_cent_z=num/32;

(*preserve*) assign   r_cent=num%32;
//num是读写时        ready有效的个数
/* always@(posedge phy_clk)
	if(!reset_n) local_address <= 25'd0;
	else if((w_cent==7)&&(SWRDB)&&(local_ready))
		local_address<=local_address+8; */
	//	 else if((num==15)&&(SWRDB)&&(local_ready))
	//	 local_address<=local_address+8; 
			//else /* if((cstate == SRDDB)&&(local_ready))
				//	local_address<=local_address+8;
				//	else if((num==1)&&(cstate == SRDDB)&&(local_ready))
				//	local_address<=local_address+8;
				//	else if(cstate == SIDLE)
				//	local_address<=0; */
				//	else;
		
wire 	    local_burst;	
assign	 local_burst = (local_read_req | local_write_req)?1'b1 : 1'b0;

//local_burstbegin(local_read_req | local_write_req)	
/////////////////////////////////////////////////////////////////		



always @(posedge phy_clk or negedge reset_n)
	if(!reset_n) num <= 9'd0;
	else if((cstate == SWRDB) || (cstate == SRDDB)|| (cstate == SRDDB_1)|| (cstate == SRDDB_2)|| (cstate == SRDDB_3)) begin
		if(local_ready) num <= num+9'h1;                     //表示高过了就为一
		else ;
	end
else  
     begin num <= 9'd0;
	end
	
////////////////////////////////////////////////////////////////////////////////	
////////////////////////////////////////////////////////////////////////////////	

////////////////////////////////////////////////////////////////////////////////read  并记录个数  个数到了 做个标志跳出await 状态
(*preserve*) reg [7:0]   read_numb;    //记录个数
(*preserve*) reg [7:0]   read_numb_1;    //记录个数

always @(posedge phy_clk or negedge reset_n)
  if(!reset_n)
	  begin
	//  FIFO16_wclk <= 0;
	   read_numb <= 0;
      ram_rdat <=64'h0;
	end else if(local_rdata_valid && (FIFO_flag_rd==0)) begin
    
	  ram_rdat     <= local_rdata;
	  FIFO16_wdata <= local_rdata;
	  
	  if(read_numb == 31)
	  read_numb <= 0 ;
	  else 
	  read_numb <=   read_numb + 8'B1;
	  
	end else if(local_rdata_valid && (FIFO_flag_rd==1)) begin
		  ram_rdat <= local_rdata;
		  FIFO16_31_wdata <= local_rdata;

		  if(read_numb == 31)
		  read_numb <= 0 ;
		  else 
		  read_numb <=   read_numb + 8'B1;
   end else if(local_rdata_valid && (FIFO_flag_rd==2)) begin
		  ram_rdat <= local_rdata;
		  FIFO32_47_wdata <= local_rdata;

		  if(read_numb == 31)
		  read_numb <= 0 ;
		  else 
		  read_numb <=   read_numb + 8'B1;
	end else if(local_rdata_valid && (FIFO_flag_rd==3)) begin
		  ram_rdat <= local_rdata;
		  FIFO48_63_wdata <= local_rdata;

		  if(read_numb == 31)
		  read_numb <= 0 ;
		  else 
		  read_numb <=   read_numb + 8'B1;
	end
		 else if(fpga_data4[0])
		 	begin
			read_numb <= 0;
			ram_rdat <=64'h0;
	end else ;
		 
///////////////////////////////////////////////////////////////////////////////
//在这里创造一个 FIFO的写时钟   好将local_rdata同步写入FIFO
// 条件是出来一个  有效数据后   时钟变化一次   这个变化频率还要个 phy_CLK 同步
//上升沿锁存数据
/////////////////////////////////////////////////////////////////////////////
  reg      FIFO16_wclk /*synthesis noprune*/;              //第一个FIFO的写时钟
  
  reg      FIFO16_31_wclk /*synthesis noprune*/;            // 第二个FIFO的写时钟
  
  reg      FIFO32_47_wclk /*synthesis noprune*/;            // 第3个FIFO的写时钟

  reg      FIFO48_63_wclk /*synthesis noprune*/;            // 第4个FIFO的写时钟

		
 always @(posedge clk_200m  or negedge reset_n)
  if(!reset_n)
    FIFO16_wclk <= 1;
	else if (( (scnt  >= 11'h100) && phy_clk && local_rdata_valid && (FIFO_flag_rd == 0) ))
	  FIFO16_wclk <= 0; 
	else
	  FIFO16_wclk<= 1; 	


 always @(posedge clk_200m  or negedge reset_n)
  if(!reset_n)
    FIFO16_31_wclk <= 1;
	else if (( (scnt  >= 11'h100) && phy_clk && local_rdata_valid && (FIFO_flag_rd == 1) ))
	  FIFO16_31_wclk <= 0; 
	else
	  FIFO16_31_wclk <= 1; 	
	
 always @(posedge clk_200m  or negedge reset_n)
  if(!reset_n)
    FIFO32_47_wclk <= 1;
	else if (( (scnt  >= 11'h100) && phy_clk && local_rdata_valid && (FIFO_flag_rd == 2) ))
	 FIFO32_47_wclk <= 0; 
	else
	 FIFO32_47_wclk <= 1; 	
	  
 always @(posedge clk_200m  or negedge reset_n)
  if(!reset_n)
	 FIFO48_63_wclk <= 1;
	else if (( (scnt  >= 11'h100) && phy_clk && local_rdata_valid && (FIFO_flag_rd == 3) ))
	 FIFO48_63_wclk <= 0; 
	else
	 FIFO48_63_wclk <= 1; 	

//需要记个数，记波形深度FIFO_wclk  从低到高为一个深度由于深度高达8M  所以需要用2的23次， 就直接给个32位算了




///////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////
	



 
/////////////////////////////////////////////////////////////////////////////////////////////	  
/////////////////////////////////////////////////////////////////////////////////////////////	
//////////////////////////////////////////////////////////////////////////////////////////// 用来计数  读地址	
/////////////////////////////////////////定义基地址  和终止地址	夏泽平   读的时候读的数据就在这两个地址之间循环  四组地址

//1-16
(*noprune*) reg 	  [24:0]    local_address_base_0/*synthesis noprune*/;      //读起始地址      
(*noprune*) reg 	  [24:0]    local_address_fine_0/*synthesis noprune*/;      //读终止地址
(*noprune*) reg     [24:0]    local_address_current_0/*synthesis noprune*/;   //当前的地址
  


//17-32
(*noprune*) reg 	  [24:0]    local_address_base_1/*synthesis noprune*/;      //读起始地址      
(*noprune*) reg 	  [24:0]    local_address_fine_1/*synthesis noprune*/;      //读终止地址
(*noprune*) reg     [24:0]    local_address_current_1/*synthesis noprune*/;   //当前的地


//33-48
(*noprune*) reg 	  [24:0]    local_address_base_2/*synthesis noprune*/;      //读起始地址      
(*noprune*) reg 	  [24:0]    local_address_fine_2/*synthesis noprune*/;      //读终止地址
(*noprune*) reg     [24:0]    local_address_current_2/*synthesis noprune*/;   //当前的地址


//49-64
(*noprune*) reg 	  [24:0]    local_address_base_3/*synthesis noprune*/;      //读起始地址      
(*noprune*) reg 	  [24:0]    local_address_fine_3/*synthesis noprune*/;      //读终止地址
(*noprune*) reg     [24:0]    local_address_current_3/*synthesis noprune*/;   //当前的地址



///////////////////////////////////////////////////////////////   读请求操作用来给地址  ddr分为4组   存储区，分别存4组16路信号  32M深度一组
///////第一组地址为   0  ~   23‘h3 fffff     
///////第二组地址为   23‘h4 00000      
 ///////第二组地址为  24‘h8 00000    
 ///////第二组地址为  25‘h10 00000    
always @(posedge phy_clk or negedge reset_n)
  if(!reset_n )
  begin
	  local_address <= 25'B0;
	//  local_address_base_0 <= 25'b0;
	  local_address_current_0 <= 25'h0;
	//  local_address_fine <= 25'd32;
	  
	  //local_address_1 <= 25'B0;
	 // local_address_base_1 <= 25'd0;
	  local_address_current_1 <= 25'H0;
	//  local_address_fine_1 <= 25'd32;
	  
	//  local_address_base_2 <= 25'd0;
	  local_address_current_2 <= 25'H0;
	//  local_address_fine_2 <= 25'd32;
	  
	//  local_address_base_3 <= 25'd0;
	  local_address_current_3 <= 25'H0;
	//  local_address_fine_3 <= 25'd32;
	  
  end
		
else   begin
 case(chang_add_flag)    
			4'b1: begin
			if(({local_address_current_0,2'b0}) < (fpga_data_deep32 ))
		      begin
		      	local_address_current_0 <= local_address_current_0 + 25'd32; 				   
		      	local_address           <= local_address_current_0;
	         end 
		      else begin     ////////////////这是地址超出后的处理     回到起始点
		      	local_address_current_0 <= local_address_base_0 + 25'd32;
		      	local_address           <= local_address_base_0;
		      end
			end
			4'b10: begin
				if(({local_address_current_1,2'b0}) < (fpga_data_deep32))
	         	begin
	         		local_address_current_1 <= local_address_current_1 + 25'd32; 				   
	         		local_address <= local_address_current_1  + 25'h400000 ;    //累加值加基地址
	            end 
	         	else begin     ////////////////这是地址超出后的处理     回到起始点
	         		local_address_current_1 <=  25'd32 + local_address_base_0;
	         		local_address           <=  local_address_base_0  + 25'h400000 ;
	        end 
			end
			4'b100: begin
	        		if(({local_address_current_2,2'b0}) < (fpga_data_deep32 ))
	        	begin
	        		local_address_current_2 <= local_address_current_2 + 25'd32; 				   
	        		local_address <= local_address_current_2  + 25'h800000  ;
	          end 
	        	else begin     ////////////////这是地址超出后的处理     回到起始点
	        		local_address_current_2 <=   25'd32  + local_address_base_0;
	        		local_address <= local_address_base_0 + 25'h800000;
            end 
			end
			//第 二 个 模 块 的 读使能
			4'b1000: begin
         			if(({local_address_current_3,2'b0}) < (fpga_data_deep32))
         		begin
         			local_address_current_3 <= local_address_current_3 + 25'd32; 				   
         			local_address <= local_address_current_3 + 25'h1000000;
         	   end 
         		else begin     ////////////////这是地址超出后的处理     回到起始点
         			local_address_current_3 <=  25'd32  + local_address_base_0;
         			local_address <= local_address_base_0 + 25'h1000000;
         	   end 
		  	end
			4'b000: begin
         			if(fpga_data4[0])
	            	begin
	                local_address_current_0 <= 25'h0;
	                local_address_current_1 <= 25'H0;
	                local_address_current_2 <= 25'H0;
	                local_address_current_3 <= 25'H0;
	             end  
              else if((w_cent==31)&&(SWRDB)&&(local_ready))
	               local_address   <=  local_address+25'd32;     //设置的写入起始位置
	           else if (fpga_data6[0])
	              local_address    <=  write_local_address;    //需要锁一道	
		  	end
			
			
			default: begin   	
		      					
		   	end
		endcase

end




















//
//if((	chang_add_flag == 0))  begin    //请求要在ready有效时执行  //执行一次读操作前改变其地址  所以要做一个标志位
//
//		if((local_address_current_0<<2) < (fpga_data_deep32 ))
//		begin
//			local_address_current_0 <= local_address_current_0 + 25'd32; 				   
//			local_address           <= local_address_current_0;
//
//	   end 
//		else begin     ////////////////这是地址超出后的处理     回到起始点
//			local_address_current_0 <= local_address_base_0 + 25'd32;
//			local_address           <= local_address_base_0;
//
//		end
//end 
//else if((	chang_add_flag == 1))  begin    //请求要在ready有效时执行     //请求要在ready有效时执行  //执行一次读操作前改变其地址  所以要做一个标志位
//
//		if((local_address_current_1<<2) < (fpga_data_deep32))
//		begin
//			local_address_current_1 <= local_address_current_1 + 25'd32; 				   
//			local_address <= local_address_current_1  + 25'h400000 ;    //累加值加基地址
//
//	   end 
//		else begin     ////////////////这是地址超出后的处理     回到起始点
//			local_address_current_1 <=  25'd32;
//			local_address <= local_address_base_0  + 25'h400000 ;
//
//	   end 
//end
//else if((	chang_add_flag == 2))  begin    //请求要在ready有效时执行     //请求要在ready有效时执行  //执行一次读操作前改变其地址  所以要做一个标志位
//
//		if((local_address_current_2<<2) < (fpga_data_deep32 ))
//		begin
//			local_address_current_2 <= local_address_current_2 + 25'd32; 				   
//			local_address <= local_address_current_2  + 25'h800000  ;
//
//	   end 
//		else begin     ////////////////这是地址超出后的处理     回到起始点
//			local_address_current_2 <=   25'd32;
//			local_address <= local_address_base_0 + 25'h800000;
//     end 
//end
//else if((	chang_add_flag == 3))  begin    //请求要在ready有效时执行     //请求要在ready有效时执行  //执行一次读操作前改变其地址  所以要做一个标志位
//
//		if((local_address_current_3<<2) < (fpga_data_deep32))
//		begin
//			local_address_current_3 <= local_address_current_3 + 25'd32; 				   
//			local_address <= local_address_current_3 + 25'h1000000;
//
//	   end 
//		else begin     ////////////////这是地址超出后的处理     回到起始点
//			local_address_current_3 <=  25'd32;
//			local_address <= local_address_base_0 + 25'h1000000;
//
//	   end 
//end
// /////////////////////////////////////////////////这是写数据时地址的变化
//else if((w_cent==31)&&(SWRDB)&&(local_ready))
//	 local_address   <=  local_address+25'd32;     //设置的写入起始位置
//	 else if (fpga_data6[0])
//	local_address    <=  write_local_address;    //需要锁一道
//	 
//else if(fpga_data4[0])
//		 	begin
//	  local_address_current_0 <= 25'h0;
//
//	  local_address_current_1 <= 25'H0;
//	  
//	  local_address_current_2 <= 25'H0;
//	  
//	  local_address_current_3 <= 25'H0;
//	end else ;

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////	
//目的是   当FIFO内部数据低于多少的时候     启动一次写请求        将ddr2  读出的数据给FIFO
//DDR2  一次给32个64位数据
//timer16_rdreq   执行一次读请求  2个burst   32个   之前是定时间    ，现在是根据条件
/////////////////////////////////////////////////////////////////////////////////////////////////////////	 



(*noprune*)  reg    [10:0]  FIFO16_rdusedw_n /*synthesis noprune*/; 


(*noprune*)  wire   [63:0]  FIFO_rdata /*synthesis noprune*/;    //用来做FIFO 与FIFO 之间数据传输
(*noprune*)  reg    [63:0]  FIFO_rdata_n /*synthesis noprune*/;  




(*noprune*)  reg    [63:0]   FIFO16_wdata /*synthesis noprune*/;  
(*noprune*)  reg    [63:0]   FIFO16_31_wdata /*synthesis noprune*/;  
(*noprune*)  reg    [63:0]   FIFO32_47_wdata /*synthesis noprune*/; 
(*noprune*)  reg    [63:0]   FIFO48_63_wdata /*synthesis noprune*/; 

(*noprune*)  wire   [10:0]   FIFO16_rdusedw /*synthesis noprune*/;  
(*noprune*)  wire   [10:0]   FIFO16_31_rdusedw /*synthesis noprune*/; 
(*noprune*)  wire   [10:0]   FIFO32_47_rdusedw /*synthesis noprune*/; 
(*noprune*)  wire   [10:0]   FIFO48_63_rdusedw /*synthesis noprune*/; 

(*noprune*)  wire            timer16_rdreq /*synthesis noprune*/;
(*noprune*)  wire            timer16_31_rdreq /*synthesis noprune*/;
(*noprune*)  wire            timer32_47_rdreq /*synthesis noprune*/;
(*noprune*)  wire            timer48_63_rdreq /*synthesis noprune*/;

/*
第1组请求信号
*/
assign    timer16_rdreq    = ((scnt  >= 16'h110) &&(FIFO16_rdusedw < 250))? 1'b1 : 1'b0;       //读条件   然后将读出来的数给FIFO**************主要难点  FIFO写时钟的配合，需要单独创造一个
/*
第二组请求信号
*/
assign    timer16_31_rdreq =  ((scnt  >= 16'h110) &&(FIFO16_31_rdusedw < 250))? 1'b1 : 1'b0;       //读条件   然后将读出来的数给FIFO**************主要难点  FIFO写时钟的配合，需要单独创造一个
/*
第3组请求信号
*/
assign    timer32_47_rdreq =  ((scnt  >= 16'h110) &&(FIFO32_47_rdusedw < 250))? 1'b1 : 1'b0;       //读条件   然后将读出来的数给FIFO**************主要难点  FIFO写时钟的配合，需要单独创造一个
/*
第4组请求信号
*/
assign    timer48_63_rdreq =  ((scnt  >= 16'h110) &&(FIFO48_63_rdusedw < 250))? 1'b1 : 1'b0;       //读条件   然后将读出来的数给FIFO**************主要难点  FIFO写时钟的配合，需要单独创造一个


//assign    timer16_31_rdreq = ((scnt  >= 11'h190) &&(FIFO16_31_rdusedw < 50))? 1'b1 : 1'b0;       //读条件   然后将读出来的数给FIFO**************主要难点  FIFO写时钟的配合，需要单独创造一个

//timer16_rdreq只是用来singtap2查看的 
always @(posedge phy_clk or negedge reset_n)
  if(!reset_n)
  begin 
   FIFO_rdata_n <= 31'B0;
	FIFO16_rdusedw_n <= 31'B0;
	end
	else 
		begin 
		FIFO_rdata_n <= FIFO_rdata;
		FIFO16_rdusedw_n <= FIFO16_rdusedw;
		FIFO0_31_Two_level_cache_rdusedw_n <= FIFO0_31_Two_level_cache_rdusedw;
	end 
/////////////////////////////////////////////////////////	
	(*noprune*)  reg [8:0] FIFO0_31_Two_level_cache_rdusedw_n /*synthesis noprune*/;
	

/*/////////////////////////////////////////////
前0-15位的二级FIFO输出控制和写请求  ，和16-31是一样的因为他们是同频率输出

*/	////////////////////////////////////////////////// FIFO0_31_read_req 主要是为了二级FIFO数据不够时的写请求  
wire  FIFO0_31_read_req_n   = ((scnt  >= 16'h250) &&(FIFO16_rdusedw > 200) && ((FIFO16_31_rdusedw > 200))    && (FIFO0_31_Two_level_cache_rdusedw_n <= 300))? 1'b1 : 1'b0; 
////////////////////////////////////////////////// FIFO64_read_req 主要是为了二级FIFO数据不够时的写请求  
wire  FIFO32_63_read_req_n  = ((scnt  >= 16'h250) &&(FIFO32_47_rdusedw > 200)&&(FIFO48_63_rdusedw >200) && (FIFO32_63_Two_level_cache_rdusedw <= 300))? 1'b1 : 1'b0; 

reg   FIFO0_31_read_req;
reg   FIFO32_63_read_req;

always @(negedge phy_clk or negedge reset_n)
	if(!reset_n)begin
	FIFO0_31_read_req <= 0;
	FIFO32_63_read_req <= 0;
	start <= 0;
end  else begin
   FIFO0_31_read_req <=  FIFO0_31_read_req_n;
	FIFO32_63_read_req <= FIFO32_63_read_req_n;
	start <= start_n;
	end









wire start_n= (scnt  >= 16'h7fff)? 1'b1 : 1'b0;          //最后的读使能
//wire start_n=fpga_data1[1] ;
reg  start ;






reg   FIFO0_31_Two_level_cache_rdclk_en;//前32路同步使能

reg   FIFO32_63_Two_level_cache_rdclk_en;//后32路同步使能


////////////////按读出数据计数

  

////////////////////////////////////////////////////////////////////////////
  reg [31:0]    fifo0_31_deep;    //64路深度是一样的，但前32和后32的读取速度不一样   用来计数
  reg [31:0]    fifo32_63_deep;   //64路深度是一样的，但前32和后32的读取速度不一样  用来计数
  
  reg [31:0]    fifo0_31_deep_base;    //   
  reg [31:0]    fifo32_63_deep_base;    //
  ///////0-15和16-31只需要一个FIFO16——read——req  因为他们是同步输出，所以二级缓存里的数据多少理论上是一样的，所以只需一个
  
  //当初始化深度%4时 余数不为零  则后续算循环段地址时 计数地址要加1，且当循环段地址
 wire     [2:0]      flag_init;
 assign    flag_init =   fpga_data_deep32_inti % 4;
 //循环深度，  突发长度为32    一次32*4个地址   如果是128 则判断 flag_init 是否为0 是的话 +1个突发长度
 wire     [30:0]     deep_loop;
 assign    deep_loop  =  fpga_data_deep32 - fpga_data_deep32_inti   + flag_init ;
 //计算出最后需要多少个  突发长度
 wire    [31:0]     BURST_CNT1;
 assign    BURST_CNT1 = ((((deep_loop-1) >>7) + 1 )<< 7 );  //*128   读取深度
 
  
 
 
  
 wire  [31:0]   cnt1;
assign     cnt1 =(first_count32)?((BURST_CNT1 + ( {local_address_base_0 ,2'b00}))-1):(({(((fpga_data_deep32-1) >>7)  +1 ), 7'b0})-1);
  
 reg    first_count32;
always @(posedge phy_clk or negedge reset_n)
  if(!reset_n )begin 
     fifo0_31_deep <=32'd0 ;
     FIFO0_31_Two_level_cache_rdclk_en <= 0;
	  first_count32 <= 0;
  end // & (start_flag_count==1)
  else if (FIFO0_31_read_req )begin                  
	  
	  if((fifo0_31_deep >= fpga_data_deep32) | (( fifo0_31_deep <  fpga_data_deep32_inti )&&first_count32))          //这里是大于深度后的多余突发长度。不要存入二级缓存
		begin FIFO0_31_Two_level_cache_rdclk_en <= 0;
		      fifo0_31_deep <= fifo0_31_deep + 32'd1;
		end
	  else begin
	    fifo0_31_deep <= fifo0_31_deep + 32'd1;
		 FIFO0_31_Two_level_cache_rdclk_en <= 1;
		end
		 
	//  if((fifo0_31_deep  + 1) >= (fpga_data_deep32-fpga_data_deep32_inti + (127 - (fpga_data_deep32 - 1 - fpga_data_deep32_inti) % 128)+ (local_address_base_0 * 4)*first_count32 ) )             //这里是设置深度，最小突发长度对应的深度 2022-5-22
 //if((fifo0_31_deep   + 1) >= (fpga_data_deep32 + (127 - (fpga_data_deep32-1) % 128) + (local_address_base_0 * 4)*first_count32  ))           //这里是设置深度，最小突发长度对应的深度
	if((fifo0_31_deep ) >= cnt1)           //这里是设置深度，最小突发长度对应的深度 
	 begin
		 fifo0_31_deep <=   {local_address_base_0 ,2'b00}  ;
		 first_count32 <= 1;
		end
	end
	else if(fpga_data4[0]) begin 
		fifo0_31_deep <=32'd0 ;
		FIFO0_31_Two_level_cache_rdclk_en <= 0;
		first_count32 <= 0;
  end 
////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////这是后32路

 reg    first_count64;  
 
  wire  [31:0]   cnt2;
assign     cnt2 =(first_count64)?((BURST_CNT1 + ( {local_address_base_0 ,2'b00}))-1):(({(((fpga_data_deep32-1) >>7)  +1 ), 7'b0})-1);
 
 
always @(posedge phy_clk or negedge reset_n)
  if(!reset_n )begin 
     fifo32_63_deep <=32'd0 ;
     FIFO32_63_Two_level_cache_rdclk_en <= 0;
	  first_count64 <= 0;
  end 
  else if (FIFO32_63_read_req)begin                  
	    fifo32_63_deep <= fifo32_63_deep + 32'd1;
	  if((fifo32_63_deep >=  fpga_data_deep64) | (( fifo32_63_deep <  fpga_data_deep64_inti)&&first_count64))            //这里是大于深度后的多余突发长度。不要存入二级缓存
		 begin
		  fifo32_63_deep <= fifo32_63_deep + 32'd1;
		  FIFO32_63_Two_level_cache_rdclk_en <= 0;
		 end
	  else 
	  begin
		  fifo32_63_deep <= fifo32_63_deep + 32'd1;
		  FIFO32_63_Two_level_cache_rdclk_en <= 1;
		 end
	 // if((fifo32_63_deep + 1) >=  ( fpga_data_deep64- fpga_data_deep32_inti +(127 - (fpga_data_deep64 -1 - fpga_data_deep32_inti) %  128)+(local_address_base_0 * 4 )*first_count64))             //这里是设置深度，最小突发长度对应的深度 2022-5-20
	//  	  if((fifo32_63_deep + 1) >=  ( fpga_data_deep64 +(127 - (fpga_data_deep64 -1) %  128)))             //这里是设置深度，最小突发长度对应的深度
	  if((fifo32_63_deep ) >=  cnt2)
	 begin
		 first_count64 <= 1;
		 fifo32_63_deep <=   {local_address_base_0 ,2'b00} ;
	  end
	end
   else if ((fpga_data4[0]))
	begin 
	   fifo32_63_deep <=32'd0 ;
      FIFO32_63_Two_level_cache_rdclk_en <= 0;
	   first_count64 <= 0;
	end
/////////////////////////////////////////////////////////

wire    [63:0]  fifo_output_pin_n;
reg     [63:0]  fifo_output_pin_nn;

always @(posedge phy_clk or negedge reset_n )
	if(!reset_n )begin 
	fifo_output_pin<=0;
	end
	else begin 
	 fifo_output_pin_nn <= fifo_output_pin_n   &  (~FPGA_santai_control);
    fifo_output_pin    <= fifo_output_pin_nn;
	if(fpga_data4[0])
		fifo_output_pin<=0;
	end
	
	
	

	
	
//	//需要人为处理2个时钟的一级缓冲,开始第一次需要后续就不用了
//reg [1:0]  start_flag_count;
//always @(posedge clk_200m or negedge reset_n )
//	if(!reset_n)begin 
//	start_flag_count  <= 2'd0;
//	end else if(FIFO0_31_read_req & ((~(start_flag_count==1))))
//		start_flag_count <= start_flag_count+1;
//	else 
//		start_flag_count <= start_flag_count;
	


////////////////////////////////////
 /*
 
 双缓存FIFO  两组0-15和16-31      读出时钟同步
 
 */ 
 ////////////////////////////////// 

 FIFO1 FIFO16(
         .aclr  	     (!reset_n |(fpga_data4[0])),
			.data	        (FIFO16_wdata) ,                //  写入数据     64位   input
		   .wrclk	     (FIFO16_wclk),                 //写时钟  	    input
			.wrreq        (1'b1),					//写请求           input
			.rdclk        (phy_clk  ) ,               //  读时钟     需要控制它方便 计数
			.rdreq	     (FIFO0_31_read_req  ),                 //读请求
			.q		        (FIFO_rdata[15:0]),                     //输出数据        output      16位
			.rdusedw	     (FIFO16_rdusedw), 				//读 还有多少个数据没读出   output
			.wrfull		  ()                 //写满数据表示   output  可以不用因为我知道要写多少数据什么时候会满
   );

	
////////////////////////////////////////////////////读出数据按输出深度

(*noprune*)  wire  [8:0] FIFO0_31_Two_level_cache_rdusedw/*synthesis noprune*/; 

fifo2  FIFO16_Two_level_cache (
	.aclr       (!reset_n |(fpga_data4[0])),
	.data       (FIFO_rdata[15:0]) ,
	.rdclk      (output1_clk  ) ,               //  读时钟        
	.rdreq      (start),            
	.wrclk      (phy_clk),                 //写时钟  	    input
	.wrreq      (FIFO0_31_read_req && FIFO0_31_Two_level_cache_rdclk_en),					//写请求           input
	.q          (fifo_output_pin_n[15:0]),           //最后输出的引脚
	.wrusedw    (FIFO0_31_Two_level_cache_rdusedw)
	);
//	
	

  
/*
前16-31位输出数据

*/	
 FIFO1 FIFO16_31(
         .aclr  	     (!reset_n |(fpga_data4[0])),
			.data	        (FIFO16_31_wdata) ,                //  写入数据     64位   input
			.rdclk        (phy_clk ) ,               //  读时钟 
			.rdreq	     (FIFO0_31_read_req),                 //读请求   就是最后输出的频率 是连续的不间断
			.wrclk	     (FIFO16_31_wclk),                 //写时钟  	    input
			.wrreq        (1'b1),					//写请求           input
			.q		        (FIFO_rdata[31:16]),                     //输出数据        output      16位
			.rdusedw	     (FIFO16_31_rdusedw), 				//读 还有多少个数据没读出   output
			.wrfull		  ()                 //写满数据表示   output  可以不用因为我知道要写多少数据什么时候会满
	);


fifo2  FIFO16_31_Two_level_cache (
	.aclr       (!reset_n |(fpga_data4[0])),
	.data       (FIFO_rdata[31:16]) ,
	.rdclk      (output1_clk ) ,               //  读时钟        
	.rdreq      (start),            
	.wrclk      (phy_clk ),                 //写时钟  	    input
	.wrreq      (FIFO0_31_read_req && FIFO0_31_Two_level_cache_rdclk_en),					//写请求           input
	.q          (fifo_output_pin_n[31:16]),           //最后输出的引脚
	.wrusedw    ()    //和前一片同步
	);
////////////////////////////////////////////
////////////////////////////////////////////
////////////////////////////////////////////
  
  	
	
////////////////////////////////////
 /*
 
 双缓存FIFO  两组32-47和48-64      读出时钟同步
 
 */ 
 ////////////////////////////////// 
  FIFO1 FIFO32_47(
         .aclr  	     (!reset_n |(fpga_data4[0])),
			.data	        (FIFO32_47_wdata) ,                //  写入数据     64位   input
		   .wrclk	     (FIFO32_47_wclk),                 //写时钟  	    input
			.wrreq        (1'b1),					//写请求           input
			.rdclk        (phy_clk  ) ,               //  读时钟     需要控制它方便 计数
			.rdreq	     (FIFO32_63_read_req),                 //读请求
			.q		        (FIFO_rdata[47:32]),                     //输出数据        output      16位
			.rdusedw	     (FIFO32_47_rdusedw), 				//读 还有多少个数据没读出   output
			.wrfull		  ()                 //写满数据表示   output  可以不用因为我知道要写多少数据什么时候会满
   );

	
////////////////////////////////////////////////////读出数据按输出深度

(*noprune*) wire  [8:0] FIFO32_63_Two_level_cache_rdusedw/*synthesis noprune*/; 

fifo2  FIFO32_47_Two_level_cache (
	.aclr       (!reset_n |(fpga_data4[0])),
	.data       (FIFO_rdata[47:32]) ,
	.rdclk      (output2_clk  ) ,               //  读时钟        
	.rdreq      ( start),            
	.wrclk      (phy_clk ),                 //写时钟  	    input
	.wrreq      (FIFO32_63_read_req && FIFO32_63_Two_level_cache_rdclk_en),					//写请求           input
	.q          (fifo_output_pin_n[47:32]),           //最后输出的引脚
	.wrusedw    (FIFO32_63_Two_level_cache_rdusedw)
	);
//	
	

  
/*
前48-63位输出数据

*/	
 FIFO1 FIFO48_63(
         .aclr  	     (!reset_n |(fpga_data4[0])),
			.data	        (FIFO48_63_wdata) ,                //  写入数据     64位   input
			.rdclk        (phy_clk ) ,               //  读时钟 
			.rdreq	     (FIFO32_63_read_req),                 //读请求   就是最后输出的频率 是连续的不间断
			.wrclk	     (FIFO48_63_wclk),                 //写时钟  	    input
			.wrreq        (1'b1),					//写请求           input
			.q		        (FIFO_rdata[63:48]),                     //输出数据        output      16位
			.rdusedw	     (FIFO48_63_rdusedw), 				//读 还有多少个数据没读出   output
			.wrfull		  ()                 //写满数据表示   output  可以不用因为我知道要写多少数据什么时候会满
	);


fifo2  FIFO48_63_Two_level_cache (
	.aclr       (!reset_n |(fpga_data4[0])),
	.data       (FIFO_rdata[63:48]) ,
	.rdclk      (output2_clk ) ,               //  读时钟        
	.rdreq      (start ),            
	.wrclk      (phy_clk ),                 //写时钟  	    input
	.wrreq      (FIFO32_63_read_req && FIFO32_63_Two_level_cache_rdclk_en),					//写请求           input
	.q          (fifo_output_pin_n[63:48]),           //最后输出的引脚
	.wrusedw    ()    //和前一片同步
	); 
  
  
  
  
reg          output1_clk_n;
reg          output2_clk_n;
  
  
always @(posedge phy_clk  or negedge reset_n)
if(!reset_n)begin
	 output1_clk_n <=1;
	 output2_clk_n <=1;
end else begin
	 output1_clk_n <= output1_clk;
	 output2_clk_n <= output2_clk;
end
	 
  
  
  
  
////////////////////////////////////////////
 reg  [31:0]  clk1_count;
 reg  [31:0]  clk2_count;
 
 reg          output1_clk;
 reg          output2_clk;
//主频设置
 always @(posedge phy_clk  or negedge reset_n)
if(!reset_n)begin
	 clk1_count <= 0;
	 clk2_count <= 0;
	 output1_clk <=1;
	 output2_clk <=1;
end else if (fpga_data1[0])begin 

	if(clk1_count < fpga_data14 )begin
	 clk1_count  <= clk1_count +  1;
	 output1_clk <= 0;
	 end else begin 
	 clk1_count <= 1;
	 output1_clk <= 1; 
	 end

	 
	if(clk2_count < fpga_data15)begin 
	 output2_clk <= 0;
	 clk2_count <=  clk2_count +1;
	 end else begin 
	 output2_clk <= 1;
	 clk2_count <=1;
	 end

end else 	begin 
	 clk1_count <= 0;
	 clk2_count <= 0;
	 output1_clk <=1;
	 output2_clk <=1;
	 end
 


  
  

  
  
  
  

  
  
  
  
  
  
  
  //网页说明http://group.chinaaet.com/273/4100034224
	
ddr2   xxxx(	
	.local_address  (local_address),     		 //地址信号  input
	.local_write_req(local_write_req), 		 //写请求 INPut，本地逻辑对DDR2 IP核的数据写入请求信号，高电平有效。
	.local_read_req (local_read_req),   		 //	读请求  input，   本地逻辑对DDR2 IP核的数据读出请求信号，高电平有效。
	.local_wdata    (local_wdata),         		 //数据  input
	.local_be       (8'hff),                 		 //INPUT   是否屏蔽字节，8位 一位为一个字节 ，读写数据字节使能标志信号。Local_be的每个位对应local_wdata或local_rdata的8bit数据是否有效。
	.local_size     (64'b100000),    //16GE           		 //INPUT 突发长度，突发传输的有效数据数量，即传输多少个local_wdata或local_rdata数据。
	.global_reset_n (reset_n),         		 //  INPUT  FUWEI  he fpgA tongbu   IP核的全局异步复位信号，低电平有效。该信号有效时，将使得ALTMEMPHY（包括PLL）都进入复位状态。
	//.local_refresh_req(1'b0), 	
	//.local_self_rfsh_req(1'b0),
	.pll_ref_clk    ( local_clk_50m),      		 //控制器读写时钟，  PLL的输入参考时钟信号。
	.soft_reset_n   (1'h1),              		 //软件复位    IP核的全局异步复位信号，低电平有效。该信号只能复位ALTMEMPHY，而不能复位PLL。
	.local_ready    (local_ready),        		 //OUTPUT   状态表示位高表示可以进行读写，DDR2 IP核输出的当前读写请求已经被接收的指示信号，高电平有效
	.local_rdata    (local_rdata),        		 //OUTPUT   数据出口
	.local_rdata_valid(local_rdata_valid),   //OUTPUT  读出数据有没有效，local_rdata数据总线输出有效信号，高电平有效。
	.reset_request_n(),           			 //
	.mem_cs_n       (ddr2_cs_n),
	.mem_cke        (ddr2_cke),
	.mem_addr       (ddr2_addr),
	.mem_ba         (ddr2_ba),
	.mem_ras_n      (ddr2_ras_n),
	.mem_cas_n      (ddr2_cas_n),
	.mem_we_n       (ddr2_we_n),
	.mem_dm         (ddr2_dm),
	.local_refresh_ack(),                 		//INPUT
	//////////////////////////////////////////
	.local_burstbegin(local_burst), 
	//.local_burstbegin(local_read_req | local_write_req),   //INPUT ONE BITE，本地逻辑对DDR2 IP核的数据突发传输起始标志信号。多个数据传输时，该信号在 local_write_req或local_read_req信号拉高的第一个时钟周期时保持高电平，用于指示传输的起始。
	.local_init_done(local_init_done),   		//OUTPUT ，ALTMEMPHY完成DDR存储控制器的自动校准操作，拉高该信号。该信号可以作为用户逻辑的复位信号。
	.reset_phy_clk_n(),            				//
	.phy_clk(phy_clk),             				//外部逻辑时钟  output ALTMEMPHY产生供用户逻辑使用的半速率时钟信号。所有输入和输出到ALTMEMPHY的用户逻辑接口信号，都与此时钟同步。
	.aux_half_rate_clk(),						//phy_clk时钟信号的引出，时钟频率与phy_clk一样，可用于用户逻辑使用。
	.mem_clk(ddr2_clk),
	.mem_clk_n(ddr2_clk_n),
	.mem_dq(ddr2_dq),
	.mem_dqs(ddr2_dqs),
	.mem_odt(ddr2_odt)
	);
	
	
	
	
reg  local_clk_25m;
always @(posedge local_clk_50m or negedge reset_n)
  if(!reset_n)
  local_clk_25m <=0;
  else 
  local_clk_25m <= ~local_clk_25m;
  
  reg  local_clk_12m;
  always @(posedge local_clk_25m or negedge reset_n)
  if(!reset_n)
  local_clk_12m <=0;
  else 
  local_clk_12m <= ~local_clk_12m;
  

  

PLL	 PLL_inst (
	.areset ( ~reset_n ),
	.inclk0 ( local_clk_50m ),
	.c0     (clk_150m),
	.c1     ( clk_200m ),
	.c2     ( clk_100m ),
	.locked ( kk )
	);
	
endmodule
