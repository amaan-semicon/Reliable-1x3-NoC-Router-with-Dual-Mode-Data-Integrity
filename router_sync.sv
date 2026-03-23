`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.03.2026 22:22:51
// Design Name: 
// Module Name: router_sync
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module router_sync (
    input  logic       clock,
    input  logic       resetn,
    input  logic [1:0] data_in,        // To check destination address (00, 01, 10)
    input  logic       detect_add,     // From FSM: indicates header byte is present
    input  logic       write_enb_reg,  // From FSM: request to write data
    input  logic       read_enb_0, read_enb_1, read_enb_2, // From output receivers
    input  logic       empty_0, empty_1, empty_2,          // From FIFOs
    input  logic       full_0, full_1, full_2,             // From FIFOs

    output logic [2:0] write_enb,      // Individual write enables for 3 FIFOs
    output logic       fifo_full,      // Tells FSM if target FIFO is full
    output logic       vld_sync_0, vld_sync_1, vld_sync_2, // Valid signals for receivers
    output logic       soft_reset_0, soft_reset_1, soft_reset_2 // Timeout resets
);

    // Internal register to lock the destination address
    logic [1:0] int_addr_reg;

    // Timer variables for soft reset (30 cycles timeout)
    logic [4:0] timer_0, timer_1, timer_2;

    // -------------------------------------------------------------------------
    // 1. ADDRESS LATCHING LOGIC
    // -------------------------------------------------------------------------
    always_ff @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            int_addr_reg <= 2'b11; // 11 means invalid/no address
        end 
        else if (detect_add) begin
            int_addr_reg <= data_in; // Lock the address (00, 01, or 10)
        end
    end

    // -------------------------------------------------------------------------
    // 2. FIFO FULL LOGIC (MUX to route the correct full signal to FSM)
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
    // 3. WRITE ENABLE LOGIC (Route FSM's write request to correct FIFO)
    // -------------------------------------------------------------------------
    always_comb begin
        write_enb = 3'b000; // Default: No write
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
    // 4. VALID SYNC LOGIC (Tell receiver that data is ready to be read)
    // -------------------------------------------------------------------------
    assign vld_sync_0 = ~empty_0;
    assign vld_sync_1 = ~empty_1;
    assign vld_sync_2 = ~empty_2;

    // -------------------------------------------------------------------------
    // 5. SOFT RESET LOGIC (30 Clock Cycle Timeout for each FIFO)
    // -------------------------------------------------------------------------
    
    // Timer for FIFO 0
    always_ff @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            timer_0 <= 5'd0;
            soft_reset_0 <= 1'b0;
        end 
        else if (vld_sync_0) begin
            if (!read_enb_0) begin
                if (timer_0 == 5'd29) begin
                    soft_reset_0 <= 1'b1; // Trigger soft reset
                    timer_0 <= 5'd0;
                end else begin
                    timer_0 <= timer_0 + 1'b1;
                    soft_reset_0 <= 1'b0;
                end
            end else begin
                timer_0 <= 5'd0; // Reset timer if read happens
                soft_reset_0 <= 1'b0;
            end
        end else begin
            timer_0 <= 5'd0;
            soft_reset_0 <= 1'b0;
        end
    end

    // Timer for FIFO 1
    always_ff @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            timer_1 <= 5'd0;
            soft_reset_1 <= 1'b0;
        end 
        else if (vld_sync_1) begin
            if (!read_enb_1) begin
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
        end else begin
            timer_1 <= 5'd0;
            soft_reset_1 <= 1'b0;
        end
    end

    // Timer for FIFO 2
    always_ff @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            timer_2 <= 5'd0;
            soft_reset_2 <= 1'b0;
        end 
        else if (vld_sync_2) begin
            if (!read_enb_2) begin
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
        end else begin
            timer_2 <= 5'd0;
            soft_reset_2 <= 1'b0;
        end
    end

endmodule
