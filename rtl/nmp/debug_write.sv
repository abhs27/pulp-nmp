`timescale 1ns/1ps
module debug_write;
    reg clk = 0, rst_n = 0;
    reg [31:0] instruction = 0;
    reg instruction_valid = 0;
    wire inter_flag;
    
    reg [31:0] memory [0:32767];
    reg [31:0] write_addr_capture, write_data_capture;
    integer write_count = 0;
    
    nmp_unit_top dut(
        .clk(clk), .rst_n(rst_n),
        .instruction(instruction),
        .instruction_valid(instruction_valid),
        .nmp_active(), .inter_flag(inter_flag),
        .error_flag(), .error_code(),
        
        // Port A - simple responses
        .axia_araddr(),
        .axia_arvalid(),
        .axia_arready(1'b1),
        .axia_rdata(dut.addr_load_counter == 0 ? 32'h00105000 : 
                    dut.addr_load_counter == 1 ? 32'h00106000 :
                    dut.addr_load_counter == 2 ? 32'h00107000 :
                    32'h10 + dut.element_counter),
        .axia_rresp(2'b00),
        .axia_rvalid(1'b1),
        .axia_rready(),
        
        // Port B
        .axib_araddr(),
        .axib_arvalid(),
        .axib_arready(1'b1),
        .axib_rdata(32'h20 + dut.element_counter),
        .axib_rresp(2'b00),
        .axib_rvalid(1'b1),
        .axib_rready(),
        
        // Port C - monitor writes
        .axic_awaddr(write_addr_capture),
        .axic_awvalid(),
        .axic_awready(1'b1),
        .axic_wdata(write_data_capture),
        .axic_wvalid(),
        .axic_wready(1'b1),
        .axic_bresp(2'b00),
        .axic_bvalid(1'b1),
        .axic_bready()
    );
    
    always #5 clk = ~clk;
    
    // Capture writes
    always @(posedge clk) begin
        if (dut.axic_wvalid && dut.axic_awvalid) begin
            memory[write_addr_capture[16:2]] <= write_data_capture;
            $display("Write[%0d]: addr=0x%h, data=0x%h", 
                write_count, write_addr_capture, write_data_capture);
            write_count <= write_count + 1;
        end
    end
    
    initial begin
        $dumpfile("debug_write.vcd");
        $dumpvars(0, debug_write);
        
        for (int i = 0; i < 32768; i++) memory[i] = 32'hDEADBEEF;
        
        #50 rst_n = 1;
        #10;
        
        instruction = {7'b0110000, 5'd4, 5'b00000, 3'b000, 5'b00000, 7'b0110011};
        instruction_valid = 1;
        #10 instruction_valid = 0;
        
        wait(inter_flag);
        #10;
        
        $display("\nFinal memory content at result location:");
        for (int i = 0; i < 4; i++) begin
            $display("memory[0x%h] = 0x%h", 32'h00107000 + i*4, memory[(32'h00107000 >> 2) + i]);
        end
        
        $finish;
    end
endmodule
