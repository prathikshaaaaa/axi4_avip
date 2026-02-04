`ifndef HDL_TOP_INCLUDED_
`define HDL_TOP_INCLUDED_

//--------------------------------------------------------------------------------------------
// Module : HDL Top
// Description : Multi-master, multi-slave AXI4 testbench top
//--------------------------------------------------------------------------------------------
module hdl_top;

  import uvm_pkg::*;
  import axi4_globals_pkg::*;
  `include "uvm_macros.svh"

  bit aclk;
  bit aresetn;

  initial begin
    $display("HDL_TOP");
  end

  initial begin
    aclk = 1'b0;
    forever #10 aclk = ~aclk;
  end


  initial begin
    aresetn = 1'b1;
    #10 aresetn = 1'b0;
    repeat (1) begin
      @(posedge aclk);
    end
    aresetn = 1'b1;
  end

  initial begin
    $dumpfile("waveform.vcd");
    $dumpvars(0, hdl_top);
  end

  axi4_if master_if [NO_OF_MASTERS] (.aclk(aclk), .aresetn(aresetn));
  axi4_if slave_if  [NO_OF_SLAVES]  (.aclk(aclk), .aresetn(aresetn));

//----------------------------------
  // AXI Interconnect + Cache
  //----------------------------------
  axi_interconnect_cache #(
    .NO_OF_MASTERS(NO_OF_MASTERS),
    .NO_OF_SLAVES (NO_OF_SLAVES)
  ) axi_interconnect (
    .aclk      (aclk),
    .aresetn  (aresetn),
    .master_if(master_if),
    .slave_if (slave_if)
  );

  genvar i;
  generate
    for (i=0; i<NO_OF_MASTERS; i++) begin : MASTER_BFM
      axi4_master_bfm master_bfm (
        .master_if(master_if[i])  
      );
    end
  endgenerate

  genvar j;
  generate
    for (j=0; j<NO_OF_SLAVES; j++) begin : SLAVE_BFM
      axi4_slave_bfm slave_bfm (
        .slave_if(slave_if[j])  
      );
    end
  endgenerate


  /*initial begin
    for (int m=0; m<NO_OF_MASTERS; m++) begin
      uvm_config_db#(virtual axi4_if)::set(null, $sformatf("*master_agent[%0d]*", m), "vif", master_if[m]);
    end

    for (int s=0; s<NO_OF_SLAVES; s++) begin
      uvm_config_db#(virtual axi4_if)::set(null, $sformatf("*slave_agent[%0d]*", s), "vif", slave_if[s]);
    end
  end*/

endmodule : hdl_top

`endif // HDL_TOP_INCLUDED_
