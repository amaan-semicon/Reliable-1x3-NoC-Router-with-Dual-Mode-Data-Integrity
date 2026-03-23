`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.03.2026 22:31:51
// Design Name: 
// Module Name: router_top
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


module router_top (
    input  logic       clock,
    input  logic       resetn,
    input  logic       pkt_valid,
    input  logic [7:0] data_in,
    input  logic       read_enb_0,
    input  logic       read_enb_1,
    input  logic       read_enb_2,
    input  logic       parity_mode, // 0 for CRC, 1 for Parity (From your Register code)
    
    output logic [7:0] data_out_0,
    output logic [7:0] data_out_1,
    output logic [7:0] data_out_2,
    output logic       vld_out_0,
    output logic       vld_out_1,
    output logic       vld_out_2,
    output logic       err,
    output logic       busy
);

    // -------------------------------------------------------------------------
    // INTERNAL WIRES (The GLUE that connects everything)
    // -------------------------------------------------------------------------
    
    // FSM <-> Other Blocks
    logic detect_add, ld_state, lfd_state, full_state, rst_int_reg, write_enb_reg;
    
    // Register <-> Other Blocks
    logic parity_done, low_packet_valid, error_corrected;
    logic [7:0] dout, crc_out, corrected_data;
    
    // Synchronizer <-> Other Blocks
    logic fifo_full;
    logic [2:0] write_enb;
    logic soft_reset_0, soft_reset_1, soft_reset_2;
    
    // FIFOs <-> Other Blocks
    logic empty_0, empty_1, empty_2;
    logic full_0, full_1, full_2;

    // -------------------------------------------------------------------------
    // 1. INSTANTIATE FSM
    // -------------------------------------------------------------------------
    router_fsm U_FSM (
        .clock             (clock),
        .resetn            (resetn),
        .pkt_valid         (pkt_valid),
        .data_in           (data_in[1:0]), // FSM only needs first 2 bits for address
        .fifo_full         (fifo_full),
        .fifo_empty_0      (empty_0),
        .fifo_empty_1      (empty_1),
        .fifo_empty_2      (empty_2),
        .soft_reset_0      (soft_reset_0),
        .soft_reset_1      (soft_reset_1),
        .soft_reset_2      (soft_reset_2),
        .parity_done       (parity_done),
        .low_packet_valid  (low_packet_valid),
        
        .write_enb_reg     (write_enb_reg),
        .detect_add        (detect_add),
        .ld_state          (ld_state),
        .lfd_state         (lfd_state),
        .full_state        (full_state),
        .rst_int_reg       (rst_int_reg),
        .busy              (busy)
    );

    // -------------------------------------------------------------------------
    // 2. INSTANTIATE REGISTER (Exact Match with your updated code!)
    // -------------------------------------------------------------------------
    register_crc8 U_REGISTER (
        .clock             (clock),
        .resetn            (resetn),
        .pkt_valid         (pkt_valid),
        .data_in           (data_in),
        .fifo_full         (fifo_full),
        .detect_add        (detect_add),
        .ld_state          (ld_state),
        .full_state        (full_state),
        .lfd_state         (lfd_state),
        .rst_int_reg       (rst_int_reg),
        .parity_mode       (parity_mode),
        
        .dout              (dout),       // Data output that goes to FIFOs
        .err               (err),        // Top level Error output
        .parity_done       (parity_done),
        .low_packet_valid  (low_packet_valid),
        .crc_out           (crc_out),
        .error_corrected   (error_corrected),
        .corrected_data    (corrected_data)
    );

    // -------------------------------------------------------------------------
    // 3. INSTANTIATE SYNCHRONIZER
    // -------------------------------------------------------------------------
    router_sync U_SYNC (
        .clock             (clock),
        .resetn            (resetn),
        .data_in           (data_in[1:0]),
        .detect_add        (detect_add),
        .write_enb_reg     (write_enb_reg),
        .read_enb_0        (read_enb_0),
        .read_enb_1        (read_enb_1),
        .read_enb_2        (read_enb_2),
        .empty_0           (empty_0),
        .empty_1           (empty_1),
        .empty_2           (empty_2),
        .full_0            (full_0),
        .full_1            (full_1),
        .full_2            (full_2),
        
        .write_enb         (write_enb), // 3-bit array
        .fifo_full         (fifo_full),
        .vld_sync_0        (vld_out_0), // Goes directly to top level output
        .vld_sync_1        (vld_out_1),
        .vld_sync_2        (vld_out_2),
        .soft_reset_0      (soft_reset_0),
        .soft_reset_1      (soft_reset_1),
        .soft_reset_2      (soft_reset_2)
    );

    // -------------------------------------------------------------------------
    // 4. INSTANTIATE 3 FIFOs (Destination 0, 1, 2)
    // -------------------------------------------------------------------------
    router_fifo U_FIFO_0 (
        .clock       (clock),
        .resetn      (resetn),
        .soft_reset  (soft_reset_0),
        .write_enb   (write_enb[0]),
        .read_enb    (read_enb_0),
        .lfd_state   (lfd_state),
        .data_in     (dout),        // FIFOs take datapath 'dout' from register
        .empty       (empty_0),
        .full        (full_0),
        .data_out    (data_out_0)
    );

    router_fifo U_FIFO_1 (
        .clock       (clock),
        .resetn      (resetn),
        .soft_reset  (soft_reset_1),
        .write_enb   (write_enb[1]),
        .read_enb    (read_enb_1),
        .lfd_state   (lfd_state),
        .data_in     (dout),
        .empty       (empty_1),
        .full        (full_1),
        .data_out    (data_out_1)
    );

    router_fifo U_FIFO_2 (
        .clock       (clock),
        .resetn      (resetn),
        .soft_reset  (soft_reset_2),
        .write_enb   (write_enb[2]),
        .read_enb    (read_enb_2),
        .lfd_state   (lfd_state),
        .data_in     (dout),
        .empty       (empty_2),
        .full        (full_2),
        .data_out    (data_out_2)
    );

endmodule
