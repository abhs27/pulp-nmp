`timescale 1ns / 1ps

//-----------------------------------------------------------------------------
// Title         : Testbench for nmp_axi_master
// Project       : PULPino NMP Extension
// Description   : Verifies the AXI master logic by mocking the FSM controller
//                 and AXI slave responses.
//-----------------------------------------------------------------------------
module tb_nmp_axi_master;

    // Parameters
    localparam CLK_PERIOD = 10;

    // DUT Interface
    reg         clk = 0;
    reg         rst_n;
    reg  [3:0]  current_state;
    reg         start_addr_load = 0; // Unused in hash mode
    reg         start_element_read;
    reg         start_element_write;
    reg  [1:0]  addr_load_counter = 0; // Unused
    reg  [31:0] base_ptr_addr = 0; // Unused
    reg  [31:0] rs1_element_addr;
    reg  [31:0] rs2_element_addr;
    reg  [31:0] rd_element_addr;
    reg  [31:0] write_data;
    wire [31:0] rs1_data;
    wire [31:0] rs2_data;
    wire        rs1_read_done;
    wire        rs2_read_done;
    wire        write_done;

    // AXI Ports
    wire [31:0] axia_araddr, axib_araddr, axic_awaddr;
    wire        axia_arvalid, axib_arvalid, axic_awvalid;
    reg         axia_arready, axib_arready, axic_awready;
    reg  [31:0] axia_rdata, axib_rdata;
    reg         axia_rvalid, axib_rvalid, axic_bvalid;
    wire        axia_rready, axib_rready, axic_bready;
    wire [31:0] axic_wdata;
    wire        axic_wvalid;
    reg         axic_wready;

    // FSM States
    localparam [3:0] S_IDLE = 4'b0000;
    localparam [3:0] S_EXECUTE_READ = 4'b0100;
    localparam [3:0] S_EXECUTE_WRITE = 4'b0110;

    // Test tracking
    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;
    
    // Mock Memory
    reg [31:0] memory [0:1023];

    // Instantiate DUT
    nmp_axi_master dut (
        .clk(clk), .rst_n(rst_n),
        .current_state(current_state),
        .start_addr_load(start_addr_load),
        .start_element_read(start_element_read),
        .start_element_write(start_element_write),
        .addr_load_counter(addr_load_counter),
        .base_ptr_addr(base_ptr_addr),
        .rs1_element_addr(rs1_element_addr),
        .rs2_element_addr(rs2_element_addr),
        .rd_element_addr(rd_element_addr),
        .write_data(write_data),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
        .rs1_read_done(rs1_read_done),
        .rs2_read_done(rs2_read_done),
        .write_done(write_done),
        // Tie off unused ports
        .loaded_base_addr(), .store_rs1_base(), .store_rs2_base(), .store_rd_base(),
        .error_flag(), .error_code(),
        // AXI Ports
        .axia_araddr(axia_araddr), .axia_arvalid(axia_arvalid), .axia_arready(axia_arready),
        .axia_rdata(axia_rdata), .axia_rresp(2'b0), .axia_rvalid(axia_rvalid), .axia_rready(axia_rready),
        .axib_araddr(axib_araddr), .axib_arvalid(axib_arvalid), .axib_arready(axib_arready),
        .axib_rdata(axib_rdata), .axib_rresp(2'b0), .axib_rvalid(axib_rvalid), .axib_rready(axib_rready),
        .axic_awaddr(axic_awaddr), .axic_awvalid(axic_awvalid), .axic_awready(axic_awready),
        .axic_wdata(axic_wdata), .axic_wvalid(axic_wvalid), .axic_wready(axic_wready),
        .axic_bresp(2'b0), .axic_bvalid(axic_bvalid), .axic_bready(axic_bready)
    );

    // Clock generator
    always #(CLK_PERIOD / 2) clk = ~clk;

    //-------------------------------------
    // Mock AXI Slave Logic
    //-------------------------------------
    // This slave has a 1-cycle delay for responses
    always @(posedge clk) begin
        // Port A (RS1)
        if (axia_arvalid && axia_arready) begin
            axia_rdata <= memory[axia_araddr >> 2];
            axia_rvalid <= 1'b1;
        end else if (axia_rready) begin
            axia_rvalid <= 1'b0;
        end
        // Port B (RS2)
        if (axib_arvalid && axib_arready) begin
            axib_rdata <= memory[axib_araddr >> 2];
            axib_rvalid <= 1'b1;
        end else if (axib_rready) begin
            axib_rvalid <= 1'b0;
        end
        // Port C (RD)
        if (axic_awvalid && axic_awready && axic_wvalid && axic_wready) begin
            memory[axic_awaddr >> 2] <= axic_wdata;
            axic_bvalid <= 1'b1;
        end else if (axic_bready) begin
            axic_bvalid <= 1'b0;
        end
    end

    // Task to test a read cycle
    task test_read_cycle;
        test_count++;
        $display("\n--- Testing Read Cycle ---");
        // Setup
        memory[10] = 32'hAAAAAAAA;
        memory[20] = 32'hBBBBBBBB;
        rs1_element_addr = 32'd40; // 10 * 4
        rs2_element_addr = 32'd80; // 20 * 4
        
        // Start read
        @(posedge clk);
        current_state = S_EXECUTE_READ;
        start_element_read = 1;
        @(posedge clk);
        start_element_read = 0;

        wait(rs1_read_done && rs2_read_done);
        @(posedge clk);

        // Check results
        if (rs1_data === 32'hAAAAAAAA && rs2_data === 32'hBBBBBBBB) begin
            $display("[PASS] Read cycle correct.");
            pass_count++;
        end else begin
            $display("[FAIL] Read cycle incorrect. RS1: %h, RS2: %h", rs1_data, rs2_data);
            fail_count++;
        end
        current_state = S_IDLE;
    endtask

    // Task to test a write cycle
    task test_write_cycle;
        test_count++;
        $display("\n--- Testing Write Cycle ---");
        // Setup
        rd_element_addr = 32'd120; // 30 * 4
        write_data = 32'hDEADBEEF;
        memory[30] = 32'h0;

        // Start write
        @(posedge clk);
        current_state = S_EXECUTE_WRITE;
        start_element_write = 1;
        @(posedge clk);
        start_element_write = 0;

        wait(write_done);
        @(posedge clk);

        // Check memory
        if (memory[30] === 32'hDEADBEEF) begin
            $display("[PASS] Write cycle correct.");
            pass_count++;
        end else begin
            $display("[FAIL] Write cycle incorrect. Memory contains %h", memory[30]);
            fail_count++;
        end
        current_state = S_IDLE;
    endtask

    // Main test sequence
    initial begin
        $display("\n=======================================");
        $display("=== Testbench for nmp_axi_master ===");
        $display("=======================================\n");

        // Reset
        rst_n = 1'b0;
        current_state = S_IDLE;
        start_element_read = 0;
        start_element_write = 0;
        axia_arready = 1; axib_arready = 1; axic_awready = 1; axic_wready = 1;
        axia_rvalid = 0; axib_rvalid = 0; axic_bvalid = 0;
        #(CLK_PERIOD * 5);
        rst_n = 1'b1;
        @(posedge clk);

        // Run tests
        test_read_cycle();
        test_write_cycle();

        // --- Test Summary ---
        $display("\n=======================================");
        $display("--- Test Summary ---");
        if (fail_count == 0) begin
            $display("[SUCCESS] All %0d tests passed!", test_count);
        end else begin
            $display("[FAILURE] %0d out of %0d tests failed.", fail_count, test_count);
        end
        $display("=======================================\n");

        $finish;
    end

endmodule
