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
// Description: Top level of udma core block
//
///////////////////////////////////////////////////////////////////////////////
//
// Authors    : Antonio Pullini (pullinia@iis.ee.ethz.ch)
//            : Alfio Di Mauro  (adimauro@iis.ee.ethz.ch)
//
///////////////////////////////////////////////////////////////////////////////


module udma_core
  
  import udma_pkg::L2_DATA_WIDTH;  
  import udma_pkg::L2_ADDR_WIDTH;  
  import udma_pkg::CAM_DATA_WIDTH; 
  import udma_pkg::TRANS_SIZE;     
  import udma_pkg::L2_AWIDTH_NOAL; 
  import udma_pkg::STREAM_ID_WIDTH;
  import udma_pkg::DEST_SIZE;                   

  #(

    localparam DATA_WIDTH       = L2_DATA_WIDTH,
    parameter APB_ADDR_WIDTH    = 12,  //APB slaves are 4KB by default
    parameter N_RX_LIN_CHANNELS = 8,
    parameter N_RX_EXT_CHANNELS = 8,
    parameter N_TX_LIN_CHANNELS = 8,
    parameter N_TX_EXT_CHANNELS = 8,
    parameter N_PERIPHS         = 8,
    parameter N_STREAMS         = 4

    )
   (
    input  logic                        sys_clk_i,
    input  logic                        per_clk_i,

    input  logic                        dft_cg_enable_i,

    input  logic                        HRESETn,
    input  logic   [APB_ADDR_WIDTH-1:0] PADDR,
    input  logic                 [31:0] PWDATA,
    input  logic                        PWRITE,
    input  logic                        PSEL,
    input  logic                        PENABLE,
    output logic                 [31:0] PRDATA,
    output logic                        PREADY,
    output logic                        PSLVERR,

    input  logic                        event_valid_i,
    input  logic                  [7:0] event_data_i,
    output logic                        event_ready_o,
    output logic                  [3:0] event_o,

    output logic        [N_PERIPHS-1:0] periph_per_clk_o,
    output logic        [N_PERIPHS-1:0] periph_sys_clk_o,

    output logic                 [31:0] periph_data_to_o,
    output logic                  [4:0] periph_addr_o,
    output logic                        periph_rwn_o,
    input  logic [N_PERIPHS-1:0] [31:0] periph_data_from_i,
    output logic [N_PERIPHS-1:0]        periph_valid_o,
    input  logic [N_PERIPHS-1:0]        periph_ready_i,

    output logic                        rx_l2_req_o,
    input  logic                        rx_l2_gnt_i,
    output logic                 [31:0] rx_l2_addr_o,
    output logic  [L2_DATA_WIDTH/8-1:0] rx_l2_be_o,
    output logic    [L2_DATA_WIDTH-1:0] rx_l2_wdata_o,

    output logic                        tx_l2_req_o,
    input  logic                        tx_l2_gnt_i,
    output logic                 [31:0] tx_l2_addr_o,
    input  logic    [L2_DATA_WIDTH-1:0] tx_l2_rdata_i,
    input  logic                        tx_l2_rvalid_i,

    UDMA_EXT_CH.rx_out                  str_ch_tx[N_STREAMS-1:0],

    UDMA_LIN_CH.rx_in                   lin_ch_rx[N_RX_LIN_CHANNELS-1:0],
    UDMA_LIN_CH.tx_out                  lin_ch_tx[N_TX_LIN_CHANNELS-1:0],

    UDMA_EXT_CH.rx_in                   ext_ch_rx[N_RX_EXT_CHANNELS-1:0],
    UDMA_EXT_CH.tx_out                  ext_ch_tx[N_TX_EXT_CHANNELS-1:0]
    );

  localparam int unsigned               N_REAL_PERIPHS = N_PERIPHS + 1;
  localparam int unsigned               ADDR_PREFIX_WIDTH = 32-L2_AWIDTH_NOAL;

    logic [N_STREAMS-1:0]                             s_tx_ch_req;
    logic [N_STREAMS-1:0]      [L2_AWIDTH_NOAL-1 : 0] s_tx_ch_addr;
    logic [N_STREAMS-1:0]                     [1 : 0] s_tx_ch_datasize;
    logic [N_STREAMS-1:0]                             s_tx_ch_gnt;
    logic [N_STREAMS-1:0]                             s_tx_ch_valid;
    logic [N_STREAMS-1:0]          [DATA_WIDTH-1 : 0] s_tx_ch_data;
    logic [N_STREAMS-1:0]                             s_tx_ch_ready;

    logic [N_STREAMS-1:0]                             s_cfg_en;
    logic [N_STREAMS-1:0]      [L2_AWIDTH_NOAL-1 : 0] s_cfg_addr;
    logic [N_STREAMS-1:0]          [TRANS_SIZE-1 : 0] s_cfg_buffsize;
    logic [N_STREAMS-1:0]                     [1 : 0] s_cfg_datasize;

    logic                      [31:0] s_periph_data_to;
    logic                       [4:0] s_periph_addr;
    logic                             s_periph_rwn;
    logic [N_REAL_PERIPHS-1:0] [31:0] s_periph_data_from;
    logic [N_REAL_PERIPHS-1:0]        s_periph_valid;
    logic [N_REAL_PERIPHS-1:0]        s_periph_ready;

    logic                 s_periph_ready_from_cgunit;
    logic          [31:0] s_periph_data_from_cgunit;
    logic [N_PERIPHS-1:0] s_cg_value;

    logic               s_clk_core;
    logic               s_clk_core_en;

    logic [ADDR_PREFIX_WIDTH-1:0]           l2_dest_s; // custom L2 destination
                                                       // prefix (8 address
                                                       // MSBs), can be set in
                                                       // register file (address
                                                       // 0x10)

    logic [ADDR_PREFIX_WIDTH-1:0]             l2_src_s; // custom L2 src prefix
                                                        // (8 address MSBs), can
                                                        // be set in register
                                                        // file (address 0x14)

    assign periph_data_to_o = s_periph_data_to;
    assign periph_addr_o    = s_periph_addr;
    assign periph_rwn_o     = s_periph_rwn;
    assign periph_valid_o   = s_periph_valid[N_REAL_PERIPHS-1:1];
    assign s_periph_ready[0]                      = s_periph_ready_from_cgunit;
    assign s_periph_data_from[0]                  = s_periph_data_from_cgunit;
    assign s_periph_ready[N_REAL_PERIPHS-1:1]     = periph_ready_i;
    assign s_periph_data_from[N_REAL_PERIPHS-1:1] = periph_data_from_i;
   

  UDMA_EXT_CH str_ext_ch[N_STREAMS-1:0](.clk_i(s_clk_core));

  udma_tx_channels
  #(
      .L2_DATA_WIDTH(L2_DATA_WIDTH),
      .L2_AWIDTH_NOAL(L2_AWIDTH_NOAL),
      .DATA_WIDTH(32),
      .N_STREAMS(N_STREAMS),
      .N_LIN_CHANNELS(N_TX_LIN_CHANNELS),
      .N_EXT_CHANNELS(N_TX_EXT_CHANNELS),
      .STREAM_ID_WIDTH(STREAM_ID_WIDTH),
      .TRANS_SIZE(TRANS_SIZE)
    ) u_tx_channels (
      .clk_i                ( s_clk_core          ),
      .rstn_i               ( HRESETn             ),
    
      .l2_req_o             ( tx_l2_req_o         ),
      .l2_gnt_i             ( tx_l2_gnt_i         ),
      .l2_addr_o            ( tx_l2_addr_o        ),
      .l2_rdata_i           ( tx_l2_rdata_i       ),
      .l2_rvalid_i          ( tx_l2_rvalid_i      ),
      .str_ext_ch           ( str_ext_ch          ),
      .lin_ch               ( lin_ch_tx           ), //memory to peripherals (lin channels) 
      .ext_ch               ( ext_ch_tx           ),  //memory to peripherals
                                                      //(ext channels)
      .l2_src_i             ( l2_src_s            )
    );

  udma_rx_channels
  #(
      .L2_DATA_WIDTH(L2_DATA_WIDTH),
      .L2_AWIDTH_NOAL(L2_AWIDTH_NOAL),
      .DATA_WIDTH(32),
      .N_STREAMS(N_STREAMS),
      .N_LIN_CHANNELS(N_RX_LIN_CHANNELS),
      .N_EXT_CHANNELS(N_RX_EXT_CHANNELS),
      .STREAM_ID_WIDTH(STREAM_ID_WIDTH),
      .TRANS_SIZE(TRANS_SIZE)
    ) u_rx_channels (
      .clk_i               ( s_clk_core              ),
      .rstn_i              ( HRESETn                 ),

      .l2_req_o            ( rx_l2_req_o             ),
      .l2_addr_o           ( rx_l2_addr_o            ),
      .l2_be_o             ( rx_l2_be_o              ),
      .l2_wdata_o          ( rx_l2_wdata_o           ),
      .l2_gnt_i            ( rx_l2_gnt_i             ), 

      .str_ch              ( str_ch_tx               ),
      .str_ext_ch          ( str_ext_ch              ), // goes to tx channel
      .lin_ch              ( lin_ch_rx               ),
      .ext_ch              ( ext_ch_rx               ),

      .l2_dest_i           ( l2_dest_s               )
    );

    udma_apb_if #(
        .APB_ADDR_WIDTH(APB_ADDR_WIDTH),
        .N_PERIPHS(N_REAL_PERIPHS)
    ) u_apb_if (
        .PADDR(PADDR),
        .PWDATA(PWDATA),
        .PWRITE(PWRITE),
        .PSEL(PSEL),
        .PENABLE(PENABLE),
        .PRDATA(PRDATA),
        .PREADY(PREADY),
        .PSLVERR(PSLVERR),

        .periph_data_o(s_periph_data_to),
        .periph_addr_o(s_periph_addr),
        .periph_data_i(s_periph_data_from),
        .periph_ready_i(s_periph_ready),
        .periph_valid_o(s_periph_valid),
        .periph_rwn_o(s_periph_rwn)
    );

    udma_ctrl #(
      .L2_AWIDTH_NOAL(L2_AWIDTH_NOAL),
      .TRANS_SIZE    (TRANS_SIZE    ),
      .N_PERIPHS     (N_PERIPHS     )
    )  u_udma_ctrl (
        .clk_i(sys_clk_i),
        .rstn_i(HRESETn),

        .cfg_data_i(s_periph_data_to),
        .cfg_addr_i(s_periph_addr),
        .cfg_valid_i(s_periph_valid[0]),
        .cfg_rwn_i(s_periph_rwn),
        .cfg_data_o(s_periph_data_from_cgunit),
        .cfg_ready_o(s_periph_ready_from_cgunit),

        .cg_value_o(s_cg_value),
        .cg_core_o(s_clk_core_en),

        .rst_value_o(), //TODO 

        .event_valid_i(event_valid_i),
        .event_data_i (event_data_i),
        .event_ready_o(event_ready_o),

        .event_o(event_o),
        .l2_dest_o(l2_dest_s),
        .l2_src_o(l2_src_s)
    );

    pulp_clock_gating i_clk_gate_sys_udma
    (
        .clk_i(sys_clk_i),
        .en_i(s_clk_core_en),
        .test_en_i(dft_cg_enable_i),
        .clk_o(s_clk_core)
    );

    genvar i;
    generate
      for (i=0;i<N_PERIPHS;i++)
      begin
        pulp_clock_gating_async i_clk_gate_per
        (
            .clk_i(per_clk_i),
            .rstn_i(HRESETn),
            .en_async_i(s_cg_value[i]),
            .en_ack_o(),
            .test_en_i(dft_cg_enable_i),
            .clk_o(periph_per_clk_o[i])
        );
    
        pulp_clock_gating i_clk_gate_sys
        (
            .clk_i(s_clk_core),
            .en_i(s_cg_value[i]),
            .test_en_i(dft_cg_enable_i),
            .clk_o(periph_sys_clk_o[i])
        );
      end
    endgenerate

endmodule
