`timescale 1ns/1ps

module nmp_proof;
    reg clk = 0;
    reg rst_n;
    reg [31:0] instruction;
    reg instruction_valid;
    wire inter_flag;

    // No of elements in the array can be a maximum of 128 as of now
    parameter size = 12;
    
    // Captured outputs
    reg [31:0] output_data[0:size-1];
    reg [31:0] output_addr[0:size-1];
    integer idx = 0;
    integer no_cycles = 0;
    
    // Timeout flag
    reg timeout_flag = 0;

    // Custom test arrays
reg [31:0] rs1_vals[0:size-1] = '{32'h01, 32'h03, 32'h05, 32'h07, 32'h09, 32'h0B, 32'h0D, 32'h0F, 32'h11, 32'h12, 32'h13, 32'h14};
    reg [31:0] rs2_vals[0:size-1] = '{32'h10, 32'h11, 32'h12, 32'h13, 32'h14, 32'h15, 32'h16, 32'h17, 32'h21, 32'h22, 32'h23, 32'h24};
    
    nmp_top dut(
        .clk(clk), .rst_n(rst_n),
        .instruction(instruction),
        .instruction_valid(instruction_valid),
        .nmp_active(), .inter_flag(inter_flag),
        .error_flag(), .error_code(),
        
        // Port A 
        .axia_araddr(), .axia_arvalid(),
        .axia_arready(1'b1),
        .axia_rdata(dut.current_state == 1 ? (
            dut.addr_load_counter == 0 ? 32'h00105000 :
            dut.addr_load_counter == 1 ? 32'h00106000 :
            dut.addr_load_counter == 2 ? 32'h00107000 : 32'h0
        ) : rs1_vals[dut.element_counter]),
        .axia_rresp(2'b00), .axia_rvalid(1'b1), .axia_rready(),
        
        // Port B
        .axib_araddr(), .axib_arvalid(),
        .axib_arready(1'b1),
        .axib_rdata(rs2_vals[dut.element_counter]),
        .axib_rresp(2'b00), .axib_rvalid(1'b1), .axib_rready(),
        
        // Port C
        .axic_awaddr(), .axic_awvalid(),
        .axic_awready(1'b1),
        .axic_wdata(), .axic_wvalid(),
        .axic_wready(1'b1),
        .axic_bresp(2'b00), .axic_bvalid(1'b1), .axic_bready()
    );
    
    always #5 clk = ~clk;
    
    // Monitor NMP state changes  
    reg [2:0] prev_state = 0;
    always @(posedge clk) begin
        if (dut.u_fsm.current_state !== prev_state) begin
            $display("Time %0t: NMP State changed from %0d to %0d", $time, prev_state, dut.u_fsm.current_state);
            prev_state = dut.u_fsm.current_state;
        end
        if (instruction_valid) begin
            $display("Time %0t: Instruction valid, current_state = %0d", $time, dut.u_fsm.current_state);
        end
        if (dut.axic_wvalid && dut.axic_awvalid) begin
            $display("Time %0t: Writing data 0x%08h to address 0x%08h", $time, dut.axic_wdata, dut.axic_awaddr);
        end
    end
    
    // Timeout mechanism
    initial begin
        #50000; // 50us timeout
        if (!inter_flag) begin
            $display("TIMEOUT: inter_flag not received within 50us");
            timeout_flag = 1;
        end
    end
    
    // Capture outputs
    always @(posedge clk) begin
        if (dut.axic_wvalid && dut.axic_awvalid && idx < size) begin
            output_addr[idx] = dut.axic_awaddr;
            output_data[idx] = dut.axic_wdata;
            idx = idx + 1;
        end
    end

    always @(posedge clk) begin
        no_cycles = no_cycles + 1;
    end
    
    initial begin
        integer i;
        
        $display("\n==== NMP Output Verification ====\n");
        
        rst_n = 0;
        instruction = 0;
        instruction_valid = 0;
        
        #20 rst_n = 1;
        #10;
        
        // Send NMP_ADD instruction
        instruction = {7'b0110000, size[4:0], 5'b00000, 3'b000, 5'b00000, 7'b0110011};
        instruction_valid = 1;
        $display("Sending instruction: 0x%08h at time %0t", instruction, $time);
        #10 instruction_valid = 0;
        $display("Instruction sent, waiting for response...");
        $display("DEBUG: is_nmp_add = %b", dut.u_decoder.is_nmp_add);
        $display("DEBUG: current_state = %0d", dut.u_fsm.current_state);
        $display("DEBUG: addr_load_counter = %0d", dut.addr_load_counter);
        
        // Wait for inter_flag or timeout
        fork
            wait(inter_flag);
            wait(timeout_flag);
        join_any
        
        #20;

        if (inter_flag) begin
            $display("inter_flag received\n");
        end else begin
            $display("TIMEOUT: inter_flag was not received\n");
        end
        
        $display("Total cycles : %0d \n", no_cycles);
        
        // Show results
        $display("NMP OUTPUT ARRAYS:");
        $display("==================");
        for (i = 0; i < idx; i = i + 1) begin
            $display("[%0d] Address: 0x%08h, Data: 0x%08h (0x%02h + 0x%02h = 0x%02h)",
                i, output_addr[i], output_data[i], 
                rs1_vals[i], rs2_vals[i], output_data[i]);
        end
        
        if (idx > 0) begin
            $display("\nEXPECTED vs ACTUAL:");
            $display("===================");
            for (i = 0; i < idx; i = i + 1) begin
                automatic reg [31:0] exp = rs1_vals[i] + rs2_vals[i];
                if (output_data[i] == exp)
                    $display("[%0d] PASS: Expected=0x%02h, Got=0x%02h", i, exp, output_data[i]);
                else
                    $display("[%0d] FAIL: Expected=0x%02h, Got=0x%02h", i, exp, output_data[i]);
            end
        end else begin
            $display("\nNo output data captured - check if NMP unit is working correctly");
        end
        
        $display("\n==================");
        $display("TEST COMPLETE");
        $display("==================\n");
        
        $finish;
    end
endmodule
