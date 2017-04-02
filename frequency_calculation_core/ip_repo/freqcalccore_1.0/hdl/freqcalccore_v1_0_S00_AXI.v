
`timescale 1 ns / 1 ps
`define DEBUG 0

	module freqcalccore_v1_0_S00_AXI #
	(
		// Users to add parameters here
		parameter integer FHT_B = 7,
        parameter integer FHT_N = 2 ** FHT_B,
                
        parameter IDLE = 3'b000,
        parameter PRELOAD = 3'b001,
        parameter PREMULT_1 = 3'b010,
        parameter PREMULT_2 = 3'b011,
        parameter ACCUMULATION = 3'b100,
        parameter SQUARING = 3'b101,
        parameter CONVERSION = 3'b110,
        parameter FIND_MAX = 3'b111,
       
        // User parameters ends
		// Do not modify the parameters beyond this line

		// Width of S_AXI data bus
		parameter integer C_S_AXI_DATA_WIDTH	= 32,
		// Width of S_AXI address bus
		parameter integer C_S_AXI_ADDR_WIDTH	= 4
	)
	(
		// Users to add ports here
    //    input wire [FHT_N * FHT_INPUT_WIDTH - 1: 0] RAW,
        input wire pdm_data,
        output wire pdm_clk,
        output wire pdm_lrsel, 

        output wire led0,
        output wire led1,
		// User ports ends
		// Do not modify the ports beyond this line

		// Global Clock Signal
		input wire  S_AXI_ACLK,
		// Global Reset Signal. This Signal is Active LOW
		input wire  S_AXI_ARESETN,
		// Write address (issued by master, acceped by Slave)
		input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
		// Write channel Protection type. This signal indicates the
    		// privilege and security level of the transaction, and whether
    		// the transaction is a data access or an instruction access.
		input wire [2 : 0] S_AXI_AWPROT,
		// Write address valid. This signal indicates that the master signaling
    		// valid write address and control information.
		input wire  S_AXI_AWVALID,
		// Write address ready. This signal indicates that the slave is ready
    		// to accept an address and associated control signals.
		output wire  S_AXI_AWREADY,
		// Write data (issued by master, acceped by Slave) 
		input wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
		// Write strobes. This signal indicates which byte lanes hold
    		// valid data. There is one write strobe bit for each eight
    		// bits of the write data bus.    
		input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
		// Write valid. This signal indicates that valid write
    		// data and strobes are available.
		input wire  S_AXI_WVALID,
		// Write ready. This signal indicates that the slave
    		// can accept the write data.
		output wire  S_AXI_WREADY,
		// Write response. This signal indicates the status
    		// of the write transaction.
		output wire [1 : 0] S_AXI_BRESP,
		// Write response valid. This signal indicates that the channel
    		// is signaling a valid write response.
		output wire  S_AXI_BVALID,
		// Response ready. This signal indicates that the master
    		// can accept a write response.
		input wire  S_AXI_BREADY,
		// Read address (issued by master, acceped by Slave)
		input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
		// Protection type. This signal indicates the privilege
    		// and security level of the transaction, and whether the
    		// transaction is a data access or an instruction access.
		input wire [2 : 0] S_AXI_ARPROT,
		// Read address valid. This signal indicates that the channel
    		// is signaling valid read address and control information.
		input wire  S_AXI_ARVALID,
		// Read address ready. This signal indicates that the slave is
    		// ready to accept an address and associated control signals.
		output wire  S_AXI_ARREADY,
		// Read data (issued by slave)
		output wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
		// Read response. This signal indicates the status of the
    		// read transfer.
		output wire [1 : 0] S_AXI_RRESP,
		// Read valid. This signal indicates that the channel is
    		// signaling the required read data.
		output wire  S_AXI_RVALID,
		// Read ready. This signal indicates that the master can
    		// accept the read data and response information.
		input wire  S_AXI_RREADY
	);

	// AXI4LITE signals
	reg [C_S_AXI_ADDR_WIDTH-1 : 0] 	axi_awaddr;
	reg  	axi_awready;
	reg  	axi_wready;
	reg [1 : 0] 	axi_bresp;
	reg  	axi_bvalid;
	reg [C_S_AXI_ADDR_WIDTH-1 : 0] 	axi_araddr;
	reg  	axi_arready;
	reg [C_S_AXI_DATA_WIDTH-1 : 0] 	axi_rdata;
	reg [1 : 0] 	axi_rresp;
	reg  	axi_rvalid;

	// Example-specific design signals
	// local parameter for addressing 32 bit / 64 bit C_S_AXI_DATA_WIDTH
	// ADDR_LSB is used for addressing 32/64 bit registers/memories
	// ADDR_LSB = 2 for 32 bits (n downto 2)
	// ADDR_LSB = 3 for 64 bits (n downto 3)
	localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH/32) + 1;
	localparam integer OPT_MEM_ADDR_BITS = 1;
	//----------------------------------------------
	//-- Signals for user logic register space example
	//------------------------------------------------
	//-- Number of Slave Registers 4
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg0;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg1;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg2;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg3;
	wire	 slv_reg_rden;
	wire	 slv_reg_wren;
	reg [C_S_AXI_DATA_WIDTH-1:0]	 reg_data_out;
	integer	 byte_index;
	
	// User registers and wires
	reg signed [31 : 0] PDM_ACCUMULATOR;
	reg [7 : 0] FIFO_HEAD;
	reg [31 : 0] FIFO_COUNTER;
	reg [15 : 0] PDM_COUNTER;
    wire fifo_wen;
    wire fifo_shift;
    wire [7 : 0] fifo_waddr;
    wire [7 : 0] fifo_raddr;
    wire signed [15 : 0] fifo_wdata;
    wire signed [15 : 0] fifo_rdata1;
    wire signed [15 : 0] fifo_rdata2;

	reg [7 : 0] PRELOAD_COUNTER;
	wire preloading;
	wire preload_done;
    wire xraw_wen;
    wire xraw_shift;
    wire [7 : 0] xraw_addr1;
    wire [7 : 0] xraw_addr2;
    wire signed [15 : 0] xraw_wdata;
    wire signed [15 : 0] xraw_rdata1;
    wire signed [15 : 0] xraw_rdata2;

    wire a_wen1;
    wire a_wen2;
    wire [7 : 0] a_addr1;
    wire [7 : 0] a_addr2;
    wire signed [15 : 0] a_wdata1;
    wire signed [15 : 0] a_wdata2;
    wire signed [15 : 0] a_rdata1;
    wire signed [15 : 0] a_rdata2;
    reg [31 : 0] ACCUM_COUNTER;
    wire [31 : 0] ACCUM_LAG;
    reg signed [31 : 0] premult1a;
    reg signed [31 : 0] premult1b;
    reg signed [15 : 0] premult2a;
    reg signed [15 : 0] premult2b;
    wire [7 : 0] row;
    wire [7 : 0] row1;
    wire [7 : 0] col;
    wire a_write;

    reg [15 : 0] SQUARE_COUNTER;
    wire square;
    wire squaring_done;
    wire s_wen1;
    wire s_wen2;
    wire [15 : 0] s_addr1;
    wire [15 : 0] s_addr2;
    wire signed [31 : 0] s_wdata1;
    wire signed [31 : 0] s_wdata2;
    wire signed [31 : 0] s_rdata1;
    wire signed [31 : 0] s_rdata2;

    reg [15 : 0] CONVERT_COUNTER;
    reg [15 : 0] CONVERT_FORWARD;
    reg [15 : 0] CONVERT_BACKWARD;
    wire converting;
    wire conversion_done;
    wire [15 : 0] c_foward;
    wire [15 : 0] c_backward;
    wire c_wen1;
    wire [15 : 0] c_addr1;
    wire [15 : 0] c_addr2;
    wire signed [31 : 0] c_wdata1;
    wire signed [31 : 0] c_rdata1;
    wire signed [31 : 0] c_rdata2;

	/*reg [15 : 0] COL_COUNTER;
	reg [15 : 0] ROW_COUNTER;
	wire [15 : 0] row_lag_2;
	wire [15 : 0] row_lag_1;
	reg signed [31 : 0] ACCUMULATOR[FHT_N - 1 : 0];*/

	wire [13 : 0] lut_addr1;
	wire [13 : 0] lut_addr2;
	wire signed [15 : 0] lut_rdata1;
	wire signed [15 : 0] lut_rdata2;

    /*initial begin
       $readmemh("c:/Users/Jianwei/Desktop/ECE532/fft/FHT_TEST_VALUES.txt", X_RAW);   
    end*/

	reg [15 : 0] FIND_MAX_COUNTER;
	wire finding_max;
	reg signed [31 : 0] MAXIMUM_AMPL;
	reg [31 : 0] MAXIMUM_FREQ;

	integer i;
	
	reg [2:0] Y_D, Y_Q; 
	
    wire start;
    wire count_reached;
    wire row_done;
    wire busy;
    wire accum_done;
	// End user registers and wires

	/********************************************************************************************


									AXI LOGIC SECTION


	********************************************************************************************/								

	// I/O Connections assignments
	assign S_AXI_AWREADY	= axi_awready;
	assign S_AXI_WREADY	= axi_wready;
	assign S_AXI_BRESP	= axi_bresp;
	assign S_AXI_BVALID	= axi_bvalid;
	assign S_AXI_ARREADY	= axi_arready;
	assign S_AXI_RDATA	= axi_rdata;
	assign S_AXI_RRESP	= axi_rresp;
	assign S_AXI_RVALID	= axi_rvalid;
	// Implement axi_awready generation
	// axi_awready is asserted for one S_AXI_ACLK clock cycle when both
	// S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_awready is
	// de-asserted when reset is low.

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_awready <= 1'b0;
	    end 
	  else
	    begin    
	      if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID)
	        begin
	          // slave is ready to accept write address when 
	          // there is a valid write address and write data
	          // on the write address and data bus. This design 
	          // expects no outstanding transactions. 
	          axi_awready <= 1'b1;
	        end
	      else           
	        begin
	          axi_awready <= 1'b0;
	        end
	    end 
	end       

	// Implement axi_awaddr latching
	// This process is used to latch the address when both 
	// S_AXI_AWVALID and S_AXI_WVALID are valid. 

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_awaddr <= 0;
	    end 
	  else
	    begin    
	      if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID)
	        begin
	          // Write Address latching 
	          axi_awaddr <= S_AXI_AWADDR;
	        end
	    end 
	end       

	// Implement axi_wready generation
	// axi_wready is asserted for one S_AXI_ACLK clock cycle when both
	// S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_wready is 
	// de-asserted when reset is low. 

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_wready <= 1'b0;
	    end 
	  else
	    begin    
	      if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID)
	        begin
	          // slave is ready to accept write data when 
	          // there is a valid write address and write data
	          // on the write address and data bus. This design 
	          // expects no outstanding transactions. 
	          axi_wready <= 1'b1;
	        end
	      else
	        begin
	          axi_wready <= 1'b0;
	        end
	    end 
	end       

	// Implement memory mapped register select and write logic generation
	// The write data is accepted and written to memory mapped registers when
	// axi_awready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted. Write strobes are used to
	// select byte enables of slave registers while writing.
	// These registers are cleared when reset (active low) is applied.
	// Slave register write enable is asserted when valid address and data are available
	// and the slave is ready to accept the write address and write data.
	assign slv_reg_wren = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID;

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      slv_reg0 <= 0;
	      slv_reg1 <= 0;
	      slv_reg2 <= 0;
	      slv_reg3 <= 0;
	    end 
	  else begin
	    if (slv_reg_wren)
	      begin
	        case ( axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] )
	          2'h0:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 0
	                // Busy register is unwritable
	                //slv_reg0[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          2'h1:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 1
	                // Frequency register is unwritable
	                //slv_reg1[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          2'h2:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 2
	                // Amplitude register is unwritable
	                //slv_reg2[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          2'h3:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              // Start can only be asserted if busy is not set
	              if ( S_AXI_WSTRB[byte_index] == 1 && ~busy) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 3
	                slv_reg3[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          default : begin
	                      slv_reg0 <= slv_reg0;
	                      slv_reg1 <= slv_reg1;
	                      slv_reg2 <= slv_reg2;
	                      slv_reg3 <= slv_reg3;
	                    end
	        endcase
	      end
	    //Otherwise if not writing to the registers
	    else 
	       begin
	           //Busy
	           slv_reg0 <= {slv_reg0[15:1], busy};
	           //Start register
	           slv_reg3 <= 0;
	           if((Y_Q == FIND_MAX) && found_max)
	               begin
	                   slv_reg1 <= MAXIMUM_FREQ * 8;
	                   slv_reg2 <= MAXIMUM_AMPL;
	               end
	       end
	  end
	end    

	// Implement write response logic generation
	// The write response and response valid signals are asserted by the slave 
	// when axi_wready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted.  
	// This marks the acceptance of address and indicates the status of 
	// write transaction.

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_bvalid  <= 0;
	      axi_bresp   <= 2'b0;
	    end 
	  else
	    begin    
	      if (axi_awready && S_AXI_AWVALID && ~axi_bvalid && axi_wready && S_AXI_WVALID)
	        begin
	          // indicates a valid write response is available
	          axi_bvalid <= 1'b1;
	          axi_bresp  <= 2'b0; // 'OKAY' response 
	        end                   // work error responses in future
	      else
	        begin
	          if (S_AXI_BREADY && axi_bvalid) 
	            //check if bready is asserted while bvalid is high) 
	            //(there is a possibility that bready is always asserted high)   
	            begin
	              axi_bvalid <= 1'b0; 
	            end  
	        end
	    end
	end   

	// Implement axi_arready generation
	// axi_arready is asserted for one S_AXI_ACLK clock cycle when
	// S_AXI_ARVALID is asserted. axi_awready is 
	// de-asserted when reset (active low) is asserted. 
	// The read address is also latched when S_AXI_ARVALID is 
	// asserted. axi_araddr is reset to zero on reset assertion.

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_arready <= 1'b0;
	      axi_araddr  <= 32'b0;
	    end 
	  else
	    begin    
	      if (~axi_arready && S_AXI_ARVALID)
	        begin
	          // indicates that the slave has acceped the valid read address
	          axi_arready <= 1'b1;
	          // Read address latching
	          axi_araddr  <= S_AXI_ARADDR;
	        end
	      else
	        begin
	          axi_arready <= 1'b0;
	        end
	    end 
	end       

	// Implement axi_arvalid generation
	// axi_rvalid is asserted for one S_AXI_ACLK clock cycle when both 
	// S_AXI_ARVALID and axi_arready are asserted. The slave registers 
	// data are available on the axi_rdata bus at this instance. The 
	// assertion of axi_rvalid marks the validity of read data on the 
	// bus and axi_rresp indicates the status of read transaction.axi_rvalid 
	// is deasserted on reset (active low). axi_rresp and axi_rdata are 
	// cleared to zero on reset (active low).  
	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_rvalid <= 0;
	      axi_rresp  <= 0;
	    end 
	  else
	    begin    
	      if (axi_arready && S_AXI_ARVALID && ~axi_rvalid)
	        begin
	          // Valid read data is available at the read data bus
	          axi_rvalid <= 1'b1;
	          axi_rresp  <= 2'b0; // 'OKAY' response
	        end   
	      else if (axi_rvalid && S_AXI_RREADY)
	        begin
	          // Read data is accepted by the master
	          axi_rvalid <= 1'b0;
	        end                
	    end
	end    

	// Implement memory mapped register select and read logic generation
	// Slave register read enable is asserted when valid address is available
	// and the slave is ready to accept the read address.
	assign slv_reg_rden = axi_arready & S_AXI_ARVALID & ~axi_rvalid;
	always @(*)
	begin
	      // Address decoding for reading registers
	      case ( axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] )
	        2'h0   : reg_data_out <= slv_reg0;
	        2'h1   : reg_data_out <= slv_reg1;
	        2'h2   : reg_data_out <= slv_reg2;
	        2'h3   : reg_data_out <= slv_reg3;
	        default : reg_data_out <= 0;
	      endcase
	end

	// Output register or memory read data
	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_rdata  <= 0;
	    end 
	  else
	    begin    
	      // When there is a valid read address (S_AXI_ARVALID) with 
	      // acceptance of read address by the slave (axi_arready), 
	      // output the read dada 
	      if (slv_reg_rden)
	        begin
	          axi_rdata <= reg_data_out;     // register read data
	        end   
	    end
	end    

	/********************************************************************************************


									FHT LOGIC SECTION


	********************************************************************************************/		
	// Add user logic here
	assign led0 = pdm_clk;
	assign led1 = pdm_data;

	// Block for the PDM clocks
    always @(posedge S_AXI_ACLK) begin
    	if(S_AXI_ARESETN == 0) begin
    		PDM_COUNTER <= 0;
    	end else if(PDM_COUNTER == 31) begin
    		PDM_ACCUMULATOR <= fifo_shift ? 0 : PDM_ACCUMULATOR + pdm_data;
    		PDM_COUNTER <= 0;
    	end else begin
    		PDM_COUNTER <= PDM_COUNTER + 1;
    	end
    end
    // Assign microphone outputs
    assign pdm_clk = (PDM_COUNTER < 16);
	assign pdm_lrsel = 1'b0;

	// FIFO memory
    FIFO_MEM FIFO(
    	.clk(S_AXI_ACLK),
    	.wen(fifo_wen),
    	.waddr(fifo_waddr),
    	.raddr(fifo_raddr),
    	.wdata(fifo_wdata),
    	.rdata1(fifo_rdata1),
    	.rdata2(fifo_rdata2)
    	);

    assign fifo_shift = (FIFO_COUNTER == 97663);
    assign fifo_wen = fifo_shift;
    assign fifo_waddr = FIFO_HEAD;
    assign fifo_wdata = PDM_ACCUMULATOR;
    // Updating the FIFO
    always @(posedge S_AXI_ACLK) begin
    	if(S_AXI_ARESETN == 0) begin
    		FIFO_HEAD <= 0;
			FIFO_COUNTER <= 0;
		end else if(fifo_shift) begin  //Condition for updating the head of the FIFO
			FIFO_HEAD <= (FIFO_HEAD + 1) % 128;
			FIFO_COUNTER <= 0;
		end else begin
			FIFO_COUNTER <= FIFO_COUNTER + 1;
		end
    end
	
	// Updating the preload counter	
	always @(posedge S_AXI_ACLK) begin
    	if((S_AXI_ARESETN == 0) || start || preload_done) begin
    		PRELOAD_COUNTER <= 0;
    	end else begin
    		PRELOAD_COUNTER <= PRELOAD_COUNTER + 1;
    	end
    end

    assign preloading = (Y_Q == PRELOAD);
    assign preload_done =  preloading & (PRELOAD_COUNTER == 127);
    assign xraw_wen = (~`DEBUG) & preloading;
    assign xraw_addr1 = PRELOAD_COUNTER;
    assign fifo_raddr = (FIFO_HEAD + PRELOAD_COUNTER) % 128;
    assign xraw_wdata = fifo_rdata2;

    DATA_MEM X_RAW(
    	.clk(S_AXI_ACLK),
    	.wen1(xraw_wen),
    	.wen2(1'b0),
    	.addr1(xraw_addr1),
    	.addr2(xraw_addr2),
    	.wdata1(xraw_wdata),
    	.wdata2(16'h0000),
    	.rdata1(xraw_rdata1),
    	.rdata2(xraw_rdata2)
    	);





     
    // Control FSM
    assign start = (slv_reg3 != 0); //Cannot start if an operation is happening
    always @(start, preload_done, accum_done, squaring_done, conversion_done, found_max, Y_Q)
        begin
            case(Y_Q)
                IDLE: if(start) Y_D = PRELOAD;
                        else Y_D = IDLE;
                PRELOAD: if(preload_done) Y_D = PREMULT_1;
                		else Y_D = PRELOAD;
               	PREMULT_1: Y_D = PREMULT_2;  // two clock cycle delays for pipeline registers to fill up

               	PREMULT_2: Y_D = ACCUMULATION;

                ACCUMULATION: if(accum_done) Y_D = SQUARING;
                        else Y_D = ACCUMULATION;
                SQUARING: if(squaring_done) Y_D = CONVERSION;
                		else Y_D = SQUARING;
                CONVERSION: if(conversion_done) Y_D = FIND_MAX;
                		else Y_D = CONVERSION;
                FIND_MAX: if(found_max) Y_D = IDLE;
                        else Y_D = FIND_MAX;
                default: Y_D = IDLE;
            endcase
        end
    always @(posedge S_AXI_ACLK)
        begin
            if(S_AXI_ARESETN == 0) Y_Q <= IDLE;
            else Y_Q <= Y_D;
        end
    // FSM OUTPUTS
    assign busy = (Y_Q != IDLE);


    LOOKUP_TABLE LUT(
    	.clk(S_AXI_ACLK),
    	.wen1(1'b0),
    	.wen2(1'b0),
    	.addr1(lut_addr1),
    	.addr2(lut_addr2),
    	.wdata1(16'h0000),
    	.wdata2(16'h0000),
    	.rdata1(lut_rdata1),
    	.rdata2(lut_rdata2)
    	);

    DATA_MEM ACCUMULATOR(
    	.clk(S_AXI_ACLK),
    	.wen1(a_wen1),
    	.wen2(a_wen2),
    	.addr1(a_addr1),
    	.addr2(a_addr2),
    	.wdata1(a_wdata1),
    	.wdata2(a_wdata2),
    	.rdata1(a_rdata1),
    	.rdata2(a_rdata2)
    	);

    assign accumulating = (Y_Q == ACCUMULATION);

	always @(posedge S_AXI_ACLK) begin
    	if((S_AXI_ARESETN == 0) || preload_done) begin
    		ACCUM_COUNTER <= 0;
    	end else begin
    		ACCUM_COUNTER <= ACCUM_COUNTER + 1;
    	end
    end
    assign a_write = accumulating & ACCUM_LAG[0];
    assign ACCUM_LAG = ACCUM_COUNTER - 2;
    assign row = {1'b0, ACCUM_LAG[6 : 1], 1'b0};
    assign row1 = {1'b0, ACCUM_LAG[6 : 1], 1'b1};
    assign col = {1'b0, ACCUM_COUNTER[13 : 7]};

    assign lut_addr1 = {ACCUM_COUNTER[13 : 1], 1'b0};
    assign lut_addr2 = {ACCUM_COUNTER[13 : 1], 1'b1};
    assign xraw_addr2 = col;

    assign a_addr1 = preloading ? PRELOAD_COUNTER : square ? {SQUARE_COUNTER[7 : 1], 1'b0} : row;
    assign a_wdata1 = preloading ? 0 : a_rdata1 + premult2a;
    assign a_wen1 = preloading | a_write;

	assign a_addr2 = square ? {SQUARE_COUNTER[7 : 1], 1'b1} : row1;
    assign a_wdata2 = a_rdata2 + premult2b;
    assign a_wen2 = a_write;

    always @(posedge S_AXI_ACLK) begin
    	if(S_AXI_ARESETN == 0) begin
    		premult1a <= 0;
    		premult1b <= 0;
    	end else begin
    		premult1a <= (lut_rdata1 * xraw_rdata2);
    		premult1b <= (lut_rdata2 * xraw_rdata2);
    		premult2a <= premult1a / (2 ** 16);
    		premult2b <= premult1b / (2 ** 16);
    	end
    end

    assign accum_done = accumulating & (ACCUM_LAG == 16383);


    LARGE_DATA_MEM SQUARER(
		.clk(S_AXI_ACLK),
		.wen1(s_wen1),
		.wen2(s_wen2),
		.addr1(s_addr1),
		.addr2(s_addr2),
		.wdata1(s_wdata1),
		.wdata2(s_wdata2),
		.rdata1(s_rdata1),
		.rdata2(s_rdata2)
		);
    always @(posedge S_AXI_ACLK) begin
    	if((S_AXI_ARESETN == 0) || accum_done) begin
    		SQUARE_COUNTER <= 0;
    	end else begin
    		SQUARE_COUNTER <= SQUARE_COUNTER + 1;
    	end
    end
	assign square = (Y_Q == SQUARING);

    assign s_addr1 = square ? {SQUARE_COUNTER[15 : 1], 1'b0} : c_foward; 
    assign s_wdata1 = a_rdata1 ** 2;
    assign s_wen1 = square & SQUARE_COUNTER[0];

    assign s_addr2 = square ? {SQUARE_COUNTER[15 : 1], 1'b1} : c_backward; 
    assign s_wdata2 = a_rdata2 ** 2;
    assign s_wen2 = square & SQUARE_COUNTER[0];

    assign squaring_done = square & (SQUARE_COUNTER == 127);

	LARGE_DATA_MEM CONVERTER(
		.clk(S_AXI_ACLK),
		.wen1(c_wen1),
		.wen2(1'b0),
		.addr1(c_addr1),
		.addr2(c_addr2),
		.wdata1(c_wdata1),
		.wdata2(32'h00000000),
		.rdata1(c_rdata1),
		.rdata2(c_rdata2)
		);

	always @(posedge S_AXI_ACLK) begin
    	if((S_AXI_ARESETN == 0) || squaring_done) begin
    		CONVERT_COUNTER <= 0;
    		CONVERT_FORWARD <= 0;
    		CONVERT_BACKWARD <= 255;
    	end else begin
    		CONVERT_COUNTER <= CONVERT_COUNTER + 1;
    		CONVERT_FORWARD <= CONVERT_FORWARD + 1;
    		CONVERT_BACKWARD <= CONVERT_BACKWARD - 1;
    	end
    end
    assign converting = (Y_Q == CONVERSION);

    assign c_foward = {1'b0, CONVERT_FORWARD[15 : 1]};
    assign c_backward = {1'b0, CONVERT_BACKWARD[15 : 1]};

    assign c_addr1 = {1'b0, CONVERT_COUNTER[15 : 1]}; 
    assign c_wdata1 = s_rdata1 + s_rdata2;
    assign c_wen1 = converting & CONVERT_COUNTER[0];

    assign conversion_done = converting & (CONVERT_COUNTER == 255);




    always @(posedge S_AXI_ACLK) begin
    	if((S_AXI_ARESETN == 0) || conversion_done) begin
    		FIND_MAX_COUNTER <= 16;
    	end else begin
    		FIND_MAX_COUNTER <= FIND_MAX_COUNTER + 1;
    	end
    end

    assign c_addr2 = {1'b0, FIND_MAX_COUNTER[15 : 1]};
    assign finding_max = (Y_Q == FIND_MAX);

    always @(posedge S_AXI_ACLK) begin
	    if((S_AXI_ARESETN == 0) || start) begin
	        MAXIMUM_AMPL <= 0;
	        MAXIMUM_FREQ <= 0;
	    end else if(finding_max & FIND_MAX_COUNTER[0]) begin
            MAXIMUM_AMPL <= (c_rdata2 > MAXIMUM_AMPL) ? c_rdata2 : MAXIMUM_AMPL;
            MAXIMUM_FREQ <= (c_rdata2 > MAXIMUM_AMPL) ? c_addr2 : MAXIMUM_FREQ;
	    end
    end

	assign found_max = (FIND_MAX_COUNTER == 127);



  // User logic ends

	endmodule

module LOOKUP_TABLE (
	input clk,
	input wen1,
	input wen2,
	input wire [13 : 0] addr1,
	input wire [13 : 0] addr2,
	input wire [15 : 0] wdata1,
	input wire [15 : 0] wdata2,
	output reg signed [15 : 0] rdata1,
	output reg signed [15 : 0] rdata2
	);
	// Declaring the ram
	reg signed [15:0] ram[16383 : 0];
	// Instantiating the ram
	initial begin
		$readmemh("c:/Users/Jianwei/Desktop/ECE532/fft/FHT_LUT_VALUES.txt", ram); 
	end
	// Port 1
	always@(posedge clk) begin
		if(wen1) ram[addr1] <= wdata1;
		rdata1 <= ram[addr1];
	end
	// Port 2
	always@(posedge clk) begin
		if(wen2) ram[addr2] <= wdata2;
		rdata2 <= ram[addr2];
	end
endmodule

module LARGE_DATA_MEM(
	input clk,
	input wen1,
	input wen2,
	input wire [15 : 0] addr1,
	input wire [15 : 0] addr2,
	input wire [31 : 0] wdata1,
	input wire [31 : 0] wdata2,
	output reg signed [31 : 0] rdata1,
	output reg signed [31 : 0] rdata2
	);
	// Declaring the ram
	reg signed [31:0] ram[127 : 0];

	// Port 1
	always@(posedge clk) begin
		if(wen1) ram[addr1] <= wdata1;
		rdata1 <= ram[addr1];
	end
	// Port 2
	always@(posedge clk) begin
		if(wen2) ram[addr2] <= wdata2;
		rdata2 <= ram[addr2];
	end
endmodule

module DATA_MEM(
	input clk,
	input wen1,
	input wen2,
	input wire [7 : 0] addr1,
	input wire [7 : 0] addr2,
	input wire signed [15 : 0] wdata1,
	input wire signed [15 : 0] wdata2,
	output reg signed [15 : 0] rdata1,
	output reg signed [15 : 0] rdata2
	);
	reg signed [15 : 0] ram [127 : 0];
	initial begin
		if(`DEBUG) begin
			$readmemh("c:/Users/Jianwei/Desktop/ECE532/fft/FHT_TEST_VALUES.txt", ram); 
		end else begin
			$readmemh("c:/Users/Jianwei/Desktop/ECE532/fft/ZERO_VALUES.txt", ram);
		end
	end
	// Port 1
	always@(posedge clk) begin
		if(wen1) ram[addr1] <= wdata1;
		rdata1 <= ram[addr1];
	end
	// Port 2
	always@(posedge clk) begin
		if(wen2) ram[addr2] <= wdata2;
		rdata2 <= ram[addr2];
	end
endmodule		

module FIFO_MEM(
	input clk,
	input wen,
	input wire [7 : 0] raddr,
	input wire [7 : 0] waddr,
	input wire signed [15 : 0] wdata,
	output wire signed [15 : 0] rdata1,
	output wire signed [15 : 0] rdata2
	);
	reg signed [15 : 0] ram [127 : 0];
	initial begin
		if(`DEBUG) begin
			$readmemh("c:/Users/Jianwei/Desktop/ECE532/fft/FHT_TEST_VALUES.txt", ram); 
		end else begin
			$readmemh("c:/Users/Jianwei/Desktop/ECE532/fft/ZERO_VALUES.txt", ram);
		end
	end
	// Write ports
	always@(posedge clk) begin
		if(wen) ram[waddr] <= wdata;
	end
	//Read ports
	assign rdata1 = ram[waddr];
	assign rdata2 = ram[raddr];
endmodule