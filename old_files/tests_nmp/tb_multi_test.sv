`timescale 1ns / 1ps

module tb_multi_test;

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
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            axia_arready <= 1'b1;
            axib_arready <= 1'b1;
            axic_awready <= 1'b1;
            axic_wready  <= 1'b1;
        end
    end
    
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
        input [16:0] hash;
        input [4:0] size;
        input [31:0] rs1_base, rs2_base, rd_base;
        integer i, pass;
        begin
            $display("\n--- Test: hash=0x%05X size=%0d ---", hash, size);
            
            // Write hash entry
            @(posedge clk);
            alt_write_enable = 1;
            alt_write_hash_index = hash;
            alt_write_rs1_base = rs1_base;
            alt_write_rs2_base = rs2_base;
            alt_write_rd_base  = rd_base;
            @(posedge clk);
            alt_write_enable = 0;
            repeat(3) @(posedge clk);
            
            // Execute instruction
            cycle_count = 0;
            instruction = {hash, 1'b1, 2'b00, size, 7'h6b};
            @(posedge clk);
            instruction_valid = 1;
            @(posedge clk);
            instruction_valid = 0;
            
            wait(inter_flag || cycle_count > 200);
            repeat(3) @(posedge clk);
            
            if (inter_flag) begin
                pass = 1;
                for (i = 0; i < size; i = i + 1) begin
                    if (memory[(rd_base >> 2) + i] != memory[(rs1_base >> 2) + i] + memory[(rs2_base >> 2) + i]) begin
                        pass = 0;
                    end
                end
                $display("  Result: %s (cycles=%0d)", pass ? "PASS" : "FAIL", cycle_count);
            end else begin
                $display("  Result: TIMEOUT");
            end
        end
    endtask
    
    initial begin
        integer i;
        
        $display("\n====================================");
        $display("=== MULTI-SCENARIO TEST SUITE ===");
        $display("====================================");
        
        // Initialize memory
        for (i = 0; i < 4096; i = i + 1) memory[i] = 32'h0;
        for (i = 0; i < 16; i = i + 1) begin
            memory[1024 + i] = 32'h00000100 + i;
            memory[2048 + i] = 32'h00001000 + i;
            memory[3072 + i] = 32'h00000000;
        end
        
        // Reset
        rst_n = 0;
        instruction = 0;
        instruction_valid = 0;
        alt_write_enable = 0;
        cycle_count = 0;
        axia_arready = 1;
        axib_arready = 1;
        axic_awready = 1;
        axic_wready = 1;
        
        #(CLK_PERIOD * 5);
        rst_n = 1;
        #(CLK_PERIOD * 2);
        
        // Test different scenarios
        run_test(17'h12345, 5'd4,  32'h00001000, 32'h00002000, 32'h00003000);
        run_test(17'hABCDE, 5'd8,  32'h00001000, 32'h00002000, 32'h00003000);
        run_test(17'h00001, 5'd2,  32'h00001000, 32'h00002000, 32'h00003000);
        run_test(17'h1FFFF, 5'd16, 32'h00001000, 32'h00002000, 32'h00003000);
        
        $display("\n====================================");
        $display("=== ALL TESTS COMPLETED ===");
        $display("====================================\n");
        
        $finish;
    end

endmodule
