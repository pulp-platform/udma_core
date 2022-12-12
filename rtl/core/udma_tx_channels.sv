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
// Description: TX channels for uDMA IP
//
///////////////////////////////////////////////////////////////////////////////
//
// Authors    : Antonio Pullini (pullinia@iis.ee.ethz.ch)
//            : Alfio Di Mauro   (adimauro@iis.ee.ethz.ch)
//
///////////////////////////////////////////////////////////////////////////////

`include "udma_core_defines.svh"

module udma_tx_channels

  import udma_pkg::ch_addr_t;
  import udma_pkg::ch_transize_t;
  import udma_pkg::ch_data_t;
  import udma_pkg::ch_datasize_t;
  import udma_pkg::ch_dest_t;
  import udma_pkg::ch_stream_t;
  import udma_pkg::ch_streamid_t;
  import udma_pkg::ch_byterel_addr_t;

  #(
    parameter N_STREAMS      = 4,
    parameter L2_AWIDTH_NOAL = 20,
    parameter L2_DATA_WIDTH  = 64,
    parameter DATA_WIDTH     = 32,
    parameter N_LIN_CHANNELS = 8,
    parameter N_EXT_CHANNELS = 8,
    localparam N_TOT_EXT_CHANNELS = N_EXT_CHANNELS + N_STREAMS,
    parameter TRANS_SIZE     = 16,
    parameter STREAM_ID_WIDTH = 1
    )
   (
    input  logic	                        clk_i,
    input  logic                          rstn_i,
    
    output logic                           l2_req_o,
    input  logic                           l2_gnt_i,
    output logic                 [31 : 0]  l2_addr_o,

    input  logic    [L2_DATA_WIDTH-1 : 0]  l2_rdata_i,
    input  logic                           l2_rvalid_i,

    UDMA_EXT_CH.tx_out                     str_ext_ch[N_STREAMS-1:0],
    UDMA_EXT_CH.tx_out                     ext_ch[N_EXT_CHANNELS-1:0],
    UDMA_LIN_CH.tx_out                     lin_ch[N_LIN_CHANNELS-1:0],

    input logic [32-L2_AWIDTH_NOAL-1:0]    l2_src_i
    );

    localparam  DATASIZE_WIDTH = 2;
    localparam  DEST_WIDTH     = 2;

    localparam N_CHANNELS_TX  = N_LIN_CHANNELS+N_TOT_EXT_CHANNELS;
    localparam ALIGN_BITS     = $clog2(L2_DATA_WIDTH/8);
    localparam LOG_N_CHANNELS = (N_CHANNELS_TX) > 1 ? $clog2(N_CHANNELS_TX) : 1;
    localparam INTFIFO_SIZE   = L2_AWIDTH_NOAL + LOG_N_CHANNELS + DATASIZE_WIDTH + DEST_WIDTH;//store addr_data and size and request

    UDMA_EXT_CH ext_ch_int[N_TOT_EXT_CHANNELS-1:0](.clk_i(clk_i));

    // we need to split str_ext_ch and ext_ch into ext_int_ch
    `MERGE_EXT_CHANNEL_ARRAYS(str_ext_ch,ext_ch,ext_ch_int,N_STREAMS,N_EXT_CHANNELS)
   
   // Internal signals

   ch_datasize_t [N_LIN_CHANNELS-1:0] s_lin_datasize   ;
   ch_dest_t [N_LIN_CHANNELS-1:0]     s_lin_destination;
   //logic [N_LIN_CHANNELS-1:0]         s_lin_req        ;
   //logic [N_LIN_CHANNELS-1:0]         s_lin_gnt        ;
   logic [N_LIN_CHANNELS-1:0]         s_lin_valid      ;
   ch_data_t [N_LIN_CHANNELS-1:0]     s_lin_data       ;
   //ch_addr_t [N_LIN_CHANNELS-1:0]     s_lin_curr_addr  ;

   ch_addr_t     [N_TOT_EXT_CHANNELS-1:0] s_ext_addr       ;
   ch_datasize_t [N_TOT_EXT_CHANNELS-1:0] s_ext_datasize   ;
   ch_dest_t     [N_TOT_EXT_CHANNELS-1:0] s_ext_destination;
   logic         [N_TOT_EXT_CHANNELS-1:0] s_ext_valid      ;
   ch_data_t     [N_TOT_EXT_CHANNELS-1:0] s_ext_data       ;

    logic        [N_CHANNELS_TX-1:0] s_grant;
    logic        [N_CHANNELS_TX-1:0] r_grant;
    logic        [N_CHANNELS_TX-1:0] s_req;
    logic        [N_CHANNELS_TX-1:0] s_gnt;
    logic       [LOG_N_CHANNELS-1:0] s_grant_log;
    logic        [N_CHANNELS_TX-1:0] s_ch_ready;
    logic       [N_LIN_CHANNELS-1:0] s_ch_en;
    logic       [LOG_N_CHANNELS-1:0] r_resp;
    logic       [LOG_N_CHANNELS-1:0] r_resp_dly;

    logic                        r_valid;

    logic                        s_anygrant;
    logic                        r_anygrant;

    logic                        s_send_req;

    logic                      [L2_AWIDTH_NOAL-1:0] s_addr;
    logic [N_CHANNELS_TX-1:0]  [L2_AWIDTH_NOAL-1:0] s_curr_addr;
    logic                      [L2_AWIDTH_NOAL-1:0] r_in_addr;

    //logic                  [1:0] s_size;
    logic       [DATA_WIDTH-1:0] s_data;
    logic                  [1:0] r_size;
    logic       [DATA_WIDTH-1:0] r_data;
    logic       [ALIGN_BITS-1:0] r_addr;

    logic                  [1:0] s_in_size;
    logic                  [1:0] r_in_size;
    logic                  [1:0] s_in_dest;
    logic                  [1:0] r_in_dest;

    logic         [INTFIFO_SIZE-1:0] s_fifoin;
    logic         [INTFIFO_SIZE-1:0] s_fifoout;

    logic       [ALIGN_BITS-1:0] s_fifo_addr_lsb;
    logic   [L2_AWIDTH_NOAL-1:0] s_fifo_l2_addr;
    logic       [DEST_WIDTH-1:0] s_fifo_l2_dest;
    logic                  [1:0] s_fifo_trans_size;
    logic   [LOG_N_CHANNELS-1:0] s_fifo_resp;

    logic [L2_AWIDTH_NOAL-ALIGN_BITS-1:0] s_l2_addr_na; //used for non aligned transfers

    logic s_l2_req;
    logic s_l2_gnt;

    logic s_stall;
    logic s_sample_indata;

    logic s_is_na;
    logic r_is_na;
    logic s_detect_na;

    enum logic {TX_IDLE,TX_NON_ALIGNED} r_tx_state,s_tx_state_next;

    `INTF_ARRAY_FIELD_TO_LOGIC_ARRAY(s_lin_datasize,lin_ch,datasize,N_LIN_CHANNELS)
    `INTF_ARRAY_FIELD_TO_LOGIC_ARRAY(s_lin_destination,lin_ch,destination,N_LIN_CHANNELS)
    `LOGIC_ARRAY_TO_INTF_ARRAY_FIELD(lin_ch,valid,s_lin_valid,N_LIN_CHANNELS)
    `LOGIC_ARRAY_TO_INTF_ARRAY_FIELD(lin_ch,data,s_lin_data,N_LIN_CHANNELS)

    `INTF_ARRAY_FIELD_TO_LOGIC_ARRAY(s_ext_addr,ext_ch_int,addr,N_TOT_EXT_CHANNELS)
    `INTF_ARRAY_FIELD_TO_LOGIC_ARRAY(s_ext_datasize,ext_ch_int,datasize,N_TOT_EXT_CHANNELS)
    `INTF_ARRAY_FIELD_TO_LOGIC_ARRAY(s_ext_destination,ext_ch_int,destination,N_TOT_EXT_CHANNELS)
    
    `LOGIC_ARRAY_TO_INTF_ARRAY_FIELD(ext_ch_int,valid,s_ext_valid,N_TOT_EXT_CHANNELS)
    `LOGIC_ARRAY_TO_INTF_ARRAY_FIELD(ext_ch_int,data,s_ext_data,N_TOT_EXT_CHANNELS)

    //assign lin_curr_addr_o = s_curr_addr;
    `LOGIC_ARRAY_TO_INTF_ARRAY_FIELD(lin_ch,curr_addr,s_curr_addr,N_LIN_CHANNELS)
    //assign lin_en_o = s_ch_en;
    `LOGIC_ARRAY_TO_INTF_ARRAY_FIELD(lin_ch,en,s_ch_en,N_LIN_CHANNELS)
    assign s_fifoin = {r_in_dest,s_grant_log,r_in_size,s_addr[L2_AWIDTH_NOAL-1:0]};

    assign s_fifo_l2_addr    = s_fifoout[L2_AWIDTH_NOAL-1:0];
    assign s_fifo_addr_lsb   = s_fifoout[ALIGN_BITS-1:0];
    assign s_fifo_trans_size = s_fifoout[L2_AWIDTH_NOAL+DATASIZE_WIDTH-1:L2_AWIDTH_NOAL];
    assign s_fifo_resp       = s_fifoout[L2_AWIDTH_NOAL+DATASIZE_WIDTH+LOG_N_CHANNELS-1:L2_AWIDTH_NOAL+DATASIZE_WIDTH];
    assign s_fifo_l2_dest    = s_fifoout[INTFIFO_SIZE-1:L2_AWIDTH_NOAL+DATASIZE_WIDTH+LOG_N_CHANNELS];

    assign s_l2_addr_na = s_fifo_l2_addr[L2_AWIDTH_NOAL-1:ALIGN_BITS] + 1; //ask for following word

    // we can't use the macro because of the and operation                            
    for (genvar i = 0; i < N_LIN_CHANNELS; i++) begin
      assign s_req[i] = lin_ch[i].req && s_ch_en[i];
    end 

    `INTF_ARRAY_FIELD_TO_LOGIC_ARRAY_OFFSET(s_req,ext_ch_int,req,N_TOT_EXT_CHANNELS,N_LIN_CHANNELS)
    //assign s_req[N_CHANNELS_TX-1:N_LIN_CHANNELS] = ext_req_i;

    assign s_gnt = s_sample_indata ? s_grant : 'h0;

    assign s_send_req = r_anygrant;

    assign l2_req_o = s_l2_req & ~s_stall;

    //assign lin_gnt_o = s_gnt[N_LIN_CHANNELS-1:0];
    `LOGIC_ARRAY_TO_INTF_ARRAY_FIELD(lin_ch,gnt,s_gnt,N_LIN_CHANNELS)

    //assign ext_gnt_o = s_gnt[N_CHANNELS_TX-1:N_LIN_CHANNELS];
    `LOGIC_ARRAY_TO_INTF_ARRAY_FIELD_OFFSET(ext_ch_int,gnt,s_gnt,N_TOT_EXT_CHANNELS,N_LIN_CHANNELS)

    always_comb 
    begin
      if(!s_is_na)
        l2_addr_o  = {{(32-L2_AWIDTH_NOAL){1'b0}},s_fifo_l2_addr[L2_AWIDTH_NOAL-1:ALIGN_BITS],{ALIGN_BITS{1'b0}}};
      else
        l2_addr_o  = {{(32-L2_AWIDTH_NOAL){1'b0}},s_l2_addr_na,{ALIGN_BITS{1'b0}}};

      case(s_fifo_l2_dest)
        2'b00:
        begin
            l2_addr_o[31:24]  = 8'h1C;
        end
        2'b01:
        begin
            l2_addr_o[31:20]  = 12'h1A1;
        end
        2'b10:
        begin
            l2_addr_o[31:24]  = 8'h10;
        end
        2'b11:
        begin
            l2_addr_o[31:L2_AWIDTH_NOAL] = l2_src_i; // custom prefix set in register file
        end
        default:
        begin
            l2_addr_o[31:24]  = 8'h1C;
        end
        endcase // s_fifo_l2_destination    
    end

    udma_arbiter #(
      .N(N_CHANNELS_TX),
      .S(LOG_N_CHANNELS)
      ) u_arbiter (
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .req_i(s_req),
        .grant_o(s_grant),
        .grant_ack_i(s_sample_indata),
        .anyGrant_o(s_anygrant)
      );

    io_generic_fifo #(
      .DATA_WIDTH(INTFIFO_SIZE),
      .BUFFER_DEPTH(4)
      ) u_fifo (
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .elements_o(),
        .clr_i(1'b0),
        .data_o(s_fifoout),
        .valid_o(s_l2_req),
        .ready_i(s_l2_gnt),
        .valid_i(s_send_req),
        .data_i(s_fifoin),
        .ready_o(s_sample_indata)
        );

    genvar j;
    generate
      for (j=0;j<N_LIN_CHANNELS;j++) 
      begin: tx_channels
        udma_ch_addrgen #(
          .L2_AWIDTH_NOAL(L2_AWIDTH_NOAL),
          .TRANS_SIZE(TRANS_SIZE),
          .STREAM_ID_WIDTH(STREAM_ID_WIDTH)
        ) u_tx_ch_ctrl (
          .clk_i              ( clk_i                   ),
          .rstn_i             ( rstn_i                  ),
          .cfg_startaddr_i    ( lin_ch[j].startaddr     ),
          .cfg_size_i         ( lin_ch[j].size          ),
          .cfg_continuous_i   ( lin_ch[j].continuous    ),
          .cfg_stream_i       ( 2'b00                   ),
          .cfg_stream_id_i    ( {STREAM_ID_WIDTH{1'b0}} ),
          .cfg_en_i           ( lin_ch[j].cen           ),
          .cfg_clr_i          ( lin_ch[j].clr           ),
          .int_datasize_i     ( r_in_size               ),
          .int_not_stall_i    ( s_sample_indata         ),
          .int_ch_curr_addr_o ( s_curr_addr[j]          ),
          .int_ch_bytes_left_o( lin_ch[j].bytes_left    ),
          .int_ch_grant_i     ( r_grant[j]              ),
          .int_ch_curr_bytes_o(                         ),
          .int_ch_en_o        (                         ),
          .int_ch_sot_o       (                         ),
          .int_ch_en_prev_o   ( s_ch_en[j]              ),
          .int_ch_pending_o   ( lin_ch[j].pending       ),
          .int_ch_events_o    ( lin_ch[j].events        ),
          .int_stream_o       ( lin_ch[j].stream        ),
          .int_stream_id_o    ( lin_ch[j].stream_id     )
        );
      end: tx_channels
    endgenerate

    always_comb 
    begin
      s_grant_log = 0;
      for(int i=0;i<N_CHANNELS_TX;i++)
        if(r_grant[i])
          s_grant_log = i;    
    end

    always_comb 
    begin: inside_mux
      s_addr      =  'h0;
      for(int i=0;i<N_LIN_CHANNELS;i++)
      begin
        if(r_grant[i])
        begin
          s_addr      = s_curr_addr[i];
        end
      end
      for(int i=0;i<N_TOT_EXT_CHANNELS;i++)
      begin
        if(r_grant[N_LIN_CHANNELS+i])
        begin
          s_addr      = r_in_addr;
        end
      end
    end


    always_comb
    begin: gen_size
      s_in_size = 0;
      s_in_dest = 0;
      for(int i=0;i<N_LIN_CHANNELS;i++)
        if(s_grant[i])
        begin
          s_in_size = s_lin_datasize[i];
          s_in_dest = s_lin_destination[i];
        end
      for(int i=0;i<N_TOT_EXT_CHANNELS;i++)
        if(s_grant[N_LIN_CHANNELS+i])
        begin
          s_in_size = s_ext_datasize[i];
          s_in_dest = s_ext_destination[i];
        end
    end

    always_comb
    begin: demux_data
      for(int i=0;i<N_LIN_CHANNELS;i++)
      begin
        if(r_resp_dly == i)
        begin
          s_lin_valid[i] = r_valid;
          s_lin_data[i]  = r_data;
        end
        else
        begin
          s_lin_valid[i] = 1'b0;
          s_lin_data[i]  = 'hDEADBEEF;
        end
      end
      for(int i=0;i<N_TOT_EXT_CHANNELS;i++)
      begin
        if(r_resp_dly == (N_LIN_CHANNELS+i))
        begin
          s_ext_valid[i] = r_valid;
          s_ext_data[i]  = r_data;
        end
        else
        begin
          s_ext_valid[i] = 1'b0;
          s_ext_data[i]  = 'hDEADBEEF;
        end
      end
    end
      
    //assign s_ch_ready[N_LIN_CHANNELS-1:0] = lin_ready_i;
    `INTF_ARRAY_FIELD_TO_LOGIC_ARRAY(s_ch_ready,lin_ch,ready,N_LIN_CHANNELS)
    
    //assign s_ch_ready[N_CHANNELS_TX-1:N_LIN_CHANNELS] = ext_ready_i;
    `INTF_ARRAY_FIELD_TO_LOGIC_ARRAY_OFFSET(s_ch_ready,ext_ch_int,ready,N_TOT_EXT_CHANNELS,N_LIN_CHANNELS)

    //this may happen only in burst mode when multiple reads are pipelined
    assign s_stall = |(~s_ch_ready & r_resp) & r_valid;    

    always_ff @(posedge clk_i or negedge rstn_i) 
    begin : ff_data
      if(~rstn_i) begin
        r_grant     <=  '0;
        r_anygrant  <=  '0;
        r_resp      <=  '0;
        r_resp_dly  <=  '0;
        r_valid     <=  '0;
        r_in_size   <=  '0;
        r_in_dest   <=  '0;
        r_size      <=  '0;
        r_addr      <=  '0; 
        r_data      <=  '0;
        r_in_addr   <=  '0;
        r_is_na     <=  '0;
        r_tx_state  <= TX_IDLE;
      end else begin
          r_tx_state  <= s_tx_state_next;
          r_valid     <= l2_rvalid_i & ~s_is_na;
          r_resp_dly  <= r_resp;
          r_is_na     <= s_is_na;

          if (l2_rvalid_i)
            r_data <= s_data;
          if (s_l2_req && l2_gnt_i && !s_is_na)
          begin
            r_resp     <= s_fifo_resp;
            r_size     <= s_fifo_trans_size;
            r_addr     <= s_fifo_addr_lsb;
          end
          
         if (s_sample_indata)
         begin
              r_in_size  <= s_in_size;
              r_in_dest  <= s_in_dest;
              r_grant    <= s_grant;
              r_anygrant <= s_anygrant;
              for(int i=0;i<N_TOT_EXT_CHANNELS;i++)
                if(s_grant[N_LIN_CHANNELS+i])
                  r_in_addr <= s_ext_addr[i];
         end
      end
    end

    always_comb begin : proc_TX_SM
      s_tx_state_next       = r_tx_state;
      s_l2_gnt = 1'b0;
      s_is_na  = 1'b0;
      case(r_tx_state)
        TX_IDLE:
        begin
          if(s_detect_na)
          begin
            s_l2_gnt = 1'b0;
            if(l2_gnt_i)
              s_tx_state_next = TX_NON_ALIGNED;
          end
          else
            s_l2_gnt = l2_gnt_i;
        end
        TX_NON_ALIGNED:
        begin
          s_is_na = 1'b1;
          s_l2_gnt = l2_gnt_i;
          if(l2_gnt_i)
            s_tx_state_next = TX_IDLE;
        end
      endcase
    end

    always_comb
    begin
      s_detect_na = 1'b0;
      case (s_fifo_trans_size)
      2'h1:
            begin
               if     (s_fifo_addr_lsb == 2'b11) s_detect_na = 1'b1;
            end
      2'h2:
            begin
               if     (s_fifo_addr_lsb[0] || s_fifo_addr_lsb[1]) s_detect_na = 1'b1;
            end
      endcase 
    end

    generate
      if (L2_DATA_WIDTH == 64)
      begin
        always_comb
        begin
          case (r_size)
          2'h0:
                begin
                   if     (r_addr == 3'b000) s_data = {24'h0,l2_rdata_i[7:0]};
                   else if(r_addr == 3'b001) s_data = {24'h0,l2_rdata_i[15:8]};
                   else if(r_addr == 3'b010) s_data = {24'h0,l2_rdata_i[23:16]};
                   else if(r_addr == 3'b011) s_data = {24'h0,l2_rdata_i[31:24]};
                   else if(r_addr == 3'b100) s_data = {24'h0,l2_rdata_i[39:32]};
                   else if(r_addr == 3'b101) s_data = {24'h0,l2_rdata_i[47:40]};
                   else if(r_addr == 3'b110) s_data = {24'h0,l2_rdata_i[55:48]};
                   else                      s_data = {24'h0,l2_rdata_i[63:56]};
                end
          2'h1:
                begin
                   if(r_addr[2:1] == 2'b00)      s_data = {16'h0,l2_rdata_i[15:0]};
                   else if(r_addr[2:1] == 2'b01) s_data = {16'h0,l2_rdata_i[31:16]};
                   else if(r_addr[2:1] == 2'b10) s_data = {16'h0,l2_rdata_i[47:32]};
                   else                          s_data = {16'h0,l2_rdata_i[63:48]};
                end
          2'h2: 
                begin
                   if(r_addr[2] == 1'b0)         s_data = l2_rdata_i[31:0];
                   else                          s_data = l2_rdata_i[63:32];
                end
          default:                               s_data = 32'hDEADBEEF;  // default to 32-bit access
          endcase 
        end
      end
      else if (L2_DATA_WIDTH == 32)
      begin
        always_comb
        begin
          s_data = r_data;
          case (r_size)
          2'h0:
                begin
                   if     (r_addr[1:0] == 2'b00) s_data = {24'h0,l2_rdata_i[7:0]};
                   else if(r_addr[1:0] == 2'b01) s_data = {24'h0,l2_rdata_i[15:8]};
                   else if(r_addr[1:0] == 2'b10) s_data = {24'h0,l2_rdata_i[23:16]};
                   else                          s_data = {24'h0,l2_rdata_i[31:24]};
                end
          2'h1:
                begin
                    if(s_is_na)
                                                  s_data = {24'h0,l2_rdata_i[31:24]};
                    else if(r_is_na)
                                                  s_data[15:8] = l2_rdata_i[7:0];
                    else
                    begin
                      if     (r_addr[1:0] == 2'b00) s_data = {16'h0,l2_rdata_i[15:0]};
                      else if(r_addr[1:0] == 2'b01) s_data = {16'h0,l2_rdata_i[23:8]};
                      else                          s_data = {16'h0,l2_rdata_i[31:16]};
                    end
                end
          2'h2: 
                begin
                    if(s_is_na)
                    begin
                        if     (r_addr[1:0] == 2'b01) s_data = {8'h0,l2_rdata_i[31:8]};
                        else if(r_addr[1:0] == 2'b10) s_data = {16'h0,l2_rdata_i[31:16]};
                        else                          s_data = {24'h0,l2_rdata_i[31:24]}; //(r_addr[1:0] == 2'b11)
                    end
                    else if(r_is_na)
                    begin
                        if     (r_addr[1:0] == 2'b01) s_data[31:24] = l2_rdata_i[7:0];
                        else if(r_addr[1:0] == 2'b10) s_data[31:16] = l2_rdata_i[15:0];
                        else                          s_data[31:8]  = l2_rdata_i[23:0]; //(r_addr[1:0] == 2'b11)
                    end
                    else
                      s_data = l2_rdata_i;
                end
          default:                               s_data = 32'hDEADBEEF;  // default to 32-bit access
          endcase 
        end
      end
    endgenerate



endmodule
