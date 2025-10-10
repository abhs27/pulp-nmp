`timescale 1ns/1ps

module nmp_debug_mem;
    reg clk = 0;
    reg rst_n = 0;
    reg [31:0] instruction = 0;
    reg instruction_valid = 0;
    wire inter_flag;
    
    // Single memory array
    reg [31:0] mem [0:65535];
    
    // AXI signals
    wire [31:0] axi_araddr, axi_awaddr, axi_wdata;
    wire axi_arvalid, axi_awvalid, axi_wvalid;
    
    nmp_unit_top dut(
        .clk(clk), .rst_n(rst_n),
        .instruction(instruction),
        .instruction_valid(instruction_valid),
        .nmp_active(), .inter_flag(inter_flag),
        .error_flag(), .error_code(),
        
        // Simple AXI connections for all ports
        .axia_araddr(axi_araddr), .axia_arvalid(axi_arvalid),
        .axia_arready(1'b1), .axia_rdata(mem[axi_araddr[17:2]]),
        .axia_rresp(2'b00), .axia_rvalid(axi_arvalid), .axia_rready(),
        
        .axib_araddr(), .axib_arvalid(),
        .axib_arready(1'b1), .axib_rdata(mem[axi_araddr[17:2] + 32'h400]),
        .axib_rresp(2'b00), .axib_rvalid(1'b1), .axib_rready(),
        
        .axic_awaddr(axi_awaddr), .axic_awvalid(axi_awvalid),
        .axic_awready(1'b1), .axic_wdata(axi_wdata),
        .axic_wvalid(axi_wvalid), .axic_wready(1'b1),
        .axic_bresp(2'b00), .axic_bvalid(axi_wvalid), .axic_bready()
    );
    
    always #5 clk = ~clk;
    
    // Initialize memory BEFORE simulation starts
    initial begin : mem_init
        integer i;
        
        // Clear memory
        for(i = 0; i < 65536; i=i+1) mem[i] = 0;
        
        // Set base pointers
        mem[32'h4000] = 32'h00105000; // RS1 base at 0x100000
        mem[32'h4001] = 32'h00106000; // RS2 base at 0x100004  
        mem[32'h4002] = 32'h00107000; // RD base at 0x100008
        
        // Set test data
        mem[32'h4140] = 32'h10; // RS1[0] at 0x105000
        mem[32'h4141] = 32'h11; // RS1[1]
        mem[32'h4540] = 32'h20; // RS2[0] at 0x105000 + 0x400 offset
        mem[32'h4541] = 32'h21; // RS2[1]
        
        #1; // Small delay to ensure memory is set
        
        $display("Memory initialized at time %0t", $time);
        $display("mem[0x4000]=%h (should be 0x105000)", mem[32'h4000]);
        $display("mem[0x4140]=%h (should be 0x10)", mem[32'h4140]);
    end
    
    initial begin : test_sequence
        #10; // Wait for memory init
        
        rst_n = 0;
        #20 rst_n = 1;
        #10;
        
        // Issue instruction for 2 elements
        instruction = {7'b0110000, 5'd2, 5'b00000, 3'b000, 5'b00000, 7'b0110011};
        instruction_valid = 1;
        #10 instruction_valid = 0;
        
        // Monitor reads
        @(posedge clk);
        forever @(posedge clk) begin
            if(axi_arvalid) 
                $display("Read addr=0x%h, data=0x%h", axi_araddr, mem[axi_araddr[17:2]]);
            if(axi_wvalid)
                $display("Write addr=0x%h, data=0x%h", axi_awaddr, axi_wdata);
            if(inter_flag) begin
                $display("Done!");
                #10 $finish;
            end
        end
    end
    
    initial begin
        #1000;
        $display("Timeout!");
        $finish;
    end
endmodule
