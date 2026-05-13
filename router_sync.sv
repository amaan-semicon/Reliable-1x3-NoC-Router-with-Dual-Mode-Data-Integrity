`timescale 1ns / 1ps

module router_sync (
    input  logic       clock,
    input  logic       resetn,
    input  logic [1:0] data_in,        // Dest address (00, 01, 10)
    input  logic       detect_add,     // From FSM
    input  logic       write_enb_reg,  // From FSM
    input  logic       read_enb_0, 
    input  logic       read_enb_1, 
    input  logic       read_enb_2, 
    input  logic       empty_0, 
    input  logic       empty_1, 
    input  logic       empty_2,        
    input  logic       full_0, 
    input  logic       full_1, 
    input  logic       full_2,         

    output logic [2:0] write_enb,      // Individual write enables for FIFOs
    output logic       fifo_full,      // Muxed full signal for FSM
    output logic       vld_sync_0, 
    output logic       vld_sync_1, 
    output logic       vld_sync_2, 
    output logic       soft_reset_0, 
    output logic       soft_reset_1, 
    output logic       soft_reset_2 
);

    // -------------------------------------------------------------------------
    // INTERNAL REGISTERS
    // -------------------------------------------------------------------------
    logic [1:0] int_addr_reg;
    logic [4:0] timer_0, timer_1, timer_2; // 5-bit timers for 30-cycle timeout

    // -------------------------------------------------------------------------
    // 1. ADDRESS LATCHING LOGIC
    // -------------------------------------------------------------------------
    always_ff @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            int_addr_reg <= 2'b11; // 11 is invalid default address
        end 
        else if (detect_add) begin
            int_addr_reg <= data_in; // Lock address during DECODE_ADDRESS state
        end
    end

    // -------------------------------------------------------------------------
    // 2. FIFO FULL ROUTING LOGIC (Mux to FSM)
    // -------------------------------------------------------------------------
    always_comb begin
        case (int_addr_reg)
            2'b00: fifo_full = full_0;
            2'b01: fifo_full = full_1;
            2'b10: fifo_full = full_2;
            default: fifo_full = 1'b0;
        endcase
    end

    // -------------------------------------------------------------------------
    // 3. WRITE ENABLE DEMUX LOGIC (Route FSM req to correct FIFO)
    // -------------------------------------------------------------------------
    always_comb begin
        // Default assignment to avoid latches
        write_enb = 3'b000; 
        
        if (write_enb_reg) begin
            case (int_addr_reg)
                2'b00: write_enb[0] = 1'b1;
                2'b01: write_enb[1] = 1'b1;
                2'b10: write_enb[2] = 1'b1;
                default: write_enb = 3'b000;
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // 4. VALID SYNC LOGIC (Tell receivers data is ready)
    // -------------------------------------------------------------------------
    // If FIFO is not empty, data is valid to be read
    assign vld_sync_0 = ~empty_0;
    assign vld_sync_1 = ~empty_1;
    assign vld_sync_2 = ~empty_2;

    // -------------------------------------------------------------------------
    // 5. SOFT RESET LOGIC (30 Clock Cycle Timeouts)
    // -------------------------------------------------------------------------
    // Timer 0
    always_ff @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            timer_0 <= 5'd0;
            soft_reset_0 <= 1'b0;
        end 
        else if (vld_sync_0 && !read_enb_0) begin
            if (timer_0 == 5'd29) begin  // 0 to 29 = 30 clock cycles
                soft_reset_0 <= 1'b1;
                timer_0 <= 5'd0;
            end else begin
                timer_0 <= timer_0 + 1'b1;
                soft_reset_0 <= 1'b0;
            end
        end else begin
            timer_0 <= 5'd0;
            soft_reset_0 <= 1'b0;
        end
    end

    // Timer 1
    always_ff @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            timer_1 <= 5'd0;
            soft_reset_1 <= 1'b0;
        end 
        else if (vld_sync_1 && !read_enb_1) begin
            if (timer_1 == 5'd29) begin
                soft_reset_1 <= 1'b1;
                timer_1 <= 5'd0;
            end else begin
                timer_1 <= timer_1 + 1'b1;
                soft_reset_1 <= 1'b0;
            end
        end else begin
            timer_1 <= 5'd0;
            soft_reset_1 <= 1'b0;
        end
    end

    // Timer 2
    always_ff @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            timer_2 <= 5'd0;
            soft_reset_2 <= 1'b0;
        end 
        else if (vld_sync_2 && !read_enb_2) begin
            if (timer_2 == 5'd29) begin
                soft_reset_2 <= 1'b1;
                timer_2 <= 5'd0;
            end else begin
                timer_2 <= timer_2 + 1'b1;
                soft_reset_2 <= 1'b0;
            end
        end else begin
            timer_2 <= 5'd0;
            soft_reset_2 <= 1'b0;
        end
    end

endmodule