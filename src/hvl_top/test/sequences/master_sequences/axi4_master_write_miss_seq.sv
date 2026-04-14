
`ifndef AXI4_MASTER_WRITE_MISS_SEQ_INCLUDED_
`define AXI4_MASTER_WRITE_MISS_SEQ_INCLUDED_

class axi4_master_write_miss_seq extends axi4_master_base_seq;
  `uvm_object_utils(axi4_master_write_miss_seq)

  function new(string name = "axi4_master_write_miss_seq");
    super.new(name);
  endfunction

  task body();

    req = axi4_master_tx::type_id::create("req");

    start_item(req);

    // ---------------------------------------------
    // RANDOMIZATION (MATCH YOUR EXISTING STYLE)
    // ---------------------------------------------
    if (!req.randomize() with {

      // WRITE CONFIG
      req.tx_type       == WRITE;
      req.transfer_type == BLOCKING_WRITE; // or your env equivalent

      // BURST CONFIG
      req.awburst == WRITE_INCR;
      req.awsize  == WRITE_4_BYTES;  // 32-bit
      req.awlen   == 3;              // 4 beats
      req.awcache == 4'b1111;
      
      req.addr == 32'h8000_1000;

    }) begin
      `uvm_fatal("AXI4_WRITE_MISS_SEQ", "Randomization failed")
    end

    // ---------------------------------------------
    // DATA (4 BEATS)
    // ---------------------------------------------

    foreach (req.data[i]) begin
      req.data[i] = 32'hA000_0000 + i;
    end

    // ---------------------------------------------
    // WSTRB
    // ---------------------------------------------

    foreach (req.wstrb[i]) begin
      req.wstrb[i] = 4'hF;
    end

    finish_item(req);

    // ---------------------------------------------
    // DEBUG PRINT
    // ---------------------------------------------
    `uvm_info(get_type_name(),
      $sformatf("WRITE MISS: addr=0x%0h len=%0d", req.addr, req.awlen),
      UVM_MEDIUM)

  endtask

endclass

`endif
