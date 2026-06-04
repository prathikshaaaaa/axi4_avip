`ifndef AXI4_MASTER_READ_MISS_SEQ_INCLUDED_
`define AXI4_MASTER_READ_MISS_SEQ_INCLUDED_

class axi4_master_read_miss_seq extends axi4_master_base_seq;
  `uvm_object_utils(axi4_master_read_miss_seq)

  function new(string name="axi4_master_read_miss_seq");
    super.new(name);
  endfunction

  task body();

    req = axi4_master_tx::type_id::create("req");

    start_item(req);

    if(!req.randomize() with {

      // READ CONFIG
      req.tx_type       == READ;
      req.transfer_type == NON_OUTSTANDING_READ;

      // BURST CONFIG
      req.arburst == READ_INCR;
      req.arsize  == READ_4_BYTES;
      req.arlen   == 3;                // 4-beat cache line

      req.arcache == READ_WRITE_ALLOCATE;

      // Force cache miss address
      req.araddr == 32'h0000_0001;

    }) begin
      `uvm_fatal("AXI4_READ_MISS_SEQ",
                 "Randomization failed")
    end

    finish_item(req);

    `uvm_info(get_type_name(),
              $sformatf("READ MISS: addr=0x%0h len=%0d",
                        req.araddr,
                        req.arlen),
              UVM_MEDIUM)

  endtask

endclass

`endif
