`timescale 1ns/1ps

module final_working_test;
    parameter CLK_PERIOD = 10;
    parameter TEST_SIZE = 8;
    
    // Signals
    reg clk = 0, rst_n = 0;
    reg [31:0] instruction = 0;
    reg instruction_valid = 0;
    wire nmp_active, inter_flag, error_flag;
    wire [1:0] error_code;
    
    // Memory (using proper word addressing)
    reg [31:0] memory [0:65535]; // Larger memory for proper addressing
    
    // Test data
    reg [31:0] rs1_vals[0:7] = '{32'h10, 32'h11, 32'h12, 32'h13, 32'h14, 32'h15, 32'h16, 32'h17};
    reg [31:0] rs2_vals[0:7] = '{32'h20, 32'h21, 32'h22, 32'h23, 32'h24, 32'h25, 32'h26, 32'h27};
    reg [31:0] expected[0:7] = '{32'h30, 32'h32, 32'h34, 32'h36, 32'h38, 32'h3a, 32'h3c, 32'h3e};
    
    // AXI signals
    wire [31:0] axia_araddr, axib_araddr, axic_awaddr, axic_wdata;
    wire axia_arvalid, axib_arvalid, axic_awvalid, axic_wvalid;
    wire axia_rready, axib_rready, axic_bready;
    
    // Base addresses
    localparam RS1_BASE = 32'h00105000;
    localparam RS2_BASE = 32'h00106000;
    localparam RD_BASE  = 32'h00107000;
    
    // DUT
    nmp_unit_top #(
        .RS1_BASE_PTR_ADDR(32'h00100000),
        .RS2_BASE_PTR_ADDR(32'h00100004),
        .RD_BASE_PTR_ADDR(32'h00100008)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .instruction(instruction),
        .instruction_valid(instruction_valid),
        .nmp_active(nmp_active),
        .inter_flag(inter_flag),
        .error_flag(error_flag),
        .error_code(error_code),
        
        // Port A
        .axia_araddr(axia_araddr),
        .axia_arvalid(axia_arvalid),
        .axia_arready(1'b1),
        .axia_rdata(memory[axia_araddr[17:2]]),
        .axia_rresp(2'b00),
        .axia_rvalid(axia_arvalid),
        .axia_rready(axia_rready),
        
        // Port B
        .axib_araddr(axib_araddr),
        .axib_arvalid(axib_arvalid),
        .axib_arready(1'b1),
        .axib_rdata(memory[axib_araddr[17:2]]),
        .axib_rresp(2'b00),
        .axib_rvalid(axib_arvalid),
        .axib_rready(axib_rready),
        
        // Port C
        .axic_awaddr(axic_awaddr),
        .axic_awvalid(axic_awvalid),
        .axic_awready(1'b1),
        .axic_wdata(axic_wdata),
        .axic_wvalid(axic_wvalid),
        .axic_wready(1'b1),
        .axic_bresp(2'b00),
        .axic_bvalid(axic_wvalid),
        .axic_bready(axic_bready)
    );
    
    // Clock
    always #(CLK_PERIOD/2) clk = ~clk;
    
    // Memory write capture
    always @(posedge clk) begin
        if (axic_wvalid && axic_awvalid) begin
            memory[axic_awaddr[17:2]] <= axic_wdata;
        end
    end
    
    // Test
    initial begin
        $dumpfile("final_test.vcd");
        $dumpvars(0, final_working_test);
        
        // Initialize memory
        for (int i = 0; i < 65536; i++) memory[i] = 32'h0;
        
        // Store base address pointers
        memory[32'h00100000 >> 2] = RS1_BASE;
        memory[32'h00100004 >> 2] = RS2_BASE;
        memory[32'h00100008 >> 2] = RD_BASE;
        
        // Store test arrays
        for (int i = 0; i < TEST_SIZE; i++) begin
            memory[(RS1_BASE >> 2) + i] = rs1_vals[i];
            memory[(RS2_BASE >> 2) + i] = rs2_vals[i];
        end
        
        $display("\n========================================");
        $display("  NMP Unit - Working Test");
        $display("========================================\n");
        
        // Reset
        rst_n = 0;
        #50 rst_n = 1;
        #20;
        
        // Issue NMP_ADD
        instruction = {7'b0110000, 5'd8, 5'b00000, 3'b000, 5'b00000, 7'b0110011};
        $display("Issuing NMP_ADD instruction for %0d elements", TEST_SIZE);
        instruction_valid = 1;
        #10 instruction_valid = 0;
        
        // Wait for completion
        wait(inter_flag);
        $display("NMP operation completed!\n");
        #10;
        
        // Verify results
        $display("Verification Results:");
        $display("--------------------------------------");
        $display("Idx | RS1 | RS2 | Exp | Got | Status");
        $display("--------------------------------------");
        
        automatic integer pass_count = 0;
        automatic integer i;
        for (i = 0; i < TEST_SIZE; i++) begin
            automatic reg [31:0] result = memory[(RD_BASE >> 2) + i];
            if (result == expected[i]) begin
                $display(" %0d  | %02h  | %02h  | %02h  | %02h  | PASS",
                    i, rs1_vals[i], rs2_vals[i], expected[i], result);
                pass_count = pass_count + 1;
            end else begin
                $display(" %0d  | %02h  | %02h  | %02h  | %02h  | FAIL",
                    i, rs1_vals[i], rs2_vals[i], expected[i], result);
            end
        end
        $display("--------------------------------------");
        $display("Passed: %0d/%0d tests", pass_count, TEST_SIZE);
        
        if (error_flag) begin
            $display("\nError flag set: code = %0d", error_code);
        end
        
        $display("\n========================================");
        if (pass_count == TEST_SIZE) begin
            $display("     TEST PASSED!");
        end else begin
            $display("     TEST FAILED!");
        end
        $display("========================================\n");
        
        $finish;
    end

endmodule
