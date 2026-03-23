`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.03.2026 21:09:44
// Design Name: 
// Module Name: router_fSM
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


module router_fsm (
    input  logic       clock,
    input  logic       resetn,
    input  logic       pkt_valid,
    input  logic [1:0] data_in,
    input  logic       fifo_full,
    input  logic       fifo_empty_0,
    input  logic       fifo_empty_1,
    input  logic       fifo_empty_2,
    input  logic       soft_reset_0,
    input  logic       soft_reset_1,
    input  logic       soft_reset_2,
    input  logic       parity_done,
    input  logic       low_packet_valid,

    output logic       write_enb_reg,
    output logic       detect_add,
    output logic       ld_state,
    output logic       lfd_state,
    output logic       full_state,
    output logic       rst_int_reg,
    output logic       busy
);

    // -------------------------------------------------------------------------
    // 1. STATE DEFINITIONS (7 Standard States of a 1x3 Router)
    // -------------------------------------------------------------------------
    typedef enum logic [2:0] {
        DECODE_ADDRESS     = 3'b000,
        WAIT_TILL_EMPTY    = 3'b001,
        LOAD_FIRST_DATA    = 3'b010,
        LOAD_DATA          = 3'b011,
        LOAD_PARITY        = 3'b100,
        FIFO_FULL_STATE    = 3'b101,
        CHECK_PARITY_ERROR = 3'b110
    } state_t;

    state_t present_state, next_state;
    
    // Internal register to remember the address 
    // (because data_in changes after the first clock cycle)
    logic [1:0] addr;

    // -------------------------------------------------------------------------
    // 2. ADDRESS LATCH LOGIC
    // -------------------------------------------------------------------------
    always_ff @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            addr <= 2'b11; // 11 means invalid
        end
        else if ((present_state == DECODE_ADDRESS) && pkt_valid) begin
            addr <= data_in; // Save destination address (00, 01, or 10)
        end
    end

    // -------------------------------------------------------------------------
    // 3. STATE REGISTER (Sequential)
    // -------------------------------------------------------------------------
    always_ff @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            present_state <= DECODE_ADDRESS;
        end
        else if (soft_reset_0 || soft_reset_1 || soft_reset_2) begin
            // Agar koi timeout hota hai, router reset ho ke idle me chala jaye
            present_state <= DECODE_ADDRESS; 
        end
        else begin
            present_state <= next_state;
        end
    end

    // -------------------------------------------------------------------------
    // 4. NEXT STATE LOGIC (Combinational)
    // -------------------------------------------------------------------------
    always_comb begin
        next_state = present_state; // Default: Stay in current state

        case (present_state)
            
            DECODE_ADDRESS: begin
                if (pkt_valid) begin
                    // Check if addressed FIFO is empty
                    if ((data_in == 2'b00 && fifo_empty_0) ||
                        (data_in == 2'b01 && fifo_empty_1) ||
                        (data_in == 2'b10 && fifo_empty_2)) begin
                        next_state = LOAD_FIRST_DATA;
                    end
                    // If addressed FIFO is NOT empty, wait!
                    else if ((data_in == 2'b00 && !fifo_empty_0) ||
                             (data_in == 2'b01 && !fifo_empty_1) ||
                             (data_in == 2'b10 && !fifo_empty_2)) begin
                        next_state = WAIT_TILL_EMPTY;
                    end
                end
            end

            WAIT_TILL_EMPTY: begin
                // Check the latched address, if it's empty now, proceed
                if ((addr == 2'b00 && fifo_empty_0) ||
                    (addr == 2'b01 && fifo_empty_1) ||
                    (addr == 2'b10 && fifo_empty_2)) begin
                    next_state = LOAD_FIRST_DATA;
                end
            end

            LOAD_FIRST_DATA: begin
                next_state = LOAD_DATA; // Always move to LOAD_DATA next
            end

            LOAD_DATA: begin
                if (fifo_full) begin
                    next_state = FIFO_FULL_STATE; // Emergency pause!
                end
                else if (!fifo_full && !pkt_valid) begin
                    next_state = LOAD_PARITY;     // Data done, go check CRC
                end
                else begin
                    next_state = LOAD_DATA;       // Keep loading data
                end
            end

            FIFO_FULL_STATE: begin
                // Once FIFO has space again, resume where we left off
                if (!fifo_full) begin
                    if (pkt_valid)
                        next_state = LOAD_DATA;
                    else
                        next_state = LOAD_PARITY;
                end
            end

            LOAD_PARITY: begin
                next_state = CHECK_PARITY_ERROR; // Unconditional jump
            end

            CHECK_PARITY_ERROR: begin
                // Router decides what to do after checking error
                if (fifo_full)
                    next_state = FIFO_FULL_STATE;
                else
                    next_state = DECODE_ADDRESS; // Ready for next packet!
            end
            
            default: next_state = DECODE_ADDRESS;
        endcase
    end

    // -------------------------------------------------------------------------
    // 5. OUTPUT ASSIGNMENTS (Control Signals for Datapath & Sync)
    // -------------------------------------------------------------------------
    
    assign detect_add    = (present_state == DECODE_ADDRESS);
    assign lfd_state     = (present_state == LOAD_FIRST_DATA);
    assign ld_state      = (present_state == LOAD_DATA);
    assign full_state    = (present_state == FIFO_FULL_STATE);
    assign rst_int_reg   = (present_state == CHECK_PARITY_ERROR);
    
    // Write Enable goes HIGH when we are actively putting Header, Data, or CRC into FIFO
    assign write_enb_reg = ((present_state == LOAD_DATA) || 
                            (present_state == LOAD_PARITY) || 
                            (present_state == LOAD_FIRST_DATA));
    
    // Busy is HIGH when FSM is processing a packet and CANNOT accept a NEW header.
    // Sender tool looks at 'busy' before sending a new packet.
    assign busy = ((present_state == LOAD_FIRST_DATA) || 
                   (present_state == LOAD_PARITY) || 
                   (present_state == FIFO_FULL_STATE) || 
                   (present_state == WAIT_TILL_EMPTY) || 
                   (present_state == CHECK_PARITY_ERROR) ||
                   // Latch condition: If it's DECODE_ADDRESS but we just started a packet
                   (present_state == DECODE_ADDRESS && pkt_valid));

endmodule