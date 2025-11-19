module divider (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire signed [31:0] a,
    input  wire signed [31:0] b,

    output reg  signed [31:0] q,
    output reg         done
);

    // FSM states for signed non-restoring division
    localparam S_IDLE   = 2'b00;
    localparam S_RUN    = 2'b01;
    localparam S_POST   = 2'b10;
    localparam S_FINISH = 2'b11;

    reg [1:0]  state;

    // Internal registers for the unsigned non-restoring core
    reg [31:0] q_reg;   // Holds positive dividend, then quotient
    reg [32:0] acc;     // Accumulator
    reg [31:0] divisor; // Holds positive divisor
    reg [5:0]  count;

    // Registers for sign handling
    reg a_sign, b_sign;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset logic
            state  <= S_IDLE;
            q      <= 32'd0;
            done   <= 1'b0;
            q_reg  <= 32'd0;
            acc    <= 33'd0;
            divisor<= 32'd0;
            count  <= 6'd0;
            a_sign <= 1'b0;
            b_sign <= 1'b0;
        end else begin
            done <= 1'b0; // Default

            case (state)
            S_IDLE: begin
                if (start) begin
                    if (b == 32'd0) begin
                        q     <= 32'hFFFFFFFF;
                        done  <= 1'b1;
                        state <= S_IDLE;
                    end else begin
                        // Step 1: Record signs and get absolute values
                        a_sign = a[31];
                        b_sign = b[31];
                        
                        acc     <= 33'd0;
                        q_reg   <= a_sign ? -a : a; // Load positive dividend
                        divisor <= b_sign ? -b : b; // Load positive divisor
                        
                        count   <= 6'd0;
                        state   <= S_RUN;
                    end
                end
            end

            S_RUN: begin
                // Step 2: Unsigned non-restoring division loop
                logic [32:0] next_acc;
                if (acc[32]) begin // If sign was 1
                    next_acc = {acc[31:0], q_reg[31]} + divisor;
                end else begin // If sign was 0
                    next_acc = {acc[31:0], q_reg[31]} - divisor;
                end

                acc <= next_acc;
                q_reg <= {q_reg[30:0], ~next_acc[32]};

                count <= count + 1;
                if (count == 6'd31) begin
                    state <= S_POST;
                end
            end

            S_POST: begin
                // Step 3: Remainder correction for the unsigned core
                if (acc[32]) begin
                    acc <= acc + divisor;
                end
                
                // Step 4: Apply final sign to quotient.
                // This produces a result that truncates towards zero, matching Verilog's '/' operator.
                if (a_sign ^ b_sign) begin
                    q <= -q_reg;
                end else begin
                    q <= q_reg;
                end
                state <= S_FINISH;
            end

            S_FINISH: begin
                done <= 1'b1;
                state <= S_IDLE;
            end
            
            default: state <= S_IDLE;
            endcase
        end
    end
endmodule
