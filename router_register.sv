`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.03.2026 21:16:09
// Design Name: 
// Module Name: router_register
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


module register_crc8 (
    input  logic        clock,
    input  logic        resetn,
    input  logic        pkt_valid,
    input  logic [7:0]  data_in,
    input  logic        fifo_full,
    input  logic        detect_add,
    input  logic        ld_state,
    input  logic        full_state,         // laf_state completely removed!
    input  logic        lfd_state,
    input  logic        rst_int_reg,
    input  logic        parity_mode,        // 0: CRC-8 mode, 1: Parity mode
    
    output logic [7:0]  dout,
    output logic        err,
    output logic        parity_done,
    output logic        low_packet_valid,
    output logic [7:0]  crc_out,            // Computed CRC value
    output logic        error_corrected,    // Indicates error was corrected
    output logic [7:0]  corrected_data      // Corrected data output
);

    // -------------------------------------------------------------------------
    // INTERNAL REGISTERS (Using your exact names)
    // -------------------------------------------------------------------------
    logic [7:0] full_state_byte;
    logic [7:0] header;
    logic [7:0] crc_value;
    logic [7:0] internal_parity;
    logic [7:0] received_crc;
    logic [7:0] lookup_index;

    // -------------------------------------------------------------------------
    // ZERO-LATENCY CRC-8 ARRAY (Named crc8_table as per your code)
    // -------------------------------------------------------------------------
    logic [7:0] crc8_table [0:255] = '{
        8'h00, 8'h07, 8'h0E, 8'h09, 8'h1C, 8'h1B, 8'h12, 8'h15,
        8'h38, 8'h3F, 8'h36, 8'h31, 8'h24, 8'h23, 8'h2A, 8'h2D,
        8'h70, 8'h77, 8'h7E, 8'h79, 8'h6C, 8'h6B, 8'h62, 8'h65,
        8'h48, 8'h4F, 8'h46, 8'h41, 8'h54, 8'h53, 8'h5A, 8'h5D,
        8'hE0, 8'hE7, 8'hEE, 8'hE9, 8'hFC, 8'hFB, 8'hF2, 8'hF5,
        8'hD8, 8'hDF, 8'hD6, 8'hD1, 8'hC4, 8'hC3, 8'hCA, 8'hCD,
        8'h90, 8'h97, 8'h9E, 8'h99, 8'h8C, 8'h8B, 8'h82, 8'h85,
        8'hA8, 8'hAF, 8'hA6, 8'hA1, 8'hB4, 8'hB3, 8'hBA, 8'hBD,
        8'hC7, 8'hC0, 8'hC9, 8'hCE, 8'hDB, 8'hDC, 8'hD5, 8'hD2,
        8'hFF, 8'hF8, 8'hF1, 8'hF6, 8'hE3, 8'hE4, 8'hED, 8'hEA,
        8'hB7, 8'hB0, 8'hB9, 8'hBE, 8'hAB, 8'hAC, 8'hA5, 8'hA2,
        8'h8F, 8'h88, 8'h81, 8'h86, 8'h93, 8'h94, 8'h9D, 8'h9A,
        8'h27, 8'h20, 8'h29, 8'h2E, 8'h3B, 8'h3C, 8'h35, 8'h32,
        8'h1F, 8'h18, 8'h11, 8'h16, 8'h03, 8'h04, 8'h0D, 8'h0A,
        8'h57, 8'h50, 8'h59, 8'h5E, 8'h4B, 8'h4C, 8'h45, 8'h42,
        8'h6F, 8'h68, 8'h61, 8'h66, 8'h73, 8'h74, 8'h7D, 8'h7A,
        8'h89, 8'h8E, 8'h87, 8'h80, 8'h95, 8'h92, 8'h9B, 8'h9C,
        8'hB1, 8'hB6, 8'hBF, 8'hB8, 8'hAD, 8'hAA, 8'hA3, 8'hA4,
        8'hF9, 8'hFE, 8'hF7, 8'hF0, 8'hE5, 8'hE2, 8'hEB, 8'hEC,
        8'hC1, 8'hC6, 8'hCF, 8'hC8, 8'hDD, 8'hDA, 8'hD3, 8'hD4,
        8'h69, 8'h6E, 8'h67, 8'h60, 8'h75, 8'h72, 8'h7B, 8'h7C,
        8'h51, 8'h56, 8'h5F, 8'h58, 8'h4D, 8'h4A, 8'h43, 8'h44,
        8'h19, 8'h1E, 8'h17, 8'h10, 8'h05, 8'h02, 8'h0B, 8'h0C,
        8'h21, 8'h26, 8'h2F, 8'h28, 8'h3D, 8'h3A, 8'h33, 8'h34,
        8'h4E, 8'h49, 8'h40, 8'h47, 8'h52, 8'h55, 8'h5C, 8'h5B,
        8'h76, 8'h71, 8'h78, 8'h7F, 8'h6A, 8'h6D, 8'h64, 8'h63,
        8'h3E, 8'h39, 8'h30, 8'h37, 8'h22, 8'h25, 8'h2C, 8'h2B,
        8'h06, 8'h01, 8'h08, 8'h0F, 8'h1A, 8'h1D, 8'h14, 8'h13,
        8'hAE, 8'hA9, 8'hA0, 8'hA7, 8'hB2, 8'hB5, 8'hBC, 8'hBB,
        8'h96, 8'h91, 8'h98, 8'h9F, 8'h8A, 8'h8D, 8'h84, 8'h83,
        8'hDE, 8'hD9, 8'hD0, 8'hD7, 8'hC2, 8'hC5, 8'hCC, 8'hCB,
        8'hE6, 8'hE1, 8'hE8, 8'hEF, 8'hFA, 8'hFD, 8'hF4, 8'hF3
    };

    // -------------------------------------------------------------------------
    // DOUT LOGIC (Adjusted since laf_state is gone)
    // -------------------------------------------------------------------------
    always_ff @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            dout <= 8'h00;
        end
        else begin
            if (detect_add) begin
                dout <= dout; 
            end
            else if (lfd_state) begin
                dout <= header; 
            end
            else if (ld_state && !fifo_full) begin
                dout <= data_in; 
            end
            // Since laf_state is gone, we rely on full_state or ld_state recovering
            else if (full_state) begin
                dout <= full_state_byte; 
            end
        end
    end

    // -------------------------------------------------------------------------
    // HEADER & FULL_STATE_BYTE
    // -------------------------------------------------------------------------
    always_ff @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            header <= 8'h00;
            full_state_byte <= 8'h00;
        end
        else begin
            if (detect_add && pkt_valid && (data_in[1:0] != 2'b11)) begin
                header <= data_in;
            end
            if (ld_state && fifo_full) begin
                full_state_byte <= data_in;
            end
        end
    end

    // -------------------------------------------------------------------------
    // CRC & PARITY CALCULATION (Using exact array index logic)
    // -------------------------------------------------------------------------
    always_ff @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            crc_value <= 8'h00;
            internal_parity <= 8'h00;
        end
        else begin
            if (detect_add) begin
                crc_value <= 8'h00;
                internal_parity <= 8'h00;
            end
            else if (lfd_state) begin
                lookup_index = 8'h00 ^ header;
                crc_value <= crc8_table[lookup_index];
                internal_parity <= internal_parity ^ header;
            end
            else if (ld_state && pkt_valid && !full_state) begin
                lookup_index = crc_value ^ data_in;
                crc_value <= crc8_table[lookup_index];
                internal_parity <= internal_parity ^ data_in;
            end
        end
    end

    // -------------------------------------------------------------------------
    // FSM HELPER SIGNALS 
    // -------------------------------------------------------------------------
    always_ff @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            low_packet_valid <= 1'b0;
            parity_done <= 1'b0;
            received_crc <= 8'h00;
        end
        else begin
            // low_packet_valid
            if (rst_int_reg || detect_add) low_packet_valid <= 1'b0;
            else if (ld_state && !pkt_valid) low_packet_valid <= 1'b1;

            // parity_done (Removed laf_state condition)
            if (detect_add) parity_done <= 1'b0;
            else if ((ld_state && !pkt_valid && !fifo_full) || (full_state && low_packet_valid && !parity_done)) 
                parity_done <= 1'b1;
            
            // received_crc
            if (ld_state && !pkt_valid) received_crc <= data_in; 
        end
    end

    // -------------------------------------------------------------------------
    // ERROR DETECTION VERDICT
    // -------------------------------------------------------------------------
    always_ff @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            err <= 1'b0;
        end
        else begin
            if (parity_done) begin
                if (parity_mode) begin
                    if (internal_parity != received_crc) err <= 1'b1;
                    else err <= 1'b0;
                end
                else begin
                    if (crc_value != received_crc) err <= 1'b1;
                    else err <= 1'b0;
                end
            end
            else begin
                err <= 1'b0;
            end
        end
    end

    // -------------------------------------------------------------------------
    // OUTPUT ASSIGNMENTS (Keeping your exact port signatures)
    // -------------------------------------------------------------------------
    assign crc_out = crc_value;
    
    // We keep the ports to match your Top module perfectly, 
    // but wire them cleanly since Hamming logic will handle actual correction.
    assign error_corrected = 1'b0;     
    assign corrected_data = dout;      

endmodule