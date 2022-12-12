/* 
 * Copyright (C) 2018-2020 ETH Zurich, University of Bologna
 * Copyright and related rights are licensed under the Solderpad Hardware
 * License, Version 0.51 (the "License"); you may not use this file except in
 * compliance with the License.  You may obtain a copy of the License at
 *
 *                http://solderpad.org/licenses/SHL-0.51. 
 *
 * Unless required by applicable law
 * or agreed to in writing, software, hardware and materials distributed under
 * this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
 * CONDITIONS OF ANY KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations under the License.
 *
 * Alfio Di Mauro <adimauro@iis.ee.ethz.ch>
 *
 */
`define INTF_ARRAY_FIELD_TO_LOGIC_ARRAY(array,interface,field,size) \
	for (genvar i = 0; i < size; i++) begin                         \
		assign array[i] = interface[i].field;                       \
	end   

`define INTF_ARRAY_FIELD_TO_LOGIC_ARRAY_OFFSET(array,interface,field,size,start) \
	for (genvar i = 0; i < size; i++) begin                                      \
		assign array[i + start] = interface[i].field;                            \
	end                                                             

`define LOGIC_ARRAY_TO_INTF_ARRAY_FIELD(interface,field,array,size) \
	for (genvar i = 0; i < size; i++) begin                         \
		assign interface[i].field = array[i];                       \
	end 

`define LOGIC_ARRAY_TO_INTF_ARRAY_FIELD_OFFSET(interface,field,array,size,start) \
	for (genvar i = 0; i < size; i++) begin                                      \
		assign interface[i].field = array[i + start];                            \
	end 

`define MERGE_EXT_CHANNEL_ARRAYS(ext_in0,ext_in1,ext_out,NIN0,NIN1)    \
      for(genvar i=0;i<NIN0;i++) begin                                 \
        assign ext_out[i].req      = ext_in0[i].req;                   \
        assign ext_out[i].datasize = ext_in0[i].datasize;              \
        assign ext_out[i].destination = ext_in0[i].destination;        \
        assign ext_out[i].addr     = ext_in0[i].addr;                  \
        assign ext_in0[i].gnt      = ext_out[i].gnt;                   \
        assign ext_in0[i].valid    = ext_out[i].valid;                 \
        assign ext_in0[i].data     = ext_out[i].data;                  \
        assign ext_out[i].ready    = ext_in0[i].ready;                 \
      end                                                              \
      for(genvar i=0;i<NIN1;i++) begin                                 \
      	assign ext_out[NIN0 + i].req      = ext_in1[i].req;            \
      	assign ext_out[NIN0 + i].datasize = ext_in1[i].datasize;       \
      	assign ext_out[NIN0 + i].destination = ext_in1[i].destination; \
      	assign ext_out[NIN0 + i].addr     = ext_in1[i].addr;           \
      	assign ext_in1[i].gnt      = ext_out[NIN0 + i].gnt;            \
      	assign ext_in1[i].valid    = ext_out[NIN0 + i].valid;          \
      	assign ext_in1[i].data     = ext_out[NIN0 + i].data;           \
      	assign ext_out[NIN0 + i].ready    = ext_in1[i].ready;          \
      end                                                           

`define SPLIT_EXT_CHANNEL_ARRAYS(ext_out0,ext_out1,ext_int,NIN0,NIN1)  \
      for(genvar i=0;i<NIN0;i++) begin                                 \
        assign ext_out0[i].req         = ext_int[i].req           ;     \
        assign ext_out0[i].datasize    = ext_int[i].datasize      ;     \
        assign ext_out0[i].destination = ext_int[i].destination   ;     \
        assign ext_out0[i].addr        = ext_int[i].addr          ;     \
        assign ext_out0[i].ready       = ext_int[i].ready         ;     \
        assign ext_int[i].gnt          = ext_out0[i].gnt          ;     \
        assign ext_int[i].valid        = ext_out0[i].valid        ;     \
        assign ext_int[i].data         = ext_out0[i].data         ;     \
      end                                                               \
      for(genvar i=0;i<NIN1;i++) begin                                  \
        assign ext_out1[i].req          = ext_int[NIN0 + i].req        ; \
        assign ext_out1[i].datasize     = ext_int[NIN0 + i].datasize   ; \
        assign ext_out1[i].destination  = ext_int[NIN0 + i].destination; \
        assign ext_out1[i].addr         = ext_int[NIN0 + i].addr       ; \
        assign ext_out1[i].ready        = ext_int[NIN0 + i].ready      ; \
        assign ext_int[NIN0 + i].gnt    = ext_out1[i].gnt              ; \
        assign ext_int[NIN0 + i].valid  = ext_out1[i].valid            ; \
        assign ext_int[NIN0 + i].data   = ext_out1[i].data             ; \
      end  