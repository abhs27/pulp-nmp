module test_hash_simple;
    reg [31:0] rs1, rs2, rd;
    wire [16:0] hash;
    
    nmp_hash_generator dut (
        .rs1_base_addr(rs1),
        .rs2_base_addr(rs2),
        .rd_base_addr(rd),
        .hash_index(hash)
    );
    
    initial begin
        rs1 = 32'h10000000;
        rs2 = 32'h20000000;
        rd  = 32'h30000000;
        #1;
        $display("Test 1: rs1=0x%08X, rs2=0x%08X, rd=0x%08X => hash=0x%05X", rs1, rs2, rd, hash);
        
        rs1 = 32'h00001000;
        rs2 = 32'h00002000;
        rd  = 32'h00003000;
        #1;
        $display("Test 2: rs1=0x%08X, rs2=0x%08X, rd=0x%08X => hash=0x%05X", rs1, rs2, rd, hash);
        
        $finish;
    end
endmodule
