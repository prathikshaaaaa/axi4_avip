
`ifndef AXI4_SLAVE_REFILL_SEQ_INCLUDED_
`define AXI4_SLAVE_REFILL_SEQ_INCLUDED_
 
class axi4_slave_refill_seq extends axi4_slave_base_seq;
  `uvm_object_utils(axi4_slave_refill_seq)
  function new(string name="axi4_slave_refill_seq");
    super.new(name);
  endfunction
  task body();
    super.body();
    req = axi4_slave_tx::type_id::create("req");
    start_item(req);
    if(!req.randomize() with {
      // 1. Must be a READ transaction to satisfy the AR request
      req.tx_type       == READ;
      req.transfer_type == NON_OUTSTANDING_READ;
      // 2. Match the burst parameters expected for a cache line fetch
      req.arburst == READ_INCR;      // Or READ_WRAP, depending on your cache RTL
      req.arsize  == READ_4_BYTES;   // Assuming a 32-bit data bus
      // 3. Full cache line burst length
      req.arlen   == WORDS_PER_LINE - 1;
 
      // 4. Force a successful OKAY response from the slave DDR
      // (Assuming your transaction class has an array for rresp per beat)
     req.rdata.size() == req.arlen + 1;
      req.rresp == READ_OKAY;
     
      // foreach(req.rresp[i]) {
      //    req.rresp[i] == 2'b00; // OKAY response
      // }
    }) begin
     req.print();
      `uvm_fatal("SLV_REFILL_SEQ", "Randomization failed");
    end
    finish_item(req);
  endtask
endclass
 
`endif
