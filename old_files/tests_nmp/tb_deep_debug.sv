`timescale 1ns / 1ps

module tb_deep_debug;

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
    reg         axia_arready, axib_arready, axic_awready;
    reg  [31:0] axia_rdata, axib_rdata;
    reg  [1:0]  axia_rresp, axib_rresp, axic_bresp;
    reg         axia_rvalid, axib_rvalid, axic_bvalid;
    wire        axia_rready, axib_rready, axic_bready;
    wire [31:0] axic_wdata;
    wire        axic_wvalid;
    reg         axic_wready;
    
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
    
    // AXI responder
    always @(posedge clk) begin
        if (!rst_n) begin
            axia_rvalid <= 0;
            axib_rvalid <= 0;
            axic_bvalid <= 0;
        end else begin
            if (axia_arvalid && axia_arready) begin
                axia_rdata  <= memory[axia_araddr[11:2]];
                axia_rvalid <= 1;
                axia_rresp  <= 2'b00;
            end else if (axia_rvalid && axia_rready) begin
                axia_rvalid <= 0;
            end
            
            if (axib_arvalid && axib_arready) begin
                axib_rdata  <= memory[axib_araddr[11:2]];
                axib_rvalid <= 1;
                axib_rresp  <= 2'b00;
            end else if (axib_rvalid && axib_rready) begin
                axib_rvalid <= 0;
            end
            
            if (axic_awvalid && axic_awready && axic_wvalid && axic_wready) begin
                memory[axic_awaddr[11:2]] <= axic_wdata;
                axic_bvalid <= 1;
                axic_bresp  <= 2'b00;
            end else if (axic_bvalid && axic_bready) begin
                axic_bvalid <= 0;
            end
        end
    end
    
    always @(*) begin
        axia_arready = 1;
        axib_arready = 1;
        axic_awready = 1;
        axic_wready  = 1;
    end
    
    // Cycle counter
    always @(posedge clk) begin
        if (!rst_n)
            cycle_count <= 0;
        else if (nmp_active)
            cycle_count <= cycle_count + 1;
    end
    
    // Comprehensive signal monitoring
    always @(posedge clk) begin
        if (nmp_active) begin
            $display("CYCLE %0d | State=%0d | rs1_rd=%b rs2_rd=%b wr=%b | AXIA: arv=%b arr=%b rrdy=%b rv=%b | AXIB: arv=%b arr=%b rrdy=%b rv=%b",
                     cycle_count, dut.current_state, 
                     dut.rs1_read_done, dut.rs2_read_done, dut.write_done,
                     axia_arvalid, axia_arready, axia_rready, axia_rvalid,
                     axib_arvalid, axib_arready, axib_rready, axib_rvalid);
            
            // Detailed state-specific info
            case (dut.current_state)
                3'b110: $display("  -> HASH_LOOKUP: hash_valid=%b, hash_nf=%b", dut.hash_addr_valid, dut.hash_addr_not_found);
                3'b010: $display("  -> EXECUTE_INIT: rs1_base=0x%08X, rs2_base=0x%08X, rd_base=0x%08X", 
                                 dut.rs1_base_addr, dut.rs2_base_addr, dut.rd_base_addr);
                3'b011: begin
                    $display("  -> EXECUTE_READ: rs1_elem_addr=0x%08X, rs2_elem_addr=0x%08X", 
                             dut.rs1_element_addr, dut.rs2_element_addr);
                    $display("     AXI_A internals: !arv=%b, !rrdy=%b, condition=%b",
                             !axia_arvalid, !axia_rready, (!axia_arvalid && !axia_rready));
                    $display("     AXI_B internals: !arv=%b, !rrdy=%b, condition=%b",
                             !axib_arvalid, !axib_rready, (!axib_arvalid && !axib_rready));
                end
                3'b100: $display("  -> EXECUTE_WRITE: wr_addr=0x%08X, wr_data=0x%08X", dut.rd_element_addr, dut.alu_result);
            endcase
        end
    end
    
    // Watchdog for stuck FSM
    initial begin
        #(CLK_PERIOD * 200);
        if (nmp_active && !inter_flag) begin
            $display("\n!!! WATCHDOG TIMEOUT !!!");
            $display("Stuck in state %0d after %0d cycles", dut.current_state, cycle_count);
            $display("Final status: rs1_rd=%b rs2_rd=%b wr=%b", dut.rs1_read_done, dut.rs2_read_done, dut.write_done);
            $finish;
        end
    end
    
    initial begin
        integer i;
        reg [16:0] test_hash;
        
        $display("\n========================================");
        $display("=== DEEP DEBUG TESTBENCH ===");
        $display("========================================\n");
        
        rst_n = 0;
        instruction = 0;
        instruction_valid = 0;
        alt_write_enable = 0;
        cycle_count = 0;
        #(CLK_PERIOD * 5);
        rst_n = 1;
        #(CLK_PERIOD * 2);
        
        $display("[Step 1] Writing hash entry to ALT...");
        test_hash = 17'h12345;
        @(posedge clk);
        alt_write_enable = 1;
        alt_write_hash_index = test_hash;
        alt_write_rs1_base = 32'h00001000;
        alt_write_rs2_base = 32'h00002000;
        alt_write_rd_base  = 32'h00003000;
        @(posedge clk);
        alt_write_enable = 0;
        $display("  Hash 0x%05X -> RS1=0x%08X, RS2=0x%08X, RD=0x%08X", 
                 test_hash, 32'h00001000, 32'h00002000, 32'h00003000);
        repeat(3) @(posedge clk);
        
        $display("\n[Step 2] Initializing memory arrays...");
        for (i = 0; i < 8; i = i + 1) begin
            memory[(32'h00001000 >> 2) + i] = 32'h00000100 + i;
            memory[(32'h00002000 >> 2) + i] = 32'h00001000 + i;
            memory[(32'h00003000 >> 2) + i] = 32'h00000000;
        end
        $display("  RS1[0..7] = 0x100..0x107");
        $display("  RS2[0..7] = 0x1000..0x1007");
        $display("  RD[0..7]  = 0x0 (cleared)");
        
        $display("\n[Step 3] Sending NMP instruction...");
        instruction = {test_hash, 1'b1, 2'b00, 5'd8, 7'h6b};
        $display("  Instruction: 0x%08X (hash=0x%05X, hash_mode=1, size=8)", instruction, test_hash);
        
        @(posedge clk);
        instruction_valid = 1;
        @(posedge clk);
        instruction_valid = 0;
        
        $display("\n[Step 4] Monitoring execution...\n");
        
        wait(inter_flag || cycle_count > 150);
        
        repeat(5) @(posedge clk);
        
        $display("\n========================================");
        if (inter_flag) begin
            $display("=== ✓ TEST PASSED ===");
            $display("Operation completed in %0d cycles", cycle_count);
            $display("\nResult verification:");
            for (i = 0; i < 8; i = i + 1) begin
                $display("  RD[%0d] = 0x%08X (expected: 0x%08X)", 
                         i, memory[(32'h00003000 >> 2) + i],
                         (32'h00000100 + i) + (32'h00001000 + i));
            end
        end else begin
            $display("=== ✗ TEST FAILED ===");
            $display("Timeout after %0d cycles in state %0d", cycle_count, dut.current_state);
        end
        $display("========================================\n");
        
        $finish;
    end

endmodule
