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
// Description: RX FIFO with clock domain crossing capabilities
//
///////////////////////////////////////////////////////////////////////////////
//
// Authors    : Antonio Pullini (pullinia@iis.ee.ethz.ch)
//
///////////////////////////////////////////////////////////////////////////////

module udma_dc_fifo #(
    parameter DATA_WIDTH = 32,
    parameter BUFFER_DEPTH = 8
) (
    input  logic                  src_clk_i,
    input  logic                  src_rstn_i,
    input  logic [DATA_WIDTH-1:0] src_data_i,
    input  logic                  src_valid_i,
    output logic                  src_ready_o,
    input  logic                  dst_clk_i,
    input  logic                  dst_rstn_i,
    output logic [DATA_WIDTH-1:0] dst_data_o,
    output logic                  dst_valid_o,
    input  logic                  dst_ready_i
    );

  if (BUFFER_DEPTH != 2**$clog2(BUFFER_DEPTH))
    $warning("Instantiating cdc fifo with buffer depth of %d instead of %d. Only powers of two are supported.", 2**$clog2(BUFFER_DEPTH), BUFFER_DEPTH);

  cdc_fifo_gray #(
    .WIDTH(DATA_WIDTH),
    .LOG_DEPTH($clog2(BUFFER_DEPTH)),
    .SYNC_STAGES(2)
  ) i_cdc_fifo (
    .src_clk_i,
    .src_rst_ni(src_rstn_i),
    .src_data_i,
    .src_valid_i,
    .src_ready_o,
    .dst_clk_i,
    .dst_rst_ni(dst_rstn_i),
    .dst_data_o,
    .dst_valid_o,
    .dst_ready_i
  );
endmodule
