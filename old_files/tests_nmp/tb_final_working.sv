`timescale 1ns / 1ps

module tb_final_working;

    parameter CLK_PERIOD = 10;
    
    reg         clk, rst_n;
    reg  [31:0] instruction;
    reg         instruction_valid;
    wire        nmp_active, inter_flag, hash_error;
    
    reg         alt_write_enable;
    reg  [16:0] alt_write_hash_index;
    reg  [31:0] alt_write_rs1_base, alt_write_rs2_base, alt_write_rd_base;
    
    wire [31:0] axia_araddr, axib_araddr, axic_awaddr;
    wire        axia_arvalid, axib_arvalid, axic_awvalid;
    wire        axia_rready, axib_rready, axic_bready;
    wire [31:0] axic_wdata;
    wire        axic_wvalid;
    
    reg         axia_arready, axib_arready, axic_awready, axic_wready;
    reg  [31:0] axia_rdata, axib_rdata;
    reg  [1:0]  axia_rresp, axib_rresp, axic_bresp;
    reg         axia_rvalid, axib_rvalid, axic_bvalid;
    
    reg [31:0] memory [0:4095];
    integer cycle_count;
    integer test_count, pass_count, fail_count;
    
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    nmp_top_hash #(
        .RS1_BASE_PTR_ADDR(32'h00100000),
        .RS2_BASE_PTR_ADDR(32'h00100004),
        .RD_BASE_PTR_ADDR(32'h00100008),
        .HASH_MODE_ENABLE(1'b1)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .instruction(instruction), .instruction_valid(instruction_valid),
        .nmp_active(nmp_active), .inter_flag(inter_flag),
        .error_flag(), .error_code(), .hash_error(hash_error),
        .alt_write_enable(alt_write_enable), .alt_write_hash_index(alt_write_hash_index),
        .alt_write_rs1_base(alt_write_rs1_base), .alt_write_rs2_base(alt_write_rs2_base), .alt_write_rd_base(alt_write_rd_base),
        .axia_araddr(axia_araddr), .axia_arvalid(axia_arvalid), .axia_arready(axia_arready),
        .axia_rdata(axia_rdata), .axia_rresp(axia_rresp), .axia_rvalid(axia_rvalid), .axia_rready(axia_rready),
        .axib_araddr(axib_araddr), .axib_arvalid(axib_arvalid), .axib_arready(axib_arready),
        .axib_rdata(axib_rdata), .axib_rresp(axib_rresp), .axib_rvalid(axib_rvalid), .axib_rready(axib_rready),
        .axic_awaddr(axic_awaddr), .axic_awvalid(axic_awvalid), .axic_awready(axic_awready),
        .axic_wdata(axic_wdata), .axic_wvalid(axic_wvalid), .axic_wready(axic_wready),
        .axic_bresp(axic_bresp), .axic_bvalid(axic_bvalid), .axic_bready(axic_bready)
    );
    
    // AXI Slave
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            axia_arready <= 1'b1;
            axib_arready <= 1'b1;
            axic_awready <= 1'b1;
            axic_wready  <= 1'b1;
        end
    end
    
    // AXI responder
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            axia_rvalid <= 1'b0;
            axib_rvalid <= 1'b0;
            axic_bvalid <= 1'b0;
            axia_rdata  <= 32'h0;
            axib_rdata  <= 32'h0;
        end else begin
            if (axia_arvalid && axia_arready && !axia_rvalid) begin
                axia_rdata  <= memory[axia_araddr >> 2];
                axia_rvalid <= 1'b1;
                axia_rresp  <= 2'b00;
            end else if (axia_rvalid && axia_rready) begin
                axia_rvalid <= 1'b0;
            end
            
            if (axib_arvalid && axib_arready && !axib_rvalid) begin
                axib_rdata  <= memory[axib_araddr >> 2];
                axib_rvalid <= 1'b1;
                axib_rresp  <= 2'b00;
            end else if (axib_rvalid && axib_rready) begin
                axib_rvalid <= 1'b0;
            end
            
            if (axic_awvalid && axic_awready && axic_wvalid && axic_wready && !axic_bvalid) begin
                memory[axic_awaddr >> 2] <= axic_wdata;
                axic_bvalid <= 1'b1;
                axic_bresp  <= 2'b00;
            end else if (axic_bvalid && axic_bready) begin
                axic_bvalid <= 1'b0;
            end
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cycle_count <= 0;
        else if (nmp_active)
            cycle_count <= cycle_count + 1;
    end
    
    task run_test;
        input [127:0] test_name;
        input [16:0] hash;
        input [4:0] size;
        input [31:0] rs1_base, rs2_base, rd_base;
        input [31:0] rs1_pattern, rs2_pattern;
        integer i, errors;
        reg [31:0] expected, actual;
        begin
            test_count = test_count + 1;
            
            // Clear memory
            for (i = 0; i < 4096; i = i + 1) memory[i] = 32'h0;
            
            // Initialize arrays
            for (i = 0; i < size; i = i + 1) begin
                memory[(rs1_base >> 2) + i] = rs1_pattern + i;
                memory[(rs2_base >> 2) + i] = rs2_pattern + i;
            end
            
            // Wait for idle (nmp_active must be low)
            @(posedge clk);
            while (nmp_active) @(posedge clk);
            repeat(5) @(posedge clk);
            
            // Write hash
            @(posedge clk);
            alt_write_enable = 1;
            alt_write_hash_index = hash;
            alt_write_rs1_base = rs1_base;
            alt_write_rs2_base = rs2_base;
            alt_write_rd_base  = rd_base;
            @(posedge clk);
            alt_write_enable = 0;
            repeat(3) @(posedge clk);
            
            // Execute
            cycle_count = 0;
            instruction = {hash, 1'b1, 2'b00, size, 7'h6b};
            @(posedge clk);
            instruction_valid = 1;
            @(posedge clk);
            instruction_valid = 0;
            
            // Wait for nmp_active to go high
            @(posedge clk);
            while (!nmp_active && cycle_count < 10) @(posedge clk);
            
            // Now wait for completion (nmp_active goes low and inter_flag goes high)
            while (nmp_active && cycle_count < 500) @(posedge clk);
            
            repeat(3) @(posedge clk);
            
            // Verify
            if (inter_flag && cycle_count < 500) begin
                errors = 0;
                for (i = 0; i < size; i = i + 1) begin
                    expected = (rs1_pattern + i) + (rs2_pattern + i);
                    actual = memory[(rd_base >> 2) + i];
                    if (actual !== expected) errors = errors + 1;
                end
                
                if (errors == 0) begin
                    $display("  ✓ %s (size=%0d, cycles=%0d)", test_name, size, cycle_count);
                    pass_count = pass_count + 1;
                end else begin
                    $display("  ✗ %s (%0d errors)", test_name, errors);
                    fail_count = fail_count + 1;
                end
            end else begin
                $display("  ⏱ TIMEOUT: %s (active=%b, inter=%b, cycles=%0d)", test_name, nmp_active, inter_flag, cycle_count);
                fail_count = fail_count + 1;
            end
        end
    endtask
    
    initial begin
        $display("\n========================================");
        $display("=== NMP COMPREHENSIVE TEST SUITE ===");
        $display("========================================\n");
        
        test_count = 0;
        pass_count = 0;
        fail_count = 0;
        
        rst_n = 0;
        instruction = 0;
        instruction_valid = 0;
        alt_write_enable = 0;
        axia_arready = 1;
        axib_arready = 1;
        axic_awready = 1;
        axic_wready = 1;
        
        #(CLK_PERIOD * 5);
        rst_n = 1;
        #(CLK_PERIOD * 2);
        
        $display("Array Sizes:");
        run_test("1 element",   17'h0001, 5'd1,  32'h1000, 32'h2000, 32'h3000, 32'h100, 32'h1000);
        run_test("2 elements",  17'h0002, 5'd2,  32'h1000, 32'h2000, 32'h3000, 32'h200, 32'h2000);
        run_test("4 elements",  17'h0003, 5'd4,  32'h1000, 32'h2000, 32'h3000, 32'h300, 32'h3000);
        run_test("8 elements",  17'h0004, 5'd8,  32'h1000, 32'h2000, 32'h3000, 32'h400, 32'h4000);
        run_test("16 elements", 17'h0005, 5'd16, 32'h1000, 32'h2000, 32'h3000, 32'h500, 32'h5000);
        run_test("31 elements", 17'h0006, 5'd31, 32'h1000, 32'h2000, 32'h3000, 32'h600, 32'h6000);
        
        $display("\nData Patterns:");
        run_test("All zeros",   17'h0010, 5'd4,  32'h1000, 32'h2000, 32'h3000, 32'h000, 32'h000);
        run_test("Small nums",  17'h0011, 5'd4,  32'h1000, 32'h2000, 32'h3000, 32'h1, 32'h2);
        run_test("Large nums",  17'h0012, 5'd4,  32'h1000, 32'h2000, 32'h3000, 32'hFFFF0000, 32'hFFFF);
        run_test("Max+1",       17'h0013, 5'd2,  32'h1000, 32'h2000, 32'h3000, 32'hFFFFFFFF, 32'h1);
        
        $display("\nOdd Sizes:");
        run_test("3 elements",  17'h0020, 5'd3,  32'h1000, 32'h2000, 32'h3000, 32'h30, 32'h300);
        run_test("5 elements",  17'h0021, 5'd5,  32'h1000, 32'h2000, 32'h3000, 32'h50, 32'h500);
        run_test("7 elements",  17'h0022, 5'd7,  32'h1000, 32'h2000, 32'h3000, 32'h70, 32'h700);
        run_test("15 elements", 17'h0023, 5'd15, 32'h1000, 32'h2000, 32'h3000, 32'hF0, 32'hF00);
        
        $display("\n========================================");
        $display("RESULTS:");
        $display("  Total:  %0d tests", test_count);
        $display("  Passed: %0d", pass_count);
        $display("  Failed: %0d", fail_count);
        $display("  Rate:   %0d%%", (pass_count*100)/test_count);
        $display("========================================");
        
        if (fail_count == 0)
            $display("\n🎉 ALL TESTS PASSED! System fully verified.\n");
        else
            $display("\n⚠️  %0d test(s) failed.\n", fail_count);
        
        $finish;
    end

endmodule
