// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

///////////////////////////////////////////////////////////////////////////////
//
// Description: RX channels for uDMA IP
//
///////////////////////////////////////////////////////////////////////////////
//
// Authors    : Antonio Pullini (pullinia@iis.ee.ethz.ch)
//
///////////////////////////////////////////////////////////////////////////////

`define log2(VALUE) ((VALUE) < ( 1 ) ? 0 : (VALUE) < ( 2 ) ? 1 : (VALUE) < ( 4 ) ? 2 : (VALUE) < ( 8 ) ? 3 : (VALUE) < ( 16 )  ? 4 : (VALUE) < ( 32 )  ? 5 : (VALUE) < ( 64 )  ? 6 : (VALUE) < ( 128 ) ? 7 : (VALUE) < ( 256 ) ? 8 : (VALUE) < ( 512 ) ? 9 : (VALUE) < ( 1024 ) ? 10 : (VALUE) < ( 2048 ) ? 11 : (VALUE) < ( 4096 ) ? 12 : (VALUE) < ( 8192 ) ? 13 : (VALUE) < ( 16384 ) ? 14 : (VALUE) < ( 32768 ) ? 15 : (VALUE) < ( 65536 ) ? 16 : (VALUE) < ( 131072 ) ? 17 : (VALUE) < ( 262144 ) ? 18 : (VALUE) < ( 524288 ) ? 19 : (VALUE) < ( 1048576 ) ? 20 : (VALUE) < ( 1048576 * 2 ) ? 21 : (VALUE) < ( 1048576 * 4 ) ? 22 : (VALUE) < ( 1048576 * 8 ) ? 23 : (VALUE) < ( 1048576 * 16 ) ? 24 : 25)

module udma_rx_channels
  #(
    parameter TRANS_SIZE        = 16,
    parameter L2_DATA_WIDTH     = 64,
    parameter DATA_WIDTH        = 32,
    parameter N_CHANNELS        = 8,
    parameter N_EXT_CHANNELS    = 8
    )
   (
    input  logic	                         clk_i,
    input  logic                           rstn_i,
    
    output logic                           l2_req_o,
    input  logic                           l2_gnt_i,
    output logic  [L2_DATA_WIDTH/8-1 : 0]  l2_be_o,
    output logic                 [31 : 0]  l2_addr_o,
    output logic    [L2_DATA_WIDTH-1 : 0]  l2_wdata_o,

    output logic        [DATA_WIDTH-1 : 0] filter_data_o,
    output logic                   [1 : 0] filter_datasize_o,
    output logic                           filter_valid_o,
    output logic                           filter_sot_o,
    output logic                           filter_eot_o,
    input  logic                           filter_ready_i,

    input  logic [N_CHANNELS-1:0]                            ch_valid_i,
    input  logic [N_CHANNELS-1:0]         [DATA_WIDTH-1 : 0] ch_data_i,
    input  logic [N_CHANNELS-1:0]                    [1 : 0] ch_datasize_i,
    input  logic [N_CHANNELS-1:0]                    [3 : 0] ch_destination_i,      
    output logic [N_CHANNELS-1:0]                            ch_ready_o,
    output logic [N_CHANNELS-1:0]                            ch_events_o,
    output logic [N_CHANNELS-1:0]                            ch_en_o,
    output logic [N_CHANNELS-1:0]                            ch_pending_o,
    output logic [N_CHANNELS-1:0]         [TRANS_SIZE-1 : 0] ch_curr_addr_o,
    output logic [N_CHANNELS-1:0]         [TRANS_SIZE-1 : 0] ch_bytes_left_o,

    input  logic [N_CHANNELS-1:0]         [TRANS_SIZE-1 : 0] cfg_startaddr_i,
    input  logic [N_CHANNELS-1:0]         [TRANS_SIZE-1 : 0] cfg_size_i,
    input  logic [N_CHANNELS-1:0]                            cfg_continuous_i,
    input  logic [N_CHANNELS-1:0]                            cfg_en_i,
    input  logic [N_CHANNELS-1:0]                            cfg_filter_i,
    input  logic [N_CHANNELS-1:0]                            cfg_clr_i,

    input  logic [N_EXT_CHANNELS-1:0]     [TRANS_SIZE-1 : 0] ext_ch_addr_i,
    input  logic [N_EXT_CHANNELS-1:0]                [1 : 0] ext_ch_datasize_i,
    input  logic [N_EXT_CHANNELS-1:0]                [3 : 0] ext_ch_destination_i,
    input  logic [N_EXT_CHANNELS-1:0]                        ext_ch_filter_i,
    input  logic [N_EXT_CHANNELS-1:0]                        ext_ch_sot_i,
    input  logic [N_EXT_CHANNELS-1:0]                        ext_ch_eot_i,
    input  logic [N_EXT_CHANNELS-1:0]                        ext_ch_valid_i,
    input  logic [N_EXT_CHANNELS-1:0]     [DATA_WIDTH-1 : 0] ext_ch_data_i,
    output logic [N_EXT_CHANNELS-1:0]                        ext_ch_ready_o

    );

    localparam ALIGN_BITS          = $clog2(L2_DATA_WIDTH/8);
    localparam N_CHANNELS_RX       = N_CHANNELS + N_EXT_CHANNELS;
    localparam LOG_N_CHANNELS      = `log2(N_CHANNELS_RX);

    localparam DATASIZE_BITS       = 2;
    localparam DEST_BITS           = 4;
    localparam SOT_EOT_BITS        = 2;

    localparam INTFIFO_L2_SIZE     = TRANS_SIZE + DATA_WIDTH + DEST_BITS + DATASIZE_BITS;
    localparam INTFIFO_FILTER_SIZE = DATA_WIDTH + DATASIZE_BITS + SOT_EOT_BITS;

    integer i;
   
   // Internal signals

    logic [N_CHANNELS-1:0] [TRANS_SIZE-1 : 0] s_curr_addr;

    logic                 [N_CHANNELS_RX-1:0] s_grant;
    logic                 [N_CHANNELS_RX-1:0] r_grant;
    logic                 [N_CHANNELS_RX-1:0] s_req;

    logic                [LOG_N_CHANNELS-1:0] s_grant_log;

    logic                    [N_CHANNELS-1:0] s_ch_en;

    logic                                     s_anygrant;
    logic                                     r_anygrant;

    logic                              [31:0] s_data;
    logic                              [31:0] r_data;

    logic                    [TRANS_SIZE-1:0] s_addr;

    logic                    [TRANS_SIZE-1:0] r_ext_addr;
    logic                                     r_ext_filter;
    logic                                     r_ext_sot;
    logic                                     r_ext_eot;

    logic                               [1:0] s_size;
    logic                               [1:0] r_size;

    logic                               [1:0] s_l2_transf_size;
    logic                    [DATA_WIDTH-1:0] s_l2_data;
    logic               [L2_DATA_WIDTH/8-1:0] s_l2_be;
    logic                    [TRANS_SIZE-1:0] s_l2_addr;

    logic               [INTFIFO_L2_SIZE-1:0] s_fifoin;
    logic               [INTFIFO_L2_SIZE-1:0] s_fifoout;

    logic           [INTFIFO_FILTER_SIZE-1:0] s_fifoin_filter;
    logic           [INTFIFO_FILTER_SIZE-1:0] s_fifoout_filter;

    logic                                     s_sample_indata;
    logic                                     s_sample_indata_l2;
    logic                                     s_sample_indata_filter;
    logic                    [N_CHANNELS-1:0] s_filter;
    logic                                     s_is_filter;

    logic                    [N_CHANNELS-1:0] s_ch_events;
    logic                    [N_CHANNELS-1:0] s_ch_sot;

    logic                                     s_eot;
    logic                                     s_sot;

    logic                                     s_push_l2;
    logic                                     s_push_filter;

    logic                              [31:0] s_l2_out_addr;
    logic                              [31:0] s_apb_out_addr;
    logic                              [31:0] s_clu_out_addr;

    assign ch_events_o    = s_ch_events;
    assign ch_curr_addr_o = s_curr_addr;
    assign ch_en_o        = s_ch_en;

    assign s_fifoin        = {r_size,s_addr[TRANS_SIZE-1:0],r_data};
    assign s_fifoin_filter = {s_sot,s_eot,s_grant_log,r_data};

    assign s_l2_data        = s_fifoout[DATA_WIDTH-1:0];
    assign s_l2_addr        = s_fifoout[TRANS_SIZE+DATA_WIDTH-1:DATA_WIDTH];
    assign s_l2_transf_size = s_fifoout[TRANS_SIZE+DATA_WIDTH+DATASIZE_BITS-1:TRANS_SIZE+DATA_WIDTH];
    assign s_l2_dest        = s_fifoout[TRANS_SIZE+DATA_WIDTH+DATASIZE_BITS+DEST_BITS-1:TRANS_SIZE+DATA_WIDTH+DATASIZE_BITS]; 

    assign s_req[N_CHANNELS-1:0]             = ch_valid_i & s_ch_en;
    assign s_req[N_CHANNELS_RX-1:N_CHANNELS] = ext_ch_valid_i;

    assign l2_be_o   = s_l2_be;

    assign filter_sot_o  = s_fifoout_filter[INTFIFO_FILTER_SIZE-1];
    assign filter_eot_o  = s_fifoout_filter[INTFIFO_FILTER_SIZE-2];
    assign filter_id_o   = s_fifoout_filter[INTFIFO_FILTER_SIZE-3:DATA_WIDTH];
    assign filter_data_o = s_fifoout_filter[DATA_WIDTH-1:0];

    assign s_sample_indata = s_sample_indata_filter & s_sample_indata_l2;
    assign s_push_l2     = r_anygrant & !s_is_filter;
    assign s_push_filter = r_anygrant &  s_is_filter;

    generate
      if(TRANS_SIZE < 24)
        assign s_l2_out_addr  = {  8'h1C,{(32-TRANS_SIZE-10){1'b0}},s_l2_addr[TRANS_SIZE-1:ALIGN_BITS],{ALIGN_BITS{1'b0}}};
      else
        assign s_l2_out_addr  = {  8'h1C,s_l2_addr[23:ALIGN_BITS],{ALIGN_BITS{1'b0}}};
      if(TRANS_SIZE < 20)
        assign s_apb_out_addr  = { 12'h1A1,{(32-TRANS_SIZE-10){1'b0}},s_l2_addr[TRANS_SIZE-1:ALIGN_BITS],{ALIGN_BITS{1'b0}}};
      else
        assign s_apb_out_addr  = { 12'h1A1,s_l2_addr[19:ALIGN_BITS],{ALIGN_BITS{1'b0}}};
      if(TRANS_SIZE < 24)
        assign s_clu_out_addr  = {  8'h10,{(32-TRANS_SIZE-10){1'b0}},s_l2_addr[TRANS_SIZE-1:ALIGN_BITS],{ALIGN_BITS{1'b0}}};
      else
        assign s_clu_out_addr  = {  8'h10,s_l2_addr[23:ALIGN_BITS],{ALIGN_BITS{1'b0}}};
    endgenerate

    udma_arbiter #(
      .N(N_CHANNELS_RX),
      .S(LOG_N_CHANNELS)
      ) u_arbiter (
        .clk_i       ( clk_i           ),
        .rstn_i      ( rstn_i          ),
        .req_i       ( s_req           ),
        .grant_o     ( s_grant         ),
        .grant_ack_i ( s_sample_indata ),
        .anyGrant_o  ( s_anygrant      )
      );

    io_generic_fifo #(
      .DATA_WIDTH(INTFIFO_L2_SIZE),
      .BUFFER_DEPTH(4)
      ) u_fifo (
        .clk_i      ( clk_i              ),
        .rstn_i     ( rstn_i             ),
        .elements_o ( ),
        .clr_i      ( 1'b0               ),
        .data_o     ( s_fifoout          ),
        .valid_o    ( l2_req_o           ),
        .ready_i    ( l2_gnt_i           ),
        .valid_i    ( s_push_l2          ),
        .data_i     ( s_fifoin           ),
        .ready_o    ( s_sample_indata_l2 )
        );

    io_generic_fifo #(
      .DATA_WIDTH(INTFIFO_FILTER_SIZE),
      .BUFFER_DEPTH(4)
      ) u_filter_fifo (
        .clk_i      ( clk_i                  ),
        .rstn_i     ( rstn_i                 ),
        .elements_o ( ),
        .clr_i      ( 1'b0                   ),
        .data_o     ( s_fifoout_filter       ),
        .valid_o    ( filter_valid_o         ),
        .ready_i    ( filter_ready_i         ),
        .valid_i    ( s_push_filter          ),
        .data_i     ( s_fifoin_filter        ),
        .ready_o    ( s_sample_indata_filter )
        );

    genvar j;
    generate
      for (j=0;j<N_CHANNELS;j++)
      begin
        udma_ch_addrgen #(
          .TRANS_SIZE(TRANS_SIZE)
        ) u_rx_ch_ctrl (
          .clk_i               ( clk_i               ),
          .rstn_i              ( rstn_i              ),
          .cfg_startaddr_i     ( cfg_startaddr_i[j]  ),
          .cfg_size_i          ( cfg_size_i[j]       ),
          .cfg_continuous_i    ( cfg_continuous_i[j] ),
          .cfg_filter_i        ( cfg_filter_i[j]     ),
          .cfg_en_i            ( cfg_en_i[j]         ),
          .cfg_clr_i           ( cfg_clr_i[j]        ),
          .int_datasize_i      ( r_size              ),
          .int_not_stall_i     ( s_sample_indata     ),
          .int_ch_curr_addr_o  ( s_curr_addr[j]      ),
          .int_ch_bytes_left_o ( ch_bytes_left_o[j]  ),
          .int_ch_grant_i      ( r_grant[j]          ),
          .int_ch_en_o         ( ),
          .int_ch_en_prev_o    ( s_ch_en[j]          ),
          .int_ch_pending_o    ( ch_pending_o[j]     ),
          .int_ch_sot_o        ( s_ch_sot[j]         ),
          .int_ch_events_o     ( s_ch_events[j]      ),
          .int_filter_o        ( s_filter[j]         )
        );
      end
    endgenerate

    always_comb 
    begin
      case(s_l2_dest)
        'h0:
          l2_addr_o = s_l2_out_addr;
        'h1:
          l2_addr_o = s_apb_out_addr;
        'h2:
          l2_addr_o = s_clu_out_addr;
        default:
          l2_addr_o = s_l2_out_addr;
      endcase
    end

    always_comb 
    begin
      s_grant_log = 0;
      for(int i=0;i<N_CHANNELS_RX;i++)
        if(r_grant[i])
          s_grant_log = i;    
    end

    always_comb 
    begin: inside_mux
      s_addr      =  'h0;
      s_is_filter = 1'b0;
      s_eot       = 1'b0;
      s_sot       = 1'b0;
      for(int i=0;i<N_CHANNELS;i++)
      begin
        if(r_grant[i])
        begin
          s_addr      = s_curr_addr[i];
          s_is_filter = s_filter[i];
          s_eot       = s_ch_events[i];
          s_sot       = s_ch_sot[i];
        end
      end
      for(int i=0;i<N_EXT_CHANNELS;i++)
      begin
        if(r_grant[N_CHANNELS+i])
        begin
          s_addr      = r_ext_addr;
          s_is_filter = r_ext_filter;
          s_sot       = r_ext_sot;
          s_eot       = r_ext_eot;
        end
      end
    end


    always_comb
    begin: input_mux
      s_size = 0;
      s_data = 0;
      for(int i=0;i<N_CHANNELS;i++)
      begin
        if(s_grant[i])
        begin
          s_size = ch_datasize_i[i];
          s_data = ch_data_i[i];
          ch_ready_o[i] = s_sample_indata;
        end
        else
          ch_ready_o[i] = 1'b0; 
      end
      for(int i=0;i<N_EXT_CHANNELS;i++) 
      begin
        if(s_grant[N_CHANNELS+i])
        begin
          ext_ch_ready_o[i] = s_sample_indata;
          s_size = ext_ch_datasize_i[i];
          s_data = ext_ch_data_i[i];
        end
        else
          ext_ch_ready_o[i] = 1'b0;
      end
    end
      

    always_ff @(posedge clk_i or negedge rstn_i) 
    begin : ff_data
      if(~rstn_i) begin
         r_data       <=  'h0;
         r_grant      <=  'h0;
         r_anygrant   <=  'h0;
         r_size       <=  'h0;
         r_ext_addr   <=  'h0;
         r_ext_filter <= 1'b0;
         r_ext_sot    <=  'h0;
         r_ext_eot    <=  'h0;
      end else begin
         if (s_sample_indata)
         begin
              r_data     <= s_data;
              r_size     <= s_size;
              r_grant    <= s_grant;
              r_anygrant <= s_anygrant;
              for(int i=0; i<N_EXT_CHANNELS;i++)
                if(s_grant[N_CHANNELS+i])
                begin
                  r_ext_addr   <= ext_ch_addr_i[i];
                  r_ext_filter <= ext_ch_filter_i[i];
                  r_ext_sot    <= ext_ch_sot_i[i];
                  r_ext_eot    <= ext_ch_eot_i[i];
                end
         end
      end
    end
   
    generate
      if (L2_DATA_WIDTH == 64)
      begin   
        always_comb
        begin
          case (s_l2_transf_size)
          2'h0:
                begin
                   if     (s_l2_addr[2:0] == 3'b000) s_l2_be = 8'b00000001;
                   else if(s_l2_addr[2:0] == 3'b001) s_l2_be = 8'b00000010;
                   else if(s_l2_addr[2:0] == 3'b010) s_l2_be = 8'b00000100;
                   else if(s_l2_addr[2:0] == 3'b011) s_l2_be = 8'b00001000;
                   else if(s_l2_addr[2:0] == 3'b100) s_l2_be = 8'b00010000;
                   else if(s_l2_addr[2:0] == 3'b101) s_l2_be = 8'b00100000;
                   else if(s_l2_addr[2:0] == 3'b110) s_l2_be = 8'b01000000;
                   else                              s_l2_be = 8'b10000000;
                end
          2'h1:
                begin
                   if(s_l2_addr[2:1] == 2'b00)      s_l2_be = 8'b00000011;
                   else if(s_l2_addr[2:1] == 2'b01) s_l2_be = 8'b00001100;
                   else if(s_l2_addr[2:1] == 2'b10) s_l2_be = 8'b00110000;
                   else                             s_l2_be = 8'b11000000;
                end
          2'h2: 
                begin
                   if(s_l2_addr[2] == 1'b0)         s_l2_be = 8'b00001111;
                   else                             s_l2_be = 8'b11110000;
                end
          default:                                  s_l2_be = 8'b00000000;  // default to 64-bit access
          endcase 
      end

      always_comb
      begin
        case (s_l2_be)
          8'b00001111: l2_wdata_o = {32'h0, s_l2_data[31:0]       };
          8'b11110000: l2_wdata_o = {       s_l2_data[31:0], 32'h0};
          8'b00000011: l2_wdata_o = {48'h0, s_l2_data[15:0]       };
          8'b00001100: l2_wdata_o = {32'h0, s_l2_data[15:0], 16'h0};
          8'b00110000: l2_wdata_o = {16'h0, s_l2_data[15:0], 32'h0};
          8'b11000000: l2_wdata_o = {       s_l2_data[15:0], 48'h0};
          8'b00000001: l2_wdata_o = {56'h0, s_l2_data[7:0]        };
          8'b00000010: l2_wdata_o = {48'h0, s_l2_data[7:0],   8'h0};
          8'b00000100: l2_wdata_o = {40'h0, s_l2_data[7:0],  16'h0};
          8'b00001000: l2_wdata_o = {32'h0, s_l2_data[7:0],  24'h0};
          8'b00010000: l2_wdata_o = {24'h0, s_l2_data[7:0],  32'h0};
          8'b00100000: l2_wdata_o = {16'h0, s_l2_data[7:0],  40'h0};
          8'b01000000: l2_wdata_o = { 8'h0, s_l2_data[7:0],  48'h0};
          8'b10000000: l2_wdata_o = {       s_l2_data[7:0],  56'h0};
          default: l2_wdata_o = 64'hDEADABBADEADBEEF;  // Shouldn't be possible
        endcase
      end
    end
    else if (L2_DATA_WIDTH == 32)
    begin
        always_comb
        begin
          case (s_l2_transf_size)
          2'h0:
                begin
                   if     (s_l2_addr[1:0] == 2'b00) s_l2_be = 4'b0001;
                   else if(s_l2_addr[1:0] == 2'b01) s_l2_be = 4'b0010;
                   else if(s_l2_addr[1:0] == 2'b10) s_l2_be = 4'b0100;
                   else                             s_l2_be = 4'b1000;
                end
          2'h1:
                begin
                   if(s_l2_addr[1] == 1'b0)         s_l2_be = 4'b0011;
                   else                             s_l2_be = 4'b1100;
                end
          2'h2: 
                begin
                                                    s_l2_be = 4'b1111;
                end
          default:                                  s_l2_be = 4'b0000; 
          endcase 
      end
      
      always_comb
      begin
        case (s_l2_be)
          4'b1111: l2_wdata_o =         s_l2_data[31:0];
          4'b0011: l2_wdata_o = {16'h0, s_l2_data[15:0]       };
          4'b1100: l2_wdata_o = {       s_l2_data[15:0], 16'h0};
          4'b0001: l2_wdata_o = {24'h0, s_l2_data[7:0]        };
          4'b0010: l2_wdata_o = {16'h0, s_l2_data[7:0],   8'h0};
          4'b0100: l2_wdata_o = { 8'h0, s_l2_data[7:0],  16'h0};
          4'b1000: l2_wdata_o = {       s_l2_data[7:0],  24'h0};
          default: l2_wdata_o = 32'hDEADBEEF;  // Shouldn't be possible
        endcase
      end
    end
  endgenerate
endmodule
